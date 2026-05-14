const _sensitiveAnalyticsKeyPattern =
    r'(password|passwd|pwd|token|secret|authorization|phone|mobile|email|mail|address|location|lat|lng|longitude|latitude|content|message|prompt|answer|text|image|url|avatar|photo)';

/// Removes sensitive keys and bounds values before analytics events leave the app.
Map<String, dynamic> sanitizeAnalyticsProperties(
  Map<String, dynamic>? properties, {
  int maxDepth = 2,
}) {
  if (properties == null || properties.isEmpty) {
    return <String, dynamic>{};
  }
  return _sanitizeMap(properties, 0, maxDepth);
}

Map<String, dynamic> _sanitizeMap(
  Map<dynamic, dynamic> source,
  int depth,
  int maxDepth,
) {
  if (depth > maxDepth) return <String, dynamic>{};

  final result = <String, dynamic>{};
  final sensitiveRegex = RegExp(_sensitiveAnalyticsKeyPattern,
      caseSensitive: false);

  source.forEach((rawKey, value) {
    final key = rawKey.toString().trim();
    if (key.isEmpty || sensitiveRegex.hasMatch(key)) return;

    final safeKey = key.length > 64 ? key.substring(0, 64) : key;
    final sanitized = _sanitizeValue(value, depth, maxDepth);
    if (sanitized != _AnalyticsDropValue.instance) {
      result[safeKey] = sanitized;
    }
  });

  return result;
}

Object? _sanitizeValue(Object? value, int depth, int maxDepth) {
  if (value == null || value is num || value is bool) return value;
  if (value is DateTime) return value.toIso8601String();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return _AnalyticsDropValue.instance;
    return trimmed.length > 240 ? trimmed.substring(0, 240) : trimmed;
  }
  if (value is Iterable) {
    return value
        .take(20)
        .map((item) => _sanitizeValue(item, depth + 1, maxDepth))
        .where((item) => item != _AnalyticsDropValue.instance)
        .toList();
  }
  if (value is Map) {
    return _sanitizeMap(value, depth + 1, maxDepth);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return _AnalyticsDropValue.instance;
  return text.length > 240 ? text.substring(0, 240) : text;
}

class _AnalyticsDropValue {
  static final instance = _AnalyticsDropValue._();

  _AnalyticsDropValue._();
}
