/**
 * 从 scripts/_mcp_<slug>.json 读取 deploy_edge_function 参数，向 stdout 输出单行 JSON
 * （供 Cursor MCP 调用或 Management API 复用）。
 * 用法: node scripts/emit-deploy-edge-call.mjs scripts/_mcp_moderate-text.json
 */
import fs from "node:fs";

const p = process.argv[2];
if (!p) {
  console.error("Usage: node emit-deploy-edge-call.mjs <path-to-_mcp-json>");
  process.exit(1);
}
const a = JSON.parse(fs.readFileSync(p, "utf8"));
process.stdout.write(JSON.stringify(a));
