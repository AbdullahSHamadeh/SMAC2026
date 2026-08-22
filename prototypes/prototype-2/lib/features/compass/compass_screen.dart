import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/compass_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';

/// A private, sourced assistant conversation for the current family member.
class CompassScreen extends StatefulWidget {
  const CompassScreen({required this.controller, super.key});

  final PrototypeScenarioController controller;

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late PrototypeScenario _activeScenario;
  String? _displayedQuestion;
  bool _showDadAnswer = false;
  bool _appliedPlanChange = false;

  @override
  void initState() {
    super.initState();
    _activeScenario = widget.controller.state.scenario;
    widget.controller.addListener(_resetConversationForScenario);
  }

  @override
  void didUpdateWidget(covariant CompassScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_resetConversationForScenario);
    _activeScenario = widget.controller.state.scenario;
    widget.controller.addListener(_resetConversationForScenario);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_resetConversationForScenario);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetConversationForScenario() {
    final scenario = widget.controller.state.scenario;
    if (_activeScenario == scenario) return;
    _activeScenario = scenario;
    if (!mounted) return;
    setState(() {
      _displayedQuestion = null;
      _showDadAnswer = false;
      _appliedPlanChange = false;
      _inputController.clear();
    });
  }

  void _askDad({String? visibleQuestion}) {
    final text = (visibleQuestion ?? _inputController.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _displayedQuestion = text;
      _showDadAnswer = true;
    });
    _inputController.clear();
    widget.controller.dispatch(PrototypeIntent.whereIsDad);
    _scrollAfterUpdate();
  }

  void _draftReminder() {
    widget.controller.dispatch(PrototypeIntent.draftSeparateReminder);
    _scrollAfterUpdate();
  }

  void _applyPlanChange() {
    widget.controller.applyPlanChange();
    setState(() => _appliedPlanChange = true);
  }

  void _scrollAfterUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageAtmosphere(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            return Column(
              key: const ValueKey('screen.compass'),
              children: <Widget>[
                const _CompassHeader(),
                if (state.surfaceState == SurfaceState.offlineCached)
                  const _CompassOfflineBanner(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth <
                              FamilyCompassBreakpoints.compactWidth
                          ? FamilyCompassSpacing.md
                          : FamilyCompassSpacing.lg;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: ListView(
                            key: const PageStorageKey<String>(
                                'compass.conversation'),
                            controller: _scrollController,
                            padding: EdgeInsetsDirectional.fromSTEB(
                              horizontalPadding,
                              FamilyCompassSpacing.md,
                              horizontalPadding,
                              FamilyCompassSpacing.lg,
                            ),
                            children: <Widget>[
                              const _PrivateIntroduction(),
                              const SizedBox(height: FamilyCompassSpacing.md),
                              if (_displayedQuestion
                                  case final question?) ...<Widget>[
                                _QuestionBubble(question: question),
                                const SizedBox(height: FamilyCompassSpacing.sm),
                              ],
                              if (_showDadAnswer)
                                _CompassAnswerCard(
                                  answer: widget.controller.answerForDad(),
                                  state: state,
                                  controller: widget.controller,
                                )
                              else
                                _PromptChoices(
                                  state: state,
                                  onAskDad: () => _askDad(
                                    visibleQuestion:
                                        context.l10n.compassExampleQuestion,
                                  ),
                                  onDraftReminder: _draftReminder,
                                ),
                              if (state.hasPendingPlanChange) ...<Widget>[
                                const SizedBox(height: FamilyCompassSpacing.md),
                                _PlanChangeDraftCard(onApply: _applyPlanChange),
                              ],
                              if (_appliedPlanChange) ...<Widget>[
                                const SizedBox(height: FamilyCompassSpacing.md),
                                const _ConfirmationCard(
                                  key: ValueKey('compass.planChange.applied'),
                                  icon: Icons.event_available_outlined,
                                  title: 'Plan changed to 7:30 PM',
                                  body:
                                      'The family plan now uses the reviewed time.',
                                ),
                              ],
                              if (state.separateReminderState ==
                                  SeparateReminderState.drafted) ...<Widget>[
                                const SizedBox(height: FamilyCompassSpacing.md),
                                _ManualReminderDraftCard(
                                    controller: widget.controller),
                              ],
                              if (state.separateReminderState ==
                                  SeparateReminderState.confirmed) ...<Widget>[
                                const SizedBox(height: FamilyCompassSpacing.md),
                                const _ConfirmationCard(
                                  key: ValueKey('compass.reminder.confirmed'),
                                  icon: Icons.alarm_on_outlined,
                                  title: 'Reminder confirmed',
                                  body: 'Buy dessert · Friday at 5:00 PM',
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _CompassComposer(
                  controller: _inputController,
                  enabled: state.aiAvailable &&
                      state.surfaceState != SurfaceState.offlineCached,
                  onSubmit: () => _askDad(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompassHeader extends StatelessWidget {
  const _CompassHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FamilyCompassSpacing.md,
        FamilyCompassSpacing.sm,
        FamilyCompassSpacing.md,
        FamilyCompassSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconWell(
            icon: Icons.auto_awesome_rounded,
            background: colors.secondaryContainer,
            foreground: colors.onSecondaryContainer,
          ),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.compassTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: colors.secondary),
                    const SizedBox(width: FamilyCompassSpacing.xxs),
                    Flexible(
                      child: Text(
                        context.l10n.compassPrivateLabel,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.secondary,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassOfflineBanner extends StatelessWidget {
  const _CompassOfflineBanner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(FamilyCompassSpacing.sm),
      child: StatusBanner(
        icon: Icons.cloud_off_outlined,
        title:
            'Compass needs a connection. Cached family plans remain available.',
        tone: StatusBannerTone.warning,
      ),
    );
  }
}

class _PrivateIntroduction extends StatelessWidget {
  const _PrivateIntroduction();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SoftCard(
      color: colors.secondaryContainer,
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconWell(
            icon: Icons.shield_outlined,
            background: colors.secondary,
            foreground: colors.onSecondary,
          ),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.compassPrivateDescription,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                ),
                const SizedBox(height: FamilyCompassSpacing.xxs),
                Text(
                  context.l10n.compassGroupMentionHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChoices extends StatelessWidget {
  const _PromptChoices({
    required this.state,
    required this.onAskDad,
    required this.onDraftReminder,
  });

  final PrototypeScenarioState state;
  final VoidCallback onAskDad;
  final VoidCallback onDraftReminder;

  @override
  Widget build(BuildContext context) {
    final canDraftReminder = state.aiAvailable &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.separateReminderState == SeparateReminderState.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Ask about shared family information',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FamilyCompassSpacing.sm),
        Wrap(
          spacing: FamilyCompassSpacing.xs,
          runSpacing: FamilyCompassSpacing.xs,
          children: <Widget>[
            ActionChip(
              key: const ValueKey('compass.example.whereIsDad'),
              avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(context.l10n.compassExampleQuestion),
              onPressed: state.aiAvailable ? onAskDad : null,
            ),
            if (canDraftReminder)
              ActionChip(
                key: const ValueKey('compass.example.draftReminder'),
                avatar: const Icon(Icons.alarm_add_outlined, size: 18),
                label: const Text('Remind me to buy dessert Friday at 5:00 PM'),
                onPressed: onDraftReminder,
              ),
          ],
        ),
        if (!state.aiAvailable) ...<Widget>[
          const SizedBox(height: FamilyCompassSpacing.md),
          const _ConfirmationCard(
            icon: Icons.info_outline_rounded,
            title: 'Compass is unavailable right now',
            body: 'Family plans and Chat still work.',
          ),
        ],
      ],
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(FamilyCompassRadii.large),
            topEnd: Radius.circular(FamilyCompassRadii.large),
            bottomStart: Radius.circular(FamilyCompassRadii.large),
            bottomEnd: Radius.circular(FamilyCompassRadii.small),
          ),
        ),
        child: Text(
          question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onPrimary,
              ),
        ),
      ),
    );
  }
}

class _CompassAnswerCard extends StatelessWidget {
  const _CompassAnswerCard({
    required this.answer,
    required this.state,
    required this.controller,
  });

  final CompassAnswer answer;
  final PrototypeScenarioState state;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unknown = !answer.hasPermittedInformation && state.aiAvailable;
    final unavailable = !state.aiAvailable;
    final canDraftPlanChange = answer.hasPermittedInformation &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.plan?.confirmedCandidateId == 'friday-1900';
    final canDraftReminder = state.aiAvailable &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.separateReminderState == SeparateReminderState.none;
    return SoftCard(
      key: const ValueKey('compass.answer'),
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: unknown
                      ? colors.surfaceContainerHighest
                      : colors.secondaryContainer,
                  foregroundColor: unknown
                      ? colors.onSurfaceVariant
                      : colors.onSecondaryContainer,
                  child: Icon(
                    unavailable
                        ? Icons.info_outline_rounded
                        : unknown
                            ? Icons.help_outline_rounded
                            : Icons.shield_outlined,
                  ),
                ),
                const SizedBox(width: FamilyCompassSpacing.sm),
                Expanded(
                  child: Text(
                    unavailable
                        ? 'Compass unavailable'
                        : unknown
                            ? 'No recent update'
                            : 'Answer from shared information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(answer.text, style: Theme.of(context).textTheme.bodyLarge),
            if (answer.sourceLabel.isNotEmpty && !unknown) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              Wrap(
                spacing: FamilyCompassSpacing.xs,
                runSpacing: FamilyCompassSpacing.xs,
                children: <Widget>[
                  Chip(
                    key: const ValueKey('compass.answer.source'),
                    avatar: const Icon(Icons.person_outline_rounded, size: 18),
                    label: Text(answer.sourceLabel),
                  ),
                  if (answer.freshnessLabel.isNotEmpty)
                    Chip(
                      key: const ValueKey('compass.answer.freshness'),
                      avatar: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(answer.freshnessLabel),
                    ),
                ],
              ),
            ],
            if (answer.hasPermittedInformation) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              Wrap(
                spacing: FamilyCompassSpacing.xs,
                runSpacing: FamilyCompassSpacing.xs,
                children: <Widget>[
                  TextButton.icon(
                    key: const ValueKey('compass.why'),
                    onPressed: () => _showWhyThisAnswer(context, answer),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Why this answer?'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('compass.markOutdated'),
                    onPressed: state.dadStatusMarkedOutdated
                        ? null
                        : controller.markDadStatusOutdated,
                    icon: const Icon(Icons.history_toggle_off_outlined),
                    label: Text(
                      state.dadStatusMarkedOutdated
                          ? 'Marked as outdated'
                          : 'Mark as outdated',
                    ),
                  ),
                ],
              ),
              if (canDraftPlanChange &&
                  !state.hasPendingPlanChange) ...<Widget>[
                const SizedBox(height: FamilyCompassSpacing.xs),
                FilledButton.icon(
                  key: const ValueKey('compass.planChange.draft'),
                  onPressed: controller.draftPlanChange,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(answer.actionLabel ?? 'Draft a change to 7:30'),
                ),
              ],
              if (state.dadStatusMarkedOutdated) ...<Widget>[
                const SizedBox(height: FamilyCompassSpacing.xs),
                OutlinedButton.icon(
                  key: const ValueKey('compass.requestCheckIn.afterOutdated'),
                  onPressed: state.checkInState == CheckInState.none
                      ? controller.requestCheckIn
                      : null,
                  icon: const Icon(Icons.mark_chat_unread_outlined),
                  label: Text(
                    state.checkInState == CheckInState.none
                        ? 'Request a check-in'
                        : 'Check-in requested',
                  ),
                ),
              ],
              if (canDraftReminder) ...<Widget>[
                const SizedBox(height: FamilyCompassSpacing.xs),
                OutlinedButton.icon(
                  key: const ValueKey('compass.reminder.draftAction'),
                  onPressed: controller.draftSeparateReminder,
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: const Text('Draft a personal dessert reminder'),
                ),
              ],
            ] else if (state.aiAvailable) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.md),
              FilledButton.icon(
                key: const ValueKey('compass.requestCheckIn'),
                onPressed: state.checkInState == CheckInState.none
                    ? controller.requestCheckIn
                    : null,
                icon: const Icon(Icons.mark_chat_unread_outlined),
                label: Text(
                  state.checkInState == CheckInState.none
                      ? 'Request a check-in'
                      : 'Check-in requested',
                ),
              ),
            ],
          ],
      ),
    );
  }
}

