CREATE TABLE IF NOT EXISTS public.moderation_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  scene text NOT NULL,
  result text NOT NULL CHECK (result IN ('pass', 'block', 'review')),
  risk_level text NOT NULL DEFAULT 'unknown',
  risk_labels text[] NOT NULL DEFAULT '{}',
  content_excerpt text,
  resource_path text,
  provider text NOT NULL DEFAULT 'local_fallback',
  provider_response jsonb,
  trace_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_moderation_logs_user_created
  ON public.moderation_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_moderation_logs_scene_created
  ON public.moderation_logs(scene, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_moderation_logs_created
  ON public.moderation_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_moderation_logs_trace_id
  ON public.moderation_logs(trace_id);

