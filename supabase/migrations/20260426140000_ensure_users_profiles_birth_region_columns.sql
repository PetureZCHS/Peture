-- 修复 PGRST204：PostgREST 在 users_profiles 上找不到 birth_date / province / city。
-- 若线上库从未执行 20260331000100_add_user_basic_profile_fields.sql，会出现保存出生日期、地区失败。
-- 本迁移可重复执行（IF NOT EXISTS）。

alter table public.users_profiles
  add column if not exists birth_date date;

alter table public.users_profiles
  add column if not exists province text;

alter table public.users_profiles
  add column if not exists city text;

comment on column public.users_profiles.birth_date is '用户出生日期';
comment on column public.users_profiles.province is '用户所在省份';
comment on column public.users_profiles.city is '用户所在城市';

-- 刷新 PostgREST schema cache（Supabase 托管实例支持；若报权限可忽略，通常数秒内也会自动刷新）
notify pgrst, 'reload schema';
