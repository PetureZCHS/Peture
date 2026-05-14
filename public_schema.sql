


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."gender" AS ENUM (
    'male',
    'female',
    'other',
    'confidential'
);


ALTER TYPE "public"."gender" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrease_quota"("uid" "uuid", "decr" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$begin
  update public.test set quota = quota - decr where user_id = uid;
end;$$;


ALTER FUNCTION "public"."decrease_quota"("uid" "uuid", "decr" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") RETURNS TABLE("type" "text", "breed" "text", "name" "text", "gender" "text", "age" "text", "life_photo" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p.type,
    p.breed,
    p.name,
    p.gender,
    p.age,
    p.life_photo
  from public.pets p
  where p.id = p_pet_id
    and p.user_id = p_user_id
  limit 1;
$$;


ALTER FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  -- 当 auth.users 有新用户注册时，自动向 users_profiles 插入对应的 id
  -- 如果 users_profiles 还有其他必填字段，请在此处补充默认值
  insert into public.users_profiles (id)
  values (new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."img_gen_check_guard"("p_user_id" "uuid") RETURNS TABLE("allowed" boolean, "retry_after_ms" integer, "last_img_gen_check_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_now  timestamptz := now();
  v_last timestamptz;
  v_diff_ms bigint;
begin
  -- 若不存在则插入
  insert into public.ai_usage(id)
  values (p_user_id)
  on conflict (id) do nothing;

  -- 锁住该行，防并发重放
  select a.last_img_gen_check_at
    into v_last
  from public.ai_usage a
  where a.id = p_user_id
  for update;

  v_diff_ms := floor(extract(epoch from (v_now - v_last)) * 1000);

  if v_diff_ms > 4500 then
    update public.ai_usage
      set last_img_gen_check_at = v_now
    where id = p_user_id;

    allowed := true;
    retry_after_ms := 0;
    last_img_gen_check_at := v_now;
  else
    allowed := false;
    retry_after_ms := greatest(0, (4500 - v_diff_ms))::int;
    last_img_gen_check_at := v_last;
  end if;

  return next;
end $$;


ALTER FUNCTION "public"."img_gen_check_guard"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increase_quota"("uid" "uuid", "inc" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$begin
  update public.test set quota = quota + inc where user_id = uid;
end;$$;


ALTER FUNCTION "public"."increase_quota"("uid" "uuid", "inc" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_user_business_data"("p_target_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."purge_user_business_data"("p_target_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."purge_user_business_data"("p_target_user_id" "uuid") IS '服务端注销时清业务表；不删 users_profiles（冷静期标记与重试）；profile 随 auth 用户 CASCADE 删除。';



CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uid"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT null::uuid; -- 这是一个占位符，实际运行时会被 Supabase 的真实函数覆盖
$$;


ALTER FUNCTION "public"."uid"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."account_auth_delete_retry_queue" (
    "user_id" "uuid" NOT NULL,
    "enqueued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_error" "text"
);


ALTER TABLE "public"."account_auth_delete_retry_queue" OWNER TO "postgres";


COMMENT ON TABLE "public"."account_auth_delete_retry_queue" IS 'Auth 删除失败补偿队列；业务数据已由 purge_user_business_data 清空，仅需重试 deleteUser。';



CREATE TABLE IF NOT EXISTS "public"."achievements" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "passport_id" "uuid" NOT NULL,
    "achievement_id" "text" NOT NULL,
    "achievement_name" "text" NOT NULL,
    "achievement_description" "text" NOT NULL,
    "icon_name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "unlocked_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_users" (
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'analytics_admin'::"text" NOT NULL,
    "enabled" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_users_role_allowed" CHECK (("role" = ANY (ARRAY['analytics_admin'::"text", 'owner'::"text"])))
);


ALTER TABLE "public"."admin_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ai_image_presets" (
    "id" "text" DEFAULT ''::"text" NOT NULL,
    "name" "text" DEFAULT ''::"text" NOT NULL,
    "prompt" "text" DEFAULT ''::"text" NOT NULL,
    "aspect_ratio" "text" DEFAULT '1:1'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ai_image_presets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ai_usage" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_img_gen_check_at" timestamp with time zone DEFAULT '2026-01-01 00:00:00+00'::timestamp with time zone NOT NULL,
    "remaining_token_quota" bigint DEFAULT '100000'::bigint NOT NULL,
    "remaining_img_gen_quota" integer DEFAULT 5 NOT NULL
);


ALTER TABLE "public"."ai_usage" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."analytics_event_definitions" (
    "event_name" "text" NOT NULL,
    "module" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "enabled" boolean DEFAULT true NOT NULL,
    "allowed_properties" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "analytics_event_definitions_name_length" CHECK ((("char_length"("event_name") >= 1) AND ("char_length"("event_name") <= 80))),
    CONSTRAINT "analytics_event_definitions_props_array" CHECK (("jsonb_typeof"("allowed_properties") = 'array'::"text"))
);


ALTER TABLE "public"."analytics_event_definitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."analytics_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "anonymous_id" "text",
    "session_id" "uuid" NOT NULL,
    "event_name" "text" NOT NULL,
    "page_name" "text",
    "module" "text",
    "platform" "text" NOT NULL,
    "app_version" "text" NOT NULL,
    "device_locale" "text",
    "occurred_at" timestamp with time zone NOT NULL,
    "duration_ms" integer,
    "properties" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "client_event_id" "uuid",
    CONSTRAINT "analytics_events_duration_non_negative" CHECK ((("duration_ms" IS NULL) OR ("duration_ms" >= 0))),
    CONSTRAINT "analytics_events_name_length" CHECK ((("char_length"("event_name") >= 1) AND ("char_length"("event_name") <= 80))),
    CONSTRAINT "analytics_events_platform_length" CHECK ((("char_length"("platform") >= 1) AND ("char_length"("platform") <= 32))),
    CONSTRAINT "analytics_events_properties_object" CHECK (("jsonb_typeof"("properties") = 'object'::"text"))
);


ALTER TABLE "public"."analytics_events" OWNER TO "postgres";


COMMENT ON COLUMN "public"."analytics_events"."client_event_id" IS 'Client-generated UUID used by analytics-collect to deduplicate retries.';



CREATE TABLE IF NOT EXISTS "public"."chat_messages" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "text" "text" NOT NULL,
    "is_user" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_post_collections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."community_post_collections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_post_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "parent_id" "uuid",
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."community_post_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_post_likes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."community_post_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "author_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "image_urls" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "topic_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "source_type" "text" DEFAULT 'normal'::"text" NOT NULL,
    "like_count" integer DEFAULT 0 NOT NULL,
    "comment_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."community_posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_user_follows" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "follower_id" "uuid" NOT NULL,
    "following_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."community_user_follows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    "is_pinned" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "title" "text" NOT NULL,
    "dify_conversation_id" "text"
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_cost_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_name" "text" NOT NULL,
    "total_price" real NOT NULL,
    "purchase_date" "text" NOT NULL,
    "finish_date" "text",
    "pet_id" "uuid",
    "pet_name" "text",
    "image_path" "text",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."daily_cost_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_reminders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "pet_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "time" "text" NOT NULL,
    "task" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."daily_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deworming_reminders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "pet_name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "brand" "text",
    "last_date" "text" NOT NULL,
    "next_reminder_date" "text" NOT NULL,
    "frequency" "text" NOT NULL,
    "custom_days" integer,
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."deworming_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fitness_courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "duration_minutes" integer NOT NULL,
    "intensity" "text" NOT NULL,
    "pet_type" "text" NOT NULL,
    "calories_estimate" integer NOT NULL,
    "pet_calories_estimate" integer NOT NULL,
    "icon_emoji" "text" NOT NULL,
    "tags" "text"[] NOT NULL,
    "actions" "jsonb" NOT NULL,
    "is_active" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "fitness_courses_intensity_check" CHECK (("intensity" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "fitness_courses_pet_type_check" CHECK (("pet_type" = ANY (ARRAY['dog'::"text", 'cat'::"text"])))
);


ALTER TABLE "public"."fitness_courses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fitness_records" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "course_id" "text" NOT NULL,
    "course_name" "text" NOT NULL,
    "completed_at" timestamp with time zone NOT NULL,
    "duration_minutes" integer NOT NULL,
    "calories_burned" integer NOT NULL,
    "pet_calories_burned" integer NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fitness_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_plans" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "start_date" "text" NOT NULL,
    "end_date" "text" NOT NULL,
    "is_completed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invitation_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "is_lifetime" boolean DEFAULT true NOT NULL,
    "owner_id" "uuid",
    "used_by" "uuid",
    "used_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."invitation_codes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_records" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "text" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."medical_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medication_reminders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "pet_name" "text" NOT NULL,
    "med_name" "text" NOT NULL,
    "dosage" "text" NOT NULL,
    "frequency_type" "text" NOT NULL,
    "frequency_details" "text" NOT NULL,
    "start_date" "text" NOT NULL,
    "end_date" "text" NOT NULL,
    "notes" "text",
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."medication_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moderation_errors" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "scene" "text",
    "trace_id" "text" NOT NULL,
    "error_code" "text" NOT NULL,
    "error_message" "text" NOT NULL,
    "stack" "text",
    "context_json" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."moderation_errors" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."moderation_errors_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."moderation_errors_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."moderation_errors_id_seq" OWNED BY "public"."moderation_errors"."id";



CREATE TABLE IF NOT EXISTS "public"."moderation_logs" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "scene" "text" NOT NULL,
    "trace_id" "text" NOT NULL,
    "result" "text" NOT NULL,
    "risk_level" "text",
    "risk_labels" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "content_excerpt" "text",
    "resource_path" "text",
    "provider" "text",
    "provider_response" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."moderation_logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."moderation_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."moderation_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."moderation_logs_id_seq" OWNED BY "public"."moderation_logs"."id";



CREATE TABLE IF NOT EXISTS "public"."pet_diaries" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "original_text" "text" NOT NULL,
    "content" "text" NOT NULL,
    "style" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "pet_id" "uuid" NOT NULL,
    "ai_img" "text"
);


ALTER TABLE "public"."pet_diaries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_passport_achievements" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "passport_id" "uuid" NOT NULL,
    "achievement_id" "text" NOT NULL,
    "achievement_name" "text" NOT NULL,
    "achievement_description" "text" NOT NULL,
    "icon_name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "unlocked_at" "text" NOT NULL
);


ALTER TABLE "public"."pet_passport_achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_passports" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "photo_path" "text",
    "owner_name" "text",
    "adoption_date" "text",
    "mbti_type" "text",
    "mbti_description" "text",
    "interest_tags" "text",
    "bio" "text",
    "friend_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pet_passports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_reminders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "pet_name" "text",
    "event_type" "text",
    "due_date" "date" NOT NULL,
    "is_sent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pet_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pets" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "age" "text" NOT NULL,
    "gender" "text" NOT NULL,
    "breed" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "neuter_status" boolean,
    "weight" double precision,
    "avatar" "text",
    "birth_date" "date",
    "owner_nickname" "text",
    "use_custom_nickname" boolean DEFAULT false NOT NULL,
    "life_photo" "text"
);


ALTER TABLE "public"."pets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."test" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "quota" bigint DEFAULT '100000'::bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "remarks" "text"
);


