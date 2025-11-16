# ⚡️ Supabase 邮箱登录快速修复指南

## 🚨 当前问题

1. **注册错误**: "Error sending confirmation email"
2. **OTP 错误**: "Signups not allowed for otp"

## ✅ 立即修复步骤

### 步骤 1：禁用邮箱确认（最重要）

1. **访问认证设置**：
   https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/auth/providers

2. **找到 Email 提供商**，点击编辑

3. **关闭以下选项**：
   - ❌ **Confirm email** - 取消勾选
   - 这样用户注册后可以直接登录，不需要邮箱验证

4. **点击 Save** 保存设置

### 步骤 2：启用邮箱 OTP（可选，用于验证码登录）

在同一个页面：

1. **找到 Email OTP 设置**
2. ✅ **Enable email OTP** - 勾选
3. 点击 **Save**

### 步骤 3：配置 Site URL（重要）

1. **访问 URL 配置**：
   https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/auth/url-configuration

2. **设置 Site URL**：
   - 开发环境：`http://localhost:3000` 或你的应用 URL
   - 生产环境：你的实际域名

3. 点击 **Save**

## 🧪 测试步骤

完成配置后，重新测试：

### 测试 1：注册新用户

```
邮箱：test123@example.com
密码：test123456
确认密码：test123456
```

**预期结果**：✅ "注册成功！正在跳转到登录页面..."

### 测试 2：密码登录

使用刚才注册的账号登录：

```
邮箱：test123@example.com
密码：test123456
```

**预期结果**：✅ 成功登录并跳转到主应用

### 测试 3：OTP 验证码登录（可选）

1. 切换到"验证码登录"
2. 输入邮箱
3. 点击"发送验证码"

**注意**：OTP 需要配置邮件服务才能工作

## 📧 关于邮件服务

### 当前状态

Supabase 提供默认邮件服务，但有以下限制：
- ⚠️ 每小时最多 2 封邮件
- ⚠️ 可能不稳定
- ⚠️ 仅用于测试

### 生产环境建议

配置自定义 SMTP 服务：

1. **访问邮件设置**：
   https://supabase.com/dashboard/project/tcftpcvcldfudzxgemdh/settings/auth

2. **启用 Custom SMTP**

3. **推荐服务**：
   - Resend（推荐，简单易用）
   - SendGrid
   - AWS SES
   - Mailgun

## 🎯 现在应该可以工作的功能

- ✅ **邮箱 + 密码注册**
- ✅ **邮箱 + 密码登录**
- ⚠️ **OTP 验证码登录**（需要等待邮件服务配置）

## 💡 快速测试命令

重新运行应用：

```bash
flutter run
```

或者热重载（在运行的应用中按 `r`）

## 🔧 如果还有问题

### 问题 1：Still getting "Error sending confirmation email"

**解决**：确保在 Dashboard 中 **取消勾选** "Confirm email"

### 问题 2：User registered but can't login

**解决**：检查 Dashboard → Authentication → Users，确认用户存在

### 问题 3：OTP still not working

**解决**：
1. OTP 功能需要邮件服务配置
2. 暂时只使用密码登录
3. 或配置自定义 SMTP

## 📱 立即测试

1. ✅ **完成 Supabase Dashboard 配置**（最重要）
2. ✅ **重新运行应用**
3. ✅ **注册新用户**
4. ✅ **使用密码登录**

---

**关键提醒**：必须在 Supabase Dashboard 中禁用 "Confirm email" 才能正常注册和登录！
