import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';
import 'peture_card.dart';

class PetureFeatureTile extends StatelessWidget {
  const PetureFeatureTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.accentColor = PetureColors.primary,
    this.trailing,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PetureCard(
      onTap: onTap,
      padding: const EdgeInsets.all(PetureSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(PetureRadius.md),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: PetureSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: PetureTextStyles.bodyStrong.copyWith(
                        fontSize: 16,
                        height: 1.22,
                        fontWeight: FontWeight.w700,
                        color: PetureColors.textPrimary.withOpacity(0.88),
                      ),
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: PetureSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PetureTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: PetureSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
