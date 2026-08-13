import 'package:flutter/cupertino.dart';
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

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
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
    onSurface: FamilyCompassPalette.lightText,
    surfaceContainerLowest: FamilyCompassPalette.lightSurface,
    surfaceContainerLow: FamilyCompassPalette.lightBackground,
    surfaceContainer: FamilyCompassPalette.lightSurfaceRaised,
    surfaceContainerHigh: Color(0xFFF0E1DB),
    surfaceContainerHighest: Color(0xFFE8D7CF),
    onSurfaceVariant: FamilyCompassPalette.lightSecondaryText,
    outline: FamilyCompassPalette.lightOutline,
    outlineVariant: Color(0xFFE9DED7),
    shadow: Color(0x26352925),
    scrim: Color(0x66352925),
    inverseSurface: Color(0xFF4B3933),
    onInverseSurface: Color(0xFFFFF4ED),
    inversePrimary: Color(0xFFF29AA4),
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
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
    onSurface: FamilyCompassPalette.darkText,
    surfaceContainerLowest: FamilyCompassPalette.darkBackground,
    surfaceContainerLow: FamilyCompassPalette.darkSurface,
    surfaceContainer: FamilyCompassPalette.darkSurfaceRaised,
    surfaceContainerHigh: Color(0xFF463732),
    surfaceContainerHighest: Color(0xFF52413B),
    onSurfaceVariant: FamilyCompassPalette.darkSecondaryText,
    outline: FamilyCompassPalette.darkOutline,
    outlineVariant: Color(0xFF51423D),
    shadow: Color(0x99000000),
    scrim: Color(0xB3000000),
    inverseSurface: Color(0xFFFFEDE5),
    onInverseSurface: Color(0xFF3A2A26),
    inversePrimary: FamilyCompassPalette.lightPrimary,
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
      visualDensity: VisualDensity.standard,
    );
    final textTheme = FamilyCompassTypography.base(seed.textTheme).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
    );
    return seed.copyWith(
      scaffoldBackgroundColor: semanticColors.pageBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[semanticColors],
      focusColor: colorScheme.primary.withValues(alpha: 0.16),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: colorScheme.primary,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: colorScheme.brightness,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: semanticColors.pageBackground,
        barBackgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        textTheme: CupertinoTextThemeData(
          primaryColor: colorScheme.primary,
          textStyle: textTheme.bodyLarge,
          actionTextStyle: textTheme.bodyLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          navTitleTextStyle: textTheme.titleLarge,
          navLargeTitleTextStyle: textTheme.displayLarge,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: semanticColors.pageBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: colorScheme.primary, size: 21),
        actionsIconTheme: IconThemeData(color: colorScheme.primary, size: 21),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: sheetShape,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: FamilyCompassSizes.minimumTouchTarget,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.xxs,
        ),
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        shape: sheetShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 64,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        minWidth: FamilyCompassSizes.navigationRailWidth,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.lg,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.lg,
            vertical: FamilyCompassSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.72)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FamilyCompassRadii.small),
          ),
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
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.secondaryContainer,
        checkmarkColor: colorScheme.onSecondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.sm,
          vertical: FamilyCompassSpacing.xs,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: sheetShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: sheetShape,
      ),
    );
  }
}
