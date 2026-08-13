import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/family_compass_repositories.dart';
import '../data/family_realtime_client.dart';
import '../data/family_compass_api_client.dart';
import '../domain/chat_models.dart';
import '../domain/compass_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';
import 'fixtures.dart';
import 'prototype_scenario_state.dart';

class PrototypeScenarioController extends ChangeNotifier {
  PrototypeScenarioController({
    PrototypeScenario initialScenario = PrototypeScenario.dinnerOpportunity,
    Future<void> Function()? retryAction,
    FamilyCompassRepositories? repositories,
    String? familyId,
    String? currentUserId,
    Uuid? uuid,
    Stream<FamilyEvent>? familyEvents,
    Future<void> Function()? onFamilyAccessLost,
  })  : _retryAction = retryAction ?? _defaultRetry,
        _repositories = repositories,
        _familyId = familyId,
        _currentUserId = currentUserId,
        _onFamilyAccessLost = onFamilyAccessLost,
        _uuid = uuid ?? const Uuid() {
    _state = _buildScenario(initialScenario);
    if (repositories != null && familyId != null && currentUserId != null) {
      _state = _state.copyWith(
        dataSourceMode: DataSourceMode.backend,
        surfaceState: SurfaceState.loading,
        plan: null,
        chatItems: const <ChatItem>[],
        statuses: const <String, SharedStatus>{},
        repositoryStatus: const RepositoryStatus(
          phase: RepositoryPhase.loading,
        ),
      );
      _connectBackend();
      if (familyEvents != null) {
        _subscriptions.add(
          familyEvents.listen(
            _handleFamilyEvent,
            onError: _handleFamilyEventError,
          ),
        );
      }
    }
  }

  void _handleFamilyEvent(FamilyEvent event) {
    if (event.familyId != _familyId) return;
    if (event.eventType == 'member.removed' &&
        event.resourceId == _currentUserId) {
      _reportFamilyAccessLost();
      return;
    }
    final repositories = _repositories;
    if (repositories == null) return;
    final type = event.eventType;
    if (type.startsWith('message.')) {
      unawaited(repositories.chat.refresh());
    }
    if (type.startsWith('compass.')) {
      unawaited(repositories.familyRoomCompass?.refresh());
    }
    if (type.startsWith('plan.') || type.startsWith('reminder.')) {
      unawaited(repositories.plans.refresh());
      unawaited(repositories.today.refresh());
    }
    if (type.startsWith('invitation.') ||
        type.startsWith('membership.') ||
        type.startsWith('member.')) {
      unawaited(repositories.family.refresh());
    }
    if (type.startsWith('status.') || type.startsWith('journey.')) {
      unawaited(repositories.sharing.refresh());
      unawaited(repositories.today.refresh());
    }
  }

  void _handleFamilyEventError(Object error, [StackTrace? stackTrace]) {
    if (_isFamilyAccessError(error)) {
      _reportFamilyAccessLost();
      return;
    }
    _handleBackendError(error, stackTrace);
  }

  late PrototypeScenarioState _state;
  final Future<void> Function() _retryAction;
  final FamilyCompassRepositories? _repositories;
  final String? _familyId;
  final String? _currentUserId;
  final Future<void> Function()? _onFamilyAccessLost;
  final Uuid _uuid;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  int _localMessageSequence = 0;
  FamilyCompassDeepLink? _lastDeepLink;
  int _deepLinkRevision = 0;
  String? _linkedPlanId;
  bool _accessLossReported = false;
  final Set<String> _pollNudgesInFlight = <String>{};

  PrototypeScenarioState get state => _state;

  List<FamilyMember> get availableSharingRecipients => List.unmodifiable(
        (_state.family?.members ?? familyMembers)
            .where((member) => member.id != (_currentUserId ?? 'abdullah')),
      );

  bool get usesBackend => _repositories != null;

  String get currentUserId => _currentUserId ?? 'abdullah';

  String? get familyId => _familyId;

  FamilyCompassDeepLink? get lastDeepLink => _lastDeepLink;

  int get deepLinkRevision => _deepLinkRevision;

  String? get linkedMessageId =>
      _lastDeepLink?.kind == FamilyResourceKind.messages
          ? _lastDeepLink?.resourceId
          : null;

  bool get isPollNudgeInFlight {
    final planId = _state.plan?.id;
    return planId != null && _pollNudgesInFlight.contains(planId);
  }

  bool get canManageFamily {
    final family = _state.family;
    if (family == null) return false;
    if (family.organizerId == currentUserId) return true;
    return family.members.any(
      (member) =>
          member.id == currentUserId && member.role == FamilyRole.coordinator,
    );
  }

  bool get isFamilyOrganizer => _state.family?.organizerId == currentUserId;

  List<FamilyMember> get familyMembersForDisplay =>
      List.unmodifiable(_state.family?.members ?? familyMembers);

  FamilyMember get currentMemberForDisplay {
    for (final member in familyMembersForDisplay) {
      if (member.id == currentUserId) return member;
    }
    return FamilyMember(
      id: currentUserId,
      name: 'You',
      relationshipKind: FamilyRelationshipKind.self,
      initials: '?',
    );
  }

  bool get hasLoadedFamily => _state.family != null;

  bool get canInviteFamily => !usesBackend || currentMemberForDisplay.canInvite;

  void openDeepLink(FamilyCompassDeepLink link) {
    final activeFamilyId = _familyId;
    if (activeFamilyId != null && link.familyId != activeFamilyId) return;
    final planId = switch (link.kind) {
      FamilyResourceKind.plans => link.resourceId,
      FamilyResourceKind.reminders => _state.plan?.reminders.any(
                (reminder) => reminder.id == link.resourceId,
              ) ==
              true
          ? _state.plan?.id
          : null,
      _ => null,
    };
    _recordDeepLink(link, planId: planId);
  }

