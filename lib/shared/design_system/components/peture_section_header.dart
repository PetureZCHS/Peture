import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

class PetureSectionHeader extends StatelessWidget {
  const PetureSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: PetureTextStyles.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: PetureSpacing.xs),
                Text(subtitle!, style: PetureTextStyles.caption),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: PetureSpacing.md),
          action!,
        ],
      ],
    );
  }
}
