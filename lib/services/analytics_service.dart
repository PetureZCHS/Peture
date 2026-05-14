class AnalyticsService {
  static Future<void> init() async {}

  static Future<void> acceptConsentAndInit() async {}

  static Future<bool> hasConsent() async => false;

  static Future<void> setConsentAccepted(bool accepted) async {}

  static Future<void> tryInitIfConsented() async {}

  static void logEvent(
    String eventId, {
    Map<String, dynamic>? params,
  }) {}

  static void onPageStart(String pageName) {}

  static void onPageEnd(String pageName) {}
}
