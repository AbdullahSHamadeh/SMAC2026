import 'package:flutter/widgets.dart';

enum FamilyCompassWindowSize {
  compact,
  medium,
  expanded,
  large,
  extraLarge,
}

/// Width and height classes used across the adaptive interface.
abstract final class FamilyCompassBreakpoints {
  static const compactWidth = 600.0;
  static const mediumWidth = 840.0;
  static const expandedWidth = 1200.0;
  static const largeWidth = 1600.0;
  static const compactHeight = 480.0;

  static FamilyCompassWindowSize widthClass(double width) {
    if (width < compactWidth) return FamilyCompassWindowSize.compact;
    if (width < mediumWidth) return FamilyCompassWindowSize.medium;
    if (width < expandedWidth) return FamilyCompassWindowSize.expanded;
    if (width < largeWidth) return FamilyCompassWindowSize.large;
    return FamilyCompassWindowSize.extraLarge;
  }

  static FamilyCompassWindowSize of(BuildContext context) {
    return widthClass(MediaQuery.sizeOf(context).width);
  }

  static bool hasCompactHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < compactHeight;
  }
}
