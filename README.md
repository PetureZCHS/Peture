# Peture（智宠合生）- 宠物管理应用

## 📑 目录

- [📖 项目简介](#-项目简介)
- [🎯 主要功能](#-主要功能)
- [🛠️ 技术栈](#️-技术栈)
- [📁 项目结构](#-项目结构)
  - [完整项目结构图](#完整项目结构图)
  - [根目录文件](#根目录文件)
  - [lib/ 目录](#lib-目录)
- [🚀 快速开始](#-快速开始)
- [📱 功能模块详解](#-功能模块详解)
- [💻 代码使用示例](#-代码使用示例)
- [🔧 开发指南](#-开发指南)
  - [快速开始](#快速开始-1)
  - [项目结构](#项目结构-1)
  - [代码规范](#代码规范)
  - [数据库架构](#数据库架构)
  - [API 调用](#api-调用)
  - [状态管理（Provider）](#状态管理provider)
  - [数据库操作](#数据库操作)
  - [添加新功能](#添加新功能)
  - [调试技巧](#调试技巧)
  - [测试](#测试)
  - [常见问题](#常见问题)
- [📝 注意事项](#-注意事项)
- [📞 联系方式](#-联系方式)
- [📚 相关文档](#-相关文档)

---

## 📖 项目简介

Peture（智宠合生）是一款基于 Flutter 开发的综合性宠物管理应用，旨在为宠物主人提供全方位的宠物健康管理、生活记录和智能服务。应用集成了 AI 智能问诊、电子档案、成长日记、健身训练、营养食谱、训宠响片、社区互动等功能模块。

应用采用现代化的技术架构，支持多平台部署（Android、iOS、Web、Windows、macOS、Linux），提供流畅的用户体验和强大的数据管理能力。

## 🎯 主要功能

- **AI 智能问诊**：基于 Dify 的 RAG AI 对话系统，提供 24 小时在线宠物健康咨询，支持流式和阻塞两种响应模式
- **电子档案**：完整的宠物信息管理，包括基本信息、医疗记录、疫苗记录、体重记录等，支持多宠物管理
- **成长日记**：AI 辅助生成精美的宠物成长日记，支持多种风格（小红书、微博、朋友圈等）
- **活力健身**：宠物健身课程和训练计划管理，包含课程详情、训练记录和历史追踪
- **营养食谱**：宠物营养食谱推荐和管理，提供详细的食谱信息和制作方法
- **训宠响片**：响片训练工具，支持自定义训练项目和音效，帮助宠物训练
- **社区话题**：宠物社区互动功能，分享宠物生活点滴
- **费用管理**：多维度费用管理系统，包括日常费用、医疗费用记录与统计，支持图表可视化
- **智能提醒**：多种提醒功能，包括疫苗、驱虫、用药等提醒，支持自定义提醒时间

## 🛠️ 技术栈

- **框架**：Flutter 3.0+
- **后端服务**：
  - Supabase（数据库、Edge Functions）
  - LeanCloud（用户认证）
  - Dify（AI 对话服务）
- **本地存储**：SQLite（sqflite）
- **状态管理**：Provider
- **UI 组件**：Material Design 3、自定义组件

## 📁 项目结构

### 完整项目结构图

```
Peture/
├── lib/                          # 主要代码目录
│   ├── main.dart                 # 应用入口
│   ├── home_screen.dart          # 主屏幕
│   ├── login_page.dart           # 登录页面
│   ├── chat_page.dart            # AI 聊天页面
│   ├── config/                   # 配置文件
│   │   ├── api_config.dart
│   │   ├── leancloud_config.dart
│   │   ├── leancloud_service.dart
│   │   └── supabase_config.dart
│   ├── database/                 # 数据库操作（SQLite Helper）
│   │   ├── database_helper.dart
│   │   ├── chat_history_helper.dart
│   │   ├── daily_cost_helper.dart
│   │   ├── expense_helper.dart
│   │   ├── fitness_helper.dart
│   │   ├── health_plan_helper.dart
│   │   ├── medical_record_helper.dart
│   │   ├── pet_passport_helper.dart
│   │   ├── reminder_helper.dart
│   │   └── unified_expense_helper.dart
│   ├── models/                   # 数据模型
│   │   ├── chat_history.dart
│   │   ├── conversation.dart
│   │   ├── daily_cost_item.dart
│   │   ├── dify_models.dart
│   │   ├── expense.dart
│   │   ├── fitness_course.dart
│   │   ├── medical_record.dart
│   │   ├── pet.dart
│   │   ├── pet_diary.dart
│   │   ├── pet_passport.dart
│   │   ├── pet_recipe.dart
│   │   └── unified_expense.dart
│   ├── pages/                    # 页面组件
│   │   ├── daily_cost/           # 日常费用
│   │   ├── dog_clicker/          # 训宠响片
│   │   ├── expense/              # 费用管理
│   │   ├── live_shop/            # 直播商城
│   │   ├── partner_fit/          # 活力健身
│   │   ├── pet_diary/            # 宠物日记
│   │   ├── pet_passport/         # 宠物护照
│   │   ├── pet_recipe/           # 宠物食谱
│   │   ├── reminder/             # 提醒功能
│   │   ├── shop/                 # 商城
│   │   ├── unified_expense/      # 统一费用
│   │   ├── data_migration_page.dart
│   │   └── pet_profile_form_page.dart
│   ├── services/                 # 服务层
│   │   ├── dify_service.dart
│   │   ├── supabase_dify_service.dart
│   │   ├── supabase_edge_service.dart
│   │   └── supabase_service.dart
│   ├── utils/                    # 工具类
│   │   ├── fade_snackbar.dart
│   │   ├── snackbar_utils.dart
│   │   ├── supabase_constants.dart
│   │   ├── user_avatar_helper.dart
│   │   └── utils.dart
│   ├── widgets/                  # 可复用组件
│   │   └── pet_profile_card.dart
│   ├── settings/                 # 设置相关
│   │   ├── about.dart
│   │   ├── theme.dart
│   │   └── theme_constants.dart
│   └── data/                     # 静态数据
│       └── fitness_courses_data.dart
├── assets/                       # 资源文件
│   ├── logo.png                 # 应用 Logo
│   ├── icon/                    # 应用图标
│   │   └── app_icon.png
│   └── mp3/                     # 音频文件
│       ├── 喂食.mp3
│       ├── 握手.mp3
│       └── 坐下.mp3
├── supabase/                     # Supabase Edge Functions
│   └── functions/
│       ├── chat/                # 聊天功能
│       │   ├── index.ts
│       │   └── index_anno.ts
│       └── diary/               # 日记功能
│           ├── index.ts
│           └── index_v0.ts
├── test/                         # 测试文件
│   ├── edge_function_test.dart
│   ├── simple_edge_test.dart
│   ├── README_TEST.md
│   ├── CURL_TEST.md
│   └── TROUBLESHOOTING_401.md
├── android/                      # Android 平台配置
├── ios/                          # iOS 平台配置
├── web/                          # Web 平台配置
├── windows/                      # Windows 平台配置
├── macos/                        # macOS 平台配置
├── linux/                        # Linux 平台配置
├── pubspec.yaml                  # 项目依赖配置
├── analysis_options.yaml         # Dart 代码分析配置
├── devtools_options.yaml         # DevTools 配置
├── supabase_schema.sql           # Supabase 数据库表结构
├── migrate_pets_table.sql        # 宠物表字段扩展迁移
├── setup_sounds.sh               # 音效文件设置脚本
└── .gitignore                    # Git 忽略文件配置
```

### 根目录文件

#### `pubspec.yaml`
项目依赖配置文件，定义了所有 Flutter 包依赖、资源文件和项目元数据。

**主要依赖**：
- `supabase_flutter`：Supabase 客户端
- `sqflite`：SQLite 数据库
- `provider`：状态管理
- `flutter_chat_ui`：聊天 UI 组件
- `image_picker`：图片选择
- `audioplayers`：音频播放
- `fl_chart`：图表展示
- `confetti`：礼花动画
- `liquid_glass_renderer`：液体玻璃渲染效果

#### `analysis_options.yaml`
Dart 代码分析配置文件，定义了代码检查规则和 lint 规则。

#### `devtools_options.yaml`
Flutter DevTools 扩展配置文件，用于配置开发工具的扩展启用状态。

#### `supabase_schema.sql`
Supabase 数据库表结构 SQL 脚本，包含：
- 用户信息表（users_profiles）
- 宠物信息表（pets）
- 医疗记录表（medical_records）
- 体重记录表（weight_records）
- 疫苗记录表（vaccine_records）
- 每日提醒表（daily_reminders）
- 对话记录表（conversations）
- 宠物日记表（pet_diaries）
- 聊天消息表（chat_messages）
- Row Level Security (RLS) 策略配置

#### `migrate_pets_table.sql`
宠物信息表字段扩展迁移脚本，用于添加缺失的字段：
- `avatar`：宠物头像路径
- `birth_date`：出生日期
- `neuter_status`：绝育状态
- `weight`：体重

#### `setup_sounds.sh`
训宠响片音效文件快速设置脚本，用于将音效文件复制到指定目录。

#### `.gitignore`
Git 版本控制忽略文件配置，排除构建文件、依赖文件、IDE 配置等。

### `lib/` 目录

#### 核心文件

##### `main.dart`
应用程序入口文件，负责：
- 初始化 Flutter 框架
- 初始化日期格式化本地化数据（中文）
- 初始化 Supabase 客户端
- 配置 MaterialApp 和本地化支持
- 设置登录页面为初始页面

##### `home_screen.dart`
主屏幕页面，包含：
- 全息球体菜单（HolographicSphereMenu）导航，使用液体玻璃渲染效果
- 搜索栏功能
- 8 个主要功能入口：AI 问诊、电子档案、成长日记、活力健身、营养食谱、训宠响片、社区话题、设置
- 渐变色彩主题，每个功能模块使用不同的渐变色

##### `login_page.dart`
登录页面，支持多种登录方式。

##### `email_login_page.dart`
邮箱登录页面。

##### `email_register_page.dart`
邮箱注册页面。

##### `phone_login_page.dart`
手机号登录页面。

##### `chat_page.dart`
AI 智能问诊聊天页面，集成 Dify AI 对话功能。

##### `community_screen.dart`
社区话题页面，展示宠物社区内容。

##### `medical_record_screen.dart`
医疗记录屏幕，管理宠物的医疗健康档案。

##### `profile_screen.dart`
个人资料页面，用户信息管理。

##### `settings_page.dart`
设置页面，应用配置和偏好设置。

##### `account_settings_page.dart`
账户设置页面，用户账户相关设置。

##### `post_detail_page.dart`
帖子详情页面，查看社区帖子详细内容。

##### `data_migration_page.dart`
数据迁移页面，用于数据迁移和同步。

### `lib/config/` 配置目录

##### `api_config.dart`
API 配置文件，集中管理所有 API 端点配置：
- 基础 URL 配置
- 认证相关 API（注册、登录、验证等）
- 其他 API 端点

##### `leancloud_config.dart`
LeanCloud 配置文件，包含 LeanCloud 服务配置信息。

##### `leancloud_service.dart`
LeanCloud 服务封装，提供 LeanCloud 相关功能接口。

##### `supabase_config.dart`
Supabase 配置文件，包含 Supabase 连接配置。

### `lib/database/` 数据库目录

##### `database_helper.dart`
数据库辅助类，SQLite 数据库的核心管理：
- 数据库初始化和版本管理
- 对话记录表（conversations）
- 宠物日记表（pet_diaries）
- 数据库升级逻辑

##### `chat_history_helper.dart`
聊天历史记录辅助类，管理聊天对话的本地存储。

##### `daily_cost_helper.dart`
日常费用辅助类，管理宠物日常开销记录。

##### `expense_helper.dart`
费用辅助类，管理宠物相关费用。

##### `unified_expense_helper.dart`
统一费用辅助类，整合各类费用管理。

##### `medical_record_helper.dart`
医疗记录辅助类，管理宠物医疗记录。

##### `pet_passport_helper.dart`
宠物护照辅助类，管理宠物基本信息档案。

##### `reminder_helper.dart`
提醒辅助类，管理各种提醒事项（疫苗、驱虫、用药等）。

##### `fitness_helper.dart`
健身辅助类，管理宠物健身课程和训练记录。

##### `health_plan_helper.dart`
健康计划辅助类，管理宠物健康计划。

### `lib/models/` 数据模型目录

##### `pet.dart`
宠物数据模型，包含宠物基本信息字段。

##### `medical_record.dart`
医疗记录数据模型。

##### `pet_diary.dart`
宠物日记数据模型。

##### `conversation.dart`
对话记录数据模型。

##### `chat_history.dart`
聊天历史数据模型。

##### `expense.dart`
费用数据模型。

##### `unified_expense.dart`
统一费用数据模型。

##### `daily_cost_item.dart`
日常费用项数据模型。

##### `pet_passport.dart`
宠物护照数据模型。

##### `fitness_course.dart`
健身课程数据模型。

##### `pet_recipe.dart`
宠物食谱数据模型。

##### `dify_models.dart`
Dify AI 服务相关数据模型。

### `lib/pages/` 页面目录

#### `expense/` 费用管理
- **`expense_home_page.dart`**：费用管理主页
- **`add_expense_page.dart`**：添加费用页面
- **`expense_statistics_page.dart`**：费用统计页面

#### `daily_cost/` 日常费用
- **`daily_cost_home_page.dart`**：日常费用主页
- **`add_daily_cost_page.dart`**：添加日常费用页面

#### `unified_expense/` 统一费用
- **`unified_expense_home_page.dart`**：统一费用管理主页
- **`add_unified_expense_page.dart`**：添加统一费用页面

#### `pet_diary/` 宠物日记
- **`pet_diary_compose_page.dart`**：日记编写页面
- **`pet_diary_generating_page.dart`**：日记生成中页面
- **`pet_diary_list_page.dart`**：日记列表页面
- **`pet_diary_result_page.dart`**：日记结果展示页面

#### `pet_passport/` 宠物护照
- **`pet_passport_page.dart`**：宠物护照主页
- **`edit_pet_passport_page.dart`**：编辑宠物护照页面

#### `pet_recipe/` 宠物食谱
- **`pet_recipe_list_page.dart`**：食谱列表页面
- **`pet_recipe_detail_page.dart`**：食谱详情页面

#### `partner_fit/` 活力健身
- **`partner_fit_gym_page.dart`**：健身馆主页
- **`partner_fit_course_detail_page.dart`**：课程详情页面
- **`partner_fit_training_page.dart`**：训练页面
- **`partner_fit_completion_page.dart`**：训练完成页面
- **`partner_fit_history_page.dart`**：训练历史页面

#### `reminder/` 提醒功能
- **`intelligent_reminder_page.dart`**：智能提醒主页
- **`add_vaccine_reminder_page.dart`**：添加疫苗提醒页面
- **`add_medication_reminder_page.dart`**：添加用药提醒页面
- **`add_deworming_reminder_page.dart`**：添加驱虫提醒页面
- **`medication_checkmark_page.dart`**：用药打卡页面

#### `dog_clicker/` 训宠响片
- **`dog_clicker_screen.dart`**：训宠响片训练屏幕

#### 其他页面
- **`pet_profile_form_page.dart`**：宠物资料表单页面

### `lib/services/` 服务目录

##### `supabase_service.dart`
Supabase 服务封装，提供与 Supabase 数据库交互的接口：
- 宠物数据 CRUD（创建、读取、更新、删除）
- 医疗记录管理（医疗记录、疫苗记录、体重记录）
- 用户数据管理（用户资料、头像等）
- 对话记录和宠物日记管理
- 支持 LeanCloud 和 Supabase 双重认证

##### `supabase_edge_service.dart`
Supabase Edge Functions 服务封装，调用 Supabase Edge Functions：
- 聊天对话服务（流式模式）
- 支持 SSE（Server-Sent Events）流式响应
- 错误处理和重试机制
- 对话 ID 管理，支持多轮对话

##### `supabase_dify_service.dart`
Supabase Dify 服务封装，集成 Dify AI 对话功能。

##### `dify_service.dart`
Dify 服务直接封装，提供 Dify API 调用接口。

### `lib/utils/` 工具目录

##### `utils.dart`
通用工具函数集合。

##### `user_avatar_helper.dart`
用户头像辅助工具，处理用户头像相关逻辑。

##### `supabase_constants.dart`
Supabase 常量定义。

##### `snackbar_utils.dart`
Snackbar 工具类，提供消息提示功能。

##### `fade_snackbar.dart`
渐隐 Snackbar 组件。

### `lib/settings/` 设置目录

##### `theme.dart`
主题配置，定义应用主题样式。

##### `theme_constants.dart`
主题常量定义，包含颜色、字体等主题相关常量。

##### `about.dart`
关于页面，显示应用信息。

### `lib/widgets/` 组件目录

##### `pet_profile_card.dart`
宠物资料卡片组件，用于展示宠物基本信息。

### `lib/data/` 数据目录

##### `fitness_courses_data.dart`
健身课程数据，包含预定义的健身课程信息。

### `assets/` 资源目录

#### `logo.png`
应用 Logo 图片。

#### `icon/app_icon.png`
应用图标文件。

#### `mp3/` 音频文件目录
- **`喂食.mp3`**：喂食训练音效
- **`握手.mp3`**：握手训练音效
- **`坐下.mp3`**：坐下训练音效

### `supabase/functions/` Supabase Edge Functions

#### `chat/` 聊天功能
- **`index.ts`**：聊天 Edge Function 主文件（流式模式）
- **`index_anno.ts`**：聊天 Edge Function 注解版本

#### `diary/` 日记功能
- **`index.ts`**：日记生成 Edge Function
- **`index_v0.ts`**：日记生成 Edge Function 旧版本

### `test/` 测试目录

##### `edge_function_test.dart`
Edge Function 测试文件，用于测试 Supabase Edge Functions。

##### `simple_edge_test.dart`
简单的 Edge Function 命令行测试脚本。

##### `README_TEST.md`
测试说明文档，包含测试方法和常见问题。

##### `CURL_TEST.md`
CURL 测试文档，使用 CURL 命令测试 API。

##### `TROUBLESHOOTING_401.md`
401 错误排查文档。

### `android/` Android 平台配置

Android 平台相关配置文件、资源文件和构建脚本。

### `ios/` iOS 平台配置

iOS 平台相关配置文件、资源文件和 Xcode 项目文件。

### `web/` Web 平台配置

Web 平台相关配置文件和资源。

### `windows/` Windows 平台配置

Windows 平台相关配置文件和资源。

### `macos/` macOS 平台配置

macOS 平台相关配置文件和资源。

### `linux/` Linux 平台配置

Linux 平台相关配置文件和资源。

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Supabase 账户
- LeanCloud 账户（可选）

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd Peture
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **配置 Supabase**
   - 在 `lib/main.dart` 中配置 Supabase URL 和 Anon Key
   - 在 Supabase Dashboard 中执行 `supabase_schema.sql` 创建数据库表

4. **配置 LeanCloud**（如果使用）
   - 在 `lib/config/leancloud_config.dart` 中配置 LeanCloud 应用信息

5. **运行应用**
   ```bash
   flutter run
   ```

### 设置音效文件

运行 `setup_sounds.sh` 脚本设置训宠响片音效文件：

```bash
bash setup_sounds.sh
```

**注意**：在 Windows 系统上，可以使用 Git Bash 或 WSL 来运行此脚本。

### 数据库初始化

1. **Supabase 数据库初始化**
   - 登录 Supabase Dashboard
   - 进入 SQL Editor
   - 执行 `supabase_schema.sql` 创建所有数据表
   - 执行 `migrate_pets_table.sql` 添加宠物表扩展字段（如果表已存在）

2. **本地 SQLite 数据库**
   - 应用首次启动时会自动创建本地数据库
   - 数据库文件位置：`<应用数据目录>/conversations.db`
   - 版本管理：通过 `database_helper.dart` 中的版本号控制

## 📱 功能模块详解

### AI 智能问诊
基于 Dify RAG 技术的 AI 对话系统，支持流式和阻塞两种响应模式，提供专业的宠物健康咨询。

**技术实现**：
- 使用 Supabase Edge Functions 作为中间层
- 支持 SSE（Server-Sent Events）流式响应
- 对话历史自动保存到本地和云端
- 支持多轮对话上下文

### 电子档案
完整的宠物信息管理系统，包括：
- 基本信息（姓名、品种、年龄、性别、头像、出生日期、绝育状态、体重等）
- 医疗记录（就诊日期、症状描述、治疗方案）
- 疫苗记录（疫苗类型、接种日期、下次接种日期）
- 体重记录（体重变化追踪）
- 健康日志（综合健康事件记录）

**数据存储**：
- 云端：Supabase PostgreSQL
- 本地：SQLite（用于离线访问）

### 成长日记
AI 辅助生成精美的宠物成长日记，支持多种风格和格式。

**功能特点**：
- 支持多种风格：小红书、微博、朋友圈等
- AI 自动润色和美化
- 支持图片和文字混合
- 日记列表和详情查看

### 活力健身
宠物健身课程管理系统，包含：
- 课程列表（预定义课程数据）
- 课程详情（动作说明、训练时长、难度等级）
- 训练记录（训练日期、完成情况）
- 训练历史（历史记录查看和统计）

### 费用管理
多维度费用管理系统：
- 日常费用记录（食物、玩具、日用品等）
- 医疗费用记录（诊疗费、药品费等）
- 统一费用管理（整合所有费用类型）
- 费用统计和图表（按时间、类别、宠物统计）

**统计功能**：
- 使用 `fl_chart` 生成可视化图表
- 支持按月份、年份统计
- 支持按宠物分类统计

### 智能提醒
多种提醒功能：
- 疫苗提醒（设置疫苗类型和下次接种日期）
- 驱虫提醒（设置驱虫周期）
- 用药提醒（设置用药时间和频率）
- 智能提醒管理（查看、编辑、删除提醒）

## 💻 代码使用示例

### 1. 初始化 Supabase

```dart
// lib/main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Supabase
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );
  
  runApp(MyApp());
}
```

### 2. 使用 SupabaseService 管理宠物数据

```dart
// 创建 SupabaseService 实例
final supabaseService = SupabaseService();

// 添加宠物
final petData = {
  'type': '狗',
  'name': '小白',
  'age': '2岁',
  'gender': '公',
  'breed': '金毛',
  'birth_date': '2022-01-01',
  'neuter_status': '已绝育',
  'weight': 25.5,
};

final petId = await supabaseService.insertPet(petData);
print('宠物ID: $petId');

// 获取所有宠物
final pets = await supabaseService.getAllPets();
for (var pet in pets) {
  print('宠物: ${pet['name']}');
}

// 更新宠物信息
await supabaseService.updatePet(
  petId!,
  {'weight': 26.0},
);

// 删除宠物
await supabaseService.deletePet(petId);
```

### 3. 使用数据库助手管理本地数据

```dart
// 使用 DatabaseHelper 管理对话记录
final dbHelper = DatabaseHelper.instance;

// 插入对话
final conversation = Conversation(
  question: '我的狗狗最近不爱吃饭',
  answer: '可能是消化问题，建议...',
  timestamp: DateTime.now().toIso8601String(),
  isPinned: false,
);

await dbHelper.insertConversation(conversation);

// 获取所有对话
final conversations = await dbHelper.getAllConversations();
for (var conv in conversations) {
  print('问题: ${conv.question}');
  print('回答: ${conv.answer}');
}

// 删除对话
await dbHelper.deleteConversation(conversationId);
```

### 4. 使用 Edge Function 进行 AI 对话

```dart
// 使用 SupabaseEdgeFunctionService 进行流式对话
final edgeService = SupabaseEdgeFunctionService();

// 流式对话
final stream = edgeService.callDifyChat(
  query: '我的狗狗最近不爱吃饭，怎么办？',
  user: 'user123',
  conversationId: null, // 首次对话不需要 conversationId
);

await for (var event in stream) {
  if (event is ContentEvent) {
    // 实时接收 AI 回复片段
    print('AI: ${event.content}');
  } else if (event is DoneEvent) {
    // 对话完成
    print('对话ID: ${event.conversationId}');
    print('消息ID: ${event.messageId}');
  } else if (event is ErrorEvent) {
    // 处理错误
    print('错误: ${event.error}');
  }
}
```

### 5. 使用 Pet 模型

```dart
// 创建 Pet 对象
final pet = Pet(
  type: '狗',
  name: '小白',
  age: '2岁',
  gender: '公',
  breed: '金毛',
  birthDate: '2022-01-01',
  neuterStatus: '已绝育',
  weight: 25.5,
);

// 转换为 Map（用于数据库存储）
final petMap = pet.toMap();
print(petMap);

// 从 Map 创建 Pet 对象
final petFromMap = Pet.fromMap(petMap);
print('宠物名称: ${petFromMap.name}');
```

### 6. 添加费用记录

```dart
// 使用 ExpenseHelper 管理费用
final expenseHelper = ExpenseHelper.instance;

// 创建费用记录
final expense = Expense(
  amount: 150.0,
  category: '医疗',
  date: DateTime.now().toIso8601String(),
  petId: 1,
  petName: '小白',
  note: '打疫苗',
);

await expenseHelper.insertExpense(expense);

// 获取某个月的所有费用
final expenses = await expenseHelper.getExpensesByMonth(2025, 1);
double total = 0;
for (var exp in expenses) {
  total += exp.amount;
}
print('1月总费用: $total');
```

### 7. 使用 Provider 进行状态管理

```dart
// 定义 Provider
class PetProvider extends ChangeNotifier {
  List<Pet> _pets = [];
  
  List<Pet> get pets => _pets;
  
  Future<void> loadPets() async {
    final supabaseService = SupabaseService();
    final petsData = await supabaseService.getAllPets();
    _pets = petsData.map((p) => Pet.fromMap(p)).toList();
    notifyListeners();
  }
}

// 在 Widget 中使用
class PetListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PetProvider>(
      builder: (context, petProvider, child) {
        return ListView.builder(
          itemCount: petProvider.pets.length,
          itemBuilder: (context, index) {
            final pet = petProvider.pets[index];
            return ListTile(
              title: Text(pet.name),
              subtitle: Text(pet.breed),
            );
          },
        );
      },
    );
  }
}
```

## 🔧 开发指南

### 快速开始

#### 1. 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code（推荐安装 Flutter 和 Dart 插件）
- Git

#### 2. 克隆项目

```bash
git clone <repository-url>
cd Peture
```

#### 3. 安装依赖

```bash
flutter pub get
```

#### 4. 配置 Supabase

在 `lib/main.dart` 中配置 Supabase 连接信息：

```dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your-anon-key',
);
```

#### 5. 初始化数据库

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 进入 SQL Editor
3. 执行 `supabase_schema.sql` 创建表结构
4. 执行 `migrate_pets_table.sql` 添加扩展字段（如需要）

#### 6. 运行项目

```bash
# 查看可用设备
flutter devices

# 运行到指定设备
flutter run -d <device-id>

# 运行到 Android
flutter run -d android

# 运行到 iOS（需要 macOS）
flutter run -d ios

# 运行到 Web
flutter run -d chrome
```

### 项目结构

#### 目录结构

```
lib/
├── main.dart                 # 应用入口
├── home_screen.dart          # 主屏幕
├── login_page.dart           # 登录页面
├── chat_page.dart            # AI 聊天页面
├── config/                   # 配置文件
│   ├── api_config.dart       # API 配置
│   ├── leancloud_config.dart # LeanCloud 配置
│   └── supabase_config.dart  # Supabase 配置
├── database/                 # 数据库操作
│   ├── database_helper.dart  # 数据库核心类
│   ├── expense_helper.dart   # 费用管理
│   └── ...                   # 其他 Helper
├── models/                   # 数据模型
│   ├── pet.dart             # 宠物模型
│   ├── expense.dart         # 费用模型
│   └── ...                  # 其他模型
├── pages/                    # 页面组件
│   ├── expense/             # 费用管理页面
│   ├── pet_diary/           # 宠物日记页面
│   └── ...                  # 其他页面
├── services/                 # 服务层
│   ├── supabase_service.dart      # Supabase 服务
│   ├── supabase_edge_service.dart # Edge Function 服务
│   └── dify_service.dart     # Dify AI 服务
├── utils/                    # 工具类
│   ├── utils.dart           # 通用工具
│   └── snackbar_utils.dart  # 消息提示工具
├── widgets/                  # 可复用组件
│   └── pet_profile_card.dart # 宠物卡片组件
└── settings/                # 设置相关
    ├── theme.dart           # 主题配置
    └── theme_constants.dart # 主题常量
```

#### 命名规范

- **页面文件**：`xxx_page.dart` 或 `xxx_screen.dart`
- **组件文件**：`xxx_card.dart`、`xxx_widget.dart`
- **模型文件**：`xxx.dart`（小写，多个单词用下划线）
- **服务文件**：`xxx_service.dart`
- **工具文件**：`xxx_helper.dart` 或 `xxx_utils.dart`

#### 代码组织原则

- 遵循 Flutter 最佳实践和 Material Design 3 规范
- 使用 Provider 进行状态管理
- 数据库操作封装在 `database/` 目录
- 服务调用封装在 `services/` 目录
- UI 组件放在 `widgets/` 目录
- 数据模型定义在 `models/` 目录
- 页面组件放在 `pages/` 目录，按功能模块分类

### 代码规范

#### 命名规范

- **类名**：`PascalCase`（例如：`PetService`、`PetProfileCard`）
- **变量/方法名**：`camelCase`（例如：`selectedPet`、`loadPets()`）
- **私有成员**：`_` 前缀（例如：`_selectedPet`、`_loadData()`）
- **常量**：使用 `const` 关键字或 `UPPER_SNAKE_CASE`

#### 导入顺序

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter 包
import 'package:flutter/material.dart';

// 3. 第三方包
import 'package:provider/provider.dart';

// 4. 项目内部
import '../models/pet.dart';
```

#### Widget 结构顺序

1. 状态变量
2. 控制器
3. `initState()`
4. `dispose()`
5. 私有方法
6. `build()` 方法

**示例**：

```dart
class PetListPage extends StatefulWidget {
  const PetListPage({super.key});
  
  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  // 1. 状态变量
  List<Pet> _pets = [];
  bool _isLoading = false;
  
  // 2. 控制器
  final TextEditingController _searchController = TextEditingController();
  
  // 3. initState()
  @override
  void initState() {
    super.initState();
    _loadPets();
  }
  
  // 4. dispose()
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // 5. 私有方法
  Future<void> _loadPets() async {
    setState(() => _isLoading = true);
    try {
      final service = SupabaseService();
      final petsData = await service.getAllPets();
      if (mounted) {
        setState(() {
          _pets = petsData.map((p) => Pet.fromMap(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // 6. build() 方法
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('宠物列表')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];
                return ListTile(
                  title: Text(pet.name),
                  subtitle: Text(pet.breed),
                );
              },
            ),
    );
  }
}
```


### 数据库架构

#### 本地数据库（SQLite）

**数据库文件**：`conversations.db`

**主要表**：
- `conversations`：对话记录表
- `pet_diaries`：宠物日记表

**版本管理**：
- 通过 `database_helper.dart` 中的 `version` 字段控制
- 在 `_onUpgrade` 方法中处理版本迁移

**使用示例**（Dart 代码）：

```dart
// 获取数据库 Helper 实例（单例模式）
final helper = DatabaseHelper.instance;

// 插入对话记录
final conversation = Conversation(
  question: '我的狗狗最近不爱吃饭',
  answer: '可能是消化问题...',
  timestamp: DateTime.now().toIso8601String(),
);
await helper.insertConversation(conversation);

// 查询所有对话记录
final conversations = await helper.getAllConversations();
```

#### 云端数据库（Supabase PostgreSQL）

**主要表**：
- `users_profiles`：用户资料表
- `pets`：宠物信息表
- `medical_records`：医疗记录表
- `weight_records`：体重记录表
- `vaccine_records`：疫苗记录表
- `daily_reminders`：每日提醒表
- `conversations`：对话记录表
- `pet_diaries`：宠物日记表
- `chat_messages`：聊天消息表

**安全策略**：
- 使用 Row Level Security (RLS) 确保数据安全
- 外键约束确保数据完整性

**使用示例**（Dart 代码）：

```dart
// 创建 Supabase 服务实例
final service = SupabaseService();

// 查询所有宠物
final pets = await service.getAllPets();

// 插入新宠物
final petId = await service.insertPet({
  'name': '小白',
  'type': '狗',
  'age': '2岁',
  'gender': '公',
  'breed': '金毛',
});
```

### API 调用

**Supabase 服务**（可直接使用）：

```dart
// 导入服务类
import 'package:my_pet/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 方式1：推荐使用 SupabaseService（统一错误处理和用户ID管理）
final service = SupabaseService();
final pets = await service.getAllPets();

// 方式2：直接使用 Supabase 客户端
final supabase = Supabase.instance.client;
final response = await supabase.from('pets').select();
```

**Edge Functions（AI 对话）**（可直接使用）：

```dart
// 导入服务类和事件类
import 'package:my_pet/services/supabase_edge_service.dart';

// 创建服务实例
final edgeService = SupabaseEdgeFunctionService();

// 调用流式对话（需要先获取用户ID）
final userId = await SupabaseService().currentUserId ?? 'anonymous';
final stream = edgeService.callDifyChat(
  query: '我的狗狗最近不爱吃饭，怎么办？',
  user: userId,
  conversationId: conversationId, // 可选，用于多轮对话
);

// 监听流式响应
await for (var event in stream) {
  if (event is ContentEvent) {
    // 实时接收 AI 回复片段
    print('AI: ${event.content}');
    // 更新 UI 显示回复内容
  } else if (event is DoneEvent) {
    // 对话完成，保存 conversationId 用于下次对话
    print('对话ID: ${event.conversationId}');
    print('消息ID: ${event.messageId}');
  } else if (event is ErrorEvent) {
    // 处理错误
    print('错误: ${event.error}');
    // 显示错误提示给用户
  }
}
```

**注意事项**：
- 使用前需要先初始化 Supabase（在 `main.dart` 中已完成）
- Edge Functions 需要确保 Supabase Edge Function 已部署
- 流式对话需要在异步方法中使用 `await for` 循环

### 添加新功能

> **说明**：不是所有步骤都是必需的，根据功能需求选择需要的步骤。

#### 步骤 1：规划功能（必需）

1. **确定功能需求**：明确要添加什么功能
2. **设计数据模型**：确定需要哪些数据字段（如果功能需要存储数据）
3. **设计 UI 界面**：规划页面布局和交互
4. **确定数据存储**：选择本地数据库或云端数据库

#### 步骤 2：创建数据模型（如需要存储数据）

```dart
// models/new_feature.dart
class NewFeature {
  final String? id;
  final String name;
  final DateTime createdAt;
  
  NewFeature({
    this.id,
    required this.name,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  factory NewFeature.fromMap(Map<String, dynamic> map) {
    return NewFeature(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
```

#### 步骤 3：创建数据库 Helper（仅本地数据库需要）

如果功能使用**本地 SQLite 数据库**存储数据，需要创建 Helper：

```dart
// database/new_feature_helper.dart
import 'package:sqflite/sqflite.dart';
import '../models/new_feature.dart';
import 'database_helper.dart';

class NewFeatureHelper {
  static final NewFeatureHelper instance = NewFeatureHelper._init();
  NewFeatureHelper._init();
  
  Future<Database> get database => DatabaseHelper.instance.database;
  
  Future<int> insert(NewFeature feature) async {
    final db = await database;
    return await db.insert('new_features', feature.toMap());
  }
  
  Future<List<NewFeature>> getAll() async {
    final db = await database;
    final maps = await db.query('new_features');
    return maps.map((map) => NewFeature.fromMap(map)).toList();
  }
}
```

**注意**：如果只使用云端数据库，可以跳过此步骤。

#### 步骤 4：创建服务类（仅云端数据库需要）

```dart
// services/new_feature_service.dart
class NewFeatureService {
  final _supabase = Supabase.instance.client;
  
  Future<List<NewFeature>> getAll() async {
    final response = await _supabase
        .from('new_features')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((map) => NewFeature.fromMap(map))
        .toList();
  }
}
```

#### 步骤 5：创建页面（必需）

所有功能都需要创建页面：

```dart
// pages/new_feature/new_feature_page.dart
import 'package:flutter/material.dart';
import '../../models/new_feature.dart';
import '../../database/new_feature_helper.dart'; // 如果使用本地数据库
// import '../../services/new_feature_service.dart'; // 如果使用云端数据库

class NewFeaturePage extends StatefulWidget {
  const NewFeaturePage({super.key});
  
  @override
  State<NewFeaturePage> createState() => _NewFeaturePageState();
}

class _NewFeaturePageState extends State<NewFeaturePage> {
  List<NewFeature> _features = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }
  
  Future<void> _loadFeatures() async {
    setState(() => _isLoading = true);
    try {
      // 使用本地数据库
      final helper = NewFeatureHelper.instance;
      _features = await helper.getAll();
      
      // 或使用云端数据库
      // final service = NewFeatureService();
      // _features = await service.getAll();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新功能')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feature = _features[index];
                return ListTile(
                  title: Text(feature.name),
                );
              },
            ),
    );
  }
}
```

#### 步骤 6：添加到导航（如需要在主界面显示）

```dart
// home_screen.dart
SphereItemData(
  title: '新功能',
  icon: Icons.new_releases,
  gradient: AppColors.natureGradient,
  page: const NewFeaturePage(),
),
```

#### 步骤 7：数据库迁移（仅云端数据库需要新表时）

如果功能使用**云端数据库**且需要**创建新表**，需要执行 SQL 迁移：

```sql
-- 在 Supabase Dashboard → SQL Editor 中执行
CREATE TABLE IF NOT EXISTS new_features (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_new_features_user_id 
  ON new_features(user_id);

-- 启用 RLS（Row Level Security）
ALTER TABLE new_features ENABLE ROW LEVEL SECURITY;

-- 创建 RLS 策略（允许用户访问自己的数据）
CREATE POLICY "Users can view own new_features"
  ON new_features FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own new_features"
  ON new_features FOR INSERT
  WITH CHECK (true);
```

**注意**：
- 如果使用现有表，可以跳过此步骤
- 如果只使用本地数据库，可以跳过此步骤

---

### 步骤选择指南

| 功能类型 | 必需步骤 | 可选步骤 |
|---------|---------|---------|
| **纯 UI 功能**（不存储数据） | 步骤1、步骤5 | 步骤6（如需在主界面显示） |
| **本地数据功能** | 步骤1、步骤2、步骤3、步骤5 | 步骤6 |
| **云端数据功能** | 步骤1、步骤2、步骤4、步骤5、步骤7 | 步骤6 |
| **混合存储功能** | 步骤1、步骤2、步骤3、步骤4、步骤5、步骤7 | 步骤6 |

### 调试技巧

#### 使用 Flutter DevTools

```bash
# 启动应用并打开 DevTools
flutter run --devtools

# 或手动打开
flutter pub global activate devtools
flutter pub global run devtools
```

**DevTools 功能**：
- Widget Inspector：查看 Widget 树
- Performance：性能分析
- Memory：内存使用情况
- Network：网络请求监控

#### 断点调试

在 VS Code 或 Android Studio 中：
1. 在代码行号左侧点击设置断点
2. 按 `F5` 启动调试
3. 使用 `F10`（单步跳过）、`F11`（单步进入）调试

#### 日志输出

```dart
// 使用 debugPrint（推荐，自动截断长字符串）
debugPrint('调试信息');

// 使用条件编译
if (kDebugMode) {
  print('仅在调试模式下打印');
}
```

#### 网络请求调试

在 Service 中添加日志：

```dart
print('📤 请求: ${request.method} ${request.url}');
print('📦 请求体: ${request.body}');
print('📥 响应: ${response.statusCode}');
```

#### 数据库调试

```dart
// 查看本地数据库表
final db = await DatabaseHelper.instance.database;
final tables = await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type='table'"
);
print('数据库表: $tables');
```

### 测试

#### 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/models/pet_test.dart

# 生成测试覆盖率报告
flutter test --coverage
```

#### 编写测试

```dart
// test/models/pet_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pet/models/pet.dart';

void main() {
  group('Pet Model', () {
    test('fromMap 应该正确解析数据', () {
      final map = {'id': '1', 'name': '小白', 'type': '狗'};
      final pet = Pet.fromMap(map);
      expect(pet.name, '小白');
    });
  });
}
```

### 常见问题

#### 依赖冲突

```bash
# 查看依赖树
flutter pub deps

# 清理并重新获取
flutter clean
flutter pub get
```

#### 构建错误

```bash
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 重新构建
flutter build apk  # Android
flutter build ios  # iOS
```


### 状态管理（Provider）

#### 定义 Provider

这段代码展示了如何创建一个 Provider 类来管理宠物数据的状态。Provider 用于在应用的不同部分共享和更新数据。

**代码说明**：

```dart
// 导入必要的包
import 'package:flutter/foundation.dart';
import '../models/pet.dart';
import '../services/supabase_service.dart';

// 定义 Provider 类，继承 ChangeNotifier
// ChangeNotifier 提供了 notifyListeners() 方法，用于通知监听者状态已改变
class PetProvider extends ChangeNotifier {
  // 私有状态变量（使用 _ 前缀）
  List<Pet> _pets = [];        // 宠物列表
  bool _isLoading = false;     // 加载状态
  
  // 公开的 getter，允许外部读取状态（但不能直接修改）
  List<Pet> get pets => _pets;
  bool get isLoading => _isLoading;
  
  // 加载宠物的方法
  Future<void> loadPets() async {
    // 1. 设置加载状态为 true
    _isLoading = true;
    notifyListeners(); // 通知所有监听者：状态已改变
    
    try {
      // 2. 从云端获取数据
      final service = SupabaseService();
      final petsData = await service.getAllPets();
      
      // 3. 将数据转换为 Pet 对象列表
      _pets = petsData.map((p) => Pet.fromMap(p)).toList();
    } finally {
      // 4. 无论成功或失败，都要设置加载状态为 false
      _isLoading = false;
      notifyListeners(); // 再次通知：状态已改变
    }
  }
  
  // 可以添加更多方法，例如：
  void addPet(Pet pet) {
    _pets.add(pet);
    notifyListeners(); // 状态改变后必须通知
  }
  
  void removePet(String petId) {
    _pets.removeWhere((p) => p.id == petId);
    notifyListeners();
  }
}
```

**作用**：
- 集中管理宠物相关的状态（列表、加载状态等）
- 提供统一的数据访问接口
- 当状态改变时自动通知所有使用该数据的 Widget 更新
- 避免在多个 Widget 中重复管理相同的数据

#### 注册 Provider

在 `main.dart` 中注册：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PetProvider()),
  ],
  child: MyApp(),
)
```

#### 使用 Provider

```dart
// 方式1：Consumer（推荐，性能更好）
Consumer<PetProvider>(
  builder: (context, provider, child) {
    return Text('${provider.pets.length} 只宠物');
  },
)

// 方式2：context.watch（简洁）
final count = context.watch<PetProvider>().pets.length;

// 方式3：调用方法（不触发重建）
context.read<PetProvider>().loadPets();

// 方式4：Selector（只监听部分状态，性能最优）
Selector<PetProvider, int>(
  selector: (_, provider) => provider.pets.length,
  builder: (context, count, child) => Text('$count 只宠物'),
)
```

### 数据库操作

#### 本地 SQLite 操作

```dart
// 使用 Helper（单例模式）
final helper = PetHelper.instance;

// 插入数据
await helper.insertPet(pet);

// 查询数据
final pets = await helper.getAllPets();

// 更新数据
await helper.updatePet(pet);

// 删除数据
await helper.deletePet(petId);
```

#### 云端 Supabase 操作

```dart
final service = SupabaseService();

// 插入数据
final petId = await service.insertPet({
  'name': '小白',
  'type': '狗',
  'age': '2岁',
  'gender': '公',
  'breed': '金毛',
});

// 查询数据
final pets = await service.getAllPets();

// 更新数据
await service.updatePet(petId, {'name': '小黑'});

// 删除数据
await service.deletePet(petId);
```

#### 数据库版本升级

在 `database_helper.dart` 的 `_onUpgrade` 方法中处理：

```dart
Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // 添加新表
    await db.execute('CREATE TABLE ...');
  }
  if (oldVersion < 3) {
    // 添加新列
    await db.execute('ALTER TABLE pets ADD COLUMN ...');
  }
}
```


## 📝 注意事项

### 配置相关
1. **Supabase 配置**：
   - 确保在 `lib/main.dart` 中正确配置 Supabase URL 和 Anon Key
   - URL 格式：`https://your-project.supabase.co`
   - Anon Key 可以从 Supabase Dashboard → Settings → API 获取
   - 生产环境建议使用环境变量管理敏感信息

2. **LeanCloud 认证**：
   - 如果使用 LeanCloud 认证，需要在 `lib/config/leancloud_config.dart` 中配置应用信息
   - 需要配置 App ID 和 App Key
   - 支持邮箱、手机号等多种登录方式

3. **Dify API 配置**：
   - Edge Functions 需要配置 Dify API Key
   - 在 Supabase Dashboard → Edge Functions → Settings 中设置环境变量
   - 变量名：`DIFY_API_KEY`

### 资源文件
4. **音效文件**：
   - 训宠响片功能需要音效文件（MP3 格式）
   - 文件位置：`assets/mp3/`
   - 可通过 `setup_sounds.sh` 脚本快速设置
   - 文件名必须与训练项目名称完全一致（如：`喂食.mp3`）

5. **图片资源**：
   - Logo 文件：`assets/logo.png`（用于启动页）
   - 应用图标：`assets/icon/app_icon.png`
   - 使用 `flutter_launcher_icons` 生成各平台图标

### 数据库相关
6. **数据库迁移**：
   - 如果数据库结构有更新，需要执行相应的迁移脚本
   - Supabase：在 Dashboard 的 SQL Editor 中执行迁移脚本
   - 本地 SQLite：通过 `database_helper.dart` 的 `_onUpgrade` 方法处理

7. **数据备份**：
   - 重要数据建议定期备份
   - Supabase 提供自动备份功能
   - 本地数据库文件位于应用数据目录

### 部署相关
8. **Edge Functions**：
   - 确保 Supabase Edge Functions 已正确部署
   - 部署命令：`supabase functions deploy <function-name>`
   - 检查函数状态：Supabase Dashboard → Edge Functions

9. **平台特定配置**：
   - Android：检查 `android/app/build.gradle` 中的配置
   - iOS：检查 `ios/Runner/Info.plist` 中的权限配置
   - Web：检查 `web/index.html` 中的配置

### 性能优化
10. **图片优化**：
    - 建议使用压缩后的图片
    - 宠物头像建议使用圆形裁剪
    - 考虑使用图片缓存机制

11. **网络请求**：
    - 使用连接池管理 HTTP 连接
    - 实现请求重试机制
    - 添加超时处理

### 安全相关
12. **API Key 保护**：
    - 不要在代码中硬编码 API Key
    - 使用环境变量或配置文件管理
    - 生产环境使用 Service Role Key 时要格外小心

13. **数据加密**：
    - 敏感数据使用 `flutter_secure_storage` 存储
    - 传输数据使用 HTTPS
    - 实现数据加密和签名验证


## 📞 联系方式

### 项目维护者
- **项目名称**：Peture（智宠合生）
- **GitHub**：https://github.com/PetureZCHS/Peture



## 📚 相关文档

- [Flutter 官方文档](https://flutter.dev/docs)
- [Supabase 文档](https://supabase.com/docs)
- [Dify 文档](https://docs.dify.ai)
- [LeanCloud 文档](https://leancloud.cn/docs)

---

**最后更新**：2025年11月

**版本**：1.0.0

