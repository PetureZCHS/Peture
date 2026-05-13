import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

enum PetureAlertTone { info, success, warning, danger }

class PetureAlertPanel extends StatelessWidget {
  const PetureAlertPanel({
    super.key,
    required this.title,
    this.message,
    this.tone = PetureAlertTone.info,
    this.action,
  });

  final String title;
  final String? message;
  final PetureAlertTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);

    return Container(
      padding: const EdgeInsets.all(PetureSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(PetureRadius.lg),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForTone(tone), color: color, size: 22),
          const SizedBox(width: PetureSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: PetureTextStyles.bodyStrong),
                if (message != null) ...[
                  const SizedBox(height: PetureSpacing.xs),
                  Text(message!, style: PetureTextStyles.body),
                ],
                if (action != null) ...[
                  const SizedBox(height: PetureSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForTone(PetureAlertTone tone) {
    switch (tone) {
      case PetureAlertTone.success:
        return PetureColors.success;
      case PetureAlertTone.warning:
        return PetureColors.warning;
      case PetureAlertTone.danger:
        return PetureColors.danger;
      case PetureAlertTone.info:
        return PetureColors.blue;
    }
  }

  IconData _iconForTone(PetureAlertTone tone) {
    switch (tone) {
      case PetureAlertTone.success:
        return Icons.check_circle_outline;
      case PetureAlertTone.warning:
        return Icons.warning_amber_rounded;
      case PetureAlertTone.danger:
        return Icons.error_outline;
      case PetureAlertTone.info:
        return Icons.info_outline;
    }
  }
}