ALTER TABLE "public"."test" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."unified_expenses" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "amount" real NOT NULL,
    "category" "text" NOT NULL,
    "expense_type" "text" NOT NULL,
    "date" "text" NOT NULL,
    "pet_id" "uuid",
    "pet_name" "text",
    "note" "text",
    "photo_path" "text",
    "item_name" "text",
    "estimated_end_date" "text",
    "item_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "unified_expenses_expense_type_check" CHECK (("expense_type" = ANY (ARRAY['one-off'::"text", 'recurring'::"text"]))),
    CONSTRAINT "unified_expenses_item_type_check" CHECK (("item_type" = ANY (ARRAY['consumable'::"text", 'durable'::"text"])))
);


ALTER TABLE "public"."unified_expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_content_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "feedback_type" "text" NOT NULL,
    "surface" "text" NOT NULL,
    "ref" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "reason_code" "text",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_content_feedback_feedback_type_check" CHECK (("feedback_type" = ANY (ARRAY['report'::"text", 'not_interested'::"text"]))),
    CONSTRAINT "user_content_feedback_surface_check" CHECK (("surface" = ANY (ARRAY['pet_diary'::"text", 'pet_diary_detail'::"text", 'ai_image'::"text", 'chat_ai'::"text"])))
);


ALTER TABLE "public"."user_content_feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "device_token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "last_active" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."user_devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users_profiles" (
    "id" "uuid" NOT NULL,
    "nickname" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "birthday" "date",
    "gender" "public"."gender",
    "membership_type" "text" DEFAULT 'free'::"text" NOT NULL,
    "owner_nickname" "text" DEFAULT '主人'::"text" NOT NULL,
    "birth_date" "date",
    "province" "text",
    "city" "text",
    "account_deletion_requested_at" timestamp with time zone,
    "account_deletion_effective_at" timestamp with time zone
);


