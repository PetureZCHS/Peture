import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/moderation_result.dart';
import '../domain/moderation_scene.dart';

class ModerationClient {
  ModerationClient({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ModerationResult> moderateText({
    required ModerationScene scene,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: '提交内容不能为空',
        traceId: '',
        errorCode: ModerationErrorCode.invalidRequest,
      );
    }

    try {
      final res = await _client.functions.invoke(
        'moderate-text',
        body: {'scene': scene.value, 'content': trimmed},
        headers: _authHeaders(),
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      return ModerationResult.safeParse(data, fallbackScene: scene.value);
    } on FunctionException catch (e) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: e.details?.toString() ?? '审核服务异常',
        traceId: '',
        errorCode: ModerationErrorCode.providerError,
      );
    } catch (_) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: '审核失败，请稍后重试',
        traceId: '',
        errorCode: ModerationErrorCode.unknown,
      );
    }
  }

  Future<ModerationResult> moderateImageByBytes({
    required ModerationScene scene,
    required Uint8List bytes,
  }) async {
    try {
      final base64 = base64Encode(bytes);
      final res = await _client.functions.invoke(
        'moderate-image',
        body: {'scene': scene.value, 'image_base64': base64},
        headers: _authHeaders(),
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      return ModerationResult.safeParse(data, fallbackScene: scene.value);
    } on FunctionException catch (e) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: e.details?.toString() ?? '图像审核服务异常',
        traceId: '',
        errorCode: ModerationErrorCode.providerError,
      );
    } catch (_) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: '图像审核失败，请稍后重试',
        traceId: '',
        errorCode: ModerationErrorCode.unknown,
      );
    }
  }

  Future<ModerationResult> moderateImageByStoragePath({
    required ModerationScene scene,
    required String storagePath,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'moderate-image',
        body: {'scene': scene.value, 'storage_path': storagePath},
        headers: _authHeaders(),
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      return ModerationResult.safeParse(data, fallbackScene: scene.value);
    } on FunctionException catch (e) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: e.details?.toString() ?? '图像审核服务异常',
        traceId: '',
        errorCode: ModerationErrorCode.providerError,
      );
    } catch (_) {
      return ModerationResult(
        passed: false,
        scene: scene.value,
        riskLevel: 'unknown',
        riskLabels: const [],
        action: 'block',
        message: '图像审核失败，请稍后重试',
        traceId: '',
        errorCode: ModerationErrorCode.unknown,
      );
    }
  }

  Map<String, String> _authHeaders() {
    final token = _client.auth.currentSession?.accessToken;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}

