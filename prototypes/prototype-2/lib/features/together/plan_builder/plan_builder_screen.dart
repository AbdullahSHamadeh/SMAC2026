import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/plan_models.dart';
import '../../../prototype/fixtures.dart';
import '../../../prototype/prototype_scenario_controller.dart';
import '../widgets/together_widgets.dart';

class PlanBuilderScreen extends StatelessWidget {
  const PlanBuilderScreen({
    required this.controller,
    required this.plan,
    required this.onClose,
    required this.onPollSent,
    super.key,
  });

  final PrototypeScenarioController controller;
  final FamilyPlan plan;
  final VoidCallback onClose;
  final VoidCallback onPollSent;

  static const _stepLabels = <String>[
    'Choose idea',
    'Choose times',
    'Choose people',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final ui = controller.state.ui;
    final step = ui.planBuilderStep.clamp(0, _stepLabels.length - 1);
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);

    return ColoredBox(
      color: semantic.pageBackground,
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey<String>('plan-builder-scroll'),
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
                    title: 'Plan family time',
                    subtitle: 'Nothing is sent until you review the poll.',
                    onBack: () => _requestClose(context),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.lg),
                  Semantics(
                    label: 'Step ${step + 1} of ${_stepLabels.length}',
                    child: LinearProgressIndicator(
                      value: (step + 1) / _stepLabels.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(
                        FamilyCompassRadii.pill,
                      ),
                      color: semantic.gathering,
                      backgroundColor: semantic.gatheringContainer,
                    ),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  Text(
                    '${step + 1} of ${_stepLabels.length} · ${_stepLabels[step]}',
                    style: textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: FamilyCompassSpacing.lg),
                  KeyedSubtree(
                    key: ValueKey<String>('plan-builder-step-$step'),
                    child: switch (step) {
                      0 => _IdeaStep(plan: plan),
                      1 => _CandidateTimesStep(
                          plan: plan,
                          selectedIds: ui.selectedCandidateIds,
                          onToggle: controller.toggleCandidate,
                        ),
                      2 => _ParticipantsStep(plan: plan),
                      _ => _ReviewStep(
                          plan: plan,
                          selectedIds: ui.selectedCandidateIds,
                        ),
                    },
                  ),
                  const SizedBox(height: FamilyCompassSpacing.xl),
                  Wrap(
                    spacing: FamilyCompassSpacing.sm,
                    runSpacing: FamilyCompassSpacing.sm,
                    alignment: WrapAlignment.end,
                    children: [
                      if (step > 0)
                        OutlinedButton(
                          key: const ValueKey('plan-builder-back'),
                          onPressed: () =>
                              controller.setPlanBuilderStep(step - 1),
                          child: const Text('Back'),
                        ),
                      FilledButton(
                        key: ValueKey<String>(
                          step == _stepLabels.length - 1
                              ? 'send-poll'
                              : 'plan-builder-next',
                        ),
                        onPressed: _canContinue(step, ui.selectedCandidateIds)
                            ? () {
                                if (step == _stepLabels.length - 1) {
                                  controller.sendPoll();
                                  if (controller.state.plan?.phase ==
                                      PlanPhase.pollOpen) {
                                    onPollSent();
                                  }
                                } else {
                                  controller.setPlanBuilderStep(step + 1);
                                }
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: semantic.gathering,
                          foregroundColor: semantic.onGathering,
                        ),
                        child: Text(
                          step == _stepLabels.length - 1 ? 'Send poll' : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canContinue(int step, Set<String> selectedIds) {
    if (step == 1 || step == 3) return selectedIds.length >= 2;
    return true;
  }

  Future<void> _requestClose(BuildContext context) async {
    if (!controller.state.ui.hasUnsavedPlanChanges) {
      onClose();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this plan?'),
        content: const Text(
          'Your changes have not been sent to the family.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const ValueKey('discard-plan-draft'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave plan'),
          ),
        ],
      ),
    );
    if (discard == true) onClose();
  }
}

class _IdeaStep extends StatelessWidget {
  const _IdeaStep({required this.plan});

  final FamilyPlan plan;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should you do together?', style: textTheme.titleLarge),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Card(
          color: semantic.gatheringContainer,
          child: Padding(
            padding: const EdgeInsets.all(FamilyCompassSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restaurant_rounded, color: semantic.gathering),
                const SizedBox(width: FamilyCompassSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title, style: textTheme.titleMedium),
                      const SizedBox(height: FamilyCompassSpacing.xxs),
                      Text(plan.description, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: semantic.gathering,
                  semanticLabel: 'Selected',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        Text('Other ideas', style: textTheme.titleSmall),
        const SizedBox(height: FamilyCompassSpacing.xs),
        const Wrap(
          spacing: FamilyCompassSpacing.xs,
          runSpacing: FamilyCompassSpacing.xs,
          children: [
            Chip(label: Text('Family call')),
            Chip(label: Text('Visit')),
            Chip(label: Text('Walk')),
            Chip(label: Text('Custom')),
          ],
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          'Dinner is the complete scenario in this prototype.',
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CandidateTimesStep extends StatelessWidget {
  const _CandidateTimesStep({
    required this.plan,
    required this.selectedIds,
    required this.onToggle,
  });

  final FamilyPlan plan;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which times should the family vote on?',
            style: textTheme.titleLarge),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          'Choose at least two options.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        ...plan.candidateTimes.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.xs),
            child: Card(
              child: CheckboxListTile(
                key: ValueKey<String>('candidate-${candidate.id}'),
                value: selectedIds.contains(candidate.id),
                onChanged: (_) => onToggle(candidate.id),
                title: Text(candidateTimeLabel(context, candidate)),
                subtitle: const Text('Family dinner at home'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ),
        ),
        if (selectedIds.length < 2)
          Text(
            'Select one more time to continue.',
            key: const ValueKey('candidate-time-error'),
            style: textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
      ],
    );
  }
}

class _ParticipantsStep extends StatelessWidget {
  const _ParticipantsStep({required this.plan});

  final FamilyPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who should be included?', style: textTheme.titleLarge),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          'All adults in the demonstration family are selected.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Card(
          child: Column(
            children: [
              for (var index = 0;
                  index < plan.participantIds.length;
                  index++) ...[
                ListTile(
                  key: ValueKey<String>(
                    'participant-${plan.participantIds[index]}',
                  ),
                  leading: CircleAvatar(
                    child:
                        Text(memberById(plan.participantIds[index]).initials),
                  ),
                  title: Text(memberById(plan.participantIds[index]).name),
                  subtitle: Text(
                    memberById(plan.participantIds[index]).relationship,
                  ),
                  trailing: Icon(
                    Icons.check_circle_rounded,
                    color: colors.primary,
                    semanticLabel: 'Selected',
                  ),
                ),
                if (index != plan.participantIds.length - 1) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.plan, required this.selectedIds});

  final FamilyPlan plan;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    final selectedTimes = plan.candidateTimes
        .where((candidate) => selectedIds.contains(candidate.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review before sending', style: textTheme.titleLarge),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          'The family will receive a poll. You will confirm the final time after everyone responds.',
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FamilyCompassSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: textTheme.titleMedium),
                const SizedBox(height: FamilyCompassSpacing.sm),
                for (final candidate in selectedTimes)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: FamilyCompassSpacing.xs,
                    ),
                    child: _ReviewLine(
                      icon: Icons.schedule_rounded,
                      text: candidateTimeLabel(context, candidate),
                    ),
                  ),
                _ReviewLine(
                  icon: Icons.group_outlined,
                  text: '${plan.participantIds.length} adult participants',
                ),
                const SizedBox(height: FamilyCompassSpacing.xs),
                const _ReviewLine(
                  icon: Icons.event_available_outlined,
                  text: 'Decision deadline: Friday at noon',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: FamilyCompassSpacing.xs),
          Expanded(child: Text(text)),
        ],
      );
}
