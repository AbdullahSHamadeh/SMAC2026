import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/family_models.dart';
import '../../../domain/plan_models.dart';
import '../../../l10n/l10n.dart';
import '../../../prototype/prototype_scenario_controller.dart';
import '../../../widgets/prototype_widgets.dart';
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

  static const _englishStepLabels = <String>[
    'Choose idea',
    'Choose times',
    'Choose people',
    'Review',
  ];

  static const _arabicStepLabels = <String>[
    'اختيار الفكرة',
    'اختيار الأوقات',
    'اختيار الأشخاص',
    'المراجعة',
  ];

  @override
  Widget build(BuildContext context) {
    final ui = controller.state.ui;
    final step = ui.planBuilderStep.clamp(0, _englishStepLabels.length - 1);
    final labels =
        togetherUsesArabic(context) ? _arabicStepLabels : _englishStepLabels;

    return TogetherPageCanvas(
      scrollKey: const PageStorageKey<String>('plan-builder-scroll'),
      builder: (context, constraints, compactHeight) {
        final split = constraints.maxWidth >= 760 ||
            (compactHeight && constraints.maxWidth >= 680);
        final content = _BuilderContent(
          key: ValueKey<String>('plan-builder-step-$step'),
          plan: plan,
          step: step,
          selectedIds: ui.selectedCandidateIds,
          onToggle: controller.toggleCandidate,
          memberForId: controller.memberForId,
          usesBackend: controller.usesBackend,
        );
        final navigation = _BuilderNavigation(
          step: step,
          selectedIds: ui.selectedCandidateIds,
          onBack: () => controller.setPlanBuilderStep(step - 1),
          onNext: () => _advance(step),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TogetherDetailHeader(
              title: togetherCopy(
                context,
                'Plan family time',
                'التخطيط لوقت العائلة',
              ),
              subtitle: togetherCopy(
                context,
                'Nothing is sent until you review the poll.',
                'لن يُرسل شيء قبل مراجعة الاستطلاع.',
              ),
              onBack: () => _requestClose(context),
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            if (split)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth >= 840 ? 280 : 220,
                    child: _BuilderStepRail(
                      labels: labels,
                      currentStep: step,
                    ),
                  ),
                  const SizedBox(width: FamilyCompassSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        const SizedBox(height: FamilyCompassSpacing.xl),
                        navigation,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _CompactStepProgress(labels: labels, currentStep: step),
              const SizedBox(height: FamilyCompassSpacing.lg),
              content,
              const SizedBox(height: FamilyCompassSpacing.xl),
              navigation,
            ],
          ],
        );
      },
    );
  }

  void _advance(int step) {
    if (step == _englishStepLabels.length - 1) {
      controller.sendPoll();
      if (controller.state.plan?.phase == PlanPhase.pollOpen) onPollSent();
      return;
    }
    controller.setPlanBuilderStep(step + 1);
  }

  Future<void> _requestClose(BuildContext context) async {
    if (!controller.state.ui.hasUnsavedPlanChanges) {
      onClose();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          togetherCopy(context, 'Leave this plan?', 'مغادرة هذه الخطة؟'),
        ),
        content: Text(
          togetherCopy(
            context,
            'Your changes have not been sent to the family.',
            'لم تُرسل تغييراتك إلى العائلة.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              togetherCopy(context, 'Keep editing', 'متابعة التعديل'),
            ),
          ),
          FilledButton(
            key: const ValueKey('discard-plan-draft'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(togetherCopy(context, 'Leave plan', 'مغادرة الخطة')),
          ),
        ],
      ),
    );
    if (discard == true) onClose();
  }
}

