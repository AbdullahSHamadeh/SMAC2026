import 'package:flutter/material.dart';

import 'family_compass_semantic_colors.dart';
import 'family_compass_spacing.dart';

/// Soft linen-to-sage wash used behind every primary screen.
class PageAtmosphere extends StatelessWidget {
  const PageAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.atmosphere,
            colors.pageBackground,
            colors.pageBackground,
          ],
          stops: const [0, 0.38, 1],
        ),
      ),
      child: child,
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.onTap,
    this.border,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(FamilyCompassSpacing.lg),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
        boxShadow: colors.cardShadows,
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.child,
    this.padding,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    return SoftCard(
      color: emphasized ? colors.gatheringContainer : colors.gatheringContainer,
      padding: padding,
      child: child,
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = FamilyCompassSizes.brandMark});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.explore_rounded,
        color: scheme.onPrimary,
        size: size * 0.56,
      ),
    );
  }
}

class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 44,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(
        icon,
        color: foreground ?? scheme.onPrimaryContainer,
        size: size * 0.5,
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.initials,
    this.memberId,
    this.radius = 20,
  });

  final String initials;
  final String? memberId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    final background = colors.avatarFor(memberId);
    final luminance = background.computeLuminance();
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundColor:
          luminance > 0.55 ? const Color(0xFF2A2118) : Colors.white,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: luminance > 0.55 ? const Color(0xFF2A2118) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class FamilyAvatarStack extends StatelessWidget {
  const FamilyAvatarStack({
    super.key,
    this.radius = 14,
  });

  final double radius;

  static const _members = <(String, String)>[
    ('AH', 'abdullah'),
    ('D', 'dad'),
    ('M', 'mom'),
    ('S', 'sara'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2 + (_members.length - 1) * (radius * 1.15),
      height: radius * 2,
      child: Stack(
        children: [
          for (var index = 0; index < _members.length; index++)
            PositionedDirectional(
              start: index * radius * 1.15,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: MemberAvatar(
                  initials: _members[index].$1,
                  memberId: _members[index].$2,
                  radius: radius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.tone = StatusBannerTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final StatusBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = FamilyCompassSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      StatusBannerTone.neutral => (
          scheme.surfaceContainer,
          scheme.onSurface,
        ),
      StatusBannerTone.warning => (
          colors.warningContainer,
          colors.onWarningContainer,
        ),
      StatusBannerTone.success => (
          colors.successContainer,
          colors.onSuccessContainer,
        ),
      StatusBannerTone.privacy => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
    };

    return SoftCard(
      color: background,
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                ),
                if (body != null) ...[
                  const SizedBox(height: FamilyCompassSpacing.xxs),
                  Text(
                    body!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.86),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

enum StatusBannerTone { neutral, warning, success, privacy }

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: FamilyCompassSpacing.xs),
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: FamilyCompassSpacing.xxs),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: FamilyCompassSpacing.md + FamilyCompassSpacing.xxs,
                    ),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class QuietLabel extends StatelessWidget {
  const QuietLabel({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolved),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolved,
                ),
          ),
        ),
      ],
    );
  }
}
