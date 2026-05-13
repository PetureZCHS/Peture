import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

class PetureEmptyState extends StatelessWidget {
  const PetureEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PetureSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PetureColors.surfaceMuted,
                borderRadius: BorderRadius.circular(PetureRadius.xl),
              ),
              child: Icon(icon, color: PetureColors.textTertiary, size: 32),
            ),
            const SizedBox(height: PetureSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PetureTextStyles.sectionTitle,
            ),
            if (message != null) ...[
              const SizedBox(height: PetureSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: PetureTextStyles.body,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: PetureSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
