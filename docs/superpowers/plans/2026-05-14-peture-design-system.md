# Peture 设计系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Peture 统一设计系统，完成首页样板，并收敛 MVP 主路径中明显割裂的页面视觉。

**Architecture:** 新增 `lib/shared/design_system/` 作为唯一新设计系统入口，`ui_helpers.dart` 保持兼容。先落 token/theme/components，再按优先级迁移页面，保留业务逻辑和路由行为。

**Tech Stack:** Flutter / Dart / Material 3 / Supabase Flutter / 现有 `flutter_test`。

---

## 文件结构

- 新建 `lib/shared/design_system/peture_tokens.dart`：颜色、间距、圆角、阴影、动效、语义状态。
- 新建 `lib/shared/design_system/peture_text_styles.dart`：统一文字层级。
- 新建 `lib/shared/design_system/peture_gradients.dart`：品牌和功能主题渐变。
- 新建 `lib/shared/design_system/peture_theme.dart`：生成 App 级 `ThemeData`。
- 新建 `lib/shared/design_system/components/peture_card.dart`：标准、强调、危险卡片。
- 新建 `lib/shared/design_system/components/peture_buttons.dart`：主按钮、次按钮、危险按钮。
- 新建 `lib/shared/design_system/components/peture_inputs.dart`：统一输入框装饰。
- 新建 `lib/shared/design_system/components/peture_page_scaffold.dart`：统一页面背景、安全区和底部留白。
- 新建 `lib/shared/design_system/components/peture_feature_tile.dart`：首页功能入口卡片。
- 新建 `lib/shared/design_system/components/peture_section_header.dart`：区块标题。
- 新建 `lib/shared/design_system/components/peture_empty_state.dart`：空态。
- 新建 `lib/shared/design_system/components/peture_alert_panel.dart`：风险和敏感操作提示。
- 新建 `lib/shared/design_system/peture_design_system.dart`：统一导出。
- 修改 `lib/shared/utils/ui_helpers.dart`：转发新 token，保持旧引用可编译。
- 修改 `lib/main.dart`：接入 `PetureTheme.light()`。
- 修改 `lib/features/home/presentation/home_screen.dart`：改为“温暖功能中台”首页样板，保留 5 个 MVP 入口和 3 Tab 导航。
- 修改 `lib/features/auth/presentation/login_page.dart`：保留深色宇宙风格，收敛品牌、按钮、登录选项卡片和动效强度。
- 修改 `lib/features/auth/presentation/email_login_page.dart`：统一邮箱登录表单样式、协议区和反馈。
- 修改 `lib/features/auth/presentation/email_register_page.dart`：统一邮箱注册表单样式、验证码步骤和反馈。
- 修改 `lib/features/auth/presentation/phone_login_page.dart`：保持短信不可用逻辑，统一不可用状态和视觉。
- 修改 `lib/features/profile/presentation/account_security_page.dart`：改为设计系统列表页。
- 修改 `lib/features/profile/presentation/change_password_page.dart`：统一表单、说明卡、按钮和成功弹窗。
- 修改 `lib/features/profile/presentation/account_deactivate_page.dart`：统一风险说明、验证码步骤、危险按钮和弹窗。
- 修改 P1 页面：`preparation_page.dart`、`medical_record_screen.dart`、`profile_screen.dart`、`unified_expense_home_page.dart`、`dog_clicker_screen.dart`、`pet_diary_compose_page.dart`，只做明显割裂处的视觉对齐。

## Task 1: 设计系统 token、theme、基础组件

