/*
THESIS: Today feels like looking across the family table, not reading a family
operations dashboard. It refuses the equal-weight timeline of system states.
OWN-WORLD: Warm milk canvas, pomegranate actions, apricot gatherings,
eucalyptus reassurance, flat family rows, and one split gathering sheet.
STORY: Resolve one request, understand the next family moment, see recent
family updates, then consider one quiet Compass observation.
FIRST VIEWPORT: One conditional action sits above a date-and-people gathering
sheet. Family updates and Compass follow without competing card chrome.
FORM: Sunday Table, split gathering sheet, seed 7f8d066b.
FINISH: unreviewed and undocumented is unfinished; this build ends with the
finish review, the verdict, and DESIGN.md
*/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/design_system.dart';
import '../../domain/chat_models.dart';
import '../../domain/family_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
import '../../widgets/prototype_widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenChat,
    required this.onOpenCompass,
    required this.onOpenTogether,
  });

  final PrototypeScenarioController controller;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCompass;
  final VoidCallback onOpenTogether;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final locale = Localizations.localeOf(context).languageCode;

    if (state.surfaceState == SurfaceState.loading) {
      return Semantics(
        liveRegion: true,
        label: locale == 'ar' ? 'جارٍ تحميل اليوم' : 'Loading Today',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return PrototypePage(
      maxWidth: 1120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.surfaceState == SurfaceState.offlineCached) ...[
            _OfflineNotice(controller: controller, locale: locale),
            const SizedBox(height: FamilyCompassSpacing.md),
          ],
          if (!state.aiAvailable) ...[
            InlineNotice(
              icon: FamilyCompassIcons.contactSupportOutlined,
              title: locale == 'ar'
                  ? 'البوصلة غير متاحة الآن'
                  : 'Compass is unavailable right now',
              body: locale == 'ar'
                  ? 'تظل الدردشة والخطط العائلية متاحة.'
                  : 'Family chat and plans still work normally.',
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
          ],
          if (state.surfaceState == SurfaceState.empty || state.plan == null)
            _EmptyToday(
              locale: locale,
              onStart: () {
                controller.reset(PrototypeScenario.dinnerOpportunity);
                controller.draftFridayDinner();
                onOpenTogether();
              },
            )
          else
            _TodayReady(
              state: state,
              controller: controller,
              locale: locale,
              onOpenChat: onOpenChat,
              onOpenCompass: onOpenCompass,
              onOpenTogether: onOpenTogether,
            ),
        ],
      ),
    );
  }
}

class _TodayReady extends StatelessWidget {
  const _TodayReady({
    required this.state,
    required this.controller,
    required this.locale,
    required this.onOpenChat,
    required this.onOpenCompass,
    required this.onOpenTogether,
  });

  final PrototypeScenarioState state;
  final PrototypeScenarioController controller;
  final String locale;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCompass;
  final VoidCallback onOpenTogether;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    final needsReply = plan.phase == PlanPhase.pollOpen &&
        !plan.responses.containsKey(controller.currentUserId);
    final members = controller.familyMembersForDisplay;
    final participantInitials = plan.participantIds.map((id) {
      return members.where((member) => member.id == id).firstOrNull?.initials ??
          id.characters.first.toUpperCase();
    }).toList(growable: false);
    final familyUpdates = _buildFamilyUpdates(context, members);

