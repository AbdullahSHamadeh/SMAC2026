import 'package:flutter/material.dart';

import 'family_compass_palette.dart';

/// Product-specific semantic colors that are not represented by ColorScheme.
///
/// Statuses must always have a text or icon label as well as a color.
@immutable
class FamilyCompassSemanticColors
    extends ThemeExtension<FamilyCompassSemanticColors> {
  const FamilyCompassSemanticColors({
    required this.pageBackground,
    required this.gathering,
    required this.onGathering,
    required this.gatheringInk,
    required this.gatheringContainer,
    required this.onGatheringContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.secondaryText,
    required this.stale,
    required this.privacy,
  });

  static const light = FamilyCompassSemanticColors(
    pageBackground: FamilyCompassPalette.lightBackground,
    gathering: FamilyCompassPalette.lightGathering,
    onGathering: FamilyCompassPalette.lightOnGathering,
    gatheringInk: FamilyCompassPalette.lightGatheringInk,
    gatheringContainer: FamilyCompassPalette.lightGatheringContainer,
    onGatheringContainer: FamilyCompassPalette.lightOnGatheringContainer,
    success: FamilyCompassPalette.lightSuccess,
    onSuccess: FamilyCompassPalette.lightOnSuccess,
    successContainer: FamilyCompassPalette.lightSuccessContainer,
    onSuccessContainer: FamilyCompassPalette.lightOnSuccessContainer,
    warning: FamilyCompassPalette.lightWarning,
    onWarning: FamilyCompassPalette.lightOnWarning,
    warningContainer: FamilyCompassPalette.lightWarningContainer,
    onWarningContainer: FamilyCompassPalette.lightOnWarningContainer,
    secondaryText: FamilyCompassPalette.lightSecondaryText,
    stale: FamilyCompassPalette.lightWarning,
    privacy: FamilyCompassPalette.lightSuccess,
  );

  static const dark = FamilyCompassSemanticColors(
    pageBackground: FamilyCompassPalette.darkBackground,
    gathering: FamilyCompassPalette.darkGathering,
    onGathering: FamilyCompassPalette.darkOnGathering,
    gatheringInk: FamilyCompassPalette.darkGatheringInk,
    gatheringContainer: FamilyCompassPalette.darkGatheringContainer,
    onGatheringContainer: FamilyCompassPalette.darkOnGatheringContainer,
    success: FamilyCompassPalette.darkSuccess,
    onSuccess: FamilyCompassPalette.darkOnSuccess,
    successContainer: FamilyCompassPalette.darkSuccessContainer,
    onSuccessContainer: FamilyCompassPalette.darkOnSuccessContainer,
    warning: FamilyCompassPalette.darkWarning,
    onWarning: FamilyCompassPalette.darkOnWarning,
    warningContainer: FamilyCompassPalette.darkWarningContainer,
    onWarningContainer: FamilyCompassPalette.darkOnWarningContainer,
    secondaryText: FamilyCompassPalette.darkSecondaryText,
    stale: FamilyCompassPalette.darkWarning,
    privacy: FamilyCompassPalette.darkSuccess,
  );

  final Color pageBackground;
  final Color gathering;
  final Color onGathering;

  /// Saffron-family foreground for borders, icons, and text on surfaces.
  final Color gatheringInk;
  final Color gatheringContainer;
  final Color onGatheringContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color secondaryText;
  final Color stale;
  final Color privacy;

  static FamilyCompassSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<FamilyCompassSemanticColors>()!;
  }

  @override
  FamilyCompassSemanticColors copyWith({
    Color? pageBackground,
    Color? gathering,
    Color? onGathering,
    Color? gatheringInk,
    Color? gatheringContainer,
    Color? onGatheringContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? secondaryText,
    Color? stale,
    Color? privacy,
  }) {
    return FamilyCompassSemanticColors(
      pageBackground: pageBackground ?? this.pageBackground,
      gathering: gathering ?? this.gathering,
      onGathering: onGathering ?? this.onGathering,
      gatheringInk: gatheringInk ?? this.gatheringInk,
      gatheringContainer: gatheringContainer ?? this.gatheringContainer,
      onGatheringContainer: onGatheringContainer ?? this.onGatheringContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      secondaryText: secondaryText ?? this.secondaryText,
      stale: stale ?? this.stale,
      privacy: privacy ?? this.privacy,
    );
  }

  @override
  FamilyCompassSemanticColors lerp(
    covariant FamilyCompassSemanticColors? other,
    double t,
  ) {
    if (other == null) return this;
    return FamilyCompassSemanticColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      gathering: Color.lerp(gathering, other.gathering, t)!,
      onGathering: Color.lerp(onGathering, other.onGathering, t)!,
      gatheringInk: Color.lerp(gatheringInk, other.gatheringInk, t)!,
      gatheringContainer: Color.lerp(
        gatheringContainer,
        other.gatheringContainer,
        t,
      )!,
      onGatheringContainer: Color.lerp(
        onGatheringContainer,
        other.onGatheringContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      privacy: Color.lerp(privacy, other.privacy, t)!,
    );
  }
}
