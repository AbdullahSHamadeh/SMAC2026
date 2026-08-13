import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/plan_models.dart';
import '../../../prototype/prototype_scenario_controller.dart';
import '../../../prototype/prototype_scenario_state.dart';
import '../../../widgets/prototype_widgets.dart';
import '../widgets/together_widgets.dart';

class ConfirmedPlanScreen extends StatelessWidget {
  const ConfirmedPlanScreen({
    required this.controller,
    required this.plan,
    required this.notificationPermission,
    required this.onBack,
    required this.onPlanAgain,
    super.key,
  });

  final PrototypeScenarioController controller;
  final FamilyPlan plan;
  final NotificationPermissionState notificationPermission;
  final VoidCallback onBack;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final completed = plan.phase == PlanPhase.completed;
    final automaticReminder = _automaticReminder(plan);
    final reminderAdjusted = automaticReminder?.at.hour == 18;
    final dessertAdded = plan.contributions.any(
      (item) =>
          item.memberId == controller.currentUserId &&
          item.text.trim().toLowerCase() == 'i can bring dessert',
    );

    return TogetherPageCanvas(
      scrollKey: const PageStorageKey<String>('confirmed-plan-scroll'),
      builder: (context, constraints, compactHeight) {
        final splitInsideFolio = constraints.maxWidth >= 760 ||
            (compactHeight && constraints.maxWidth >= 680);
        final summary = _PlanSummary(plan: plan, completed: completed);
        final coordination = completed
            ? _CompletedActions(
                plan: plan,
                onPlanAgain: () {
                  controller.planAgain();
                  if (controller.state.plan?.phase == PlanPhase.draft) {
                    onPlanAgain();
                  }
                },
              )
            : _PlanCoordination(
                plan: plan,
                notificationPermission: notificationPermission,
                automaticReminder: automaticReminder,
                reminderAdjusted: reminderAdjusted,
                dessertAdded: dessertAdded,
                onAdjustReminder: controller.adjustAutomaticReminder,
                onAddDessert: controller.addDessertContribution,
                onComplete: controller.completeGathering,
                memberNameFor: (id) => togetherMemberDisplayName(
                  context,
                  controller.memberForId(id),
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TogetherDetailHeader(
              title: togetherPlanTitle(context, plan),
              subtitle: completed
                  ? togetherCopy(
                      context,
                      'A family moment you can plan again',
                      'لقاء عائلي يمكن التخطيط له مجددًا',
                    )
                  : togetherCopy(
                      context,
                      'The time, reminders, and contributions stay together.',
                      'الوقت والتذكيرات والمساهمات في مكان واحد.',
                    ),
              onBack: onBack,
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            FolioSurface(
              borderColor: completed
                  ? FamilyCompassSemanticColors.of(context).success
                  : FamilyCompassSemanticColors.of(context).gatheringInk,
              padding: EdgeInsets.zero,
              child: splitInsideFolio
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: BorderDirectional(
                                end: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                FamilyCompassSpacing.lg,
                              ),
                              child: summary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(
                              FamilyCompassSpacing.lg,
                            ),
                            child: coordination,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(
                            FamilyCompassSpacing.lg,
                          ),
                          child: summary,
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(
                            FamilyCompassSpacing.lg,
                          ),
                          child: coordination,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  PlanReminder? _automaticReminder(FamilyPlan plan) {
    for (final reminder in plan.reminders) {
      if (reminder.isAutomatic) return reminder;
    }
    return null;
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, required this.completed});

  final FamilyPlan plan;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final foreground = completed ? semantic.success : semantic.gatheringInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              completed
                  ? FamilyCompassIcons.checkRounded
                  : FamilyCompassIcons.eventAvailableOutlined,
              color: foreground,
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            Expanded(
              child: Text(
                completed
                    ? togetherCopy(context, 'Completed', 'اكتمل')
                    : togetherCopy(context, 'Confirmed', 'تم التأكيد'),
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
        const SizedBox(height: FamilyCompassSpacing.md),
        Text(
          togetherPlanTitle(context, plan),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Text(confirmedPlanLabel(context, plan), style: textTheme.titleMedium),
        const SizedBox(height: FamilyCompassSpacing.lg),
        TogetherMetadataRow(
          icon: FamilyCompassIcons.homeOutlined,
          label: togetherPlanDescription(context, plan),
          topDivider: true,
        ),
        TogetherMetadataRow(
          icon: FamilyCompassIcons.groupOutlined,
          label: togetherCopy(
            context,
            '${plan.participantIds.length} family members',
            '${plan.participantIds.length} من أفراد العائلة',
          ),
          detail: togetherCopy(
            context,
            'The final time is visible to everyone included.',
            'الوقت النهائي ظاهر لكل المشاركين.',
          ),
          topDivider: true,
        ),
      ],
    );
  }
}

class _CompletedActions extends StatelessWidget {
  const _CompletedActions({required this.plan, required this.onPlanAgain});

  final FamilyPlan plan;
  final VoidCallback onPlanAgain;

  @override
  Widget build(BuildContext context) {
    final day = planDayLabel(context, plan);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(context, 'Keep the idea', 'احتفظ بالفكرة'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            'Reuse this idea and choose new times for another $day.',
            'استخدم هذه الفكرة واختر أوقاتًا جديدة ليوم $day آخر.',
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('plan-again'),
          onPressed: onPlanAgain,
          style: FilledButton.styleFrom(
            backgroundColor: FamilyCompassSemanticColors.of(context).gathering,
            foregroundColor:
                FamilyCompassSemanticColors.of(context).onGathering,
            minimumSize: const Size(
              0,
              FamilyCompassSizes.minimumTouchTarget,
            ),
          ),
          icon: const Icon(FamilyCompassIcons.replayRounded),
          label: Text(
            togetherCopy(context, 'Plan this again', 'التخطيط مجددًا'),
          ),
        ),
      ],
    );
  }
}

class _PlanCoordination extends StatelessWidget {
  const _PlanCoordination({
    required this.plan,
    required this.notificationPermission,
    required this.automaticReminder,
    required this.reminderAdjusted,
    required this.dessertAdded,
    required this.onAdjustReminder,
    required this.onAddDessert,
    required this.onComplete,
    required this.memberNameFor,
  });

  final FamilyPlan plan;
  final NotificationPermissionState notificationPermission;
  final PlanReminder? automaticReminder;
  final bool reminderAdjusted;
  final bool dessertAdded;
  final VoidCallback onAdjustReminder;
  final VoidCallback onAddDessert;
  final VoidCallback onComplete;
  final String Function(String id) memberNameFor;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          togetherCopy(context, 'Reminder', 'التذكير'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        if (notificationPermission == NotificationPermissionState.denied) ...[
          TogetherStatusLine(
            key: const ValueKey('notification-denied-notice'),
            icon: FamilyCompassIcons.notificationsOffOutlined,
            text: togetherCopy(
              context,
              'Phone notifications are off. This reminder remains visible in Family Compass.',
              'إشعارات الهاتف متوقفة. سيبقى هذا التذكير ظاهرًا في Family Compass.',
            ),
            background: semantic.warningContainer,
            foreground: semantic.onWarningContainer,
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
        ],
        if (plan.reminders.isEmpty)
          Text(
            togetherCopy(
              context,
              'No reminder is set.',
              'لم يتم تعيين تذكير.',
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else
          for (final reminder in plan.reminders)
            _ReminderLine(reminder: reminder),
        if (automaticReminder != null) ...[
          const SizedBox(height: FamilyCompassSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('adjust-reminder'),
              onPressed: reminderAdjusted ? null : onAdjustReminder,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  0,
                  FamilyCompassSizes.minimumTouchTarget,
                ),
              ),
              icon: Icon(
                reminderAdjusted
                    ? FamilyCompassIcons.checkRounded
                    : FamilyCompassIcons.editNotificationsOutlined,
              ),
              label: Text(
                reminderAdjusted
                    ? togetherCopy(
                        context,
                        'Reminder adjusted',
                        'تم تعديل التذكير',
                      )
                    : togetherCopy(
                        context,
                        'Adjust to 6:00 PM',
                        'التعديل إلى ٦:٠٠ مساءً',
                      ),
              ),
            ),
          ),
        ],
        const SizedBox(height: FamilyCompassSpacing.xl),
        Text(
          togetherCopy(context, 'Contributions', 'المساهمات'),
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          togetherCopy(
            context,
            'Family members volunteer only for what they choose.',
            'يتطوع أفراد العائلة فقط بما يختارونه.',
          ),
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        if (plan.contributions.isEmpty)
          Text(
            togetherCopy(
              context,
              'No contributions yet.',
              'لا توجد مساهمات بعد.',
            ),
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else
          for (final contribution in plan.contributions)
            TogetherMetadataRow(
              icon: FamilyCompassIcons.volunteerActivismOutlined,
              label: contribution.text,
              detail: memberNameFor(contribution.memberId),
              topDivider: true,
            ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('add-dessert-contribution'),
            onPressed: dessertAdded ? null : onAddDessert,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                0,
                FamilyCompassSizes.minimumTouchTarget,
              ),
            ),
            icon: Icon(
              dessertAdded
                  ? FamilyCompassIcons.checkRounded
                  : FamilyCompassIcons.addRounded,
            ),
            label: Text(
              dessertAdded
                  ? togetherCopy(context, 'Dessert added', 'تمت إضافة الحلوى')
                  : togetherCopy(
                      context,
                      'I can bring dessert',
                      'يمكنني إحضار الحلوى',
                    ),
            ),
          ),
        ),
        const SizedBox(height: FamilyCompassSpacing.xl),
        OutlinedButton.icon(
          key: const ValueKey('complete-gathering'),
          onPressed: onComplete,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(
              0,
              FamilyCompassSizes.minimumTouchTarget,
            ),
          ),
          icon: const Icon(FamilyCompassIcons.checkRounded),
          label: Text(
            togetherCopy(
              context,
              'Mark gathering complete',
              'تحديد اللقاء كمكتمل',
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderLine extends StatelessWidget {
  const _ReminderLine({required this.reminder});

  final PlanReminder reminder;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(reminder.at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final date = DateFormat.MMMEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(reminder.at);
    return TogetherMetadataRow(
      icon: reminder.isAutomatic
          ? FamilyCompassIcons.notificationsActiveOutlined
          : FamilyCompassIcons.alarmOutlined,
      label: reminder.isAutomatic
          ? togetherCopy(
              context,
              'Automatic gathering reminder',
              'تذكير تلقائي باللقاء',
            )
          : reminder.label,
      detail: togetherCopy(
        context,
        '$date at $time · In-app reminder',
        '$date الساعة $time · تذكير داخل التطبيق',
      ),
      topDivider: true,
    );
  }
}
