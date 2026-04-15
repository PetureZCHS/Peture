/**
 * 生成 Supabase MCP deploy_edge_function 所需的 JSON（stdout 输出单行）。
 * 用法: node scripts/build-edge-deploy-json.mjs <functionSlug> <entryRelativePath>
 * 例: node scripts/build-edge-deploy-json.mjs moderate-text moderate-text/index.ts
 * 例: node scripts/build-edge-deploy-json.mjs diary-v3 diary/diary-v3.ts
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..", "supabase", "functions");
const PROJECT_ID = "tcftpcvcldfudzxgemdh";

const SHARED_FILES = [
  "_shared/auth.ts",
  "_shared/trace.ts",
  "_shared/moderation_contract.ts",
  "_shared/moderation_provider.ts",
  "_shared/moderation_logger.ts",
  "_shared/yidun_client.ts",
];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const slug = process.argv[2];
const entryRel = process.argv[3];
const outPath = process.argv[4];
const verifyJwtArg = process.argv[5];
if (!slug || !entryRel) {
  console.error(
    "Usage: node build-edge-deploy-json.mjs <slug> <entryRelativePath> [outJsonPath] [verify_jwt true|false]",
  );
  process.exit(1);
}

let indexContent = read(entryRel);
indexContent = indexContent.replaceAll("../_shared/", "./_shared/");

const files = [
  { name: "index.ts", content: indexContent },
  ...SHARED_FILES.map((f) => ({ name: f, content: read(f) })),
];

const body = {
  project_id: PROJECT_ID,
  name: slug,
  entrypoint_path: "index.ts",
  verify_jwt: true,
  files,
};

if (verifyJwtArg === "false") {
  body.verify_jwt = false;
}

if (outPath) {
  fs.writeFileSync(outPath, JSON.stringify(body), "utf8");
  console.error("Wrote", outPath, fs.statSync(outPath).size, "bytes");
} else {
  process.stdout.write(JSON.stringify(body));
}
