-- 484 Method — schema inicial do backend (Supabase / Postgres).
-- Aplicado via MCP. Auth: sign-in anônimo (zero fricção) com upgrade para
-- e-mail mágico depois. RLS garante que cada usuário só acessa seus dados.

-- Progresso: uma linha por usuário (espelha o ProgressStore local).
create table if not exists public.progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  approved_seconds integer not null default 0,
  streak_days integer not null default 0,
  last_practice_day date,
  completed_lessons text[] not null default '{}',
  rigorous_mode boolean not null default false,
  voice_consent_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.progress enable row level security;

create policy "own progress: select" on public.progress
  for select using (auth.uid() = user_id);
create policy "own progress: insert" on public.progress
  for insert with check (auth.uid() = user_id);
create policy "own progress: update" on public.progress
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- LGPD: o usuário apaga os próprios dados pelo app (Backend.deleteRemoteData).
create policy "own progress: delete" on public.progress
  for delete using (auth.uid() = user_id);

-- Eventos de produto (métricas do MVP): append-only por usuário.
create table if not exists public.events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  event text not null,
  props jsonb not null default '{}'
);

alter table public.events enable row level security;

create policy "own events: select" on public.events
  for select using (auth.uid() = user_id);
create policy "own events: insert" on public.events
  for insert with check (auth.uid() = user_id);
-- LGPD: idem progress — exclusão dos próprios eventos pelo app.
create policy "own events: delete" on public.events
  for delete using (auth.uid() = user_id);

create index if not exists events_user_created_idx
  on public.events (user_id, created_at desc);

