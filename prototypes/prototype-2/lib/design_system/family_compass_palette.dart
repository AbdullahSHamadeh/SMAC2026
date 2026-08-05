import 'package:flutter/material.dart';

/// Approved raw color values for Family Compass.
///
/// Screens should normally read colors from [Theme.of] or
/// [FamilyCompassSemanticColors] instead of using this palette directly.
abstract final class FamilyCompassPalette {
  // Shared.
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Light theme.
  static const lightBackground = Color(0xFFF7F5F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFF1F3F6);
  static const lightPrimary = Color(0xFF2457C5);
  static const lightOnPrimary = white;
  static const lightPrimaryContainer = Color(0xFFDCE8FF);
  static const lightOnPrimaryContainer = Color(0xFF102A56);
  static const lightGathering = Color(0xFF6F4AA8);
  static const lightOnGathering = white;
  static const lightGatheringContainer = Color(0xFFE9DDF7);
  static const lightOnGatheringContainer = Color(0xFF35204F);
  static const lightText = Color(0xFF17202A);
  static const lightSecondaryText = Color(0xFF5B6573);
  static const lightOutline = Color(0xFFCBD3DE);
  static const lightSuccess = Color(0xFF267A46);
  static const lightOnSuccess = white;
  static const lightSuccessContainer = Color(0xFFD9F2E1);
  static const lightOnSuccessContainer = Color(0xFF113D24);
  static const lightWarning = Color(0xFF8A5A00);
  static const lightOnWarning = white;
  static const lightWarningContainer = Color(0xFFFFDEA3);
  static const lightOnWarningContainer = Color(0xFF2B1B00);
  static const lightError = Color(0xFFB3261E);
  static const lightOnError = white;
  static const lightErrorContainer = Color(0xFFF9DEDC);
  static const lightOnErrorContainer = Color(0xFF410E0B);

  // Dark theme.
  static const darkBackground = Color(0xFF101318);
  static const darkSurface = Color(0xFF181C22);
  static const darkSurfaceRaised = Color(0xFF222833);
  static const darkPrimary = Color(0xFFAFC6FF);
  static const darkOnPrimary = Color(0xFF082B69);
  static const darkPrimaryContainer = Color(0xFF244679);
  static const darkOnPrimaryContainer = Color(0xFFD8E2FF);
  static const darkGathering = Color(0xFFD3B8FF);
  static const darkOnGathering = Color(0xFF32165B);
  static const darkGatheringContainer = Color(0xFF4F3478);
  static const darkOnGatheringContainer = Color(0xFFE9DDFF);
  static const darkText = Color(0xFFF3F4F6);
  static const darkSecondaryText = Color(0xFFB8C0CC);
  static const darkOutline = Color(0xFF89919D);
  static const darkSuccess = Color(0xFF7ED69A);
  static const darkOnSuccess = Color(0xFF003916);
  static const darkSuccessContainer = Color(0xFF14552E);
  static const darkOnSuccessContainer = Color(0xFFA2F4B7);
  static const darkWarning = Color(0xFFF2C66D);
  static const darkOnWarning = Color(0xFF412D00);
  static const darkWarningContainer = Color(0xFF5F4300);
  static const darkOnWarningContainer = Color(0xFFFFE2A8);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
}
