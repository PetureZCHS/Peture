import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

type AnalyticsEvent = {
  user_id: string | null;
  anonymous_id: string | null;
  session_id: string;
  event_name: string;
  page_name: string | null;
  module: string | null;
  platform: string;
  occurred_at: string;
  duration_ms: number | null;
  properties: Record<string, unknown>;
};

const MAX_CUSTOM_RANGE_DAYS = 90;
const MAX_ROWS = 50000;
const PAGE_SIZE = 1000;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

const VALUE_RECORD_EVENTS = new Set([
  "diary_generate_success",
  "expense_created",
  "image_generate_success",
  "pet_memory_saved",
  "pet_profile_created",
  "pet_record_value_created",
  "share_card_click",
]);

const LEGACY_MEMORY_EVENTS = new Set([
  "diary_generate_success",
  "image_generate_success",
  "share_card_click",
]);

const PET_PROFILE_ACTIVITY_EVENTS = new Set([
  "pet_profile_active",
  "pet_profile_created",
]);

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

function startOfToday() {
  const date = new Date();
  date.setUTCHours(0, 0, 0, 0);
  return date;
}

function resolveRange(body: Record<string, unknown>) {
  const now = new Date();
  const range = String(body.range ?? "7d");
  let start: Date;
  let end = now;

  if (range === "today") {
    start = startOfToday();
  } else if (range === "30d") {
    start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  } else if (range === "custom") {
    start = new Date(String(body.start_at ?? ""));
    end = new Date(String(body.end_at ?? now.toISOString()));
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new Error("Invalid custom date range");
    }
    const days = (end.getTime() - start.getTime()) / 86400000;
    if (days < 0 || days > MAX_CUSTOM_RANGE_DAYS) {
      throw new Error(`Custom range must be 0-${MAX_CUSTOM_RANGE_DAYS} days`);
    }
  } else {
    start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  }

  return {
    range,
    startAt: start.toISOString(),
    endAt: end.toISOString(),
  };
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

function userKey(event: AnalyticsEvent) {
  return event.user_id ?? event.anonymous_id ?? event.session_id;
}

function propertyText(event: AnalyticsEvent, key: string) {
  const value = event.properties?.[key];
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 ? text : null;
}

function inc(map: Map<string, number>, key: string, amount = 1) {
  map.set(key, (map.get(key) ?? 0) + amount);
}

function topRows<T extends Record<string, unknown>>(
  rows: T[],
  sortKey: keyof T,
  limit = 20,
) {
  return rows
    .sort((a, b) => Number(b[sortKey] ?? 0) - Number(a[sortKey] ?? 0))
    .slice(0, limit);
}

async function loadEvents(
  supabase: ReturnType<typeof createServiceRoleClient>,
  range: { startAt: string; endAt: string },
  filters: Record<string, unknown>,
): Promise<AnalyticsEvent[]> {
  const rows: AnalyticsEvent[] = [];
  for (let from = 0; from < MAX_ROWS; from += PAGE_SIZE) {
    let query = supabase
      .from("analytics_events")
      .select(
        "user_id, anonymous_id, session_id, event_name, page_name, module, platform, occurred_at, duration_ms, properties",
      )
      .gte("occurred_at", range.startAt)
      .lte("occurred_at", range.endAt)
      .order("occurred_at", { ascending: false })
      .range(from, from + PAGE_SIZE - 1);

    if (typeof filters.platform === "string" && filters.platform !== "all") {
      query = query.eq("platform", filters.platform);
    }
    if (typeof filters.module === "string" && filters.module !== "all") {
      query = query.eq("module", filters.module);
    }
    if (typeof filters.event_name === "string" && filters.event_name !== "all") {
      query = query.eq("event_name", filters.event_name);
    }

    const { data, error } = await query;
    if (error) throw error;
    rows.push(...((data ?? []) as AnalyticsEvent[]));
    if (!data || data.length < PAGE_SIZE) break;
  }
  return rows;
}