    final actionAndGathering = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsReply) ...[
          _NeedsYouStrip(
            plan: plan,
            currentUserId: controller.currentUserId,
            locale: locale,
            onRespond: onOpenTogether,
          ),
          const SizedBox(height: FamilyCompassSpacing.lg),
        ],
        _GatheringSection(
          plan: plan,
          participantInitials: participantInitials,
          locale: locale,
          onOpen: onOpenTogether,
        ),
      ],
    );

    final familyAndCompass = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (familyUpdates.isNotEmpty)
          _FamilyUpdatesSection(
            updates: familyUpdates,
            locale: locale,
            onOpenChat: onOpenChat,
            onOpenCompass: onOpenCompass,
          ),
        if (familyUpdates.isNotEmpty && state.hasActiveSuggestion)
          const SizedBox(height: FamilyCompassSpacing.xl),
        if (state.hasActiveSuggestion)
          _CompassNotice(
            key: const Key('today.suggestion.dinner'),
            plan: plan,
            locale: locale,
            onOpen: onOpenChat,
          ),
        if (plan.phase == PlanPhase.completed) ...[
          if (familyUpdates.isNotEmpty || state.hasActiveSuggestion)
            const SizedBox(height: FamilyCompassSpacing.xl),
          _PlanAgainRow(
            locale: locale,
            onPlanAgain: () {
              controller.planAgain();
              onOpenTogether();
            },
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 680;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              actionAndGathering,
              if (familyUpdates.isNotEmpty ||
                  state.hasActiveSuggestion ||
                  plan.phase == PlanPhase.completed) ...[
                const SizedBox(height: FamilyCompassSpacing.xl),
                familyAndCompass,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: actionAndGathering),
            const SizedBox(width: FamilyCompassSpacing.xl),
            Expanded(flex: 9, child: familyAndCompass),
          ],
        );
      },
    );
  }

  List<_FamilyUpdate> _buildFamilyUpdates(
    BuildContext context,
    List<FamilyMember> members,
  ) {
    final updates = <_FamilyUpdate>[];
    final dad = members
        .where((member) =>
            member.relationshipKind == FamilyRelationshipKind.father)
        .firstOrNull;
    final dadStatus = dad == null ? null : state.statuses[dad.id];
    if (dad != null &&
        dadStatus != null &&
        dadStatus.isUsableAt(state.scenarioNow)) {
      updates.add(
        _FamilyUpdate(
          memberId: dad.id,
          memberName: dad.localizedDisplayName(context),
          initials: dad.initials,
          text: dadStatus.text,
          time: dadStatus.updatedAt,
          opensCompass: true,
        ),
      );
    }

    final latestHumanMessages = state.chatItems.reversed.where((item) {
      return item.kind == ChatItemKind.message &&
          item.authorId != 'compass' &&
          !containsCompassMentionText(item.text);
    });
    for (final item in latestHumanMessages) {
      if (updates.length >= 2) break;
      if (updates.any((update) => update.memberId == item.authorId)) continue;
      final member = members
          .where((candidate) => candidate.id == item.authorId)
          .firstOrNull;
      if (member == null) continue;
      updates.add(
        _FamilyUpdate(
          memberId: member.id,
          memberName: member.localizedDisplayName(context),
          initials: member.initials,
          text: item.text,
          time: item.sentAt,
          opensCompass: false,
        ),
      );
    }
    return updates;
  }
}

class _NeedsYouStrip extends StatelessWidget {
  const _NeedsYouStrip({
    required this.plan,
    required this.currentUserId,
    required this.locale,
    required this.onRespond,
  });

  final FamilyPlan plan;
  final String currentUserId;
  final String locale;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    final candidate = plan.displayCandidate(memberId: currentUserId);
    final time = candidate == null
        ? (isArabic ? 'الوقت المقترح' : 'the suggested time')
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(candidate.startsAt),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final title =
        isArabic ? 'عشاء العائلة ينتظر ردك' : 'Dinner needs your reply';
    final body = isArabic
        ? 'هل يناسبك موعد العشاء عند $time؟'
        : 'Can you make the family dinner at $time?';
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.5;

    return Semantics(
      button: true,
      label: '$title. $body',
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('today.needsReply'),
          onTap: onRespond,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.sm,
                FamilyCompassSpacing.sm,
                FamilyCompassSpacing.sm,
              ),
              child: stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              FamilyCompassIcons.howToVoteOutlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: FamilyCompassSpacing.sm),
                            Expanded(
                              child: _NeedsYouCopy(title: title, body: body),
                            ),
                          ],
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _RespondLabel(isArabic: isArabic),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          FamilyCompassIcons.howToVoteOutlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: FamilyCompassSpacing.md),
                        Expanded(
                          child: _NeedsYouCopy(title: title, body: body),
                        ),
                        const SizedBox(width: FamilyCompassSpacing.sm),
                        _RespondLabel(isArabic: isArabic),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeedsYouCopy extends StatelessWidget {
  const _NeedsYouCopy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xxs),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      );
}

