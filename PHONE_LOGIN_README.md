# 手机号验证码登录功能说明

## 功能概述

本项目已集成基于 LeanCloud 的手机号验证码登录功能。用户可以通过输入手机号和验证码进行登录。

**技术实现方式**：使用 HTTP 直接调用 LeanCloud REST API，避免 SDK 依赖冲突问题。

## LeanCloud 配置信息

配置文件位置：`lib/config/leancloud_config.dart`

```dart
AppID: dyryTmVzEpt1LSVOErRLeWXy-gzGzoHsz
AppKey: NLLCy8pUqhJLQn1nY7r9UFaw
服务器地址: https://dyrytmvz.lc-cn-n1-shared.com
```

**参考文档**：https://docs.leancloud.cn/sdk/storage/guide/setup-flutter/

## 功能实现

### 1. 新增文件

- **lib/config/leancloud_config.dart** - LeanCloud 配置信息
- **lib/config/leancloud_service.dart** - LeanCloud API 服务封装
- **lib/phone_login_page.dart** - 手机号验证码登录页面

### 2. 修改文件

- **lib/login_page.dart** - 添加了"手机号验证码登录"按钮
- **pubspec.yaml** - 添加了 http 依赖

## 为什么使用 REST API 而不是官方 SDK？

LeanCloud 官方提供了 Flutter SDK (`leancloud_storage`)，但存在以下问题：

1. **依赖冲突**：官方 SDK 依赖 `dio ^4.0.0`，而项目中其他包（如 `flutter_chat_core`）需要 `dio ^5.0.0`
2. **灵活性**：直接使用 REST API 更灵活，可以精确控制请求和响应
3. **轻量化**：不需要引入额外的 SDK 依赖，减小应用体积

我们的实现完全遵循 LeanCloud REST API 文档规范。

## 登录流程

1. 用户在登录页面点击"手机号验证码登录"按钮
2. 进入手机号登录页面
3. 输入手机号（11位数字）
4. 点击"获取验证码"按钮，系统会发送验证码到用户手机
5. 输入收到的验证码（6位数字）
6. 勾选"我已阅读并同意《用户服务协议》"
7. 点击"登录"按钮完成登录

## 测试账号

- **手机号**: 18639529172
- **验证码**: 746018（固定验证码，用于测试）

## API 接口说明

### 1. 请求验证码

```dart
LeanCloudService.requestSmsCode(String mobilePhoneNumber)
```

- 参数：手机号
- 返回：bool（成功/失败）

### 2. 验证码登录

```dart
LeanCloudService.verifyAndLogin(String mobilePhoneNumber, String smsCode)
```

- 参数：手机号、验证码
- 返回：用户信息 Map（包含 sessionToken、objectId 等）

### 3. 获取当前用户

```dart
LeanCloudService.getCurrentUser(String sessionToken)
```

- 参数：会话令牌
- 返回：用户信息 Map

## 会话管理

登录成功后，系统会自动保存以下信息到 SharedPreferences：

- `sessionToken` - 会话令牌，用于后续 API 调用
- `userId` - 用户 ID
- `mobilePhoneNumber` - 用户手机号

## 安全性说明

1. 所有 API 请求都通过 HTTPS 加密传输
2. 验证码有效期由 LeanCloud 服务端控制
3. sessionToken 用于验证用户身份，应妥善保管

## 页面特性

### 手机号登录页面特性

- ✅ 手机号格式验证（11位数字，1开头）
- ✅ 验证码输入限制（6位数字）
- ✅ 获取验证码倒计时（60秒）
- ✅ 加载状态显示
- ✅ 用户协议确认
- ✅ 友好的错误提示
- ✅ 测试号提示

## 运行项目

```bash
# 安装依赖
flutter pub get

# 运行项目
flutter run
```

## 注意事项

1. 需要确保设备有网络连接
2. LeanCloud 服务器地址需要可访问
3. 测试号 18639529172 的验证码固定为 746018
4. **重要**：正式环境下需要在 LeanCloud 控制台配置短信签名和模板
   - 登录 [LeanCloud 控制台](https://console.leancloud.cn/)
   - 进入应用设置 > 短信 > 短信签名
   - 添加并审核通过短信签名
   - 配置短信模板（可使用系统默认模板）

### 关于短信签名错误

如果遇到 `{"code":1,"error":"签名无效，应用至少需要一个默认签名，或签名未通过审核"}` 错误：

1. 这是 LeanCloud 的安全机制，需要配置短信签名后才能发送验证码
2. 测试阶段可以使用测试号 18639529172（验证码固定 746018）
3. 正式上线前务必在控制台完成短信签名配置

### LeanCloud REST API 文档

- 短信服务文档：https://docs.leancloud.cn/sdk/sms/guide/
- REST API 参考：https://docs.leancloud.cn/sdk/storage/guide/rest/
- Flutter SDK 配置：https://docs.leancloud.cn/sdk/storage/guide/setup-flutter/