ALTER TABLE "public"."users_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users_profiles"."birth_date" IS '用户出生日期';



COMMENT ON COLUMN "public"."users_profiles"."province" IS '用户所在省份';



COMMENT ON COLUMN "public"."users_profiles"."city" IS '用户所在城市';



COMMENT ON COLUMN "public"."users_profiles"."account_deletion_requested_at" IS '用户提交「预约注销」的时间；与 account_deletion_effective_at 同时非空表示冷静期中';



COMMENT ON COLUMN "public"."users_profiles"."account_deletion_effective_at" IS '计划永久删除账号的 UTC 时间；未到期前用户重新登录应清空两列以撤回';



CREATE TABLE IF NOT EXISTS "public"."vaccine_records" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "text" NOT NULL,
    "type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "next_due_date" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vaccine_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vaccine_reminders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "pet_name" "text" NOT NULL,
    "vaccine_name" "text" NOT NULL,
    "injection_date" "text" NOT NULL,
    "dose_type" "text" NOT NULL,
    "next_due_date" "text",
    "notes" "text",
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vaccine_reminders" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."vw_ai_image_presets" WITH ("security_invoker"='off') AS
 SELECT "id",
    "name",
    "aspect_ratio",
    "created_at"
   FROM "public"."ai_image_presets";


