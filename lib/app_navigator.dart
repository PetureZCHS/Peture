import 'package:flutter/material.dart';

/// 主应用（已登录态）根 [Navigator]，用于在发起异步审核的页面已 dispose 时，
/// 仍能在当前 App 内展示审核拦截 / 统一反馈弹窗。
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
}
