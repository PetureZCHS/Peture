import 'dart:ui';
import 'package:flutter/material.dart';

import '../design_system/peture_design_system.dart' as peture;

class AppColors {
  static const Color background = peture.PetureColors.background;
  static const Color textDark = peture.PetureColors.textPrimary;
  static const Color textGrey = peture.PetureColors.textTertiary;

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);

  static const LinearGradient navTab0 = peture.PetureGradients.tech;
  static const LinearGradient navTab1 = peture.PetureGradients.brand;
  static const LinearGradient navTab2 = peture.PetureGradients.mint;
  static const LinearGradient navTab3 = peture.PetureGradients.cosmic;

  static const List<LinearGradient> navGradients = [
    navTab0,
    navTab1,
    navTab2,
    navTab3
  ];

  static const LinearGradient warmGradient = peture.PetureGradients.brand;
  static const LinearGradient coolGradient = peture.PetureGradients.tech;
  static const LinearGradient natureGradient = peture.PetureGradients.mint;
  static const LinearGradient magicGradient = peture.PetureGradients.cosmic;
  static const LinearGradient oceanGradient = peture.PetureGradients.tech;
  static const LinearGradient goldGradient = peture.PetureGradients.warmSurface;

  static const Color primary = peture.PetureColors.primary;
  static const Color primaryGradientStart = peture.PetureColors.primary;
  static const Color primaryGradientEnd = peture.PetureColors.amber;
  static const Color primaryText = peture.PetureColors.textPrimary;
  static const Color secondaryText = peture.PetureColors.textSecondary;
  static const Color cardBackground = peture.PetureColors.surfacePure;

  // 宠物类型主题色映射
  static final Map<String, Color> petTypeColors = {
    '狗': const Color(0xFFFFE0B2), // Colors.orange[100]
    '猫': const Color(0xFFB2EBF2), // Colors.cyan[100]
    '兔': const Color(0xFFC8E6C9), // Colors.green[100]
    '仓鼠': const Color(0xFFF8BBD0), // Colors.pink[100]
    '其他': const Color(0xFFF5F5F5), // Colors.grey[100]
  };
}

extension WidgetBlur on Widget {
  Widget blurred({double sigmaX = 10.0, double sigmaY = 10.0}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: this,
    );
  }
}
