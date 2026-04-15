CREATE OR REPLACE FUNCTION public.detect_simple_sensitive_text(input_text text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
  IF input_text IS NULL OR btrim(input_text) = '' THEN
    RETURN false;
  END IF;
  IF input_text ~* '(颠覆|暴乱|恐怖组织|极端组织|反动|虐杀|碎尸|血腥|爆头|屠杀|裸体|强奸|幼交|淫秽)' THEN
    RETURN true;
  END IF;
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_sensitive_text_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  field_value text;
BEGIN
  field_value := TG_ARGV[0]::text;
  IF field_value = 'nickname' THEN
    IF public.detect_simple_sensitive_text(NEW.nickname) THEN
      RAISE EXCEPTION 'MODERATION_BLOCKED: nickname contains sensitive text';
    END IF;
  ELSIF field_value = 'owner_nickname' THEN
    IF public.detect_simple_sensitive_text(NEW.owner_nickname) THEN
      RAISE EXCEPTION 'MODERATION_BLOCKED: owner_nickname contains sensitive text';
    END IF;
  ELSIF field_value = 'name' THEN
    IF public.detect_simple_sensitive_text(NEW.name) THEN
      RAISE EXCEPTION 'MODERATION_BLOCKED: name contains sensitive text';
    END IF;
  ELSIF field_value = 'content' THEN
    IF public.detect_simple_sensitive_text(NEW.content) THEN
      RAISE EXCEPTION 'MODERATION_BLOCKED: content contains sensitive text';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_users_profiles_nickname ON public.users_profiles;
CREATE TRIGGER trg_guard_users_profiles_nickname
BEFORE INSERT OR UPDATE OF nickname ON public.users_profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_sensitive_text_guard('nickname');

DROP TRIGGER IF EXISTS trg_guard_users_profiles_owner_nickname ON public.users_profiles;
CREATE TRIGGER trg_guard_users_profiles_owner_nickname
BEFORE INSERT OR UPDATE OF owner_nickname ON public.users_profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_sensitive_text_guard('owner_nickname');

DROP TRIGGER IF EXISTS trg_guard_pets_name ON public.pets;
CREATE TRIGGER trg_guard_pets_name
BEFORE INSERT OR UPDATE OF name ON public.pets
FOR EACH ROW
EXECUTE FUNCTION public.enforce_sensitive_text_guard('name');

DROP TRIGGER IF EXISTS trg_guard_pets_owner_nickname ON public.pets;
CREATE TRIGGER trg_guard_pets_owner_nickname
BEFORE INSERT OR UPDATE OF owner_nickname ON public.pets
FOR EACH ROW
EXECUTE FUNCTION public.enforce_sensitive_text_guard('owner_nickname');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'pet_diaries'
      AND column_name = 'content'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_guard_pet_diaries_content ON public.pet_diaries';
    EXECUTE 'CREATE TRIGGER trg_guard_pet_diaries_content
      BEFORE INSERT OR UPDATE OF content ON public.pet_diaries
      FOR EACH ROW
      EXECUTE FUNCTION public.enforce_sensitive_text_guard(''content'')';
  END IF;
END $$;

