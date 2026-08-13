import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

/// Compatibility name retained from Prototype 2. New screens use this as an
/// adaptive page canvas, not as a web-style centered column.
class PrototypePage extends StatelessWidget {
  const PrototypePage({
    super.key,
    required this.child,
    this.padding,
    this.scrollController,
    this.maxWidth = FamilyCompassSizes.maximumContentWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final short = constraints.maxHeight < 480;
          final horizontal = compact
              ? FamilyCompassSizes.compactContentPadding
              : constraints.maxWidth < 840
                  ? FamilyCompassSizes.mediumContentPadding
                  : FamilyCompassSizes.expandedContentPadding;
          return Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: padding ??
                    EdgeInsetsDirectional.fromSTEB(
                      horizontal,
                      short ? FamilyCompassSpacing.sm : FamilyCompassSpacing.lg,
                      horizontal,
                      FamilyCompassSpacing.xxl,
                    ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.action,
    this.compact = false,
  });

  final String title;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 0 : FamilyCompassSpacing.xs,
        bottom: FamilyCompassSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class FolioSurface extends StatelessWidget {
  const FolioSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(FamilyCompassSpacing.lg),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    final paddedChild = Padding(padding: padding, child: child);
    final interactive = Material(
      color: backgroundColor ?? colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? paddedChild
          : InkWell(onTap: onTap, child: paddedChild),
    );
    if (semanticLabel == null) return interactive;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: ExcludeSemantics(child: interactive),
    );
  }
}

class FlatActionRow extends StatelessWidget {
  const FlatActionRow({
    super.key,
    required this.title,
    this.body,
    this.leading,
    this.trailing,
    this.onTap,
    this.topDivider = true,
    this.bottomDivider = false,
    this.padding = const EdgeInsets.symmetric(
      vertical: FamilyCompassSpacing.md,
    ),
  });

  final String title;
  final String? body;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool topDivider;
  final bool bottomDivider;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: FamilyCompassSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (body != null) ...[
                  const SizedBox(height: FamilyCompassSpacing.xxs),
                  Text(
                    body!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FamilyCompassSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: topDivider
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
          bottom: bottomDivider
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: FamilyCompassSizes.minimumTouchTarget,
                ),
                child: row,
              ),
            ),
    );
  }
}

class MemberMark extends StatelessWidget {
  const MemberMark({
    super.key,
    required this.initial,
    this.color,
    this.size = 40,
    this.semanticLabel,
  });

  final String initial;
  final Color? color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final background = color ?? _memberColor(scheme, semantic);
    final usesInitials = initial.characters.length > 1;
    final textStyle = size <= 36 || usesInitials
        ? Theme.of(context).textTheme.labelMedium
        : Theme.of(context).textTheme.titleMedium;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.surface.withValues(alpha: 0.9),
              width: size >= 40 ? 1.5 : 1,
            ),
          ),
          child: Text(
            initial,
            style: textStyle?.copyWith(
              fontWeight: FontWeight.w600,
              color: ThemeData.estimateBrightnessForColor(background) ==
                      Brightness.dark
                  ? Colors.white
                  : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Color _memberColor(
    ColorScheme scheme,
    FamilyCompassSemanticColors semantic,
  ) {
    final colors = <Color>[
      scheme.primaryContainer,
      semantic.successContainer,
      semantic.gatheringContainer,
      scheme.surfaceContainerHigh,
    ];
    final identity = initial.runes.fold<int>(0, (sum, rune) => sum + rune);
    return colors[identity % colors.length];
  }
}

/// A compact, non-photographic family identity stack.
///
/// Real member photos can replace individual marks later. Initials remain a
/// truthful, accessible fallback and avoid synthetic family imagery.
class FamilyIdentityStack extends StatelessWidget {
  const FamilyIdentityStack({
    super.key,
    required this.initials,
    this.semanticLabel,
    this.markSize = 34,
    this.maximumVisible = 4,
  });

  final List<String> initials;
  final String? semanticLabel;
  final double markSize;
  final int maximumVisible;

  @override
  Widget build(BuildContext context) {
    final visible = initials.take(maximumVisible).toList(growable: false);
    final remaining = initials.length - visible.length;
    final overlap = markSize * 0.28;
    final count = visible.length + (remaining > 0 ? 1 : 0);
    final width =
        count == 0 ? 0.0 : markSize + (count - 1) * (markSize - overlap);
    final colors = <Color>[
      Theme.of(context).colorScheme.primaryContainer,
      FamilyCompassSemanticColors.of(context).successContainer,
      FamilyCompassSemanticColors.of(context).gatheringContainer,
      Theme.of(context).colorScheme.surfaceContainer,
    ];

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: markSize,
          child: Stack(
            textDirection: Directionality.of(context),
            children: [
              for (var index = 0; index < visible.length; index++)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  start: index * (markSize - overlap),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: MemberMark(
                      initial: visible[index],
                      color: colors[index % colors.length],
                      size: markSize - 2,
                    ),
                  ),
                ),
              if (remaining > 0)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  start: visible.length * (markSize - overlap),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: MemberMark(
                      initial: '+$remaining',
                      color: Theme.of(context).colorScheme.primaryContainer,
                      size: markSize - 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SourceLine extends StatelessWidget {
  const SourceLine({
    super.key,
    required this.source,
    this.freshness,
    this.icon = FamilyCompassIcons.personOutlineRounded,
  });

  final String source;
  final String? freshness;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: FamilyCompassSpacing.xs,
      runSpacing: FamilyCompassSpacing.xxs,
      children: [
        Icon(icon, size: 16, color: color),
        Text(
          freshness == null ? source : '$source · $freshness',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FamilyCompassSpacing.sm),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackAction = action != null &&
                (constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35);
            final message = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: FamilyCompassSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: FamilyCompassSpacing.xxs),
                      Text(body),
                    ],
                  ),
                ),
              ],
            );
            if (stackAction) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  const SizedBox(height: FamilyCompassSpacing.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action!,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: message),
                if (action != null) ...[
                  const SizedBox(width: FamilyCompassSpacing.xs),
                  action!,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return FolioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: FamilyCompassSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(body),
          const SizedBox(height: FamilyCompassSpacing.lg),
          action,
        ],
      ),
    );
  }
}
