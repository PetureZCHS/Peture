import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

const MAX_BATCH_SIZE = 50;
const MAX_EVENT_NAME_LENGTH = 80;
const MAX_TEXT_LENGTH = 240;
const MAX_PROPERTIES_BYTES = 4096;
const ANONYMOUS_EVENT_NAMES = new Set([
  "app_open",
  "page_view",
  "page_leave",
  "button_click",
  "feature_entry",
]);

const SENSITIVE_KEY_PATTERN =
  /(password|passwd|pwd|token|secret|authorization|phone|mobile|email|mail|address|location|lat|lng|longitude|latitude|content|message|prompt|answer|text|image|url|avatar|photo)/i;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders(),
  });
}

function trimText(value: unknown, maxLength = MAX_TEXT_LENGTH): string | null {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  if (!text) return null;
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

function sanitizeProperties(value: unknown, depth = 0): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || depth > 2) {
    return {};
  }

  const result: Record<string, unknown> = {};
  for (const [rawKey, rawValue] of Object.entries(value as Record<string, unknown>)) {
    const key = rawKey.trim().slice(0, 64);
    if (!key || SENSITIVE_KEY_PATTERN.test(key)) continue;

    if (rawValue === null || rawValue === undefined) {
      result[key] = null;
    } else if (typeof rawValue === "number" || typeof rawValue === "boolean") {
      result[key] = rawValue;
    } else if (typeof rawValue === "string") {
      const text = trimText(rawValue);
      if (text !== null) result[key] = text;
    } else if (Array.isArray(rawValue)) {
      result[key] = rawValue
        .slice(0, 20)
        .map((item) => {
          if (typeof item === "number" || typeof item === "boolean") return item;
          return trimText(item, 80);
        })
        .filter((item) => item !== null);
    } else if (typeof rawValue === "object") {
      const nested = sanitizeProperties(rawValue, depth + 1);
      if (Object.keys(nested).length > 0) result[key] = nested;
    }
  }

  const encoded = new TextEncoder().encode(JSON.stringify(result));
  if (encoded.byteLength <= MAX_PROPERTIES_BYTES) return result;
  return { truncated: true };
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function parseDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

async function resolveUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : authHeader;
  if (!token) return null;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const authClient = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const payload = body as Record<string, unknown>;
  const events = Array.isArray(payload.events) ? payload.events : [];
  if (events.length === 0 || events.length > MAX_BATCH_SIZE) {
    return jsonResponse({
      error: `events must contain 1-${MAX_BATCH_SIZE} items`,
    }, 400);
  }

  const userId = await resolveUserId(req);
  const anonymousId = trimText(payload.anonymous_id, 128);
  const supabase = createServiceRoleClient();
  const definitions = await supabase
    .from("analytics_event_definitions")
    .select("event_name, module, enabled");

  if (definitions.error) {
    console.error("[analytics-collect] definitions error", definitions.error);
    return jsonResponse({ error: "Failed to load event definitions" }, 500);
  }

  const enabledEvents = new Map<string, string>();
  for (const row of definitions.data ?? []) {
    if (row.enabled) enabledEvents.set(row.event_name, row.module);
  }

  const accepted: Record<string, unknown>[] = [];
  const rejected: { index: number; reason: string }[] = [];

  events.forEach((event, index) => {
    if (!event || typeof event !== "object") {
      rejected.push({ index, reason: "event must be an object" });
      return;
    }
    const record = event as Record<string, unknown>;
    const eventName = trimText(record.event_name, MAX_EVENT_NAME_LENGTH);
    if (!eventName || !enabledEvents.has(eventName)) {
      rejected.push({ index, reason: "event_name is disabled or unknown" });
      return;
    }
    if (!userId && !ANONYMOUS_EVENT_NAMES.has(eventName)) {
      rejected.push({ index, reason: "anonymous event_name is not allowed" });
      return;
    }

    const sessionId = record.session_id ?? payload.session_id;
    if (!isUuid(sessionId)) {
      rejected.push({ index, reason: "session_id must be uuid" });
      return;
    }

    const occurredAt = parseDate(record.occurred_at);
    if (!occurredAt) {
      rejected.push({ index, reason: "occurred_at is invalid" });
      return;
    }

    const duration = Number(record.duration_ms);
    accepted.push({
      user_id: userId,
      anonymous_id: anonymousId,
      session_id: sessionId,
      event_name: eventName,
      page_name: trimText(record.page_name, 120),
      module: trimText(record.module, 80) ?? enabledEvents.get(eventName),
      platform: trimText(record.platform, 32) ?? "unknown",
      app_version: trimText(record.app_version, 80) ?? "unknown",
      device_locale: trimText(record.device_locale, 32),
      occurred_at: occurredAt,
      duration_ms: Number.isFinite(duration) && duration >= 0
        ? Math.round(duration)
        : null,
      properties: sanitizeProperties(record.properties),
    });
  });

  if (accepted.length > 0) {
    const { error } = await supabase.from("analytics_events").insert(accepted);
    if (error) {
      console.error("[analytics-collect] insert error", error);
      return jsonResponse({ error: "Failed to insert analytics events" }, 500);
    }
  }

  return jsonResponse({
    accepted_count: accepted.length,
    rejected_count: rejected.length,
    rejected,
  });
});
