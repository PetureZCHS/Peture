import 'package:flutter/material.dart';

import '../peture_text_styles.dart';
import '../peture_tokens.dart';

InputDecoration petureInputDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color fillColor = PetureColors.surface,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(PetureRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: PetureSpacing.lg,
      vertical: PetureSpacing.md,
    ),
    hintStyle: PetureTextStyles.body.copyWith(color: PetureColors.textTertiary),
    labelStyle: PetureTextStyles.label.copyWith(
      color: PetureColors.textSecondary,
    ),
    border: border(PetureColors.border),
    enabledBorder: border(PetureColors.border),
    focusedBorder: border(PetureColors.primary, width: 1.4),
    errorBorder: border(PetureColors.danger),
    focusedErrorBorder: border(PetureColors.danger, width: 1.4),
  );
}
