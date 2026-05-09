import 'dart:convert';

import 'package:flutter/services.dart';

/// 加载 [assets/data/china_regions.json]（省 + 市列表）
class ChinaRegionsLoader {
  ChinaRegionsLoader._();

  static List<Map<String, dynamic>>? _cache;

  static Future<List<Map<String, dynamic>>> load() async {
    if (_cache != null) return _cache!;
    final s =
        await rootBundle.loadString('assets/data/china_regions.json');
    _cache = (jsonDecode(s) as List<dynamic>).cast<Map<String, dynamic>>();
    return _cache!;
  }
}
