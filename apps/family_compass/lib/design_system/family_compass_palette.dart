import 'package:flutter/material.dart';

/// Approved raw color values for Family Compass.
///
/// Screens should normally read colors from [Theme.of] or
/// [FamilyCompassSemanticColors] instead of using this palette directly.
abstract final class FamilyCompassPalette {
  // Shared.
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Sunday Table, light theme.
  static const lightBackground = Color(0xFFFFF8F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFF7ECE7);
  static const lightPrimary = Color(0xFF9C3F4B);
  static const lightOnPrimary = white;
  static const lightPrimaryContainer = Color(0xFFF7DDE0);
  static const lightOnPrimaryContainer = Color(0xFF56202A);
  static const lightGathering = Color(0xFFF4B65E);
  static const lightOnGathering = Color(0xFF402B0D);
  static const lightGatheringInk = Color(0xFF70430D);
  static const lightGatheringContainer = Color(0xFFF9D9A4);
  static const lightOnGatheringContainer = Color(0xFF402B0D);
  static const lightText = Color(0xFF352925);
  static const lightSecondaryText = Color(0xFF74635D);
  static const lightOutline = Color(0xFF947E74);
  static const lightSuccess = Color(0xFF2F6D5E);
  static const lightOnSuccess = white;
  static const lightSuccessContainer = Color(0xFFDDECE5);
  static const lightOnSuccessContainer = Color(0xFF245447);
  static const lightWarning = Color(0xFF82530D);
  static const lightOnWarning = white;
  static const lightWarningContainer = Color(0xFFF6E3BF);
  static const lightOnWarningContainer = Color(0xFF573500);
  static const lightError = Color(0xFF9B3A3A);
  static const lightOnError = white;
  static const lightErrorContainer = Color(0xFFF7DDDA);
  static const lightOnErrorContainer = Color(0xFF5A1F1F);

  // Sunday Table, dark theme.
  static const darkBackground = Color(0xFF211A18);
  static const darkSurface = Color(0xFF2C2320);
  static const darkSurfaceRaised = Color(0xFF3A2E2A);
  static const darkPrimary = Color(0xFFF29AA4);
  static const darkOnPrimary = Color(0xFF3D171D);
  static const darkPrimaryContainer = Color(0xFF6B2934);
  static const darkOnPrimaryContainer = Color(0xFFFFE8EB);
  static const darkGathering = Color(0xFFF2C274);
  static const darkOnGathering = Color(0xFF301F09);
  static const darkGatheringInk = darkGathering;
  static const darkGatheringContainer = Color(0xFF604A25);
  static const darkOnGatheringContainer = Color(0xFFFFEDCC);
  static const darkText = Color(0xFFFFF4ED);
  static const darkSecondaryText = Color(0xFFCDBAB0);
  static const darkOutline = Color(0xFF6E5B54);
  static const darkSuccess = Color(0xFF93CDBA);
  static const darkOnSuccess = Color(0xFF153A30);
  static const darkSuccessContainer = Color(0xFF294A41);
  static const darkOnSuccessContainer = Color(0xFFD9F4EA);
  static const darkWarning = Color(0xFFF2C274);
  static const darkOnWarning = Color(0xFF301F09);
  static const darkWarningContainer = Color(0xFF604A25);
  static const darkOnWarningContainer = Color(0xFFFFEDCC);
  static const darkError = Color(0xFFFFB4AC);
  static const darkOnError = Color(0xFF5A1919);
  static const darkErrorContainer = Color(0xFF7A2E2E);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
}
