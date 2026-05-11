CREATE TABLE IF NOT EXISTS public.moderation_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trace_id uuid NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  scene text,
  error_code text NOT NULL,
  error_message text NOT NULL,
  stack text,
  context_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_moderation_errors_trace_id
  ON public.moderation_errors(trace_id);

CREATE INDEX IF NOT EXISTS idx_moderation_errors_created
  ON public.moderation_errors(created_at DESC);

