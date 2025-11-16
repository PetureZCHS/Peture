# Edge Function 测试说明

## 🎯 目的

这些测试文件用于验证您在 Supabase 上部署的 chat Edge Function 是否正常工作。

## 📁 测试文件

### 1. `simple_edge_test.dart` - 命令行测试（推荐）

**最简单、最快速的测试方式！**

#### 使用步骤：

1. **获取 Anon Key**
   - 登录 [Supabase Dashboard](https://supabase.com/dashboard)
   - 选择项目 `tcftpcvcldfudzxgemdh`
   - 进入 **Settings** → **API**
   - 复制 **anon** **public** key

2. **配置测试脚本**
   ```dart
   // 打开 test/simple_edge_test.dart
   // 找到这行并替换：
   const String ANON_KEY = 'YOUR_ANON_KEY_HERE';
   ```

3. **运行测试**
   ```bash
   dart test/simple_edge_test.dart
   ```

4. **查看结果**
   - ✅ 如果成功，会看到完整的响应内容
   - ❌ 如果失败，会显示详细的错误信息

#### 输出示例：

```
🚀 开始测试 Supabase Edge Function...

📦 测试 1: 阻塞模式 (Blocking)
------------------------------------------------------------
📤 发送请求...
📥 收到响应: HTTP 200
✅ 成功!

响应内容:
------------------------------------------------------------
{
  "event": "message_end",
  "answer": "您好！我是一个AI助手...",
  "conversation_id": "abc123...",
  "message_id": "msg456..."
}

============================================================

📡 测试 2: 流式模式 (Streaming)
------------------------------------------------------------
📤 发送请求...
📥 收到响应: HTTP 200
✅ 开始接收流式数据...

您好！我是一个AI助手...

✅ 流式响应完成!
   总共收到 15 个数据块
   完整答案长度: 85 字符
```

---

### 2. `edge_function_test.dart` - Flutter UI 测试

**带界面的测试工具，适合调试！**

#### 使用步骤：

1. **配置 Anon Key**
   ```dart
   // 打开 test/edge_function_test.dart
   // 找到这行并替换：
   static const String _anonKey = 'YOUR_ANON_KEY_HERE';
   ```

2. **集成到应用中**
   
   在您的 `main.dart` 中添加测试入口：
   ```dart
   import 'test/edge_function_test.dart';
   
   // 在某个菜单或设置页面添加：
   ListTile(
     title: Text('测试 Edge Function'),
     trailing: Icon(Icons.arrow_forward),
     onTap: () {
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (context) => EdgeFunctionTestPage(),
         ),
       );
     },
   )
   ```

3. **运行应用并测试**
   - 点击 "测试阻塞模式" 或 "测试流式模式"
   - 查看详细的请求和响应信息
   - 结果可以复制和分享

---

## 🔍 测试内容

### 阻塞模式测试
- 发送问题："你好，请简单介绍一下你自己"
- 等待完整响应
- 验证 JSON 格式
- 检查 `answer` 和 `conversation_id` 字段

### 流式模式测试
- 发送问题："你好，请用一句话介绍你自己"
- 实时接收 SSE 数据流
- 统计数据块数量
- 验证完整答案

---

## ⚠️ 常见问题

### Q1: 提示 "401 Unauthorized"

**原因**: Anon Key 配置错误

**解决**:
1. 确认复制的是 **anon** **public** key（不是 service_role key）
2. 检查是否有多余的空格或换行
3. 确保 key 格式类似：`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### Q2: 提示 "404 Not Found"

**原因**: Edge Function 未部署或名称错误

**解决**:
1. 检查 Supabase Dashboard → Edge Functions
2. 确认函数名称是 `chat`（注意大小写）
3. 确认函数状态是 **Active**

### Q3: 提示 "500 Internal Server Error"

**原因**: Edge Function 内部错误

**解决**:
1. 在 Supabase Dashboard 查看函数日志
2. 检查 `DIFY_API_KEY` 环境变量是否设置
3. 确认 Dify API 是否正常工作

### Q4: 阻塞模式成功，流式模式失败

**原因**: SSE 流处理问题

**解决**:
1. 检查网络是否支持长连接
2. 查看 Edge Function 是否正确返回 `text/event-stream`
3. 确认没有代理或防火墙拦截

### Q5: 超时或连接失败

**原因**: 网络问题或 Dify API 响应慢

**解决**:
1. 检查网络连接
2. 尝试使用简单的测试问题
3. 增加超时时间

---

## 📊 验证标准

### ✅ 测试通过的标志：

**阻塞模式**:
- HTTP 状态码: 200
- 响应格式: JSON
- 包含字段: `answer`, `conversation_id`, `message_id`
- `answer` 有合理的内容

**流式模式**:
- HTTP 状态码: 200
- Content-Type: text/event-stream
- 收到多个 `data:` 开头的数据块
- 最后收到 `message_end` 事件
- 能拼接出完整答案

---

## 🎓 进阶测试

### 测试多轮对话

修改测试代码，保存第一次的 `conversation_id`，在第二次请求中传入：

```dart
final firstResponse = await testBlocking();
final conversationId = jsonDecode(firstResponse)['conversation_id'];

// 第二次请求
final body = jsonEncode({
  'query': '你刚才说了什么？',
  'user': 'test-user',
  'response_mode': 'blocking',
  'conversation_id': conversationId,  // ← 传入 conversation_id
});
```

### 测试错误处理

尝试发送无效请求：

```dart
// 缺少必填字段
final body = jsonEncode({
  'query': '你好',
  // 'user': 'test-user',  // ← 故意注释掉
  'response_mode': 'blocking',
});
```

应该收到 400 错误和有意义的错误消息。

---

## 📝 测试记录

建议记录测试结果：

```
日期: 2025-11-05
测试人: [您的名字]

阻塞模式:
- 状态: ✅ / ❌
- 响应时间: [X] 秒
- 备注: [任何特殊情况]

流式模式:
- 状态: ✅ / ❌
- 数据块数: [X]
- 响应时间: [X] 秒
- 备注: [任何特殊情况]
```

---

## 🚀 下一步

测试成功后，您可以：

1. **集成到应用**: 按照 `QUICKSTART.md` 将服务集成到 `chat_page.dart`
2. **完善功能**: 添加用户认证、历史记录等
3. **监控优化**: 在 Supabase Dashboard 监控使用情况

---

需要帮助？查看：
- [快速开始指南](../QUICKSTART.md)
- [完整迁移指南](../MIGRATION_GUIDE.md)
- [详细文档](../supabase_flutter_guide.md)
