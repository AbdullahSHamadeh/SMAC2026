import 'package:flutter/material.dart';

import 'family_compass_palette.dart';
import 'family_compass_semantic_colors.dart';
import 'family_compass_spacing.dart';
import 'family_compass_typography.dart';

abstract final class FamilyCompassTheme {
  static ThemeData get light => _build(
        colorScheme: _lightScheme,
        semanticColors: FamilyCompassSemanticColors.light,
      );

  static ThemeData get dark => _build(
        colorScheme: _darkScheme,
        semanticColors: FamilyCompassSemanticColors.dark,
      );

  static ColorScheme get _lightScheme => ColorScheme.fromSeed(
        seedColor: FamilyCompassPalette.lightPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: FamilyCompassPalette.lightPrimary,
        onPrimary: FamilyCompassPalette.lightOnPrimary,
        primaryContainer: FamilyCompassPalette.lightPrimaryContainer,
        onPrimaryContainer: FamilyCompassPalette.lightOnPrimaryContainer,
        secondary: FamilyCompassPalette.lightGathering,
        onSecondary: FamilyCompassPalette.lightOnGathering,
        secondaryContainer: FamilyCompassPalette.lightGatheringContainer,
        onSecondaryContainer: FamilyCompassPalette.lightOnGatheringContainer,
        error: FamilyCompassPalette.lightError,
        onError: FamilyCompassPalette.lightOnError,
        errorContainer: FamilyCompassPalette.lightErrorContainer,
        onErrorContainer: FamilyCompassPalette.lightOnErrorContainer,
        surface: FamilyCompassPalette.lightSurface,
        surfaceContainerLowest: FamilyCompassPalette.lightSurface,
        surfaceContainerLow: FamilyCompassPalette.lightBackground,
        surfaceContainer: FamilyCompassPalette.lightSurfaceRaised,
        surfaceContainerHigh: FamilyCompassPalette.lightSurfaceRaised,
        surfaceContainerHighest: FamilyCompassPalette.lightSurfaceRaised,
        onSurface: FamilyCompassPalette.lightText,
        onSurfaceVariant: FamilyCompassPalette.lightSecondaryText,
        outline: FamilyCompassPalette.lightOutline,
        outlineVariant: FamilyCompassPalette.lightOutline,
        surfaceTint: Colors.transparent,
      );

  static ColorScheme get _darkScheme => ColorScheme.fromSeed(
        seedColor: FamilyCompassPalette.darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: FamilyCompassPalette.darkPrimary,
        onPrimary: FamilyCompassPalette.darkOnPrimary,
        primaryContainer: FamilyCompassPalette.darkPrimaryContainer,
        onPrimaryContainer: FamilyCompassPalette.darkOnPrimaryContainer,
        secondary: FamilyCompassPalette.darkGathering,
        onSecondary: FamilyCompassPalette.darkOnGathering,
        secondaryContainer: FamilyCompassPalette.darkGatheringContainer,
        onSecondaryContainer: FamilyCompassPalette.darkOnGatheringContainer,
        error: FamilyCompassPalette.darkError,
        onError: FamilyCompassPalette.darkOnError,
        errorContainer: FamilyCompassPalette.darkErrorContainer,
        onErrorContainer: FamilyCompassPalette.darkOnErrorContainer,
        surface: FamilyCompassPalette.darkSurface,
        surfaceContainerLowest: FamilyCompassPalette.darkBackground,
        surfaceContainerLow: FamilyCompassPalette.darkSurface,
        surfaceContainer: FamilyCompassPalette.darkSurfaceRaised,
        surfaceContainerHigh: FamilyCompassPalette.darkSurfaceRaised,
        surfaceContainerHighest: FamilyCompassPalette.darkSurfaceRaised,
        onSurface: FamilyCompassPalette.darkText,
        onSurfaceVariant: FamilyCompassPalette.darkSecondaryText,
        outline: FamilyCompassPalette.darkOutline,
        outlineVariant: FamilyCompassPalette.darkOutline,
        surfaceTint: Colors.transparent,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required FamilyCompassSemanticColors semanticColors,
  }) {
    final seed = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
    );
    final textTheme = FamilyCompassTypography.base(seed.textTheme).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final roundedMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
    );

    return seed.copyWith(
      scaffoldBackgroundColor: semanticColors.pageBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      appBarTheme: AppBarTheme(
        backgroundColor: semanticColors.pageBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: roundedMedium.copyWith(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        minWidth: FamilyCompassSizes.navigationRailWidth,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: textTheme.labelMedium,
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, FamilyCompassSizes.minimumTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.lg,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          shape: roundedMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, FamilyCompassSizes.minimumTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.lg,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.outline),
          shape: roundedMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, FamilyCompassSizes.minimumTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.md,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          shape: roundedMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: seed.chipTheme.copyWith(
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
        ),
        labelStyle: textTheme.labelMedium,
        padding:
            const EdgeInsets.symmetric(horizontal: FamilyCompassSpacing.xs),
      ),
    );
  }
}
