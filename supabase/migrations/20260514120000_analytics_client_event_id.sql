-- Add client-side event identity for idempotent analytics ingestion.

ALTER TABLE public.analytics_events
  ADD COLUMN IF NOT EXISTS client_event_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS idx_analytics_events_client_event_id
  ON public.analytics_events (client_event_id);

COMMENT ON COLUMN public.analytics_events.client_event_id IS
  'Client-generated UUID used by analytics-collect to deduplicate retries.';
