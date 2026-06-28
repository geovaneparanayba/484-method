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
--
-- Datas usam o fuso do produto (America/Sao_Paulo), nunca UTC: senão à noite
-- (já depois da meia-noite UTC) os cohorts de retenção e "hoje" escorregam um
-- dia. Métricas pra investidor: usuários = user_id distintos em events (base
-- única e consistente em todas as janelas).
create or replace function public.get_dev_stats()
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  tz CONSTANT text := 'America/Sao_Paulo';
  azure_rate_usd_per_hour CONSTANT numeric := 1.0; -- tarifa S0 Azure (pron. assessment)
  v_total_users int;
  v_today date := (NOW() AT TIME ZONE tz)::date;  -- "hoje" no fuso do produto, não UTC
  v_retention json;
BEGIN
  SELECT COUNT(DISTINCT user_id) INTO v_total_users FROM events;

  -- Retenção DN = voltou em algum dia dentro de [1º dia + 1, 1º dia + N].
  -- Cohort = só quem é velho o bastante p/ ter tido a chance (fd <= hoje - N).
  -- pct null quando o cohort está vazio (caso do D30 com app < 30 dias).
  SELECT json_build_object(
    'd1', json_build_object(
      'pct', ROUND(100.0 * COUNT(*) FILTER (WHERE r1 AND fd <= v_today - 1)
             / NULLIF(COUNT(*) FILTER (WHERE fd <= v_today - 1), 0), 1),
      'n', COUNT(*) FILTER (WHERE fd <= v_today - 1)),
    'd7', json_build_object(
      'pct', ROUND(100.0 * COUNT(*) FILTER (WHERE r7 AND fd <= v_today - 7)
             / NULLIF(COUNT(*) FILTER (WHERE fd <= v_today - 7), 0), 1),
      'n', COUNT(*) FILTER (WHERE fd <= v_today - 7)),
    'd30', json_build_object(
      'pct', ROUND(100.0 * COUNT(*) FILTER (WHERE r30 AND fd <= v_today - 30)
             / NULLIF(COUNT(*) FILTER (WHERE fd <= v_today - 30), 0), 1),
      'n', COUNT(*) FILTER (WHERE fd <= v_today - 30))
  ) INTO v_retention
  FROM (
    SELECT user_id, fd,
           BOOL_OR(d = fd + 1)                  AS r1,
           BOOL_OR(d BETWEEN fd + 1 AND fd + 7)  AS r7,
           BOOL_OR(d BETWEEN fd + 1 AND fd + 30) AS r30
    FROM (
      SELECT user_id,
             DATE(created_at AT TIME ZONE tz) AS d,
             MIN(DATE(created_at AT TIME ZONE tz)) OVER (PARTITION BY user_id) AS fd
      FROM events
    ) x
    GROUP BY user_id, fd
  ) base;

  RETURN json_build_object(
    -- ── Usuários ──────────────────────────────────────────────────────────
    'total_users',      v_total_users,
    'users_today',      (SELECT COUNT(DISTINCT user_id) FROM events WHERE created_at >= NOW() - INTERVAL '24 hours'),
    'users_7d',         (SELECT COUNT(DISTINCT user_id) FROM events WHERE created_at >= NOW() - INTERVAL '7 days'),
    'users_30d',        (SELECT COUNT(DISTINCT user_id) FROM events WHERE created_at >= NOW() - INTERVAL '30 days'),
    'users_with_streak',(SELECT COUNT(*) FROM progress WHERE streak_days > 0),
    'avg_streak_days',  (SELECT COALESCE(ROUND(AVG(streak_days), 1), 0) FROM progress),
    'rigorous_mode_users',(SELECT COUNT(*) FROM progress WHERE rigorous_mode = true),
    -- Stickiness DAU/MAU (hábito): ativos hoje / ativos em 30d.
    'stickiness_pct', (
      SELECT COALESCE(ROUND(100.0 *
        (SELECT COUNT(DISTINCT user_id) FROM events WHERE created_at >= NOW() - INTERVAL '24 hours')
        / NULLIF((SELECT COUNT(DISTINCT user_id) FROM events WHERE created_at >= NOW() - INTERVAL '30 days'), 0), 1), 0)
    ),

    -- ── Retenção (cohort) & ativação ─────────────────────────────────────
    'retention', v_retention,
    'activation', (
      SELECT json_build_object('started', started_n, 'activated', activated_n,
        'pct', COALESCE(ROUND(100.0 * activated_n / NULLIF(started_n, 0), 1), 0))
      FROM (SELECT
              (SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'lesson_started')  AS started_n,
              (SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'lesson_completed') AS activated_n) a
    ),

    -- ── Crescimento ──────────────────────────────────────────────────────
    'new_users_14d', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.day), '[]'::json)
      FROM (SELECT fd AS day, COUNT(*) AS users
            FROM (SELECT user_id, MIN(DATE(created_at AT TIME ZONE tz)) AS fd FROM events GROUP BY user_id) f
            WHERE fd >= v_today - 13 GROUP BY fd ORDER BY fd) t
    ),
    'north_star_14d', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.day), '[]'::json)
      FROM (SELECT DATE(created_at AT TIME ZONE tz) AS day,
                   ROUND(SUM((props->>'approved_seconds')::numeric) / 60.0, 1) AS approved_min
            FROM events WHERE event = 'lesson_completed' AND props->>'approved_seconds' IS NOT NULL
              AND created_at >= NOW() - INTERVAL '14 days'
            GROUP BY day ORDER BY day) t
    ),

    -- ── Profundidade de engajamento ──────────────────────────────────────
    'lessons_per_active_user', (
      SELECT COALESCE(ROUND((SELECT COUNT(*) FROM events WHERE event = 'lesson_completed')::numeric
        / NULLIF((SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'lesson_completed'), 0), 1), 0)
    ),
    'recordings_per_user', (
      SELECT COALESCE(ROUND((SELECT COUNT(*) FROM events WHERE event = 'attempt_assessed')::numeric
        / NULLIF((SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'attempt_assessed'), 0), 1), 0)
    ),

    -- ── Engajamento ───────────────────────────────────────────────────────
    'total_attempts',   (SELECT COUNT(*) FROM events WHERE event = 'attempt_assessed'),
    'total_completed',  (SELECT COUNT(*) FROM events WHERE event = 'lesson_completed'),
    'avg_accuracy',     (SELECT ROUND(AVG((props->>'accuracy')::numeric)) FROM events
                         WHERE event = 'attempt_assessed' AND props->>'accuracy' IS NOT NULL),
    'total_approved_min',(SELECT COALESCE(ROUND(SUM(approved_seconds) / 60.0), 0) FROM progress),
    'approval_rate',    (SELECT COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE props->>'approved' = 'true')
                            / NULLIF(COUNT(*), 0), 1), 0) FROM events WHERE event = 'attempt_assessed'),
    'avg_attempts_to_approve', (SELECT COALESCE(ROUND(AVG((props->>'attempt')::numeric), 1), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'approved' = 'true'),
    'avg_seconds_between_attempts', (
      SELECT COALESCE(ROUND(AVG(gap), 1), 0)
      FROM (SELECT EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (
                     PARTITION BY user_id, props->>'lesson' ORDER BY created_at))) AS gap
            FROM events WHERE event = 'attempt_assessed') t WHERE gap IS NOT NULL AND gap BETWEEN 0 AND 120
    ),

    -- ── Áudio / custo Azure ──────────────────────────────────────────────
    'avg_audio_seconds', (SELECT COALESCE(ROUND(AVG((props->>'audio_seconds')::numeric), 1), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'audio_seconds' IS NOT NULL),
    'max_audio_seconds', (SELECT COALESCE(ROUND(MAX((props->>'audio_seconds')::numeric), 1), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'audio_seconds' IS NOT NULL),
    'total_audio_sent_min', (SELECT COALESCE(ROUND(SUM((props->>'audio_seconds')::numeric) / 60.0, 1), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'audio_seconds' IS NOT NULL),
    'azure_cost_usd', (SELECT COALESCE(ROUND(SUM((props->>'audio_seconds')::numeric) / 3600.0 * azure_rate_usd_per_hour, 2), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'audio_seconds' IS NOT NULL),
    'azure_cost_per_user_usd', (SELECT COALESCE(ROUND(
        SUM((props->>'audio_seconds')::numeric) / 3600.0 * azure_rate_usd_per_hour / NULLIF(v_total_users, 0), 4), 0)
      FROM events WHERE event = 'attempt_assessed' AND props->>'audio_seconds' IS NOT NULL),

    -- ── Distribuição de notas (accuracy) ─────────────────────────────────
    'accuracy_histogram', (
      SELECT COALESCE(json_object_agg(bucket, n ORDER BY bucket), '{}'::json)
      FROM (SELECT CASE WHEN acc < 50 THEN '0-49' WHEN acc < 70 THEN '50-69'
                        WHEN acc < 85 THEN '70-84' WHEN acc < 95 THEN '85-94' ELSE '95-100' END AS bucket,
                   COUNT(*) AS n
            FROM (SELECT (props->>'accuracy')::numeric AS acc FROM events
                  WHERE event = 'attempt_assessed' AND props->>'accuracy' IS NOT NULL) a
            GROUP BY bucket) t
    ),

    -- ── Palavras mais difíceis ───────────────────────────────────────────
    'hardest_words', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
      FROM (SELECT props->>'item' AS word, ROUND(AVG((props->>'accuracy')::numeric)) AS avg_accuracy, COUNT(*) AS attempts
            FROM events WHERE event = 'attempt_assessed' AND props->>'item' IS NOT NULL AND props->>'accuracy' IS NOT NULL
            GROUP BY word HAVING COUNT(*) >= 3 ORDER BY AVG((props->>'accuracy')::numeric) ASC LIMIT 8) t
    ),

    -- ── Tempo até concluir cada lição ────────────────────────────────────
    'lesson_duration', (
      SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.lesson_id), '[]'::json)
      FROM (SELECT lesson_id, ROUND(AVG(dur)) AS avg_seconds, COUNT(*) AS n
            FROM (SELECT c.props->>'lesson' AS lesson_id, EXTRACT(EPOCH FROM (c.created_at - s.started_at)) AS dur
                  FROM events c
                  JOIN LATERAL (SELECT s2.created_at AS started_at FROM events s2
                    WHERE s2.user_id = c.user_id AND s2.event = 'lesson_started'
                      AND s2.props->>'lesson' = c.props->>'lesson' AND s2.created_at <= c.created_at
                    ORDER BY s2.created_at DESC LIMIT 1) s ON true
                  WHERE c.event = 'lesson_completed') raw
            WHERE dur BETWEEN 0 AND 3600 GROUP BY lesson_id) g
    ),

    -- ── Saúde operacional ─────────────────────────────────────────────────
    'assessment_failures', (SELECT COUNT(*) FROM events WHERE event = 'assessment_failed'),
    'recordings_discarded_silence', (SELECT COUNT(*) FROM events WHERE event = 'recording_discarded_silence'),
    'feedback_fallback_used', (SELECT COUNT(*) FROM events WHERE event = 'feedback_fallback_used'),

    -- ── Funil de aquisição (landing → CTA → consentimento → 1ª lição) ────
    -- landing_views fica 0 até o app instrumentar 'landing_viewed'.
    'acquisition_funnel', json_build_object(
      'landing_views',     (SELECT COUNT(*) FROM events WHERE event = 'landing_viewed'),
      'cta_clicks',        (SELECT COUNT(*) FROM events WHERE event = 'onboarding_cta_clicked'),
      'consent_accepted',  (SELECT COUNT(*) FROM events WHERE event = 'onboarding_consent_accepted'),
      'first_lesson_done', (SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'lesson_completed')
    ),

    -- ── Funil de paywall ──────────────────────────────────────────────────
    'paywall_views',            (SELECT COUNT(*) FROM events WHERE event = 'paywall_viewed'),
    'paywall_subscribe_clicks', (SELECT COUNT(*) FROM events WHERE event = 'paywall_subscribe_clicked'),
    'paywall_dismissals',       (SELECT COUNT(*) FROM events WHERE event = 'paywall_dismissed'),

    -- ── Funil de onboarding (compat) ─────────────────────────────────────
    'onboarding_cta_clicks',       (SELECT COUNT(*) FROM events WHERE event = 'onboarding_cta_clicked'),
    'onboarding_consent_accepted', (SELECT COUNT(*) FROM events WHERE event = 'onboarding_consent_accepted'),

    -- ── Aquisição: fonte / referrer (instrumentado em device_info.source) ─
    'source_breakdown', (
      SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (SELECT COALESCE(props->>'source', props->>'referrer') AS k, COUNT(*) AS n
            FROM events WHERE event = 'device_info'
              AND COALESCE(props->>'source', props->>'referrer') IS NOT NULL GROUP BY k) t
    ),

    -- ── Dispositivo: browser / SO / idioma ───────────────────────────────
    'browser_breakdown', (SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (SELECT props->>'browser' AS k, COUNT(*) AS n FROM events
            WHERE event = 'device_info' AND props->>'browser' IS NOT NULL GROUP BY k) t),
    'os_breakdown', (SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (SELECT props->>'os' AS k, COUNT(*) AS n FROM events
            WHERE event = 'device_info' AND props->>'os' IS NOT NULL GROUP BY k) t),
    'locale_breakdown', (SELECT COALESCE(json_object_agg(k, n ORDER BY n DESC), '{}'::json)
      FROM (SELECT props->>'locale' AS k, COUNT(*) AS n FROM events
            WHERE event = 'device_info' AND props->>'locale' IS NOT NULL GROUP BY k) t),

    -- ── Bônus ─────────────────────────────────────────────────────────────
    'bonus_lessons_completed', (SELECT COUNT(*) FROM events WHERE event = 'lesson_completed'
      AND props->>'lesson' IN ('fase1-licao07', 'fase1-licao13', 'fase1-licao20')),
    'bonus_users', (SELECT COUNT(DISTINCT user_id) FROM events WHERE event = 'lesson_completed'
      AND props->>'lesson' IN ('fase1-licao07', 'fase1-licao13', 'fase1-licao20')),

    -- ── Retenção D1 legada (mantida p/ compat) ───────────────────────────
    'retention_d1_pct', (
      SELECT COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE returned_d1) / NULLIF(COUNT(*), 0), 1), 0)
      FROM (SELECT e.user_id,
              EXISTS (SELECT 1 FROM events e2 WHERE e2.user_id = e.user_id
                AND DATE(e2.created_at AT TIME ZONE tz) = MIN(DATE(e.created_at AT TIME ZONE tz)) + 1) AS returned_d1
            FROM events e GROUP BY e.user_id
            HAVING MIN(DATE(e.created_at AT TIME ZONE tz)) <= v_today - 1) t
    ),

    -- ── Funil por lição (usuários únicos que concluíram) ─────────────────
    'funnel', (SELECT COALESCE(json_object_agg(lesson_id, users ORDER BY (lesson_id)), '{}'::json)
      FROM (SELECT props->>'lesson' AS lesson_id, COUNT(DISTINCT user_id) AS users
            FROM events WHERE event = 'lesson_completed' GROUP BY lesson_id) t),

    -- ── DAU últimos 14 dias ───────────────────────────────────────────────
    'dau_14d', (SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.day), '[]'::json)
      FROM (SELECT DATE(created_at AT TIME ZONE tz) AS day, COUNT(DISTINCT user_id) AS users
            FROM events WHERE created_at >= NOW() - INTERVAL '14 days' GROUP BY day ORDER BY day) t),

    -- ── Usuários ativos por hora (últimas 48h) ────────────────────────────
    'hourly_48h', (SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.hour_ts), '[]'::json)
      FROM (SELECT date_trunc('hour', created_at AT TIME ZONE tz) AS hour_ts, COUNT(DISTINCT user_id) AS users
            FROM events WHERE created_at >= NOW() - INTERVAL '48 hours' GROUP BY hour_ts ORDER BY hour_ts) t),

    -- ── Dropoff: iniciou mas não completou nenhuma lição ─────────────────
    'started_not_finished', (SELECT COUNT(DISTINCT s.user_id) FROM events s WHERE s.event = 'lesson_started'
      AND NOT EXISTS (SELECT 1 FROM events c WHERE c.user_id = s.user_id AND c.event = 'lesson_completed'))
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

