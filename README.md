# Peture（智宠合生）

Peture 是一款面向宠物管理场景的 Flutter 应用。当前仓库更适合内部团队协作与持续迭代，因此本文档重点说明项目目标、现有结构、开发方式、联调路径和协作约定。

## 项目范围

当前实现覆盖以下核心模块：

- AI 问诊
- 宠物档案与医疗记录
- 成长日记
- AI 图像实验室
- 活力健身
- 营养食谱
- 训宠响片
- 费用管理
- 智能提醒
- 社区话题
- 宠物商城与直播商城
- 邀请码、遗失宠物救助、图书馆、领地玩法、个人中心与设置

## 技术栈

- Flutter / Dart
- Supabase：数据库、认证、Storage、Edge Functions
- LeanCloud：登录与账户能力
- Dify：AI 对话服务
- Sentry：错误监控与性能追踪
- Provider：状态管理
- sqflite、Hive、shared_preferences：本地存储与缓存

## 目录结构

仓库当前采用按业务拆分的结构，重点目录如下：

- [lib/core](lib/core)：全局配置、路由观察器、基础能力
- [lib/features](lib/features)：按功能拆分的业务模块
- [lib/shared](lib/shared)：公共模型、工具、数据库辅助类、通用组件
- [supabase/functions](supabase/functions)：Supabase Edge Functions
- [assets](assets)：图片、音频、静态数据
- [test](test)：测试代码

### 主要功能模块

- [lib/features/auth/presentation](lib/features/auth/presentation)：登录、注册、手机号登录、邮箱登录
- [lib/features/home/presentation](lib/features/home/presentation)：首页与功能入口
- [lib/features/chat/presentation](lib/features/chat/presentation)：AI 问诊
- [lib/features/diary/presentation](lib/features/diary/presentation)：成长日记、分享卡片、时间线
- [lib/features/image_generation/presentation](lib/features/image_generation/presentation)：AI 图像实验室
- [lib/features/medical/presentation](lib/features/medical/presentation)：医疗记录
- [lib/features/pet_passport/presentation](lib/features/pet_passport/presentation)：宠物档案
- [lib/features/fitness/presentation](lib/features/fitness/presentation)：活力健身
- [lib/features/pet_recipe/presentation](lib/features/pet_recipe/presentation)：营养食谱
- [lib/features/dog_clicker/presentation](lib/features/dog_clicker/presentation)：训宠响片
- [lib/features/expense/presentation](lib/features/expense/presentation)：费用管理
- [lib/features/reminder/presentation](lib/features/reminder/presentation)：智能提醒
- [lib/features/community/presentation](lib/features/community/presentation)：社区话题、发帖、帖子详情
- [lib/features/shop/presentation](lib/features/shop/presentation)：宠物商城、直播商城、商品详情、购物车、支付
- [lib/features/invitation/presentation](lib/features/invitation/presentation)：邀请码系统
- [lib/features/lost_pet/presentation](lib/features/lost_pet/presentation)：遗失宠物救助
- [lib/features/library/presentation](lib/features/library/presentation)：图书馆与阅读器
- [lib/features/profile/presentation](lib/features/profile/presentation)：个人资料、设置、账号、改密
- [lib/features/growth_log/presentation](lib/features/growth_log/presentation)：成长记录

### 核心共享层

- [lib/core/config](lib/core/config)：Supabase、LeanCloud、API 配置
- [lib/services](lib/services)：Supabase 服务、Edge Function 服务、分析服务
- [lib/shared/models](lib/shared/models)：宠物、日记、对话、费用、食谱等数据模型
- [lib/shared/database](lib/shared/database)：本地数据库辅助类
- [lib/shared/utils](lib/shared/utils)：通用工具、头像工具、UI 工具
- [lib/shared/widgets](lib/shared/widgets)：共享组件

## 运行入口

- 应用入口位于 [lib/main.dart](lib/main.dart)
- 首页壳层与功能导航位于 [lib/features/home/presentation/home_screen.dart](lib/features/home/presentation/home_screen.dart)
- 当前启动流程会先初始化 Sentry，再初始化 Supabase，然后根据登录状态进入登录页或主界面

## 环境要求

- Flutter SDK 3.x
- Dart SDK 3.x
- macOS、Windows、Linux、Android 或 iOS 开发环境
- Supabase 项目
- LeanCloud 配置
- Dify 服务配置
- Sentry 配置

## 本地启动

1. 安装依赖：`flutter pub get`
2. 检查配置：确认 [lib/core/config/supabase_config.dart](lib/core/config/supabase_config.dart) 与 [lib/core/config/leancloud_config.dart](lib/core/config/leancloud_config.dart)
3. 启动应用：`flutter run`
4. 如需指定设备：先执行 `flutter devices`，再用 `flutter run -d <device-id>`

## 后端与云函数

Supabase Edge Functions 位于 [supabase/functions](supabase/functions)，当前仓库中可见的主要函数包括：

- `chat`：AI 问诊
- `diary`：成长日记相关能力
- `img-gen`、`img-gen-precheck`、`img-gen-start`、`img-gen-check`：AI 图像实验室
- `get-or-create-invitation-code`、`redeem-invitation`：邀请码流程
- `cleanup-storage-avatars`：头像清理
- `recharge-test`：测试辅助

团队协作时，涉及云函数改动的需求应同步检查：

- 函数代码是否已部署
- Supabase Storage 桶权限是否正确
- RLS 与 GRANT 是否覆盖新数据路径
- 前端是否对错误码、超时和限流做了统一处理

## 资源与配置

- `assets/logo.png`：启动页使用
- `assets/icon/app_icon.png`：应用图标
- `assets/mp3/`：训宠响片音效
- `assets/image_styles/`：图片风格资源
- `assets/data/china_regions.json`：区域数据

## 团队协作约定

- 新功能优先按 `features / shared / core` 结构拆分，不要回退到旧版扁平目录。
- 页面、服务、模型、工具尽量保持单一职责，跨模块公共逻辑放到 `shared`。
- 接入 Supabase 或云函数的新能力时，优先补齐错误兜底、超时与空态处理。
- UI 改动应保持当前应用的统一视觉语言，避免引入与现有页面冲突的风格。
- 涉及数据结构变更时，应同步更新后端迁移、前端模型和说明文档。

## 开发常用命令

```bash
flutter pub get
flutter devices
flutter run
flutter test
```

## 常见排查点

- 图片预检失败：先检查 `img-gen-precheck` 云函数是否可用，再看用户登录态和网络。
- AI 生图无样式：优先检查 `ai_image_presets` 的数据、RLS、以及 `aspect_ratio` 是否与前端过滤条件一致。
- 头像或图片加载异常：先确认 Storage 路径、读写权限与本地缓存文件是否存在。
- 登录后白屏或初始化异常：重点查看 Supabase、Sentry、LeanCloud 配置是否完整。

## 测试

- 单元测试与基础测试放在 [test](test)
- 当前仓库已有 Edge Function 相关测试与排障文档，可在联调阶段继续补充

## 版本说明

- 当前仓库以内部团队协作为主，不需要公开开源说明。
- README 的目标是帮助新同事快速理解架构、找到入口、完成联调和排障。

最后更新：2026 年 4 月 28 日