**Files:**
- Create: `lib/shared/design_system/peture_tokens.dart`
- Create: `lib/shared/design_system/peture_text_styles.dart`
- Create: `lib/shared/design_system/peture_gradients.dart`
- Create: `lib/shared/design_system/peture_theme.dart`
- Create: `lib/shared/design_system/peture_design_system.dart`
- Create: `lib/shared/design_system/components/peture_card.dart`
- Create: `lib/shared/design_system/components/peture_buttons.dart`
- Create: `lib/shared/design_system/components/peture_inputs.dart`
- Create: `lib/shared/design_system/components/peture_page_scaffold.dart`
- Create: `lib/shared/design_system/components/peture_feature_tile.dart`
- Create: `lib/shared/design_system/components/peture_section_header.dart`
- Create: `lib/shared/design_system/components/peture_empty_state.dart`
- Create: `lib/shared/design_system/components/peture_alert_panel.dart`
- Modify: `lib/shared/utils/ui_helpers.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 新建设计系统 token**

创建 `lib/shared/design_system/peture_tokens.dart`：

```dart
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
```

- [ ] **Step 2: 新建文字层级**

创建 `lib/shared/design_system/peture_text_styles.dart`：

```dart
import 'package:flutter/material.dart';

import 'peture_tokens.dart';

class PetureTextStyles {
  const PetureTextStyles._();

  static const TextStyle largeTitle = TextStyle(
    fontSize: 30,
    height: 1.18,
    fontWeight: FontWeight.w800,
    color: PetureColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: PetureColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: PetureColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: PetureColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: PetureColors.textTertiary,
  );
}
```

- [ ] **Step 3: 新建渐变和功能主题**

创建 `lib/shared/design_system/peture_gradients.dart`：

```dart
import 'package:flutter/material.dart';

import 'peture_tokens.dart';

class PetureGradients {
  const PetureGradients._();

