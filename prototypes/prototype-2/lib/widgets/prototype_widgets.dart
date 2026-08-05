import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

class PrototypePage extends StatelessWidget {
  const PrototypePage({
    super.key,
    required this.child,
    this.padding,
    this.scrollController,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600
            ? FamilyCompassSizes.compactContentPadding
            : FamilyCompassSizes.mediumContentPadding;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FamilyCompassSizes.maximumContentWidth,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: padding ??
                  EdgeInsets.fromLTRB(
                    horizontal,
                    FamilyCompassSpacing.lg,
                    horizontal,
                    FamilyCompassSpacing.xxl,
                  ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class SourceLine extends StatelessWidget {
  const SourceLine({
    super.key,
    required this.source,
    this.freshness,
    this.icon = Icons.person_outline_rounded,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: FamilyCompassSpacing.lg),
            action,
          ],
        ),
      ),
    );
  }
}
