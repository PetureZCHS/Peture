import 'package:flutter/foundation.dart';

/// 登录/注册流程中的协议勾选共享状态
class AuthTermsConsent {
  AuthTermsConsent._();

  static final ValueNotifier<bool> accepted = ValueNotifier<bool>(false);

  static bool get value => accepted.value;

  static void set(bool next) {
    if (accepted.value == next) return;
    accepted.value = next;
  }
}
