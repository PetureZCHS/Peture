-- 为用户和宠物添加"主人昵称"相关字段
-- users_profiles 添加 owner_nickname（宠物对主人的默认称呼）
ALTER TABLE public.users_profiles
  ADD COLUMN IF NOT EXISTS owner_nickname text NOT NULL DEFAULT '主人';

-- pets 添加 owner_nickname（该宠物对主人的称呼）和 use_custom_nickname（是否使用自定义称呼）
ALTER TABLE public.pets
  ADD COLUMN IF NOT EXISTS owner_nickname text,
  ADD COLUMN IF NOT EXISTS use_custom_nickname boolean NOT NULL DEFAULT false;

-- 添加注释说明
COMMENT ON COLUMN public.users_profiles.owner_nickname IS '宠物对主人的默认称呼（例如：主人、妈妈、姐姐）';
COMMENT ON COLUMN public.pets.owner_nickname IS '该宠物对主人的自定义称呼（当 use_custom_nickname=true 时生效）';
COMMENT ON COLUMN public.pets.use_custom_nickname IS '是否为该宠物使用自定义称呼（false 时使用 users_profiles.owner_nickname）';
