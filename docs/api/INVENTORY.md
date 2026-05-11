# Peture 接口清单（源码反查）

本文档由 `lib/**/*.dart` 与 `supabase/functions/**` 交叉梳理生成，供 [openapi/openapi.yaml](openapi/openapi.yaml) 与维护流程对齐使用。

## Edge Functions 与客户端调用矩阵

| 部署名（URL 段） | 客户端调用位置 | 鉴权 | 备注 |
|------------------|----------------|------|------|
| `chat` | [lib/services/supabase_edge_service.dart](../../lib/services/supabase_edge_service.dart)（HTTP POST 流式） | `apikey` + `Authorization: Bearer <用户 access_token>` | 未过审输入时返回 JSON `ModerationResult`，否则 SSE |
| `diary-v3` | 同上 `callDiaryStream` / `callDiaryBlocking` | 用户 JWT | 与 [lib/shared/utils/supabase_constants.dart](../../lib/shared/utils/supabase_constants.dart) 中 `diaryFunction` 一致 |
| `diary` | [lib/core/config/supabase_config.dart](../../lib/core/config/supabase_config.dart) 中 `diaryUrl`（若使用该配置） | 依部署 | 源码入口为 [supabase/functions/diary/index.ts](../../supabase/functions/diary/index.ts)；与 `diary-v3` 可能并存，以实际部署为准 |
| `moderate-text` | [lib/features/moderation/data/moderation_client.dart](../../lib/features/moderation/data/moderation_client.dart) | 用户 JWT（invoke 显式 headers） | body: `scene`, `content` |
| `moderate-image` | 同上 | 用户 JWT | body: `scene` + `image_base64` 或 `storage_path` |
| `img-gen-start` | [lib/features/image_generation/presentation/preparation_page.dart](../../lib/features/image_generation/presentation/preparation_page.dart) | SDK 默认 session（Bearer） | body: `file_name`, `style` |
| `img-gen-check-v2` | [lib/features/image_generation/presentation/loading_page.dart](../../lib/features/image_generation/presentation/loading_page.dart) | 显式 Bearer access_token | body: `task_id`, `file_name` |
| `img-gen-check` | 无 Flutter 引用 | Bearer | 旧版轮询实现；保留于仓库，客户端当前用 v2 |
| `avatar-finalize` | [lib/services/supabase_service.dart](../../lib/services/supabase_service.dart) | SDK session | body: `temp_path` |
| `get-or-create-invitation-code` | `supabase_service.dart` | SDK session | 无 body |
| `redeem-invitation` | `supabase_service.dart` | SDK session | body: `code` |
| `recharge-test` | [lib/features/profile/presentation/settings_page.dart](../../lib/features/profile/presentation/settings_page.dart) | SDK session | body: `amount`（测试用） |

## PostgREST：`lib` 中出现的表（去重）

`users_profiles`, `pets`, `medical_records`, `weight_records`, `vaccine_records`, `daily_reminders`, `medication_reminders`, `vaccine_reminders`, `deworming_reminders`, `conversations`, `chat_messages`, `pet_diaries`, `daily_cost_items`, `fitness_records`, `health_plans`, `pet_passports`, `pet_passport_achievements`, `unified_expenses`, `fitness_courses`, `community_posts`, `community_post_comments`, `community_post_likes`, `community_post_collections`, `community_user_follows`, `user_content_feedback`。

主要数据访问入口：[lib/services/supabase_service.dart](../../lib/services/supabase_service.dart)；反馈表：[lib/features/content_feedback/data/content_feedback_repository.dart](../../lib/features/content_feedback/data/content_feedback_repository.dart)。

## Storage 桶（去重）

| 桶名 | 引用位置 |
|------|-----------|
| `avatars-temp` | `supabase_service`, `ModerationStorageBuckets` |
| `avatars` | `ModerationStorageBuckets`, `avatar-finalize` |
| `ai-images-temp` | `ModerationStorageBuckets`, `img-gen-start` |
| `ai-images` | `ModerationStorageBuckets`, `loading_page` 下载生成图 |
| `post-images` | `supabase_service` 社区图片 |

## 与 OpenAPI 的对应关系

- Edge：`/functions/v1/{name}`，详见 [openapi/openapi.yaml](openapi/openapi.yaml)。
- REST：`/rest/v1/{table}` 最小契约（字段以客户端写入与 `supabase/migrations` 为准，缺迁移的表在 OpenAPI 中标注 `additionalProperties`）。
- 流式与存储操作：见 [streaming-and-edge-cases.md](streaming-and-edge-cases.md)、[storage-contract.md](storage-contract.md)。
