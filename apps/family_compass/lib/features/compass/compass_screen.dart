import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../data/family_compass_repositories.dart';
import '../../data/http_compass_repository.dart';
import '../../domain/compass_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
import '../../widgets/prototype_widgets.dart';

/// A private, sourced assistant conversation for the current family member.
class CompassScreen extends StatefulWidget {
  const CompassScreen({required this.controller, this.repository, super.key});

  final PrototypeScenarioController controller;
  final CompassRepository? repository;

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _answerAnchorKey = GlobalKey();
  late PrototypeScenario _activeScenario;
  String? _displayedQuestion;
  bool _showAnswer = false;
  bool _questionTargetsDad = true;
  bool _appliedPlanChange = false;
  bool _isLoading = false;
  CompassAnswer? _remoteAnswer;
  String? _answerError;

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
      _showAnswer = false;
      _questionTargetsDad = true;
      _appliedPlanChange = false;
      _isLoading = false;
      _remoteAnswer = null;
      _answerError = null;
      _inputController.clear();
    });
  }

  Future<void> _askCompass({String? visibleQuestion}) async {
    final text = (visibleQuestion ?? _inputController.text).trim();
    if (text.isEmpty) return;
    final targetsDad = _looksLikeDadQuestion(text);
    setState(() {
      _displayedQuestion = text;
      _showAnswer = true;
      _questionTargetsDad = targetsDad;
      _remoteAnswer = null;
      _answerError = null;
      _isLoading = widget.repository != null;
    });
    _inputController.clear();
    if (widget.repository == null) {
      if (targetsDad) {
        widget.controller.dispatch(PrototypeIntent.whereIsDad);
      }
      _revealAnswerAfterUpdate();
      return;
    }

    try {
      final answer = await widget.repository!.ask(
        conversationId: '77777777-7777-7777-7777-777777777777',
        question: text,
      );
      if (!mounted) return;
      setState(() => _remoteAnswer = answer);
    } on CompassConnectionException catch (error) {
      if (!mounted) return;
      setState(() => _answerError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _answerError =
            'Compass could not answer right now. Nothing was sent or changed.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (targetsDad && _remoteAnswer?.hasPermittedInformation == true) {
      widget.controller.dispatch(PrototypeIntent.whereIsDad);
    }
    _revealAnswerAfterUpdate();
  }

  void _retryQuestion() {
    final question = _displayedQuestion;
    if (question != null) _askCompass(visibleQuestion: question);
  }

  void _draftReminder() {
    widget.controller.dispatch(PrototypeIntent.draftSeparateReminder);
    _scrollAfterUpdate();
  }

  void _applyPlanChange() {
    widget.controller.applyPlanChange();
    setState(() => _appliedPlanChange = true);
  }

  Future<void> _runCompassAction(CompassAction action) async {
    if (action.requiresConfirmation) {
      final copy = _CompassCopy.of(context);
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(copy.confirmActionTitle),
              content: Text(copy.confirmActionBody(action)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(copy.confirm),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }
    switch (action.kind) {
      case CompassActionKind.openPlan:
        final targetId = action.targetId;
        if (targetId != null) widget.controller.openFamilyPlan(targetId);
      case CompassActionKind.startPlan:
        widget.controller.startFamilyPlan();
      case CompassActionKind.requestCheckIn:
        final targetId = action.targetId;
        if (targetId != null) widget.controller.requestCheckInFor(targetId);
      case CompassActionKind.createReminder:
        // The current action schema has no reminder time or editable draft.
        // Unsupported live actions are filtered before reaching this handler.
        return;
    }
  }

  void _scrollAfterUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _revealAnswerAfterUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final answerContext = _answerAnchorKey.currentContext;
      if (answerContext == null) return;
      Scrollable.ensureVisible(
        answerContext,
        alignment: 0.08,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
            final fallbackAnswer = widget.repository == null && _showAnswer
                ? _questionTargetsDad || !state.aiAvailable
                    ? widget.controller.answerForDad()
                    : const CompassAnswer(
                        text:
                            'No permitted source is available for that question.',
                        sourceLabel: 'No permitted source',
                        freshnessLabel: '',
                        hasPermittedInformation: false,
                      )
                : null;
            final answer = _remoteAnswer ?? fallbackAnswer;
            return Column(
              key: const ValueKey('screen.compass'),
              children: <Widget>[
                if (state.surfaceState == SurfaceState.offlineCached)
                  const _CompassOfflineBanner(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactHeight = constraints.maxHeight <
                          FamilyCompassBreakpoints.compactHeight;
                      final showSupportingPane = constraints.maxWidth >=
                              FamilyCompassBreakpoints.mediumWidth &&
                          !compactHeight;
                      final conversation = _CompassConversation(
                        state: state,
                        answer: answer,
                        displayedQuestion: _displayedQuestion,
                        appliedPlanChange: _appliedPlanChange,
                        compactHeight: compactHeight,
                        controller: widget.controller,
                        scrollController: _scrollController,
                        answerAnchorKey: _answerAnchorKey,
                        inputController: _inputController,
                        isLoading: _isLoading,
                        answerError: _answerError,
                        usesLiveProvider: widget.repository != null,
                        unsupportedQuestion: _showAnswer &&
                            !_questionTargetsDad &&
                            answer?.isGeneralKnowledge != true,
                        onAskDad: () => _askCompass(
                          visibleQuestion: context.l10n.compassExampleQuestion,
                        ),
                        onSubmit: () => _askCompass(),
                        onRetry: _retryQuestion,
                        onDraftReminder: _draftReminder,
                        onApplyPlanChange: _applyPlanChange,
                        onAction: _runCompassAction,
                      );

                      if (!showSupportingPane) return conversation;
                      return Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: FamilyCompassSizes.maximumContentWidth,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(flex: 7, child: conversation),
                              VerticalDivider(
                                width: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                              SizedBox(
                                width: constraints.maxWidth >= 1100 ? 344 : 296,
                                child: _SourcePrivacyPane(
                                  answer: answer,
                                  state: state,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _CompassConversation extends StatelessWidget {
  const _CompassConversation({
    required this.state,
    required this.answer,
    required this.displayedQuestion,
    required this.appliedPlanChange,
    required this.compactHeight,
    required this.controller,
    required this.scrollController,
    required this.answerAnchorKey,
    required this.inputController,
    required this.isLoading,
    required this.answerError,
    required this.usesLiveProvider,
    required this.unsupportedQuestion,
    required this.onAskDad,
    required this.onSubmit,
    required this.onRetry,
    required this.onDraftReminder,
    required this.onApplyPlanChange,
    required this.onAction,
  });

  final PrototypeScenarioState state;
  final CompassAnswer? answer;
  final String? displayedQuestion;
  final bool appliedPlanChange;
  final bool compactHeight;
  final PrototypeScenarioController controller;
  final ScrollController scrollController;
  final GlobalKey answerAnchorKey;
  final TextEditingController inputController;
  final bool isLoading;
  final String? answerError;
  final bool usesLiveProvider;
  final bool unsupportedQuestion;
  final VoidCallback onAskDad;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onDraftReminder;
  final VoidCallback onApplyPlanChange;
  final ValueChanged<CompassAction> onAction;

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    final enabled = state.aiAvailable &&
        state.surfaceState != SurfaceState.offlineCached &&
        !isLoading;
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth < FamilyCompassBreakpoints.compactWidth
                      ? FamilyCompassSpacing.md
                      : FamilyCompassSpacing.lg;
              final useLandscapeStart = compactHeight &&
                  answer == null &&
                  displayedQuestion == null &&
                  constraints.maxWidth >= FamilyCompassBreakpoints.compactWidth;

              final start = useLandscapeStart
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Expanded(
                          child: _PrivateIntroduction(compact: true),
                        ),
                        const SizedBox(width: FamilyCompassSpacing.lg),
                        Expanded(
                          child: _PromptChoices(
                            state: state,
                            compact: true,
                            onAskDad: onAskDad,
                            onDraftReminder: onDraftReminder,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _PrivateIntroduction(compact: compactHeight),
                        SizedBox(
                          height: compactHeight
                              ? FamilyCompassSpacing.xs
                              : FamilyCompassSpacing.md,
                        ),
                        if (displayedQuestion case final question?) ...<Widget>[
                          _QuestionBubble(question: question),
                          const SizedBox(height: FamilyCompassSpacing.sm),
                        ],
                        if (isLoading)
                          const _CompassLoadingAnswer()
                        else if (answerError case final message?)
                          _CompassAnswerError(
                            message: message,
                            onRetry: onRetry,
                          )
                        else if (answer case final currentAnswer?)
                          KeyedSubtree(
                            key: answerAnchorKey,
                            child: _CompassAnswerLedger(
                              answer: currentAnswer,
                              state: state,
                              controller: controller,
                              compact: compactHeight,
                              unsupportedQuestion: unsupportedQuestion,
                              usesLiveProvider: usesLiveProvider,
                              onAction: onAction,
                            ),
                          )
                        else
                          _PromptChoices(
                            state: state,
                            compact: compactHeight,
                            onAskDad: onAskDad,
                            onDraftReminder: onDraftReminder,
                          ),
                      ],
                    );

              return Align(
                alignment: AlignmentDirectional.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    key: const PageStorageKey<String>(
                      'compass.conversation',
                    ),
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding,
                      compactHeight
                          ? FamilyCompassSpacing.xs
                          : FamilyCompassSpacing.md,
                      horizontalPadding,
                      compactHeight
                          ? FamilyCompassSpacing.sm
                          : FamilyCompassSpacing.lg,
                    ),
                    children: <Widget>[
                      start,
                      if (state.hasPendingPlanChange) ...<Widget>[
                        const SizedBox(height: FamilyCompassSpacing.md),
                        _PlanChangeDraftCard(onApply: onApplyPlanChange),
                      ],
                      if (appliedPlanChange) ...<Widget>[
                        const SizedBox(height: FamilyCompassSpacing.md),
                        _ConfirmationCard(
                          key: const ValueKey('compass.planChange.applied'),
                          icon: FamilyCompassIcons.eventAvailableOutlined,
                          title: copy.planChangedTitle,
                          body: copy.planChangedBody,
                        ),
                      ],
                      if (state.separateReminderState ==
                          SeparateReminderState.drafted) ...<Widget>[
                        const SizedBox(height: FamilyCompassSpacing.md),
                        _ManualReminderDraftCard(controller: controller),
                      ],
                      if (state.separateReminderState ==
                          SeparateReminderState.confirmed) ...<Widget>[
                        const SizedBox(height: FamilyCompassSpacing.md),
                        _ConfirmationCard(
                          key: const ValueKey('compass.reminder.confirmed'),
                          icon: FamilyCompassIcons.alarmOnOutlined,
                          title: copy.reminderConfirmedTitle,
                          body: copy.dessertFridayFive,
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
          controller: inputController,
          enabled: enabled,
          compact: compactHeight,
          allowsGeneralQuestions: usesLiveProvider,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _CompassOfflineBanner extends StatelessWidget {
  const _CompassOfflineBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = _CompassCopy.of(context);
    return Material(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              FamilyCompassIcons.cloudOffOutlined,
              color: colors.onTertiaryContainer,
            ),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Text(
                copy.offlineBanner,
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateIntroduction extends StatelessWidget {
  const _PrivateIntroduction({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label:
          '${context.l10n.compassPrivateDescription} ${context.l10n.compassGroupMentionHint}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            vertical: compact ? FamilyCompassSpacing.xxs : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  FamilyCompassIcons.lockPersonOutlined,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.compassPrivateDescription,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: FamilyCompassSpacing.xxs),
                    Text(
                      context.l10n.compassGroupMentionHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptChoices extends StatelessWidget {
  const _PromptChoices({
    required this.state,
    required this.compact,
    required this.onAskDad,
    required this.onDraftReminder,
  });

  final PrototypeScenarioState state;
  final bool compact;
  final VoidCallback onAskDad;
  final VoidCallback onDraftReminder;

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    final canUseCompass =
        state.aiAvailable && state.surfaceState != SurfaceState.offlineCached;
    final canDraftReminder = canUseCompass &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.separateReminderState == SeparateReminderState.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.askSharedInformation,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(
          height: compact ? FamilyCompassSpacing.xxs : FamilyCompassSpacing.xs,
        ),
        _PromptRow(
          key: const ValueKey('compass.example.whereIsDad'),
          icon: FamilyCompassIcons.chatBubbleOutlineRounded,
          label: context.l10n.compassExampleQuestion,
          onPressed: canUseCompass ? onAskDad : null,
        ),
        if (canDraftReminder)
          _PromptRow(
            key: const ValueKey('compass.example.draftReminder'),
            icon: FamilyCompassIcons.alarmAddOutlined,
            label: copy.reminderPrompt,
            onPressed: onDraftReminder,
          ),
        if (!state.aiAvailable) ...<Widget>[
          const SizedBox(height: FamilyCompassSpacing.sm),
          _ConfirmationCard(
            icon: FamilyCompassIcons.infoOutlineRounded,
            title: copy.unavailableNow,
            body: copy.familyPlansAndChatWork,
          ),
        ],
      ],
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: FamilyCompassSizes.minimumTouchTarget,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: FamilyCompassSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(icon, size: 21, color: colors.primary),
                      const SizedBox(width: FamilyCompassSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: FamilyCompassSpacing.xs),
                      Icon(
                        FamilyCompassIcons.arrowForwardRounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassLoadingAnswer extends StatelessWidget {
  const _CompassLoadingAnswer();

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    return Semantics(
      key: const ValueKey('compass.answer.loading'),
      liveRegion: true,
      label: copy.thinking,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: FamilyCompassSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Text(copy.thinking),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassAnswerError extends StatelessWidget {
  const _CompassAnswerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('compass.answer.error'),
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: FamilyCompassSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
            bottom: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(copy.answerFailed,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: FamilyCompassSpacing.xs),
            _BidiText(message),
            const SizedBox(height: FamilyCompassSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('compass.answer.retry'),
              onPressed: onRetry,
              icon: const Icon(FamilyCompassIcons.refreshRounded),
              label: Text(copy.tryAgain),
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              copy.errorNoAction,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: FamilyCompassSpacing.md,
          vertical: FamilyCompassSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(FamilyCompassRadii.medium),
            topEnd: Radius.circular(FamilyCompassRadii.medium),
            bottomStart: Radius.circular(FamilyCompassRadii.medium),
            bottomEnd: Radius.circular(FamilyCompassRadii.small),
          ),
        ),
        child: _BidiText(
          question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onPrimary,
              ),
        ),
      ),
    );
  }
}

class _CompassAnswerLedger extends StatelessWidget {
  const _CompassAnswerLedger({
    required this.answer,
    required this.state,
    required this.controller,
    required this.compact,
    required this.unsupportedQuestion,
    required this.usesLiveProvider,
    required this.onAction,
  });

  final CompassAnswer answer;
  final PrototypeScenarioState state;
  final PrototypeScenarioController controller;
  final bool compact;
  final bool unsupportedQuestion;
  final bool usesLiveProvider;
  final ValueChanged<CompassAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = _CompassCopy.of(context);
    final general = answer.isGeneralKnowledge;
    final unknown =
        !answer.hasPermittedInformation && !general && state.aiAvailable;
    final unavailable = !state.aiAvailable;
    final canDraftPlanChange = answer.hasPermittedInformation &&
        !general &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.plan?.confirmedCandidateId == 'friday-1900';
    final canDraftReminder = state.aiAvailable &&
        state.plan?.phase == PlanPhase.confirmed &&
        state.separateReminderState == SeparateReminderState.none;
    final title = unavailable
        ? copy.unavailableTitle
        : general
            ? copy.generalAnswerTitle
            : unknown
                ? unsupportedQuestion
                    ? copy.noPermittedAnswer
                    : copy.noRecentUpdate
                : copy.groundedTitle;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        key: const ValueKey('compass.answer'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(color: colors.outlineVariant),
          Row(
            children: <Widget>[
              Icon(
                unavailable
                    ? FamilyCompassIcons.cloudOffOutlined
                    : unknown
                        ? FamilyCompassIcons.infoOutlineRounded
                        : FamilyCompassIcons.chatOutlined,
                size: 20,
                color: unknown || unavailable
                    ? colors.onSurfaceVariant
                    : colors.primary,
              ),
              const SizedBox(width: FamilyCompassSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                context.l10n.compassPrivateLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          SizedBox(
            height: compact ? FamilyCompassSpacing.sm : FamilyCompassSpacing.md,
          ),
          _BidiText(
            copy.answerText(answer),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
          ),
          SizedBox(
            height: compact ? FamilyCompassSpacing.sm : FamilyCompassSpacing.md,
          ),
          _AnswerEvidence(
            answer: answer,
            unknown: unknown,
            unavailable: unavailable,
            general: general,
            compact: compact,
          ),
          if (answer.hasPermittedInformation &&
              !general &&
              !usesLiveProvider) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.xs),
            _AnswerActionRow(
              label: copy.whyLabel,
              body: copy.whyBody,
              action: TextButton.icon(
                key: const ValueKey('compass.why'),
                onPressed: () => _showWhyThisAnswer(context, answer),
                icon: const Icon(FamilyCompassIcons.infoOutlineRounded),
                label: Text(copy.whyButton),
              ),
            ),
            _AnswerActionRow(
              label: copy.correction,
              body: copy.correctionBody,
              action: TextButton.icon(
                key: const ValueKey('compass.markOutdated'),
                onPressed: state.dadStatusMarkedOutdated
                    ? null
                    : controller.markDadStatusOutdated,
                icon: const Icon(FamilyCompassIcons.historyToggleOffOutlined),
                label: Text(
                  state.dadStatusMarkedOutdated
                      ? copy.markedOutdated
                      : copy.markOutdated,
                ),
              ),
            ),
          ] else if (!general && !usesLiveProvider) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.xs),
            _AnswerStatementRow(
              label: copy.correction,
              body: copy.nothingToCorrect,
            ),
          ],
          if (!usesLiveProvider &&
              answer.hasPermittedInformation &&
              !general &&
              ((canDraftPlanChange && !state.hasPendingPlanChange) ||
                  state.dadStatusMarkedOutdated ||
                  canDraftReminder)) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(copy.nextStep, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Wrap(
              spacing: FamilyCompassSpacing.xs,
              runSpacing: FamilyCompassSpacing.xs,
              children: <Widget>[
                if (canDraftPlanChange && !state.hasPendingPlanChange)
                  FilledButton.icon(
                    key: const ValueKey('compass.planChange.draft'),
                    onPressed: controller.draftPlanChange,
                    icon: const Icon(FamilyCompassIcons.editCalendarOutlined),
                    label: Text(copy.actionLabel(answer.actionLabel)),
                  ),
                if (state.dadStatusMarkedOutdated)
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'compass.requestCheckIn.afterOutdated',
                    ),
                    onPressed: state.checkInState == CheckInState.none
                        ? controller.requestCheckIn
                        : null,
                    icon: const Icon(FamilyCompassIcons.markChatUnreadOutlined),
                    label: Text(
                      state.checkInState == CheckInState.none
                          ? copy.requestCheckIn
                          : copy.checkInRequested,
                    ),
                  ),
                if (canDraftReminder)
                  OutlinedButton.icon(
                    key: const ValueKey('compass.reminder.draftAction'),
                    onPressed: controller.draftSeparateReminder,
                    icon: const Icon(FamilyCompassIcons.alarmAddOutlined),
                    label: Text(copy.draftDessertReminder),
                  ),
              ],
            ),
          ] else if (usesLiveProvider && answer.actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            _LiveCompassActions(
              actions: answer.actions,
              onAction: onAction,
            ),
          ] else if (general) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            _AnswerStatementRow(
              label: copy.nextStep,
              body: copy.generalAnswerNextStep,
              topDivider: false,
            ),
          ] else if (unknown && !unsupportedQuestion) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(copy.nextStep, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: FamilyCompassSpacing.xs),
            FilledButton.icon(
              key: const ValueKey('compass.requestCheckIn'),
              onPressed: state.checkInState == CheckInState.none
                  ? controller.requestCheckIn
                  : null,
              icon: const Icon(FamilyCompassIcons.markChatUnreadOutlined),
              label: Text(
                state.checkInState == CheckInState.none
                    ? copy.requestCheckIn
                    : copy.checkInRequested,
              ),
            ),
          ] else if (unknown) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            _AnswerStatementRow(
              label: copy.nextStep,
              body: copy.unsupportedQuestionNextStep,
              topDivider: false,
            ),
          ] else if (answer.hasPermittedInformation) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            _AnswerStatementRow(
              label: copy.nextStep,
              body: copy.noFollowUp,
              topDivider: false,
            ),
          ] else if (unavailable) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            _AnswerStatementRow(
              label: copy.nextStep,
              body: copy.reconnectNextStep,
              topDivider: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveCompassActions extends StatelessWidget {
  const _LiveCompassActions({required this.actions, required this.onAction});

  final List<CompassAction> actions;
  final ValueChanged<CompassAction> onAction;

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    final supported = actions.where((action) {
      return switch (action.kind) {
        CompassActionKind.openPlan ||
        CompassActionKind.requestCheckIn =>
          action.targetId != null,
        CompassActionKind.startPlan => true,
        CompassActionKind.createReminder => false,
      };
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.nextStep, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: FamilyCompassSpacing.xs),
        if (supported.isEmpty)
          _AnswerStatementRow(
            label: copy.actionNeedsDetailsTitle,
            body: copy.actionNeedsDetailsBody,
            topDivider: false,
          )
        else
          Wrap(
            spacing: FamilyCompassSpacing.xs,
            runSpacing: FamilyCompassSpacing.xs,
            children: <Widget>[
              for (final action in supported)
                if (action.requiresConfirmation)
                  FilledButton.icon(
                    key: ValueKey('compass.liveAction.${action.kind.name}'),
                    onPressed: () => onAction(action),
                    icon: Icon(_compassActionIcon(action.kind)),
                    label: Text(copy.liveActionLabel(action)),
                  )
                else
                  OutlinedButton.icon(
                    key: ValueKey('compass.liveAction.${action.kind.name}'),
                    onPressed: () => onAction(action),
                    icon: Icon(_compassActionIcon(action.kind)),
                    label: Text(copy.liveActionLabel(action)),
                  ),
            ],
          ),
      ],
    );
  }
}

IconData _compassActionIcon(CompassActionKind kind) => switch (kind) {
      CompassActionKind.openPlan => FamilyCompassIcons.eventNoteOutlined,
      CompassActionKind.startPlan => FamilyCompassIcons.editCalendarOutlined,
      CompassActionKind.requestCheckIn =>
        FamilyCompassIcons.markChatUnreadOutlined,
      CompassActionKind.createReminder => FamilyCompassIcons.alarmAddOutlined,
    };

class _AnswerEvidence extends StatelessWidget {
  const _AnswerEvidence({
    required this.answer,
    required this.unknown,
    required this.unavailable,
    required this.general,
    required this.compact,
  });

  final CompassAnswer answer;
  final bool unknown;
  final bool unavailable;
  final bool general;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = _CompassCopy.of(context);
    if (unknown || unavailable) {
      return Column(
        children: <Widget>[
          _EvidenceLine(
            icon: FamilyCompassIcons.personOffOutlined,
            label: copy.source,
            value:
                unavailable ? copy.noAnswerGenerated : copy.noPermittedSource,
          ),
          _EvidenceLine(
            icon: FamilyCompassIcons.visibilityOffOutlined,
            label: copy.uncertainty,
            value: unavailable
                ? copy.unavailableUncertainty
                : copy.unknownUncertainty,
          ),
          _EvidenceLine(
            icon: FamilyCompassIcons.lockOutlineRounded,
            label: copy.audience,
            value: context.l10n.compassAnswerVisibility,
          ),
        ],
      );
    }

    if (general) {
      return Column(
        children: <Widget>[
          _EvidenceLine(
            key: const ValueKey('compass.answer.source'),
            icon: FamilyCompassIcons.autoStoriesOutlined,
            label: copy.source,
            value: answer.sourceLabel,
          ),
          _EvidenceLine(
            icon: FamilyCompassIcons.factCheckOutlined,
            label: copy.uncertainty,
            value: copy.generalKnowledgeUncertainty,
          ),
          _EvidenceLine(
            icon: FamilyCompassIcons.lockOutlineRounded,
            label: copy.audience,
            value: context.l10n.compassAnswerVisibility,
          ),
        ],
      );
    }

    final citation = answer.citations.firstOrNull;
    final legacyManualAnswer = citation == null;
    final lines = <Widget>[
      _EvidenceLine(
        key: const ValueKey('compass.answer.source'),
        icon: FamilyCompassIcons.personOutlineRounded,
        label: copy.source,
        value: copy.sourceLabel(citation?.sourceLabel ?? answer.sourceLabel),
      ),
      _EvidenceLine(
        key: const ValueKey('compass.answer.freshness'),
        icon: FamilyCompassIcons.scheduleOutlined,
        label: copy.freshness,
        value: citation == null
            ? copy.freshnessLabel(answer.freshnessLabel)
            : copy.citationFreshness(citation),
      ),
      _EvidenceLine(
        icon: FamilyCompassIcons.lockOutlineRounded,
        label: copy.audience,
        value: citation == null
            ? context.l10n.compassAnswerVisibility
            : copy.citationAudience(citation.audience),
      ),
      _EvidenceLine(
        icon: FamilyCompassIcons.gpsNotFixedOutlined,
        label: copy.uncertainty,
        value: legacyManualAnswer
            ? copy.manualNotLive
            : copy.answerUncertainty(answer.uncertainty),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = compact && constraints.maxWidth >= 560;
        if (!twoColumns) return Column(children: lines);
        return Wrap(
          spacing: FamilyCompassSpacing.lg,
          runSpacing: 0,
          children: <Widget>[
            for (final line in lines)
              SizedBox(
                width: (constraints.maxWidth - FamilyCompassSpacing.lg) / 2,
                child: line,
              ),
          ],
        );
      },
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(
        minHeight: FamilyCompassSizes.minimumTouchTarget,
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: FamilyCompassSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: FamilyCompassSpacing.xs),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: FamilyCompassSpacing.xs),
          Expanded(
            child: _BidiText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerActionRow extends StatelessWidget {
  const _AnswerActionRow({
    required this.label,
    required this.body,
    required this.action,
  });

  final String label;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: FamilyCompassSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 480;
          final explanation = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: FamilyCompassSpacing.xxs),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                explanation,
                const SizedBox(height: FamilyCompassSpacing.xxs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action,
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: explanation),
              const SizedBox(width: FamilyCompassSpacing.md),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _AnswerStatementRow extends StatelessWidget {
  const _AnswerStatementRow({
    required this.label,
    required this.body,
    this.topDivider = true,
  });

  final String label;
  final String body;
  final bool topDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: topDivider
              ? BorderSide(color: colors.outlineVariant)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: FamilyCompassSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: FamilyCompassSpacing.xxs),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SourcePrivacyPane extends StatelessWidget {
  const _SourcePrivacyPane({required this.answer, required this.state});

  final CompassAnswer? answer;
  final PrototypeScenarioState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = _CompassCopy.of(context);
    final general = answer?.isGeneralKnowledge == true;
    final unknown = answer != null &&
        !answer!.hasPermittedInformation &&
        !general &&
        state.aiAvailable;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(FamilyCompassIcons.lockOutlineRounded,
                    color: colors.primary),
                const SizedBox(width: FamilyCompassSpacing.xs),
                Expanded(
                  child: Text(
                    copy.sourceAndPrivacy,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Text(
              context.l10n.compassAnswerVisibility,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              copy.sourcePrivacyDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: FamilyCompassSpacing.md),
            if (!state.aiAvailable) ...<Widget>[
              _PaneFact(
                label: copy.answerState,
                value: copy.noGeneratedAnswerSentence,
              ),
              _PaneFact(
                label: copy.whatStillWorks,
                value: copy.familyPlansAndChatWork,
              ),
            ] else if (state.surfaceState ==
                SurfaceState.offlineCached) ...<Widget>[
              _PaneFact(
                label: copy.answerState,
                value: copy.needsConnection,
              ),
              _PaneFact(
                label: copy.whatStillWorks,
                value: copy.savedPlansRemain,
              ),
            ] else if (answer == null) ...<Widget>[
              Text(
                copy.inspectSourceHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else if (unknown) ...<Widget>[
              _PaneFact(
                label: copy.source,
                value: copy.noPermittedSourceSentence,
              ),
              _PaneFact(
                label: copy.uncertainty,
                value: copy.noRoutineInference,
              ),
            ] else if (general) ...<Widget>[
              _PaneFact(
                label: copy.source,
                value: answer!.sourceLabel,
              ),
              _PaneFact(
                label: copy.uncertainty,
                value: copy.generalKnowledgeUncertainty,
              ),
            ] else ...<Widget>[
              if (answer!.citations.isEmpty) ...<Widget>[
                _PaneFact(
                  label: copy.source,
                  value: copy.sourceLabel(answer!.sourceLabel),
                ),
                _PaneFact(
                  label: copy.freshness,
                  value: copy.freshnessLabel(answer!.freshnessLabel),
                ),
                _PaneFact(
                  label: copy.audience,
                  value: copy.dadSharedWithAbdullah,
                ),
              ] else
                for (var index = 0;
                    index < answer!.citations.length;
                    index++) ...<Widget>[
                  _PaneFact(
                    label: answer!.citations.length == 1
                        ? copy.source
                        : copy.numberedSource(index + 1),
                    value: copy.sourceLabel(
                      answer!.citations[index].sourceLabel,
                    ),
                  ),
                  _PaneFact(
                    label: copy.freshness,
                    value: copy.citationFreshness(
                      answer!.citations[index],
                    ),
                  ),
                  _PaneFact(
                    label: copy.audience,
                    value: copy.citationAudience(
                      answer!.citations[index].audience,
                    ),
                  ),
                ],
              _PaneFact(
                label: copy.uncertainty,
                value: answer!.citations.isEmpty
                    ? copy.manualMayChange
                    : copy.answerUncertainty(answer!.uncertainty),
              ),
            ],
            const SizedBox(height: FamilyCompassSpacing.md),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: FamilyCompassSpacing.md),
            _PaneFact(
              label: copy.whatWasNotUsed,
              value: copy.noMapOrHistory,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneFact extends StatelessWidget {
  const _PaneFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: FamilyCompassSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xxs),
          _BidiText(value),
        ],
      ),
    );
  }
}

Future<void> _showWhyThisAnswer(
  BuildContext context,
  CompassAnswer answer,
) {
  final copy = _CompassCopy.of(context);
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
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              key: const ValueKey('compass.why.sheet'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.whyButton,
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: FamilyCompassSpacing.md),
                if (answer.citations.isEmpty) ...<Widget>[
                  _ExplanationRow(
                    icon: FamilyCompassIcons.personOutlineRounded,
                    title: copy.source,
                    body:
                        '${copy.sourceLabel(answer.sourceLabel)}. ${copy.dadManualSourceSuffix}',
                  ),
                  const SizedBox(height: FamilyCompassSpacing.md),
                  _ExplanationRow(
                    icon: FamilyCompassIcons.peopleOutlineRounded,
                    title: copy.audience,
                    body: copy.dadSharedWithAbdullah,
                  ),
                  const SizedBox(height: FamilyCompassSpacing.md),
                  _ExplanationRow(
                    icon: FamilyCompassIcons.scheduleOutlined,
                    title: copy.freshness,
                    body: copy.updated(
                      copy.freshnessLabel(answer.freshnessLabel),
                    ),
                  ),
                ] else
                  for (var index = 0;
                      index < answer.citations.length;
                      index++) ...<Widget>[
                    _ExplanationRow(
                      icon: FamilyCompassIcons.personOutlineRounded,
                      title: answer.citations.length == 1
                          ? copy.source
                          : copy.numberedSource(index + 1),
                      body: copy.sourceLabel(
                        answer.citations[index].sourceLabel,
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    _ExplanationRow(
                      icon: FamilyCompassIcons.peopleOutlineRounded,
                      title: copy.audience,
                      body: copy.citationAudience(
                        answer.citations[index].audience,
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.sm),
                    _ExplanationRow(
                      icon: FamilyCompassIcons.scheduleOutlined,
                      title: copy.freshness,
                      body: copy.citationFreshness(
                        answer.citations[index],
                      ),
                    ),
                    const SizedBox(height: FamilyCompassSpacing.md),
                  ],
                const SizedBox(height: FamilyCompassSpacing.md),
                _ExplanationRow(
                  icon: FamilyCompassIcons.gpsNotFixedOutlined,
                  title: copy.uncertainty,
                  body: answer.citations.isEmpty
                      ? copy.answerManualMayChange
                      : copy.answerUncertainty(answer.uncertainty),
                ),
                const SizedBox(height: FamilyCompassSpacing.md),
                _ExplanationRow(
                  icon: FamilyCompassIcons.locationOffOutlined,
                  title: copy.whatWasNotUsed,
                  body: copy.answerNoMap,
                ),
              ],
            ),
          ),
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
              _BidiText(body),
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
    final copy = _CompassCopy.of(context);
    return FolioSurface(
      key: const ValueKey('compass.planChange.draftCard'),
      backgroundColor: colors.secondaryContainer,
      borderColor: colors.secondary.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.planChangeDraft,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          _BidiText(
            copy.dinnerTimeChange,
            style: TextStyle(color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            copy.reviewPlanChange,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          FilledButton(
            key: const ValueKey('compass.planChange.apply'),
            onPressed: onApply,
            child: Text(copy.confirmChange),
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
    final copy = _CompassCopy.of(context);
    return FolioSurface(
      key: const ValueKey('compass.reminder.draft'),
      backgroundColor: colors.secondaryContainer,
      borderColor: colors.secondary.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(FamilyCompassSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.reminderDraft,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          _BidiText(
            copy.dessertFridayFive,
            style: TextStyle(color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: FamilyCompassSpacing.xxs),
          Text(
            copy.reminderPrivateDraft,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('compass.reminder.confirm'),
            onPressed: controller.confirmSeparateReminder,
            icon: const Icon(FamilyCompassIcons.alarmAddOutlined),
            label: Text(copy.confirmReminder),
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
    return InlineNotice(
      icon: icon,
      title: title,
      body: body,
    );
  }
}

class _CompassComposer extends StatelessWidget {
  const _CompassComposer({
    required this.controller,
    required this.enabled,
    required this.compact,
    required this.allowsGeneralQuestions,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool compact;
  final bool allowsGeneralQuestions;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = _CompassCopy.of(context);
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.shadow,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.sm,
          compact ? FamilyCompassSpacing.xxs : FamilyCompassSpacing.xs,
          FamilyCompassSpacing.sm,
          compact ? FamilyCompassSpacing.xxs : FamilyCompassSpacing.sm,
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
                maxLines: compact ? 1 : 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: allowsGeneralQuestions
                      ? copy.askAnythingHint
                      : context.l10n.compassInputHint,
                  contentPadding: EdgeInsetsDirectional.symmetric(
                    horizontal: FamilyCompassSpacing.md,
                    vertical: compact
                        ? FamilyCompassSpacing.sm
                        : FamilyCompassSpacing.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            IconButton.filled(
              key: const ValueKey('compass.composer.send'),
              tooltip: copy.askCompass,
              constraints: const BoxConstraints.tightFor(
                width: FamilyCompassSizes.minimumTouchTarget,
                height: FamilyCompassSizes.minimumTouchTarget,
              ),
              onPressed: enabled ? onSubmit : null,
              icon: const Icon(FamilyCompassIcons.arrowUpwardRounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BidiText extends StatelessWidget {
  const _BidiText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _firstStrongDirection(text) ?? Directionality.of(context),
      child: Text(text, style: style, textAlign: TextAlign.start),
    );
  }
}

class _CompassCopy {
  const _CompassCopy(this.isArabic);

  factory _CompassCopy.of(BuildContext context) => _CompassCopy(
        Localizations.localeOf(context).languageCode == 'ar',
      );

  final bool isArabic;

  String pick(String english, String arabic) => isArabic ? arabic : english;

  String get planChangedTitle =>
      pick('Plan changed to 7:30 PM', 'تم تغيير الخطة إلى 7:30 م');
  String get planChangedBody => pick(
        'The family plan now uses the reviewed time.',
        'تستخدم خطة العائلة الآن الوقت الذي تمت مراجعته.',
      );
  String get reminderConfirmedTitle =>
      pick('Reminder confirmed', 'تم تأكيد التذكير');
  String get dessertFridayFive => pick(
        'Buy dessert · Friday at 5:00 PM',
        'شراء الحلوى · الجمعة الساعة 5:00 م',
      );
  String get offlineBanner => pick(
        'Compass needs a connection. Cached family plans remain available.',
        'تحتاج البوصلة إلى اتصال بالإنترنت. تبقى خطط العائلة المحفوظة متاحة.',
      );
  String get askSharedInformation => pick(
        'Ask about shared family information',
        'اسأل عن معلومات شاركتها العائلة',
      );
  String get reminderPrompt => pick(
        'Remind me to buy dessert Friday at 5:00 PM',
        'ذكّرني بشراء الحلوى يوم الجمعة الساعة 5:00 م',
      );
  String get unavailableNow =>
      pick('Compass is unavailable right now', 'البوصلة غير متاحة الآن');
  String get familyPlansAndChatWork => pick(
        'Family plans and Chat still work.',
        'لا تزال خطط العائلة والدردشة تعملان.',
      );
  String get unavailableTitle =>
      pick('Compass unavailable', 'البوصلة غير متاحة');
  String get generalAnswerTitle => pick('General answer', 'إجابة عامة');
  String get generalAnswerNextStep => pick(
        'Ask another question. Family-specific answers remain limited to information family members chose to share.',
        'اطرح سؤالًا آخر. تظل الإجابات الخاصة بالعائلة محدودة بالمعلومات التي اختار أفراد العائلة مشاركتها.',
      );
  String get generalKnowledgeUncertainty => pick(
        'Generated from the model’s general knowledge. Verify important facts.',
        'إجابة من المعرفة العامة للنموذج. تحقّق من المعلومات المهمة.',
      );
  String get thinking =>
      pick('Compass is thinking…', 'تعمل البوصلة على الإجابة…');
  String get answerFailed =>
      pick('Compass could not answer', 'تعذّرت إجابة البوصلة');
  String get tryAgain => pick('Try again', 'حاول مجددًا');
  String get errorNoAction => pick(
        'No message was sent and no family information was changed.',
        'لم تُرسل أي رسالة ولم تتغير أي معلومات عائلية.',
      );
  String get noRecentUpdate => pick('No recent update', 'لا يوجد تحديث حديث');
  String get noPermittedAnswer =>
      pick('No permitted answer', 'لا توجد إجابة مسموح بها');
  String get groundedTitle => pick(
        'Answer from shared information',
        'إجابة من معلومات تمت مشاركتها',
      );
  String get whyLabel => pick('Why this answer', 'لماذا هذه الإجابة');
  String get whyButton => pick('Why this answer?', 'لماذا هذه الإجابة؟');
  String get whyBody => pick(
        'See what Compass used and what it left out.',
        'اطّلع على ما استخدمته البوصلة وما لم تستخدمه.',
      );
  String get correction => pick('Correction', 'تصحيح');
  String get correctionBody => pick(
        'Flag this update if it no longer reflects Dad\'s plans.',
        'أشر إلى أن هذا التحديث قديم إذا لم يعد يعكس خطط الأب.',
      );
  String get markedOutdated =>
      pick('Marked as outdated', 'تم اعتبار التحديث قديمًا');
  String get markOutdated => pick('Mark as outdated', 'اعتبار التحديث قديمًا');
  String get nothingToCorrect => pick(
        'No sourced claim was shown, so there is nothing to correct.',
        'لم تظهر معلومة منسوبة إلى مصدر، لذلك لا يوجد ما يحتاج إلى تصحيح.',
      );
  String get nextStep => pick('Next step', 'الخطوة التالية');
  String get draftPlanChange =>
      pick('Draft a change to 7:30', 'إعداد تغيير إلى 7:30');
  String get requestCheckIn => pick('Request a check-in', 'طلب الاطمئنان');
  String get checkInRequested => pick('Check-in requested', 'تم طلب الاطمئنان');
  String get draftDessertReminder => pick(
        'Draft a personal dessert reminder',
        'إعداد تذكير شخصي بالحلوى',
      );
  String get noFollowUp => pick(
        'No follow-up is needed. Ask another question or continue the family plan in Together.',
        'لا يلزم إجراء آخر. اسأل سؤالًا آخر أو تابع خطة العائلة في «معًا».',
      );
  String get reconnectNextStep => pick(
        'Try again after Compass reconnects. Family plans and Chat still work.',
        'حاول مجددًا بعد اتصال البوصلة. لا تزال خطط العائلة والدردشة تعملان.',
      );
  String get unsupportedQuestionNextStep => pick(
        'Ask about Dad\'s shared update, or continue the family plan in Together.',
        'اسأل عن التحديث الذي شاركه الأب، أو تابع خطة العائلة في «معًا».',
      );
  String get source => pick('Source', 'المصدر');
  String get freshness => pick('Freshness', 'وقت التحديث');
  String get audience => pick('Audience', 'من يرى الإجابة');
  String get uncertainty => pick('Uncertainty', 'درجة اليقين');
  String get noAnswerGenerated =>
      pick('No answer was generated', 'لم يتم إنشاء إجابة');
  String get noPermittedSource => pick(
        'No permitted source is available',
        'لا يتوفر مصدر مسموح لك برؤيته',
      );
  String get unavailableUncertainty => pick(
        'Compass cannot check shared information while unavailable',
        'لا تستطيع البوصلة التحقق من المعلومات المشتركة أثناء عدم توفرها',
      );
  String get unknownUncertainty => pick(
        'Compass did not infer a location from silence or routine',
        'لم تستنتج البوصلة موقعًا من عدم الرد أو من الروتين',
      );
  String get manualNotLive => pick(
        'Manual update, not a live position',
        'تحديث يدوي، وليس موقعًا مباشرًا',
      );
  String get sourceAndPrivacy => pick('Source & privacy', 'المصدر والخصوصية');
  String get sourcePrivacyDescription => pick(
        'Compass only explains family information that was deliberately shared with your account.',
        'تشرح البوصلة فقط معلومات العائلة التي تمت مشاركتها عمدًا مع حسابك.',
      );
  String get answerState => pick('Answer state', 'حالة الإجابة');
  String get noGeneratedAnswerSentence => pick(
        'Compass did not generate an answer.',
        'لم تُنشئ البوصلة إجابة.',
      );
  String get whatStillWorks => pick('What still works', 'ما زال يعمل');
  String get needsConnection => pick(
        'Compass needs a connection before it can answer.',
        'تحتاج البوصلة إلى اتصال قبل أن تتمكن من الإجابة.',
      );
  String get savedPlansRemain => pick(
        'Saved family plans remain available.',
        'تبقى خطط العائلة المحفوظة متاحة.',
      );
  String get inspectSourceHint => pick(
        'Ask a question to inspect its source, freshness, audience, and uncertainty here.',
        'اطرح سؤالًا لعرض مصدر الإجابة ووقت تحديثها ومن يراها ودرجة اليقين هنا.',
      );
  String get noPermittedSourceSentence => pick(
      'No permitted source is available.', 'لا يتوفر مصدر مسموح لك برؤيته.');
  String get noRoutineInference => pick(
        'Compass did not infer a location from routine, silence, or past movement.',
        'لم تستنتج البوصلة موقعًا من الروتين أو عدم الرد أو الحركة السابقة.',
      );
  String get dadSharedWithAbdullah => pick(
        'Dad chose to share this update with Abdullah.',
        'اختار الأب مشاركة هذا التحديث مع عبدالله.',
      );
  String get manualMayChange => pick(
        'This is a manual update and may change before Dad shares again.',
        'هذا تحديث يدوي وقد يتغير قبل أن يشارك الأب تحديثًا جديدًا.',
      );
  String get whatWasNotUsed => pick('What was not used', 'ما لم يُستخدم');
  String get noMapOrHistory => pick(
        'No live map, continuous location, or private Compass history.',
        'لم تُستخدم خريطة مباشرة أو مشاركة موقع مستمرة أو سجل محادثاتك الخاصة مع البوصلة.',
      );
  String get dadManualSourceSuffix => pick(
        'This was Dad\'s manual update.',
        'هذا تحديث يدوي شاركه الأب.',
      );
  String updated(String freshnessValue) => pick(
        'Updated $freshnessValue.',
        'آخر تحديث: $freshnessValue.',
      );
  String get answerManualMayChange => pick(
        'This answer reflects a manual update and may change before Dad shares again.',
        'تعكس هذه الإجابة تحديثًا يدويًا وقد تتغير قبل أن يشارك الأب تحديثًا جديدًا.',
      );
  String get answerNoMap => pick(
        'This answer did not use a live map or continuous location.',
        'لم تستخدم هذه الإجابة خريطة مباشرة أو مشاركة موقع مستمرة.',
      );
  String get planChangeDraft => pick('Plan change draft', 'مسودة تغيير الخطة');
  String get dinnerTimeChange => pick(
        'Friday family dinner: 7:00 PM → 7:30 PM',
        'عشاء العائلة يوم الجمعة: من 7:00 م إلى 7:30 م',
      );
  String get reviewPlanChange => pick(
        'Review this change before updating the family plan.',
        'راجع هذا التغيير قبل تحديث خطة العائلة.',
      );
  String get confirmChange => pick('Confirm change', 'تأكيد التغيير');
  String get reminderDraft =>
      pick('Personal reminder draft', 'مسودة تذكير شخصي');
  String get reminderPrivateDraft => pick(
        'This is private and has not been created yet.',
        'هذا التذكير خاص بك ولم يتم إنشاؤه بعد.',
      );
  String get confirmReminder => pick('Confirm reminder', 'تأكيد التذكير');
  String get askCompass => pick('Ask Compass', 'اسأل البوصلة');
  String get askAnythingHint => pick(
        'Ask anything, or ask about shared family information',
        'اسأل أي سؤال، أو اسأل عن معلومات شاركتها العائلة',
      );
  String get confirmActionTitle =>
      pick('Review this action', 'راجع هذا الإجراء');
  String get confirm => pick('Confirm', 'تأكيد');
  String get cancel => pick('Cancel', 'إلغاء');
  String get actionNeedsDetailsTitle =>
      pick('More details needed', 'هناك حاجة إلى تفاصيل إضافية');
  String get actionNeedsDetailsBody => pick(
        'Compass has not changed anything. Open Together to choose the people, time, and reminder details yourself.',
        'لم تغيّر البوصلة أي شيء. افتح «معًا» لاختيار الأشخاص والوقت وتفاصيل التذكير بنفسك.',
      );

  String confirmActionBody(CompassAction action) => pick(
        '${liveActionLabel(action)} will affect your family space. Nothing happens until you confirm.',
        'سيؤثر إجراء «${liveActionLabel(action)}» في مساحة العائلة. لن يحدث شيء قبل التأكيد.',
      );

  String liveActionLabel(CompassAction action) {
    if (!isArabic) return action.label;
    return switch (action.kind) {
      CompassActionKind.openPlan => 'فتح خطة العائلة',
      CompassActionKind.startPlan => 'بدء خطة عائلية',
      CompassActionKind.requestCheckIn => 'طلب الاطمئنان',
      CompassActionKind.createReminder => 'إنشاء تذكير',
    };
  }

  String numberedSource(int number) => pick('Source $number', 'المصدر $number');

  String citationAudience(CompassFactAudience value) => switch (value) {
        CompassFactAudience.wholeFamily =>
          pick('Shared with the whole family', 'مشاركة مع العائلة كلها'),
        CompassFactAudience.selectedPeople =>
          pick('Shared with selected people', 'مشاركة مع أشخاص محددين'),
        CompassFactAudience.onlyMe => pick('Only you', 'أنت فقط'),
        CompassFactAudience.requestParticipants => pick(
            'Only the check-in participants',
            'المشاركون في طلب الاطمئنان فقط',
          ),
      };

  String citationFreshness(CompassCitation citation) {
    final elapsed =
        DateTime.now().toUtc().difference(citation.updatedAt.toUtc());
    final relative = elapsed.isNegative || elapsed.inMinutes <= 0
        ? pick('just now', 'الآن')
        : elapsed.inMinutes < 60
            ? pick(
                '${elapsed.inMinutes} min ago',
                'قبل ${elapsed.inMinutes} دقيقة',
              )
            : elapsed.inHours < 24
                ? pick(
                    '${elapsed.inHours} hr ago',
                    'قبل ${elapsed.inHours} ساعة',
                  )
                : pick(
                    '${elapsed.inDays} d ago',
                    'قبل ${elapsed.inDays} يوم',
                  );
    final kind = switch (citation.freshness) {
      CompassFactFreshness.current => pick('Current', 'حالي'),
      CompassFactFreshness.recent => pick('Recent', 'حديث'),
      CompassFactFreshness.scheduled => pick('Scheduled', 'مجدول'),
    };
    return '$kind · $relative';
  }

  String answerUncertainty(CompassUncertainty value) => switch (value) {
        CompassUncertainty.low => pick(
            'Low uncertainty, based directly on shared information',
            'درجة عدم يقين منخفضة، استنادًا مباشرة إلى معلومات تمت مشاركتها',
          ),
        CompassUncertainty.medium => pick(
            'Some uncertainty remains. Check the source and update time.',
            'لا تزال هناك بعض درجة عدم اليقين. راجع المصدر ووقت التحديث.',
          ),
        CompassUncertainty.high => pick(
            'No reliable current family fact supports a specific claim',
            'لا توجد معلومة عائلية حالية موثوقة تدعم ادعاءً محددًا',
          ),
        CompassUncertainty.notApplicable => generalKnowledgeUncertainty,
      };

  String answerText(CompassAnswer answer) {
    if (!isArabic) return answer.text;
    return switch (answer.text) {
      'Dad shared that he is leaving work and expects to arrive around 7:20 PM.' =>
        'شارك الأب أنه يغادر العمل ويتوقع الوصول نحو الساعة 7:20 م.',
      'No recent permitted information is available.' =>
        'لا تتوفر معلومات حديثة مسموح لك برؤيتها.',
      'No permitted source is available for that question.' =>
        'لا يتوفر مصدر مسموح به للإجابة عن هذا السؤال.',
      'Compass is unavailable right now. Family plans and Chat still work.' =>
        'البوصلة غير متاحة الآن. لا تزال خطط العائلة والدردشة تعملان.',
      _ => answer.text,
    };
  }

  String sourceLabel(String sourceValue) {
    if (!isArabic) return sourceValue;
    return switch (sourceValue) {
      'Shared by Dad' => 'مشاركة من الأب',
      'AI unavailable' => 'البوصلة غير متاحة',
      'No permitted source' => 'لا يوجد مصدر مسموح',
      _ => sourceValue,
    };
  }

  String freshnessLabel(String freshnessValue) {
    if (!isArabic) return freshnessValue;
    final minutesMatch = RegExp(r'^(\d+) minutes ago$').firstMatch(
      freshnessValue,
    );
    if (minutesMatch != null) {
      final minutes = int.parse(minutesMatch.group(1)!);
      if (minutes == 1) return 'قبل دقيقة واحدة';
      if (minutes == 2) return 'قبل دقيقتين';
      if (minutes >= 3 && minutes <= 10) return 'قبل $minutes دقائق';
      return 'قبل $minutes دقيقة';
    }
    return switch (freshnessValue) {
      'Current' => 'محدّث',
      'May be out of date' => 'قد لا يكون محدّثًا',
      _ => freshnessValue,
    };
  }

  String actionLabel(String? actionValue) {
    final value = actionValue ?? 'Draft a change to 7:30';
    if (!isArabic) return value;
    return switch (value) {
      'Draft a change to 7:30' => 'إعداد تغيير إلى 7:30',
      'Request a check-in' => 'طلب الاطمئنان',
      _ => value,
    };
  }
}

bool _looksLikeDadQuestion(String text) {
  final normalized = text.toLowerCase();
  if (RegExp(r'\b(dad|father|papa)\b').hasMatch(normalized)) return true;
  return <String>['أبي', 'ابي', 'والدي', 'الأب', 'بابا', 'ابوي'].any(
    normalized.contains,
  );
}

TextDirection? _firstStrongDirection(String text) {
  final arabic = RegExp(r'[\u0600-\u06FF]');
  final latin = RegExp(r'[A-Za-z]');
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    if (arabic.hasMatch(character)) return TextDirection.rtl;
    if (latin.hasMatch(character)) return TextDirection.ltr;
  }
  return null;
}