ALTER VIEW "public"."vw_ai_image_presets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."weight_records" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "text" NOT NULL,
    "weight" real NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."weight_records" OWNER TO "postgres";


ALTER TABLE ONLY "public"."moderation_errors" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."moderation_errors_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."moderation_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."moderation_logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."account_auth_delete_retry_queue"
    ADD CONSTRAINT "account_auth_delete_retry_queue_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."ai_image_presets"
    ADD CONSTRAINT "ai_image_presets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ai_usage"
    ADD CONSTRAINT "ai_usage_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_event_definitions"
    ADD CONSTRAINT "analytics_event_definitions_pkey" PRIMARY KEY ("event_name");



ALTER TABLE ONLY "public"."analytics_events"
    ADD CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id", "user_id");



ALTER TABLE ONLY "public"."community_post_collections"
    ADD CONSTRAINT "community_post_collections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_post_comments"
    ADD CONSTRAINT "community_post_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_post_likes"
    ADD CONSTRAINT "community_post_likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_posts"
    ADD CONSTRAINT "community_posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_user_follows"
    ADD CONSTRAINT "community_user_follows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_cost_items"
    ADD CONSTRAINT "daily_cost_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_reminders"
    ADD CONSTRAINT "daily_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deworming_reminders"
    ADD CONSTRAINT "deworming_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fitness_courses"
    ADD CONSTRAINT "fitness_courses_course_id_key" UNIQUE ("course_id");



ALTER TABLE ONLY "public"."fitness_courses"
    ADD CONSTRAINT "fitness_courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fitness_records"
    ADD CONSTRAINT "fitness_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_plans"
    ADD CONSTRAINT "health_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invitation_codes"
    ADD CONSTRAINT "invitation_codes_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."invitation_codes"
    ADD CONSTRAINT "invitation_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_records"
    ADD CONSTRAINT "medical_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medication_reminders"
    ADD CONSTRAINT "medication_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_errors"
    ADD CONSTRAINT "moderation_errors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_logs"
    ADD CONSTRAINT "moderation_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_diaries"
    ADD CONSTRAINT "pet_diaries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_passport_achievements"
    ADD CONSTRAINT "pet_passport_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_passports"
    ADD CONSTRAINT "pet_passports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_reminders"
    ADD CONSTRAINT "pet_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."test"
    ADD CONSTRAINT "test_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."unified_expenses"
    ADD CONSTRAINT "unified_expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_content_feedback"
    ADD CONSTRAINT "user_content_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users_profiles"
    ADD CONSTRAINT "users_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vaccine_records"
    ADD CONSTRAINT "vaccine_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vaccine_reminders"
    ADD CONSTRAINT "vaccine_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."weight_records"
    ADD CONSTRAINT "weight_records_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "idx_analytics_events_client_event_id" ON "public"."analytics_events" USING "btree" ("client_event_id");