class _RespondLabel extends StatelessWidget {
  const _RespondLabel({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic ? 'الرد' : 'Respond',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            Icon(
              FamilyCompassIcons.chevronRightRounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
}

class _GatheringSection extends StatelessWidget {
  const _GatheringSection({
    required this.plan,
    required this.participantInitials,
    required this.locale,
    required this.onOpen,
  });

  final FamilyPlan plan;
  final List<String> participantInitials;
  final String locale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    final candidate = plan.displayCandidate();
    final date = candidate?.startsAt ??
        (plan.candidateTimes.isNotEmpty
            ? plan.candidateTimes.first.startsAt
            : plan.decisionDeadline);
    final title = plan.localizedDisplayTitle(context);
    final place = plan.locationLabel?.trim().isNotEmpty == true
        ? plan.locationLabel!
        : plan.id == 'friday-dinner'
            ? (isArabic ? 'في المنزل' : 'At home')
            : plan.description;
    final stateLabel = _planStateLabel(context, plan);
    final timeLabel = _timeLabel(context, plan);
    final actionLabel = switch (plan.phase) {
      PlanPhase.opportunity => isArabic ? 'مراجعة الفكرة' : 'Review idea',
      PlanPhase.draft => isArabic ? 'متابعة الخطة' : 'Continue plan',
      PlanPhase.pollOpen => isArabic ? 'عرض الاستطلاع' : 'View poll',
      PlanPhase.readyToConfirm => isArabic ? 'تأكيد الموعد' : 'Confirm time',
      PlanPhase.confirmed => isArabic ? 'عرض الخطة' : 'View plan',
      PlanPhase.completed => isArabic ? 'خطط لها مجددًا' : 'Plan again',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: isArabic ? 'اللقاء العائلي القادم' : 'Next family moment',
          compact: true,
        ),
        Semantics(
          button: true,
          label: '$title. $stateLabel. $timeLabel. $place. $actionLabel',
          child: ExcludeSemantics(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(FamilyCompassRadii.large),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('today.next'),
                onTap: onOpen,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final split =
                        constraints.maxWidth >= 340 && textScale <= 1.35;
                    if (!split) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GatheringDateBand(date: date, locale: locale),
                          _GatheringDetails(
                            title: title,
                            stateLabel: stateLabel,
                            timeLabel: timeLabel,
                            place: place,
                            participantInitials: participantInitials,
                            actionLabel: actionLabel,
                          ),
                        ],
                      );
                    }

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 440 ? 92 : 108,
                            child: _GatheringDatePanel(
                              date: date,
                              locale: locale,
                            ),
                          ),
                          Expanded(
                            child: _GatheringDetails(
                              title: title,
                              stateLabel: stateLabel,
                              timeLabel: timeLabel,
                              place: place,
                              participantInitials: participantInitials,
                              actionLabel: actionLabel,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _planStateLabel(BuildContext context, FamilyPlan plan) {
    final isArabic = locale == 'ar';
    final numbers = NumberFormat.decimalPattern(locale);
    return switch (plan.phase) {
      PlanPhase.opportunity => isArabic
          ? '${numbers.format(plan.candidateTimes.length)} مواعيد مقترحة'
          : plan.candidateTimes.length == 1
              ? '1 possible time'
              : '${numbers.format(plan.candidateTimes.length)} possible times',
      PlanPhase.draft => isArabic ? 'مسودة خاصة' : 'Private draft',
      PlanPhase.pollOpen => () {
          final remaining = plan.participantIds.length - plan.responses.length;
          if (isArabic) {
            return remaining == 1
                ? 'بانتظار رد واحد'
                : remaining == 2
                    ? 'بانتظار ردّين'
                    : 'بانتظار ${numbers.format(remaining)} ردود';
          }
          return remaining == 1
              ? 'Waiting for 1 reply'
              : 'Waiting for ${numbers.format(remaining)} replies';
        }(),
      PlanPhase.readyToConfirm =>
        isArabic ? 'جاهزة للتأكيد' : 'Ready to confirm',
      PlanPhase.confirmed => isArabic
          ? '${numbers.format(plan.attendingCount)} سيحضرون'
          : '${numbers.format(plan.attendingCount)} going',
      PlanPhase.completed =>
        isArabic ? 'لحظة يمكن تكرارها' : 'A moment to revisit',
    };
  }

  String _timeLabel(BuildContext context, FamilyPlan plan) {
    final isArabic = locale == 'ar';
    final material = MaterialLocalizations.of(context);
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    String format(CandidateTime candidate) => material.formatTimeOfDay(
          TimeOfDay.fromDateTime(candidate.startsAt),
          alwaysUse24HourFormat: use24Hour,
        );
    if (plan.phase == PlanPhase.opportunity && plan.candidateTimes.isNotEmpty) {
      return plan.candidateTimes.map((candidate) {
        return '${DateFormat.E(locale).format(candidate.startsAt)} ${format(candidate)}';
      }).join(isArabic ? '، ' : ' · ');
    }
    final candidate = plan.displayCandidate();
    return candidate == null
        ? (isArabic ? 'الوقت قيد التحديد' : 'Time to be decided')
        : '${DateFormat.E(locale).format(candidate.startsAt)} ${format(candidate)}';
  }
}

class _GatheringDatePanel extends StatelessWidget {
  const _GatheringDatePanel({required this.date, required this.locale});

  final DateTime date;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final isArabic = locale == 'ar';
    final month = DateFormat.MMM(locale).format(date);
    final day = DateFormat.d(locale).format(date);
    final weekday = DateFormat.E(locale).format(date);
    return ColoredBox(
      color: semantic.gathering,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.sm,
          vertical: FamilyCompassSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isArabic ? month : month.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: semantic.onGathering,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              day,
              textAlign: TextAlign.center,
              style:
                  FamilyCompassTypography.of(context).headlineLarge?.copyWith(
                        color: semantic.onGathering,
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                      ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              isArabic ? weekday : weekday.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: semantic.onGathering,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatheringDateBand extends StatelessWidget {
  const _GatheringDateBand({required this.date, required this.locale});

  final DateTime date;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    return ColoredBox(
      color: semantic.gathering,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              FamilyCompassIcons.calendarTodayOutlined,
              color: semantic.onGathering,
            ),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Text(
                DateFormat.yMMMMEEEEd(locale).format(date),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: semantic.onGathering,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatheringDetails extends StatelessWidget {
  const _GatheringDetails({
    required this.title,
    required this.stateLabel,
    required this.timeLabel,
    required this.place,
    required this.participantInitials,
    required this.actionLabel,
  });

  final String title;
  final String stateLabel;
  final String timeLabel;
  final String place;
  final List<String> participantInitials;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            stateLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            title,
            style: FamilyCompassTypography.of(context).titleLarge,
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          _GatheringMetadata(
            icon: FamilyCompassIcons.scheduleOutlined,
            label: timeLabel,
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          _GatheringMetadata(
            icon: FamilyCompassIcons.homeOutlined,
            label: place,
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          _GatheringFooter(
            participantInitials: participantInitials,
            actionLabel: actionLabel,
          ),
        ],
      ),
    );
  }
}

class _GatheringFooter extends StatelessWidget {
  const _GatheringFooter({
    required this.participantInitials,
    required this.actionLabel,
  });

  final List<String> participantInitials;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final identities = FamilyIdentityStack(
      initials: participantInitials,
      maximumVisible: 3,
      markSize: 32,
      semanticLabel: context.l10n.familyMembersCount(
        participantInitials.length,
      ),
    );
    final action = KeyedSubtree(
      key: const Key('today.plan.view'),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: FamilyCompassSpacing.xs,
        children: [
          Text(
            actionLabel,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
          ),
          Icon(
            FamilyCompassIcons.chevronRightRounded,
            size: 15,
            color: scheme.primary,
          ),
        ],
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.35) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          identities,
          const SizedBox(height: FamilyCompassSpacing.sm),
          Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ],
      );
    }
    return Row(
      children: [
        identities,
        const SizedBox(width: FamilyCompassSpacing.sm),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: action,
          ),
        ),
      ],
    );
  }
}

