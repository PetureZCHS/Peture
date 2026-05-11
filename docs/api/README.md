# Peture 接口文档

本目录以 **OpenAPI 3.0** 为主描述 HTTP 契约，以 Markdown 补充 **SSE 流式**、**Storage** 及联调说明。事实来源优先对齐：

- Flutter：`lib/`（调用方、请求体、解析逻辑；相对本目录为 `../../lib`）
- Edge：`supabase/functions/`
- 数据库片段：`supabase/migrations/`（仓库内已有迁移）

## 文件导航

| 文件 | 说明 |
|------|------|
| [INVENTORY.md](INVENTORY.md) | Edge / PostgREST / Storage 清单与源码索引 |
| [openapi/openapi.yaml](openapi/openapi.yaml) | **主规范**：`/functions/v1/*`、`/rest/v1/{table}` |
| [streaming-and-edge-cases.md](streaming-and-edge-cases.md) | `chat`、`diary-v3` 的 SSE 与客户端事件处理 |
| [storage-contract.md](storage-contract.md) | Storage 桶、路径约定及与 Edge 生图/头像流程的关系 |

## 如何使用 OpenAPI

1. **导入工具**：将 `openapi/openapi.yaml` 导入 Apifox、Postman、Stoplight 等（注意相对路径 `../streaming-and-edge-cases.md` 仅在说明文字中供人阅读，工具不会解析）。
2. **Server**：将 `servers[0].variables.projectRef.default` 替换为你的项目 ref，或使用环境变量覆盖。
3. **鉴权**：
   - 所有请求建议携带 `apikey: <SUPABASE_ANON_KEY>`（占位符，勿提交生产密钥到文档仓库外渠道）。
   - 用户数据与 Edge 多数接口需 `Authorization: Bearer <access_token>`。
   - `chat` 实际客户端见 [lib/services/supabase_edge_service.dart](../../lib/services/supabase_edge_service.dart)：同时使用 `apikey` 与用户 JWT。

## 维护约定

- 新增或修改 Edge Function：同步更新 `openapi/openapi.yaml` 对应 path 与 `x-source-files`。
- 新增客户端访问的表或桶：更新 [INVENTORY.md](INVENTORY.md)、OpenAPI 中 `TableName` enum 或 Storage 文档。
- 流式协议变更：先改服务端与 `supabase_edge_service`，再改 `streaming-and-edge-cases.md` 与本 YAML 中的 description。

## 已知差异与注意点

1. **日记函数名**： [lib/shared/utils/supabase_constants.dart](../../lib/shared/utils/supabase_constants.dart) 使用 `diary-v3`；[lib/core/config/supabase_config.dart](../../lib/core/config/supabase_config.dart) 使用 `diary`。以实际打包入口引用的配置为准；OpenAPI 中两条路径均列出，`diary` 标记为 deprecated 倾向。
2. **PostgREST 行结构**：OpenAPI 对 `/rest/v1/{table}` 使用宽松 `PostgrestRow`（`additionalProperties: true`）。精确列以数据库与 [lib/services/supabase_service.dart](../../lib/services/supabase_service.dart) 为准；仓库内 migrations 未覆盖的表需自行对照线上 Dashboard 或补迁移。
3. **RLS**：未在 OpenAPI 中展开逐表策略；以 Supabase Dashboard（Authentication → Policies）及本仓库 `supabase/migrations/` 为准。
4. **密钥**：客户端源码中可能存在历史硬编码 anon key——**文档与示例一律使用占位符**；密钥轮换应走 Dashboard 与客户端配置重构，不在此重复真实值。

## 联调检查表（走查摘要）

| 场景 | 验证要点 |
|------|-----------|
| Chat | 带用户 JWT + apikey；输入未通过服务端校验时返回 JSON `ModerationResult`；正常为 SSE `data:` 行 |
| Diary-v3 | 仅用户 JWT；402 余额；流式事件与 `supabase_edge_service` 解析一致 |
| moderate-text / moderate-image | 401 无 token；400 非法 scene；图路径前缀归属当前用户 |
| img-gen-start → v2 | start 需 temp 文件已就绪；check 带 Bearer；成功返回 `path` 可 download |
| avatar-finalize | `temp_path` 必须以当前 userId 开头；失败体多为 ModerationResult 形态 |
| 邀请码 | 403 NOT_ALLOWED 与 200 `{ code }`；兑换 `{ success, error? }` |
| PostgREST | 同请求携带 apikey + 用户 JWT；枚举表名与 INVENTORY 一致 |

前后端联调时以 **OpenAPI 字段** 为 HTTP 合同，上表可作为冒烟清单。
