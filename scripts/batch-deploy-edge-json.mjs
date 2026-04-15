/**
 * 依次用 Management API 部署 scripts 目录下所有 _mcp_*.json（与 MCP deploy_edge_function 同源负载）。
 * 需要: $env:SUPABASE_ACCESS_TOKEN = "sbp_..."
 *
 * 用法: node scripts/batch-deploy-edge-json.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/** 与 @supabase/mcp-server-supabase deployEdgeFunction 一致 */
function buildDeployFormData(payload) {
  const metadata = {
    name: payload.name,
    entrypoint_path: payload.entrypoint_path,
    verify_jwt: payload.verify_jwt,
  };
  if (payload.import_map_path) {
    metadata.import_map_path = payload.import_map_path;
  } else {
    const importMapFile = payload.files.find((x) =>
      ["deno.json", "import_map.json"].includes(x.name),
    );
    if (importMapFile) metadata.import_map_path = importMapFile.name;
  }
  const form = new FormData();
  form.append(
    "metadata",
    new Blob([JSON.stringify(metadata)], { type: "application/json" }),
  );
  for (const file of payload.files) {
    form.append(
      "file",
      new Blob([file.content], { type: "application/typescript" }),
      file.name,
    );
  }
  return form;
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const token = process.env.SUPABASE_ACCESS_TOKEN?.trim();
if (!token) {
  console.error("Missing SUPABASE_ACCESS_TOKEN");
  process.exit(1);
}

const dir = __dirname;
const files = fs
  .readdirSync(dir)
  .filter(
    (f) =>
      f.startsWith("_mcp_") &&
      f.endsWith(".json") &&
      !f.includes("_payload_"),
  )
  .sort();

if (files.length === 0) {
  console.error("No _mcp_*.json in", dir);
  process.exit(1);
}

for (const f of files) {
  const full = path.join(dir, f);
  const a = JSON.parse(fs.readFileSync(full, "utf8"));
  const { project_id, name } = a;
  const url = `https://api.supabase.com/v1/projects/${project_id}/functions/deploy?slug=${encodeURIComponent(name)}`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: buildDeployFormData(a),
  });
  const text = await r.text();
  console.log(name, r.status, text.slice(0, 300));
  if (!r.ok) process.exit(1);
}

console.log("All OK:", files.length);
