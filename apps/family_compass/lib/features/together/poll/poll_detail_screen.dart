import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/family_models.dart';
import '../../../domain/plan_models.dart';
import '../../../l10n/l10n.dart';
import '../../../prototype/prototype_scenario_controller.dart';
import '../../../widgets/prototype_widgets.dart';
import '../widgets/together_widgets.dart';

class PollDetailScreen extends StatefulWidget {
  const PollDetailScreen({
    required this.controller,
    required this.plan,
    required this.onBack,
    required this.onConfirmed,
    super.key,
  });

  final PrototypeScenarioController controller;
  final FamilyPlan plan;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  late String _candidateId;
  late RsvpChoice _choice;

  @override
  void initState() {
    super.initState();
    final existing = widget.plan.responses[widget.controller.currentUserId];
    _candidateId = existing?.candidateId ??
        widget.plan.candidateTimes.firstOrNull?.id ??
        '';
    _choice = existing?.choice ?? RsvpChoice.going;
  }

  @override
  void didUpdateWidget(covariant PollDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userId = widget.controller.currentUserId;
    final existing = widget.plan.responses[userId];
    if (existing != null && oldWidget.plan.responses[userId] == null) {
      _candidateId = existing.candidateId;
      _choice = existing.choice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final response = plan.responses[widget.controller.currentUserId];
    final allResponded = plan.participantIds.every(plan.responses.containsKey);
    final selectedCandidate = plan.candidateById(_candidateId) ??
        plan.displayCandidate(memberId: widget.controller.currentUserId);

    return TogetherPageCanvas(
      scrollKey: const PageStorageKey<String>('poll-detail-scroll'),
      builder: (context, constraints, compactHeight) {
        final split = constraints.maxWidth >= 760 ||
            (compactHeight && constraints.maxWidth >= 680);
        final compactPhone = MediaQuery.sizeOf(context).width <
            FamilyCompassBreakpoints.compactWidth;
        final poll = _PollFolio(
          plan: plan,
          response: response,
          candidateId: _candidateId,
          choice: _choice,
          onCandidateChanged: (value) => setState(() => _candidateId = value),
          onChoiceChanged: (value) => setState(() => _choice = value),
          onSuggestAnother: () => _suggestAnotherTime(context),
          onSubmit: () => widget.controller.submitAbdullahResponse(
            candidateId: _candidateId,
            choice: _choice,
          ),
          candidateLabel: (id) => _candidateLabel(context, id),
        );
        final replies = _FamilyReplies(
          plan: plan,
          response: response,
          allResponded: allResponded,
          selectedCandidate: selectedCandidate,
          onNudge: widget.controller.sendPollNudge,
          nudgeInFlight: widget.controller.isPollNudgeInFlight,
          onConfirm: () {
            widget.controller.confirmDinner(candidateId: selectedCandidate?.id);
            if (widget.controller.state.plan?.phase == PlanPhase.confirmed) {
              widget.onConfirmed();
            }
          },
          memberForId: widget.controller.memberForId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TogetherDetailHeader(
              title: togetherPlanTitle(context, plan),
              subtitle: togetherCopy(
                context,
                'Choose together, then confirm one time.',
                'اختاروا معًا، ثم أكدوا وقتًا واحدًا.',
              ),
              onBack: widget.onBack,
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            if (split)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: poll),
                  const SizedBox(width: FamilyCompassSpacing.xl),
                  Expanded(flex: 5, child: replies),
                ],
              )
            else if (compactPhone) ...[
              poll,
              const SizedBox(height: FamilyCompassSpacing.xl),
              replies,
            ] else ...[
              TogetherThreadItem(
                isFirst: true,
                isLast: false,
                isComplete: response != null,
                isCurrent: response == null,
                child: poll,
              ),
              TogetherThreadItem(
                isFirst: false,
                isLast: true,
                isComplete: allResponded,
                isCurrent: response != null,
                padding: EdgeInsets.zero,
                child: replies,
              ),
            ],
          ],
        );
      },
    );
  }

  String _candidateLabel(BuildContext context, String id) {
    for (final candidate in widget.plan.candidateTimes) {
      if (candidate.id == id) return candidateTimeLabel(context, candidate);
    }
    return togetherCopy(context, 'the selected time', 'الوقت المختار');
  }

  Future<void> _suggestAnotherTime(BuildContext context) async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SuggestTimeSheet(
        planDate: widget.plan.candidateTimes.firstOrNull?.startsAt ??
            widget.plan.decisionDeadline,
      ),
    );
    if (selected == null || !mounted) return;
    widget.controller.suggestCandidateTime(selected);
    final candidate = widget.controller.state.plan?.candidateTimes.lastOrNull;
    if (candidate != null && candidate.startsAt == selected) {
      setState(() => _candidateId = candidate.id);
    }
  }
}

