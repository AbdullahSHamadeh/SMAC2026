import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/family_compass_repositories.dart';
import '../../design_system/design_system.dart';
import '../../domain/chat_models.dart';
import '../../domain/compass_models.dart';
import '../../domain/family_models.dart';
import '../../domain/plan_models.dart';
import '../../l10n/l10n.dart';
import '../../prototype/prototype_scenario_controller.dart';
import '../../prototype/prototype_scenario_state.dart';
import '../../widgets/prototype_widgets.dart';

/// The shared family conversation.
///
/// Human messages use a familiar conversation grammar. Plans, polls, and
/// reminders are the only bounded folio artifacts. Compass remains a quiet,
/// clearly labelled participant and never speaks for a family member.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.controller,
    this.familyRoomCompassRepository,
    this.familyId,
    super.key,
  });

  final PrototypeScenarioController controller;
  final FamilyRoomCompassRepository? familyRoomCompassRepository;
  final String? familyId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _uuid = Uuid();
  late final TextEditingController _composerController;
  late final FocusNode _composerFocusNode;
  final ScrollController _scrollController = ScrollController();
  late String _contentSignature;
  final Map<String, GlobalKey> _messageAnchors = <String, GlobalKey>{};
  int _lastHandledDeepLinkRevision = -1;
  String? _linkedMessageId;
  StreamSubscription<List<FamilyRoomCompassArtifact>>? _familyRoomSubscription;
  final Map<String, GlobalKey> _familyRoomArtifactAnchors =
      <String, GlobalKey>{};
  List<FamilyRoomCompassArtifact> _familyRoomArtifacts = const [];
  String? _pendingCompassPrompt;
  String? _failedCompassPrompt;
  String? _failedCompassRequestId;
  Set<String> _failedCompassMentionedMemberIds = const <String>{};
  String? _familyRoomError;
  _MentionTrigger? _activeMention;
  final Map<String, String> _selectedMemberMentionHandles = <String, String>{};
  final List<FamilyRoomCompassArtifact> _localFamilyRoomArtifacts =
      <FamilyRoomCompassArtifact>[];

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController(
      text: widget.controller.state.ui.chatDraft,
    )..addListener(_handleComposerChanged);
    _composerFocusNode = FocusNode(debugLabel: 'Family chat composer');
    _contentSignature = _signatureFor(widget.controller.state);
    widget.controller.addListener(_syncControllerState);
    _syncLinkedMessage();
    _listenToFamilyRoom();
    _scheduleScrollToNewest();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncControllerState);
      _composerController.removeListener(_handleComposerChanged);
      _composerController.text = widget.controller.state.ui.chatDraft;
      _composerController.addListener(_handleComposerChanged);
      _contentSignature = _signatureFor(widget.controller.state);
      _lastHandledDeepLinkRevision = -1;
      _linkedMessageId = null;
      _messageAnchors.clear();
      _selectedMemberMentionHandles.clear();
      widget.controller.addListener(_syncControllerState);
      _syncLinkedMessage();
      _scheduleScrollToNewest();
    }
    if (oldWidget.familyRoomCompassRepository !=
            widget.familyRoomCompassRepository ||
        oldWidget.familyId != widget.familyId) {
      _familyRoomArtifacts = const [];
      _listenToFamilyRoom();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerState);
    unawaited(_familyRoomSubscription?.cancel());
    _composerController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToFamilyRoom() {
    unawaited(_familyRoomSubscription?.cancel());
    _familyRoomSubscription = null;
    final repository = widget.familyRoomCompassRepository;
    final familyId = widget.familyId;
    if (repository == null || familyId == null) return;
    _familyRoomSubscription = repository.watchArtifacts(familyId).listen(
      (artifacts) {
        if (!mounted) return;
        final previousIds =
            _familyRoomArtifacts.map((artifact) => artifact.id).toSet();
        final newestIncoming = artifacts
            .where((artifact) => !previousIds.contains(artifact.id))
            .lastOrNull;
        final wasFollowingNewest = _isFollowingNewest;
        setState(() {
          _familyRoomArtifacts = List.unmodifiable(artifacts);
          _familyRoomError = null;
        });
        _familyRoomArtifactAnchors.removeWhere(
          (id, _) => !artifacts.any((artifact) => artifact.id == id),
        );
        if (newestIncoming != null &&
            wasFollowingNewest &&
            _pendingCompassPrompt == null) {
          _scheduleRevealFamilyArtifact(newestIncoming.id);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _familyRoomError = _copy(
            context,
            en: 'Compass could not load its family-visible notes.',
            ar: 'تعذر على البوصلة تحميل ملاحظاتها الظاهرة للعائلة.',
          );
        });
      },
    );
  }

  void _saveDraft() {
    final value = _composerController.text;
    if (value != widget.controller.state.ui.chatDraft) {
      widget.controller.updateChatDraft(value);
    }
  }

  void _handleComposerChanged() {
    _saveDraft();
    _selectedMemberMentionHandles.removeWhere(
      (_, handle) => !_containsMentionHandle(_composerController.text, handle),
    );
    final next = _mentionTriggerFor(_composerController.value);
    if (next == _activeMention) return;
    setState(() => _activeMention = next);
  }

  List<_MentionCandidate> _mentionCandidates(BuildContext context) {
    final candidates = <_MentionCandidate>[
      _MentionCandidate.compass(
        label: 'Compass',
        supportingLabel: _copy(
          context,
          en: 'Ask with family-shared context',
          ar: 'اسأل باستخدام ما شاركته العائلة',
        ),
      ),
      for (final member in widget.controller.familyMembersForDisplay)
        if (_mentionName(member.name).isNotEmpty)
          _MentionCandidate.member(
            member: member,
            supportingLabel: _mentionRelationshipLabel(context, member),
          ),
    ];
    final query = _activeMention?.query.trim().toLowerCase() ?? '';
    if (query.isEmpty) return candidates;
    return candidates
        .where(
          (candidate) =>
              candidate.label.toLowerCase().contains(query) ||
              candidate.supportingLabel.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _selectMention(_MentionCandidate candidate) {
    final trigger = _activeMention;
    if (trigger == null) return;
    final value = _composerController.value;
    final safeEnd = trigger.end.clamp(trigger.start, value.text.length);
    final before = value.text.substring(0, trigger.start);
    final after = value.text.substring(safeEnd);
    final separator = after.isEmpty || !_startsWithWhitespace(after) ? ' ' : '';
    final insertion = '${candidate.handle}$separator';
    if (candidate.memberId case final memberId?) {
      _selectedMemberMentionHandles[memberId] = candidate.handle;
    }
    _composerController.value = TextEditingValue(
      text: '$before$insertion$after',
      selection: TextSelection.collapsed(
        offset: before.length + insertion.length,
      ),
    );
    setState(() => _activeMention = null);
    _composerFocusNode.requestFocus();
  }

  void _syncControllerState() {
    final state = widget.controller.state;
    if (_composerController.text != state.ui.chatDraft) {
      _composerController.value = TextEditingValue(
        text: state.ui.chatDraft,
        selection: TextSelection.collapsed(offset: state.ui.chatDraft.length),
      );
    }
    final signature = _signatureFor(state);
    if (signature != _contentSignature) {
      final wasFollowingNewest = _isFollowingNewest;
      _contentSignature = signature;
      _messageAnchors.removeWhere(
        (id, _) => !state.chatItems.any((item) => item.id == id),
      );
      if (wasFollowingNewest) {
        _scheduleScrollToNewest(animate: !_disableAnimations);
      }
    }
    _syncLinkedMessage();
  }

  void _syncLinkedMessage() {
    final revision = widget.controller.deepLinkRevision;
    if (revision == _lastHandledDeepLinkRevision) return;
    _lastHandledDeepLinkRevision = revision;
    final linkedMessageId = widget.controller.linkedMessageId;
    _linkedMessageId = linkedMessageId;
    if (linkedMessageId != null &&
        widget.controller.state.chatItems.any(
          (item) => item.id == linkedMessageId,
        )) {
      _scheduleRevealLinkedMessage(linkedMessageId);
    }
  }

  String _signatureFor(PrototypeScenarioState state) => <Object?>[
        state.chatItems.length,
        state.plan?.phase,
        state.plan?.responses.length,
        state.plan?.nudgeSent,
        state.plan?.confirmedCandidateId,
      ].join(':');

  bool get _isFollowingNewest =>
      !_scrollController.hasClients ||
      _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels <=
          120;

  bool get _disableAnimations =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  GlobalKey _familyRoomArtifactAnchor(String id) =>
      _familyRoomArtifactAnchors.putIfAbsent(id, GlobalKey.new);

  GlobalKey _messageAnchor(String id) =>
      _messageAnchors.putIfAbsent(id, GlobalKey.new);

  void _scheduleScrollToNewest({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate && !_disableAnimations) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _scheduleRevealFamilyArtifact(String artifactId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_disableAnimations) {
        _scheduleScrollToNewest();
        return;
      }
      final artifactContext =
          _familyRoomArtifactAnchors[artifactId]?.currentContext;
      if (artifactContext == null) {
        _scheduleScrollToNewest(animate: true);
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          artifactContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _scheduleRevealLinkedMessage(String messageId, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final messageContext = _messageAnchors[messageId]?.currentContext;
      if (messageContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            messageContext,
            alignment: 0.18,
            duration: _disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
        return;
      }
      if (attempt >= 2) return;
      final items = widget.controller.state.chatItems;
      final index = items.indexWhere((item) => item.id == messageId);
      if (index < 0) return;
      final fraction = items.length <= 1 ? 0.0 : index / (items.length - 1);
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent * fraction,
      );
      _scheduleRevealLinkedMessage(messageId, attempt: attempt + 1);
    });
  }

  void _sendHumanMessage() {
    final message = _composerController.text.trim();
    if (message.isEmpty) return;
    final mentionedMemberIds = Set<String>.unmodifiable(
      _selectedMemberMentionHandles.keys,
    );
    if (_containsCompassMention(message)) {
      if (widget.controller.state.surfaceState == SurfaceState.offlineCached) {
        return;
      }
      if (_pendingCompassPrompt != null) return;
      final prompt = _canonicalCompassPrompt(message);
      if (_compassQuestionBody(prompt).isEmpty) {
        setState(() {
          _familyRoomError = _copy(
            context,
            en: 'Add a question after @Compass. Your message is still here.',
            ar: 'أضف سؤالاً بعد @Compass. ما زالت رسالتك هنا.',
          );
          _failedCompassPrompt = null;
          _failedCompassRequestId = null;
          _failedCompassMentionedMemberIds = const <String>{};
        });
        return;
      }
      if (widget.familyRoomCompassRepository == null ||
          widget.familyId == null) {
        _selectedMemberMentionHandles.clear();
        unawaited(_askLocalFamilyRoomCompass(prompt, _uuid.v4()));
        return;
      }
      _selectedMemberMentionHandles.clear();
      unawaited(
        _askFamilyRoomCompass(
          prompt,
          _uuid.v4(),
          mentionedMemberIds: mentionedMemberIds,
        ),
      );
      return;
    }
    _selectedMemberMentionHandles.clear();
    widget.controller.sendHumanMessage(
      message,
      mentionedMemberIds: mentionedMemberIds,
    );
    _scheduleScrollToNewest(animate: !_disableAnimations);
  }

  Future<void> _askLocalFamilyRoomCompass(
    String prompt,
    String requestId,
  ) async {
    setState(() {
      _pendingCompassPrompt = prompt;
      _failedCompassPrompt = null;
      _failedCompassRequestId = null;
      _failedCompassMentionedMemberIds = const <String>{};
      _familyRoomError = null;
    });
    widget.controller.clearChatDraft();
    _scheduleScrollToNewest(animate: !_disableAnimations);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    final answer = widget.controller.answerForDad();
    final now = DateTime.now().toUtc();
    final artifact = FamilyRoomCompassArtifact(
      id: requestId,
      familyId: widget.familyId ?? 'demo-family',
      requestMessageId: 'demo-question-$requestId',
      requestedBy: widget.controller.currentUserId,
      kind: FamilyCompassArtifactKind.answer,
      answer: _localCompassAnswer(context, prompt, answer),
      provider: 'local-demo',
      citations: answer.hasPermittedInformation
          ? <CompassCitation>[
              CompassCitation(
                sourceId: 'demo-shared-update-$requestId',
                subjectUserId: 'dad',
                sourceType: CompassFactSource.sharedUpdate,
                sourceLabel: _copy(
                  context,
                  en: answer.sourceLabel,
                  ar: 'مشاركة من الأب',
                ),
                audience: CompassFactAudience.wholeFamily,
                freshness: CompassFactFreshness.recent,
                updatedAt: now,
                expiresAt: now.add(const Duration(hours: 1)),
                text: answer.text,
              ),
            ]
          : const <CompassCitation>[],
      actions: const <CompassAction>[],
      uncertainty: answer.hasPermittedInformation
          ? CompassUncertainty.low
          : CompassUncertainty.high,
      createdAt: now,
    );
    setState(() {
      _pendingCompassPrompt = null;
      _localFamilyRoomArtifacts.add(artifact);
    });
    _scheduleRevealFamilyArtifact(artifact.id);
  }

  String _localCompassAnswer(
    BuildContext context,
    String prompt,
    CompassAnswer familyAnswer,
  ) {
    final question = _compassQuestionBody(prompt).toLowerCase();
    final asksAboutDad = question.contains('dad') ||
        question.contains('father') ||
        question.contains('أبي') ||
        question.contains('والدي') ||
        question.contains('الأب');
    if (asksAboutDad) {
      return _copy(
        context,
        en: familyAnswer.text,
        ar: familyAnswer.hasPermittedInformation
            ? 'شارك الأب أنه غادر العمل ويتوقع الوصول نحو 7:20 مساءً.'
            : 'لا توجد معلومات حديثة مسموح بها عن الأب.',
      );
    }
    return _copy(
      context,
      en: 'I can use this family chat and information your family chose to share. The connected backend will answer broader questions here.',
      ar: 'يمكنني استخدام محادثة العائلة والمعلومات التي اختارت العائلة مشاركتها. ستجيب النسخة المتصلة بالخادم عن الأسئلة الأوسع هنا.',
    );
  }

  Future<void> _askFamilyRoomCompass(
    String prompt,
    String requestId, {
    Set<String> mentionedMemberIds = const <String>{},
  }) async {
    final repository = widget.familyRoomCompassRepository;
    final familyId = widget.familyId;
    if (repository == null || familyId == null) return;
    setState(() {
      _pendingCompassPrompt = prompt;
      _failedCompassPrompt = null;
      _failedCompassRequestId = null;
      _failedCompassMentionedMemberIds = const <String>{};
      _familyRoomError = null;
    });
    widget.controller.clearChatDraft();
    _scheduleScrollToNewest(animate: !_disableAnimations);
    try {
      final artifact = await repository.ask(
        familyId: familyId,
        prompt: prompt,
        idempotencyKey: requestId,
        mentionedMemberIds: mentionedMemberIds,
      );
      if (!mounted) return;
      setState(() {
        _familyRoomArtifacts = List.unmodifiable(<FamilyRoomCompassArtifact>[
          ..._familyRoomArtifacts.where((value) => value.id != artifact.id),
          artifact,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
        _pendingCompassPrompt = null;
      });
      _scheduleRevealFamilyArtifact(artifact.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingCompassPrompt = null;
        _failedCompassPrompt = prompt;
        _failedCompassRequestId = requestId;
        _failedCompassMentionedMemberIds = Set<String>.unmodifiable(
          mentionedMemberIds,
        );
        _familyRoomError = _copy(
          context,
          en: 'Your question is in the chat, but Compass could not reply.',
          ar: 'سؤالك موجود في الدردشة، لكن تعذر على البوصلة الرد.',
        );
      });
      _scheduleScrollToNewest(animate: !_disableAnimations);
    }
  }

  void _retryFamilyRoomCompass() {
    final prompt = _failedCompassPrompt;
    final requestId = _failedCompassRequestId;
    if (prompt == null || requestId == null) return;
    unawaited(
      _askFamilyRoomCompass(
        prompt,
        requestId,
        mentionedMemberIds: _failedCompassMentionedMemberIds,
      ),
    );
  }

  Future<void> _handleCompassAction(
    BuildContext context,
    CompassAction action,
  ) async {
    if (!_supportsCompassAction(action)) return;
    if (_requiresCompassActionConfirmation(action)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: ValueKey('chat.compass.action.confirmation.${action.kind.name}'),
          title: Text(
            _copy(context,
                en: 'Confirm this action?', ar: 'تأكيد هذا الإجراء؟'),
          ),
          content: Text(
            _copy(
              context,
              en: '${action.label} will happen only after you confirm.',
              ar: 'لن يتم ${action.label} إلا بعد تأكيدك.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_copy(context, en: 'Cancel', ar: 'إلغاء')),
            ),
            FilledButton(
              key: ValueKey('chat.compass.action.confirm.${action.kind.name}'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_copy(context, en: 'Confirm', ar: 'تأكيد')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    switch (action.kind) {
      case CompassActionKind.openPlan:
        widget.controller.openFamilyPlan(action.targetId!);
      case CompassActionKind.startPlan:
        widget.controller.startFamilyPlan();
      case CompassActionKind.requestCheckIn:
        widget.controller.requestCheckInFor(action.targetId!);
      case CompassActionKind.createReminder:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            final compactHeight =
                FamilyCompassBreakpoints.hasCompactHeight(context);
            return Column(
              key: const ValueKey('screen.chat'),
              children: <Widget>[
                if (state.surfaceState == SurfaceState.offlineCached)
                  _OfflineBanner(controller: widget.controller),
                if (!state.aiAvailable) const _AiUnavailableBanner(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSupportingPane = constraints.maxWidth >=
                              FamilyCompassBreakpoints.mediumWidth ||
                          (compactHeight && constraints.maxWidth >= 700);
                      final conversation = _ConversationPane(
                        state: state,
                        controller: widget.controller,
                        scrollController: _scrollController,
                        composerController: _composerController,
                        composerFocusNode: _composerFocusNode,
                        compactHeight: compactHeight,
                        onSend: _sendHumanMessage,
                        familyRoomArtifacts: List.unmodifiable(
                          <FamilyRoomCompassArtifact>[
                            ..._familyRoomArtifacts,
                            ..._localFamilyRoomArtifacts,
                          ]..sort(
                              (a, b) => a.createdAt.compareTo(b.createdAt),
                            ),
                        ),
                        pendingCompassPrompt: _pendingCompassPrompt,
                        familyRoomError: _familyRoomError,
                        onRetryCompass: _failedCompassPrompt == null
                            ? null
                            : _retryFamilyRoomCompass,
                        onCompassAction: (action) =>
                            _handleCompassAction(context, action),
                        familyRoomArtifactAnchor: _familyRoomArtifactAnchor,
                        linkedMessageId: _linkedMessageId,
                        messageAnchor: _messageAnchor,
                        mentionCandidates: _activeMention == null
                            ? const <_MentionCandidate>[]
                            : _mentionCandidates(context),
                        mentionChooserVisible: _activeMention != null,
                        onMentionSelected: _selectMention,
                      );

                      if (!showSupportingPane) return conversation;

                      final paneWidth = compactHeight
                          ? (constraints.maxWidth * 0.36).clamp(280.0, 332.0)
                          : 340.0;
                      return Row(
                        children: <Widget>[
                          Expanded(child: conversation),
                          VerticalDivider(
                            width: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          SizedBox(
                            width: paneWidth,
                            child: _ConversationContextPane(
                              state: state,
                              compactHeight: compactHeight,
                              members:
                                  widget.controller.familyMembersForDisplay,
                            ),
                          ),
                        ],
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

class _ConversationPane extends StatelessWidget {
  const _ConversationPane({
    required this.state,
    required this.controller,
    required this.scrollController,
    required this.composerController,
    required this.composerFocusNode,
    required this.compactHeight,
    required this.onSend,
    required this.familyRoomArtifacts,
    required this.pendingCompassPrompt,
    required this.familyRoomError,
    required this.onRetryCompass,
    required this.onCompassAction,
    required this.familyRoomArtifactAnchor,
    required this.linkedMessageId,
    required this.messageAnchor,
    required this.mentionCandidates,
    required this.mentionChooserVisible,
    required this.onMentionSelected,
  });

  final PrototypeScenarioState state;
  final PrototypeScenarioController controller;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final bool compactHeight;
  final VoidCallback onSend;
  final List<FamilyRoomCompassArtifact> familyRoomArtifacts;
  final String? pendingCompassPrompt;
  final String? familyRoomError;
  final VoidCallback? onRetryCompass;
  final ValueChanged<CompassAction> onCompassAction;
  final GlobalKey Function(String artifactId) familyRoomArtifactAnchor;
  final String? linkedMessageId;
  final GlobalKey Function(String messageId) messageAnchor;
  final List<_MentionCandidate> mentionCandidates;
  final bool mentionChooserVisible;
  final ValueChanged<_MentionCandidate> onMentionSelected;

  List<_ChatTimelineEntry> _timelineEntries() {
    var sequence = 0;
    final entries = <_ChatTimelineEntry>[
      for (final item in state.chatItems)
        _ChatTimelineEntry(
          occurredAt: item.sentAt,
          sequence: sequence++,
          child: _LinkedChatItemView(
            anchorKey: messageAnchor(item.id),
            messageId: item.id,
            highlighted: linkedMessageId == item.id,
            child: _ChatItemView(
              item: item,
              state: state,
              controller: controller,
            ),
          ),
        ),
      if (_needsDerivedPollCard(state))
        _ChatTimelineEntry(
          occurredAt: _derivedPlanOccurredAt(state),
          sequence: sequence++,
          child: _PollFolio(
            key: ValueKey('plan.${state.plan!.id}.poll'),
            plan: state.plan,
            controller: controller,
          ),
        ),
      if (_needsDerivedConfirmationCard(state))
        _ChatTimelineEntry(
          occurredAt: _derivedPlanOccurredAt(state),
          sequence: sequence++,
          child: _ConfirmedPlanFolio(
            key: ValueKey('plan.${state.plan!.id}.confirmed'),
            plan: state.plan,
            controller: controller,
          ),
        ),
      if (state.plan?.phase == PlanPhase.opportunity)
        _ChatTimelineEntry(
          occurredAt: _derivedPlanOccurredAt(state),
          sequence: sequence++,
          child: _DinnerOpportunityAnnotation(controller: controller),
        ),
      for (final artifact in familyRoomArtifacts)
        _ChatTimelineEntry(
          occurredAt: artifact.createdAt,
          sequence: sequence++,
          child: _FamilyRoomCompassArtifactView(
            key: ValueKey(
              'chat.compass.familyArtifact.${artifact.id}',
            ),
            anchorKey: familyRoomArtifactAnchor(artifact.id),
            artifact: artifact,
            onAction: onCompassAction,
          ),
        ),
    ];
    entries.sort((left, right) {
      final chronological = left.occurredAt.compareTo(right.occurredAt);
      return chronological == 0
          ? left.sequence.compareTo(right.sequence)
          : chronological;
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final timelineEntries = _timelineEntries();
              final horizontalPadding =
                  constraints.maxWidth < FamilyCompassBreakpoints.compactWidth
                      ? MediaQuery.textScalerOf(context).scale(1) > 1.5
                          ? FamilyCompassSpacing.xs
                          : FamilyCompassSpacing.md
                      : FamilyCompassSpacing.lg;
              return Align(
                alignment: AlignmentDirectional.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    key: const PageStorageKey<String>('chat.messages'),
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      horizontalPadding,
                      compactHeight
                          ? FamilyCompassSpacing.sm
                          : FamilyCompassSpacing.md,
                      horizontalPadding,
                      FamilyCompassSpacing.lg,
                    ),
                    children: <Widget>[
                      _ConversationDate(date: state.scenarioNow),
                      SizedBox(
                        height: compactHeight
                            ? FamilyCompassSpacing.sm
                            : FamilyCompassSpacing.md,
                      ),
                      for (final entry in timelineEntries) ...<Widget>[
                        entry.child,
                        const SizedBox(height: FamilyCompassSpacing.sm),
                      ],
                      if (pendingCompassPrompt != null) ...<Widget>[
                        const _PendingFamilyCompassView(),
                        const SizedBox(height: FamilyCompassSpacing.sm),
                      ],
                      if (familyRoomError case final message?) ...<Widget>[
                        _FamilyCompassErrorView(
                          message: message,
                          onRetry: onRetryCompass,
                        ),
                        const SizedBox(height: FamilyCompassSpacing.sm),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _ChatComposer(
          controller: composerController,
          focusNode: composerFocusNode,
          canSend: state.ui.chatDraft.trim().isNotEmpty &&
              (state.surfaceState != SurfaceState.offlineCached ||
                  controller.usesBackend),
          isOffline: state.surfaceState == SurfaceState.offlineCached,
          compactHeight: compactHeight,
          onSend: onSend,
          mentionCandidates: mentionCandidates,
          mentionChooserVisible: mentionChooserVisible,
          onMentionSelected: onMentionSelected,
        ),
      ],
    );
  }
}

class _ChatTimelineEntry {
  const _ChatTimelineEntry({
    required this.occurredAt,
    required this.sequence,
    required this.child,
  });

  final DateTime occurredAt;
  final int sequence;
  final Widget child;
}

class _LinkedChatItemView extends StatelessWidget {
  const _LinkedChatItemView({
    required this.anchorKey,
    required this.messageId,
    required this.highlighted,
    required this.child,
  });

  final GlobalKey anchorKey;
  final String messageId;
  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: anchorKey,
      child: Semantics(
        selected: highlighted,
        liveRegion: highlighted,
        child: AnimatedContainer(
          key: highlighted ? ValueKey('chat.linked.$messageId') : null,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(highlighted ? 3 : 0),
          decoration: highlighted
              ? BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.32),
                  borderRadius:
                      BorderRadius.circular(FamilyCompassRadii.medium),
                  border: Border.all(color: colors.primary, width: 2),
                )
              : null,
          child: child,
        ),
      ),
    );
  }
}

class _PendingFamilyCompassView extends StatelessWidget {
  const _PendingFamilyCompassView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    return Semantics(
      liveRegion: true,
      label: _copy(
        context,
        en: 'Compass is preparing a family-visible answer.',
        ar: 'تُعد البوصلة رداً ظاهراً للعائلة.',
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _CompassMentionMark(
                color: semantic.onSuccessContainer,
                background: semantic.successContainer,
              ),
              const SizedBox(width: FamilyCompassSpacing.xs),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: FamilyCompassSpacing.xs,
                        end: FamilyCompassSpacing.xs,
                        bottom: FamilyCompassSpacing.xxs,
                      ),
                      child: Text(
                        _copy(
                          context,
                          en: 'Compass · Visible to family',
                          ar: 'البوصلة · ظاهر للعائلة',
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Material(
                      key: const ValueKey('chat.compass.familyPending'),
                      color: semantic.successContainer,
                      borderRadius: const BorderRadiusDirectional.only(
                        topStart: Radius.circular(FamilyCompassRadii.medium),
                        topEnd: Radius.circular(FamilyCompassRadii.medium),
                        bottomStart: Radius.circular(FamilyCompassSpacing.xxs),
                        bottomEnd: Radius.circular(FamilyCompassRadii.medium),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FamilyCompassSpacing.md,
                          vertical: FamilyCompassSpacing.sm,
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: semantic.onSuccessContainer,
                              ),
                            ),
                            const SizedBox(width: FamilyCompassSpacing.sm),
                            Expanded(
                              child: Text(
                                _copy(
                                  context,
                                  en: 'Preparing a reply…',
                                  ar: 'جارٍ إعداد الرد…',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: semantic.onSuccessContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
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

class _FamilyCompassErrorView extends StatelessWidget {
  const _FamilyCompassErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    return DecoratedBox(
      key: const ValueKey('chat.compass.familyError'),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.xs,
          FamilyCompassSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              FamilyCompassIcons.errorOutlineRounded,
              color: semantic.onWarningContainer,
            ),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: semantic.onWarningContainer),
              ),
            ),
            if (onRetry != null)
              TextButton(
                key: const ValueKey('chat.compass.familyRetry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: semantic.onWarningContainer,
                ),
                child: Text(_copy(context, en: 'Retry', ar: 'إعادة المحاولة')),
              ),
          ],
        ),
      ),
    );
  }
}

class _FamilyRoomCompassArtifactView extends StatelessWidget {
  const _FamilyRoomCompassArtifactView({
    required this.anchorKey,
    required this.artifact,
    required this.onAction,
    super.key,
  });

  final GlobalKey anchorKey;
  final FamilyRoomCompassArtifact artifact;
  final ValueChanged<CompassAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final uncertainty = _uncertaintyLabel(context, artifact.uncertainty);
    final visibleCitations = artifact.citations
        .where(
          (citation) => citation.audience == CompassFactAudience.wholeFamily,
        )
        .toList(growable: false);
    final supportedActions =
        artifact.actions.where(_supportsCompassAction).toList(growable: false);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(artifact.createdAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return KeyedSubtree(
      key: anchorKey,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: _copy(
          context,
          en: 'Compass. Visible to family. $uncertainty.',
          ar: 'البوصلة. ظاهر للعائلة. $uncertainty.',
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _CompassMentionMark(
                  color: semantic.onSuccessContainer,
                  background: semantic.successContainer,
                ),
                const SizedBox(width: FamilyCompassSpacing.xs),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: FamilyCompassSpacing.xs,
                          end: FamilyCompassSpacing.xs,
                          bottom: FamilyCompassSpacing.xxs,
                        ),
                        child: Wrap(
                          spacing: FamilyCompassSpacing.xs,
                          runSpacing: FamilyCompassSpacing.xxs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              _copy(context, en: 'Compass', ar: 'البوصلة'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: semantic.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              _copy(
                                context,
                                en: 'Visible to family',
                                ar: 'ظاهر للعائلة',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                time,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        key: ValueKey(
                          'chat.compass.familyBubble.${artifact.id}',
                        ),
                        color: semantic.successContainer,
                        borderRadius: const BorderRadiusDirectional.only(
                          topStart: Radius.circular(FamilyCompassRadii.medium),
                          topEnd: Radius.circular(FamilyCompassRadii.medium),
                          bottomStart:
                              Radius.circular(FamilyCompassSpacing.xxs),
                          bottomEnd: Radius.circular(FamilyCompassRadii.medium),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            FamilyCompassSpacing.md,
                            FamilyCompassSpacing.sm,
                            FamilyCompassSpacing.sm,
                            FamilyCompassSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Directionality(
                                textDirection: _directionForText(
                                  artifact.answer,
                                  Directionality.of(context),
                                ),
                                child: Text(
                                  artifact.answer,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: semantic.onSuccessContainer,
                                      ),
                                ),
                              ),
                              const SizedBox(height: FamilyCompassSpacing.xs),
                              TextButton.icon(
                                key: ValueKey(
                                  'chat.compass.details.${artifact.id}',
                                ),
                                onPressed: () => _showCompassAnswerDetails(
                                  context,
                                  citations: visibleCitations,
                                  uncertainty: uncertainty,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: semantic.onSuccessContainer,
                                  minimumSize: const Size(
                                    FamilyCompassSizes.minimumTouchTarget,
                                    FamilyCompassSizes.minimumTouchTarget,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: FamilyCompassSpacing.xs,
                                  ),
                                ),
                                icon: const Icon(
                                  FamilyCompassIcons.factCheckOutlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _copy(
                                    context,
                                    en: 'Sources & details',
                                    ar: 'المصادر والتفاصيل',
                                  ),
                                ),
                              ),
                              if (supportedActions.isNotEmpty) ...<Widget>[
                                const SizedBox(
                                  height: FamilyCompassSpacing.xxs,
                                ),
                                Wrap(
                                  spacing: FamilyCompassSpacing.xs,
                                  runSpacing: FamilyCompassSpacing.xs,
                                  children: <Widget>[
                                    for (final action in supportedActions)
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                          'chat.compass.action.${artifact.id}.${action.kind.name}',
                                        ),
                                        onPressed: () => onAction(action),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              semantic.onSuccessContainer,
                                          side: BorderSide(
                                            color: semantic.onSuccessContainer
                                                .withValues(alpha: 0.34),
                                          ),
                                        ),
                                        icon: Icon(
                                          _compassActionIcon(action.kind),
                                        ),
                                        label: Text(
                                          _requiresCompassActionConfirmation(
                                            action,
                                          )
                                              ? _copy(
                                                  context,
                                                  en: '${action.label} · Confirm',
                                                  ar: '${action.label} · تأكيد',
                                                )
                                              : action.label,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showCompassAnswerDetails(
  BuildContext context, {
  required List<CompassCitation> citations,
  required String uncertainty,
}) {
  final expanded =
      MediaQuery.sizeOf(context).width >= FamilyCompassBreakpoints.mediumWidth;
  final content = _CompassSourcesDetails(
    citations: citations,
    uncertainty: uncertainty,
  );
  if (expanded) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: content,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => content,
  );
}

class _CompassSourcesDetails extends StatelessWidget {
  const _CompassSourcesDetails({
    required this.citations,
    required this.uncertainty,
  });

  final List<CompassCitation> citations;
  final String uncertainty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.sm,
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const ValueKey('chat.compass.sources.details'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _copy(
                context,
                en: 'About this answer',
                ar: 'حول هذا الرد',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              _copy(
                context,
                en: 'Only information your family allowed Compass to use appears here.',
                ar: 'يظهر هنا فقط ما سمحت العائلة للبوصلة باستخدامه.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            _CompassDetailRow(
              icon: FamilyCompassIcons.infoOutlineRounded,
              label: _copy(context, en: 'Confidence', ar: 'درجة الثقة'),
              value: uncertainty,
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(
              _copy(
                context,
                en: 'Sources used',
                ar: 'المصادر المستخدمة',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            if (citations.isEmpty)
              Text(
                _copy(
                  context,
                  en: 'No permitted family source was available.',
                  ar: 'لم يتوفر مصدر عائلي مسموح.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              )
            else
              for (var index = 0;
                  index < citations.length;
                  index++) ...<Widget>[
                _CompassCitationRow(citation: citations[index]),
                if (index != citations.length - 1)
                  Divider(color: colors.outlineVariant),
              ],
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_copy(context, en: 'Done', ar: 'تم')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDetailRow extends StatelessWidget {
  const _CompassDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompassCitationRow extends StatelessWidget {
  const _CompassCitationRow({required this.citation});

  final CompassCitation citation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metadata = <String>[
      _freshnessLabel(context, citation),
      _audienceLabel(context, citation.audience),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: FamilyCompassSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            FamilyCompassIcons.factCheckOutlined,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: FamilyCompassSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  citation.sourceLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  metadata,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final semantic = FamilyCompassSemanticColors.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackAction =
        MediaQuery.sizeOf(context).width < 430 || textScale >= 1.5;
    final message = _copy(
      context,
      en: state.retryFailed
          ? 'Couldn\'t reconnect. Your saved messages are still here.'
          : 'Offline. Showing messages saved at 6:00 PM.',
      ar: state.retryFailed
          ? 'تعذر الاتصال. ما زالت رسائلك المحفوظة متاحة.'
          : 'أنت غير متصل. نعرض الرسائل المحفوظة عند 6:00 م.',
    );
    final retry = TextButton(
      key: const ValueKey('chat.offline.retry'),
      onPressed: state.isRetrying ? null : controller.retryOffline,
      style: TextButton.styleFrom(
        foregroundColor: semantic.onWarningContainer,
        minimumSize: const Size(48, 48),
      ),
      child: Text(
        state.isRetrying
            ? _copy(context, en: 'Retrying…', ar: 'جارٍ الاتصال…')
            : _copy(context, en: 'Retry', ar: 'إعادة المحاولة'),
      ),
    );
    return Material(
      color: semantic.warningContainer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            FamilyCompassSpacing.md,
            stackAction ? FamilyCompassSpacing.sm : 0,
            FamilyCompassSpacing.sm,
            stackAction ? FamilyCompassSpacing.xs : 0,
          ),
          child: stackAction
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            FamilyCompassIcons.cloudOffOutlined,
                            color: semantic.onWarningContainer,
                          ),
                        ),
                        const SizedBox(width: FamilyCompassSpacing.sm),
                        Expanded(
                          child: Text(
                            message,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: semantic.onWarningContainer,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: retry,
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Icon(
                      FamilyCompassIcons.cloudOffOutlined,
                      color: semantic.onWarningContainer,
                    ),
                    const SizedBox(width: FamilyCompassSpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: semantic.onWarningContainer,
                            ),
                      ),
                    ),
                    retry,
                  ],
                ),
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
      color: colors.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FamilyCompassSpacing.md,
            vertical: FamilyCompassSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Icon(FamilyCompassIcons.exploreOutlined,
                  color: colors.onSurfaceVariant),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Text(
                  _copy(
                    context,
                    en: 'Compass is unavailable. Messages and plans still work.',
                    ar: 'البوصلة غير متاحة. ما زالت الرسائل والخطط تعمل.',
                  ),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationDate extends StatelessWidget {
  const _ConversationDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = MaterialLocalizations.of(context).formatFullDate(date);
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: colors.outlineVariant)),
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FamilyCompassSpacing.sm,
            ),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.outlineVariant)),
      ],
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
    final member = item.authorId == 'compass'
        ? null
        : controller.memberForId(item.authorId);
    return switch (item.kind) {
      ChatItemKind.message => _HumanMessageBubble(
          key: ValueKey('chat.message.${item.id}'),
          author: member?.name ?? item.authorId,
          initials: member?.initials ?? '?',
          text: item.text,
          sentAt: item.sentAt,
          isMine: item.authorId == controller.currentUserId,
          deliveryState: item.deliveryState,
        ),
      ChatItemKind.compassDraft => _CompassDraftAnnotation(
          key: const ValueKey('chat.compassDraft.fridayDinner'),
          item: item,
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.poll => _PollFolio(
          key: ValueKey('plan.${item.referenceId ?? 'friday-dinner'}.poll'),
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.confirmedPlan => _ConfirmedPlanFolio(
          key: ValueKey(
            'plan.${item.referenceId ?? 'friday-dinner'}.confirmed',
          ),
          plan: state.plan,
          controller: controller,
        ),
      ChatItemKind.checkInRequest => _SystemRecordRow(
          key: const ValueKey('chat.checkIn.requested'),
          icon: FamilyCompassIcons.markChatUnreadOutlined,
          label: _copy(
            context,
            en: 'Check-in requested',
            ar: 'تم طلب الاطمئنان',
          ),
          text: item.text,
          source: _copy(
            context,
            en: 'Sent by Abdullah · Family visible',
            ar: 'أرسله عبدالله · ظاهر للعائلة',
          ),
        ),
      ChatItemKind.checkInResponse => _SystemRecordRow(
          key: const ValueKey('chat.checkIn.responded'),
          icon: FamilyCompassIcons.checkCircleOutlineRounded,
          label: _copy(context, en: 'Sara replied', ar: 'ردّت سارة'),
          text: item.text,
          source: _copy(
            context,
            en: 'Shared by Sara · Family visible',
            ar: 'شاركته سارة · ظاهر للعائلة',
          ),
        ),
      ChatItemKind.reminderDraft => _ReminderDraftFolio(
          key: const ValueKey('chat.reminder.draft'),
          text: item.text,
          date: item.sentAt,
          controller: controller,
        ),
      ChatItemKind.reminderConfirmed => _SystemRecordRow(
          key: const ValueKey('chat.reminder.confirmed'),
          icon: FamilyCompassIcons.alarmOnOutlined,
          label: _copy(
            context,
            en: 'Personal reminder',
            ar: 'تذكير شخصي',
          ),
          text: item.text,
          source: _copy(
            context,
            en: 'Confirmed by you · Only you',
            ar: 'أكدته أنت · لك فقط',
          ),
        ),
    };
  }
}

class _HumanMessageBubble extends StatelessWidget {
  const _HumanMessageBubble({
    required this.author,
    required this.initials,
    required this.text,
    required this.isMine,
    this.deliveryState = ChatDeliveryState.sent,
    this.sentAt,
    super.key,
  });

  final String author;
  final String initials;
  final String text;
  final DateTime? sentAt;
  final bool isMine;
  final ChatDeliveryState deliveryState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ambientDirection = Directionality.of(context);
    final messageDirection = _directionForText(text, ambientDirection);
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
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
            child: Wrap(
              spacing: FamilyCompassSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  author,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (sentAt != null)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(sentAt!),
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ),
                if (isMine) _MessageDeliveryLabel(deliveryState: deliveryState),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: isMine
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(FamilyCompassRadii.medium),
                topEnd: const Radius.circular(FamilyCompassRadii.medium),
                bottomStart: Radius.circular(
                  isMine ? FamilyCompassRadii.medium : FamilyCompassSpacing.xxs,
                ),
                bottomEnd: Radius.circular(
                  isMine ? FamilyCompassSpacing.xxs : FamilyCompassRadii.medium,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FamilyCompassSpacing.md,
                vertical: FamilyCompassSpacing.sm,
              ),
              child: Directionality(
                textDirection: messageDirection,
                child: Text(
                  text,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isMine
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isMine) ...<Widget>[
            MemberMark(
              initial: initials,
              size: 28,
              semanticLabel: author,
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _MessageDeliveryLabel extends StatelessWidget {
  const _MessageDeliveryLabel({required this.deliveryState});

  final ChatDeliveryState deliveryState;

  @override
  Widget build(BuildContext context) {
    final failed = deliveryState == ChatDeliveryState.failed;
    final waiting = deliveryState == ChatDeliveryState.waitingToSend;
    final label = failed
        ? _copy(context, en: 'Not sent · Retry', ar: 'لم تُرسل · أعد المحاولة')
        : waiting
            ? _copy(context, en: 'Waiting to send', ar: 'بانتظار الإرسال')
            : _copy(context, en: 'Sent', ar: 'تم الإرسال');
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        key: ValueKey<String>(
          failed
              ? 'chat.message.failed'
              : waiting
                  ? 'chat.message.waiting'
                  : 'chat.message.sent',
        ),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            failed
                ? FamilyCompassIcons.errorOutlineRounded
                : waiting
                    ? FamilyCompassIcons.scheduleOutlined
                    : FamilyCompassIcons.checkRounded,
            size: 14,
            color: failed ? colors.error : colors.onSurfaceVariant,
          ),
          const SizedBox(width: FamilyCompassSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: failed ? colors.error : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _DinnerOpportunityAnnotation extends StatelessWidget {
  const _DinnerOpportunityAnnotation({required this.controller});

  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    return _CompassAnnotation(
      key: const ValueKey('chat.compassOpportunity.fridayDinner'),
      label: _copy(
        context,
        en: 'Compass · Family visible',
        ar: 'البوصلة · ظاهر للعائلة',
      ),
      message: _copy(
        context,
        en: 'Would a two-time dinner poll help settle Friday?',
        ar: 'هل يساعد تصويت بموعدين على تثبيت عشاء الجمعة؟',
      ),
      source: _copy(
        context,
        en: 'Based on Mom and Dad’s messages · No action taken',
        ar: 'بناءً على رسالتي الأم والأب · لم يُتخذ أي إجراء',
      ),
      action: TextButton.icon(
        key: const ValueKey('chat.turnIntoPlan'),
        onPressed: controller.draftFridayDinner,
        icon: const Icon(FamilyCompassIcons.eventAvailableOutlined),
        label: Text(
          _copy(context, en: 'Turn into a plan', ar: 'تحويل إلى خطة'),
        ),
      ),
    );
  }
}

class _CompassDraftAnnotation extends StatelessWidget {
  const _CompassDraftAnnotation({
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
    final canReview = plan?.phase == PlanPhase.draft;
    return _CompassAnnotation(
      label: _copy(
        context,
        en: 'Compass draft · Family visible',
        ar: 'مسودة البوصلة · ظاهرة للعائلة',
      ),
      message: item.text,
      source: canReview
          ? _copy(
              context,
              en: 'Drafted from this conversation · Nothing sent',
              ar: 'مسودة من هذه المحادثة · لم يُرسل شيء',
            )
          : _copy(
              context,
              en: 'Reviewed by Abdullah · Sent as the poll below',
              ar: 'راجعها عبدالله · أُرسلت كالتصويت أدناه',
            ),
      action: canReview
          ? TextButton(
              key: const ValueKey('chat.reviewPlan'),
              onPressed: () => _showPlanReview(context, plan!, controller),
              child: Text(
                _copy(context, en: 'Review plan', ar: 'مراجعة الخطة'),
              ),
            )
          : null,
    );
  }
}

class _CompassAnnotation extends StatelessWidget {
  const _CompassAnnotation({
    required this.label,
    required this.message,
    required this.source,
    this.action,
    super.key,
  });

  final String label;
  final String message;
  final String source;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.symmetric(
            horizontal: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            FamilyCompassSpacing.md,
            FamilyCompassSpacing.sm,
            FamilyCompassSpacing.xs,
            FamilyCompassSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: FamilyCompassSpacing.xxs),
                  child: Icon(
                    FamilyCompassIcons.exploreOutlined,
                    size: 22,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: FamilyCompassSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      container: true,
                      label: '$label. $message. $source',
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(
                              height: FamilyCompassSpacing.xxs,
                            ),
                            Text(message),
                            const SizedBox(height: FamilyCompassSpacing.xs),
                            Text(
                              source,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (action != null) ...<Widget>[
                      const SizedBox(height: FamilyCompassSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: action!,
                      ),
                    ],
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

Future<void> _showPlanReview(
  BuildContext context,
  FamilyPlan plan,
  PrototypeScenarioController controller,
) {
  final expanded =
      MediaQuery.sizeOf(context).width >= FamilyCompassBreakpoints.mediumWidth;
  if (expanded) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: _PlanReviewBody(
            plan: plan,
            controller: controller,
            closeContext: dialogContext,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _PlanReviewBody(
      plan: plan,
      controller: controller,
      closeContext: sheetContext,
    ),
  );
}

class _PlanReviewBody extends StatelessWidget {
  const _PlanReviewBody({
    required this.plan,
    required this.controller,
    required this.closeContext,
  });

  final FamilyPlan plan;
  final PrototypeScenarioController controller;
  final BuildContext closeContext;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.md,
          FamilyCompassSpacing.lg,
          FamilyCompassSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const ValueKey('chat.planReview'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _copy(
                context,
                en: 'Review family plan',
                ar: 'مراجعة خطة العائلة',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              _copy(
                context,
                en: 'Compass prepared the draft. You choose whether the family receives it.',
                ar: 'أعدّت البوصلة المسودة. أنت تختار إن كانت العائلة ستستلمها.',
              ),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: FamilyCompassSpacing.lg),
            FolioSurface(
              padding: const EdgeInsets.all(FamilyCompassSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _displayPlanTitle(context, plan),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: FamilyCompassSpacing.xs),
                  Text(_displayPlanDescription(context, plan)),
                  const SizedBox(height: FamilyCompassSpacing.md),
                  SourceLine(
                    source: _copy(
                      context,
                      en: 'Abdullah, Dad, Mom, and Sara',
                      ar: 'عبدالله والأب والأم وسارة',
                    ),
                    freshness: _copy(
                      context,
                      en: '4 selected adults',
                      ar: '4 بالغين محددين',
                    ),
                    icon: FamilyCompassIcons.peopleOutlineRounded,
                  ),
                  const SizedBox(height: FamilyCompassSpacing.sm),
                  for (final candidate in plan.candidateTimes)
                    _ReviewTimeRow(
                      label: _formatCandidate(context, material, candidate),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.md),
            Text(
              _copy(
                context,
                en: 'Nothing is sent until you tap Send poll.',
                ar: 'لن يُرسل شيء قبل الضغط على إرسال التصويت.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('chat.sendPoll'),
              onPressed: () {
                controller.sendPoll();
                Navigator.of(closeContext).pop();
              },
              icon: const Icon(FamilyCompassIcons.howToVoteOutlined),
              label: Text(
                _copy(context, en: 'Send poll', ar: 'إرسال التصويت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTimeRow extends StatelessWidget {
  const _ReviewTimeRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: FamilyCompassSizes.minimumTouchTarget,
      ),
      child: Row(
        children: <Widget>[
          Icon(FamilyCompassIcons.scheduleOutlined, color: colors.primary),
          const SizedBox(width: FamilyCompassSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _PollFolio extends StatelessWidget {
  const _PollFolio({required this.plan, required this.controller, super.key});

  final FamilyPlan? plan;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    if (currentPlan == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final material = MaterialLocalizations.of(context);
    final hasResponded =
        currentPlan.responses.containsKey(controller.currentUserId);
    final isOpen = currentPlan.phase == PlanPhase.pollOpen ||
        currentPlan.phase == PlanPhase.readyToConfirm;
    final responseCandidateId =
        currentPlan.responses[controller.currentUserId]?.candidateId;
    final actionCandidate = _candidateForPlanAction(
      currentPlan,
      preferredId: responseCandidateId,
    );
    final actionTime = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(actionCandidate.startsAt),
    );
    final actionDate = material.formatMediumDate(actionCandidate.startsAt);

    return _DatedFolio(
      date: currentPlan.candidateTimes.first.startsAt,
      semanticLabel: _copy(
        context,
        en: 'Family dinner poll',
        ar: 'تصويت عشاء العائلة',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ArtifactLabel(
            icon: FamilyCompassIcons.howToVoteOutlined,
            text: isOpen
                ? _copy(context, en: 'Family poll', ar: 'تصويت العائلة')
                : _copy(context, en: 'Poll closed', ar: 'أُغلق التصويت'),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            context.l10n.pollDinnerQuestion,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: FamilyCompassSpacing.md),
          for (final candidate in currentPlan.candidateTimes)
            _CandidatePollRow(
              label: _formatCandidate(context, material, candidate),
              responseCount: currentPlan.responses.values
                  .where((response) => response.candidateId == candidate.id)
                  .length,
              selected: currentPlan
                      .responses[controller.currentUserId]?.candidateId ==
                  candidate.id,
            ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            context.l10n.pollResponsesCount(currentPlan.responses.length),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          SourceLine(
            source: _copy(
              context,
              en: 'Sent by Abdullah · Family visible',
              ar: 'أرسله عبدالله · ظاهر للعائلة',
            ),
            freshness: isOpen
                ? _copy(context, en: 'Open', ar: 'مفتوح')
                : _copy(context, en: 'Closed', ar: 'مغلق'),
            icon: FamilyCompassIcons.peopleOutlineRounded,
          ),
          if (isOpen && !hasResponded) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.md),
            FilledButton.icon(
              key: const ValueKey('poll.fridayDinner.respond1930'),
              onPressed: controller.submitAbdullahResponse,
              icon: const Icon(FamilyCompassIcons.checkCircleOutlineRounded),
              label: Text(
                _copy(
                  context,
                  en: 'Going at $actionTime',
                  ar: 'سأحضر الساعة $actionTime',
                ),
              ),
            ),
          ],
          if (isOpen && hasResponded) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.md),
            _InlineStatus(
              icon: FamilyCompassIcons.checkCircleOutlineRounded,
              text: _copy(
                context,
                en: 'You replied: Going at $actionTime',
                ar: 'ردّك: سأحضر الساعة $actionTime',
              ),
            ),
            const SizedBox(height: FamilyCompassSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('poll.fridayDinner.nudge'),
              onPressed: currentPlan.nudgeSent || controller.isPollNudgeInFlight
                  ? null
                  : controller.sendPollNudge,
              icon: const Icon(FamilyCompassIcons.notificationsActiveOutlined),
              label: Text(
                controller.isPollNudgeInFlight
                    ? _copy(
                        context,
                        en: 'Sending nudge…',
                        ar: 'جارٍ إرسال التذكير…',
                      )
                    : currentPlan.nudgeSent
                        ? _copy(context, en: 'Nudge sent', ar: 'أُرسل التذكير')
                        : currentPlan.nudgeDeliveryFailed
                            ? _copy(
                                context,
                                en: 'Try nudge again',
                                ar: 'حاول إرسال التذكير مجددًا',
                              )
                            : _copy(
                                context,
                                en: 'Nudge Sara',
                                ar: 'تذكير سارة',
                              ),
              ),
            ),
          ],
          if (currentPlan.phase == PlanPhase.readyToConfirm) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('poll.fridayDinner.confirm1930'),
              onPressed: controller.confirmDinner,
              icon: const Icon(FamilyCompassIcons.eventAvailableOutlined),
              label: Text(
                _copy(
                  context,
                  en: 'Confirm $actionDate at $actionTime',
                  ar: 'تأكيد $actionDate الساعة $actionTime',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidatePollRow extends StatelessWidget {
  const _CandidatePollRow({
    required this.label,
    required this.responseCount,
    required this.selected,
  });

  final String label;
  final int responseCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? FamilyCompassIcons.checkCircleRounded
                  : FamilyCompassIcons.radioButtonUncheckedRounded,
              size: 20,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(child: Text(label)),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Text(
              _copy(
                context,
                en: '$responseCount ${responseCount == 1 ? 'reply' : 'replies'}',
                ar: '$responseCount رد',
              ),
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

class _ConfirmedPlanFolio extends StatelessWidget {
  const _ConfirmedPlanFolio({
    required this.plan,
    required this.controller,
    super.key,
  });

  final FamilyPlan? plan;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    if (currentPlan == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final material = MaterialLocalizations.of(context);
    final reminderState = controller.state.separateReminderState;
    final confirmedTime = currentPlan.confirmedTime;
    final displayDate =
        confirmedTime?.startsAt ?? currentPlan.candidateTimes.last.startsAt;
    final timeLabel = confirmedTime == null
        ? _copy(context, en: 'Time pending', ar: 'الوقت قيد التحديد')
        : material.formatTimeOfDay(
            TimeOfDay.fromDateTime(confirmedTime.startsAt),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );

    return _DatedFolio(
      date: displayDate,
      semanticLabel: _copy(
        context,
        en: '${_displayPlanTitle(context, currentPlan)} confirmed for ${material.formatFullDate(displayDate)} at $timeLabel',
        ar: 'تم تأكيد ${_displayPlanTitle(context, currentPlan)} في ${material.formatFullDate(displayDate)} الساعة $timeLabel',
      ),
      backgroundColor: semantic.successContainer,
      borderColor: semantic.success.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ArtifactLabel(
            icon: FamilyCompassIcons.checkCircleRounded,
            text: _copy(
              context,
              en: 'Confirmed family plan',
              ar: 'خطة عائلية مؤكدة',
            ),
            color: semantic.onSuccessContainer,
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(
            '${_displayPlanTitle(context, currentPlan)} · $timeLabel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: semantic.onSuccessContainer,
                ),
          ),
          if (currentPlan.reminders.isNotEmpty) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  FamilyCompassIcons.notificationsNoneRounded,
                  size: 20,
                  color: semantic.onSuccessContainer,
                ),
                const SizedBox(width: FamilyCompassSpacing.xs),
                Expanded(
                  child: Text(
                    _copy(
                      context,
                      en: 'Automatic reminder: ${currentPlan.reminders.first.label}',
                      ar: 'تذكير تلقائي: يبدأ عشاء العائلة بعد ساعتين',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: semantic.onSuccessContainer,
                        ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: FamilyCompassSpacing.sm),
          SourceLine(
            source: _copy(
              context,
              en: 'Confirmed by Abdullah · Family visible',
              ar: 'أكده عبدالله · ظاهر للعائلة',
            ),
            freshness: _copy(
              context,
              en: '${currentPlan.attendingCount} going',
              ar: '${currentPlan.attendingCount} سيحضرون',
            ),
            icon: FamilyCompassIcons.peopleOutlineRounded,
          ),
          if (reminderState == SeparateReminderState.none) ...<Widget>[
            const SizedBox(height: FamilyCompassSpacing.xs),
            TextButton.icon(
              key: const ValueKey('chat.reminder.draftAction'),
              onPressed: controller.draftSeparateReminder,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
              ),
              icon: const Icon(FamilyCompassIcons.alarmAddOutlined),
              label: Text(
                _copy(
                  context,
                  en: 'Draft a personal dessert reminder',
                  ar: 'مسودة تذكير شخصي للحلوى',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderDraftFolio extends StatelessWidget {
  const _ReminderDraftFolio({
    required this.text,
    required this.date,
    required this.controller,
    super.key,
  });

  final String text;
  final DateTime date;
  final PrototypeScenarioController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _DatedFolio(
      date: date,
      semanticLabel: _copy(
        context,
        en: 'Personal reminder draft',
        ar: 'مسودة تذكير شخصي',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ArtifactLabel(
            icon: FamilyCompassIcons.alarmAddOutlined,
            text: _copy(
              context,
              en: 'Personal reminder draft',
              ar: 'مسودة تذكير شخصي',
            ),
          ),
          const SizedBox(height: FamilyCompassSpacing.xs),
          Text(text),
          const SizedBox(height: FamilyCompassSpacing.xs),
          SourceLine(
            source: _copy(
              context,
              en: 'Prepared by Compass · Only you',
              ar: 'أعدّتها البوصلة · لك فقط',
            ),
            freshness: _copy(
              context,
              en: 'Not created',
              ar: 'لم يتم إنشاؤه',
            ),
            icon: FamilyCompassIcons.lockOutlineRounded,
          ),
          const SizedBox(height: FamilyCompassSpacing.sm),
          FilledButton(
            key: const ValueKey('chat.reminder.confirm'),
            onPressed: controller.confirmSeparateReminder,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            child: Text(
              _copy(context, en: 'Confirm reminder', ar: 'تأكيد التذكير'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatedFolio extends StatelessWidget {
  const _DatedFolio({
    required this.date,
    required this.semanticLabel,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final DateTime date;
  final String semanticLabel;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final semantic = FamilyCompassSemanticColors.of(context);
    final material = MaterialLocalizations.of(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: FolioSurface(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ColoredBox(
              color: semantic.gatheringContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FamilyCompassSpacing.md,
                  vertical: FamilyCompassSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      FamilyCompassIcons.calendarTodayOutlined,
                      size: 17,
                      color: semantic.onGatheringContainer,
                    ),
                    const SizedBox(width: FamilyCompassSpacing.xs),
                    Expanded(
                      child: Text(
                        material.formatFullDate(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: semantic.onGatheringContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FamilyCompassSpacing.md),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactLabel extends StatelessWidget {
  const _ArtifactLabel({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: <Widget>[
        Icon(icon, color: foreground, size: 20),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _SystemRecordRow extends StatelessWidget {
  const _SystemRecordRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.source,
    super.key,
  });

  final IconData icon;
  final String label;
  final String text;
  final String source;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FlatActionRow(
      leading: Icon(icon, color: colors.primary),
      title: label,
      body: '$text\n$source',
      padding: const EdgeInsets.symmetric(
        vertical: FamilyCompassSpacing.sm,
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
    final semantic = FamilyCompassSemanticColors.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: semantic.success),
        const SizedBox(width: FamilyCompassSpacing.xs),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isOffline,
    required this.compactHeight,
    required this.onSend,
    required this.mentionCandidates,
    required this.mentionChooserVisible,
    required this.onMentionSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isOffline;
  final bool compactHeight;
  final VoidCallback onSend;
  final List<_MentionCandidate> mentionCandidates;
  final bool mentionChooserVisible;
  final ValueChanged<_MentionCandidate> onMentionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    return Material(
      color: colors.surface,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          FamilyCompassSpacing.sm,
          compactHeight ? FamilyCompassSpacing.xxs : FamilyCompassSpacing.xs,
          FamilyCompassSpacing.sm,
          compactHeight ? FamilyCompassSpacing.xxs : FamilyCompassSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (mentionChooserVisible) ...<Widget>[
              _MentionChooser(
                candidates: mentionCandidates,
                onSelected: onMentionSelected,
              ),
              const SizedBox(height: FamilyCompassSpacing.xs),
            ],
            if (isOffline)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: FamilyCompassSpacing.xxs,
                ),
                child: Text(
                  _copy(
                    context,
                    en: 'Messages will wait here and send after you reconnect.',
                    ar: 'ستنتظر الرسائل هنا وتُرسل بعد عودة الاتصال.',
                  ),
                  key: const ValueKey('chat.composer.offlineStatus'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: _copy(
                      context,
                      en: 'Message your family',
                      ar: 'رسالة إلى عائلتك',
                    ),
                    hint: _copy(
                      context,
                      en: 'Type @ to mention Compass or a family member.',
                      ar: 'اكتب @ للإشارة إلى البوصلة أو أحد أفراد العائلة.',
                    ),
                    child: TextField(
                      key: const ValueKey('chat.composer.input'),
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: compactHeight ? 2 : 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: _copy(
                          context,
                          en: 'Message your family',
                          ar: 'اكتب رسالة للعائلة',
                        ),
                        prefixIcon: Icon(
                          FamilyCompassIcons.chatBubbleOutlineRounded,
                          color: semantic.gatheringInk,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: FamilyCompassSpacing.xs),
                SizedBox.square(
                  dimension: FamilyCompassSizes.minimumTouchTarget,
                  child: IconButton.filled(
                    key: const ValueKey('chat.composer.send'),
                    tooltip: _copy(
                      context,
                      en: 'Send message',
                      ar: 'إرسال الرسالة',
                    ),
                    onPressed: canSend ? onSend : null,
                    icon: const Icon(FamilyCompassIcons.sendRounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MentionChooser extends StatelessWidget {
  const _MentionChooser({
    required this.candidates,
    required this.onSelected,
  });

  final List<_MentionCandidate> candidates;
  final ValueChanged<_MentionCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _copy(
        context,
        en: 'Mention suggestions',
        ar: 'اقتراحات الإشارة',
      ),
      child: DecoratedBox(
        key: const ValueKey('chat.mention.chooser'),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(FamilyCompassRadii.medium),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 244),
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(FamilyCompassSpacing.md),
                  child: Text(
                    _copy(
                      context,
                      en: 'No family member matches that name.',
                      ar: 'لا يوجد فرد من العائلة بهذا الاسم.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('chat.mention.options'),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    vertical: FamilyCompassSpacing.xxs,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => Divider(
                    indent: 60,
                    height: 1,
                    color: colors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    final isCompass = candidate.isCompass;
                    return Semantics(
                      button: true,
                      label: _copy(
                        context,
                        en: 'Mention ${candidate.label}. ${candidate.supportingLabel}',
                        ar: 'أشر إلى ${candidate.label}. ${candidate.supportingLabel}',
                      ),
                      child: InkWell(
                        key: ValueKey('chat.mention.${candidate.id}'),
                        onTap: () => onSelected(candidate),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: FamilyCompassSizes.minimumTouchTarget,
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              FamilyCompassSpacing.sm,
                              FamilyCompassSpacing.xs,
                              FamilyCompassSpacing.md,
                              FamilyCompassSpacing.xs,
                            ),
                            child: Row(
                              children: <Widget>[
                                if (isCompass)
                                  _CompassMentionMark(
                                    color: semantic.onSuccessContainer,
                                    background: semantic.successContainer,
                                  )
                                else
                                  MemberMark(
                                    initial: candidate.initials,
                                    size: 36,
                                    semanticLabel: candidate.label,
                                  ),
                                const SizedBox(width: FamilyCompassSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        candidate.handle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: isCompass
                                                  ? semantic.onSuccessContainer
                                                  : colors.onSurface,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        candidate.supportingLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
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
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _CompassMentionMark extends StatelessWidget {
  const _CompassMentionMark({
    required this.color,
    required this.background,
  });

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(
          FamilyCompassIcons.compassFilled,
          color: color,
          size: 21,
        ),
      ),
    );
  }
}

class _ConversationContextPane extends StatelessWidget {
  const _ConversationContextPane({
    required this.state,
    required this.compactHeight,
    required this.members,
  });

  final PrototypeScenarioState state;
  final bool compactHeight;
  final List<FamilyMember> members;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plan = state.plan;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          compactHeight ? FamilyCompassSpacing.md : FamilyCompassSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _copy(
                context,
                en: 'Conversation details',
                ar: 'تفاصيل المحادثة',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: FamilyCompassSpacing.xs),
            Text(
              _copy(
                context,
                en: 'The plan stays beside the messages on larger screens.',
                ar: 'تبقى الخطة بجوار الرسائل على الشاشات الأكبر.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            if (plan != null) ...<Widget>[
              SizedBox(
                height: compactHeight
                    ? FamilyCompassSpacing.md
                    : FamilyCompassSpacing.lg,
              ),
              _ContextPlanSummary(plan: plan),
              const SizedBox(height: FamilyCompassSpacing.lg),
              Text(
                _copy(context, en: 'Replies', ar: 'الردود'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: FamilyCompassSpacing.xs),
              for (final member in members)
                _ParticipantReplyRow(
                  name: member.name,
                  initials: member.initials,
                  hasReplied: plan.responses.containsKey(member.id),
                  isCoordinator: member.id == plan.coordinatorId,
                ),
            ] else ...<Widget>[
              const SizedBox(height: FamilyCompassSpacing.lg),
              Text(
                _copy(
                  context,
                  en: 'There is no active family plan in this conversation.',
                  ar: 'لا توجد خطة عائلية نشطة في هذه المحادثة.',
                ),
              ),
            ],
            const SizedBox(height: FamilyCompassSpacing.lg),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: FamilyCompassSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(FamilyCompassIcons.verifiedUserOutlined,
                    color: colors.primary),
                const SizedBox(width: FamilyCompassSpacing.sm),
                Expanded(
                  child: Text(
                    _copy(
                      context,
                      en: 'Compass may prepare a suggestion. A family member must send or confirm it.',
                      ar: 'يمكن للبوصلة إعداد اقتراح. يجب أن يرسله أو يؤكده أحد أفراد العائلة.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextPlanSummary extends StatelessWidget {
  const _ContextPlanSummary({required this.plan});

  final FamilyPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date =
        plan.confirmedTime?.startsAt ?? plan.candidateTimes.last.startsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ArtifactLabel(
          icon: _planPhaseIcon(plan.phase),
          text: _planPhaseLabel(context, plan.phase),
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          _displayPlanTitle(context, plan),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: FamilyCompassSpacing.xs),
        Text(
          MaterialLocalizations.of(context).formatMediumDate(date),
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: FamilyCompassSpacing.sm),
        SourceLine(
          source: _copy(
            context,
            en: 'From this family conversation',
            ar: 'من محادثة العائلة هذه',
          ),
          freshness: _copy(context, en: 'Current', ar: 'حالي'),
          icon: FamilyCompassIcons.forumOutlined,
        ),
      ],
    );
  }
}

class _ParticipantReplyRow extends StatelessWidget {
  const _ParticipantReplyRow({
    required this.name,
    required this.initials,
    required this.hasReplied,
    required this.isCoordinator,
  });

  final String name;
  final String initials;
  final bool hasReplied;
  final bool isCoordinator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = FamilyCompassSemanticColors.of(context);
    final label = hasReplied
        ? _copy(context, en: 'Replied', ar: 'ردّ')
        : isCoordinator
            ? _copy(context, en: 'Coordinator', ar: 'المنسق')
            : _copy(context, en: 'Waiting', ar: 'بانتظار الرد');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: FamilyCompassSizes.minimumTouchTarget,
        ),
        child: Row(
          children: <Widget>[
            MemberMark(initial: initials, size: 28, semanticLabel: name),
            const SizedBox(width: FamilyCompassSpacing.sm),
            Expanded(child: Text(name)),
            Icon(
              hasReplied
                  ? FamilyCompassIcons.checkCircleOutlineRounded
                  : isCoordinator
                      ? FamilyCompassIcons.editCalendarOutlined
                      : FamilyCompassIcons.scheduleOutlined,
              size: 18,
              color: hasReplied ? semantic.success : colors.onSurfaceVariant,
            ),
            const SizedBox(width: FamilyCompassSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        hasReplied ? semantic.success : colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCandidate(
  BuildContext context,
  MaterialLocalizations material,
  CandidateTime candidate,
) {
  final date = material.formatMediumDate(candidate.startsAt);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(candidate.startsAt),
  );
  return _copy(
    context,
    en: '$date · $time',
    ar: '$date، $time',
  );
}

CandidateTime _candidateForPlanAction(
  FamilyPlan plan, {
  String? preferredId,
}) {
  return plan.candidateById(preferredId) ??
      plan.displayCandidate() ??
      plan.candidateTimes.first;
}

String _displayPlanTitle(BuildContext context, FamilyPlan plan) {
  if (plan.id == 'friday-dinner') {
    return _copy(
      context,
      en: plan.title,
      ar: 'عشاء العائلة يوم الجمعة',
    );
  }
  return plan.title;
}

String _displayPlanDescription(BuildContext context, FamilyPlan plan) {
  if (plan.id == 'friday-dinner') {
    return _copy(
      context,
      en: plan.description,
      ar: 'عشاء معًا في المنزل',
    );
  }
  return plan.description;
}

String _planPhaseLabel(BuildContext context, PlanPhase phase) =>
    switch (phase) {
      PlanPhase.opportunity =>
        _copy(context, en: 'Suggested next step', ar: 'خطوة مقترحة'),
      PlanPhase.draft =>
        _copy(context, en: 'Draft for review', ar: 'مسودة للمراجعة'),
      PlanPhase.pollOpen =>
        _copy(context, en: 'Poll open', ar: 'التصويت مفتوح'),
      PlanPhase.readyToConfirm =>
        _copy(context, en: 'Ready to confirm', ar: 'جاهز للتأكيد'),
      PlanPhase.confirmed => _copy(context, en: 'Confirmed', ar: 'مؤكد'),
      PlanPhase.completed => _copy(context, en: 'Completed', ar: 'مكتمل'),
    };

IconData _planPhaseIcon(PlanPhase phase) => switch (phase) {
      PlanPhase.opportunity => FamilyCompassIcons.lightbulbOutlineRounded,
      PlanPhase.draft => FamilyCompassIcons.editCalendarOutlined,
      PlanPhase.pollOpen => FamilyCompassIcons.howToVoteOutlined,
      PlanPhase.readyToConfirm => FamilyCompassIcons.ruleRounded,
      PlanPhase.confirmed => FamilyCompassIcons.eventAvailableOutlined,
      PlanPhase.completed => FamilyCompassIcons.taskAltRounded,
    };

TextDirection _directionForText(String text, TextDirection fallback) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A)) {
      return TextDirection.ltr;
    }
  }
  return fallback;
}

class _MentionTrigger {
  const _MentionTrigger({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is _MentionTrigger &&
      other.start == start &&
      other.end == end &&
      other.query == query;

  @override
  int get hashCode => Object.hash(start, end, query);
}

class _MentionCandidate {
  const _MentionCandidate._({
    required this.id,
    required this.label,
    required this.handle,
    required this.initials,
    required this.supportingLabel,
    required this.isCompass,
    required this.memberId,
  });

  factory _MentionCandidate.compass({
    required String label,
    required String supportingLabel,
  }) =>
      _MentionCandidate._(
        id: 'compass',
        label: label,
        handle: '@Compass',
        initials: 'C',
        supportingLabel: supportingLabel,
        isCompass: true,
        memberId: null,
      );

  factory _MentionCandidate.member({
    required FamilyMember member,
    required String supportingLabel,
  }) =>
      _MentionCandidate._(
        id: 'member.${member.id}',
        label: member.name,
        handle: '@${_mentionName(member.name)}',
        initials: member.initials,
        supportingLabel: supportingLabel,
        isCompass: false,
        memberId: member.id,
      );

  final String id;
  final String label;
  final String handle;
  final String initials;
  final String supportingLabel;
  final bool isCompass;
  final String? memberId;
}

@immutable
class ChatMentionMatch {
  const ChatMentionMatch({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

/// Finds the unfinished mention at the current caret, if one exists.
///
/// Exposed for focused domain tests so Unicode and cursor behavior stay stable
/// without reaching through the widget tree.
ChatMentionMatch? activeChatMention(TextEditingValue value) {
  final trigger = _mentionTriggerFor(value);
  if (trigger == null) return null;
  return ChatMentionMatch(
    start: trigger.start,
    end: trigger.end,
    query: trigger.query,
  );
}

bool containsCompassMention(String value) => _containsCompassMention(value);

String canonicalCompassPrompt(String value) => _canonicalCompassPrompt(value);

_MentionTrigger? _mentionTriggerFor(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset.clamp(0, value.text.length);
  final beforeCaret = value.text.substring(0, caret);
  final at = beforeCaret.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0 && !_isMentionBoundary(beforeCaret.codeUnitAt(at - 1))) {
    return null;
  }
  final query = beforeCaret.substring(at + 1);
  if (query.contains(RegExp(r'\s')) || query.contains(RegExp(r'[,،:؛.!?؟]'))) {
    return null;
  }
  return _MentionTrigger(start: at, end: caret, query: query);
}

bool _isMentionBoundary(int codeUnit) =>
    String.fromCharCode(codeUnit).contains(RegExp(r'[\s([{:،]'));

bool _startsWithWhitespace(String value) =>
    value.isNotEmpty && value[0].contains(RegExp(r'\s'));

bool _containsMentionHandle(String value, String handle) {
  var searchFrom = 0;
  while (searchFrom < value.length) {
    final start = value.indexOf(handle, searchFrom);
    if (start < 0) return false;
    final end = start + handle.length;
    final startsAtBoundary =
        start == 0 || _isMentionBoundary(value.codeUnitAt(start - 1));
    final endsAtBoundary = end == value.length ||
        value[end].contains(RegExp(r'[\s)\]};:,،؛.!?؟]'));
    if (startsAtBoundary && endsAtBoundary) return true;
    searchFrom = start + 1;
  }
  return false;
}

String _mentionName(String name) => name
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[@\n\r\t]'), '');

String _mentionRelationshipLabel(BuildContext context, FamilyMember member) {
  if (member.relationshipKind == FamilyRelationshipKind.self) {
    return _copy(context, en: 'You', ar: 'أنت');
  }
  if (member.relationship.trim().isNotEmpty) return member.relationship;
  return _copy(context, en: 'Family member', ar: 'فرد من العائلة');
}

bool _containsCompassMention(String value) => containsCompassMentionText(value);

String _canonicalCompassPrompt(String value) {
  final match = firstCompassMentionMatch(value);
  if (match == null) return value.trim();
  final prefix = match.group(1) ?? '';
  final suffix = value
      .substring(match.end)
      .replaceFirst(RegExp(r'^\s*[,،:：;؛\-]+\s*'), ' ');
  final withoutMention = '${value.substring(0, match.start)}$prefix$suffix';
  var question = withoutMention.trim();
  question = question.replaceAllMapped(
    RegExp(r'\s+([,،:：;؛.!?؟])'),
    (match) => match.group(1)!,
  );
  question = question
      .replaceFirst(RegExp(r'^[,،:：;؛.!?؟\-]+\s*'), '')
      .replaceAll(RegExp(r'[,،:：;؛\-]+\s*$'), '')
      .replaceAll(RegExp(r'[,،:：;؛\-]+(?=[.!?؟])'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return question.isEmpty ? '@Compass' : '@Compass $question';
}

String _compassQuestionBody(String value) => value
    .replaceFirst(RegExp(r'^\s*@compass\b', caseSensitive: false), '')
    .trim()
    .replaceFirst(RegExp(r'^[,،:：;؛.!?؟\-]+\s*'), '')
    .trim();

bool _requiresCompassActionConfirmation(CompassAction action) =>
    action.requiresConfirmation || action.kind != CompassActionKind.openPlan;

bool _supportsCompassAction(CompassAction action) => switch (action.kind) {
      CompassActionKind.openPlan ||
      CompassActionKind.requestCheckIn =>
        action.targetId != null,
      CompassActionKind.startPlan => true,
      // A safe reminder draft needs an explicit label, time, and owner. Those
      // fields are not in the current action artifact, so the live control is
      // withheld instead of creating the fixed demo reminder.
      CompassActionKind.createReminder => false,
    };

String _uncertaintyLabel(
  BuildContext context,
  CompassUncertainty uncertainty,
) =>
    switch (uncertainty) {
      CompassUncertainty.low =>
        _copy(context, en: 'Low uncertainty', ar: 'ثقة عالية'),
      CompassUncertainty.medium =>
        _copy(context, en: 'Some uncertainty', ar: 'ثقة متوسطة'),
      CompassUncertainty.high =>
        _copy(context, en: 'High uncertainty', ar: 'غير مؤكد'),
      CompassUncertainty.notApplicable =>
        _copy(context, en: 'General answer', ar: 'إجابة عامة'),
    };

String _audienceLabel(
  BuildContext context,
  CompassFactAudience audience,
) =>
    switch (audience) {
      CompassFactAudience.wholeFamily =>
        _copy(context, en: 'Whole family', ar: 'كل العائلة'),
      CompassFactAudience.selectedPeople =>
        _copy(context, en: 'Selected people', ar: 'أشخاص محددون'),
      CompassFactAudience.onlyMe =>
        _copy(context, en: 'Only me', ar: 'أنا فقط'),
      CompassFactAudience.requestParticipants =>
        _copy(context, en: 'Request participants', ar: 'أطراف الطلب'),
    };

String _freshnessLabel(BuildContext context, CompassCitation citation) {
  final prefix = switch (citation.freshness) {
    CompassFactFreshness.current => _copy(context, en: 'Current', ar: 'حالي'),
    CompassFactFreshness.recent => _copy(context, en: 'Recent', ar: 'حديث'),
    CompassFactFreshness.scheduled =>
      _copy(context, en: 'Scheduled', ar: 'مجدول'),
  };
  final difference =
      DateTime.now().toUtc().difference(citation.updatedAt.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) {
    return '$prefix · ${_copy(context, en: 'just now', ar: 'الآن')}';
  }
  if (difference.inHours < 1) {
    return '$prefix · ${difference.inMinutes} ${_copy(context, en: 'min ago', ar: 'دقيقة مضت')}';
  }
  if (difference.inDays < 1) {
    return '$prefix · ${difference.inHours} ${_copy(context, en: 'hr ago', ar: 'ساعة مضت')}';
  }
  return '$prefix · ${MaterialLocalizations.of(context).formatShortDate(citation.updatedAt)}';
}

IconData _compassActionIcon(CompassActionKind kind) => switch (kind) {
      CompassActionKind.openPlan => FamilyCompassIcons.eventNoteOutlined,
      CompassActionKind.startPlan => FamilyCompassIcons.editCalendarOutlined,
      CompassActionKind.requestCheckIn =>
        FamilyCompassIcons.markChatUnreadOutlined,
      CompassActionKind.createReminder => FamilyCompassIcons.alarmAddOutlined,
    };

String _copy(
  BuildContext context, {
  required String en,
  required String ar,
}) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

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

DateTime _derivedPlanOccurredAt(PrototypeScenarioState state) =>
    state.chatItems.lastOrNull?.sentAt ?? state.scenarioNow;
