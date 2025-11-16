# 测试 Supabase Edge Function 的命令

## 使用 curl 测试（最简单）

### 测试阻塞模式
```bash
curl -X POST https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s" \
  -d '{"query":"Hello","user":"test-user","response_mode":"blocking"}'
```

### 测试流式模式
```bash
curl -X POST https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s" \
  -d '{"query":"Hello","user":"test-user","response_mode":"streaming"}'
```

## PowerShell 版本

### 测试阻塞模式
```powershell
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s"
}

$body = @{
    query = "Hello"
    user = "test-user"
    response_mode = "blocking"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat" -Method Post -Headers $headers -Body $body
```

## 401 错误排查

如果收到 401 错误，请检查：

1. **Edge Function 设置**
   - 在 Supabase Dashboard → Edge Functions → chat
   - 点击 Settings
   - 确保没有启用 "Verify JWT"（或者正确配置了认证）

2. **尝试不带 Authorization 头**
   ```bash
   curl -X POST https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat \
     -H "Content-Type: application/json" \
     -d '{"query":"Hello","user":"test-user","response_mode":"blocking"}'
   ```

3. **检查 CORS 设置**
   - Edge Function 代码中应该有 CORS 头
   - 确保 Edge Function 正确部署

4. **查看函数日志**
   - Supabase Dashboard → Edge Functions → chat → Logs
   - 查看详细错误信息
