import 'package:flutter/material.dart';

import 'family_compass_breakpoints.dart';

/// A compact native type ramp that leaves text scaling fully under the user's
/// control. Arabic keeps its platform letter spacing and line metrics.
abstract final class FamilyCompassTypography {
  static TextTheme base(TextTheme source) {
    return source.copyWith(
      displayLarge: source.displayLarge?.copyWith(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      displayMedium: source.displayMedium?.copyWith(
        fontSize: 30,
        height: 1.20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      displaySmall: source.displaySmall?.copyWith(
        fontSize: 28,
        height: 1.21,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: source.headlineLarge?.copyWith(
        fontSize: 28,
        height: 1.21,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: source.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: source.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.27,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: source.titleLarge?.copyWith(
        fontSize: 21,
        height: 1.30,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: source.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: source.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: source.bodyLarge?.copyWith(fontSize: 17, height: 1.42),
      bodyMedium: source.bodyMedium?.copyWith(fontSize: 15, height: 1.42),
      bodySmall: source.bodySmall?.copyWith(fontSize: 13, height: 1.38),
      labelLarge: source.labelLarge?.copyWith(
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: source.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: source.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.45,
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
          displayLarge: 36,
          headlineLarge: 30,
          headlineMedium: 26,
        ),
      FamilyCompassWindowSize.expanded ||
      FamilyCompassWindowSize.large ||
      FamilyCompassWindowSize.extraLarge =>
        _withHeadings(
          textTheme,
          displayLarge: 40,
          headlineLarge: 32,
          headlineMedium: 28,
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
