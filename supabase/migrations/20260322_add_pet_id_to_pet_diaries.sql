-- 为 pet_diaries 表添加 pet_id 字段
ALTER TABLE public.pet_diaries 
ADD COLUMN IF NOT EXISTS pet_id uuid;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_pet_diaries_pet_id ON public.pet_diaries(pet_id);
