# Edge Functions 部署脚本说明

本目录下的 `.mjs` 脚本用于在**本地**把 `supabase/functions/` 里的代码打成与 **Supabase Management API**（及 Cursor 里 Supabase MCP 的 `deploy_edge_function`）兼容的载荷，并可选地发起部署。

**与 Flutter App 无关**：不参与应用构建或运行时。

---

## 前置条件

| 项 | 说明 |
|----|------|
| Node.js | 建议 18+（使用原生 `fetch` / `FormData`）。 |
| `SUPABASE_ACCESS_TOKEN` | 部署前在终端设置；来自 Supabase Dashboard → Account → Access Tokens，需具备 **`edge_functions:write`** 等权限。**切勿把 token 写入仓库或提交到 Git。** |

PowerShell 示例：

```powershell
$env:SUPABASE_ACCESS_TOKEN = "sbp_你的令牌"
```

---

## 脚本一览

| 文件 | 作用 |
|------|------|
| `build-edge-deploy-json.mjs` | 从 `supabase/functions/` 读取入口文件 + 固定列表的 `_shared/*.ts`，生成一份部署用 JSON（可写文件或输出到 stdout）。 |
| `push-edge-management-api.mjs` | 读取 `_mcp_*.json`（或任意符合格式的 JSON），调用 **Management API** 执行**单次**部署。 |
| `batch-deploy-edge-json.mjs` | 扫描本目录下所有 `_mcp_*.json`（排除文件名含 `_payload_` 的），**按文件名排序依次**部署；任一失败则退出。 |
| `emit-deploy-edge-call.mjs` | 读取 `_mcp_*.json`，将整份载荷 **一行 JSON** 输出到 stdout，便于复制给 MCP 或其它工具。 |
| `mcp-deploy-one.mjs` | 读取 `scripts/_mcp_<slug>.json`，校验字段是否齐全；**不发起网络请求**。 |

---

## 推荐工作流

### 1. 生成载荷（`_mcp_<slug>.json`）

```powershell
Set-Location "D:\code\codefield\codeinFlutter\Peture"

node scripts/build-edge-deploy-json.mjs moderate-text moderate-text/index.ts scripts/_mcp_moderate-text.json
node scripts/build-edge-deploy-json.mjs chat chat/index.ts scripts/_mcp_chat.json
node scripts/build-edge-deploy-json.mjs diary-v3 diary/diary-v3.ts scripts/_mcp_diary-v3.json
```

- 参数：`slug`（函数名）、`入口相对 supabase/functions 的路径`、可选 `输出文件路径`。
- 第 4 个参数省略时，JSON 会打到 **stdout**（体积大，适合管道重定向）。
- 第 5 个参数可传 `false`，将载荷中的 `verify_jwt` 设为 `false`（默认 `true`）。

### 2. 检查载荷（可选）

```powershell
node scripts/mcp-deploy-one.mjs moderate-text
```

### 3. 部署到 Supabase

**单个函数：**

```powershell
node scripts/push-edge-management-api.mjs scripts/_mcp_moderate-text.json
```

仅查看将要请求的 URL 与体积，不写远端：

```powershell
node scripts/push-edge-management-api.mjs scripts/_mcp_moderate-text.json --dry-run
```

**多个函数（依赖本目录下已存在多个 `_mcp_*.json`）：**

```powershell
node scripts/batch-deploy-edge-json.mjs
```

### 4. 给 MCP / 外部工具用的一行 JSON

```powershell
node scripts/emit-deploy-edge-call.mjs scripts/_mcp_moderate-text.json
```

---

## 关于 `project_id` 与 `_shared` 打包范围

- `build-edge-deploy-json.mjs` 内写死了 **`PROJECT_ID`**（当前为 Peture 对应项目）。换 Supabase 项目时请改脚本中的常量，或后续可考虑改为读环境变量。
- 该脚本**固定**打入的共享文件见脚本内 `SHARED_FILES` 数组。若某 Edge Function 还依赖 `supabase/functions/` 下其它 `.ts` 文件，仅靠当前脚本**不会**自动包含，需要**扩展 `SHARED_FILES` 或入口打包逻辑**，否则部署后函数可能无法运行。

---

## `_mcp_*.json` 与 Git

`_mcp_*.json` 等载荷文件体积大、且可再生成，通常**不必提交**到 Git（可用 `.gitignore` 忽略）。发布前在本地按上文「推荐工作流」重新生成即可。

---

## 与 Supabase CLI 的关系

团队也可使用官方 **`supabase functions deploy`**。本套脚本的用途是：在已熟悉 **Management API / MCP 载荷格式** 或需要与 MCP **同构** 的 JSON 时，用 Node 直接推送，而不强制依赖 Supabase CLI 登录态。

---

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| `Missing SUPABASE_ACCESS_TOKEN` | 未在当前 shell 设置环境变量。 |
| HTTP 4xx/5xx | Token 权限不足、项目 ID 错误、载荷缺文件或入口路径与线上不一致。 |
| `No _mcp_*.json` | `batch-deploy-edge-json` 需要先有 `build-edge-deploy-json` 生成的 json 文件。 |
| 部署成功但函数报错 | 打包列表未包含该函数实际 `import` 的本地文件，需改 `build-edge-deploy-json.mjs`。 |
