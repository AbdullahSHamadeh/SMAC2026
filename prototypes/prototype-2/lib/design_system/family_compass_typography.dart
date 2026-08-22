import 'package:flutter/material.dart';

import 'family_compass_breakpoints.dart';

/// Family Compass typography based on Material 3 roles.
///
/// Body and label sizes remain stable across window sizes. Only high-level
/// headings grow on larger windows. Flutter's MediaQuery text scaler is left
/// intact so user accessibility preferences continue to apply.
abstract final class FamilyCompassTypography {
  static const letterSpacingTight = -0.4;
  static const letterSpacingDisplay = -0.8;
  static const letterSpacingLabel = 0.2;

  static TextTheme base(TextTheme source) {
    return source.copyWith(
      displayLarge: source.displayLarge?.copyWith(
        fontSize: 44,
        height: 1.08,
        letterSpacing: letterSpacingDisplay,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: source.displayMedium?.copyWith(
        fontSize: 40,
        height: 1.10,
        letterSpacing: letterSpacingDisplay,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: source.displaySmall?.copyWith(
        fontSize: 36,
        height: 1.11,
        letterSpacing: letterSpacingTight,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: source.headlineLarge?.copyWith(
        fontSize: 32,
        height: 1.18,
        letterSpacing: letterSpacingTight,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: source.headlineMedium?.copyWith(
        fontSize: 28,
        height: 1.22,
        letterSpacing: letterSpacingTight,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: source.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.28,
        letterSpacing: letterSpacingTight,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: source.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.27,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: source.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.45,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: source.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.40,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: source.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: source.bodyMedium?.copyWith(fontSize: 14, height: 1.50),
      bodySmall: source.bodySmall?.copyWith(fontSize: 12, height: 1.40),
      labelLarge: source.labelLarge?.copyWith(
        fontSize: 14,
        height: 1.35,
        letterSpacing: letterSpacingLabel,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: source.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.30,
        letterSpacing: letterSpacingLabel,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: source.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.40,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static TextTheme forWidth(TextTheme source, double width) {
    final textTheme = base(source);
    return switch (FamilyCompassBreakpoints.widthClass(width)) {
      FamilyCompassWindowSize.compact => textTheme,
      FamilyCompassWindowSize.medium => _withHeadings(
          textTheme,
          displayLarge: 48,
          headlineLarge: 34,
          headlineMedium: 30,
        ),
      FamilyCompassWindowSize.expanded ||
      FamilyCompassWindowSize.large ||
      FamilyCompassWindowSize.extraLarge =>
        _withHeadings(
          textTheme,
          displayLarge: 56,
          headlineLarge: 40,
          headlineMedium: 34,
        ),
    };
  }

  static TextTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return forWidth(theme.textTheme, MediaQuery.sizeOf(context).width);
  }

  static TextTheme _withHeadings(
    TextTheme source, {
    required double displayLarge,
    required double headlineLarge,
    required double headlineMedium,
  }) {
    return source.copyWith(
      displayLarge: source.displayLarge?.copyWith(fontSize: displayLarge),
      headlineLarge: source.headlineLarge?.copyWith(fontSize: headlineLarge),
      headlineMedium: source.headlineMedium?.copyWith(fontSize: headlineMedium),
    );
  }
}
