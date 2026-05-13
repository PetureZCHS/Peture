import 'package:flutter/material.dart';

import 'peture_tokens.dart';

class PetureGradients {
  const PetureGradients._();

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PetureColors.primary, PetureColors.amber],
  );

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PetureColors.mint, PetureColors.blue],
  );

  static const LinearGradient tech = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PetureColors.blue, PetureColors.violet],
  );

  static const LinearGradient warmSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PetureColors.surface, PetureColors.surfaceMuted],
  );

  static const LinearGradient cosmic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      PetureColors.cosmicStart,
      PetureColors.cosmicMid,
      PetureColors.cosmicEnd,
    ],
  );
}
