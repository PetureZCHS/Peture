# Storage 桶与路径约定

OpenAPI 对 Supabase Storage 描述能力有限；此处补充与 **客户端 + Edge** 对齐的桶名与路径规则。桶级 **RLS / policy** 以 Supabase 项目配置及仓库内 `supabase/migrations/`（含 Storage 相关迁移）为准。

## 桶清单（应用相关）

| 桶 ID | 用途摘要 |
|--------|-----------|
| `avatars-temp` | 用户头像临时上传；`avatar-finalize` 读取并审核后写入正式桶 |
| `avatars` | 正式头像；`getPublicUrl` 公开访问（以项目策略为准） |
| `ai-images-temp` | AI 生图原图临时区；`img-gen-start` 轮询等待 `{userId}/original/{file_name}` |
| `ai-images` | 生成结果正式区；`img-gen-check-v2` 上传 `{userId}/generated/{file_name}` |
| `post-images` | 社区发帖图片（见 `SupabaseService`） |

Dart 常量参考：[lib/features/moderation/domain/moderation_storage_buckets.dart](../../lib/features/moderation/domain/moderation_storage_buckets.dart)。

## 路径约定

1. **头像临时**：须落在当前用户命名空间，供 `avatar-finalize` 校验：`{userId}/...`（与 Edge 中 `temp_path` 校验一致）。
2. **生图原文件**：`{userId}/original/{file_name}`（与 `img-gen-start` 中 list/sign 路径一致）。
3. **生图结果**：`{userId}/generated/{file_name}`（`img-gen-check-v2` 成功响应 `path`）。
4. **审核 `moderate-image`**：若传 `storage_path`，须以当前 `userId` 为前缀，否则 400（见 Edge 实现）。

## 与 Edge 的衔接

- `img-gen-start`：依赖客户端已把文件传到 `ai-images-temp` 对应路径；通过后调用上游并返回 `task_id`。
- `img-gen-check-v2`：上游成功后下载图片 → **输出图审核** → 写入 `ai-images`。
- `avatar-finalize`：审核通过则从 `avatars-temp` 拷贝到 `avatars` 并 `upsert users_profiles.avatar_url`。

## HTTP API 说明

Storage 上传/下载通常通过 **Supabase 客户端 SDK**（`storage.from(bucket).upload/download`），而非 `/functions/v1`。REST 层为 Supabase Storage API（路径形如 `/storage/v1/object/...`），若需单独 HTTP 文档可从 [Supabase Storage API 官方文档](https://supabase.com/docs/reference/javascript/storage) 生成，本仓库以 **SDK 用法 + 上述桶/路径契约** 为主。