-- Teto diário de feedbacks via Claude por usuário (guarda de custo contra
-- loop/abuso de um único usuário). RLS ligado SEM policies = nenhum acesso
-- direto do cliente; só a função SECURITY DEFINER abaixo lê/escreve.
-- Aplicado em 2026-06-27 (migração feedback_daily_quota).
create table if not exists public.feedback_quota (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  count int not null default 0,
  primary key (user_id, day)
);
alter table public.feedback_quota enable row level security;

-- Incrementa o contador do dia de forma atômica e devolve se a chamada é
-- permitida (false acima do teto). Chamada pela Edge Function `feedback`
-- antes de gerar via Claude; acima do teto → 429 → cliente usa a msg fixa.
create or replace function public.consume_feedback_quota(p_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_count int;
begin
  if auth.uid() is null then
    return true; -- sem usuário identificado: não conta, deixa passar
  end if;
  insert into public.feedback_quota as fq (user_id, day, count)
  values (auth.uid(), current_date, 1)
  on conflict (user_id, day) do update
    set count = fq.count + 1
    where fq.count < p_limit
  returning fq.count into v_count;
  return v_count is not null;
end;
$function$;
revoke all on function public.consume_feedback_quota(int) from public;
grant execute on function public.consume_feedback_quota(int) to authenticated, anon;