function overview(events: AnalyticsEvent[]) {
  const users = new Set<string>();
  const sessions = new Set<string>();
  const byDay = new Map<string, Set<string>>();
  let durationSum = 0;
  let durationCount = 0;

  for (const event of events) {
    const key = userKey(event);
    users.add(key);
    sessions.add(event.session_id);
    const day = event.occurred_at.slice(0, 10);
    if (!byDay.has(day)) byDay.set(day, new Set());
    byDay.get(day)!.add(key);
    if (typeof event.duration_ms === "number") {
      durationSum += event.duration_ms;
      durationCount += 1;
    }
  }

  return {
    event_count: events.length,
    active_users: users.size,
    session_count: sessions.size,
    dau_series: Array.from(byDay.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, set]) => ({ date, users: set.size })),
    avg_duration_ms: durationCount > 0 ? Math.round(durationSum / durationCount) : 0,
  };
}

function northStarMetrics(events: AnalyticsEvent[]) {
  const valueRecordingUsers = new Set<string>();
  const activePetProfiles = new Set<string>();
  const activePetProfileUsers = new Set<string>();
  let explicitMemorySavedCount = 0;
  let legacyMemoryCount = 0;

  for (const event of events) {
    const key = userKey(event);
    if (VALUE_RECORD_EVENTS.has(event.event_name)) {
      valueRecordingUsers.add(key);
    }

    if (event.event_name === "pet_memory_saved") {
      explicitMemorySavedCount += 1;
    } else if (LEGACY_MEMORY_EVENTS.has(event.event_name)) {
      legacyMemoryCount += 1;
    }

    const petId = propertyText(event, "pet_id") ?? propertyText(event, "petId");
    if (petId) {
      activePetProfiles.add(petId);
    }
    if (
      event.module === "pet_profile" ||
      PET_PROFILE_ACTIVITY_EVENTS.has(event.event_name)
    ) {
      activePetProfileUsers.add(key);
    }
  }

  const hasPetProfileIds = activePetProfiles.size > 0;
  return {
    weekly_value_recording_users: valueRecordingUsers.size,
    weekly_active_pet_profiles: hasPetProfileIds
      ? activePetProfiles.size
      : activePetProfileUsers.size,
    weekly_pet_memories_saved: explicitMemorySavedCount > 0
      ? explicitMemorySavedCount
      : legacyMemoryCount,
    active_pet_profiles_approximate: !hasPetProfileIds,
  };
}

function pageRankings(events: AnalyticsEvent[]) {
  const stats = new Map<string, {
    pv: number;
    users: Set<string>;
    durationSum: number;
    durationCount: number;
  }>();

  for (const event of events) {
    if (!event.page_name) continue;
    const row = stats.get(event.page_name) ?? {
      pv: 0,
      users: new Set<string>(),
      durationSum: 0,
      durationCount: 0,
    };
    if (event.event_name === "page_view") row.pv += 1;
    row.users.add(userKey(event));
    if (typeof event.duration_ms === "number") {
      row.durationSum += event.duration_ms;
      row.durationCount += 1;
    }
    stats.set(event.page_name, row);
  }

  return topRows(
    Array.from(stats.entries()).map(([page_name, row]) => ({
      page_name,
      pv: row.pv,
      uv: row.users.size,
      avg_duration_ms: row.durationCount > 0
        ? Math.round(row.durationSum / row.durationCount)
        : 0,
    })),
    "pv",
  );
}

function featureRankings(events: AnalyticsEvent[]) {
  const counts = new Map<string, number>();
  const users = new Map<string, Set<string>>();
  for (const event of events) {
    if (event.event_name === "page_view" || event.event_name === "page_leave") {
      continue;
    }
    inc(counts, event.event_name);
    if (!users.has(event.event_name)) users.set(event.event_name, new Set());
    users.get(event.event_name)!.add(userKey(event));
  }
  return topRows(
    Array.from(counts.entries()).map(([event_name, count]) => ({
      event_name,
      count,
      users: users.get(event_name)?.size ?? 0,
    })),
    "count",
  );
}

