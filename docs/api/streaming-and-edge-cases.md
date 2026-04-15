# 流式接口与边界行为（SSE）

对应 OpenAPI 中带 `text/event-stream` 的接口；实现参考 [lib/services/supabase_edge_service.dart](../../lib/services/supabase_edge_service.dart) 与 Edge 源码。

## `POST /functions/v1/chat`

### 成功流（输入审核通过后）

- **Content-Type**：`text/event-stream`（由 Dify 经 Edge 转发）。
- **行格式**：以 `data: ` 开头的行负载为 JSON；非 `data:` 行（如 `event: ping`）客户端应忽略，勿当 JSON 解析。
- **客户端处理的事件**（节选，与 `callDifyChat` 一致）：
  - `event: "message"`：增量答案在字段 `answer`；同时可能携带 `conversation_id`、`message_id`。
  - `event: "message_end"`：本轮结束；`conversation_id` 在 `conversation_id`，消息 id 在 `id`。
  - `event: "error"`：流内错误，字段 `message`；客户端应终止并提示。
  - `workflow_started` / `workflow_finished` / `node_*` / `tts_*`：当前客户端逻辑为跳过仅日志。
- **流结束**：HTTP 流关闭后，客户端合成 `DoneEvent(conversationId, messageId)`。

### 输入审核未通过

- **HTTP 200**，`Content-Type: application/json`，体为 `ModerationResult`（与 [moderation_contract.ts](../../supabase/functions/_shared/moderation_contract.ts) 一致），**非 SSE**。

### 配置/上游错误

- 可能返回 JSON：`error`、`errorCode`（如 `DIFY_API_KEY_MISSING`）、`status`、`code` 等；HTTP 状态码非 200。客户端可读文案逻辑见 `formatChatUpstreamError`。

---

## `POST /functions/v1/diary-v3`

### 成功流（输入审核通过且 `response_mode: streaming`）

- **Content-Type**：`text/event-stream`。
- **负载**：`data: ` 后为 JSON，常见 `event` 值：
  - `text_chunk`：`data.text` 为增量文本（见 `supabase_edge_service` 中 `DiaryContentEvent`）。
  - `workflow_finished`：可从 `data.outputs` 等取最终文本（客户端有兜底合并逻辑）。
- **服务端行为**（`diary-v3.ts`）：流式过程中可能对**累积输出**做 `diary_output` 审核；拦截时由 TransformStream 改写事件（以部署代码为准）。

### 输入审核未通过

- **HTTP 200** + JSON `ModerationResult`（与 chat 对称）。

### 其他 HTTP 状态

- **401**：缺少/无效 `Authorization`。
- **402**：余额不足等业务拒绝（纯文本 body，非统一 JSON 时以实际响应为准）。
- **500 / 502**：配置缺失、上游不可用等。

### 阻塞模式

- `response_mode` 非 `streaming` 时，响应为 JSON（完整 workflow 结果）；OpenAPI 未展开 Dify 原始结构，调试时可抓包对照。

---

## `img-gen-check-v2` 状态字段

客户端将 `status` **大写** 比较，并兼容多种「成功」别名（见 [loading_page.dart](../../lib/features/image_generation/presentation/loading_page.dart)）：

- 进行中：`PENDING`、`RUNNING`（及服务端可能返回的 `PROCESSING`）。
- 成功：`SUCCEED`、`SUCCEEDED`、`COMPLETED`、`SUCCESS`、`DONE`。
- 失败：`FAILED` 或审核失败时返回的 `status: FAILED` + `error` / `errorCode`。

成功且过审时响应含 `path`（`ai-images` 桶内对象键），客户端优先 `storage.download(path)`，失败再回退 `getPublicUrl`。

---

## 与 OpenAPI 的衔接

OpenAPI 中上述接口的 `200` response 声明了 `application/json` 与 `text/event-stream` 两种 content type；**实际 Content-Type 每次请求只取其一**，由是否触发审核拦截、以及 `response_mode` 决定。
