/**
 * 清理 user-avatars / pet-avatars 中与数据库不一致的历史头像文件。
 * 调用方式（需保密）：
 * - Header `x-cleanup-secret` 与 Dashboard Secrets 中 `AVATAR_STORAGE_CLEANUP_SECRET` 一致；或
 * - Header `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`（仅服务端/脚本）
 * Query: `?dry_run=true` 只统计不删除。
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, x-cleanup-secret, content-type",
};

const USER_BUCKET = "user-avatars";
const PET_BUCKET = "pet-avatars";

function pathFromPublicUrl(
  url: string | null | undefined,
  bucket: string,
): string | null {
  if (!url || typeof url !== "string") return null;
  const u = url.split("?")[0];
  const marker = `/object/public/${bucket}/`;
  const i = u.indexOf(marker);
  if (i === -1) return null;
  try {
    return decodeURIComponent(u.slice(i + marker.length));
  } catch {
    return null;
  }
}

async function removeBatches(
  supabase: ReturnType<typeof createClient>,
  bucket: string,
  paths: string[],
  dryRun: boolean,
  onError: (msg: string) => void,
) {
  if (dryRun || paths.length === 0) return;
  const chunk = 80;
  for (let i = 0; i < paths.length; i += chunk) {
    const batch = paths.slice(i, i + chunk);
    const { error } = await supabase.storage.from(bucket).remove(batch);
    if (error) onError(`${bucket} remove ${batch[0]}: ${error.message}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const cleanupSecret = Deno.env.get("AVATAR_STORAGE_CLEANUP_SECRET");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const hdrSecret = req.headers.get("x-cleanup-secret");
  const bearer = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ??
    "";

  const authorized =
    (cleanupSecret && hdrSecret === cleanupSecret) ||
    (serviceKey.length > 0 && bearer === serviceKey);
  if (!authorized) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const dryRun = new URL(req.url).searchParams.get("dry_run") === "true";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const stats = {
    dryRun,
    userFoldersScanned: 0,
    petFoldersScanned: 0,
    userObjectsRemoved: 0,
    petObjectsRemoved: 0,
    errors: [] as string[],
  };
  const err = (m: string) => stats.errors.push(m);

  try {
    const { data: profiles, error: pe } = await supabase
      .from("users_profiles")
      .select("id, avatar_url");
    if (pe) throw pe;

    for (const row of profiles ?? []) {
      const uid = row.id as string;
      const keep = pathFromPublicUrl(row.avatar_url as string | null, USER_BUCKET);
      stats.userFoldersScanned++;

      const { data: items, error: le } = await supabase.storage
        .from(USER_BUCKET)
        .list(uid, { limit: 1000 });
      if (le) {
        err(`list ${USER_BUCKET}/${uid}: ${le.message}`);
        continue;
      }

      const toRemove: string[] = [];
      for (const it of items ?? []) {
        if (!it.name?.startsWith("avatar_")) continue;
        const full = `${uid}/${it.name}`;
        if (full === keep) continue;
        toRemove.push(full);
      }
      stats.userObjectsRemoved += toRemove.length;
      await removeBatches(supabase, USER_BUCKET, toRemove, dryRun, err);
    }

    const { data: pets, error: petErr } = await supabase
      .from("pets")
      .select("id, user_id, avatar");
    if (petErr) throw petErr;

    for (const p of pets ?? []) {
      const petId = p.id as string;
      const userId = p.user_id as string;
      if (!userId || !petId) continue;
      const prefix = `${userId}/${petId}`;
      const keep = pathFromPublicUrl(p.avatar as string | null, PET_BUCKET);
      stats.petFoldersScanned++;

      const { data: pitems, error: ple } = await supabase.storage
        .from(PET_BUCKET)
        .list(prefix, { limit: 1000 });
      if (ple) {
        err(`list ${PET_BUCKET}/${prefix}: ${ple.message}`);
        continue;
      }

      const toRemove: string[] = [];
      for (const it of pitems ?? []) {
        if (!it.name?.startsWith("avatar_")) continue;
        const full = `${prefix}/${it.name}`;
        if (full === keep) continue;
        toRemove.push(full);
      }
      stats.petObjectsRemoved += toRemove.length;
      await removeBatches(supabase, PET_BUCKET, toRemove, dryRun, err);
    }

    return new Response(JSON.stringify({ ok: true, stats }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e), stats }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