  static const LinearGradient brand = LinearGradient(
    colors: [PetureColors.primary, Color(0xFFE7B56F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mint = LinearGradient(
    colors: [PetureColors.mint, Color(0xFFB9DDC8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tech = LinearGradient(
    colors: [PetureColors.violet, PetureColors.blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmSurface = LinearGradient(
    colors: [Color(0xFFFFEFE1), Color(0xFFE3F3EC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cosmic = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      PetureColors.cosmicStart,
      PetureColors.cosmicMid,
      PetureColors.cosmicEnd,
    ],
  );
}
```

- [ ] **Step 4: 新建主题**

创建 `lib/shared/design_system/peture_theme.dart`：

```dart
import 'package:flutter/material.dart';

import 'peture_text_styles.dart';
import 'peture_tokens.dart';

class PetureTheme {
  const PetureTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PetureColors.primary,
      brightness: Brightness.light,
      primary: PetureColors.primary,
      secondary: PetureColors.mint,
      surface: PetureColors.surface,
      error: PetureColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: '.SF Pro Text',
      scaffoldBackgroundColor: PetureColors.background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: PetureTextStyles.sectionTitle,
        iconTheme: IconThemeData(color: PetureColors.textPrimary),
      ),
      textTheme: const TextTheme(
        headlineLarge: PetureTextStyles.largeTitle,
        titleLarge: PetureTextStyles.title,
        titleMedium: PetureTextStyles.sectionTitle,
        bodyLarge: PetureTextStyles.body,
        bodyMedium: PetureTextStyles.body,
        labelLarge: PetureTextStyles.label,
        bodySmall: PetureTextStyles.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PetureColors.surfacePure,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PetureRadius.md),
          borderSide: const BorderSide(color: PetureColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PetureRadius.md),
          borderSide: const BorderSide(color: PetureColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PetureRadius.md),
          borderSide: const BorderSide(color: PetureColors.primary, width: 1.4),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 新建基础组件**

创建 `lib/shared/design_system/components/peture_card.dart`：

```dart
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
    final Color background = switch (variant) {
      PetureCardVariant.standard => PetureColors.surface,
      PetureCardVariant.emphasized => PetureColors.surfacePure,
      PetureCardVariant.danger => PetureColors.dangerSurface,
    };
    final Color border = switch (variant) {
      PetureCardVariant.danger => PetureColors.danger.withOpacity(0.24),
      _ => PetureColors.border,
    };

    final card = AnimatedContainer(
      duration: PetureMotion.fast,
      curve: PetureMotion.standard,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PetureRadius.lg),
        border: Border.all(color: border),
        boxShadow: PetureShadows.soft,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PetureRadius.lg),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_buttons.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_tokens.dart';

class PeturePrimaryButton extends StatelessWidget {
  const PeturePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon ?? Icons.check_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: PetureColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PetureRadius.pill),
          ),
        ),
      ),
    );
  }
}

class PetureSecondaryButton extends StatelessWidget {
  const PetureSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: PetureColors.primary,
          side: const BorderSide(color: PetureColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PetureRadius.pill),
          ),
        ),
      ),
    );
  }
}

class PetureDangerButton extends StatelessWidget {
  const PetureDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PetureColors.danger,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PetureRadius.pill),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_inputs.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_tokens.dart';

InputDecoration petureInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: PetureColors.textTertiary),
    suffixIcon: suffix,
  );
}
```

创建 `lib/shared/design_system/components/peture_page_scaffold.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_tokens.dart';

class PeturePageScaffold extends StatelessWidget {
  const PeturePageScaffold({
    super.key,
    required this.child,
    this.title,
    this.bottomPadding = 24,
    this.appBar,
    this.extendBody = false,
  });

  final Widget child;
  final String? title;
  final double bottomPadding;
  final PreferredSizeWidget? appBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      backgroundColor: PetureColors.background,
      appBar: appBar ??
          (title == null
              ? null
              : AppBar(
                  title: Text(title!),
                )),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: child,
        ),
      ),
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_feature_tile.dart`：

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';
import 'peture_card.dart';

class PetureFeatureTile extends StatelessWidget {
  const PetureFeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return PetureCard(
      padding: const EdgeInsets.all(PetureSpacing.lg),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(PetureRadius.md),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: PetureSpacing.xl),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PetureTextStyles.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: PetureSpacing.xs),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PetureTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_section_header.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

class PetureSectionHeader extends StatelessWidget {
  const PetureSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PetureTextStyles.sectionTitle),
        if (subtitle != null) ...[
          const SizedBox(height: PetureSpacing.xs),
          Text(subtitle!, style: PetureTextStyles.caption),
        ],
      ],
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_empty_state.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

class PetureEmptyState extends StatelessWidget {
  const PetureEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PetureSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: PetureColors.textTertiary),
            const SizedBox(height: PetureSpacing.md),
            Text(title, style: PetureTextStyles.sectionTitle),
            const SizedBox(height: PetureSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PetureTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
```

创建 `lib/shared/design_system/components/peture_alert_panel.dart`：

```dart
import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';
import 'peture_card.dart';

class PetureAlertPanel extends StatelessWidget {
  const PetureAlertPanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.danger = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? PetureColors.danger : PetureColors.primary;
    return PetureCard(
      variant: danger ? PetureCardVariant.danger : PetureCardVariant.emphasized,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: PetureSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PetureTextStyles.bodyStrong.copyWith(color: color)),
                const SizedBox(height: PetureSpacing.xs),
                Text(message, style: PetureTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

创建 `lib/shared/design_system/peture_design_system.dart`：

```dart
export 'peture_gradients.dart';
export 'peture_text_styles.dart';
export 'peture_theme.dart';
export 'peture_tokens.dart';
export 'components/peture_alert_panel.dart';
export 'components/peture_buttons.dart';
export 'components/peture_card.dart';
export 'components/peture_empty_state.dart';
export 'components/peture_feature_tile.dart';
export 'components/peture_inputs.dart';
export 'components/peture_page_scaffold.dart';
export 'components/peture_section_header.dart';
```

- [ ] **Step 6: 接入全局主题和兼容层**

修改 `lib/main.dart`，引入新主题：

```dart
import 'shared/design_system/peture_design_system.dart';
```

将 `MyApp.build` 内的本地 `ThemeData` 替换为：

```dart
final theme = PetureTheme.light();
```

修改 `lib/shared/utils/ui_helpers.dart`，顶部引入：

```dart
import '../design_system/peture_design_system.dart' as peture;
```

保留 `AppColors` 类名，将常用颜色映射到新 token：

```dart
static const Color background = peture.PetureColors.background;
static const Color textDark = peture.PetureColors.textPrimary;
static const Color textGrey = peture.PetureColors.textTertiary;
static const Color primary = peture.PetureColors.primary;
static const Color primaryText = peture.PetureColors.textPrimary;
static const Color secondaryText = peture.PetureColors.textSecondary;
static const Color cardBackground = peture.PetureColors.surfacePure;
```

保留旧渐变名，但将颜色调整为新系统：

```dart
static const LinearGradient warmGradient = peture.PetureGradients.brand;
static const LinearGradient coolGradient = peture.PetureGradients.tech;
static const LinearGradient natureGradient = peture.PetureGradients.mint;
static const LinearGradient magicGradient = peture.PetureGradients.tech;
static const LinearGradient oceanGradient = peture.PetureGradients.mint;
static const LinearGradient goldGradient = peture.PetureGradients.brand;
```

- [ ] **Step 7: 运行静态分析**

Run: `flutter analyze`

Expected: 不出现新增 design_system 相关编译错误。若已有旧警告，记录警告来源，但必须修复新增错误。

- [ ] **Step 8: 提交**

```bash
git add lib/main.dart lib/shared/design_system lib/shared/utils/ui_helpers.dart
git commit -m "feat: add Peture design system foundation"
```

## Task 2: 首页温暖功能中台样板

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`

- [ ] **Step 1: 引入设计系统**

在 `home_screen.dart` 添加：

```dart
import '../../../shared/design_system/peture_design_system.dart';
```

- [ ] **Step 2: 重写首页 Dashboard 布局**

将 `_HomeDashboardContentState.build` 的 `ListView` 内容改为：

```dart
padding: EdgeInsets.fromLTRB(20, topPadding + 32, 20, 130),
children: [
  const PetureSectionHeader(
    title: '今天也好好照顾它',
    subtitle: '把常用工具放在顺手的位置。',
  ),
  const SizedBox(height: PetureSpacing.lg),
  Container(
    padding: const EdgeInsets.all(PetureSpacing.xl),
    decoration: BoxDecoration(
      gradient: PetureGradients.warmSurface,
      borderRadius: BorderRadius.circular(PetureRadius.xl),
      border: Border.all(color: PetureColors.border),
      boxShadow: PetureShadows.soft,
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(PetureRadius.lg),
          ),
          child: const Icon(Icons.pets_rounded, color: PetureColors.primary),
        ),
        const SizedBox(width: PetureSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Peture 功能中台', style: PetureTextStyles.sectionTitle),
              const SizedBox(height: PetureSpacing.xs),
              Text('记录、创作、训练和管理，都从这里开始。', style: PetureTextStyles.caption),
            ],
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: PetureSpacing.xl),
  LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            height: width * 0.88,
            child: const PetureFeatureTile(
              title: '宠物消费',
              subtitle: '记录日常开销',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: PetureColors.blue,
              page: UnifiedExpenseHomePage(),
            ),
          ),
          SizedBox(
            width: width,
            height: width * 0.88,
            child: const PetureFeatureTile(
              title: '电子档案',
              subtitle: '身份与成长记录',
              icon: Icons.badge_rounded,
              accentColor: PetureColors.mint,
              page: PetPassportPage(),
            ),
          ),
          SizedBox(
            width: width,
            height: width * 0.88,
            child: const PetureFeatureTile(
              title: '第一人称日记',
              subtitle: '把今天写成故事',
              icon: Icons.menu_book_rounded,
              accentColor: PetureColors.primary,
              page: PetDiaryComposePage(),
            ),
          ),
          SizedBox(
            width: width,
            height: width * 0.88,
            child: const PetureFeatureTile(
              title: '训宠响片',
              subtitle: '轻量训练陪伴',
              icon: Icons.touch_app_rounded,
              accentColor: PetureColors.amber,
              page: DogClickerScreen(),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth,
            height: 112,
            child: const PetureFeatureTile(
              title: 'AI 图像实验室',
              subtitle: '生成专属宠物视觉',
              icon: Icons.auto_fix_high_rounded,
              accentColor: PetureColors.violet,
              page: PreparationPage(),
            ),
          ),
        ],
      );
    },
  ),
  const SizedBox(height: PetureSpacing.xl),
  Text(
    '更多能力正在打磨中',
    textAlign: TextAlign.center,
    style: PetureTextStyles.caption,
  ),
]
```

- [ ] **Step 3: 收敛底部导航颜色**

将 `_navGradients` 改为：

```dart
static const List<LinearGradient> _navGradients = [
  PetureGradients.brand,
  PetureGradients.mint,
  PetureGradients.tech,
];
```

- [ ] **Step 4: 删除未使用的 `_buildFeatureCard`**

删除 `_HomeDashboardContentState._buildFeatureCard` 方法。确认 `CupertinoPageRoute` 仍被其它代码使用；如果只在被删除方法中使用，也删除 `package:flutter/cupertino.dart` 引入。

- [ ] **Step 5: 分析首页**

Run: `flutter analyze lib/features/home/presentation/home_screen.dart`

Expected: 首页文件无新增错误。

- [ ] **Step 6: 提交**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat: refresh home as warm utility hub"
```

## Task 3: 登录注册视觉收敛

**Files:**
- Modify: `lib/features/auth/presentation/login_page.dart`
- Modify: `lib/features/auth/presentation/email_login_page.dart`
- Modify: `lib/features/auth/presentation/email_register_page.dart`
- Modify: `lib/features/auth/presentation/phone_login_page.dart`

- [ ] **Step 1: 根登录页保留宇宙风格并收敛控件**

在 `login_page.dart` 引入：

```dart
import '../../../shared/design_system/peture_design_system.dart';
```

保留现有深色背景和黑洞动画。将登录选项按钮/卡片统一改为 `PetureCard` 包裹，按钮颜色使用 `PetureColors.primary`、`PetureColors.mint`、`PetureColors.violet`。保留 `EmailLoginPage`、`PhoneLoginPage` 导航行为。

- [ ] **Step 2: 邮箱登录页使用统一输入装饰和按钮**

在 `email_login_page.dart` 引入设计系统：

```dart
import '../../../shared/design_system/peture_design_system.dart';
```

将主要 `TextFormField` 的 `InputDecoration` 改用：

```dart
decoration: petureInputDecoration(
  label: '邮箱',
  hint: '请输入邮箱地址',
  icon: Icons.mail_outline_rounded,
)
```

密码、验证码字段分别使用 `Icons.lock_outline_rounded` 和 `Icons.mark_email_read_outlined`。主提交按钮替换为 `PeturePrimaryButton`，切换登录方式按钮使用 `PetureSecondaryButton` 或 `TextButton`，协议区文字使用 `PetureTextStyles.caption`。

- [ ] **Step 3: 邮箱注册页使用统一结构**

在 `email_register_page.dart` 引入设计系统：

```dart
import '../../../shared/design_system/peture_design_system.dart';
```

页面背景使用 `PetureColors.background`。把成功/错误消息改为 `PetureAlertPanel`：

```dart
if (_successMessage != null)
  PetureAlertPanel(
    title: '验证码已发送',
    message: _successMessage!,
    icon: Icons.mark_email_read_outlined,
  )
else if (_errorMessage != null)
  PetureAlertPanel(
    title: '无法继续',
    message: _errorMessage!,
    icon: Icons.error_outline_rounded,
    danger: true,
  )
```

发送验证码和验证按钮使用 `PeturePrimaryButton`，返回登录入口使用 `PetureSecondaryButton` 或 `TextButton`。

- [ ] **Step 4: 手机号登录页明确不可用状态**

在 `phone_login_page.dart` 引入设计系统，并把首屏顶部加入：

```dart
const PetureAlertPanel(
  title: '短信登录暂不可用',
  message: '请使用邮箱登录。手机号入口会在短信服务准备好后开放。',
  icon: Icons.phone_android_rounded,
)
```

保留 `_requestSmsCode` 和 `_verifySmsCodeAndLogin` 的不可用提示，不接入任何短信能力。按钮改为禁用态或点击后继续显示现有提示。

- [ ] **Step 5: 分析认证页面**

Run: `flutter analyze lib/features/auth/presentation`

Expected: 登录注册相关文件无新增错误。

- [ ] **Step 6: 提交**

```bash
git add lib/features/auth/presentation
git commit -m "feat: align auth screens with Peture design system"
```

## Task 4: 设置安全链路视觉收敛

**Files:**
- Modify: `lib/features/profile/presentation/account_security_page.dart`
- Modify: `lib/features/profile/presentation/change_password_page.dart`
- Modify: `lib/features/profile/presentation/account_deactivate_page.dart`

- [ ] **Step 1: 账户安全页改为系统列表卡**

在 `account_security_page.dart` 引入：

```dart
import '../../../shared/design_system/peture_design_system.dart';
```

使用 `PeturePageScaffold(title: '账号安全')`。列表容器使用 `PetureCard`。修改密码入口使用 `PetureColors.blue`，账号注销入口使用 `PetureColors.danger`。保留原有两个 `Navigator.of(context).push(...)`。

- [ ] **Step 2: 修改密码页统一表单**

在 `change_password_page.dart` 引入设计系统，移除 `google_fonts` 的页面级视觉依赖。标题、说明文本、Switch 容器、表单卡、按钮均使用设计系统。保留全部 Supabase 校验、OTP、倒计时、全局退出逻辑。

将 `_fieldDecoration` 改为返回：

```dart
return petureInputDecoration(
  label: label,
  hint: hint,
  icon: icon,
  suffix: suffix,
);
```

提交按钮使用：

```dart
PeturePrimaryButton(
  label: '确认修改',
  isLoading: _isSubmitting,
  onPressed: _submit,
)
```

- [ ] **Step 3: 注销页建立风险层级**

在 `account_deactivate_page.dart` 引入设计系统。页面使用 `PeturePageScaffold(title: '账号注销')`。首屏说明使用 `PetureAlertPanel(danger: true)` 加正文说明卡。验证码步骤使用 `PetureCard` 包裹 `TextField` 和重发按钮。底部主危险操作使用 `PetureDangerButton(label: '开始注销流程')`。

保留 `_onTapStartDeactivate`、`_sendDeletionOtp`、`_verifyOtpAndDeleteAccount` 的业务逻辑和弹窗流程。

- [ ] **Step 4: 分析设置安全链路**

Run: `flutter analyze lib/features/profile/presentation/account_security_page.dart lib/features/profile/presentation/change_password_page.dart lib/features/profile/presentation/account_deactivate_page.dart`

Expected: 三个文件无新增错误。

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/presentation/account_security_page.dart lib/features/profile/presentation/change_password_page.dart lib/features/profile/presentation/account_deactivate_page.dart
git commit -m "feat: polish account security screens"
```

## Task 5: P1 主路径明显割裂页收敛

**Files:**
- Modify: `lib/features/image_generation/presentation/preparation_page.dart`
- Modify: `lib/features/medical/presentation/medical_record_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/features/expense/presentation/unified_expense_home_page.dart`
- Modify: `lib/features/dog_clicker/presentation/dog_clicker_screen.dart`
- Modify: `lib/features/diary/presentation/pet_diary_compose_page.dart`

- [ ] **Step 1: AI 图像页降低孤立霓虹感**

在 `preparation_page.dart` 中保留局部 `AppColors` 类名，但将背景、surface、文字和主色映射到设计系统。保留 AI 图像生成、预检、上传、缓存、风格选择所有逻辑。

目标替换：

```dart
background = PetureColors.background
surface = PetureColors.surfacePure
primary = PetureColors.violet
secondary = PetureColors.blue
accent = PetureColors.primary
```

- [ ] **Step 2: 医疗记录页迁移局部主题颜色**

在 `medical_record_screen.dart` 保留 `AppTheme` 类名，但把颜色映射到 `PetureColors`，文本样式映射到 `PetureTextStyles`。保留健康记录、提醒、体重趋势、数据刷新逻辑。

- [ ] **Step 3: 个人页统一卡片和头像边框**

在 `profile_screen.dart` 的页面背景、头像渐变、宠物卡片容器、列表项容器使用设计系统 token。保留头像上传、昵称编辑、宠物资料入口和数据刷新逻辑。

- [ ] **Step 4: 消费首页统一背景和图表容器**

在 `unified_expense_home_page.dart` 的 `ExpenseStyles` 中把 `bgGradient`、`mainGradient`、`textDark`、`textGrey`、`glassDecoration` 映射到设计系统。保留账本、统计、图表、日期范围和账单逻辑。

- [ ] **Step 5: 响片页只改外围**

在 `dog_clicker_screen.dart` 保留 `SkeuomorphicClickerDevice` 的拟物设备视觉。只统一页面背景、标题、面板、按钮和弹窗。训练设备本体不重绘。

- [ ] **Step 6: 日记撰写页统一输入与选择器**

在 `pet_diary_compose_page.dart` 统一背景、宠物选择器、风格选择 chip、输入框、生成按钮。保留示例文本、审核、跳转到结果页等逻辑。

- [ ] **Step 7: 分析 P1 页面**

Run: `flutter analyze lib/features/image_generation/presentation/preparation_page.dart lib/features/medical/presentation/medical_record_screen.dart lib/features/profile/presentation/profile_screen.dart lib/features/expense/presentation/unified_expense_home_page.dart lib/features/dog_clicker/presentation/dog_clicker_screen.dart lib/features/diary/presentation/pet_diary_compose_page.dart`

Expected: 无新增错误。若旧文件已有与本次无关警告，记录并确认没有由本任务新增。

- [ ] **Step 8: 提交**

```bash
git add lib/features/image_generation/presentation/preparation_page.dart lib/features/medical/presentation/medical_record_screen.dart lib/features/profile/presentation/profile_screen.dart lib/features/expense/presentation/unified_expense_home_page.dart lib/features/dog_clicker/presentation/dog_clicker_screen.dart lib/features/diary/presentation/pet_diary_compose_page.dart
git commit -m "feat: align primary MVP pages with design system"
```

## Task 6: 全量验证与收尾

**Files:**
- Test: existing `test/`

- [ ] **Step 1: 运行全局分析**

Run: `flutter analyze`

Expected: 不存在新增错误。若仓库存在历史警告，列出警告数量和代表文件。

- [ ] **Step 2: 运行 Flutter 测试**

Run: `flutter test`

Expected: 所有现有测试通过。若测试依赖环境缺失，记录具体失败原因和命令输出。

- [ ] **Step 3: 手动检查主路径**

在可用设备上依次检查：

```text
根登录页
邮箱登录
邮箱注册
首页
宠物消费
电子档案
第一人称日记
训宠响片
AI 图像实验室
医疗记录 Tab
个人中心 Tab
账户安全
修改密码
账号注销
```

检查点：

```text
页面背景不割裂
按钮样式统一
输入框样式统一
底部导航不遮挡内容
危险操作有明确风险层级
登录首屏保留深色宇宙风格但控件与品牌一致
5 个 MVP 首页入口仍存在且可点击
```

- [ ] **Step 4: 最终提交**

若 Step 1、Step 2 或 Step 3 产生修复，先运行：

```bash
git status --short
git diff --name-only
```

然后只暂存 `git diff --name-only` 中与本计划相关的文件，并提交：

```bash
git commit -m "fix: address design system verification issues"
```

只有在 Step 1 或 Step 2/3 产生修复文件时执行最终提交；如果没有额外修复，不创建空提交。

## 自审

- 规格覆盖：计划覆盖设计系统、首页、登录注册、账号安全链路、P1 明显割裂页、验证标准。
- 占位扫描：计划不包含待填占位项。
- 类型一致性：所有新增组件名均由 Task 1 定义，后续任务只引用这些组件。
- 范围控制：不新增功能，不改变认证、Supabase、生成、删除、账单、宠物资料等业务逻辑。
