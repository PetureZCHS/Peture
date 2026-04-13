import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

class AnalyticsService {
  static const String _consentKey = 'analytics_consent_accepted';
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    // 默认值为友盟控制台 Android AppKey，本地可直接 flutter run；发布前可用 dart-define 覆盖。
    const androidKey = String.fromEnvironment(
      'UMENG_ANDROID_KEY',
      defaultValue: '69da1f829a7f376488bdeb2d',
    );
    const iosKey = String.fromEnvironment('UMENG_IOS_KEY');

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    // initCommon(androidKey, iosKey, channel)。仅配置 Android Key 时，iOS 参数用 Android Key 占位以便本地调试。
    if (Platform.isAndroid) {
      if (androidKey.isEmpty) {
        debugPrint('AnalyticsService: UMENG_ANDROID_KEY 未配置');
        return;
      }
      final iosParam = iosKey.isEmpty ? androidKey : iosKey;
      await UmengCommonSdk.initCommon(androidKey, iosParam, 'official');
    } else if (Platform.isIOS) {
      if (iosKey.isEmpty) {
        debugPrint('AnalyticsService: UMENG_IOS_KEY 未配置');
        return;
      }
      final androidParam = androidKey.isEmpty ? iosKey : androidKey;
      await UmengCommonSdk.initCommon(androidParam, iosKey, 'official');
    }

    UmengCommonSdk.setPageCollectionModeManual();

    _isInitialized = true;
    debugPrint('AnalyticsService: 友盟 initCommon 已完成（channel=official）');
  }

  /// 用户同意《隐私政策》等后调用：持久化同意并初始化友盟。
  static Future<void> acceptConsentAndInit() async {
    await setConsentAccepted(true);
    await init();
  }

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<void> setConsentAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, accepted);
  }

  static Future<void> tryInitIfConsented() async {
    if (await hasConsent()) {
      await init();
    }
  }

  static void logEvent(
    String eventId, {
    Map<String, dynamic>? params,
  }) {
    if (!_isInitialized) return;
    final normalized = <String, String>{};
    params?.forEach((key, value) {
      normalized[key] = value?.toString() ?? '';
    });
    UmengCommonSdk.onEvent(eventId, normalized);
  }

  static void onPageStart(String pageName) {
    if (!_isInitialized) return;
    UmengCommonSdk.onPageStart(pageName);
  }

  static void onPageEnd(String pageName) {
    if (!_isInitialized) return;
    UmengCommonSdk.onPageEnd(pageName);
  }
}