  Future<bool> openExactDeepLink(FamilyCompassDeepLink link) async {
    final activeFamilyId = _familyId;
    if (activeFamilyId != null && link.familyId != activeFamilyId) return false;
    final repositories = _repositories;
    if (repositories == null || activeFamilyId == null) {
      openDeepLink(link);
      return true;
    }
    try {
      switch (link.kind) {
        case FamilyResourceKind.messages:
          final message = await repositories.chat.getMessage(
            familyId: activeFamilyId,
            messageId: link.resourceId,
          );
          final messages = <ChatItem>[
            ..._state.chatItems.where((value) => value.id != message.id),
            message,
          ]..sort((left, right) => left.sentAt.compareTo(right.sentAt));
          _state = _state.copyWith(chatItems: messages);
          _recordDeepLink(link);
        case FamilyResourceKind.plans:
          final plan = await repositories.plans.getPlan(
            familyId: activeFamilyId,
            planId: link.resourceId,
          );
          _state = _state.copyWith(plan: plan);
          _recordDeepLink(link, planId: plan.id);
        case FamilyResourceKind.reminders:
          final plan = await repositories.plans.getPlanForReminder(
            familyId: activeFamilyId,
            reminderId: link.resourceId,
          );
          _state = _state.copyWith(plan: plan);
          _recordDeepLink(link, planId: plan.id);
        case FamilyResourceKind.checkIns:
          _recordDeepLink(link);
        case FamilyResourceKind.unknown:
          return false;
      }
      return true;
    } on FamilyCompassApiException catch (error) {
      if (_isFamilyAccessError(error)) _reportFamilyAccessLost();
      if (error.kind == FamilyCompassApiErrorKind.notFound ||
          error.kind == FamilyCompassApiErrorKind.forbidden ||
          error.kind == FamilyCompassApiErrorKind.unauthorized) {
        return false;
      }
      rethrow;
    }
  }

  void _recordDeepLink(FamilyCompassDeepLink link, {String? planId}) {
    _lastDeepLink = link;
    _deepLinkRevision += 1;
    if (planId != null) _linkedPlanId = planId;
    final selectedTab = switch (link.kind) {
      FamilyResourceKind.messages => 1,
      FamilyResourceKind.plans || FamilyResourceKind.reminders => 3,
      FamilyResourceKind.checkIns => 0,
      FamilyResourceKind.unknown => _state.ui.selectedTab,
    };
    _state = _state.copyWith(
      ui: _state.ui.copyWith(
        selectedTab: selectedTab,
        selectedPlanId: planId,
      ),
    );
    notifyListeners();
  }

  Future<void> leaveCurrentFamily() async {
    final repositories = _repositories;
    final activeFamilyId = _familyId;
    if (repositories == null || activeFamilyId == null) {
      throw const BackendCapabilityUnavailableException('Leaving a family');
    }
    await repositories.family.leaveFamily(activeFamilyId);
    await repositories.chat.discardPending(familyId: activeFamilyId);
    _state = _state.copyWith(
      surfaceState: SurfaceState.empty,
      clearPlan: true,
      chatItems: const <ChatItem>[],
      statuses: const <String, SharedStatus>{},
    );
    notifyListeners();
  }

  Future<void> removeFamilyMember(String memberId) async {
    final repositories = _repositories;
    final activeFamilyId = _familyId;
    if (repositories == null || activeFamilyId == null) {
      throw const BackendCapabilityUnavailableException(
        'Removing a family member',
      );
    }
    await repositories.family.removeMember(
      familyId: activeFamilyId,
      memberId: memberId,
    );
    await repositories.family.refresh();
  }

  Future<void> deleteCurrentFamily() async {
    final repositories = _repositories;
    final activeFamilyId = _familyId;
    if (repositories == null || activeFamilyId == null) {
      throw const BackendCapabilityUnavailableException('Deleting a family');
    }
    await repositories.family.deleteFamily(activeFamilyId);
    await repositories.chat.discardPending(familyId: activeFamilyId);
    _state = _state.copyWith(
      surfaceState: SurfaceState.empty,
      clearPlan: true,
      chatItems: const <ChatItem>[],
      statuses: const <String, SharedStatus>{},
    );
    notifyListeners();
  }

  FamilyMember memberForId(String id) {
    for (final member in familyMembersForDisplay) {
      if (member.id == id) return member;
    }
    return FamilyMember(
      id: id,
      name: 'Family member',
      relationshipKind: FamilyRelationshipKind.familyMember,
      initials: '?',
    );
  }