CREATE INDEX "idx_analytics_events_event_time" ON "public"."analytics_events" USING "btree" ("event_name", "occurred_at" DESC);



CREATE INDEX "idx_analytics_events_module_time" ON "public"."analytics_events" USING "btree" ("module", "occurred_at" DESC) WHERE ("module" IS NOT NULL);



CREATE INDEX "idx_analytics_events_occurred_at" ON "public"."analytics_events" USING "btree" ("occurred_at" DESC);



CREATE INDEX "idx_analytics_events_page_time" ON "public"."analytics_events" USING "btree" ("page_name", "occurred_at" DESC) WHERE ("page_name" IS NOT NULL);



CREATE INDEX "idx_analytics_events_platform_time" ON "public"."analytics_events" USING "btree" ("platform", "occurred_at" DESC);



CREATE INDEX "idx_analytics_events_user_time" ON "public"."analytics_events" USING "btree" ("user_id", "occurred_at" DESC) WHERE ("user_id" IS NOT NULL);



CREATE INDEX "idx_moderation_errors_created_at" ON "public"."moderation_errors" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_moderation_errors_trace_id" ON "public"."moderation_errors" USING "btree" ("trace_id");



CREATE INDEX "idx_moderation_errors_user_id" ON "public"."moderation_errors" USING "btree" ("user_id");



CREATE INDEX "idx_moderation_logs_created_at" ON "public"."moderation_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_moderation_logs_trace_id" ON "public"."moderation_logs" USING "btree" ("trace_id");



CREATE INDEX "idx_moderation_logs_user_id" ON "public"."moderation_logs" USING "btree" ("user_id");



CREATE INDEX "idx_user_content_feedback_surface_created" ON "public"."user_content_feedback" USING "btree" ("surface", "created_at" DESC);



CREATE INDEX "idx_user_content_feedback_user_created" ON "public"."user_content_feedback" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_users_profiles_account_deletion_due" ON "public"."users_profiles" USING "btree" ("account_deletion_effective_at") WHERE ("account_deletion_effective_at" IS NOT NULL);



ALTER TABLE ONLY "public"."account_auth_delete_retry_queue"
    ADD CONSTRAINT "account_auth_delete_retry_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_passport_id_fkey" FOREIGN KEY ("passport_id") REFERENCES "public"."pet_passports"("id");



ALTER TABLE ONLY "public"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_usage"
    ADD CONSTRAINT "ai_usage_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."analytics_events"
    ADD CONSTRAINT "analytics_events_event_name_fkey" FOREIGN KEY ("event_name") REFERENCES "public"."analytics_event_definitions"("event_name");



ALTER TABLE ONLY "public"."analytics_events"
    ADD CONSTRAINT "analytics_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id");



ALTER TABLE ONLY "public"."community_post_collections"
    ADD CONSTRAINT "community_post_collections_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."community_posts"("id");



ALTER TABLE ONLY "public"."community_post_collections"
    ADD CONSTRAINT "community_post_collections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_post_comments"
    ADD CONSTRAINT "community_post_comments_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."community_post_comments"("id");



ALTER TABLE ONLY "public"."community_post_comments"
    ADD CONSTRAINT "community_post_comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."community_posts"("id");



ALTER TABLE ONLY "public"."community_post_comments"
    ADD CONSTRAINT "community_post_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_post_likes"
    ADD CONSTRAINT "community_post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."community_posts"("id");



