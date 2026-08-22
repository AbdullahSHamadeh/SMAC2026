import 'package:flutter/material.dart';

/// Approved raw color values for Family Compass.
///
/// The palette is warm and domestic: linen paper, deep teal, and terracotta.
/// Screens should normally read colors from [Theme.of] or
/// [FamilyCompassSemanticColors] instead of using this palette directly.
abstract final class FamilyCompassPalette {
  // Shared.
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Light theme.
  static const lightBackground = Color(0xFFF3EBE0);
  static const lightAtmosphere = Color(0xFFE7F0EC);
  static const lightSurface = Color(0xFFFFFBF6);
  static const lightSurfaceRaised = Color(0xFFF7F0E6);
  static const lightPrimary = Color(0xFF1E5C57);
  static const lightOnPrimary = white;
  static const lightPrimaryContainer = Color(0xFFD5EBE6);
  static const lightOnPrimaryContainer = Color(0xFF0C2F2C);
  static const lightGathering = Color(0xFFB4532A);
  static const lightOnGathering = white;
  static const lightGatheringContainer = Color(0xFFF6DCCB);
  static const lightOnGatheringContainer = Color(0xFF3D1B0C);
  static const lightText = Color(0xFF2A2118);
  static const lightSecondaryText = Color(0xFF6B5D50);
  static const lightOutline = Color(0xFFE4D6C6);
  static const lightSuccess = Color(0xFF2F6B4A);
  static const lightOnSuccess = white;
  static const lightSuccessContainer = Color(0xFFD8EEDF);
  static const lightOnSuccessContainer = Color(0xFF113D24);
  static const lightWarning = Color(0xFF8A5A12);
  static const lightOnWarning = white;
  static const lightWarningContainer = Color(0xFFF6E2B8);
  static const lightOnWarningContainer = Color(0xFF2B1B00);
  static const lightError = Color(0xFFB3261E);
  static const lightOnError = white;
  static const lightErrorContainer = Color(0xFFF9DEDC);
  static const lightOnErrorContainer = Color(0xFF410E0B);
  static const lightShadow = Color(0x1F2A2118);
  static const lightAvatarTeal = Color(0xFF1E5C57);
  static const lightAvatarClay = Color(0xFFB4532A);
  static const lightAvatarSage = Color(0xFF4E6B4A);
  static const lightAvatarPlum = Color(0xFF6D4C7D);

  // Dark theme.
  static const darkBackground = Color(0xFF14110E);
  static const darkAtmosphere = Color(0xFF1A221F);
  static const darkSurface = Color(0xFF1D1915);
  static const darkSurfaceRaised = Color(0xFF28231E);
  static const darkPrimary = Color(0xFF8FCFC6);
  static const darkOnPrimary = Color(0xFF08322E);
  static const darkPrimaryContainer = Color(0xFF1F4A46);
  static const darkOnPrimaryContainer = Color(0xFFD4F0EB);
  static const darkGathering = Color(0xFFF0B089);
  static const darkOnGathering = Color(0xFF3C1A0B);
  static const darkGatheringContainer = Color(0xFF5C3220);
  static const darkOnGatheringContainer = Color(0xFFF8DCC9);
  static const darkText = Color(0xFFF6EFE6);
  static const darkSecondaryText = Color(0xFFC9B8A6);
  static const darkOutline = Color(0xFF4A4036);
  static const darkSuccess = Color(0xFF8FCBAA);
  static const darkOnSuccess = Color(0xFF003916);
  static const darkSuccessContainer = Color(0xFF1B4A32);
  static const darkOnSuccessContainer = Color(0xFFC8F0D8);
  static const darkWarning = Color(0xFFE8C27A);
  static const darkOnWarning = Color(0xFF412D00);
  static const darkWarningContainer = Color(0xFF5F4300);
  static const darkOnWarningContainer = Color(0xFFFFE2A8);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkShadow = Color(0x66000000);
  static const darkAvatarTeal = Color(0xFF8FCFC6);
  static const darkAvatarClay = Color(0xFFF0B089);
  static const darkAvatarSage = Color(0xFFA8C4A3);
  static const darkAvatarPlum = Color(0xFFC9A8D6);
}
