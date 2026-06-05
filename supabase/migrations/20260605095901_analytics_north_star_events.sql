-- Add event definitions used by north-star analytics metrics.

INSERT INTO public.analytics_event_definitions
  (event_name, module, description, allowed_properties)
VALUES
  (
    'pet_record_value_created',
    'north_star',
    'A user completed a valuable pet record action.',
    '["entry_page","source_event","pet_id","record_type"]'
  ),
  (
    'pet_profile_active',
    'pet_profile',
    'A pet profile was created, viewed, updated, or otherwise active.',
    '["entry_page","pet_id","activity_type"]'
  ),
  (
    'pet_memory_saved',
    'diary',
    'A generated pet memory was saved or exported by the user.',
    '["entry_page","pet_id","memory_type","source_event"]'
  )
ON CONFLICT (event_name) DO UPDATE SET
  module = EXCLUDED.module,
  description = EXCLUDED.description,
  allowed_properties = EXCLUDED.allowed_properties,
  enabled = true,
  updated_at = now();