ALTER TABLE ONLY "public"."community_post_likes"
    ADD CONSTRAINT "community_post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_posts"
    ADD CONSTRAINT "community_posts_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_user_follows"
    ADD CONSTRAINT "community_user_follows_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_user_follows"
    ADD CONSTRAINT "community_user_follows_following_id_fkey" FOREIGN KEY ("following_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."daily_cost_items"
    ADD CONSTRAINT "daily_cost_items_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."daily_cost_items"
    ADD CONSTRAINT "daily_cost_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."daily_reminders"
    ADD CONSTRAINT "daily_reminders_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."daily_reminders"
    ADD CONSTRAINT "daily_reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."deworming_reminders"
    ADD CONSTRAINT "deworming_reminders_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."deworming_reminders"
    ADD CONSTRAINT "deworming_reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."fitness_records"
    ADD CONSTRAINT "fitness_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."health_plans"
    ADD CONSTRAINT "health_plans_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."health_plans"
    ADD CONSTRAINT "health_plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."invitation_codes"
    ADD CONSTRAINT "invitation_codes_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."invitation_codes"
    ADD CONSTRAINT "invitation_codes_used_by_fkey" FOREIGN KEY ("used_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."medical_records"
    ADD CONSTRAINT "medical_records_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."medical_records"
    ADD CONSTRAINT "medical_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."medication_reminders"
    ADD CONSTRAINT "medication_reminders_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."medication_reminders"
    ADD CONSTRAINT "medication_reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."pet_diaries"
    ADD CONSTRAINT "pet_diaries_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_diaries"
    ADD CONSTRAINT "pet_diaries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."pet_passport_achievements"
    ADD CONSTRAINT "pet_passport_achievements_passport_id_fkey" FOREIGN KEY ("passport_id") REFERENCES "public"."pet_passports"("id");



ALTER TABLE ONLY "public"."pet_passports"
    ADD CONSTRAINT "pet_passports_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."pet_passports"
    ADD CONSTRAINT "pet_passports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."unified_expenses"
    ADD CONSTRAINT "unified_expenses_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."unified_expenses"
    ADD CONSTRAINT "unified_expenses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."user_content_feedback"
    ADD CONSTRAINT "user_content_feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users_profiles"
    ADD CONSTRAINT "users_profiles_id_fkey_auth_users_cascade" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vaccine_records"
    ADD CONSTRAINT "vaccine_records_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."vaccine_records"
    ADD CONSTRAINT "vaccine_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."vaccine_reminders"
    ADD CONSTRAINT "vaccine_reminders_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."vaccine_reminders"
    ADD CONSTRAINT "vaccine_reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE ONLY "public"."weight_records"
    ADD CONSTRAINT "weight_records_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id");



ALTER TABLE ONLY "public"."weight_records"
    ADD CONSTRAINT "weight_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users_profiles"("id");



ALTER TABLE "public"."account_auth_delete_retry_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ai_image_presets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ai_usage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."analytics_event_definitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."analytics_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chat_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "chat_messages_insert_own_v1" ON "public"."chat_messages" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "chat_messages_select_own_v1" ON "public"."chat_messages" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "chat_messages_update_own_v1" ON "public"."chat_messages" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."community_post_collections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_post_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_post_likes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_user_follows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_insert_own_v1" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "conversations_select_own_v1" ON "public"."conversations" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "conversations_update_own_v1" ON "public"."conversations" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."daily_cost_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_reminders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_reminders_delete_own_v1" ON "public"."daily_reminders" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "daily_reminders_insert_own_v1" ON "public"."daily_reminders" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "daily_reminders_select_own_v1" ON "public"."daily_reminders" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "daily_reminders_update_own_v1" ON "public"."daily_reminders" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



ALTER TABLE "public"."deworming_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fitness_courses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fitness_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."health_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invitation_codes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "manage_own_diaries" ON "public"."pet_diaries" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."medical_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "medical_records_delete_own_v1" ON "public"."medical_records" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "medical_records_insert_own_v1" ON "public"."medical_records" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "medical_records_select_own_v1" ON "public"."medical_records" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "medical_records_update_own_v1" ON "public"."medical_records" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



ALTER TABLE "public"."medication_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_errors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "moderation_errors_insert_own_v1" ON "public"."moderation_errors" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "moderation_errors_select_own_v1" ON "public"."moderation_errors" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "moderation_errors_update_own_v1" ON "public"."moderation_errors" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."moderation_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "moderation_logs_insert_own_v1" ON "public"."moderation_logs" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "moderation_logs_select_own_v1" ON "public"."moderation_logs" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "moderation_logs_update_own_v1" ON "public"."moderation_logs" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."pet_diaries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_passport_achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_passports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pets_delete_own_v1" ON "public"."pets" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "pets_insert_own_v1" ON "public"."pets" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "pets_select_own_v1" ON "public"."pets" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "pets_update_own_v1" ON "public"."pets" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



ALTER TABLE "public"."test" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."unified_expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_content_feedback" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_content_feedback_insert_own" ON "public"."user_content_feedback" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "user_content_feedback_select_own" ON "public"."user_content_feedback" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."user_devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_profiles_delete_own_v1" ON "public"."users_profiles" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "users_profiles_insert_own_v1" ON "public"."users_profiles" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "users_profiles_select_own_v1" ON "public"."users_profiles" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "users_profiles_update_own_v1" ON "public"."users_profiles" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("id")::"text" = ("auth"."uid"())::"text")));



ALTER TABLE "public"."vaccine_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vaccine_records_delete_own_v1" ON "public"."vaccine_records" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "vaccine_records_insert_own_v1" ON "public"."vaccine_records" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "vaccine_records_select_own_v1" ON "public"."vaccine_records" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "vaccine_records_update_own_v1" ON "public"."vaccine_records" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



ALTER TABLE "public"."vaccine_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."weight_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "weight_records_delete_own_v1" ON "public"."weight_records" FOR DELETE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "weight_records_insert_own_v1" ON "public"."weight_records" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "weight_records_select_own_v1" ON "public"."weight_records" FOR SELECT TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



CREATE POLICY "weight_records_update_own_v1" ON "public"."weight_records" FOR UPDATE TO "authenticated" USING ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text"))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (("user_id")::"text" = ("auth"."uid"())::"text")));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pet_for_diary"("p_pet_id" "uuid", "p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_user_business_data"("p_target_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_user_business_data"("p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."account_auth_delete_retry_queue" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."account_auth_delete_retry_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."account_auth_delete_retry_queue" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."achievements" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."achievements" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."achievements" TO "service_role";



GRANT ALL ON TABLE "public"."admin_users" TO "service_role";



GRANT ALL ON TABLE "public"."ai_image_presets" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."ai_usage" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."ai_usage" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."ai_usage" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_event_definitions" TO "service_role";



GRANT ALL ON TABLE "public"."analytics_events" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."chat_messages" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."chat_messages" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."chat_messages" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_collections" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_collections" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_collections" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_comments" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_comments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_comments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_likes" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_likes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_post_likes" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_posts" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_posts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_posts" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_user_follows" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_user_follows" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_user_follows" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."conversations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."conversations" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."conversations" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."daily_cost_items" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."daily_cost_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."daily_cost_items" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."daily_reminders" TO "anon";
GRANT ALL ON TABLE "public"."daily_reminders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."daily_reminders" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."deworming_reminders" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."deworming_reminders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."deworming_reminders" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_courses" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_courses" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_courses" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_records" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_records" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fitness_records" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."health_plans" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."health_plans" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."health_plans" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invitation_codes" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invitation_codes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invitation_codes" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_records" TO "anon";
GRANT ALL ON TABLE "public"."medical_records" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_records" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medication_reminders" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medication_reminders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medication_reminders" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."moderation_errors" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."moderation_errors" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."moderation_errors" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."moderation_errors_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."moderation_errors_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."moderation_errors_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."moderation_logs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."moderation_logs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."moderation_logs" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."moderation_logs_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."moderation_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."moderation_logs_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_diaries" TO "anon";
GRANT ALL ON TABLE "public"."pet_diaries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_diaries" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passport_achievements" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passport_achievements" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passport_achievements" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passports" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passports" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_passports" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_reminders" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_reminders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pet_reminders" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pets" TO "anon";
GRANT ALL ON TABLE "public"."pets" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pets" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."test" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."test" TO "authenticated";
GRANT ALL ON TABLE "public"."test" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."unified_expenses" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."unified_expenses" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."unified_expenses" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_content_feedback" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_content_feedback" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_devices" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_devices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."user_devices" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."users_profiles" TO "anon";
GRANT ALL ON TABLE "public"."users_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."users_profiles" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_records" TO "anon";
GRANT ALL ON TABLE "public"."vaccine_records" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_records" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_reminders" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_reminders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_reminders" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vw_ai_image_presets" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vw_ai_image_presets" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vw_ai_image_presets" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."weight_records" TO "anon";
GRANT ALL ON TABLE "public"."weight_records" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."weight_records" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";







