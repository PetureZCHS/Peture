-- 账号注销：在数据库内以 SECURITY DEFINER 删除业务数据，绕过 PostgREST/RLS 导致的 permission_denied。
-- Edge Function delete-my-account 通过 service_role 调用 public.purge_user_business_data(uuid)。
-- 执行：Supabase SQL Editor 粘贴运行，或 supabase db push。

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
  DELETE FROM public.users_profiles WHERE id = p_target_user_id;
END;
$$;

COMMENT ON FUNCTION public.purge_user_business_data(uuid) IS
  '服务端（service_role）注销时清业务表；勿对 authenticated 开放 EXECUTE。';

REVOKE ALL ON FUNCTION public.purge_user_business_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_user_business_data(uuid) TO service_role;
