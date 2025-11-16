# Chat Page 迁移到 Supabase Dify 指南

## 📝 概述

本文档说明如何将现有的 `chat_page.dart` 从直接调用 API 迁移到使用 Supabase Edge Function 调用 Dify。

## 🔧 配置步骤

### 1. 获取 Supabase Anon Key

1. 登录 Supabase Dashboard: https://supabase.com/dashboard
2. 选择您的项目：`tcftpcvcldfudzxgemdh`
3. 进入 **Settings** → **API**
4. 复制 **anon** **public** key

### 2. 更新配置

在 `lib/services/supabase_dify_service.dart` 中，将您的 anon key 替换：

```dart
static const String _supabaseAnonKey = 'YOUR_ANON_KEY_HERE'; // ← 替换这里
```

### 3. 在 main.dart 中初始化 Supabase

在您的 `main.dart` 文件中添加 Supabase 初始化：

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Supabase
  await Supabase.initialize(
    url: 'https://tcftpcvcldfudzxgemdh.supabase.co',
    anonKey: 'YOUR_ANON_KEY_HERE', // 从 Dashboard 获取
  );
  
  runApp(MyApp());
}
```

## 🔄 迁移 chat_page.dart

### 方案一：最小修改（推荐）

只需要修改 `import` 语句和服务实例化：

**原代码：**
```dart
import 'api_service.dart';

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase> {
  // ...
  final ApiService _apiService = ApiService();
  // ...
}
```

**新代码：**
```dart
import 'services/supabase_dify_service.dart';

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase> {
  // ...
  final SupabaseDifyService _apiService = SupabaseDifyService();
  // ...
}
```

✅ **就这么简单！** 因为 `SupabaseDifyService` 完全兼容 `ApiService` 的接口，所以其他代码无需修改。

### 方案二：重命名服务（可选）

如果您想更明确地表示使用的是 Dify 服务：

```dart
import 'services/supabase_dify_service.dart';

class _ChatPageWithDatabaseState extends State<ChatPageWithDatabase> {
  // ...
  final SupabaseDifyService _difyService = SupabaseDifyService();
  
  // 然后在使用处：
  final stream = _difyService.getChatStream(
    userMessage: messageText,
    userId: _userId,
    conversationId: _conversationId,
  );
  // ...
}
```

## 📊 对比说明

### 事件模型（完全兼容）

两个服务使用相同的事件模型：

| 事件类型 | 说明 | 触发时机 |
|---------|------|---------|
| `ContentEvent` | AI 返回新的文本片段 | 实时流式输出 |
| `DoneEvent` | AI 完成回复 | 对话结束 |
| `ErrorEvent` | 发生错误 | 请求失败或解析错误 |

### API 对比

| 功能 | 原 ApiService | 新 SupabaseDifyService |
|------|--------------|----------------------|
| 流式响应 | ✅ | ✅ |
| 打字机效果支持 | ✅ | ✅ |
| 会话管理 | ✅ | ✅ |
| 错误处理 | ✅ | ✅ |
| 数据来源 | 直接 API | Supabase Edge Function |

## 🧪 测试步骤

### 1. 验证 Edge Function 部署

在浏览器或 Postman 中测试：

```bash
POST https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat
Headers:
  Authorization: Bearer YOUR_ANON_KEY
  Content-Type: application/json
Body:
{
  "query": "你好",
  "user": "test-user",
  "response_mode": "streaming"
}
```

应该看到 SSE 格式的流式响应。

### 2. 在 Flutter 中测试

运行您的应用，在聊天页面：
1. 发送一条消息
2. 观察是否有打字机效果
3. 检查控制台是否有错误
4. 验证 conversation_id 是否正确传递

### 3. 调试技巧

如果遇到问题，可以在 `supabase_dify_service.dart` 中添加调试日志：

```dart
// 在 startStreaming() 方法中添加：
print('🚀 Sending request to: $functionUrl');
print('📦 Request body: ${jsonEncode(requestBody)}');

// 在收到数据时添加：
print('📨 Received data: $dataString');
```

## ⚠️ 常见问题

### Q1: 认证错误

**错误**: `401 Unauthorized`

**解决**: 
- 检查 anon key 是否正确
- 确保 Edge Function 的 CORS 配置正确
- 验证 Supabase 项目 URL 是否正确

### Q2: 流式响应不工作

**错误**: 没有收到流式数据

**解决**:
- 确认 Edge Function 返回了正确的 `Content-Type: text/event-stream` 头
- 检查 Dify API Key 是否正确设置
- 查看 Edge Function 日志（在 Supabase Dashboard 中）

### Q3: conversation_id 未保持

**错误**: 每次对话都是新会话

**解决**:
- 确保 `_conversationId` 变量在 State 中正确保存
- 检查 `DoneEvent` 中是否正确更新了 conversation_id

## 🎯 优势对比

### 使用 Supabase Edge Function 的优势：

1. **✅ 安全性**: API Key 不暴露在客户端
2. **✅ 灵活性**: 可以在 Edge Function 中添加业务逻辑
3. **✅ 监控**: Supabase Dashboard 提供完整的日志和监控
4. **✅ 成本**: Edge Function 有免费额度
5. **✅ 扩展性**: 未来可以轻松添加认证、限流等功能

### 直接调用 API 的问题：

1. ❌ API Key 暴露在客户端代码中
2. ❌ 难以添加服务器端逻辑
3. ❌ 缺少统一的监控和日志
4. ❌ 难以实现用户级别的访问控制

## 🔜 下一步

完成迁移后，您可以：

1. **添加用户认证**: 集成 Supabase Auth
2. **保存对话历史**: 使用 Supabase Database
3. **添加文件上传**: 支持 Dify 的文件功能
4. **实现速率限制**: 在 Edge Function 中添加限流逻辑
5. **添加使用统计**: 记录 API 调用次数和成本

## 📚 相关文档

- [Supabase Edge Functions 文档](https://supabase.com/docs/guides/functions)
- [Dify API 文档](https://docs.dify.ai/api)
- [完整实现指南](./supabase_flutter_guide.md)

---

**需要帮助？** 如有问题，请查看上面的常见问题部分或参考完整文档。
