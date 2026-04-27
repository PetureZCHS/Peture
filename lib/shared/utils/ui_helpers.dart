import 'dart:ui';
import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);

  static const LinearGradient navTab0 =
      LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]);
  static const LinearGradient navTab1 =
      LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]);
  static const LinearGradient navTab2 =
      LinearGradient(colors: [Color(0xFF00b09b), Color(0xFF96c93d)]);
  static const LinearGradient navTab3 =
      LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]);

  static const List<LinearGradient> navGradients = [
    navTab0,
    navTab1,
    navTab2,
    navTab3
  ];

  static const LinearGradient warmGradient =
      LinearGradient(colors: [Color(0xFFFF5E62), Color(0xFFFF9966)]);
  static const LinearGradient coolGradient =
      LinearGradient(colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)]);
  static const LinearGradient natureGradient =
      LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]);
  static const LinearGradient magicGradient =
      LinearGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]);
  static const LinearGradient oceanGradient =
      LinearGradient(colors: [Color(0xFF30CFD0), Color(0xFF330867)]);
  static const LinearGradient goldGradient =
      LinearGradient(colors: [Color(0xFFF6D365), Color(0xFFFDA085)]);

  static const Color primary = Color(0xFF5D5FEF);
  // 🎨 与首页AI智能问诊相同的渐变色
  static const Color primaryGradientStart = Color(0xFF5A8EFA); // primaryBlue
  static const Color primaryGradientEnd = Color(0xFF8B77FF); // primaryPurple
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color cardBackground = Colors.white;

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
