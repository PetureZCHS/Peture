-- Cleanup helper for moderation temporary buckets.
-- Can be scheduled by pg_cron in environments where cron is enabled.

CREATE OR REPLACE FUNCTION public.cleanup_moderation_temp_objects(hours_threshold integer DEFAULT 24)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count integer := 0;
BEGIN
  DELETE FROM storage.objects
  WHERE bucket_id IN ('avatars-temp', 'ai-images-temp')
    AND created_at < (now() - make_interval(hours => hours_threshold));

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'cleanup_moderation_temp_objects_daily',
      '0 * * * *',
      $$SELECT public.cleanup_moderation_temp_objects(24);$$
    );
  END IF;
END $$;

