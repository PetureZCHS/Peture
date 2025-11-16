# 🔍 401 错误诊断指南

## 当前问题

Edge Function 返回 401 错误：
```json
{
  "error": "Access token is invalid",
  "status": 401,
  "code": "unauthorized"
}
```

## 🛠️ 解决方案

### 方案 1：在 Supabase Dashboard 修改 Edge Function 设置（推荐）

1. **登录 Supabase Dashboard**
   - 访问：https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh

2. **进入 Edge Functions**
   - 左侧菜单 → **Edge Functions**
   - 找到 `chat` 函数

3. **修改函数设置**
   - 点击函数名进入详情页
   - 点击 **Settings** 标签
   - 查找 **Verify JWT** 或类似的认证设置
   - **关闭 JWT 验证**（因为我们使用的是公开 API）

4. **或者修改 CORS 和认证**
   - 确保 Edge Function 代码中正确处理了认证
   - 检查是否需要特定的请求头

### 方案 2：修改 Edge Function 代码

在您的 Edge Function 代码中，确保正确处理请求：

```typescript
Deno.serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ⚠️ 不验证认证，直接处理请求
  try {
    const requestBody = await req.json()
    
    // ... 您的 Dify API 调用逻辑 ...
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
```

### 方案 3：使用正确的认证方式

如果 Edge Function 必须启用认证，尝试不同的请求头组合：

**选项 A: 只用 apikey**
```bash
curl -X POST https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s" \
  -d '{"query":"Hello","user":"test-user","response_mode":"blocking"}'
```

**选项 B: 使用 service_role key**
- 从 Supabase Dashboard → Settings → API 获取 `service_role` key
- ⚠️ 注意：service_role key 不应暴露在客户端！只用于测试

### 方案 4：检查 Edge Function 日志

1. **查看日志**
   - Supabase Dashboard → Edge Functions → chat
   - 点击 **Logs** 标签
   - 查看最近的请求日志

2. **查找错误信息**
   - 看是否有详细的错误堆栈
   - 确认是否是认证问题还是其他问题

## 🎯 推荐操作步骤

1. **首先尝试**：在 Supabase Dashboard 关闭 Edge Function 的 JWT 验证
2. **如果不行**：查看 Edge Function 日志，了解具体错误
3. **最后**：修改 Edge Function 代码，移除认证验证（仅用于测试）

## 📝 临时测试方案

在解决认证问题前，您可以：

1. **使用 Postman 或类似工具**
   - 手动测试不同的请求头组合
   - 更容易看到详细的响应信息

2. **直接测试 Dify API**
   - 绕过 Edge Function
   - 确认 Dify 服务本身是否正常工作
   ```bash
   curl -X POST https://api.dify.ai/v1/chat-messages \
     -H "Authorization: Bearer YOUR_DIFY_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"query":"Hello","user":"test-user","response_mode":"blocking"}'
   ```

## 🔄 下一步

请尝试：
1. 在 Supabase Dashboard 中检查 Edge Function 设置
2. 查看 Edge Function 日志
3. 告诉我您看到的具体错误信息

然后我可以帮您进一步诊断和解决问题！
