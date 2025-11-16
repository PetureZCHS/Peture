# Supabase 邮箱登录调试指南

## 🔍 当前问题

邮箱登录功能无法正常工作。根据 Supabase 文档，可能的原因包括：

## ⚠️ 常见问题和解决方案

### 1. 邮件服务未配置

**问题**：Supabase 默认使用内置的邮件服务，但在生产环境中需要配置自定义 SMTP。

**解决方案**：
1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 进入项目设置 → Authentication → Email Auth
3. 检查邮件服务配置：
   - 如果使用默认服务，可能有发送限制
   - 建议配置自定义 SMTP（如 SendGrid、Resend、AWS SES 等）

### 2. 认证提供商未启用

**步骤**：
1. 进入 **Authentication** → **Providers**
2. 确保 **Email** 提供商已启用
3. 检查以下设置：
   - ✅ Enable Email provider
   - ✅ Confirm email（新用户需要确认邮箱）
   - ✅ Enable Email OTP

### 3. 可发布密钥格式错误

**问题**：你提供的密钥是 `sb_publishable_6vpdGAb3VfsM3zKqZIv9ug_nSOFgl2j`

**正确的密钥格式**：
- Supabase 的 anon key 应该是 JWT 格式（很长的字符串）
- 位置：Dashboard → Settings → API → Project API keys → `anon` `public`

**修复步骤**：
1. 进入 https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/settings/api
2. 复制 **anon** / **public** key（不是 service_role key）
3. 这个 key 通常长这样：`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey...`

### 4. 用户不存在

**问题**：如果数据库中没有用户，登录会失败。

**解决方案**：
- 方案A：先通过注册页面创建用户
- 方案B：在 Supabase Dashboard 手动创建测试用户：
  1. 进入 **Authentication** → **Users**
  2. 点击 **Add user** → **Create new user**
  3. 输入邮箱和密码

### 5. 邮箱验证设置

**检查配置**：
1. 进入 **Authentication** → **Email Templates**
2. 确认 OTP 邮件模板已配置
3. 检查 **Confirm email** 设置：
   - 如果启用，新用户必须验证邮箱才能登录
   - 如果禁用，用户可以直接登录

### 6. Site URL 配置

**检查**：
1. 进入 **Authentication** → **URL Configuration**
2. 确保 **Site URL** 配置正确
3. 添加应用的重定向 URL（如果需要）

## 🧪 测试步骤

### 步骤 1：检查密钥
```dart
// 在 main.dart 中添加调试信息
print('Supabase URL: ${Supabase.instance.client.supabaseUrl}');
print('Key starts with: ${Supabase.instance.client.restUrl}');
```

### 步骤 2：测试密码登录
1. 在 Dashboard 创建测试用户（邮箱：test@example.com，密码：test123456）
2. 运行应用
3. 选择"密码登录"
4. 输入测试账号
5. 查看控制台输出

### 步骤 3：测试 OTP 登录
1. 确保用户已存在
2. 点击"验证码登录"
3. 输入邮箱，点击"发送验证码"
4. 查看控制台输出：
   - ✅ 如果成功：应该显示 "OTP 发送成功"
   - ❌ 如果失败：查看错误信息

### 步骤 4：检查邮件
1. 检查邮箱收件箱
2. 检查垃圾邮件文件夹
3. 如果没收到，检查 Dashboard → Authentication → Email Templates

## 📋 调试日志说明

代码中已添加详细日志，运行时会输出：

```
🔍 开始发送 OTP 到: user@example.com
✅ OTP 发送成功
```

或错误信息：
```
❌ AuthException: Email rate limit exceeded
Status Code: 429
```

常见错误代码：
- `400`: 请求格式错误或参数无效
- `401`: 认证失败（密钥错误）
- `404`: 用户不存在
- `422`: 邮箱格式错误
- `429`: 请求过于频繁（速率限制）

## 🔧 快速修复检查清单

- [ ] 确认使用正确的 anon key（JWT 格式）
- [ ] 确认 Email 认证提供商已启用
- [ ] 确认邮件服务已配置
- [ ] 确认测试用户已创建
- [ ] 确认 OTP 模板已配置
- [ ] 查看控制台日志了解具体错误
- [ ] 检查 Supabase Dashboard 的 Logs 页面

## 📞 获取正确的 API 密钥

1. 访问：https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/settings/api
2. 查找 **Project API keys** 部分
3. 复制 **anon** **public** key
4. 更新 `lib/main.dart` 中的 `anonKey`

## 🌐 在线测试工具

可以使用 Supabase 的在线 SQL 编辑器测试：

```sql
-- 检查用户是否存在
SELECT * FROM auth.users;

-- 创建测试用户（在 SQL Editor 中不建议，使用 Dashboard）
```

## 💡 临时解决方案

如果邮件服务配置复杂，可以暂时：
1. 在 Dashboard 手动创建用户
2. 设置密码
3. 禁用邮箱验证要求
4. 只使用密码登录功能

---

**需要帮助？**
1. 查看 Supabase Dashboard 的 Logs 页面
2. 运行应用并查看控制台输出
3. 提供错误信息以便进一步诊断
