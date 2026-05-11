/**
 * 使用 Supabase Management API 部署 Edge Function（与 MCP deploy_edge_function 等价负载）。
 * 需要环境变量 SUPABASE_ACCESS_TOKEN（Dashboard → Account → Access Tokens，需含 edge_functions:write）。
 *
 * 用法:
 *   node scripts/push-edge-management-api.mjs scripts/_mcp_moderate-text.json
 *   node scripts/push-edge-management-api.mjs scripts/_mcp_moderate-text.json --dry-run
 */
import fs from "node:fs";

const path = process.argv[2];
const dryRun = process.argv.includes("--dry-run");
if (!path) {
  console.error("Usage: node push-edge-management-api.mjs <_mcp_*.json> [--dry-run]");
  process.exit(1);
}

const token = process.env.SUPABASE_ACCESS_TOKEN?.trim();
const a = JSON.parse(fs.readFileSync(path, "utf8"));
const { project_id, name, entrypoint_path, verify_jwt, files } = a;
if (!project_id || !name || !entrypoint_path || typeof verify_jwt !== "boolean" || !Array.isArray(files)) {
  console.error("Invalid payload: need project_id, name, entrypoint_path, verify_jwt, files[]");
  process.exit(1);
}

const url = `https://api.supabase.com/v1/projects/${project_id}/functions/deploy?slug=${encodeURIComponent(name)}`;

/** 与 @supabase/mcp-server-supabase deployEdgeFunction 一致：multipart + metadata Blob + 多个 file */
function buildDeployFormData(payload) {
  const metadata = {
    name: payload.name,
    entrypoint_path: payload.entrypoint_path,
    verify_jwt: payload.verify_jwt,
  };
  if (payload.import_map_path) {
    metadata.import_map_path = payload.import_map_path;
  } else {
    const importMapFile = payload.files.find((f) =>
      ["deno.json", "import_map.json"].includes(f.name),
    );
    if (importMapFile) metadata.import_map_path = importMapFile.name;
  }
  const form = new FormData();
  form.append(
    "metadata",
    new Blob([JSON.stringify(metadata)], { type: "application/json" }),
  );
  for (const f of payload.files) {
    form.append(
      "file",
      new Blob([f.content], { type: "application/typescript" }),
      f.name,
    );
  }
  return form;
}

if (dryRun) {
  let total = 0;
  for (const f of files) total += Buffer.byteLength(f.content, "utf8");
  console.log("POST", url, "(multipart/form-data)");
  console.log("file_count", files.length, "approx_bytes", total);
  process.exit(0);
}

if (!token) {
  console.error("Missing SUPABASE_ACCESS_TOKEN");
  process.exit(1);
}

const r = await fetch(url, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
  },
  body: buildDeployFormData(a),
});

const text = await r.text();
console.log(name, r.status, text.slice(0, 500));
if (!r.ok) process.exit(1);
