/// 在「修改密码」等流程中：必须先 [showDialog] 再 [signOut]，
/// 否则 [RootRouter] 会立刻切到 [LoginPage]，子页面 [context] 失效，SnackBar / Navigator 会一闪而过。
///
/// 登出后由 [LoginPage] 在首帧读取并 [Navigator.pushReplacement] 到 [EmailLoginPage]。
class AuthPendingEmailLogin {
  AuthPendingEmailLogin._();

  static String? _initialEmail;

  /// 修改密码成功后调用：登出完成、根路由重建后打开邮箱登录并预填邮箱。
  static void armAfterPasswordChanged(String email) {
    _initialEmail = email.trim();
  }

  /// 由 [LoginPage] 消费一次；若无待处理数据则返回 null。
  static String? takeInitialEmail() {
    final e = _initialEmail;
    _initialEmail = null;
    return e;
  }

  /// 若登出失败，应丢弃待跳转，避免下次误打开邮箱登录页。
  static void clear() {
    _initialEmail = null;
  }
}
