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
    return Text(
      compact ? shortText : fullText,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        height: 1.4,
        fontSize: compact ? 11.5 : 12.5,
      ),
    );
  }
}
