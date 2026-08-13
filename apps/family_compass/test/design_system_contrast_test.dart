import 'package:family_compass/design_system/family_compass_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Family Invitation Folio contrast', () {
    test('light text and status inks meet WCAG AA on their surfaces', () {
      _expectContrast(
        FamilyCompassPalette.lightSecondaryText,
        FamilyCompassPalette.lightSurface,
      );
      _expectContrast(
        FamilyCompassPalette.lightSecondaryText,
        FamilyCompassPalette.lightBackground,
      );
      _expectContrast(
        FamilyCompassPalette.lightGatheringInk,
        FamilyCompassPalette.lightSurface,
      );
      _expectContrast(
        FamilyCompassPalette.lightGatheringInk,
        FamilyCompassPalette.lightBackground,
      );
      _expectContrast(
        FamilyCompassPalette.lightWarning,
        FamilyCompassPalette.lightSurface,
      );
      _expectContrast(
        FamilyCompassPalette.lightOnWarning,
        FamilyCompassPalette.lightWarning,
      );
    });

    test('dark text and status inks meet WCAG AA on their surfaces', () {
      _expectContrast(
        FamilyCompassPalette.darkSecondaryText,
        FamilyCompassPalette.darkSurface,
      );
      _expectContrast(
        FamilyCompassPalette.darkGatheringInk,
        FamilyCompassPalette.darkSurface,
      );
      _expectContrast(
        FamilyCompassPalette.darkWarning,
        FamilyCompassPalette.darkSurface,
      );
    });

    test('inactive navigation labels meet WCAG AA in both themes', () {
      _expectContrast(
        Color.lerp(
          FamilyCompassPalette.lightPrimary,
          FamilyCompassPalette.lightOnPrimary,
          0.78,
        )!,
        FamilyCompassPalette.lightPrimary,
      );
      _expectContrast(
        Color.lerp(
          FamilyCompassPalette.darkPrimary,
          FamilyCompassPalette.darkOnPrimary,
          0.78,
        )!,
        FamilyCompassPalette.darkPrimary,
      );
    });
  });
}

void _expectContrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  final ratio = (lighter + 0.05) / (darker + 0.05);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '${foreground.toARGB32().toRadixString(16)} on '
        '${background.toARGB32().toRadixString(16)} has ${ratio.toStringAsFixed(2)}:1',
  );
}
