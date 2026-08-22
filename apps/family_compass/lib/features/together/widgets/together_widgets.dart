import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/family_models.dart';
import '../../../domain/plan_models.dart';
import '../../../l10n/l10n.dart';
import '../../../prototype/fixtures.dart';
import '../../../widgets/prototype_widgets.dart';

bool togetherUsesArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String togetherCopy(BuildContext context, String english, String arabic) =>
    togetherUsesArabic(context) ? arabic : english;

/// Adaptive canvas shared by the Together overview and its detail routes.
///
/// The child receives the real content width plus the height class so compact
/// landscape can recompose instead of showing a compressed portrait stack.
class TogetherPageCanvas extends StatelessWidget {
  const TogetherPageCanvas({
    required this.scrollKey,
    required this.builder,
    this.maxWidth = FamilyCompassSizes.maximumContentWidth,
    super.key,
  });

  final PageStorageKey<String> scrollKey;
  final double maxWidth;
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    bool compactHeight,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    return ColoredBox(
      color: semantic.pageBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compactHeight =
                viewport.maxHeight < FamilyCompassBreakpoints.compactHeight;
            final horizontal =
                viewport.maxWidth < FamilyCompassBreakpoints.compactWidth
                    ? FamilyCompassSizes.compactContentPadding
                    : viewport.maxWidth < FamilyCompassBreakpoints.mediumWidth
                        ? FamilyCompassSizes.mediumContentPadding
                        : FamilyCompassSizes.expandedContentPadding;
            return CustomScrollView(
              key: scrollKey,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    horizontal,
                    compactHeight
                        ? FamilyCompassSpacing.sm
                        : FamilyCompassSpacing.lg,
                    horizontal,
                    FamilyCompassSpacing.xxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: LayoutBuilder(
                          builder: (context, contentConstraints) => builder(
                            context,
                            contentConstraints,
                            compactHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: FamilyCompassSpacing.xxs),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A real proposal, poll, or confirmed plan. Routine metadata never uses this
/// bounded treatment.
class TogetherPlanFolio extends StatelessWidget {
  const TogetherPlanFolio({
    required this.plan,
    required this.phaseLabel,
    required this.detail,
    this.actionLabel,
    this.onPressed,
    this.supportingLabel,
    this.emphasized = false,
    super.key,
  });

  final FamilyPlan plan;
  final String phaseLabel;
  final String detail;
  final String? supportingLabel;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final date = plan.confirmedTime?.startsAt ??
        (plan.candidateTimes.isEmpty
            ? plan.decisionDeadline
            : plan.displayCandidate()?.startsAt ?? plan.decisionDeadline);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.yMMMMEEEEd(locale).format(date);
    final candidateLabel = plan.displayCandidate() == null
        ? togetherCopy(context, 'Time not selected', 'لم يتم اختيار الوقت')
        : candidateTimeLabel(context, plan.displayCandidate()!);
    final title = togetherPlanTitle(context, plan);

    return Semantics(
      container: true,
      button: onPressed != null,
      label: '$title. $candidateLabel. $phaseLabel. $detail.'
          '${supportingLabel == null ? '' : ' $supportingLabel.'}'
          '${actionLabel == null ? '' : ' $actionLabel.'}',
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
            side: BorderSide(
              color: emphasized
                  ? semantic.gatheringInk.withValues(alpha: 0.42)
                  : scheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final body = _PlanFolioBody(
                  title: title,
                  phaseLabel: phaseLabel,
                  detail: detail,
                  supportingLabel: supportingLabel,
                  actionLabel: actionLabel,
                  participantInitials: plan.participantIds
                      .map((id) => memberName(id).characters.first)
                      .toList(growable: false),
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FolioDateTab(label: dateLabel),
                      body,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 92,
                        child: _FolioDateBlock(date: date, locale: locale),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FolioDateBlock extends StatelessWidget {
  const _FolioDateBlock({required this.date, required this.locale});

  final DateTime date;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final month = DateFormat.MMM(locale).format(date);
    final weekday = DateFormat.E(locale).format(date);
    return ColoredBox(
      color: semantic.gatheringContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.xs,
          vertical: FamilyCompassSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isArabic ? month : month.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: semantic.onGatheringContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xxs),
            Text(
              DateFormat.d(locale).format(date),
              textAlign: TextAlign.center,
              style:
                  FamilyCompassTypography.of(context).headlineLarge?.copyWith(
                        color: semantic.onGatheringContainer,
                        fontWeight: FontWeight.w600,
                      ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xxs),
            Text(
              isArabic ? weekday : weekday.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: semantic.onGatheringContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolioDateTab extends StatelessWidget {
  const _FolioDateTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    return ColoredBox(
      color: semantic.gatheringContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              FamilyCompassIcons.calendarTodayOutlined,
              size: 16,
              color: semantic.onGatheringContainer,
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: semantic.onGatheringContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFolioBody extends StatelessWidget {
  const _PlanFolioBody({
    required this.title,
    required this.phaseLabel,
    required this.detail,
    required this.supportingLabel,
    required this.actionLabel,
    required this.participantInitials,
  });

  final String title;
  final String phaseLabel;
  final String detail;
  final String? supportingLabel;
  final String? actionLabel;
  final List<String> participantInitials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phaseLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(title, style: FamilyCompassTypography.of(context).titleLarge),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(detail),
          if (supportingLabel != null) ...[
            const SizedBox(height: FamilyCompassSpacing.xxs),
            Text(
              supportingLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (participantInitials.isNotEmpty) ...[
            const SizedBox(height: FamilyCompassSpacing.md),
            FamilyIdentityStack(
              initials: participantInitials,
              maximumVisible: 4,
              markSize: 30,
              semanticLabel: context.l10n.familyMembersCount(
                participantInitials.length,
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: FamilyCompassSpacing.sm),
            Divider(color: scheme.outlineVariant),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: FamilyCompassSizes.minimumTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      actionLabel!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(width: FamilyCompassSpacing.xs),
                  Icon(
                    FamilyCompassIcons.chevronRightRounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty and routine states stay in the page flow instead of becoming cards.
class TogetherEmptyRow extends StatelessWidget {
  const TogetherEmptyRow({
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
    return FlatActionRow(
      title: message,
      body: actionLabel,
      onTap: onPressed,
      trailing: onPressed == null
          ? null
          : Icon(
              FamilyCompassIcons.chevronRightRounded,
              size: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      topDivider: true,
      bottomDivider: true,
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
        BackButton(
          key: const ValueKey('together-detail-back'),
          onPressed: onBack,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(
              FamilyCompassSizes.minimumTouchTarget,
            ),
          ),
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

/// A stage on the idea-to-gathering thread. The narrow gutter is directional,
/// so RTL moves the thread to the right without repainting the content.
class TogetherThreadItem extends StatelessWidget {
  const TogetherThreadItem({
    required this.child,
    required this.isFirst,
    required this.isLast,
    required this.isComplete,
    required this.isCurrent,
    this.padding = const EdgeInsets.only(bottom: FamilyCompassSpacing.lg),
    super.key,
  });

  final Widget child;
  final bool isFirst;
  final bool isLast;
  final bool isComplete;
  final bool isCurrent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? FamilyCompassSemanticColors.of(context).gatheringInk
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      label: isComplete
          ? togetherCopy(context, 'Completed stage', 'مرحلة مكتملة')
          : isCurrent
              ? togetherCopy(context, 'Current stage', 'المرحلة الحالية')
              : togetherCopy(context, 'Later stage', 'مرحلة لاحقة'),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 30,
            child: CustomPaint(
              key: const ValueKey('together-thread-segment'),
              painter: _TogetherThreadPainter(
                color: color,
                surface: Theme.of(context).colorScheme.surface,
                isFirst: isFirst,
                isLast: isLast,
                isComplete: isComplete,
                isCurrent: isCurrent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 30 + FamilyCompassSpacing.sm,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class _TogetherThreadPainter extends CustomPainter {
  const _TogetherThreadPainter({
    required this.color,
    required this.surface,
    required this.isFirst,
    required this.isLast,
    required this.isComplete,
    required this.isCurrent,
  });

  final Color color;
  final Color surface;
  final bool isFirst;
  final bool isLast;
  final bool isComplete;
  final bool isCurrent;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const markerY = 24.0;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (!isFirst) {
      canvas.drawLine(const Offset(15, 0), const Offset(15, markerY - 8), line);
    }
    if (!isLast) {
      if (isComplete) {
        canvas.drawLine(Offset(x, markerY + 8), Offset(x, size.height), line);
      } else {
        var y = markerY + 10;
        while (y < size.height) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, (y + 4).clamp(0, size.height)),
            line,
          );
          y += 9;
        }
      }
    }
    canvas.drawCircle(Offset(x, markerY), 8, Paint()..color = surface);
    canvas.drawCircle(
      Offset(x, markerY),
      7,
      Paint()
        ..color = isComplete || isCurrent ? color : surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(x, markerY),
      7,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TogetherThreadPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.surface != surface ||
      oldDelegate.isFirst != isFirst ||
      oldDelegate.isLast != isLast ||
      oldDelegate.isComplete != isComplete ||
      oldDelegate.isCurrent != isCurrent;
}

class TogetherMetadataRow extends StatelessWidget {
  const TogetherMetadataRow({
    required this.icon,
    required this.label,
    this.detail,
    this.trailing,
    this.topDivider = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Widget? trailing;
  final bool topDivider;

  @override
  Widget build(BuildContext context) => FlatActionRow(
        title: label,
        body: detail,
        leading: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        trailing: trailing,
        topDivider: topDivider,
      );
}

class TogetherChoiceChip extends StatelessWidget {
  const TogetherChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: onSelected,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
}

class TogetherStatusLine extends StatelessWidget {
  const TogetherStatusLine({
    required this.icon,
    required this.text,
    required this.foreground,
    this.background,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: background ?? Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.sm,
            vertical: FamilyCompassSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
}

String candidateTimeLabel(BuildContext context, CandidateTime candidate) {
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(candidate.startsAt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.MMMEd(locale).format(candidate.startsAt);
  return context.l10n.todayDinnerDetails(date, time);
}

String candidateTimeOnlyLabel(
  BuildContext context,
  CandidateTime candidate,
) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(candidate.startsAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String planDayLabel(BuildContext context, FamilyPlan plan) {
  final date = plan.displayCandidate()?.startsAt ?? plan.decisionDeadline;
  return DateFormat.EEEE(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);
}

String planDeadlineLabel(BuildContext context, FamilyPlan plan) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.MMMEd(locale).format(plan.decisionDeadline);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(plan.decisionDeadline),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return context.l10n.todayDinnerDetails(date, time);
}

String confirmedPlanLabel(BuildContext context, FamilyPlan plan) {
  final candidate = plan.confirmedTime;
  return candidate == null
      ? togetherCopy(context, 'Time not confirmed', 'لم يتم تأكيد الوقت')
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

String togetherPlanTitle(BuildContext context, FamilyPlan plan) =>
    plan.localizedDisplayTitle(context);

String togetherPlanDescription(BuildContext context, FamilyPlan plan) =>
    plan.id == 'friday-dinner'
        ? togetherCopy(
            context,
            'Dinner together at home',
            'عشاء عائلي معًا في المنزل',
          )
        : plan.description;

String togetherMemberName(BuildContext context, String id) {
  try {
    final member = switch (id) {
      '22222222-2222-2222-2222-222222222222' => const FamilyMember(
          id: '22222222-2222-2222-2222-222222222222',
          name: 'Dad',
          initials: 'D',
        ),
      '33333333-3333-3333-3333-333333333333' => const FamilyMember(
          id: '33333333-3333-3333-3333-333333333333',
          name: 'Mom',
          initials: 'M',
        ),
      _ => memberById(id),
    };
    return togetherMemberDisplayName(context, member);
  } on StateError {
    return id;
  }
}

String togetherMemberDisplayName(
  BuildContext context,
  FamilyMember member,
) =>
    member.localizedDisplayName(context);

String togetherMemberRelationship(BuildContext context, String id) {
  final member = memberById(id);
  return member.localizedRelationship(context);
}
