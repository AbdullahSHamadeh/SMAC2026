import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../domain/plan_models.dart';
import '../../../prototype/prototype_scenario_controller.dart';
import '../../../prototype/prototype_scenario_state.dart';
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
    final semantic = FamilyCompassSemanticColors.of(context);
    final textTheme = FamilyCompassTypography.of(context);
    final colors = Theme.of(context).colorScheme;
    final automaticReminder = _automaticReminder(plan);
    final reminderAdjusted = automaticReminder?.at.hour == 18;
    final dessertAdded = plan.contributions.any((item) => item.id == 'dessert');

    return PageAtmosphere(
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey<String>('confirmed-plan-scroll'),
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
                    title: completed ? 'Dinner completed' : 'Dinner confirmed',
                    subtitle: completed
                        ? 'A family moment worth planning again'
                        : 'Everyone has the final time',
                    onBack: onBack,
                  ),
                  const SizedBox(height: FamilyCompassSpacing.lg),
                  SoftCard(
                    color: completed
                        ? semantic.successContainer
                        : semantic.gatheringContainer,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            completed
                                ? Icons.favorite_rounded
                                : Icons.restaurant_rounded,
                            color: completed
                                ? semantic.success
                                : semantic.gathering,
                            size: 32,
                          ),
                          const SizedBox(height: FamilyCompassSpacing.sm),
                          Text(plan.title, style: textTheme.headlineSmall),
                          const SizedBox(height: FamilyCompassSpacing.xs),
                          Text(
                            confirmedPlanLabel(context, plan),
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: FamilyCompassSpacing.xs),
                          Text(
                            '${plan.participantIds.length} family members · ${plan.description}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: completed
                                  ? semantic.onSuccessContainer
                                  : semantic.onGatheringContainer,
                            ),
                          ),
                        ],
                    ),
                  ),
                  if (completed) ...[
                    const SizedBox(height: FamilyCompassSpacing.lg),
                    FilledButton.icon(
                      key: const ValueKey('plan-again'),
                      onPressed: () {
                        controller.planAgain();
                        if (controller.state.plan?.phase == PlanPhase.draft) {
                          onPlanAgain();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: semantic.gathering,
                        foregroundColor: semantic.onGathering,
                      ),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Plan this again'),
                    ),
                  ] else ...[
                    const SizedBox(height: FamilyCompassSpacing.xl),
                    Text('Reminder', style: textTheme.titleLarge),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    if (notificationPermission ==
                        NotificationPermissionState.denied) ...[
                      _InformationNotice(
                        key: const ValueKey('notification-denied-notice'),
                        icon: Icons.notifications_off_outlined,
                        text:
                            'Phone notifications are off. This reminder remains visible in Family Compass.',
                        background: semantic.warningContainer,
                        foreground: semantic.onWarningContainer,
                      ),
                      const SizedBox(height: FamilyCompassSpacing.sm),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final reminder in plan.reminders)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: FamilyCompassSpacing.sm,
                                ),
                                child: _ReminderLine(reminder: reminder),
                              ),
                            if (automaticReminder != null)
                              OutlinedButton.icon(
                                key: const ValueKey('adjust-reminder'),
                                onPressed: reminderAdjusted
                                    ? null
                                    : controller.adjustAutomaticReminder,
                                icon: Icon(
                                  reminderAdjusted
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.edit_notifications_outlined,
                                ),
                                label: Text(
                                  reminderAdjusted
                                      ? 'Reminder adjusted'
                                      : 'Adjust to 6:00 PM',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xl),
                    Text('Contributions', style: textTheme.titleLarge),
                    const SizedBox(height: FamilyCompassSpacing.xs),
                    Text(
                      'Family members volunteer only for what they choose.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (plan.contributions.isEmpty)
                              Text(
                                'No contributions yet.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              )
                            else
                              for (final contribution in plan.contributions)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.volunteer_activism_outlined,
                                    color: semantic.gathering,
                                  ),
                                  title: Text(contribution.text),
                                  subtitle:
                                      Text(memberName(contribution.memberId)),
                                ),
                            const SizedBox(height: FamilyCompassSpacing.xs),
                            OutlinedButton.icon(
                              key: const ValueKey('add-dessert-contribution'),
                              onPressed: dessertAdded
                                  ? null
                                  : controller.addDessertContribution,
                              icon: Icon(
                                dessertAdded
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.add_rounded,
                              ),
                              label: Text(
                                dessertAdded
                                    ? 'Dessert added'
                                    : 'I can bring dessert',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xl),
                    OutlinedButton.icon(
                      key: const ValueKey('complete-gathering'),
                      onPressed: controller.completeGathering,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark gathering complete'),
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

  PlanReminder? _automaticReminder(FamilyPlan plan) {
    for (final reminder in plan.reminders) {
      if (reminder.isAutomatic) return reminder;
    }
    return null;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          reminder.isAutomatic
              ? Icons.notifications_active_outlined
              : Icons.alarm_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: FamilyCompassSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.isAutomatic
                    ? 'Automatic gathering reminder'
                    : reminder.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: FamilyCompassSpacing.xxs),
              Text('Friday at $time · In-app reminder'),
            ],
          ),
        ),
      ],
    );
  }
}

class _InformationNotice extends StatelessWidget {
  const _InformationNotice({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    super.key,
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
                    ),
              ),
            ),
          ],
        ),
      );
}
