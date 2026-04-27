-- 修复健康模块：medical_records / weight_records / vaccine_records / daily_reminders
-- 在 PostgREST 下报 permission denied (42501)。
-- 与 public.pets 一致：仅允许访问 user_id 与 auth.uid() 匹配的行（含 SELECT 以便 UPDATE 命中行）。

grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.medical_records to authenticated;
grant select, insert, update, delete on table public.weight_records to authenticated;
grant select, insert, update, delete on table public.vaccine_records to authenticated;
grant select, insert, update, delete on table public.daily_reminders to authenticated;

alter table public.medical_records enable row level security;
alter table public.weight_records enable row level security;
alter table public.vaccine_records enable row level security;
alter table public.daily_reminders enable row level security;

-- medical_records
drop policy if exists "medical_records_select_own_v1" on public.medical_records;
drop policy if exists "medical_records_insert_own_v1" on public.medical_records;
drop policy if exists "medical_records_update_own_v1" on public.medical_records;
drop policy if exists "medical_records_delete_own_v1" on public.medical_records;

create policy "medical_records_select_own_v1"
  on public.medical_records for select
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "medical_records_insert_own_v1"
  on public.medical_records for insert
  to authenticated
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "medical_records_update_own_v1"
  on public.medical_records for update
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text)
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "medical_records_delete_own_v1"
  on public.medical_records for delete
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

-- weight_records
drop policy if exists "weight_records_select_own_v1" on public.weight_records;
drop policy if exists "weight_records_insert_own_v1" on public.weight_records;
drop policy if exists "weight_records_update_own_v1" on public.weight_records;
drop policy if exists "weight_records_delete_own_v1" on public.weight_records;

create policy "weight_records_select_own_v1"
  on public.weight_records for select
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "weight_records_insert_own_v1"
  on public.weight_records for insert
  to authenticated
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "weight_records_update_own_v1"
  on public.weight_records for update
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text)
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "weight_records_delete_own_v1"
  on public.weight_records for delete
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

-- vaccine_records
drop policy if exists "vaccine_records_select_own_v1" on public.vaccine_records;
drop policy if exists "vaccine_records_insert_own_v1" on public.vaccine_records;
drop policy if exists "vaccine_records_update_own_v1" on public.vaccine_records;
drop policy if exists "vaccine_records_delete_own_v1" on public.vaccine_records;

create policy "vaccine_records_select_own_v1"
  on public.vaccine_records for select
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "vaccine_records_insert_own_v1"
  on public.vaccine_records for insert
  to authenticated
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "vaccine_records_update_own_v1"
  on public.vaccine_records for update
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text)
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "vaccine_records_delete_own_v1"
  on public.vaccine_records for delete
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

-- daily_reminders
drop policy if exists "daily_reminders_select_own_v1" on public.daily_reminders;
drop policy if exists "daily_reminders_insert_own_v1" on public.daily_reminders;
drop policy if exists "daily_reminders_update_own_v1" on public.daily_reminders;
drop policy if exists "daily_reminders_delete_own_v1" on public.daily_reminders;

create policy "daily_reminders_select_own_v1"
  on public.daily_reminders for select
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "daily_reminders_insert_own_v1"
  on public.daily_reminders for insert
  to authenticated
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "daily_reminders_update_own_v1"
  on public.daily_reminders for update
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text)
  with check (auth.uid() is not null and user_id::text = auth.uid()::text);

create policy "daily_reminders_delete_own_v1"
  on public.daily_reminders for delete
  to authenticated
  using (auth.uid() is not null and user_id::text = auth.uid()::text);
