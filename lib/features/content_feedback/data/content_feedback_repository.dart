import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/content_feedback_kind.dart';

class ContentFeedbackRepository {
  ContentFeedbackRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 未登录时抛出 [StateError]
  Future<void> submit({
    required ContentFeedbackType feedbackType,
    required ContentSurface surface,
    required Map<String, dynamic> ref,
    String? reasonCode,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('未登录，无法提交反馈');
    }

    Map<String, dynamic> safeRef;
    try {
      final w = jsonEncode(ref);
      final d = jsonDecode(w);
      if (d is Map<String, dynamic>) {
        safeRef = d;
      } else if (d is Map) {
        safeRef = d.map((k, v) => MapEntry(k.toString(), v));
      } else {
        safeRef = {'hint': 'invalid_ref_shape'};
      }
    } catch (_) {
      safeRef = {'hint': 'ref_encode_error'};
    }

    await _client.from('user_content_feedback').insert({
      'user_id': user.id,
      'feedback_type': feedbackType.value,
      'surface': surface.value,
      'ref': safeRef,
      'reason_code': reasonCode,
      'note': (note != null && note.trim().isEmpty) ? null : note?.trim(),
    });
  }
}
