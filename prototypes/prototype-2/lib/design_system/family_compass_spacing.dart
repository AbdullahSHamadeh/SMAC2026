/// Shared spacing, shape, and sizing constants.
abstract final class FamilyCompassSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

abstract final class FamilyCompassRadii {
  static const small = 12.0;
  static const medium = 20.0;
  static const large = 28.0;
  static const extraLarge = 36.0;
  static const pill = 999.0;
}

abstract final class FamilyCompassSizes {
  static const minimumTouchTarget = 48.0;
  static const compactContentPadding = 16.0;
  static const mediumContentPadding = 24.0;
  static const expandedContentPadding = 32.0;
  static const maximumContentWidth = 1200.0;
  static const navigationRailWidth = 88.0;
  static const brandMark = 40.0;
}

abstract final class FamilyCompassShadows {
  static const List<BoxShadow> lightCard = [
    BoxShadow(
      color: Color(0x142A2118),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x0A2A2118),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> darkCard = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> lightBar = [
    BoxShadow(
      color: Color(0x142A2118),
      blurRadius: 18,
      offset: Offset(0, -4),
    ),
  ];

  static const List<BoxShadow> darkBar = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}
