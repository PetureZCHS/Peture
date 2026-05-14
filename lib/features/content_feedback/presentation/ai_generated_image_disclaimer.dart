import 'package:flutter/material.dart';

/// AI 生图合规说明（多页复用）
class AiGeneratedImageDisclaimer extends StatelessWidget {
  const AiGeneratedImageDisclaimer({
    super.key,
    this.compact = false,
  });

  /// 紧凑版用于准备页/加载页一行展示
  final bool compact;

  static const fullText =
      '图片由人工智能生成，仅为创意效果，不代表真实场景，请勿作为医疗、诊断或事实依据。';

  static const shortText = '图片由 AI 生成，不代表真实场景。';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return Text(
        shortText,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          height: 1.4,
          fontSize: 11.5,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 生成说明',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fullText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
