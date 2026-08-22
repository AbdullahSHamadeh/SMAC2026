import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/plan_models.dart';
import '../../../l10n/l10n.dart';
import '../../../prototype/prototype_scenario_controller.dart';
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
    final existing = widget.plan.responses['abdullah'];
    _candidateId = existing?.candidateId ?? 'friday-1930';
    _choice = existing?.choice ?? RsvpChoice.going;
  }

  @override
  void didUpdateWidget(covariant PollDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final existing = widget.plan.responses['abdullah'];
    if (existing != null && oldWidget.plan.responses['abdullah'] == null) {
      _candidateId = existing.candidateId;
      _choice = existing.choice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final response = plan.responses['abdullah'];
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    final allResponded = plan.responses.length == plan.participantIds.length;

    return PageAtmosphere(
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey<String>('poll-detail-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.md,
                FamilyCompassSpacing.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  TogetherDetailHeader(
                    title: context.l10n.todayFamilyDinner,
                    subtitle: context.l10n.pollTitle,
                    onBack: widget.onBack,
                  ),
                  const SizedBox(height: FamilyCompassSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.pollDinnerQuestion,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: FamilyCompassSpacing.xs),
                          Text(
                            'Choose the time you prefer, then tell the family if you can attend.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: FamilyCompassSpacing.md),
                          Text('Preferred time', style: textTheme.titleSmall),
                          const SizedBox(height: FamilyCompassSpacing.xs),
                          Wrap(
                            spacing: FamilyCompassSpacing.xs,
                            runSpacing: FamilyCompassSpacing.xs,
                            children: [
                              for (final candidate in plan.candidateTimes)
                                ChoiceChip(
                                  key: ValueKey<String>(
                                    'poll-candidate-${candidate.id}',
                                  ),
                                  label: Text(
                                      candidateTimeLabel(context, candidate)),
                                  selected: _candidateId == candidate.id,
                                  onSelected: response == null
                                      ? (_) => setState(
                                            () => _candidateId = candidate.id,
                                          )
                                      : null,
                                ),
                            ],
                          ),
                          const SizedBox(height: FamilyCompassSpacing.md),
                          Text('Your response', style: textTheme.titleSmall),
                          const SizedBox(height: FamilyCompassSpacing.xs),
                          Wrap(
                            spacing: FamilyCompassSpacing.xs,
                            runSpacing: FamilyCompassSpacing.xs,
                            children: [
                              for (final choice in RsvpChoice.values)
                                ChoiceChip(
                                  key: ValueKey<String>(
                                    'rsvp-${choice.name}',
                                  ),
                                  label: Text(
                                    responseChoiceLabel(context, choice),
                                  ),
                                  selected: _choice == choice,
                                  onSelected: response == null
                                      ? (_) => setState(() => _choice = choice)
                                      : null,
                                ),
                            ],
                          ),
                          if (_choice == RsvpChoice.maybe ||
                              _choice == RsvpChoice.cannotMakeIt) ...[
                            const SizedBox(height: FamilyCompassSpacing.sm),
                            OutlinedButton.icon(
                              key: const ValueKey('suggest-another-time'),
                              onPressed: response == null
                                  ? () => _showSuggestionNote(context)
                                  : null,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(context.l10n.pollSuggestAnother),
                            ),
                          ],
                          const SizedBox(height: FamilyCompassSpacing.md),
                          if (response == null)
                            FilledButton(
                              key: const ValueKey('submit-poll-response'),
                              onPressed: () =>
                                  widget.controller.submitAbdullahResponse(
                                candidateId: _candidateId,
                                choice: _choice,
                              ),
                              child: const Text('Send my response'),
                            )
                          else
                            _StatusNotice(
                              icon: Icons.check_circle_outline_rounded,
                              text:
                                  'Your response: ${responseChoiceLabel(context, response.choice)} for ${_candidateLabel(context, response.candidateId)}',
                              background: semantic.successContainer,
                              foreground: semantic.onSuccessContainer,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.lg),
                  Text('Family responses', style: textTheme.titleLarge),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  Card(
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < plan.participantIds.length;
                            index++) ...[
                          _ResponseTile(
                            memberId: plan.participantIds[index],
                            response:
                                plan.responses[plan.participantIds[index]],
                            plan: plan,
                          ),
                          if (index != plan.participantIds.length - 1)
                            const Divider(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.md),
                  if (response != null)
                    OutlinedButton.icon(
                      key: const ValueKey('send-poll-nudge'),
                      onPressed: plan.nudgeSent
                          ? null
                          : widget.controller.sendPollNudge,
                      icon: Icon(
                        plan.nudgeSent
                            ? Icons.check_circle_outline_rounded
                            : Icons.notifications_active_outlined,
                      ),
                      label: Text(plan.nudgeSent ? 'Nudge sent' : 'Nudge Sara'),
                    ),
                  if (allResponded) ...[
                    const SizedBox(height: FamilyCompassSpacing.lg),
                    _StatusNotice(
                      icon: Icons.groups_rounded,
                      text: 'Everyone can make Friday at 7:30 PM.',
                      background: semantic.gatheringContainer,
                      foreground: semantic.onGatheringContainer,
                    ),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    FilledButton.icon(
                      key: const ValueKey('confirm-dinner'),
                      onPressed: plan.phase == PlanPhase.readyToConfirm
                          ? () {
                              widget.controller.confirmDinner();
                              if (widget.controller.state.plan?.phase ==
                                  PlanPhase.confirmed) {
                                widget.onConfirmed();
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: semantic.gathering,
                        foregroundColor: semantic.onGathering,
                      ),
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Confirm Friday at 7:30 PM'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _candidateLabel(BuildContext context, String id) {
    for (final candidate in widget.plan.candidateTimes) {
      if (candidate.id == id) return candidateTimeLabel(context, candidate);
    }
    return 'the selected time';
  }

  void _showSuggestionNote(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FamilyCompassSpacing.md,
            FamilyCompassSpacing.xs,
            FamilyCompassSpacing.md,
            FamilyCompassSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggest another time',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FamilyCompassSpacing.xs),
              const Text(
                'The Dinner scenario uses the two prepared times. Custom suggestions will be saved in the functional prototype.',
              ),
              const SizedBox(height: FamilyCompassSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseTile extends StatelessWidget {
  const _ResponseTile({
    required this.memberId,
    required this.response,
    required this.plan,
  });

  final String memberId;
  final PollResponse? response;
  final FamilyPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final candidate = response == null
        ? null
        : plan.candidateTimes
            .where((item) => item.id == response!.candidateId)
            .firstOrNull;
    return ListTile(
      key: ValueKey<String>('poll-response-$memberId'),
      leading: MemberAvatar(
        initials: memberName(memberId).characters.first,
        memberId: memberId,
      ),
      title: Text(memberName(memberId)),
      subtitle: Text(
        response == null
            ? 'Waiting for response'
            : '${responseChoiceLabel(context, response!.choice)} · ${candidate == null ? 'Selected time' : candidateTimeLabel(context, candidate)}',
      ),
      trailing: Icon(
        response == null ? Icons.schedule_rounded : Icons.check_circle_rounded,
        color: response == null ? colors.onSurfaceVariant : colors.primary,
        semanticLabel: response == null ? 'Pending' : 'Responded',
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(FamilyCompassSpacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: FamilyCompassSpacing.xs),
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
      );
}
