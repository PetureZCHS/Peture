import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AnalyticsDashboardService {
  final SupabaseClient _client;

  AnalyticsDashboardService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> loadDashboard({
    String range = '7d',
    String platform = 'all',
    String module = 'all',
    String eventName = 'all',
  }) async {
    final response = await _client.functions.invoke(
      SupabaseConfig.analyticsDashboardFunctionName,
      body: {
        'action': 'all',
        'range': range,
        'filters': {
          'platform': platform,
          'module': module,
          'event_name': eventName,
        },
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Invalid analytics dashboard response');
  }
}