  void _connectBackend() {
    final repositories = _repositories!;
    final familyId = _familyId!;
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      repositories.family.watchFamily(familyId).listen(
            (family) => _applyBackend(family: family),
            onError: _handleBackendError,
          ),
      repositories.chat.watchMessages(familyId: familyId).listen(
        (items) {
          final linkedId = linkedMessageId;
          final currentLinked = linkedId == null
              ? null
              : _state.chatItems
                  .where((item) => item.id == linkedId)
                  .firstOrNull;
          final incomingContainsLinked =
              linkedId == null || items.any((item) => item.id == linkedId);
          final mergedItems = currentLinked != null && !incomingContainsLinked
              ? (<ChatItem>[...items, currentLinked]
                ..sort((left, right) => left.sentAt.compareTo(right.sentAt)))
              : items;
          _applyBackend(chatItems: mergedItems);
        },
        onError: _handleBackendError,
      ),
      repositories.plans.watchPlans(familyId).listen(
        (plans) {
          final selectedPlan = _selectPlan(plans);
          _applyBackend(
            plan: selectedPlan,
            clearPlan: plans.isEmpty && selectedPlan == null,
          );
        },
        onError: _handleBackendError,
      ),
      repositories.sharing.watchPermittedStatuses(familyId).listen(
            (statuses) => _applyBackend(
              statuses: <String, SharedStatus>{
                for (final status in statuses) status.memberId: status,
              },
            ),
            onError: _handleBackendError,
          ),
      repositories.today.watchToday(familyId).listen(
        (today) {
          final linkedPlanId = _linkedPlanId;
          final preserveLinkedPlan = linkedPlanId != null &&
              _state.plan?.id == linkedPlanId &&
              today.nextPlan?.id != linkedPlanId;
          _applyBackend(
            plan: preserveLinkedPlan ? null : today.nextPlan,
            clearPlan: !preserveLinkedPlan && today.nextPlan == null,
            statuses: today.sharedUpdates.isEmpty
                ? null
                : <String, SharedStatus>{
                    for (final status in today.sharedUpdates)
                      status.memberId: status,
                  },
          );
        },
        onError: _handleBackendError,
      ),
      repositories.chat.status.listen(_applyRepositoryStatus),
      repositories.plans.status.listen(_applyRepositoryStatus),
      repositories.sharing.status.listen(_applyRepositoryStatus),
      repositories.today.status.listen(_applyRepositoryStatus),
    ]);
  }

  FamilyPlan? _selectPlan(List<FamilyPlan> plans) {
    if (plans.isEmpty) {
      final linkedId = _linkedPlanId;
      if (linkedId != null && _state.plan?.id == linkedId) return _state.plan;
      return null;
    }
    final selected = _linkedPlanId ?? _state.ui.selectedPlanId;
    if (selected != null) {
      for (final plan in plans) {
        if (plan.id == selected) return plan;
      }
      if (_linkedPlanId != null && _state.plan?.id == _linkedPlanId) {
        return _state.plan;
      }
    }
    final values = [...plans]
      ..sort((a, b) => a.decisionDeadline.compareTo(b.decisionDeadline));
    return values.first;
  }

  void _applyBackend({
    FamilySummary? family,
    FamilyPlan? plan,
    bool clearPlan = false,
    List<ChatItem>? chatItems,
    Map<String, SharedStatus>? statuses,
    PrototypeUiState? ui,
  }) {
    if (_isDisposed) return;
    _state = _state.copyWith(
      family: family,
      plan: plan,
      clearPlan: clearPlan,
      chatItems: chatItems,
      statuses: statuses,
      surfaceState: SurfaceState.ready,
      repositoryStatus: const RepositoryStatus(phase: RepositoryPhase.ready),
      scenarioNow: DateTime.now(),
      ui: ui ??
          (plan == null ? null : _state.ui.copyWith(selectedPlanId: plan.id)),
    );
    notifyListeners();
  }

  void _applyRepositoryStatus(RepositoryStatus status) {
    if (_isDisposed) return;
    final surface = status.phase == RepositoryPhase.offline
        ? SurfaceState.offlineCached
        : status.phase == RepositoryPhase.loading &&
                _state.chatItems.isEmpty &&
                _state.plan == null
            ? SurfaceState.loading
            : _state.surfaceState;
    _state = _state.copyWith(
      repositoryStatus: status,
      surfaceState: surface,
    );
    notifyListeners();
  }

  void _handleBackendError(Object error, [StackTrace? stackTrace]) {
    if (_isDisposed) return;
    if (_isFamilyAccessError(error)) {
      _reportFamilyAccessLost();
      return;
    }
    final apiError = error is FamilyCompassApiException ? error : null;
    final hasCachedData = _state.plan != null ||
        _state.chatItems.isNotEmpty ||
        _state.statuses.isNotEmpty;
    _state = _state.copyWith(
      surfaceState:
          hasCachedData ? SurfaceState.offlineCached : SurfaceState.empty,
      repositoryStatus: RepositoryStatus(
        phase: apiError?.kind == FamilyCompassApiErrorKind.offline
            ? RepositoryPhase.offline
            : RepositoryPhase.failed,
        message: error.toString(),
        canRetry: apiError?.canRetry ?? true,
      ),
    );
    notifyListeners();
  }

  bool _isFamilyAccessError(Object error) =>
      error is FamilyCompassApiException &&
      (error.kind == FamilyCompassApiErrorKind.unauthorized ||
          error.kind == FamilyCompassApiErrorKind.forbidden);

  void _reportFamilyAccessLost() {
    if (_isDisposed || _accessLossReported) return;
    _accessLossReported = true;
    _state = _state.copyWith(
      surfaceState: SurfaceState.empty,
      clearPlan: true,
      chatItems: const <ChatItem>[],
      statuses: const <String, SharedStatus>{},
      repositoryStatus: const RepositoryStatus(
        phase: RepositoryPhase.failed,
        message: 'Access to this family has ended.',
        canRetry: false,
      ),
    );
    notifyListeners();
    unawaited(_onFamilyAccessLost?.call());
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  static Future<void> _defaultRetry() =>
      Future<void>.delayed(const Duration(milliseconds: 550));

  void reset(PrototypeScenario scenario) {
    if (usesBackend) {
      unawaited(retryOffline());
      return;
    }
    _state = _buildScenario(scenario);
    notifyListeners();
  }

  void selectTab(int index) {
    _state = _state.copyWith(ui: _state.ui.copyWith(selectedTab: index));
    notifyListeners();
  }

  void updateChatDraft(String value) {
    _state = _state.copyWith(ui: _state.ui.copyWith(chatDraft: value));
    notifyListeners();
  }

  void clearChatDraft() => updateChatDraft('');

  void sendHumanMessage(
    String value, {
    Set<String> mentionedMemberIds = const <String>{},
  }) {
    final message = value.trim();
    if (message.isEmpty) return;
    final familyMemberIds =
        familyMembersForDisplay.map((member) => member.id).toSet();
    final authorizedMentionIds = Set<String>.unmodifiable(
      mentionedMemberIds.where(familyMemberIds.contains),
    );
    if (usesBackend) {
      _state = _state.copyWith(ui: _state.ui.copyWith(chatDraft: ''));
      notifyListeners();
      unawaited(_sendBackendMessage(message, authorizedMentionIds));
      return;
    }
    if (_state.surfaceState == SurfaceState.offlineCached) return;
    _localMessageSequence += 1;
    _state = _state.copyWith(
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'local-message-$_localMessageSequence',
          kind: ChatItemKind.message,
          authorId: 'abdullah',
          text: message,
          mentionedMemberIds: authorizedMentionIds,
          sentAt: _state.scenarioNow,
        ),
      ],
      ui: _state.ui.copyWith(chatDraft: ''),
    );
    notifyListeners();
  }

  Future<void> _sendBackendMessage(
    String message,
    Set<String> mentionedMemberIds,
  ) async {
    try {
      await _repositories!.chat.sendText(
        familyId: _familyId!,
        text: message,
        idempotencyKey: _uuid.v4(),
        mentionedMemberIds: mentionedMemberIds,
        queueOnly: _state.surfaceState == SurfaceState.offlineCached,
      );
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void setPlanBuilderStep(int step) {
    _state = _state.copyWith(
      ui: _state.ui.copyWith(
        planBuilderStep: step,
        hasUnsavedPlanChanges: true,
      ),
    );
    notifyListeners();
  }

  void toggleCandidate(String id) {
    final selected = <String>{..._state.ui.selectedCandidateIds};
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    _state = _state.copyWith(
      ui: _state.ui.copyWith(
        selectedCandidateIds: selected,
        hasUnsavedPlanChanges: true,
      ),
    );
    notifyListeners();
  }

  void draftFridayDinner() {
    final plan = _state.plan;
    if (usesBackend) {
      if (plan == null) unawaited(_createBackendDinnerPlan());
      return;
    }
    if (plan == null || plan.phase != PlanPhase.opportunity) return;
    final item = ChatItem(
      id: 'compass-plan-draft',
      kind: ChatItemKind.compassDraft,
      authorId: 'compass',
      text: 'I drafted Friday dinner with two possible times.',
      sentAt: _state.scenarioNow,
      referenceId: plan.id,
    );
    _state = _state.copyWith(
      plan: plan.copyWith(phase: PlanPhase.draft),
      chatItems: [..._state.chatItems, item],
      ui: _state.ui.copyWith(
        selectedCandidateIds: {'friday-1900', 'friday-1930'},
        selectedPlanId: plan.id,
      ),
    );
    notifyListeners();
  }

  Future<void> _createBackendDinnerPlan() async {
    final now = DateTime.now();
    final dinnerDate = DateTime(now.year, now.month, now.day + 1);
    final members = _state.family?.members ?? const <FamilyMember>[];
    final participantIds = members.map((member) => member.id).toList();
    if (participantIds.isEmpty) {
      _unsupportedBackendAction('Creating a plan before family members load');
      return;
    }
    try {
      final plan = await _repositories!.plans.createPlan(
        familyId: _familyId!,
        title: 'Family dinner',
        locationLabel: 'Home',
        participantIds: participantIds,
        candidateTimes: <CandidateTime>[
          CandidateTime(
            id: 'dinner-1900-${dinnerDate.millisecondsSinceEpoch}',
            startsAt: DateTime(
              dinnerDate.year,
              dinnerDate.month,
              dinnerDate.day,
              19,
            ),
          ),
          CandidateTime(
            id: 'dinner-1930-${dinnerDate.millisecondsSinceEpoch}',
            startsAt: DateTime(
              dinnerDate.year,
              dinnerDate.month,
              dinnerDate.day,
              19,
              30,
            ),
          ),
        ],
        decisionDeadline: DateTime(
          dinnerDate.year,
          dinnerDate.month,
          dinnerDate.day,
          12,
        ),
      );
      _applyBackend(
        plan: plan,
        ui: _state.ui.copyWith(
          selectedCandidateIds:
              plan.candidateTimes.map((value) => value.id).toSet(),
          selectedPlanId: plan.id,
          hasUnsavedPlanChanges: true,
        ),
      );
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void sendPoll() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.draft) return;
    if (usesBackend) {
      unawaited(_publishBackendPoll(plan));
      return;
    }
    _state = _state.copyWith(
      plan: plan.copyWith(phase: PlanPhase.pollOpen),
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'dinner-poll-card',
          kind: ChatItemKind.poll,
          authorId: 'abdullah',
          text: 'Vote on a time for Friday family dinner.',
          sentAt: _state.scenarioNow,
          referenceId: plan.id,
        ),
      ],
      ui: _state.ui.copyWith(
        hasUnsavedPlanChanges: false,
        planBuilderStep: 0,
      ),
    );
    notifyListeners();
  }

  Future<void> _publishBackendPoll(FamilyPlan plan) async {
    try {
      final published = await _repositories!.plans.publishPlan(
        familyId: _familyId!,
        planId: plan.id,
        candidateIds: _state.ui.selectedCandidateIds,
        expectedVersion: plan.version,
      );
      _applyBackend(
        plan: published,
        ui: _state.ui.copyWith(
          hasUnsavedPlanChanges: false,
          planBuilderStep: 0,
        ),
      );
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void submitAbdullahResponse({
    String? candidateId,
    RsvpChoice choice = RsvpChoice.going,
  }) {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.pollOpen) return;
    final resolvedCandidate = plan.candidateById(candidateId) ??
        plan.displayCandidate(memberId: currentUserId);
    if (resolvedCandidate == null) return;
    if (usesBackend) {
      _state = _state.copyWith(
        ui: _state.ui.copyWith(selectedPollChoice: choice),
      );
      notifyListeners();
      unawaited(
        _saveBackendResponse(plan, resolvedCandidate.id, choice),
      );
      return;
    }
    final responses = <String, PollResponse>{
      ...plan.responses,
      'abdullah': PollResponse(
        memberId: 'abdullah',
        candidateId: resolvedCandidate.id,
        choice: choice,
      ),
      'mom': const PollResponse(
        memberId: 'mom',
        candidateId: 'friday-1930',
        choice: RsvpChoice.going,
      ),
      'dad': const PollResponse(
        memberId: 'dad',
        candidateId: 'friday-1930',
        choice: RsvpChoice.going,
      ),
    };
    _state = _state.copyWith(
      plan: plan.copyWith(responses: responses),
      ui: _state.ui.copyWith(selectedPollChoice: choice),
    );
    notifyListeners();
  }

  Future<void> _saveBackendResponse(
    FamilyPlan plan,
    String candidateId,
    RsvpChoice choice,
  ) async {
    try {
      final updated = await _repositories!.plans.saveResponse(
        planId: plan.id,
        candidateId: candidateId,
        choice: choice,
        expectedVersion: plan.version,
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void suggestCandidateTime(DateTime startsAt) {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.pollOpen) return;
    final duplicate = plan.candidateTimes.any(
      (candidate) => candidate.startsAt == startsAt,
    );
    if (duplicate) return;
    final candidate = CandidateTime(
      id: 'suggested-${startsAt.millisecondsSinceEpoch}',
      startsAt: startsAt,
    );
    if (usesBackend) {
      unawaited(_suggestBackendCandidateTime(plan, candidate));
      return;
    }
    _state = _state.copyWith(
      plan: plan.copyWith(candidateTimes: [...plan.candidateTimes, candidate]),
    );
    notifyListeners();
  }

  Future<void> _suggestBackendCandidateTime(
    FamilyPlan plan,
    CandidateTime candidate,
  ) async {
    try {
      final updated = await _repositories!.plans.suggestCandidateTime(
        familyId: _familyId!,
        planId: plan.id,
        candidate: candidate,
        expectedVersion: plan.version,
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void sendPollNudge() {
    final plan = _state.plan;
    if (plan == null ||
        plan.nudgeSent ||
        _pollNudgesInFlight.contains(plan.id) ||
        !plan.responses.containsKey(currentUserId)) {
      return;
    }
    if (usesBackend) {
      _pollNudgesInFlight.add(plan.id);
      notifyListeners();
      unawaited(_sendBackendPollNudge(plan));
      return;
    }
    final responses = <String, PollResponse>{
      ...plan.responses,
      'sara': PollResponse(
        memberId: 'sara',
        candidateId: plan.displayCandidate()?.id ??
            plan.candidateTimes.firstOrNull?.id ??
            '',
        choice: RsvpChoice.going,
      ),
    };
    _state = _state.copyWith(
      scenarioNow: DateTime(2026, 8, 7, 10),
      plan: plan.copyWith(
        responses: responses,
        nudgeSent: true,
        phase: PlanPhase.readyToConfirm,
      ),
    );
    notifyListeners();
  }

  Future<void> _sendBackendPollNudge(FamilyPlan plan) async {
    try {
      final updated = await _repositories!.plans.sendNudge(
        familyId: _familyId!,
        planId: plan.id,
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    } finally {
      _pollNudgesInFlight.remove(plan.id);
      if (!_isDisposed) notifyListeners();
    }
  }

  void confirmDinner({String? candidateId}) {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.readyToConfirm) return;
    final selected = plan.candidateById(candidateId) ??
        plan.candidateById(plan.confirmedCandidateId) ??
        plan.candidateById(_commonCandidateId(plan)) ??
        plan.displayCandidate();
    if (selected == null) return;
    if (usesBackend) {
      unawaited(_confirmBackendPlan(plan, selected.id));
      return;
    }
    final reminder = PlanReminder(
      id: 'automatic-gathering-reminder',
      label: 'Family dinner starts in 2 hours',
      at: selected.startsAt.subtract(const Duration(hours: 2)),
      isAutomatic: true,
    );
    _state = _state.copyWith(
      plan: plan.copyWith(
        phase: PlanPhase.confirmed,
        confirmedCandidateId: selected.id,
        reminders: [reminder],
      ),
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'confirmed-dinner-card',
          kind: ChatItemKind.confirmedPlan,
          authorId: 'abdullah',
          text:
              'Family dinner is confirmed for ${selected.startsAt.toIso8601String()}.',
          sentAt: _state.scenarioNow,
          referenceId: plan.id,
        ),
      ],
    );
    notifyListeners();
  }

  String? _commonCandidateId(FamilyPlan plan) {
    if (plan.responses.isEmpty) return null;
    final ids =
        plan.responses.values.map((response) => response.candidateId).toSet();
    return ids.length == 1 ? ids.single : null;
  }

  Future<void> _confirmBackendPlan(FamilyPlan plan, String candidateId) async {
    try {
      final updated = await _repositories!.plans.confirmPlan(
        planId: plan.id,
        candidateId: candidateId,
        expectedVersion: plan.version,
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void adjustAutomaticReminder() {
    final plan = _state.plan;
    if (plan == null || plan.reminders.isEmpty) return;
    if (usesBackend) {
      final reminder = plan.reminders.firstWhere(
        (value) => value.isAutomatic,
        orElse: () => plan.reminders.first,
      );
      final planDate = plan.confirmedTime?.startsAt ?? reminder.at;
      unawaited(
        _adjustBackendReminder(
          plan,
          reminder,
          DateTime(planDate.year, planDate.month, planDate.day, 18),
        ),
      );
      return;
    }
    final reminders = [...plan.reminders];
    reminders[0] = reminders[0].copyWith(at: DateTime(2026, 8, 7, 18));
    _state = _state.copyWith(plan: plan.copyWith(reminders: reminders));
    notifyListeners();
  }

  Future<void> _adjustBackendReminder(
    FamilyPlan plan,
    PlanReminder reminder,
    DateTime at,
  ) async {
    try {
      final updated = await _repositories!.reminders.updateReminder(
        familyId: _familyId!,
        reminderId: reminder.id,
        at: at,
      );
      final reminders = <PlanReminder>[
        for (final value in plan.reminders)
          if (value.id == reminder.id)
            PlanReminder(
              id: updated.id,
              label: updated.label,
              at: updated.at,
              isAutomatic: value.isAutomatic,
              isConfirmed: updated.isConfirmed,
            )
          else
            value,
      ];
      _applyBackend(plan: plan.copyWith(reminders: reminders));
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void denyNotifications() {
    _state = _state.copyWith(
      notificationPermission: NotificationPermissionState.denied,
    );
    notifyListeners();
  }

  void addDessertContribution() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.confirmed) return;
    if (usesBackend) {
      unawaited(_addBackendContribution(plan));
      return;
    }
    if (plan.contributions.any((item) => item.id == 'dessert')) return;
    _state = _state.copyWith(
      plan: plan.copyWith(
        contributions: [
          ...plan.contributions,
          const PlanContribution(
            id: 'dessert',
            memberId: 'abdullah',
            text: 'I can bring dessert',
          ),
        ],
      ),
    );
    notifyListeners();
  }

  Future<void> _addBackendContribution(FamilyPlan plan) async {
    try {
      final updated = await _repositories!.plans.addContribution(
        familyId: _familyId!,
        planId: plan.id,
        text: 'I can bring dessert',
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void completeGathering() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.confirmed) return;
    if (usesBackend) {
      unawaited(_completeBackendGathering(plan));
      return;
    }
    _state = _state.copyWith(plan: plan.copyWith(phase: PlanPhase.completed));
    notifyListeners();
  }

  Future<void> _completeBackendGathering(FamilyPlan plan) async {
    try {
      final updated = await _repositories!.plans.completePlan(
        familyId: _familyId!,
        planId: plan.id,
      );
      _applyBackend(plan: updated);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void planAgain() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.completed) return;
    if (usesBackend) {
      unawaited(_createBackendDinnerPlan());
      return;
    }
    _state = _state.copyWith(
      plan: fridayDinner(phase: PlanPhase.draft, clock: _state.scenarioNow),
      ui: _state.ui.copyWith(
        selectedCandidateIds: {'friday-1900', 'friday-1930'},
        hasUnsavedPlanChanges: true,
      ),
    );
    notifyListeners();
  }

  CompassAnswer answerForDad() {
    if (!_state.aiAvailable) {
      return const CompassAnswer(
        text:
            'Compass is unavailable right now. Family plans and Chat still work.',
        sourceLabel: 'AI unavailable',
        freshnessLabel: '',
        hasPermittedInformation: false,
      );
    }
    final status = _state.statuses['dad'];
    if (status == null || !status.isUsableAt(_state.scenarioNow)) {
      return const CompassAnswer(
        text: 'No recent permitted information is available.',
        sourceLabel: 'No permitted source',
        freshnessLabel: '',
        hasPermittedInformation: false,
        actionLabel: 'Request a check-in',
      );
    }
    final minutes = _state.scenarioNow.difference(status.updatedAt).inMinutes;
    return CompassAnswer(
      text:
          'Dad shared that he is leaving work and expects to arrive around 7:20 PM.',
      sourceLabel: 'Shared by Dad',
      freshnessLabel: '$minutes minutes ago',
      hasPermittedInformation: true,
      actionLabel: 'Draft a change to 7:30',
    );
  }

  void markDadStatusOutdated() {
    _state = _state.copyWith(dadStatusMarkedOutdated: true);
    notifyListeners();
  }

  void draftPlanChange() {
    _state = _state.copyWith(hasPendingPlanChange: true);
    notifyListeners();
  }

  void applyPlanChange() {
    final plan = _state.plan;
    if (plan == null || !_state.hasPendingPlanChange) return;
    if (usesBackend) {
      _unsupportedBackendAction('Changing a confirmed plan');
      return;
    }
    _state = _state.copyWith(
      plan: plan.copyWith(confirmedCandidateId: 'friday-1930'),
      hasPendingPlanChange: false,
    );
    notifyListeners();
  }

  void requestCheckIn() {
    if (_state.checkInState != CheckInState.none) return;
    if (usesBackend) {
      final memberId = _dadMemberId;
      if (memberId == null) return;
      requestCheckInFor(memberId);
      return;
    }
    _state = _state.copyWith(
      checkInState: CheckInState.requested,
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'check-in-request',
          kind: ChatItemKind.checkInRequest,
          authorId: 'abdullah',
          text: 'Requested a check-in.',
          sentAt: _state.scenarioNow,
        ),
      ],
    );
    notifyListeners();
  }

  void requestCheckInFor(String memberId) {
    if (_state.checkInState != CheckInState.none) return;
    if (!usesBackend) {
      requestCheckIn();
      return;
    }
    final isFamilyMember = (_state.family?.members ?? const <FamilyMember>[])
        .any((member) => member.id == memberId && member.id != _currentUserId);
    if (!isFamilyMember) return;
    _state = _state.copyWith(checkInState: CheckInState.requested);
    notifyListeners();
    unawaited(_requestBackendCheckIn(memberId));
  }

  void openFamilyPlan(String planId) {
    final activeFamilyId = _familyId;
    if (activeFamilyId == null) return;
    openDeepLink(
      FamilyCompassDeepLink(
        familyId: activeFamilyId,
        kind: FamilyResourceKind.plans,
        resourceId: planId,
      ),
    );
  }

  void startFamilyPlan() {
    draftFridayDinner();
    selectTab(3);
  }

  String? get _dadMemberId {
    final members = _state.family?.members ?? const <FamilyMember>[];
    for (final member in members) {
      if (member.name.toLowerCase() == 'dad' ||
          member.relationship.toLowerCase() == 'father') {
        return member.id;
      }
    }
    final current = _currentUserId;
    return members.where((member) => member.id != current).firstOrNull?.id;
  }

  Future<void> _requestBackendCheckIn(String memberId) async {
    try {
      await _repositories!.checkIns.request(
        familyId: _familyId!,
        memberId: memberId,
      );
    } on Object catch (error, stackTrace) {
      _state = _state.copyWith(checkInState: CheckInState.none);
      _handleBackendError(error, stackTrace);
    }
  }

  void receiveCheckIn() {
    if (_state.checkInState != CheckInState.requested) return;
    if (usesBackend) {
      _unsupportedBackendAction('Responding to a check-in');
      return;
    }
    _state = _state.copyWith(
      checkInState: CheckInState.responded,
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'check-in-response',
          kind: ChatItemKind.checkInResponse,
          authorId: 'sara',
          text: "I'm okay and home until 8:00 PM.",
          sentAt: _state.scenarioNow,
        ),
      ],
    );
    notifyListeners();
  }

  void draftSeparateReminder() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.confirmed) return;
    if (usesBackend) {
      _state = _state.copyWith(
        separateReminderState: SeparateReminderState.drafted,
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      separateReminderState: SeparateReminderState.drafted,
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'dessert-reminder-draft',
          kind: ChatItemKind.reminderDraft,
          authorId: 'compass',
          text: 'Draft: Remind me to buy dessert Friday at 5:00 PM.',
          sentAt: _state.scenarioNow,
          referenceId: plan.id,
        ),
      ],
    );
    notifyListeners();
  }

  void confirmSeparateReminder() {
    final plan = _state.plan;
    if (plan == null ||
        _state.separateReminderState != SeparateReminderState.drafted) {
      return;
    }
    if (usesBackend) {
      unawaited(_createBackendReminder(plan));
      return;
    }
    final reminder = PlanReminder(
      id: 'dessert-reminder',
      label: 'Buy dessert',
      at: DateTime(2026, 8, 7, 17),
      isConfirmed: true,
    );
    _state = _state.copyWith(
      separateReminderState: SeparateReminderState.confirmed,
      plan: plan.copyWith(reminders: [...plan.reminders, reminder]),
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'dessert-reminder-confirmed',
          kind: ChatItemKind.reminderConfirmed,
          authorId: 'compass',
          text: 'Personal reminder confirmed for Friday at 5:00 PM.',
          sentAt: _state.scenarioNow,
          referenceId: plan.id,
        ),
      ],
    );
    notifyListeners();
  }

  Future<void> _createBackendReminder(FamilyPlan plan) async {
    final repositories = _repositories!;
    try {
      await repositories.reminders.createReminder(
        familyId: _familyId!,
        planId: plan.id,
        label: 'Buy dessert',
        at: DateTime.now().add(const Duration(hours: 2)),
      );
      await repositories.plans.refresh();
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void _unsupportedBackendAction(String capability) {
    _state = _state.copyWith(
      repositoryStatus: RepositoryStatus(
        phase: RepositoryPhase.failed,
        message: '$capability is not available from this backend yet.',
        canRetry: false,
      ),
    );
    notifyListeners();
  }

  void correctOwnStatus(String text) {
    final key = _currentUserId ?? 'abdullah';
    final status = _state.statuses[key];
    if (status == null) return;
    if (usesBackend) {
      unawaited(
        _replaceBackendStatus(
          status,
          text: text,
          audience: status.audience,
          recipientIds: status.recipientIds,
          expiresAt: status.expiresAt,
        ),
      );
      return;
    }
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        key: status.copyWith(text: text, updatedAt: _state.scenarioNow),
      },
    );
    notifyListeners();
  }

  void setOwnAudience({
    required SharingAudience audience,
    required Set<String> recipientIds,
  }) {
    final key = _currentUserId ?? 'abdullah';
    final status = _state.statuses[key];
    if (status == null) return;
    final updatedStatus = status.copyWith(
      audience: audience,
      recipientIds: recipientIds,
    );
    final availableIds =
        availableSharingRecipients.map((member) => member.id).toSet();
    if (!availableIds.containsAll(updatedStatus.recipientIds)) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Recipients must be available adult family members.',
      );
    }
    if (usesBackend) {
      unawaited(
        _replaceBackendStatus(
          status,
          text: status.text,
          audience: audience,
          recipientIds: recipientIds,
          expiresAt: status.expiresAt,
        ),
      );
      return;
    }
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        key: updatedStatus,
      },
    );
    notifyListeners();
  }

  void shortenOwnStatus() {
    final key = _currentUserId ?? 'abdullah';
    final status = _state.statuses[key];
    if (status == null) return;
    final expiresAt = DateTime.now().add(const Duration(minutes: 30));
    if (usesBackend) {
      unawaited(
        _replaceBackendStatus(
          status,
          text: status.text,
          audience: status.audience,
          recipientIds: status.recipientIds,
          expiresAt: expiresAt,
        ),
      );
      return;
    }
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        key: status.copyWith(
          expiresAt: _state.scenarioNow.add(const Duration(minutes: 30)),
        ),
      },
    );
    notifyListeners();
  }

  Future<void> _replaceBackendStatus(
    SharedStatus previous, {
    required String text,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) async {
    final repositories = _repositories!;
    try {
      await repositories.sharing.revokeStatus(previous.id);
      await repositories.sharing.shareManualStatus(
        familyId: _familyId!,
        text: text,
        audience: audience,
        recipientIds: recipientIds,
        expiresAt: expiresAt,
      );
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  void pauseOwnSharing() {
    final status = _state.statuses[_currentUserId ?? 'abdullah'];
    if (status == null) return;
    if (usesBackend) {
      unawaited(_pauseBackendStatus(status));
      return;
    }
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        currentUserId: status.copyWith(state: SharingState.paused),
      },
    );
    notifyListeners();
  }

  Future<void> _pauseBackendStatus(SharedStatus status) async {
    try {
      await _repositories!.sharing.pauseStatus(status.id);
    } on Object catch (error, stackTrace) {
      _handleBackendError(error, stackTrace);
    }
  }

  Future<void> retryOffline() async {
    if (usesBackend) {
      final repositories = _repositories!;
      if (_state.isRetrying) return;
      _state = _state.copyWith(isRetrying: true, retryFailed: false);
      notifyListeners();
      try {
        await Future.wait(<Future<void>>[
          repositories.chat.retryPending(),
          repositories.family.refresh(),
          repositories.plans.refresh(),
          repositories.sharing.refresh(),
          repositories.today.refresh(),
        ]);
        _state = _state.copyWith(
          surfaceState: SurfaceState.ready,
          isRetrying: false,
          retryFailed: false,
        );
      } on Object catch (error, stackTrace) {
        _state = _state.copyWith(
          surfaceState: SurfaceState.offlineCached,
          isRetrying: false,
          retryFailed: true,
        );
        _handleBackendError(error, stackTrace);
      }
      notifyListeners();
      return;
    }
    if (_state.surfaceState != SurfaceState.offlineCached ||
        _state.isRetrying) {
      return;
    }
    _state = _state.copyWith(isRetrying: true, retryFailed: false);
    notifyListeners();
    try {
      await _retryAction();
      _state = _state.copyWith(
        surfaceState: SurfaceState.ready,
        isRetrying: false,
        retryFailed: false,
      );
    } on Object {
      _state = _state.copyWith(
        surfaceState: SurfaceState.offlineCached,
        isRetrying: false,
        retryFailed: true,
      );
    }
    notifyListeners();
  }

  void dispatch(PrototypeIntent intent) {
    switch (intent) {
      case PrototypeIntent.draftFridayDinner:
        draftFridayDinner();
      case PrototypeIntent.whereIsDad:
      case PrototypeIntent.explainStatusSource:
        notifyListeners();
      case PrototypeIntent.markStatusOutdated:
        markDadStatusOutdated();
      case PrototypeIntent.requestCheckIn:
        requestCheckIn();
      case PrototypeIntent.draftPlanChange:
        draftPlanChange();
      case PrototypeIntent.draftSeparateReminder:
        draftSeparateReminder();
    }
  }

  static PrototypeScenarioState _buildScenario(PrototypeScenario scenario) {
    final planningClock = DateTime(2026, 8, 6, 18);
    final reassuranceClock = DateTime(2026, 8, 7, 18, 40);
    switch (scenario) {
      case PrototypeScenario.dinnerOpportunity:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: planningClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: true,
          plan:
              fridayDinner(phase: PlanPhase.opportunity, clock: planningClock),
          statuses: sharedStatuses(clock: planningClock),
          chatItems: openingChat(planningClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.dinnerPollOpen:
        final plan =
            fridayDinner(phase: PlanPhase.pollOpen, clock: planningClock);
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: planningClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: true,
          plan: plan,
          statuses: sharedStatuses(clock: planningClock),
          chatItems: [
            ...openingChat(planningClock),
            ChatItem(
              id: 'dinner-poll-card',
              kind: ChatItemKind.poll,
              authorId: 'abdullah',
              text: 'Vote on a time for Friday family dinner.',
              sentAt: planningClock,
              referenceId: plan.id,
            ),
          ],
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.reassuranceAtSeven:
      case PrototypeScenario.notificationDenied:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: reassuranceClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: true,
          plan: fridayDinner(
            phase: PlanPhase.confirmed,
            clock: reassuranceClock,
            confirmedCandidateId: 'friday-1900',
          ),
          statuses: sharedStatuses(clock: reassuranceClock),
          chatItems: openingChat(reassuranceClock),
          ui: const PrototypeUiState(),
          notificationPermission:
              scenario == PrototypeScenario.notificationDenied
                  ? NotificationPermissionState.denied
                  : NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.reassuranceUnknown:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: reassuranceClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: true,
          plan: fridayDinner(
            phase: PlanPhase.confirmed,
            clock: reassuranceClock,
            confirmedCandidateId: 'friday-1900',
          ),
          statuses: sharedStatuses(clock: reassuranceClock, includeDad: false),
          chatItems: openingChat(reassuranceClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.todayEmpty:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: planningClock,
          surfaceState: SurfaceState.empty,
          aiAvailable: true,
          plan: null,
          statuses: sharedStatuses(clock: planningClock),
          chatItems: openingChat(planningClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.offlineCached:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: planningClock,
          surfaceState: SurfaceState.offlineCached,
          aiAvailable: true,
          plan: fridayDinner(phase: PlanPhase.pollOpen, clock: planningClock),
          statuses: sharedStatuses(clock: planningClock),
          chatItems: openingChat(planningClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.aiUnavailable:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: reassuranceClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: false,
          plan: fridayDinner(phase: PlanPhase.pollOpen, clock: planningClock),
          statuses: sharedStatuses(clock: reassuranceClock),
          chatItems: openingChat(reassuranceClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
      case PrototypeScenario.sharingPaused:
        return PrototypeScenarioState(
          scenario: scenario,
          scenarioNow: reassuranceClock,
          surfaceState: SurfaceState.ready,
          aiAvailable: true,
          plan: fridayDinner(phase: PlanPhase.pollOpen, clock: planningClock),
          statuses: sharedStatuses(
            clock: reassuranceClock,
            abdullahState: SharingState.paused,
          ),
          chatItems: openingChat(reassuranceClock),
          ui: const PrototypeUiState(),
          notificationPermission: NotificationPermissionState.notAsked,
        );
    }
  }
}
