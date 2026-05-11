/// OTP 邮件场景：通过 [signInWithOtp] 的 `data` 传给 GoTrue，合并进 `auth.users.user_metadata`。
/// Dashboard → Authentication → Email Templates → **Magic link**（验证码邮件默认使用该模板）
/// 内可用 `{{ .Data }}` / `{{ index .Data "otp_kind" }}` 做分支，区分注销 / 改密 / 登录 / 注册。
///
/// 建议在 Magic link 模板中用如下结构（按需微调文案）：
/// ```html
/// {{ if eq (index .Data "otp_kind") "account_deletion" }}
/// <h2>账号注销验证</h2>
/// <p>您正在<strong>确认注销账号</strong>。完成后账号及数据将被永久删除。若非本人操作，请立即修改密码并联系客服。</p>
/// <p>验证码：<strong>{{ .Token }}</strong></p>
/// {{ else if eq (index .Data "otp_kind") "password_change" }}
/// <h2>修改密码验证</h2>
/// <p>您正在<strong>修改登录密码</strong>。若非本人操作，请忽略本邮件并尽快修改密码。</p>
/// <p>验证码：<strong>{{ .Token }}</strong></p>
/// {{ else if eq (index .Data "otp_kind") "signup" }}
/// <h2>注册验证</h2>
/// <p>欢迎注册。请使用以下验证码完成邮箱验证：</p>
/// <p>验证码：<strong>{{ .Token }}</strong></p>
/// {{ else }}
/// <h2>登录验证码</h2>
/// <p>您正在登录账号，验证码如下：</p>
/// <p>验证码：<strong>{{ .Token }}</strong></p>
/// {{ end }}
/// ```
abstract final class AuthOtpEmailKind {
  AuthOtpEmailKind._();

  static const String login = 'login';
  static const String signup = 'signup';
  static const String passwordChange = 'password_change';
  static const String accountDeletion = 'account_deletion';

  static Map<String, dynamic> payload(String kind) => {'otp_kind': kind};
}
