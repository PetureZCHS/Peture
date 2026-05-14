-- Self-hosted analytics events and dashboard access control.

CREATE TABLE IF NOT EXISTS public.analytics_event_definitions (
  event_name text PRIMARY KEY,
  module text NOT NULL,
  description text NOT NULL DEFAULT '',
  enabled boolean NOT NULL DEFAULT true,
  allowed_properties jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT analytics_event_definitions_name_length
    CHECK (char_length(event_name) BETWEEN 1 AND 80),
  CONSTRAINT analytics_event_definitions_props_array
    CHECK (jsonb_typeof(allowed_properties) = 'array')
);

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  anonymous_id text,
  session_id uuid NOT NULL,
  event_name text NOT NULL REFERENCES public.analytics_event_definitions(event_name),
  page_name text,
  module text,
  platform text NOT NULL,
  app_version text NOT NULL,
  device_locale text,
  occurred_at timestamptz NOT NULL,
  duration_ms integer,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT analytics_events_name_length
    CHECK (char_length(event_name) BETWEEN 1 AND 80),
  CONSTRAINT analytics_events_platform_length
    CHECK (char_length(platform) BETWEEN 1 AND 32),
  CONSTRAINT analytics_events_duration_non_negative
    CHECK (duration_ms IS NULL OR duration_ms >= 0),
  CONSTRAINT analytics_events_properties_object
    CHECK (jsonb_typeof(properties) = 'object')
);

CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'analytics_admin',
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admin_users_role_allowed
    CHECK (role IN ('analytics_admin', 'owner'))
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_occurred_at
  ON public.analytics_events (occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_time
  ON public.analytics_events (event_name, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_module_time
  ON public.analytics_events (module, occurred_at DESC)
  WHERE module IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_platform_time
  ON public.analytics_events (platform, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_page_time
  ON public.analytics_events (page_name, occurred_at DESC)
  WHERE page_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_time
  ON public.analytics_events (user_id, occurred_at DESC)
  WHERE user_id IS NOT NULL;

ALTER TABLE public.analytics_event_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.analytics_event_definitions FROM anon, authenticated;
REVOKE ALL ON public.analytics_events FROM anon, authenticated;
REVOKE ALL ON public.admin_users FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.analytics_event_definitions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.analytics_events TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_users TO service_role;

INSERT INTO public.analytics_event_definitions
  (event_name, module, description, allowed_properties)
VALUES
  ('app_open', 'app', 'App opened or resumed.', '["source"]'),
  ('page_view', 'navigation', 'Page became visible.', '["source","route"]'),
  ('page_leave', 'navigation', 'Page became hidden.', '["source","route"]'),
  ('button_click', 'interaction', 'Generic button click.', '["button_id","entry_page","source"]'),
  ('feature_entry', 'interaction', 'User entered a feature.', '["feature","entry_page","source"]'),
  ('form_submit', 'interaction', 'Form submit attempt.', '["form_id","success","error_code"]'),
  ('ai_chat_start', 'ai_chat', 'AI chat request started.', '["entry_page","pet_id"]'),
  ('ai_chat_success', 'ai_chat', 'AI chat request succeeded.', '["entry_page","duration_ms"]'),
  ('ai_chat_error', 'ai_chat', 'AI chat request failed.', '["entry_page","error_code","duration_ms"]'),
  ('diary_generate_start', 'diary', 'Diary generation started.', '["entry_page","style","pet_type"]'),
  ('diary_generate_success', 'diary', 'Diary generation succeeded.', '["entry_page","style","duration_ms"]'),
  ('diary_generate_error', 'diary', 'Diary generation failed.', '["entry_page","style","error_code","duration_ms"]'),
  ('image_generate_start', 'ai_image', 'AI image generation started.', '["entry_page","style","aspect_ratio"]'),
  ('image_generate_success', 'ai_image', 'AI image generation succeeded.', '["entry_page","style","duration_ms"]'),
  ('image_generate_error', 'ai_image', 'AI image generation failed.', '["entry_page","style","error_code","duration_ms"]'),
  ('expense_created', 'expense', 'Expense record created.', '["entry_page","category","amount_bucket"]'),
  ('pet_profile_created', 'pet_profile', 'Pet profile created.', '["entry_page","pet_type"]'),
  ('share_card_click', 'diary', 'Diary share card clicked.', '["card_id","card_style","diary_id","diary_style","entry_page"]'),
  ('error_event', 'error', 'Client-visible error occurred.', '["entry_page","error_code","operation"]')
ON CONFLICT (event_name) DO UPDATE SET
  module = EXCLUDED.module,
  description = EXCLUDED.description,
  allowed_properties = EXCLUDED.allowed_properties,
  enabled = true,
  updated_at = now();
