-- 将 users_profiles.gender 规范为枚举 male / female / confidential（与 PostgREST 一致）

-- 先把中文或旧值写成可 cast 的文本
UPDATE public.users_profiles
SET gender = CASE trim(both from gender::text)
  WHEN '男' THEN 'male'
  WHEN '女' THEN 'female'
  WHEN 'male' THEN 'male'
  WHEN 'female' THEN 'female'
  WHEN 'confidential' THEN 'confidential'
  ELSE 'confidential'
END
WHERE gender IS NOT NULL
  AND trim(both from gender::text) NOT IN ('male', 'female', 'confidential');

DO $$
BEGIN
  CREATE TYPE public.user_gender AS ENUM ('male', 'female', 'confidential');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.users_profiles
  ALTER COLUMN gender TYPE public.user_gender
  USING (
    CASE
      WHEN gender IS NULL THEN NULL::public.user_gender
      WHEN trim(both from gender::text) = 'male' THEN 'male'::public.user_gender
      WHEN trim(both from gender::text) = 'female' THEN 'female'::public.user_gender
      WHEN trim(both from gender::text) = 'confidential' THEN 'confidential'::public.user_gender
      WHEN trim(both from gender::text) = '男' THEN 'male'::public.user_gender
      WHEN trim(both from gender::text) = '女' THEN 'female'::public.user_gender
      ELSE 'confidential'::public.user_gender
    END
  );

COMMENT ON COLUMN public.users_profiles.gender IS '用户性别枚举：male, female, confidential';
