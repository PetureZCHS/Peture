-- 邀请码表：一人一码，8 位数字
CREATE TABLE IF NOT EXISTS public.invitation_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  is_lifetime boolean NOT NULL DEFAULT true,
  owner_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  used_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS invitation_codes_owner_id_key
  ON public.invitation_codes (owner_id) WHERE owner_id IS NOT NULL;

ALTER TABLE public.invitation_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "invitation_codes_server_only" ON public.invitation_codes FOR ALL USING (false) WITH CHECK (false);

ALTER TABLE public.users_profiles
  ADD COLUMN IF NOT EXISTS membership_type text NOT NULL DEFAULT 'free';