-- Painel de uso. SECURITY DEFINER porque o cliente só tem a anon key (RLS
-- bloquearia agregados entre usuários); EXECUTE é revogado de anon/
-- authenticated — só a Edge Function `dev-stats`, com a service role key,
-- consegue chamar get_dev_stats(). get_public_stats() fica exposta (stats
-- agregadas sem dado individual) para o painel de uso ao vivo público.
create or replace function public.get_dev_stats()
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  RETURN json_build_object(

    -- ── Usuários ──────────────────────────────────────────────────────────
    'total_users',      (SELECT COUNT(*) FROM progress),
    'users_today',      (SELECT COUNT(DISTINCT user_id) FROM events
                         WHERE created_at >= NOW() - INTERVAL '24 hours'),
    'users_7d',         (SELECT COUNT(DISTINCT user_id) FROM events
                         WHERE created_at >= NOW() - INTERVAL '7 days'),
    'users_30d',        (SELECT COUNT(DISTINCT user_id) FROM events
                         WHERE created_at >= NOW() - INTERVAL '30 days'),
    'users_with_streak',(SELECT COUNT(*) FROM progress WHERE streak_days > 0),
    'avg_streak_days',  (SELECT COALESCE(ROUND(AVG(streak_days), 1), 0) FROM progress),
    'rigorous_mode_users',(SELECT COUNT(*) FROM progress WHERE rigorous_mode = true),

    -- ── Engajamento ───────────────────────────────────────────────────────
    'total_attempts',   (SELECT COUNT(*) FROM events
                         WHERE event = 'attempt_assessed'),
    'total_completed',  (SELECT COUNT(*) FROM events
                         WHERE event = 'lesson_completed'),
    'avg_accuracy',     (SELECT ROUND(AVG((props->>'accuracy')::numeric))
                         FROM events WHERE event = 'attempt_assessed'
                         AND props->>'accuracy' IS NOT NULL),
    'total_approved_min',(SELECT COALESCE(ROUND(SUM(approved_seconds) / 60.0), 0)
                          FROM progress),
    'approval_rate',    (SELECT COALESCE(ROUND(100.0 *
                            COUNT(*) FILTER (WHERE props->>'approved' = 'true')
                            / NULLIF(COUNT(*), 0), 1), 0)
                         FROM events WHERE event = 'attempt_assessed'),
    'avg_attempts_to_approve', (
      SELECT COALESCE(ROUND(AVG((props->>'attempt')::numeric), 1), 0)
      FROM events
      WHERE event = 'attempt_assessed' AND props->>'approved' = 'true'
    ),
    'avg_seconds_between_attempts', (
      SELECT COALESCE(ROUND(AVG(gap), 1), 0)
      FROM (
        SELECT EXTRACT(EPOCH FROM (
                 created_at - LAG(created_at) OVER (
                   PARTITION BY user_id, props->>'lesson' ORDER BY created_at
                 )
               )) AS gap
        FROM events
        WHERE event = 'attempt_assessed'
      ) t
      WHERE gap IS NOT NULL AND gap BETWEEN 0 AND 120
    ),

    -- ── Áudio / custo (Azure cobra por segundo enviado) ──────────────────
    'avg_audio_seconds', (
      SELECT COALESCE(ROUND(AVG((props->>'audio_seconds')::numeric), 1), 0)
      FROM events WHERE event = 'attempt_assessed'
      AND props->>'audio_seconds' IS NOT NULL
    ),
    'max_audio_seconds', (
      SELECT COALESCE(ROUND(MAX((props->>'audio_seconds')::numeric), 1), 0)
      FROM events WHERE event = 'attempt_assessed'
      AND props->>'audio_seconds' IS NOT NULL
    ),
    'total_audio_sent_min', (
      SELECT COALESCE(ROUND(SUM((props->>'audio_seconds')::numeric) / 60.0, 1), 0)
      FROM events WHERE event = 'attempt_assessed'
      AND props->>'audio_seconds' IS NOT NULL
    ),

    -- ── Distribuição de notas (accuracy) ─────────────────────────────────
    'accuracy_histogram', (
      SELECT COALESCE(json_object_agg(bucket, n ORDER BY bucket), '{}'::json)
      FROM (
        SELECT
          CASE
            WHEN acc < 50 THEN '0-49'
            WHEN acc < 70 THEN '50-69'
            WHEN acc < 85 THEN '70-84'
            WHEN acc < 95 THEN '85-94'
            ELSE '95-100'
          END AS bucket,
          COUNT(*) AS n
        FROM (
          SELECT (props->>'accuracy')::numeric AS acc
          FROM events
          WHERE event = 'attempt_assessed' AND props->>'accuracy' IS NOT NULL
        ) a
        GROUP BY bucket
      ) t
    ),

    -- ── Palavras mais difíceis (menor accuracy média, min. 3 tentativas) ──
    'hardest_words', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
      FROM (
        SELECT props->>'item' AS word,
               ROUND(AVG((props->>'accuracy')::numeric)) AS avg_accuracy,
               COUNT(*) AS attempts
        FROM events
        WHERE event = 'attempt_assessed'
        AND props->>'item' IS NOT NULL
        AND props->>'accuracy' IS NOT NULL
        GROUP BY word
        HAVING COUNT(*) >= 3
        ORDER BY AVG((props->>'accuracy')::numeric) ASC
        LIMIT 8
      ) t
    ),

    -- ── Saúde operacional ─────────────────────────────────────────────────
    'assessment_failures', (
      SELECT COUNT(*) FROM events WHERE event = 'assessment_failed'
    ),
    'recordings_discarded_silence', (
      SELECT COUNT(*) FROM events WHERE event = 'recording_discarded_silence'
    ),
    'feedback_fallback_used', (
      SELECT COUNT(*) FROM events WHERE event = 'feedback_fallback_used'
    ),

    -- ── Funil de paywall ──────────────────────────────────────────────────
    'paywall_views',            (SELECT COUNT(*) FROM events WHERE event = 'paywall_viewed'),
    'paywall_subscribe_clicks', (SELECT COUNT(*) FROM events WHERE event = 'paywall_subscribe_clicked'),
    'paywall_dismissals',       (SELECT COUNT(*) FROM events WHERE event = 'paywall_dismissed'),

    -- ── Funil de onboarding ───────────────────────────────────────────────
    'onboarding_cta_clicks',        (SELECT COUNT(*) FROM events WHERE event = 'onboarding_cta_clicked'),
    'onboarding_consent_accepted',  (SELECT COUNT(*) FROM events WHERE event = 'onboarding_consent_accepted'),

    -- ── Dispositivo: browser / SO / idioma (agregado, 1x por sessão) ─────
    'browser_breakdown', (
      SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (
        SELECT props->>'browser' AS k, COUNT(*) AS n
        FROM events WHERE event = 'device_info' AND props->>'browser' IS NOT NULL
        GROUP BY k
      ) t
    ),
    'os_breakdown', (
      SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (
        SELECT props->>'os' AS k, COUNT(*) AS n
        FROM events WHERE event = 'device_info' AND props->>'os' IS NOT NULL
        GROUP BY k
      ) t
    ),
    'locale_breakdown', (
      SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (
        SELECT props->>'locale' AS k, COUNT(*) AS n
        FROM events WHERE event = 'device_info' AND props->>'locale' IS NOT NULL
        GROUP BY k
      ) t
    ),

    -- ── Bônus ─────────────────────────────────────────────────────────────
    'bonus_lessons_completed', (
      SELECT COUNT(*) FROM events
      WHERE event = 'lesson_completed'
      AND props->>'lesson' IN ('fase1-licao07', 'fase1-licao13', 'fase1-licao20')
    ),
    'bonus_users', (
      SELECT COUNT(DISTINCT user_id) FROM events
      WHERE event = 'lesson_completed'
      AND props->>'lesson' IN ('fase1-licao07', 'fase1-licao13', 'fase1-licao20')
    ),

    -- ── Retenção D1 (voltou no dia seguinte ao primeiro evento) ──────────
    'retention_d1_pct', (
      SELECT COALESCE(ROUND(100.0 *
        COUNT(*) FILTER (WHERE returned_d1)
        / NULLIF(COUNT(*), 0), 1), 0)
      FROM (
        SELECT
          e.user_id,
          MIN(DATE(e.created_at AT TIME ZONE 'America/Sao_Paulo')) AS first_day,
          EXISTS (
            SELECT 1 FROM events e2
            WHERE e2.user_id = e.user_id
            AND DATE(e2.created_at AT TIME ZONE 'America/Sao_Paulo')
                = MIN(DATE(e.created_at AT TIME ZONE 'America/Sao_Paulo')) + 1
          ) AS returned_d1
        FROM events e
        GROUP BY e.user_id
        HAVING MIN(DATE(e.created_at AT TIME ZONE 'America/Sao_Paulo')) <= CURRENT_DATE - 1
      ) t
    ),

    -- ── Funil por lição (usuários únicos que concluíram) ─────────────────
    'funnel', (
      SELECT COALESCE(
        json_object_agg(lesson_id, users ORDER BY (lesson_id)),
        '{}'::json
      )
      FROM (
        SELECT props->>'lesson'          AS lesson_id,
               COUNT(DISTINCT user_id)  AS users
        FROM   events
        WHERE  event = 'lesson_completed'
        GROUP  BY lesson_id
      ) t
    ),

    -- ── DAU últimos 14 dias ───────────────────────────────────────────────
    'dau_14d', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.day), '[]'::json)
      FROM (
        SELECT DATE(created_at AT TIME ZONE 'America/Sao_Paulo') AS day,
               COUNT(DISTINCT user_id)                           AS users
        FROM   events
        WHERE  created_at >= NOW() - INTERVAL '14 days'
        GROUP  BY day
        ORDER  BY day
      ) t
    ),

    -- ── Usuários ativos por hora (últimas 48h) ────────────────────────────
    'hourly_48h', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.hour_ts), '[]'::json)
      FROM (
        SELECT date_trunc('hour', created_at AT TIME ZONE 'America/Sao_Paulo') AS hour_ts,
               COUNT(DISTINCT user_id) AS users
        FROM   events
        WHERE  created_at >= NOW() - INTERVAL '48 hours'
        GROUP  BY hour_ts
        ORDER  BY hour_ts
      ) t
    ),

    -- ── Dropoff: iniciou mas não completou lição 1 ─────────────────────
    'started_not_finished', (
      SELECT COUNT(DISTINCT s.user_id)
      FROM   events s
      WHERE  s.event = 'lesson_started'
      AND    NOT EXISTS (
               SELECT 1 FROM events c
               WHERE  c.user_id = s.user_id
               AND    c.event   = 'lesson_completed'
             )
    )
  );
END;
$function$;

-- Painel de uso ao vivo público (demo para investidor): só agregados, zero
-- dado por usuário.
create or replace function public.get_public_stats()
returns json
language sql
stable security definer
as $function$
  select json_build_object(
    'total_users',
      (select count(distinct user_id) from public.events),
    'total_lessons_completed',
      (select count(*) from public.events where event = 'lesson_completed'),
    'total_attempts',
      (select count(*) from public.events where event = 'attempt_assessed'),
    'total_approved_seconds',
      (select coalesce(sum((props->>'approved_seconds')::int), 0)
       from public.events where event = 'lesson_completed'),
    'most_practiced_lesson',
      (select props->>'lesson' from public.events
       where event = 'lesson_completed'
       group by props->>'lesson'
       order by count(*) desc
       limit 1)
  );
$function$;
