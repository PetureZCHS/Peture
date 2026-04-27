-- 修复客户端更新资料时报 permission denied (42501)、以及 UPDATE 无行匹配等问题。
-- 原因常见为：authenticated 角色缺少表权限，或已启用 RLS 但缺少 SELECT/INSERT/UPDATE 策略
-- （Postgres RLS 下 UPDATE 需能通过 SELECT 选中目标行）。

grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.users_profiles to authenticated;
grant select, insert, update, delete on table public.pets to authenticated;

alter table public.users_profiles enable row level security;
alter table public.pets enable row level security;

drop policy if exists "users_profiles_select_own_v1" on public.users_profiles;
drop policy if exists "users_profiles_insert_own_v1" on public.users_profiles;
drop policy if exists "users_profiles_update_own_v1" on public.users_profiles;
drop policy if exists "users_profiles_delete_own_v1" on public.users_profiles;

-- id 与 auth.uid() 统一按 text 比较，兼容 uuid / text 主键
create policy "users_profiles_select_own_v1"
  on public.users_profiles for select
  to authenticated
  using (auth.uid() is not null and id::text = auth.uid()::text);

create policy "users_profiles_insert_own_v1"
  on public.users_profiles for insert
  to authenticated
  with check (auth.uid() is not null and id::text = auth.uid()::text);

create policy "users_profiles_update_own_v1"
  on public.users_profiles for update
  to authenticated
  using (auth.uid() is not null and id::text = auth.uid()::text)
  with check (auth.uid() is not null and id::text = auth.uid()::text);

create policy "users_profiles_delete_own_v1"
  on public.users_profiles for delete
  to authenticated
  using (auth.uid() is not null and id::text = auth.uid()::text);

drop policy if exists "pets_select_own_v1" on public.pets;
drop policy if exists "pets_insert_own_v1" on public.pets;
drop policy if exists "pets_update_own_v1" on public.pets;
drop policy if exists "pets_delete_own_v1" on public.pets;

create policy "pets_select_own_v1"
  on public.pets for select
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "pets_insert_own_v1"
  on public.pets for insert
  to authenticated
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "pets_update_own_v1"
  on public.pets for update
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text)
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "pets_delete_own_v1"
  on public.pets for delete
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);