class _BuilderStepRail extends StatelessWidget {
  const _BuilderStepRail({required this.labels, required this.currentStep});

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            togetherCopy(context, 'Plan progress', 'تقدم الخطة'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          for (var index = 0; index < labels.length; index++)
            TogetherThreadItem(
              isFirst: index == 0,
              isLast: index == labels.length - 1,
              isComplete: index < currentStep,
              isCurrent: index == currentStep,
              padding: const EdgeInsets.only(
                bottom: FamilyCompassSpacing.sm,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FamilyCompassSpacing.sm,
                ),
                child: Text(
                  labels[index],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: index > currentStep
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
        ],
      );
}

class _CompactStepProgress extends StatelessWidget {
  const _CompactStepProgress({
    required this.labels,
    required this.currentStep,
  });

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: togetherCopy(
        context,
        'Step ${currentStep + 1} of ${labels.length}: ${labels[currentStep]}',
        'الخطوة ${currentStep + 1} من ${labels.length}: ${labels[currentStep]}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    color: index <= currentStep
                        ? semantic.gatheringInk
                        : scheme.outlineVariant,
                  ),
                ),
                if (index != labels.length - 1)
                  const SizedBox(width: FamilyCompassSpacing.xxs),
              ],
            ],
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          Text(
            togetherCopy(
              context,
              '${currentStep + 1} of ${labels.length} · ${labels[currentStep]}',
              '${currentStep + 1} من ${labels.length} · ${labels[currentStep]}',
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _BuilderContent extends StatelessWidget {
  const _BuilderContent({
    required this.plan,
    required this.step,
    required this.selectedIds,
    required this.onToggle,
    required this.memberForId,
    required this.usesBackend,
    super.key,
  });

  final FamilyPlan plan;
  final int step;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final FamilyMember Function(String id) memberForId;
  final bool usesBackend;

  @override
  Widget build(BuildContext context) => switch (step) {
        0 => _IdeaStep(plan: plan, usesBackend: usesBackend),
        1 => _CandidateTimesStep(
            plan: plan,
            selectedIds: selectedIds,
            onToggle: onToggle,
          ),
        2 => _ParticipantsStep(
            plan: plan,
            memberForId: memberForId,
            usesBackend: usesBackend,
          ),
        _ => _ReviewStep(plan: plan, selectedIds: selectedIds),
      };
}

class _BuilderNavigation extends StatelessWidget {
  const _BuilderNavigation({
    required this.step,
    required this.selectedIds,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final Set<String> selectedIds;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canContinue = step != 1 && step != 3 || selectedIds.length >= 2;
    final semantic = FamilyCompassSemanticColors.of(context);
    return Wrap(
      spacing: FamilyCompassSpacing.sm,
      runSpacing: FamilyCompassSpacing.sm,
      alignment: WrapAlignment.end,
      children: [
        if (step > 0)
          OutlinedButton(
            key: const ValueKey('plan-builder-back'),
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                0,
                FamilyCompassSizes.minimumTouchTarget,
              ),
            ),
            child: Text(togetherCopy(context, 'Back', 'رجوع')),
          ),
        FilledButton(
          key: ValueKey<String>(step == 3 ? 'send-poll' : 'plan-builder-next'),
          onPressed: canContinue ? onNext : null,
          style: FilledButton.styleFrom(
            backgroundColor: semantic.gathering,
            foregroundColor: semantic.onGathering,
            minimumSize: const Size(
              0,
              FamilyCompassSizes.minimumTouchTarget,
            ),
          ),
          child: Text(
            step == 3
                ? togetherCopy(context, 'Send poll', 'إرسال الاستطلاع')
                : togetherCopy(context, 'Next', 'التالي'),
          ),
        ),
      ],
    );
  }
}

class _IdeaStep extends StatelessWidget {
  const _IdeaStep({required this.plan, required this.usesBackend});

  final FamilyPlan plan;
  final bool usesBackend;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(
            context,
            'What should you do together?',
            'ماذا ستفعلون معًا؟',
          ),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        TogetherPlanFolio(
          plan: plan,
          phaseLabel: togetherCopy(context, 'Selected idea', 'الفكرة المختارة'),
          detail: togetherPlanDescription(context, plan),
          supportingLabel: togetherCopy(
            context,
            'This idea came from the family thread.',
            'جاءت هذه الفكرة من مسار العائلة.',
          ),
          emphasized: true,
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        Text(
          togetherCopy(context, 'Other ideas', 'أفكار أخرى'),
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            'Family call · Visit · Walk · Custom',
            'مكالمة عائلية · زيارة · نزهة · فكرة مخصصة',
          ),
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            usesBackend
                ? 'Dinner is the first fully supported family plan.'
                : 'Dinner is the complete scenario in this prototype.',
            usesBackend
                ? 'العشاء هو أول خطة عائلية مدعومة بالكامل.'
                : 'العشاء هو السيناريو المكتمل في هذا النموذج.',
          ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(
            context,
            'Which times should the family vote on?',
            'على أي أوقات ستصوّت العائلة؟',
          ),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            'Choose at least two options.',
            'اختر خيارين على الأقل.',
          ),
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0;
                    index < plan.candidateTimes.length;
                    index++) ...[
                  CheckboxListTile(
                    key: ValueKey<String>(
                      'candidate-${plan.candidateTimes[index].id}',
                    ),
                    value: selectedIds.contains(plan.candidateTimes[index].id),
                    onChanged: (_) => onToggle(plan.candidateTimes[index].id),
                    title: Text(
                      candidateTimeLabel(context, plan.candidateTimes[index]),
                    ),
                    subtitle: Text(
                      togetherCopy(
                        context,
                        'Family dinner at home',
                        'عشاء عائلي في المنزل',
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (index != plan.candidateTimes.length - 1)
                    Divider(height: 1, color: colors.outlineVariant),
                ],
              ],
            ),
          ),
        ),
        if (selectedIds.length < 2) ...[
          const SizedBox(height: FamilyCompassSpacing.sm),
          Text(
            togetherCopy(
              context,
              'Select one more time to continue.',
              'اختر وقتًا آخر للمتابعة.',
            ),
            key: const ValueKey('candidate-time-error'),
            style: textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}

class _ParticipantsStep extends StatelessWidget {
  const _ParticipantsStep({
    required this.plan,
    required this.memberForId,
    required this.usesBackend,
  });

  final FamilyPlan plan;
  final FamilyMember Function(String id) memberForId;
  final bool usesBackend;

  @override
  Widget build(BuildContext context) {
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(context, 'Who should be included?', 'من سيشارك؟'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            usesBackend
                ? 'All adults in this family are included.'
                : 'All adults in the demonstration family are selected.',
            usesBackend
                ? 'تم إشراك جميع البالغين في هذه العائلة.'
                : 'تم اختيار جميع البالغين في العائلة التجريبية.',
          ),
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0;
                  index < plan.participantIds.length;
                  index++) ...[
                ListTile(
                  key: ValueKey<String>(
                    'participant-${plan.participantIds[index]}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: MemberMark(
                    initial: memberForId(plan.participantIds[index]).initials,
                    semanticLabel: togetherMemberDisplayName(
                      context,
                      memberForId(plan.participantIds[index]),
                    ),
                  ),
                  title: Text(
                    togetherMemberDisplayName(
                      context,
                      memberForId(plan.participantIds[index]),
                    ),
                  ),
                  subtitle: Text(
                    memberForId(
                      plan.participantIds[index],
                    ).localizedRelationship(context),
                  ),
                  trailing: Icon(
                    FamilyCompassIcons.checkRounded,
                    color: colors.primary,
                    semanticLabel: togetherCopy(
                      context,
                      'Selected',
                      'تم الاختيار',
                    ),
                  ),
                ),
                if (index != plan.participantIds.length - 1)
                  Divider(height: 1, color: colors.outlineVariant),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(context, 'Review before sending', 'راجع قبل الإرسال'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            'The family will receive one poll. You will confirm the final time after everyone responds.',
            'ستتلقى العائلة استطلاعًا واحدًا. ستؤكد الوقت النهائي بعد رد الجميع.',
          ),
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        FolioSurface(
          backgroundColor: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                togetherPlanTitle(context, plan),
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: FamilyCompassSpacing.sm),
              for (final candidate in selectedTimes)
                TogetherMetadataRow(
                  icon: FamilyCompassIcons.scheduleOutlined,
                  label: candidateTimeLabel(context, candidate),
                  topDivider: true,
                ),
              TogetherMetadataRow(
                icon: FamilyCompassIcons.groupOutlined,
                label: togetherCopy(
                  context,
                  '${plan.participantIds.length} adult participants',
                  '${plan.participantIds.length} مشاركين بالغين',
                ),
                topDivider: true,
              ),
              TogetherMetadataRow(
                icon: FamilyCompassIcons.eventAvailableOutlined,
                label: togetherCopy(
                  context,
                  'Decision deadline: ${planDeadlineLabel(context, plan)}',
                  'آخر موعد للقرار: ${planDeadlineLabel(context, plan)}',
                ),
                topDivider: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