Future<void> _showWhyThisAnswer(
  BuildContext context,
  CompassAnswer answer,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.lg +
              MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          key: const ValueKey('compass.why.sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Why this answer?',
                style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: FamilyCompassSpacing.md),
            _ExplanationRow(
              icon: Icons.person_outline_rounded,
              title: 'Source',
              body: '${answer.sourceLabel}. This was Dad\'s manual update.',
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            const _ExplanationRow(
              icon: Icons.people_outline_rounded,
              title: 'Audience',
              body: 'Dad chose to share this update with Abdullah.',
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            _ExplanationRow(
              icon: Icons.schedule_outlined,
              title: 'Freshness',
              body: 'Updated ${answer.freshnessLabel}.',
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            const _ExplanationRow(
              icon: Icons.location_off_outlined,
              title: 'What was not used',
              body:
                  'This answer did not use a live map or continuous location.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExplanationRow extends StatelessWidget {
  const _ExplanationRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: FamilyCompassSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: FamilyCompassSpacing.xxs),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanChangeDraftCard extends StatelessWidget {
  const _PlanChangeDraftCard({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SoftCard(
      key: const ValueKey('compass.planChange.draftCard'),
      color: colors.secondaryContainer,
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Plan change draft',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              'Friday family dinner: 7:00 PM → 7:30 PM',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              'Review this change before updating the family plan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton(
              key: const ValueKey('compass.planChange.apply'),
              onPressed: onApply,
              child: const Text('Confirm change'),
            ),
          ],
      ),
    );
  }
}

class _ManualReminderDraftCard extends StatelessWidget {
  const _ManualReminderDraftCard({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SoftCard(
      key: const ValueKey('compass.reminder.draft'),
      color: colors.secondaryContainer,
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Personal reminder draft',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              'Buy dessert · Friday at 5:00 PM',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
            const SizedBox(height: FamilyCompassSpacing.xxs),
            Text(
              'This is private and has not been created yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('compass.reminder.confirm'),
              onPressed: controller.confirmSeparateReminder,
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('Confirm reminder'),
            ),
          ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SoftCard(
      color: colors.primaryContainer,
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconWell(
            icon: icon,
            background: colors.primary,
            foreground: colors.onPrimary,
          ),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: FamilyCompassSpacing.xxs),
                Text(body,
                    style: TextStyle(color: colors.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassComposer extends StatelessWidget {
  const _CompassComposer({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: FamilyCompassSemanticColors.of(context).barShadows,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const ValueKey('compass.composer.input'),
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: context.l10n.compassInputHint,
                ),
              ),
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            IconButton.filled(
              key: const ValueKey('compass.composer.send'),
              tooltip: 'Ask Compass',
              onPressed: enabled ? onSubmit : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
