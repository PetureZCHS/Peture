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
    ).copyWith(
      onPrimary: PetureColors.surfacePure,
      onSecondary: PetureColors.surfacePure,
      onSurface: PetureColors.textPrimary,
      outline: PetureColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PetureColors.background,
      primaryColor: PetureColors.primary,
      fontFamily: PetureTextStyles.fontFamily,
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        displayLarge: PetureTextStyles.largeTitle,
        headlineMedium: PetureTextStyles.title,
        titleMedium: PetureTextStyles.sectionTitle,
        bodyLarge: PetureTextStyles.body,
        bodyMedium: PetureTextStyles.body,
        labelLarge: PetureTextStyles.label,
        bodySmall: PetureTextStyles.caption,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PetureColors.textPrimary,
        iconTheme: IconThemeData(color: PetureColors.textPrimary),
        titleTextStyle: PetureTextStyles.sectionTitle,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PetureColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PetureSpacing.lg,
          vertical: PetureSpacing.md,
        ),
        hintStyle: PetureTextStyles.body.copyWith(
          color: PetureColors.textTertiary,
        ),
        labelStyle: PetureTextStyles.label.copyWith(
          color: PetureColors.textSecondary,
        ),
        border: _inputBorder(PetureColors.border),
        enabledBorder: _inputBorder(PetureColors.border),
        focusedBorder: _inputBorder(PetureColors.primary, width: 1.4),
        errorBorder: _inputBorder(PetureColors.danger),
        focusedErrorBorder: _inputBorder(PetureColors.danger, width: 1.4),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PetureColors.primary,
          textStyle: PetureTextStyles.label,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(PetureRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
