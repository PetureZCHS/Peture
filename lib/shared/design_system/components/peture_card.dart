import 'package:flutter/material.dart';

import '../peture_tokens.dart';

enum PetureCardVariant { standard, emphasized, danger }

class PetureCard extends StatelessWidget {
  const PetureCard({
    super.key,
    required this.child,
    this.variant = PetureCardVariant.standard,
    this.padding = const EdgeInsets.all(PetureSpacing.lg),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final PetureCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = _decorationFor(variant);

    final card = AnimatedContainer(
      duration: PetureMotion.normal,
      curve: PetureMotion.standard,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PetureRadius.lg),
        onTap: onTap,
        child: card,
      ),
    );
  }

  BoxDecoration _decorationFor(PetureCardVariant variant) {
    switch (variant) {
      case PetureCardVariant.emphasized:
        return BoxDecoration(
          color: PetureColors.surfacePure,
          borderRadius: BorderRadius.circular(PetureRadius.lg),
          border: Border.all(color: PetureColors.primary.withOpacity(0.18)),
          boxShadow: PetureShadows.elevated(PetureColors.primary),
        );
      case PetureCardVariant.danger:
        return BoxDecoration(
          color: PetureColors.dangerSurface,
          borderRadius: BorderRadius.circular(PetureRadius.lg),
          border: Border.all(color: PetureColors.danger.withOpacity(0.18)),
        );
      case PetureCardVariant.standard:
        return BoxDecoration(
          color: PetureColors.surface,
          borderRadius: BorderRadius.circular(PetureRadius.lg),
          border: Border.all(color: PetureColors.border),
          boxShadow: PetureShadows.soft,
        );
    }
  }
}
