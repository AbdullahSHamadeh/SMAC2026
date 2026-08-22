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
        tertiary: FamilyCompassPalette.lightAvatarSage,
        onTertiary: FamilyCompassPalette.white,
        tertiaryContainer: FamilyCompassPalette.lightSuccessContainer,
        onTertiaryContainer: FamilyCompassPalette.lightOnSuccessContainer,
        error: FamilyCompassPalette.lightError,
        onError: FamilyCompassPalette.lightOnError,
        errorContainer: FamilyCompassPalette.lightErrorContainer,
        onErrorContainer: FamilyCompassPalette.lightOnErrorContainer,
        surface: FamilyCompassPalette.lightSurface,
        surfaceContainerLowest: FamilyCompassPalette.lightSurface,
        surfaceContainerLow: FamilyCompassPalette.lightBackground,
        surfaceContainer: FamilyCompassPalette.lightSurfaceRaised,
        surfaceContainerHigh: FamilyCompassPalette.lightSurfaceRaised,
        surfaceContainerHighest: FamilyCompassPalette.lightPrimaryContainer,
        onSurface: FamilyCompassPalette.lightText,
        onSurfaceVariant: FamilyCompassPalette.lightSecondaryText,
        outline: FamilyCompassPalette.lightOutline,
        outlineVariant: FamilyCompassPalette.lightOutline,
        shadow: FamilyCompassPalette.lightShadow,
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
        tertiary: FamilyCompassPalette.darkAvatarSage,
        onTertiary: FamilyCompassPalette.darkOnSuccess,
        tertiaryContainer: FamilyCompassPalette.darkSuccessContainer,
        onTertiaryContainer: FamilyCompassPalette.darkOnSuccessContainer,
        error: FamilyCompassPalette.darkError,
        onError: FamilyCompassPalette.darkOnError,
        errorContainer: FamilyCompassPalette.darkErrorContainer,
        onErrorContainer: FamilyCompassPalette.darkOnErrorContainer,
        surface: FamilyCompassPalette.darkSurface,
        surfaceContainerLowest: FamilyCompassPalette.darkBackground,
        surfaceContainerLow: FamilyCompassPalette.darkSurface,
        surfaceContainer: FamilyCompassPalette.darkSurfaceRaised,
        surfaceContainerHigh: FamilyCompassPalette.darkSurfaceRaised,
        surfaceContainerHighest: FamilyCompassPalette.darkPrimaryContainer,
        onSurface: FamilyCompassPalette.darkText,
        onSurfaceVariant: FamilyCompassPalette.darkSecondaryText,
        outline: FamilyCompassPalette.darkOutline,
        outlineVariant: FamilyCompassPalette.darkOutline,
        shadow: FamilyCompassPalette.darkShadow,
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
    final roundedLarge = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
    );
    final roundedPill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
    );

    return seed.copyWith(
      scaffoldBackgroundColor: semanticColors.pageBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
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
        clipBehavior: Clip.antiAlias,
        shadowColor: colorScheme.shadow,
        shape: roundedLarge,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        height: 76,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: roundedPill,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelMedium;
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: colorScheme.primary);
          }
          return base?.copyWith(color: colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: roundedPill,
        minWidth: FamilyCompassSizes.navigationRailWidth,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, FamilyCompassSizes.minimumTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.lg,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: roundedPill,
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
          shape: roundedPill,
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
          shape: roundedPill,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: roundedPill,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.md,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FamilyCompassRadii.pill),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: seed.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide.none,
        shape: roundedPill,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.sm,
          vertical: FamilyCompassSpacing.xxs,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colorScheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FamilyCompassRadii.extraLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: roundedLarge,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        shape: roundedMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.surface,
        ),
        shape: roundedMedium,
      ),
    );
  }
}
