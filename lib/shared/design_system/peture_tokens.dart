import 'package:flutter/material.dart';

class PetureColors {
  const PetureColors._();

  static const Color background = Color(0xFFFBF7F1);
  static const Color backgroundAlt = Color(0xFFF4F8F4);
  static const Color surface = Color(0xFFFFFCF8);
  static const Color surfacePure = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7EFE7);
  static const Color border = Color(0xFFECE1D6);

  static const Color textPrimary = Color(0xFF2E2723);
  static const Color textSecondary = Color(0xFF776A61);
  static const Color textTertiary = Color(0xFFA29489);

  static const Color primary = Color(0xFFD98265);
  static const Color primaryPressed = Color(0xFFC86E51);
  static const Color mint = Color(0xFF7BB9A5);
  static const Color violet = Color(0xFF8A7AC8);
  static const Color blue = Color(0xFF6B9BCF);
  static const Color amber = Color(0xFFE3A84F);

  static const Color success = Color(0xFF3F9B73);
  static const Color warning = Color(0xFFC8842F);
  static const Color danger = Color(0xFFC74D43);
  static const Color dangerSurface = Color(0xFFFFF1EE);

  static const Color cosmicStart = Color(0xFF060711);
  static const Color cosmicMid = Color(0xFF111326);
  static const Color cosmicEnd = Color(0xFF1A1D35);
}

class PetureSpacing {
  const PetureSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class PetureRadius {
  const PetureRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

class PetureMotion {
  const PetureMotion._();
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Curves.easeOutCubic;
}

class PetureShadows {
  const PetureShadows._();
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.045),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> elevated(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.18),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}