class _GatheringMetadata extends StatelessWidget {
  const _GatheringMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: FamilyCompassSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
}

class _FamilyUpdate {
  const _FamilyUpdate({
    required this.memberId,
    required this.memberName,
    required this.initials,
    required this.text,
    required this.time,
    required this.opensCompass,
  });

  final String memberId;
  final String memberName;
  final String initials;
  final String text;
  final DateTime time;
  final bool opensCompass;
}

class _FamilyUpdatesSection extends StatelessWidget {
  const _FamilyUpdatesSection({
    required this.updates,
    required this.locale,
    required this.onOpenChat,
    required this.onOpenCompass,
  });

  final List<_FamilyUpdate> updates;
  final String locale;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenCompass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: locale == 'ar' ? 'من عائلتك' : 'From your family',
          compact: true,
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < updates.length; index++) ...[
                _FamilyUpdateRow(
                  key: index == 0
                      ? const Key('today.relevantUpdate')
                      : ValueKey('today.familyUpdate.$index'),
                  update: updates[index],
                  locale: locale,
                  onTap:
                      updates[index].opensCompass ? onOpenCompass : onOpenChat,
                ),
                if (index != updates.length - 1)
                  Divider(
                    height: 1,
                    indent: 68,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyUpdateRow extends StatelessWidget {
  const _FamilyUpdateRow({
    super.key,
    required this.update,
    required this.locale,
    required this.onTap,
  });

  final _FamilyUpdate update;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(update.time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final stackHeader = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.md,
            vertical: FamilyCompassSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MemberMark(
                initial: update.initials,
                size: 40,
                semanticLabel: update.memberName,
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stackHeader) ...[
                      Text(
                        update.memberName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              update.memberName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            time,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    const SizedBox(height: FamilyCompassSpacing.xxs),
                    Text(
                      update.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FamilyCompassSpacing.xs),
              Icon(
                FamilyCompassIcons.chevronRightRounded,
                size: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassNotice extends StatelessWidget {
  const _CompassNotice({
    super.key,
    required this.plan,
    required this.locale,
    required this.onOpen,
  });

  final FamilyPlan plan;
  final String locale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    final semantic = FamilyCompassSemanticColors.of(context);
    final candidate = plan.displayCandidate();
    final day = candidate == null
        ? (isArabic ? 'الموعد المقترح' : 'The proposed date')
        : DateFormat.EEEE(locale).format(candidate.startsAt);
    final count = NumberFormat.decimalPattern(locale).format(
      plan.participantIds.length,
    );
    final body = isArabic
        ? 'يبدو $day مناسبًا لـ$count من أفراد العائلة.'
        : '$day looks open for $count family members.';

    return Semantics(
      button: true,
      label: '${isArabic ? 'لاحظت البوصلة' : 'Compass noticed'}. $body',
      child: ExcludeSemantics(
        child: Material(
          color: semantic.successContainer,
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(FamilyCompassSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FamilyCompassIcons.compassOutline,
                    color: semantic.onSuccessContainer,
                  ),
                  const SizedBox(width: FamilyCompassSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'لاحظت البوصلة' : 'Compass noticed',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: semantic.onSuccessContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: FamilyCompassSpacing.xxs),
                        Text(
                          body,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: semantic.onSuccessContainer,
                                  ),
                        ),
                        const SizedBox(height: FamilyCompassSpacing.xs),
                        Text(
                          isArabic ? 'خطط في الدردشة' : 'Plan in Chat',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: semantic.onSuccessContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    FamilyCompassIcons.chevronRightRounded,
                    size: 16,
                    color: semantic.onSuccessContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanAgainRow extends StatelessWidget {
  const _PlanAgainRow({required this.locale, required this.onPlanAgain});

  final String locale;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    return FlatActionRow(
      title: isArabic ? 'اجتمعتم معًا' : 'A family moment, shared',
      body: isArabic
          ? 'يمكنك استخدام هذه الخطة مرة أخرى.'
          : 'You can use this plan again.',
      leading: Icon(
        FamilyCompassIcons.replayRounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      trailing: Text(
        isArabic ? 'كررها' : 'Plan again',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
      onTap: onPlanAgain,
      topDivider: false,
      bottomDivider: false,
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.controller, required this.locale});

  final PrototypeScenarioController controller;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    return InlineNotice(
      icon: FamilyCompassIcons.cloudOffOutlined,
      title: isArabic
          ? controller.state.retryFailed
              ? 'تعذر الاتصال'
              : 'عرض معلومات العائلة المحفوظة'
          : controller.state.retryFailed
              ? 'Couldn\'t reconnect'
              : 'Showing saved family information',
      body: controller.state.retryFailed
          ? isArabic
              ? 'ما زالت معلومات العائلة المحفوظة متاحة. حاول مرة أخرى.'
              : 'Saved family information is still available. Try again.'
          : isArabic
              ? 'آخر تحديث قبل ١٢ دقيقة'
              : 'Last updated 12 minutes ago',
      action: TextButton(
        key: const Key('offline.retry'),
        onPressed: controller.state.isRetrying ? null : controller.retryOffline,
        child: controller.state.isRetrying
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.locale, required this.onStart});

  final String locale;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isArabic = locale == 'ar';
    return EmptyStateCard(
      icon: FamilyCompassIcons.eventAvailableOutlined,
      title: context.l10n.todayNoUrgentUpdates,
      body: isArabic
          ? 'لا شيء يحتاج إلى انتباهك الآن. ابدأ خطة بسيطة عندما تكون العائلة مستعدة.'
          : 'Nothing needs your attention right now. Start a simple plan when the family is ready.',
      action: FilledButton.icon(
        key: const Key('today.startPlan'),
        onPressed: onStart,
        icon: const Icon(FamilyCompassIcons.addRounded),
        label: Text(isArabic ? 'ابدأ خطة عائلية' : 'Start a family plan'),
      ),
    );
  }
}
