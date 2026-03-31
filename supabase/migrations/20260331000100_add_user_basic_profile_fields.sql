-- 为用户资料补充基础信息字段：性别、出生日期、省、市
ALTER TABLE public.users_profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS birth_date date,
  ADD COLUMN IF NOT EXISTS province text,
  ADD COLUMN IF NOT EXISTS city text;

COMMENT ON COLUMN public.users_profiles.gender IS '用户性别（应用层枚举：男/女/其他/不透露）';
COMMENT ON COLUMN public.users_profiles.birth_date IS '用户出生日期';
COMMENT ON COLUMN public.users_profiles.province IS '用户所在省份';
COMMENT ON COLUMN public.users_profiles.city IS '用户所在城市';
