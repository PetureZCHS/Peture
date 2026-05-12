import 'package:flutter/material.dart';

import '../../../app_navigator.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../domain/moderation_result.dart';

BuildContext? moderationOverlayContext(BuildContext? preferred) {
  if (preferred != null && preferred.mounted) return preferred;
  return AppNavigator.rootKey.currentContext;
}

Future<void> showModerationBlockedDialog(
  BuildContext context, {
  required ModerationResult result,
}) {
  final overlay = moderationOverlayContext(context);
  if (overlay == null) return Future.value();

  final traceId = result.traceId.trim();
  final detail = result.message.isEmpty ? '内容不符合规范' : result.message;
  return showDialog<void>(
    context: overlay,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.cardBackground,
        elevation: 8,
        shadowColor: Colors.black26,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          '内容未通过审核',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
            letterSpacing: 0.3,
            height: 1.25,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.warmGradient.colors.first.withValues(alpha: 0.9),
                      AppColors.warmGradient.colors.last.withValues(alpha: 0.95),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmGradient.colors.first
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
            if (traceId.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondaryText.withValues(alpha: 0.15),
                  ),
                ),
                child: SelectableText(
                  '追踪 ID：$traceId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '我知道了',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 与 [showModerationBlockedDialog] 同布局的成功反馈（无追踪 ID 区）。
///
/// [anchorContext] 在发起修改的页面仍挂载时可传入以便栈上下文一致；若已 `dispose` 请传 `null`，
/// 将仅用 [AppNavigator.rootKey] 在应用根上展示，避免离开后无法提示。
Future<void> showModerationSuccessDialog(
  BuildContext? anchorContext, {
  required String message,
  String title = '修改成功',
}) {
  final overlay = moderationOverlayContext(anchorContext);
  if (overlay == null) return Future.value();

  return showDialog<void>(
    context: overlay,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.cardBackground,
        elevation: 8,
        shadowColor: Colors.black26,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
            letterSpacing: 0.3,
            height: 1.25,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.natureGradient.colors.first.withValues(alpha: 0.9),
                      AppColors.natureGradient.colors.last.withValues(alpha: 0.95),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.natureGradient.colors.first
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '我知道了',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
