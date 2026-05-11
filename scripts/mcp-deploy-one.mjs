/**
 * 从 scripts/_mcp_<slug>.json 读取 deploy_edge_function 参数并打印校验信息。
 * 实际 MCP 调用由 Cursor 完成；本脚本用于生成各函数的 JSON 负载。
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const slug = process.argv[2];
if (!slug) {
  console.error("Usage: node mcp-deploy-one.mjs <slug>");
  process.exit(1);
}
const p = path.join(__dirname, `_mcp_${slug}.json`);
const j = JSON.parse(fs.readFileSync(p, "utf8"));
const keys = ["project_id", "name", "entrypoint_path", "verify_jwt", "files"];
for (const k of keys) {
  if (!(k in j)) throw new Error(`missing ${k}`);
}
console.log("OK", j.name, "files", j.files.length, "bytes", fs.statSync(p).size);
