import 'package:flutter/material.dart';

class ThemeConstants {
  // 核心主题色 - 采用Apple风格的低饱和高质感色调
  static const Color primaryBlue = Color(0xFF007AFF); // Apple标准蓝
  static const Color primaryPurple = Color(0xFF5856D6); // 深紫
  static const Color primaryTeal = Color(0xFF34C759); // 薄荷绿
  static const Color primaryGray = Color(0xFF8E8E93); // 高级灰
  static const Color primaryPink = Color(0xFFFF2D55); // 草莓红

  // 主题色列表 - 精简数量，提升质感
  static final List<Color> themeColors = [
    primaryBlue,
    primaryPurple,
    primaryTeal,
    primaryGray,
    primaryPink,
  ];

  // 主题名称 - 采用简约命名，符合Apple风格
  static final List<String> themeNames = ['灵动蓝', '深邃紫', '清新绿', '雅致灰', '活力粉'];

  // 中性色体系 - Apple风格的灰度系统
  static const Color neutral100 = Color(0xFFFFFFFF); // 纯白
  static const Color neutral200 = Color(0xFFF9F9F9); // 背景白
  static const Color neutral300 = Color(0xFFEFEFF4); // 卡片灰
  static const Color neutral400 = Color(0xFFD1D1D6); // 分割线
  static const Color neutral500 = Color(0xFF8E8E93); // 次要文本
  static const Color neutral600 = Color(0xFF3A3A3C); // 主要文本

  // 圆角常量 - Apple风格的统一圆角半径
  static const double cornerRadiusSmall = 8.0;
  static const double cornerRadiusMedium = 12.0;
  static const double cornerRadiusLarge = 16.0;

  // 获取主题数量
  static int get themeCount => themeColors.length;

  // 生成主题配置 - 完整的Apple风格主题
  static ThemeData getTheme(int index) {
    return ThemeData(
      primaryColor: themeColors[index % themeCount],
      cardColor: neutral100,
      canvasColor: neutral300,
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: neutral600,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: neutral600,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: neutral500,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadiusSmall),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadiusMedium),
          side: BorderSide(color: neutral400, width: 0.5),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSwatch()
          .copyWith(secondary: themeColors[index % themeCount].withOpacity(0.8))
          .copyWith(surface: neutral200),
    );
  }
}
