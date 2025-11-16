# 🚀 快速开始：将 Chat Page 迁移到 Supabase Dify

## ✅ 检查清单

按照以下步骤完成迁移：

### 第 1 步：获取 Supabase 配置

- [ ] 登录 [Supabase Dashboard](https://supabase.com/dashboard)
- [ ] 选择项目 `tcftpcvcldfudzxgemdh`
- [ ] 进入 **Settings** → **API**
- [ ] 复制 **Project URL**
- [ ] 复制 **anon** **public** key

### 第 2 步：配置项目

- [ ] 打开 `lib/config/supabase_config.dart`
- [ ] 将 `anonKey` 替换为您的实际 anon key
- [ ] 确认 `difyChatFunctionName` 与您部署的函数名一致（`chat`）

### 第 3 步：初始化 Supabase

在 `lib/main.dart` 中添加初始化代码：

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Supabase
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(MyApp());
}
```

### 第 4 步：更新 Chat Page

在 `lib/chat_page.dart` 中：

**找到这行：**
```dart
import 'api_service.dart';
```

**替换为：**
```dart
import 'services/supabase_dify_service.dart';
```

**找到这行：**
```dart
final ApiService _apiService = ApiService();
```

**替换为：**
```dart
final SupabaseDifyService _apiService = SupabaseDifyService();
```

### 第 5 步：测试

- [ ] 运行 `flutter pub get` 安装依赖
- [ ] 运行应用
- [ ] 在聊天页面发送消息
- [ ] 验证是否看到流式响应
- [ ] 检查多轮对话是否正常工作

## 📝 代码对比

### 修改前：
```dart
// chat_page.dart
import 'api_service.dart';

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase> {
  final ApiService _apiService = ApiService();
  
  // ... 其他代码不变 ...
}
```

### 修改后：
```dart
// chat_page.dart
import 'services/supabase_dify_service.dart';

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase> {
  final SupabaseDifyService _apiService = SupabaseDifyService();
  
  // ... 其他代码不变 ...
}
```

## 🎯 关键点

✅ **完全兼容**: `SupabaseDifyService` 与 `ApiService` 接口完全相同
✅ **最小修改**: 只需改 2-3 行代码
✅ **无需改动**: `getChatStream` 方法调用方式完全不变
✅ **事件一致**: `ContentEvent`, `DoneEvent`, `ErrorEvent` 完全相同

## 🔍 验证步骤

### 1. 检查控制台输出

正常情况下应该看到：
```
📦 Sending request to Edge Function...
📨 Received SSE data: {"event":"message","answer":"您好..."}
✅ Message stream completed
```

### 2. 检查功能

- [ ] 发送消息有打字机效果
- [ ] 多轮对话 conversation_id 保持不变
- [ ] 错误处理正常工作
- [ ] 重新生成功能正常

## ⚠️ 常见问题

### Q: 提示 "User not authenticated"

**A:** 检查：
1. `supabase_config.dart` 中的 anon key 是否正确
2. `main.dart` 中是否正确初始化了 Supabase

### Q: 没有收到流式响应

**A:** 检查：
1. Edge Function 是否正确部署
2. Dify API Key 是否在 Supabase Dashboard 中正确设置
3. 网络连接是否正常

### Q: 编译错误

**A:** 运行：
```bash
flutter clean
flutter pub get
flutter run
```

## 📂 完整文件列表

您应该有以下新文件：

```
lib/
├── config/
│   └── supabase_config.dart          # ✅ 新建：配置文件
├── services/
│   ├── supabase_dify_service.dart    # ✅ 新建：Dify 服务
│   └── dify_chat_service.dart        # (可选，更完整的实现)
├── models/
│   └── dify_models.dart              # (可选，数据模型)
├── chat_page.dart                     # ✏️ 修改：更新 import
└── main.dart                          # ✏️ 修改：添加初始化

项目根目录/
├── MIGRATION_GUIDE.md                 # ✅ 新建：迁移指南
├── QUICKSTART.md                      # ✅ 当前文件
└── supabase_flutter_guide.md         # ✅ 新建：完整文档
```

## 🎉 完成！

迁移完成后，您的聊天功能将：
- ✅ 更安全（API Key 不暴露）
- ✅ 更灵活（可扩展 Edge Function）
- ✅ 更易监控（Supabase Dashboard）
- ✅ 完全兼容（原有功能不变）

---

**需要帮助？**
- 查看 [完整迁移指南](./MIGRATION_GUIDE.md)
- 查看 [详细文档](./supabase_flutter_guide.md)
- 检查 [常见问题](#-常见问题)
