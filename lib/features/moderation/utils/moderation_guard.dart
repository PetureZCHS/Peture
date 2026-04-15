import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../../app_navigator.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../data/moderation_client.dart';
import '../domain/moderation_result.dart';
import '../domain/moderation_scene.dart';
import '../presentation/moderation_dialog.dart';
import 'moderation_error_mapper.dart';

typedef ModerationPassedAction = Future<void> Function();

class ModerationGuard {
  ModerationGuard(this._client);

  final ModerationClient _client;

  Future<bool> runTextGuard({
    required BuildContext context,
    required ModerationScene scene,
    required String content,
    required ModerationPassedAction onPassed,
  }) async {
    final result = await _client.moderateText(scene: scene, content: content);
    return _dispatchResult(
      originalContext: context,
      result: result,
      onPassed: onPassed,
    );
  }

  Future<bool> runImageGuardByBytes({
    required BuildContext context,
    required ModerationScene scene,
    required List<int> bytes,
    required ModerationPassedAction onPassed,
  }) async {
    final result = await _client.moderateImageByBytes(
      scene: scene,
      bytes: Uint8List.fromList(bytes),
    );
    return _dispatchResult(
      originalContext: context,
      result: result,
      onPassed: onPassed,
    );
  }

  Future<bool> runImageGuardByStoragePath({
    required BuildContext context,
    required ModerationScene scene,
    required String storagePath,
    required ModerationPassedAction onPassed,
  }) async {
    final result = await _client.moderateImageByStoragePath(
      scene: scene,
      storagePath: storagePath,
    );
    return _dispatchResult(
      originalContext: context,
      result: result,
      onPassed: onPassed,
    );
  }

  /// 通过时仅在原页面仍挂载时执行 [onPassed]；拦截/异常时用根 Navigator 上下文展示反馈，
  /// 避免用户在等待审核期间离开页面后看不到提示。
  Future<bool> _dispatchResult({
    required BuildContext originalContext,
    required ModerationResult result,
    required ModerationPassedAction onPassed,
  }) async {
    if (result.passed) {
      if (!originalContext.mounted) return false;
      await onPassed();
      return true;
    }

    final uiContext = originalContext.mounted
        ? originalContext
        : AppNavigator.rootKey.currentContext;
    if (uiContext == null) return false;

    if (result.errorCode == ModerationErrorCode.blocked ||
        result.action.toLowerCase() == 'block') {
      await showModerationBlockedDialog(uiContext, result: result);
      return false;
    }
    final message = result.message.isNotEmpty
        ? result.message
        : mapModerationErrorMessage(result.errorCode);
    final messengerContext = uiContext.mounted
        ? uiContext
        : AppNavigator.rootKey.currentContext;
    if (messengerContext != null && messengerContext.mounted) {
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: AppColors.primaryText.withValues(alpha: 0.92),
        ),
      );
    }
    return false;
  }
}

