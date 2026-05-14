create table if not exists public.user_feedback (
  id uuid primary key default extensions.uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  status text not null default 'new' check (status in ('new', 'processing', 'closed')),
  client jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_feedback_user_created
  on public.user_feedback(user_id, created_at desc);

create index if not exists idx_user_feedback_status_created
  on public.user_feedback(status, created_at desc);

alter table public.user_feedback enable row level security;

drop policy if exists user_feedback_insert_own on public.user_feedback;
create policy user_feedback_insert_own
  on public.user_feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists user_feedback_select_own on public.user_feedback;
create policy user_feedback_select_own
  on public.user_feedback
  for select
  to authenticated
  using (auth.uid() = user_id);

grant select, insert on table public.user_feedback to authenticated;
grant all on table public.user_feedback to service_role;
