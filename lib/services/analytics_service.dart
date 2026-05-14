import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';
import 'package:uuid/uuid.dart';

import '../core/config/supabase_config.dart';
import '../shared/utils/analytics_payload_sanitizer.dart';

class AnalyticsService {
  static const String _consentKey = 'analytics_consent_accepted';
  static const String _queueKey = 'analytics_supabase_event_queue';
  static const String _anonymousIdKey = 'analytics_anonymous_id';
  static const int _maxBatchSize = 50;
  static const int _maxQueueSize = 500;

  static bool _isInitialized = false;
  static bool _isUmengInitialized = false;
  static bool _isFlushing = false;
  static String? _anonymousId;
  static String? _sessionId;
  static final Map<String, DateTime> _pageStartTimes = {};

  static Future<void> init() async {
    if (_isInitialized) return;

    _anonymousId = await _loadAnonymousId();
    _sessionId = const Uuid().v4();
    _isInitialized = true;
    track(
      'app_open',
      module: 'app',
      properties: {'source': 'app_start'},
    );

    if (kIsWeb) {
      debugPrint('AnalyticsService: Web 平台跳过友盟初始化');
      unawaited(flush());
      return;
    }

    const androidKey = String.fromEnvironment(
      'UMENG_ANDROID_KEY',
      defaultValue: '69da1f829a7f376488bdeb2d',
    );
    const iosKey = String.fromEnvironment('UMENG_IOS_KEY');
    final platform = defaultTargetPlatform;

    if (platform == TargetPlatform.android) {
      if (androidKey.isEmpty) {
        debugPrint('AnalyticsService: UMENG_ANDROID_KEY 未配置');
        unawaited(flush());
        return;
      }
      final iosParam = iosKey.isEmpty ? androidKey : iosKey;
      await UmengCommonSdk.initCommon(androidKey, iosParam, 'official');
      _isUmengInitialized = true;
    } else if (platform == TargetPlatform.iOS) {
      if (iosKey.isEmpty) {
        debugPrint('AnalyticsService: UMENG_IOS_KEY 未配置');
        unawaited(flush());
        return;
      }
      final androidParam = androidKey.isEmpty ? iosKey : androidKey;
      await UmengCommonSdk.initCommon(androidParam, iosKey, 'official');
      _isUmengInitialized = true;
    }

    if (_isUmengInitialized) {
      UmengCommonSdk.setPageCollectionModeManual();
      debugPrint('AnalyticsService: 友盟 initCommon 已完成（channel=official）');
    }
    unawaited(flush());
  }

