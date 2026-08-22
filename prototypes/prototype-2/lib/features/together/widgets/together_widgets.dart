import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/plan_models.dart';
import '../../../l10n/l10n.dart';
import '../../../prototype/fixtures.dart';

class TogetherSectionHeading extends StatelessWidget {
  const TogetherSectionHeading({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SectionEyebrow(title: title, subtitle: subtitle);
  }
}

class TogetherPlanCard extends StatelessWidget {
  const TogetherPlanCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final background =
        emphasized ? semantic.gatheringContainer : colors.surface;
    final foreground =
        emphasized ? semantic.onGatheringContainer : colors.onSurface;

    return SoftCard(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(
                icon: icon,
                background: emphasized
                    ? semantic.gathering
                    : colors.primaryContainer,
                foreground:
                    emphasized ? semantic.onGathering : colors.onPrimaryContainer,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          textTheme.titleMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xxs),
                    Text(
                      detail,
                      style: textTheme.bodyMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          FilledButton(
            onPressed: onPressed,
            style: emphasized
                ? FilledButton.styleFrom(
                    backgroundColor: semantic.gathering,
                    foregroundColor: semantic.onGathering,
                  )
                : null,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class TogetherEmptyCard extends StatelessWidget {
  const TogetherEmptyCard({
    required this.message,
    this.actionLabel,
    this.onPressed,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class TogetherDetailHeader extends StatelessWidget {
  const TogetherDetailHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const ValueKey('together-detail-back'),
          onPressed: onBack,
          tooltip: 'Back to Together',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: FamilyCompassSpacing.xxs),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String candidateTimeLabel(BuildContext context, CandidateTime candidate) {
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(candidate.startsAt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final locale = Localizations.localeOf(context).toLanguageTag();
  final day = DateFormat.EEEE(locale).format(candidate.startsAt);
  return context.l10n.todayDinnerDetails(day, time);
}

String confirmedPlanLabel(BuildContext context, FamilyPlan plan) {
  final candidate = plan.confirmedTime;
  return candidate == null
      ? 'Time not confirmed'
      : candidateTimeLabel(context, candidate);
}

String responseChoiceLabel(BuildContext context, RsvpChoice choice) =>
    switch (choice) {
      RsvpChoice.going => context.l10n.pollGoing,
      RsvpChoice.maybe => context.l10n.pollMaybe,
      RsvpChoice.cannotMakeIt => context.l10n.pollCannotGo,
    };

String memberName(String id) {
  try {
    return memberById(id).name;
  } on StateError {
    return id;
  }
}
