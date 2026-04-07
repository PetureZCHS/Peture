import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

class AnalyticsService {
  static const String _consentKey = 'analytics_consent_accepted';
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    const androidKey = String.fromEnvironment('UMENG_ANDROID_KEY');
    const iosKey = String.fromEnvironment('UMENG_IOS_KEY');

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    if (androidKey.isEmpty || iosKey.isEmpty) {
      debugPrint('AnalyticsService: UMENG_ANDROID_KEY / UMENG_IOS_KEY 未完整配置');
      return;
    }

    await UmengCommonSdk.initCommon(androidKey, iosKey, 'official');
    UmengCommonSdk.setPageCollectionModeManual();

    _isInitialized = true;
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