  /// 用户同意《隐私政策》等后调用：持久化同意并初始化埋点。
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
    if (_isUmengInitialized) {
      final normalized = <String, String>{};
      params?.forEach((key, value) {
        normalized[key] = value?.toString() ?? '';
      });
      UmengCommonSdk.onEvent(eventId, normalized);
    }
    track(eventId, properties: params);
  }

  static void track(
    String eventName, {
    String? pageName,
    String? module,
    int? durationMs,
    Map<String, dynamic>? properties,
  }) {
    if (!_isInitialized) return;
    unawaited(_enqueueAndFlush(
      eventName: eventName,
      pageName: pageName,
      module: module,
      durationMs: durationMs,
      properties: properties,
    ));
  }

  static void onPageStart(String pageName) {
    if (!_isInitialized) return;
    _pageStartTimes[pageName] = DateTime.now().toUtc();
    if (_isUmengInitialized) {
      UmengCommonSdk.onPageStart(pageName);
    }
    track(
      'page_view',
      pageName: pageName,
      module: _moduleFromPage(pageName),
    );
  }

  static void onPageEnd(String pageName) {
    if (!_isInitialized) return;
    if (_isUmengInitialized) {
      UmengCommonSdk.onPageEnd(pageName);
    }
    final startedAt = _pageStartTimes.remove(pageName);
    final durationMs = startedAt == null
        ? null
        : DateTime.now().toUtc().difference(startedAt).inMilliseconds;
    track(
      'page_leave',
      pageName: pageName,
      module: _moduleFromPage(pageName),
      durationMs: durationMs,
    );
  }

  static Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _decodeQueue(prefs.getString(_queueKey));
      if (queue.isEmpty) return;

      final batch = queue.take(_maxBatchSize).toList();
      final session = Supabase.instance.client.auth.currentSession;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
      };
      final response = await http
          .post(
            Uri.parse(SupabaseConfig.analyticsCollectUrl),
            headers: headers,
            body: jsonEncode({
              'anonymous_id': await _loadAnonymousId(),
              'session_id': _sessionId ?? const Uuid().v4(),
              'events': batch,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final latestQueue = _decodeQueue(prefs.getString(_queueKey));
        final remaining = reconcileAnalyticsQueueAfterFlush(
          latestQueue,
          batch,
        );
        await prefs.setString(_queueKey, jsonEncode(remaining));
        if (remaining.isNotEmpty) {
          scheduleMicrotask(flush);
        }
      } else {
        debugPrint(
          'AnalyticsService: Supabase 埋点上报失败 ${response.statusCode} ${response.body}',
        );
      }
    } catch (error) {
      debugPrint('AnalyticsService: Supabase 埋点上报异常 $error');
    } finally {
      _isFlushing = false;
    }
  }

  static Future<void> _enqueueAndFlush({
    required String eventName,
    String? pageName,
    String? module,
    int? durationMs,
    Map<String, dynamic>? properties,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_queueKey));
    final event = <String, dynamic>{
      'client_event_id': const Uuid().v4(),
      'event_name': eventName,
      'session_id': _sessionId ?? const Uuid().v4(),
      'page_name': pageName,
      'module': module,
      'platform': _platformName(),
      'app_version': const String.fromEnvironment(
        'RELEASE',
        defaultValue: '1.0.0',
      ),
      'device_locale':
          WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'duration_ms': durationMs,
      'properties': sanitizeAnalyticsProperties(properties),
    }..removeWhere((_, value) => value == null);

    queue.add(event);
    final bounded = queue.length > _maxQueueSize
        ? queue.sublist(queue.length - _maxQueueSize)
        : queue;
    await prefs.setString(_queueKey, jsonEncode(bounded));
    await flush();
  }

  static List<Map<String, dynamic>> _decodeQueue(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<String> _loadAnonymousId() async {
    if (_anonymousId != null) return _anonymousId!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_anonymousIdKey);
    if (existing != null && existing.isNotEmpty) {
      _anonymousId = existing;
      return existing;
    }
    final next = const Uuid().v4();
    await prefs.setString(_anonymousIdKey, next);
    _anonymousId = next;
    return next;
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static String _moduleFromPage(String pageName) {
    if (pageName.startsWith('diary_')) return 'diary';
    if (pageName.startsWith('ai_image_')) return 'ai_image';
    if (pageName.startsWith('expense_')) return 'expense';
    if (pageName.startsWith('pet_profile_')) return 'pet_profile';
    if (pageName.startsWith('clicker_')) return 'clicker';
    return 'navigation';
  }
}

@visibleForTesting
List<Map<String, dynamic>> reconcileAnalyticsQueueAfterFlush(
  List<Map<String, dynamic>> latestQueue,
  List<Map<String, dynamic>> sentBatch,
) {
  final sentIds = sentBatch
      .map((event) => event['client_event_id'])
      .whereType<String>()
      .toSet();
  if (sentIds.length == sentBatch.length) {
    return latestQueue
        .where((event) => !sentIds.contains(event['client_event_id']))
        .toList();
  }

  var fallbackRemovals = sentBatch.length;
  final remaining = <Map<String, dynamic>>[];
  for (final event in latestQueue) {
    final eventId = event['client_event_id'];
    if (eventId is String && sentIds.contains(eventId)) {
      continue;
    }
    if (eventId == null && fallbackRemovals > 0) {
      fallbackRemovals -= 1;
      continue;
    }
    remaining.add(event);
  }
  return remaining;
}
