-- 即时注销：purge 成功但 auth.admin.deleteUser 失败时入队，供 Cron 仅重试删除 Auth。
-- 外键 ON DELETE CASCADE：deleteUser 成功后队列行随 auth.users 一并消失。

CREATE TABLE IF NOT EXISTS public.account_auth_delete_retry_queue (
  user_id uuid NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  enqueued_at timestamptz NOT NULL DEFAULT now(),
  last_error text
);

COMMENT ON TABLE public.account_auth_delete_retry_queue IS
  'Auth 删除失败补偿队列；业务数据已由 purge_user_business_data 清空，仅需重试 deleteUser。';

ALTER TABLE public.account_auth_delete_retry_queue ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.account_auth_delete_retry_queue FROM PUBLIC;
GRANT ALL ON TABLE public.account_auth_delete_retry_queue TO service_role;