function aiUsage(events: AnalyticsEvent[]) {
  const aiEvents = events.filter((event) =>
    event.module === "ai_chat" || event.module === "ai_image" ||
    event.event_name.startsWith("ai_") ||
    event.event_name.startsWith("image_generate")
  );
  const total = aiEvents.filter((event) => event.event_name.endsWith("_start")).length;
  const success = aiEvents.filter((event) => event.event_name.endsWith("_success")).length;
  const failed = aiEvents.filter((event) => event.event_name.endsWith("_error")).length;
  const durations = aiEvents
    .map((event) => event.duration_ms)
    .filter((value): value is number => typeof value === "number");

  return {
    started_count: total,
    success_count: success,
    error_count: failed,
    success_rate: success + failed > 0 ? success / (success + failed) : 0,
    avg_duration_ms: durations.length > 0
      ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length)
      : 0,
  };
}

function errorRankings(events: AnalyticsEvent[]) {
  const stats = new Map<string, { count: number; users: Set<string> }>();
  for (const event of events) {
    if (!event.event_name.endsWith("_error") && event.event_name !== "error_event") {
      continue;
    }
    const errorCode = String(event.properties?.error_code ?? event.event_name);
    const row = stats.get(errorCode) ?? { count: 0, users: new Set<string>() };
    row.count += 1;
    row.users.add(userKey(event));
    stats.set(errorCode, row);
  }
  return topRows(
    Array.from(stats.entries()).map(([error_code, row]) => ({
      error_code,
      count: row.count,
      affected_users: row.users.size,
    })),
    "count",
  );
}

function funnel(events: AnalyticsEvent[]) {
  const steps = [
    { key: "home", event_name: "page_view", page_name: "home" },
    { key: "diary_compose", event_name: "page_view", page_name: "diary_compose" },
    { key: "diary_success", event_name: "diary_generate_success" },
  ];
  return steps.map((step) => {
    const users = new Set<string>();
    for (const event of events) {
      if (event.event_name !== step.event_name) continue;
      if (step.page_name && event.page_name !== step.page_name) continue;
      users.add(userKey(event));
    }
    return { step: step.key, users: users.size };
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  const userId = await resolveUserId(req);
  if (!userId) return jsonResponse({ error: "Unauthorized" }, 401);

  const supabase = createServiceRoleClient();
  const admin = await supabase
    .from("admin_users")
    .select("user_id, role, enabled")
    .eq("user_id", userId)
    .eq("enabled", true)
    .maybeSingle();

  if (admin.error || !admin.data) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  let range;
  try {
    range = resolveRange(body);
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : String(error) }, 400);
  }

  const filters = (body.filters && typeof body.filters === "object")
    ? body.filters as Record<string, unknown>
    : {};
  const action = String(body.action ?? "overview");

  try {
    const events = await loadEvents(supabase, range, filters);
    const weeklyRange = {
      startAt: new Date(Date.now() - WEEK_MS).toISOString(),
      endAt: new Date().toISOString(),
    };
    const weeklyFilters = { ...filters, module: "all", event_name: "all" };
    const weeklyEvents = await loadEvents(supabase, weeklyRange, weeklyFilters);
    const payload = {
      range,
      filters,
      truncated: events.length >= MAX_ROWS,
      north_star: northStarMetrics(weeklyEvents),
      overview: overview(events),
      page_rankings: pageRankings(events),
      feature_rankings: featureRankings(events),
      ai_usage: aiUsage(events),
      error_rankings: errorRankings(events),
      funnel: funnel(events),
    };

    if (action === "all") return jsonResponse(payload);
    if (action in payload) {
      return jsonResponse({
        range,
        filters,
        [action]: payload[action as keyof typeof payload],
      });
    }
    return jsonResponse({ error: "Unknown action" }, 400);
  } catch (error) {
    console.error("[analytics-dashboard] query error", error);
    return jsonResponse({ error: "Failed to load analytics dashboard data" }, 500);
  }
});
