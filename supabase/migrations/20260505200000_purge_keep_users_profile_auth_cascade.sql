-- 注销：purge 不再删除 users_profiles，保留 account_deletion_* 标记以便 Auth 删除失败时可重试或 cron 再次处理。
-- 删除 Auth 用户时需一并删除 profile：将 users_profiles -> auth.users 外键设为 ON DELETE CASCADE（若已存在则替换）。

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE n.nspname = 'public'
      AND t.relname = 'users_profiles'
      AND c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND cardinality(c.conkey) = 1
      AND EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = c.conrelid
          AND a.attnum = c.conkey[1]
          AND NOT a.attisdropped
          AND a.attname = 'id'
      )
  ) LOOP
    EXECUTE format('ALTER TABLE public.users_profiles DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE public.users_profiles
  ADD CONSTRAINT users_profiles_id_fkey_auth_users_cascade
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION public.purge_user_business_data(p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'purge_user_business_data: null user id';
  END IF;

  DELETE FROM public.community_post_likes WHERE user_id = p_target_user_id;
  DELETE FROM public.community_post_collections WHERE user_id = p_target_user_id;
  DELETE FROM public.community_post_comments WHERE user_id = p_target_user_id;
  DELETE FROM public.community_user_follows
  WHERE follower_id = p_target_user_id OR following_id = p_target_user_id;
  DELETE FROM public.community_posts WHERE author_id = p_target_user_id;

  DELETE FROM public.chat_messages WHERE user_id = p_target_user_id;
  DELETE FROM public.conversations WHERE user_id = p_target_user_id;
  DELETE FROM public.pet_diaries WHERE user_id = p_target_user_id;
  DELETE FROM public.medical_records WHERE user_id = p_target_user_id;
  DELETE FROM public.weight_records WHERE user_id = p_target_user_id;
  DELETE FROM public.vaccine_records WHERE user_id = p_target_user_id;
  DELETE FROM public.daily_reminders WHERE user_id = p_target_user_id;
  DELETE FROM public.medication_reminders WHERE user_id = p_target_user_id;
  DELETE FROM public.vaccine_reminders WHERE user_id = p_target_user_id;
  DELETE FROM public.deworming_reminders WHERE user_id = p_target_user_id;
  DELETE FROM public.daily_cost_items WHERE user_id = p_target_user_id;
  DELETE FROM public.fitness_records WHERE user_id = p_target_user_id;
  DELETE FROM public.health_plans WHERE user_id = p_target_user_id;
  DELETE FROM public.unified_expenses WHERE user_id = p_target_user_id;

  DELETE FROM public.pet_passport_achievements
  WHERE passport_id IN (
    SELECT id FROM public.pet_passports WHERE user_id = p_target_user_id
  );

  DELETE FROM public.pet_passports WHERE user_id = p_target_user_id;
  DELETE FROM public.pets WHERE user_id = p_target_user_id;
  -- users_profiles 保留至 auth.admin.deleteUser 成功；由 ON DELETE CASCADE 随 auth.users 删除。
END;
$$;

COMMENT ON FUNCTION public.purge_user_business_data(uuid) IS
  '服务端注销时清业务表；不删 users_profiles（冷静期标记与重试）；profile 随 auth 用户 CASCADE 删除。';
