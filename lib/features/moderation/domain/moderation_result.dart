import 'moderation_scene.dart';

class ModerationResult {
  final bool passed;
  final String scene;
  final String riskLevel;
  final List<String> riskLabels;
  final String action;
  final String message;
  final String traceId;
  final ModerationErrorCode errorCode;

  const ModerationResult({
    required this.passed,
    required this.scene,
    required this.riskLevel,
    required this.riskLabels,
    required this.action,
    required this.message,
    required this.traceId,
    required this.errorCode,
  });

  factory ModerationResult.safeParse(
    Map<String, dynamic>? raw, {
    required String fallbackScene,
  }) {
    final map = raw ?? <String, dynamic>{};
    final labels = (map['riskLabels'] is List)
        ? List<String>.from(map['riskLabels'] as List)
        : <String>[];
    return ModerationResult(
      passed: map['passed'] == true,
      scene: (map['scene']?.toString() ?? fallbackScene),
      riskLevel: map['riskLevel']?.toString() ?? 'unknown',
      riskLabels: labels,
      action: map['action']?.toString() ?? 'unknown',
      message: map['message']?.toString() ?? '',
      traceId: map['traceId']?.toString() ?? '',
      errorCode: ModerationErrorCode.fromString(map['errorCode']?.toString()),
    );
  }
}

class ModerationException implements Exception {
  final ModerationResult result;
  const ModerationException(this.result);

  @override
  String toString() => 'ModerationException(${result.message})';
}