class _SuggestTimeSheet extends StatefulWidget {
  const _SuggestTimeSheet({required this.planDate});

  final DateTime planDate;

  @override
  State<_SuggestTimeSheet> createState() => _SuggestTimeSheetState();
}

class _SuggestTimeSheetState extends State<_SuggestTimeSheet> {
  late final TextEditingController _timeController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: '20:00');
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_timeController.text.trim());
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      setState(() {
        _errorText = togetherCopy(
          context,
          'Use a valid time such as 20:00.',
          'استخدم وقتًا صحيحًا مثل 20:00.',
        );
      });
      return;
    }
    final date = widget.planDate;
    Navigator.pop(
      context,
      DateTime(date.year, date.month, date.day, hour, minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + FamilyCompassSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              togetherCopy(
                context,
                'Suggest another time',
                'اقتراح وقت آخر',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              togetherCopy(
                context,
                'Add a time for ${DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag()).format(widget.planDate)} using 24-hour time.',
                'أضف وقتًا ليوم ${DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag()).format(widget.planDate)} بصيغة ٢٤ ساعة.',
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            TextField(
              key: const ValueKey('suggested-time-input'),
              controller: _timeController,
              keyboardType: TextInputType.datetime,
              autofocus: true,
              decoration: InputDecoration(
                labelText: togetherCopy(context, 'Time', 'الوقت'),
                hintText: '20:00',
                errorText: _errorText,
                prefixIcon: const Icon(FamilyCompassIcons.scheduleOutlined),
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            FilledButton(
              key: const ValueKey('save-suggested-time'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  0,
                  FamilyCompassSizes.minimumTouchTarget,
                ),
              ),
              child: Text(togetherCopy(context, 'Add time', 'إضافة الوقت')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollFolio extends StatelessWidget {
  const _PollFolio({
    required this.plan,
    required this.response,
    required this.candidateId,
    required this.choice,
    required this.onCandidateChanged,
    required this.onChoiceChanged,
    required this.onSuggestAnother,
    required this.onSubmit,
    required this.candidateLabel,
  });

  final FamilyPlan plan;
  final PollResponse? response;
  final String candidateId;
  final RsvpChoice choice;
  final ValueChanged<String> onCandidateChanged;
  final ValueChanged<RsvpChoice> onChoiceChanged;
  final VoidCallback onSuggestAnother;
  final VoidCallback onSubmit;
  final String Function(String id) candidateLabel;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return FolioSurface(
      key: const ValueKey('poll-detail-folio'),
      borderColor: colors.outlineVariant.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            togetherCopy(context, 'Family poll', 'استطلاع العائلة'),
            style: textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(context.l10n.pollDinnerQuestion, style: textTheme.titleLarge),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            togetherCopy(
              context,
              'Choose the time you prefer, then tell the family if you can attend.',
              'اختر الوقت الذي تفضله، ثم أخبر العائلة إن كنت ستتمكن من الحضور.',
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FamilyCompassSpacing.lg),
          Text(
            togetherCopy(context, 'Preferred time', 'الوقت المفضل'),
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Wrap(
            spacing: FamilyCompassSpacing.xs,
            runSpacing: FamilyCompassSpacing.xs,
            children: [
              for (final candidate in plan.candidateTimes)
                TogetherChoiceChip(
                  key: ValueKey<String>('poll-candidate-${candidate.id}'),
                  label: candidateTimeLabel(context, candidate),
                  selected: candidateId == candidate.id,
                  onSelected: response == null
                      ? (_) => onCandidateChanged(candidate.id)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.lg),
          Text(
            togetherCopy(context, 'Your response', 'ردك'),
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Wrap(
            spacing: FamilyCompassSpacing.xs,
            runSpacing: FamilyCompassSpacing.xs,
            children: [
              for (final item in RsvpChoice.values)
                TogetherChoiceChip(
                  key: ValueKey<String>('rsvp-${item.name}'),
                  label: responseChoiceLabel(context, item),
                  selected: choice == item,
                  onSelected:
                      response == null ? (_) => onChoiceChanged(item) : null,
                ),
            ],
          ),
          if (choice == RsvpChoice.maybe ||
              choice == RsvpChoice.cannotMakeIt) ...[
            const SizedBox(height: FamilyCompassSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('suggest-another-time'),
              onPressed: response == null ? onSuggestAnother : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  0,
                  FamilyCompassSizes.minimumTouchTarget,
                ),
              ),
              icon: const Icon(FamilyCompassIcons.addRounded),
              label: Text(context.l10n.pollSuggestAnother),
            ),
          ],
          const SizedBox(height: FamilyCompassSpacing.lg),
          if (response == null)
            FilledButton(
              key: const ValueKey('submit-poll-response'),
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  0,
                  FamilyCompassSizes.minimumTouchTarget,
                ),
              ),
              child: Text(
                togetherCopy(context, 'Send my response', 'إرسال ردي'),
              ),
            )
          else
            TogetherStatusLine(
              icon: FamilyCompassIcons.checkRounded,
              text: togetherCopy(
                context,
                'Your response: ${responseChoiceLabel(context, response!.choice)} for ${candidateLabel(response!.candidateId)}',
                'ردك: ${responseChoiceLabel(context, response!.choice)} في ${candidateLabel(response!.candidateId)}',
              ),
              background: semantic.successContainer,
              foreground: semantic.onSuccessContainer,
            ),
        ],
      ),
    );
  }
}

class _FamilyReplies extends StatelessWidget {
  const _FamilyReplies({
    required this.plan,
    required this.response,
    required this.allResponded,
    required this.selectedCandidate,
    required this.onNudge,
    required this.nudgeInFlight,
    required this.onConfirm,
    required this.memberForId,
  });

  final FamilyPlan plan;
  final PollResponse? response;
  final bool allResponded;
  final CandidateTime? selectedCandidate;
  final VoidCallback onNudge;
  final bool nudgeInFlight;
  final VoidCallback onConfirm;
  final FamilyMember Function(String id) memberForId;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(context, 'Family responses', 'ردود العائلة'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Material(
          color: Colors.transparent,
          shape: Border.symmetric(
            horizontal: BorderSide(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var index = 0;
                  index < plan.participantIds.length;
                  index++) ...[
                _ResponseTile(
                  memberId: plan.participantIds[index],
                  response: plan.responses[plan.participantIds[index]],
                  plan: plan,
                  member: memberForId(plan.participantIds[index]),
                ),
                if (index != plan.participantIds.length - 1)
                  Divider(height: 1, color: colors.outlineVariant),
              ],
            ],
          ),
        ),
        if (response != null) ...[
          const SizedBox(height: FamilyCompassSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('send-poll-nudge'),
              onPressed: plan.nudgeSent || nudgeInFlight ? null : onNudge,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  0,
                  FamilyCompassSizes.minimumTouchTarget,
                ),
              ),
              icon: Icon(
                nudgeInFlight
                    ? FamilyCompassIcons.scheduleOutlined
                    : plan.nudgeSent
                        ? FamilyCompassIcons.checkRounded
                        : FamilyCompassIcons.notificationsActiveOutlined,
              ),
              label: Text(
                nudgeInFlight
                    ? togetherCopy(
                        context,
                        'Sending nudge…',
                        'جارٍ إرسال التذكير…',
                      )
                    : plan.nudgeSent
                        ? togetherCopy(
                            context, 'Nudge sent', 'تم إرسال التذكير')
                        : plan.nudgeDeliveryFailed
                            ? togetherCopy(
                                context,
                                'Try nudge again',
                                'حاول إرسال التذكير مجددًا',
                              )
                            : _nudgeLabel(context),
              ),
            ),
          ),
        ],
        if (allResponded) ...[
          const SizedBox(height: FamilyCompassSpacing.lg),
          TogetherStatusLine(
            icon: FamilyCompassIcons.groupOutlined,
            text: togetherCopy(
              context,
              '$_selectedAttendingCount of ${plan.participantIds.length} can make ${_selectedTimeLabel(context)}.',
              'يمكن لـ$_selectedAttendingCount من أصل ${plan.participantIds.length} الحضور في ${_selectedTimeLabel(context)}.',
            ),
            background: semantic.gatheringContainer,
            foreground: semantic.onGatheringContainer,
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('confirm-dinner'),
            onPressed:
                plan.phase == PlanPhase.readyToConfirm ? onConfirm : null,
            style: FilledButton.styleFrom(
              backgroundColor: semantic.gathering,
              foregroundColor: semantic.onGathering,
              minimumSize: const Size(
                0,
                FamilyCompassSizes.minimumTouchTarget,
              ),
            ),
            icon: const Icon(FamilyCompassIcons.eventAvailableOutlined),
            label: Text(
              togetherCopy(
                context,
                'Confirm ${_selectedTimeLabel(context)}',
                'تأكيد ${_selectedTimeLabel(context)}',
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _selectedTimeLabel(BuildContext context) => selectedCandidate == null
      ? togetherCopy(context, 'the selected time', 'الوقت المختار')
      : candidateTimeLabel(context, selectedCandidate!);

  int get _selectedAttendingCount {
    final selectedId = selectedCandidate?.id;
    return plan.responses.values.where((response) {
      return response.candidateId == selectedId &&
          response.choice != RsvpChoice.cannotMakeIt;
    }).length;
  }

  String _nudgeLabel(BuildContext context) {
    final pendingId = plan.participantIds
        .where((memberId) => !plan.responses.containsKey(memberId))
        .firstOrNull;
    if (pendingId == null) {
      return togetherCopy(context, 'Nudge family', 'تذكير العائلة');
    }
    final name = togetherMemberDisplayName(context, memberForId(pendingId));
    return togetherCopy(context, 'Nudge $name', 'تذكير $name');
  }
}

class _ResponseTile extends StatelessWidget {
  const _ResponseTile({
    required this.memberId,
    required this.response,
    required this.plan,
    required this.member,
  });

  final String memberId;
  final PollResponse? response;
  final FamilyPlan plan;
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final candidate = response == null
        ? null
        : plan.candidateTimes
            .where((item) => item.id == response!.candidateId)
            .firstOrNull;
    final name = togetherMemberDisplayName(context, member);
    return ListTile(
      key: ValueKey<String>('poll-response-$memberId'),
      contentPadding: EdgeInsets.zero,
      leading: MemberMark(
        initial: member.initials,
        semanticLabel: name,
      ),
      title: Text(name),
      subtitle: Text(
        response == null
            ? togetherCopy(
                context,
                'Waiting for response',
                'بانتظار الرد',
              )
            : '${responseChoiceLabel(context, response!.choice)} · ${candidate == null ? togetherCopy(context, 'Selected time', 'الوقت المختار') : candidateTimeLabel(context, candidate)}',
      ),
      trailing: Icon(
        response == null
            ? FamilyCompassIcons.scheduleOutlined
            : FamilyCompassIcons.checkRounded,
        color: response == null ? colors.onSurfaceVariant : colors.primary,
        semanticLabel: response == null
            ? togetherCopy(context, 'Pending', 'معلّق')
            : togetherCopy(context, 'Responded', 'تم الرد'),
      ),
    );
  }
}
