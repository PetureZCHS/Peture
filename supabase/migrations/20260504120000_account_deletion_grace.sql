-- 账号注销 15 天冷静期：仅写入计划删除时间，到期由 Edge（service_role）执行硬删

ALTER TABLE public.users_profiles
  ADD COLUMN IF NOT EXISTS account_deletion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS account_deletion_effective_at timestamptz;

COMMENT ON COLUMN public.users_profiles.account_deletion_requested_at IS
  '用户提交「预约注销」的时间；与 account_deletion_effective_at 同时非空表示冷静期中';
COMMENT ON COLUMN public.users_profiles.account_deletion_effective_at IS
  '计划永久删除账号的 UTC 时间；未到期前用户重新登录应清空两列以撤回';

CREATE INDEX IF NOT EXISTS idx_users_profiles_account_deletion_due
  ON public.users_profiles (account_deletion_effective_at)
  WHERE account_deletion_effective_at IS NOT NULL;
