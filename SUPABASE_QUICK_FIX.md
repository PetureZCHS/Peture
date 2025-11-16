# 🔧 Supabase 邮箱登录问题诊断

## ⚠️ 当前状态：邮箱登录无法工作

根据你提供的信息和 Supabase 文档，我已经实现了完整的邮箱登录功能，但需要正确的配置才能工作。

## 🚨 关键问题

### 1. API 密钥可能不正确

你提供的密钥：`sb_publishable_6vpdGAb3VfsM3zKqZIv9ug_nSOFgl2j`

**这不是标准的 Supabase anon key 格式！**

标准的 anon key 应该是 JWT 格式，看起来像这样：
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0...
```

### ✅ 如何获取正确的 API 密钥

1. **访问你的项目设置**：
   - URL: https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/settings/api

2. **找到 "Project API keys" 部分**

3. **复制 `anon` / `public` key**（不是 service_role）
   - 这个 key 很长（200+ 字符）
   - 以 `eyJ` 开头
   - 包含两个点 `.`

4. **更新代码中的密钥**：
   - 文件：`lib/main.dart`
   - 替换 `anonKey` 的值

## 🧪 使用诊断工具

我已经创建了一个 Supabase 诊断工具页面，帮助你快速测试连接：

### 如何使用：

1. **运行应用**
   ```bash
   flutter run
   ```

2. **打开诊断工具**
   - 在登录页面，点击底部的 "🧪 Supabase 诊断工具" 按钮

3. **执行测试**
   - **检查连接**：验证 Supabase 客户端是否正确初始化
   - **测试注册**：创建一个测试用户
   - **测试登录**：用测试账号登录
   - **发送 OTP**：测试邮件服务是否配置正确

4. **查看日志**
   - 诊断工具会显示详细的操作日志
   - 红色：错误
   - 绿色：成功
   - 橙色：提示

## 📋 快速检查清单

在继续之前，请确认以下配置：

### Supabase Dashboard 配置

- [ ] **Email 认证已启用**
  - 路径：Authentication → Providers → Email
  - 确保 "Enable Email provider" 已勾选

- [ ] **邮件服务已配置**
  - 路径：Authentication → Email Auth
  - 默认使用 Supabase 内置服务（有限制）
  - 建议配置自定义 SMTP

- [ ] **有测试用户**
  - 路径：Authentication → Users
  - 至少创建一个测试用户用于登录测试

- [ ] **正确的 API 密钥**
  - 路径：Settings → API
  - 使用 anon/public key（不是 service_role）

### 应用配置

- [ ] **main.dart 中的密钥已更新**
  ```dart
  await Supabase.initialize(
    url: 'https://tcftpcvcldfudzxgemdh.supabase.co',
    anonKey: '你的正确的JWT格式密钥',
  );
  ```

## 🔍 调试步骤

### 步骤 1：更新 API 密钥

1. 获取正确的 anon key
2. 更新 `lib/main.dart` 中的 `anonKey`
3. 重新启动应用

### 步骤 2：使用诊断工具

1. 打开应用的诊断工具页面
2. 点击 "检查连接"
3. 查看输出日志

### 步骤 3：创建测试用户

**方法 A：使用 Dashboard**
1. 进入 Authentication → Users
2. 点击 "Add user" → "Create new user"
3. 输入：
   - Email: test@example.com
   - Password: test123456
4. 点击创建

**方法 B：使用诊断工具**
1. 点击 "测试注册" 按钮
2. 查看是否成功创建用户

### 步骤 4：测试登录

1. 在诊断工具中点击 "测试登录"
2. 或返回登录页面，使用邮箱登录

## 📧 邮件服务配置

如果 OTP 邮件无法发送，需要配置邮件服务：

### 选项 1：使用默认服务（有限制）
- Supabase 提供的内置邮件服务
- 有发送限制和频率限制
- 适合开发测试

### 选项 2：配置自定义 SMTP（推荐）
1. 进入 Authentication → Email Auth
2. 启用 "Enable custom SMTP"
3. 配置 SMTP 服务器（如 SendGrid、AWS SES、Resend）

## 🐛 常见错误和解决方案

### 错误 1：401 Unauthorized
```
❌ AuthException: Invalid API key
Status Code: 401
```
**解决**：API 密钥不正确，需要更新为正确的 JWT 格式密钥

### 错误 2：Invalid login credentials
```
❌ AuthException: Invalid login credentials
```
**解决**：
- 用户不存在 → 先注册
- 密码错误 → 检查密码
- 邮箱未验证 → 在 Dashboard 手动验证

### 错误 3：Email rate limit exceeded
```
❌ AuthException: Email rate limit exceeded
Status Code: 429
```
**解决**：
- 等待一段时间后再试
- 或配置自定义 SMTP 服务

### 错误 4：Email not configured
```
❌ AuthException: Email provider is not configured
```
**解决**：
- 在 Dashboard 启用 Email 认证提供商
- 配置邮件服务

## 📞 下一步

1. **获取正确的 API 密钥** ← 最重要！
2. 更新 `lib/main.dart`
3. 使用诊断工具测试
4. 查看错误日志
5. 根据错误信息调整配置

## 💬 需要帮助？

运行诊断工具后，如果还有问题，请提供：
1. 诊断工具的日志输出
2. Flutter 控制台的错误信息
3. Supabase Dashboard 的配置截图

---

**重要提醒**：确保使用正确的 JWT 格式的 anon key，这是最常见的问题！
