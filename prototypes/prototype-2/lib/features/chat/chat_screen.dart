import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../domain/chat_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/fixtures.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';

/// The shared family conversation.
///
/// Compass content in this screen is intentionally compact and explicitly
/// family-visible. Private sourced answers belong in the private Compass tab.
class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.controller, super.key});

  final PrototypeScenarioController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _composerController;
  late PrototypeScenario _activeScenario;
  final ScrollController _scrollController = ScrollController();
  final List<String> _prototypeOnlySentMessages = <String>[];

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController(
      text: widget.controller.state.ui.chatDraft,
    )..addListener(_saveDraft);
    _activeScenario = widget.controller.state.scenario;
    widget.controller.addListener(_syncControllerState);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncControllerState);
    _composerController.removeListener(_saveDraft);
    _composerController.text = widget.controller.state.ui.chatDraft;
    _composerController.addListener(_saveDraft);
    _activeScenario = widget.controller.state.scenario;
    widget.controller.addListener(_syncControllerState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerState);
    _composerController
      ..removeListener(_saveDraft)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    final value = _composerController.text;
    if (value != widget.controller.state.ui.chatDraft) {
      widget.controller.updateChatDraft(value);
    }
  }

  void _syncControllerState() {
    final state = widget.controller.state;
    if (_composerController.text != state.ui.chatDraft) {
      _composerController.value = TextEditingValue(
        text: state.ui.chatDraft,
        selection: TextSelection.collapsed(offset: state.ui.chatDraft.length),
      );
    }
    if (_activeScenario == state.scenario) return;
    _activeScenario = state.scenario;
    if (!mounted) return;
    setState(_prototypeOnlySentMessages.clear);
  }

  void _sendHumanMessage() {
    final message = _composerController.text.trim();
    if (message.isEmpty) return;
    setState(() => _prototypeOnlySentMessages.add(message));
    _composerController.clear();
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
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            return Column(
              key: const ValueKey('screen.chat'),
              children: <Widget>[
                _ChatHeader(
                    isOffline:
                        state.surfaceState == SurfaceState.offlineCached),
                if (state.surfaceState == SurfaceState.offlineCached)
                  _OfflineBanner(controller: widget.controller),
                if (!state.aiAvailable) const _AiUnavailableBanner(),
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
                            key: const PageStorageKey<String>('chat.messages'),
                            controller: _scrollController,
                            padding: EdgeInsetsDirectional.fromSTEB(
                              horizontalPadding,
                              FamilyCompassSpacing.md,
                              horizontalPadding,
                              FamilyCompassSpacing.lg,
                            ),
                            children: <Widget>[
                              for (final item in state.chatItems) ...<Widget>[
                                _ChatItemView(
                                  item: item,
                                  state: state,
                                  controller: widget.controller,
                                ),
                                const SizedBox(height: FamilyCompassSpacing.sm),
                              ],
                              if (state.plan?.phase == PlanPhase.opportunity)
                                _DinnerOpportunityCard(
                                  controller: widget.controller,
                                ),
                              if (_needsDerivedPollCard(state)) ...<Widget>[
                                _PollCard(
                                  key: ValueKey(
                                    'plan.${state.plan!.id}.poll',
                                  ),
                                  plan: state.plan,
                                  controller: widget.controller,
                                ),
                                const SizedBox(
                                  height: FamilyCompassSpacing.sm,
                                ),
                              ],
                              if (_needsDerivedConfirmationCard(state))
                                _ConfirmedPlanCard(
                                  key: ValueKey(
                                    'plan.${state.plan!.id}.confirmed',
                                  ),
                                  plan: state.plan,
                                  controller: widget.controller,
                                ),
                              for (final message in _prototypeOnlySentMessages)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: FamilyCompassSpacing.sm,
                                  ),
                                  child: _HumanMessageBubble(
                                    author: 'Abdullah',
                                    text: message,
                                    isMine: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _ChatComposer(
                  controller: _composerController,
                  canSend: state.ui.chatDraft.trim().isNotEmpty,
                  showCompassShortcut: state.aiAvailable &&
                      state.plan?.phase == PlanPhase.opportunity,
                  onCompassPressed: widget.controller.draftFridayDinner,
                  onSend: _sendHumanMessage,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.isOffline});

  final bool isOffline;

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
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: const Icon(Icons.family_restroom_rounded),
          ),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.tabChat,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  isOffline
                      ? 'Cached family conversation'
                      : 'The Hamadeh family',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Semantics(
            label: '4 family members',
            child: Icon(
              Icons.group_outlined,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, color: colors.onTertiaryContainer),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Text(
                'Offline. Showing the conversation saved at 6:00 PM.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
              ),
            ),
            TextButton(
              key: const ValueKey('chat.offline.retry'),
              onPressed: state.isRetrying ? null : controller.retryOffline,
              child: Text(state.isRetrying ? 'Retrying…' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiUnavailableBanner extends StatelessWidget {
  const _AiUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(FamilyCompassSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.auto_awesome_outlined),
            SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Text(
                'Compass is unavailable. Family messages and plans still work.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItemView extends StatelessWidget {
  const _ChatItemView({
    required this.item,
    required this.state,
    required this.controller,
  });

  final ChatItem item;
  final PrototypeScenarioState state;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    return switch (item.kind) {
      ChatItemKind.message => _HumanMessageBubble(
          key: ValueKey('chat.message.${item.id}'),
          author: memberById(item.authorId).name,
          text: item.text,
          isMine: item.authorId == 'abdullah',
        ),
      ChatItemKind.compassDraft => _CompassDraftCard(
          key: const ValueKey('chat.compassDraft.fridayDinner'),
          item: item,
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.poll => _PollCard(
          key: ValueKey('plan.${item.referenceId ?? 'friday-dinner'}.poll'),
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.confirmedPlan => _ConfirmedPlanCard(
          key:
              ValueKey('plan.${item.referenceId ?? 'friday-dinner'}.confirmed'),
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.checkInRequest => _SystemRecordCard(
          key: const ValueKey('chat.checkIn.requested'),
          icon: Icons.mark_chat_unread_outlined,
          label: 'Check-in requested',
          text: item.text,
        ),
      ChatItemKind.checkInResponse => _SystemRecordCard(
          key: const ValueKey('chat.checkIn.responded'),
          icon: Icons.check_circle_outline_rounded,
          label: 'Sara replied',
          text: item.text,
        ),
      ChatItemKind.reminderDraft => _ReminderDraftCard(
          key: const ValueKey('chat.reminder.draft'),
          text: item.text,
          controller: controller,
        ),
      ChatItemKind.reminderConfirmed => _SystemRecordCard(
          key: const ValueKey('chat.reminder.confirmed'),
          icon: Icons.alarm_on_outlined,
          label: 'Personal reminder',
          text: item.text,
        ),
    };
  }
}

class _HumanMessageBubble extends StatelessWidget {
  const _HumanMessageBubble({
    required this.author,
    required this.text,
    required this.isMine,
    super.key,
  });

  final String author;
  final String text;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: FamilyCompassSpacing.xs,
                end: FamilyCompassSpacing.xs,
                bottom: FamilyCompassSpacing.xxs,
              ),
              child:
                  Text(author, style: Theme.of(context).textTheme.labelSmall),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isMine ? colors.primary : colors.surface,
                border:
                    isMine ? null : Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(FamilyCompassRadii.large),
                  topEnd: const Radius.circular(FamilyCompassRadii.large),
                  bottomStart: Radius.circular(
                    isMine
                        ? FamilyCompassRadii.large
                        : FamilyCompassRadii.small,
                  ),
                  bottomEnd: Radius.circular(
                    isMine
                        ? FamilyCompassRadii.small
                        : FamilyCompassRadii.large,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FamilyCompassSpacing.md,
                  vertical: FamilyCompassSpacing.sm,
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isMine ? colors.onPrimary : colors.onSurface,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DinnerOpportunityCard extends StatelessWidget {
  const _DinnerOpportunityCard({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('chat.compassOpportunity.fridayDinner'),
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardLabel(
              icon: Icons.auto_awesome_rounded,
              text: '@Compass suggestion · Family visible',
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              'Turn this conversation into a simple dinner poll?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('chat.turnIntoPlan'),
              onPressed: controller.draftFridayDinner,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Turn into a plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDraftCard extends StatelessWidget {
  const _CompassDraftCard({
    required this.item,
    required this.plan,
    required this.controller,
    super.key,
  });

  final ChatItem item;
  final FamilyPlan? plan;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canReview = plan?.phase == PlanPhase.draft;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardLabel(
              icon: Icons.auto_awesome_rounded,
              text: '@Compass draft · Family visible',
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              item.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              canReview
                  ? 'Nothing has been sent yet.'
                  : 'This draft became the family poll below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            if (canReview) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              FilledButton(
                key: const ValueKey('chat.reviewPlan'),
                onPressed: () => _showPlanReview(context, plan!, controller),
                child: const Text('Review plan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showPlanReview(
  BuildContext context,
  FamilyPlan plan,
  PrototypeScenarioController controller,
) {
  final material = MaterialLocalizations.of(context);
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
          key: const ValueKey('chat.planReview'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Review family plan',
                style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: FamilyCompassSpacing.xs),
            const Text(
                'Compass prepared this draft. You decide whether to send it.'),
            const SizedBox(height: FamilyCompassSpacing.lg),
            Text(plan.title,
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(plan.description),
            const SizedBox(height: FamilyCompassSpacing.md),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.people_outline_rounded),
              title: Text('Abdullah, Dad, Mom, and Sara'),
              subtitle: Text('Selected adult participants'),
            ),
            for (final candidate in plan.candidateTimes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_formatCandidate(material, candidate)),
              ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('chat.sendPoll'),
              onPressed: () {
                controller.sendPoll();
                Navigator.of(sheetContext).pop();
              },
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('Send poll'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.plan, required this.controller, super.key});

  final FamilyPlan? plan;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    if (currentPlan == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final material = MaterialLocalizations.of(context);
    final hasResponded = currentPlan.responses.containsKey('abdullah');
    final isOpen = currentPlan.phase == PlanPhase.pollOpen ||
        currentPlan.phase == PlanPhase.readyToConfirm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardLabel(
              icon: Icons.how_to_vote_outlined,
              text: isOpen ? 'Family poll' : 'Poll closed',
              color: colors.primary,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              context.l10n.pollDinnerQuestion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            for (final candidate in currentPlan.candidateTimes)
              Padding(
                padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.schedule_outlined,
                        color: colors.onSurfaceVariant),
                    const SizedBox(width: FamilyCompassSpacing.sm),
                    Expanded(
                        child: Text(_formatCandidate(material, candidate))),
                  ],
                ),
              ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              context.l10n.pollResponsesCount(currentPlan.responses.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            if (isOpen && !hasResponded) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.md),
              FilledButton.icon(
                key: const ValueKey('poll.fridayDinner.respond1930'),
                onPressed: controller.submitAbdullahResponse,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Going at 7:30 PM'),
              ),
            ],
            if (isOpen && hasResponded) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              const _InlineStatus(
                icon: Icons.check_circle_outline_rounded,
                text: 'You replied: Going at 7:30 PM',
              ),
              const SizedBox(height: FamilyCompassSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('poll.fridayDinner.nudge'),
                onPressed:
                    currentPlan.nudgeSent ? null : controller.sendPollNudge,
                icon: const Icon(Icons.notifications_active_outlined),
                label:
                    Text(currentPlan.nudgeSent ? 'Nudge sent' : 'Nudge Sara'),
              ),
            ],
            if (currentPlan.phase == PlanPhase.readyToConfirm) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('poll.fridayDinner.confirm1930'),
                onPressed: controller.confirmDinner,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Confirm Friday at 7:30 PM'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmedPlanCard extends StatelessWidget {
  const _ConfirmedPlanCard(
      {required this.plan, required this.controller, super.key});

  final FamilyPlan? plan;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reminderState = controller.state.separateReminderState;
    final confirmedTime = plan?.confirmedTime;
    final timeLabel = confirmedTime == null
        ? 'Time pending'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(confirmedTime.startsAt),
          );
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardLabel(
              icon: Icons.check_circle_rounded,
              text: 'Confirmed family plan',
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              'Friday dinner · $timeLabel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
            ),
            if (plan?.reminders.isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.xs),
              Text(
                'Automatic reminder: ${plan!.reminders.first.label}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
              ),
            ],
            if (reminderState == SeparateReminderState.none) ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.sm),
              TextButton.icon(
                key: const ValueKey('chat.reminder.draftAction'),
                onPressed: controller.draftSeparateReminder,
                icon: const Icon(Icons.alarm_add_outlined),
                label: const Text('Draft a personal dessert reminder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderDraftCard extends StatelessWidget {
  const _ReminderDraftCard(
      {required this.text, required this.controller, super.key});

  final String text;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardLabel(
              icon: Icons.alarm_add_outlined,
              text: '@Compass reminder draft · Only you',
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(text),
            const SizedBox(height: FamilyCompassSpacing.xs),
            const Text('This reminder has not been created yet.'),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton(
              key: const ValueKey('chat.reminder.confirm'),
              onPressed: controller.confirmSeparateReminder,
              child: const Text('Confirm reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemRecordCard extends StatelessWidget {
  const _SystemRecordCard({
    required this.icon,
    required this.label,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FamilyCompassSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.primary),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: FamilyCompassSpacing.xxs),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(
      {required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(
          child: Text(
            text,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.canSend,
    required this.showCompassShortcut,
    required this.onCompassPressed,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool showCompassShortcut;
  final VoidCallback onCompassPressed;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showCompassShortcut)
              Padding(
                padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.xs),
                child: ActionChip(
                  key: const ValueKey('chat.composer.compassShortcut'),
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('@Compass · Plan Friday dinner'),
                  onPressed: onCompassPressed,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat.composer.input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Message your family',
                    ),
                  ),
                ),
                const SizedBox(width: FamilyCompassSpacing.xs),
                IconButton.filled(
                  key: const ValueKey('chat.composer.send'),
                  tooltip: 'Send message',
                  onPressed: canSend ? onSend : null,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCandidate(
  MaterialLocalizations material,
  CandidateTime candidate,
) {
  final date = material.formatMediumDate(candidate.startsAt);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(candidate.startsAt),
  );
  return '$date · $time';
}

bool _needsDerivedPollCard(PrototypeScenarioState state) {
  final phase = state.plan?.phase;
  if (phase != PlanPhase.pollOpen && phase != PlanPhase.readyToConfirm) {
    return false;
  }
  return !state.chatItems.any((item) => item.kind == ChatItemKind.poll);
}

bool _needsDerivedConfirmationCard(PrototypeScenarioState state) {
  if (state.plan?.phase != PlanPhase.confirmed) return false;
  return !state.chatItems.any(
    (item) => item.kind == ChatItemKind.confirmedPlan,
  );
}
