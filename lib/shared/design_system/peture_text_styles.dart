import 'package:flutter/material.dart';

import 'peture_tokens.dart';

class PetureTextStyles {
  const PetureTextStyles._();

  static const String fontFamily = '.SF Pro Text';

  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: PetureColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.22,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: PetureColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: PetureColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: PetureColors.textTertiary,
  );
}
