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
