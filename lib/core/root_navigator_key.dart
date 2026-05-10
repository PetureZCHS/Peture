import 'package:flutter/material.dart';

/// [MaterialApp.navigatorKey]，用于在子页面已 dispose 时仍能切回登录栈。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
