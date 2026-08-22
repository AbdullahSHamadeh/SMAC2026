import 'dart:async';

import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/data/family_realtime_client.dart';
import 'package:family_compass/domain/chat_models.dart';
import 'package:family_compass/domain/compass_models.dart';
import 'package:family_compass/domain/family_models.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userId = '11111111-1111-4111-8111-111111111111';
const _dadId = '22222222-2222-4222-8222-222222222222';

void main() {
  test('backend controller loads family, Today, Chat, plans and statuses',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
      uuid: const Uuid(),
    );
    addTearDown(controller.dispose);

    await _settle();

    expect(controller.state.dataSourceMode, DataSourceMode.backend);
    expect(controller.state.family?.name, 'Hamadeh Family');
    expect(controller.state.plan?.id, 'plan-one');
    expect(controller.state.chatItems.single.text, 'Dinner?');
    expect(controller.state.statuses[_dadId]?.text, 'Leaving work');
    expect(controller.availableSharingRecipients.single.id, _dadId);
    expect(controller.state.surfaceState, SurfaceState.ready);
  });

  test('backend actions write through repositories instead of scripted state',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    controller.sendHumanMessage('I can come');
    controller.submitAbdullahResponse(
      candidateId: 'friday-1930',
      choice: RsvpChoice.going,
    );
    controller.requestCheckIn();
    await _settle();
    controller.sendPollNudge();
    await _settle();
    controller.confirmDinner();
    await _settle();
    controller.completeGathering();
    await _settle();

    expect(backend.chat.sentTexts, <String>['I can come']);
    expect(backend.plans.savedCandidateIds, <String>['friday-1930']);
    expect(backend.plans.nudgeCount, 1);
    expect(backend.plans.completeCount, 1);
    expect(backend.checkIns.requestedMemberIds, <String>[_dadId]);
    expect(controller.state.ui.chatDraft, isEmpty);
  });

  test('backend Chat carries only current-family structured mention ids',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    controller.sendHumanMessage(
      '@Dad Dinner is ready',
      mentionedMemberIds: const <String>{_dadId, 'removed-member'},
    );
    await _settle();

    expect(backend.chat.sentMentionSets, <Set<String>>[
      <String>{_dadId},
    ]);
  });

  test(
      'live plan draft publishes, accepts a suggested time, and adjusts reminder',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    final draft = _plan.copyWith(
      phase: PlanPhase.draft,
      candidateTimes: <CandidateTime>[
        ..._plan.candidateTimes,
        CandidateTime(
          id: 'friday-2000',
          startsAt: DateTime(2026, 8, 14, 20),
        ),
      ],
    );
    backend.plans.emitPlans(<FamilyPlan>[draft]);
    await _settle();
    controller.toggleCandidate('friday-1930');
    controller.toggleCandidate('friday-2000');
    controller.sendPoll();
    await _settle();

    expect(backend.plans.publishCount, 1);
    expect(controller.state.plan?.phase, PlanPhase.pollOpen);

    controller.suggestCandidateTime(DateTime(2026, 8, 14, 20, 30));
    await _settle();
    expect(backend.plans.suggestCount, 1);
    expect(controller.state.plan?.candidateTimes.last.startsAt.hour, 20);
    expect(controller.state.plan?.candidateTimes.last.startsAt.minute, 30);

    final confirmed = controller.state.plan!.copyWith(
      phase: PlanPhase.confirmed,
      confirmedCandidateId: 'friday-1930',
      reminders: <PlanReminder>[
        PlanReminder(
          id: 'automatic-reminder',
          label: 'Dinner starts in one hour',
          at: DateTime(2026, 8, 14, 18, 30),
          isAutomatic: true,
        ),
      ],
    );
    backend.plans.emitPlans(<FamilyPlan>[confirmed]);
    await _settle();
    controller.adjustAutomaticReminder();
    await _settle();
    expect(backend.reminders.updatedIds, <String>['automatic-reminder']);
    expect(controller.state.plan?.reminders.single.at.hour, 18);
    expect(controller.state.plan?.reminders.single.at.minute, 0);
  });

  test('rapid nudge taps start only one backend delivery', () async {
    final delayedPlans = _DelayedNudgePlanRepository();
    final backend = _BackendHarness(planRepository: delayedPlans);
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();
    controller.submitAbdullahResponse(
      candidateId: 'friday-1930',
      choice: RsvpChoice.going,
    );
    await _settle();

    controller.sendPollNudge();
    controller.sendPollNudge();
    await _settle();

    expect(delayedPlans.nudgeCount, 1);
    expect(controller.isPollNudgeInFlight, isTrue);

    delayedPlans.completeDelivery();
    await _settle();

    expect(controller.isPollNudgeInFlight, isFalse);
    expect(controller.state.plan?.nudgeSent, isTrue);
    controller.sendPollNudge();
    expect(delayedPlans.nudgeCount, 1);
  });

  test('backend retry flushes outgoing messages and refreshes surfaces',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    backend.chat.statusController.add(
      const RepositoryStatus(
        phase: RepositoryPhase.offline,
        pendingWrites: 1,
        canRetry: true,
      ),
    );
    await _settle();
    expect(controller.state.surfaceState, SurfaceState.offlineCached);

    await controller.retryOffline();

    expect(backend.chat.retryCount, 1);
    expect(backend.family.refreshCount, 1);
    expect(backend.plans.refreshCount, 1);
    expect(backend.sharing.refreshCount, 1);
    expect(backend.today.refreshCount, 1);
    expect(controller.state.surfaceState, SurfaceState.ready);
  });

  test('known-offline backend Chat queues instead of attempting a live send',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    backend.chat.statusController.add(
      const RepositoryStatus(
        phase: RepositoryPhase.offline,
        pendingWrites: 1,
        canRetry: true,
      ),
    );
    await _settle();
    controller.sendHumanMessage('Keep this until I reconnect');
    await _settle();

    expect(backend.chat.sentTexts, <String>['Keep this until I reconnect']);
    expect(backend.chat.queueOnlyValues, <bool>[true]);
    expect(controller.state.ui.chatDraft, isEmpty);
  });

  test('leave and delete discard their family-scoped pending Chat', () async {
    final leavingBackend = _BackendHarness();
    final leavingController = PrototypeScenarioController(
      repositories: leavingBackend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(leavingController.dispose);
    await _settle();

    await leavingController.leaveCurrentFamily();
    expect(leavingBackend.chat.discardedFamilyIds, <String>[_familyId]);

    final deletingBackend = _BackendHarness();
    final deletingController = PrototypeScenarioController(
      repositories: deletingBackend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(deletingController.dispose);
    await _settle();

    await deletingController.deleteCurrentFamily();
    expect(deletingBackend.chat.discardedFamilyIds, <String>[_familyId]);
  });

  testWidgets('Chat visibly moves through waiting, failed, and sent states',
      (tester) async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    controller.selectTab(1);
    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final message = ChatItem(
      id: 'pending-local-one',
      clientId: 'local-one',
      kind: ChatItemKind.message,
      authorId: _userId,
      text: 'Queued family message',
      sentAt: DateTime(2026, 8, 13, 10, 2),
      deliveryState: ChatDeliveryState.waitingToSend,
    );
    backend.chat.emitMessages(<ChatItem>[message]);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chat.message.waiting')),
      findsOneWidget,
    );

    backend.chat.emitMessages(<ChatItem>[
      message.copyWith(deliveryState: ChatDeliveryState.failed),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chat.message.failed')),
      findsOneWidget,
    );

    backend.chat.emitMessages(<ChatItem>[
      message.copyWith(deliveryState: ChatDeliveryState.sent),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('chat.message.sent')),
      findsOneWidget,
    );
  });

  testWidgets('exact message link loads and highlights the requested message',
      (tester) async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final opened = await controller.openExactDeepLink(
      const FamilyCompassDeepLink(
        familyId: _familyId,
        kind: FamilyResourceKind.messages,
        resourceId: 'message-linked',
      ),
    );
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(controller.state.ui.selectedTab, 1);
    expect(
      controller.state.chatItems.any((item) => item.id == 'message-linked'),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey<String>('chat.linked.message-linked')),
      findsOneWidget,
    );
  });

  testWidgets('exact unloaded plan link opens that plan poll', (tester) async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final opened = await controller.openExactDeepLink(
      const FamilyCompassDeepLink(
        familyId: _familyId,
        kind: FamilyResourceKind.plans,
        resourceId: 'plan-linked',
      ),
    );
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(controller.state.plan?.id, 'plan-linked');
    expect(controller.state.ui.selectedPlanId, 'plan-linked');
    expect(controller.state.ui.selectedTab, 3);
    expect(find.byKey(const ValueKey<String>('poll-detail')), findsOneWidget);
  });

  testWidgets('exact reminder link opens its unloaded parent plan',
      (tester) async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final opened = await controller.openExactDeepLink(
      const FamilyCompassDeepLink(
        familyId: _familyId,
        kind: FamilyResourceKind.reminders,
        resourceId: 'reminder-linked',
      ),
    );
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(controller.state.plan?.id, 'plan-linked');
    expect(controller.state.ui.selectedPlanId, 'plan-linked');
    expect(controller.state.ui.selectedTab, 3);
    expect(find.byKey(const ValueKey<String>('poll-detail')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'together.linkedReminder.reminder-linked',
        ),
      ),
      findsOneWidget,
    );
  });

  test('stale repository emissions do not replace an exact linked artifact',
      () async {
    final backend = _BackendHarness();
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
    );
    addTearDown(controller.dispose);
    await _settle();

    await controller.openExactDeepLink(
      const FamilyCompassDeepLink(
        familyId: _familyId,
        kind: FamilyResourceKind.messages,
        resourceId: 'message-linked',
      ),
    );
    backend.chat.emitMessages(<ChatItem>[
      ChatItem(
        id: 'message-one',
        kind: ChatItemKind.message,
        authorId: _dadId,
        text: 'Older list response',
        sentAt: DateTime(2026, 8, 13, 10),
      ),
    ]);
    await _settle();
    expect(
      controller.state.chatItems.any((item) => item.id == 'message-linked'),
      isTrue,
    );

    await controller.openExactDeepLink(
      const FamilyCompassDeepLink(
        familyId: _familyId,
        kind: FamilyResourceKind.plans,
        resourceId: 'plan-linked',
      ),
    );
    backend.plans.emitPlans(<FamilyPlan>[_plan]);
    await _settle();
    expect(controller.state.plan?.id, 'plan-linked');

    backend.plans.emitPlans(const <FamilyPlan>[]);
    await _settle();
    expect(controller.state.plan?.id, 'plan-linked');
  });

  test('forbidden family event clears stale data and reports access loss once',
      () async {
    final backend = _BackendHarness();
    final events = StreamController<FamilyEvent>.broadcast();
    final accessLost = Completer<void>();
    var accessLossCount = 0;
    final controller = PrototypeScenarioController(
      repositories: backend.repositories,
      familyId: _familyId,
      currentUserId: _userId,
      familyEvents: events.stream,
      onFamilyAccessLost: () async {
        accessLossCount += 1;
        if (!accessLost.isCompleted) accessLost.complete();
      },
    );
    addTearDown(controller.dispose);
    addTearDown(events.close);
    await _settle();

    events.addError(
      const FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.forbidden,
        message: 'Membership revoked.',
        statusCode: 403,
      ),
    );
    await accessLost.future.timeout(const Duration(seconds: 1));

    expect(accessLossCount, 1);
    expect(controller.state.family, isNotNull);
    expect(controller.state.plan, isNull);
    expect(controller.state.chatItems, isEmpty);
    expect(controller.state.statuses, isEmpty);
    expect(controller.state.surfaceState, SurfaceState.empty);
    expect(controller.state.repositoryStatus.canRetry, isFalse);

    events.addError(
      const FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.forbidden,
        message: 'Membership revoked again.',
        statusCode: 403,
      ),
    );
    await _settle();
    expect(accessLossCount, 1);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _BackendHarness {
  _BackendHarness({_PlanRepository? planRepository})
      : session = _SessionRepository(),
        family = _FamilyRepository(),
        chat = _ChatRepository(),
        plans = planRepository ?? _PlanRepository(),
        sharing = _SharingRepository(),
        compass = _CompassRepository(),
        permissions = _PermissionRepository(),
        checkIns = _CheckInRepository(),
        today = _TodayRepository(),
        journeys = _JourneyRepository(),
        reminders = _ReminderRepository() {
    repositories = FamilyCompassRepositories(
      session: session,
      family: family,
      chat: chat,
      plans: plans,
      sharing: sharing,
      compass: compass,
      permissions: permissions,
      checkIns: checkIns,
      today: today,
      journeys: journeys,
      reminders: reminders,
    );
  }

  late final FamilyCompassRepositories repositories;
  final _SessionRepository session;
  final _FamilyRepository family;
  final _ChatRepository chat;
  final _PlanRepository plans;
  final _SharingRepository sharing;
  final _CompassRepository compass;
  final _PermissionRepository permissions;
  final _CheckInRepository checkIns;
  final _TodayRepository today;
  final _JourneyRepository journeys;
  final _ReminderRepository reminders;
}

abstract class _RepositoryBase implements SyncableRepository {
  final statusController = StreamController<RepositoryStatus>.broadcast();
  int refreshCount = 0;
  int retryCount = 0;

  @override
  Stream<RepositoryStatus> get status => statusController.stream;

  @override
  Future<void> refresh() async => refreshCount += 1;

  @override
  Future<void> retryPending() async => retryCount += 1;
}

class _SessionRepository extends _RepositoryBase implements SessionRepository {
  @override
  Future<AppSession> startDevelopmentSession() async => const AppSession(
        userId: _userId,
        phoneNumber: '',
        familyIds: <String>[_familyId],
      );

  @override
  Stream<AppSession?> watchSession() => const Stream<AppSession?>.empty();

  @override
  Future<void> requestPhoneCode(String internationalPhoneNumber) async {}

  @override
  Future<AppSession> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) =>
      startDevelopmentSession();

  @override
  Future<void> signOut() async {}
}

class _FamilyRepository extends _RepositoryBase implements FamilyRepository {
  static const summary = FamilySummary(
    id: _familyId,
    name: 'Hamadeh Family',
    organizerId: _userId,
    members: <FamilyMember>[
      FamilyMember(
        id: _userId,
        name: 'Abdullah',
        relationship: 'You',
        initials: 'A',
        role: FamilyRole.coordinator,
      ),
      FamilyMember(
        id: _dadId,
        name: 'Dad',
        relationship: 'Father',
        initials: 'D',
      ),
    ],
  );

  @override
  Future<FamilySummary> createFamily(String name) async => summary;

  @override
  Future<List<FamilySummary>> listFamilies() async => <FamilySummary>[summary];

  @override
  Stream<FamilySummary> watchFamily(String familyId) =>
      Stream<FamilySummary>.value(summary);

  @override
  Stream<List<FamilyInvitation>> watchInvitations(String familyId) =>
      Stream<List<FamilyInvitation>>.value(const <FamilyInvitation>[]);

  @override
  Future<FamilyInvitation> inviteByPhone({
    required String familyId,
    required String internationalPhoneNumber,
    required String idempotencyKey,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> respondToInvitation({
    required String invitationId,
    required InvitationResponse response,
  }) async {}

  @override
  Future<void> revokeInvitation(String invitationId) async {}

  @override
  Future<void> leaveFamily(String familyId) async {}

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberId,
  }) async {}

  @override
  Future<void> deleteFamily(String familyId) async {}
}

class _ChatRepository extends _RepositoryBase implements ChatRepository {
  final sentTexts = <String>[];
  final sentMentionSets = <Set<String>>[];
  final queueOnlyValues = <bool>[];
  final discardedFamilyIds = <String>[];
  final messagesController = StreamController<List<ChatItem>>.broadcast();

  @override
  Stream<List<ChatItem>> watchMessages({
    required String familyId,
    String? afterMessageId,
  }) async* {
    yield <ChatItem>[
      ChatItem(
        id: 'message-one',
        kind: ChatItemKind.message,
        authorId: _dadId,
        text: 'Dinner?',
        sentAt: DateTime(2026, 8, 13, 10),
      ),
    ];
    yield* messagesController.stream;
  }

  void emitMessages(List<ChatItem> messages) {
    messagesController.add(List<ChatItem>.unmodifiable(messages));
  }

  @override
  Future<ChatItem> getMessage({
    required String familyId,
    required String messageId,
  }) async =>
      ChatItem(
        id: messageId,
        kind: ChatItemKind.message,
        authorId: _dadId,
        text: 'The linked message',
        sentAt: DateTime(2026, 8, 13, 9),
      );

  @override
  Future<ChatItem> sendText({
    required String familyId,
    required String text,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
    bool queueOnly = false,
  }) async {
    sentTexts.add(text);
    sentMentionSets.add(Set<String>.unmodifiable(mentionedMemberIds));
    queueOnlyValues.add(queueOnly);
    return ChatItem(
      id: 'sent-one',
      clientId: idempotencyKey,
      kind: ChatItemKind.message,
      authorId: _userId,
      text: text,
      mentionedMemberIds: mentionedMemberIds,
      sentAt: DateTime(2026, 8, 13, 10, 1),
    );
  }

  @override
  Future<void> discardPending({required String familyId}) async {
    discardedFamilyIds.add(familyId);
  }
}

FamilyPlan get _plan => FamilyPlan(
      id: 'plan-one',
      title: 'Friday dinner',
      description: 'At home',
      coordinatorId: _userId,
      participantIds: const <String>[_userId, _dadId],
      candidateTimes: <CandidateTime>[
        CandidateTime(
          id: 'friday-1930',
          startsAt: DateTime(2026, 8, 14, 19, 30),
        ),
      ],
      phase: PlanPhase.pollOpen,
      decisionDeadline: DateTime(2026, 8, 14, 12),
      version: 2,
    );

FamilyPlan get _linkedPlan => FamilyPlan(
      id: 'plan-linked',
      title: 'Linked family poll',
      description: 'Loaded only when its notification is opened',
      coordinatorId: _userId,
      participantIds: const <String>[_userId, _dadId],
      candidateTimes: <CandidateTime>[
        CandidateTime(
          id: 'linked-saturday-1800',
          startsAt: DateTime(2026, 8, 15, 18),
        ),
      ],
      phase: PlanPhase.pollOpen,
      decisionDeadline: DateTime(2026, 8, 15, 12),
      reminders: <PlanReminder>[
        PlanReminder(
          id: 'reminder-linked',
          label: 'Linked reminder',
          at: DateTime(2026, 8, 15, 16),
        ),
      ],
      version: 1,
    );

class _PlanRepository extends _RepositoryBase implements PlanRepository {
  final savedCandidateIds = <String>[];
  int nudgeCount = 0;
  int completeCount = 0;
  int publishCount = 0;
  int suggestCount = 0;
  final planController = StreamController<List<FamilyPlan>>.broadcast();

  @override
  Future<FamilyPlan> createPlan({
    required String familyId,
    required String title,
    String? locationLabel,
    required List<String> participantIds,
    required List<CandidateTime> candidateTimes,
    required DateTime decisionDeadline,
  }) async =>
      _plan;

  void emitPlans(List<FamilyPlan> plans) {
    planController.add(List<FamilyPlan>.unmodifiable(plans));
  }

  @override
  Future<FamilyPlan> publishPlan({
    required String familyId,
    required String planId,
    required Set<String> candidateIds,
    required int expectedVersion,
  }) async {
    publishCount += 1;
    return _plan.copyWith(
      phase: PlanPhase.pollOpen,
      version: expectedVersion + 1,
    );
  }

  @override
  Future<FamilyPlan> suggestCandidateTime({
    required String familyId,
    required String planId,
    required CandidateTime candidate,
    required int expectedVersion,
  }) async {
    suggestCount += 1;
    return _plan.copyWith(
      candidateTimes: <CandidateTime>[..._plan.candidateTimes, candidate],
      version: expectedVersion + 1,
    );
  }

  @override
  Stream<List<FamilyPlan>> watchPlans(String familyId) async* {
    yield <FamilyPlan>[_plan];
    yield* planController.stream;
  }

  @override
  Future<FamilyPlan> getPlan({
    required String familyId,
    required String planId,
  }) async =>
      planId == _linkedPlan.id ? _linkedPlan : _plan;

  @override
  Future<FamilyPlan> getPlanForReminder({
    required String familyId,
    required String reminderId,
  }) async =>
      reminderId == 'reminder-linked' ? _linkedPlan : _plan;

  @override
  Future<FamilyPlan> saveResponse({
    required String planId,
    required String candidateId,
    required RsvpChoice choice,
    required int expectedVersion,
  }) async {
    savedCandidateIds.add(candidateId);
    return _plan.copyWith(
      responses: <String, PollResponse>{
        _userId: PollResponse(
          memberId: _userId,
          candidateId: candidateId,
          choice: choice,
        ),
      },
      version: expectedVersion + 1,
    );
  }

  @override
  Future<FamilyPlan> confirmPlan({
    required String planId,
    required String candidateId,
    required int expectedVersion,
  }) async =>
      _plan.copyWith(
        phase: PlanPhase.confirmed,
        confirmedCandidateId: candidateId,
      );

  @override
  Future<FamilyPlan> addContribution({
    required String familyId,
    required String planId,
    required String text,
  }) async =>
      _plan.copyWith(
        contributions: <PlanContribution>[
          PlanContribution(id: 'contribution', memberId: _userId, text: text),
        ],
      );

  @override
  Future<FamilyPlan> sendNudge({
    required String familyId,
    required String planId,
  }) async {
    nudgeCount += 1;
    return _plan.copyWith(
      responses: <String, PollResponse>{
        _userId: const PollResponse(
          memberId: _userId,
          candidateId: 'friday-1930',
          choice: RsvpChoice.going,
        ),
      },
      nudgeSent: true,
      phase: PlanPhase.readyToConfirm,
    );
  }

  @override
  Future<FamilyPlan> completePlan({
    required String familyId,
    required String planId,
  }) async {
    completeCount += 1;
    return _plan.copyWith(phase: PlanPhase.completed);
  }
}

class _DelayedNudgePlanRepository extends _PlanRepository {
  final Completer<FamilyPlan> _delivery = Completer<FamilyPlan>();

  @override
  Future<FamilyPlan> sendNudge({
    required String familyId,
    required String planId,
  }) {
    nudgeCount += 1;
    return _delivery.future;
  }

  void completeDelivery() {
    _delivery.complete(
      _plan.copyWith(
        responses: <String, PollResponse>{
          _userId: const PollResponse(
            memberId: _userId,
            candidateId: 'friday-1930',
            choice: RsvpChoice.going,
          ),
        },
        nudgeSent: true,
        nudgedAt: DateTime.utc(2026, 8, 13, 10),
        nudgeDeliveredAt: DateTime.utc(2026, 8, 13, 10, 0, 1),
      ),
    );
  }
}

class _SharingRepository extends _RepositoryBase implements SharingRepository {
  final dadStatus = SharedStatus(
    id: 'status-one',
    memberId: _dadId,
    text: 'Leaving work',
    updatedAt: DateTime(2026, 8, 13, 10),
    expiresAt: DateTime(2026, 8, 13, 11),
    audience: SharingAudience.wholeFamily,
    recipientIds: const <String>{},
    state: SharingState.active,
  );

  @override
  Stream<List<SharedStatus>> watchPermittedStatuses(String familyId) =>
      Stream<List<SharedStatus>>.value(<SharedStatus>[dadStatus]);

  @override
  Future<SharedStatus> shareManualStatus({
    required String familyId,
    required String text,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) async =>
      dadStatus;

  @override
  Future<void> pauseStatus(String statusId) async {}

  @override
  Future<void> revokeStatus(String statusId) async {}
}

class _CompassRepository implements CompassRepository {
  @override
  Future<CompassAnswer> ask({
    required String conversationId,
    required String question,
    CompassVisibility visibility = CompassVisibility.private,
  }) async =>
      const CompassAnswer(
        text: 'Answer',
        sourceLabel: 'Source',
        freshnessLabel: '',
        hasPermittedInformation: false,
      );
}

class _PermissionRepository extends _RepositoryBase
    implements PermissionRepository {
  @override
  Stream<List<FamilyPermission>> watchPermissions(String familyId) =>
      Stream<List<FamilyPermission>>.value(const <FamilyPermission>[]);

  @override
  Future<FamilyPermission> setInvitePermission({
    required String familyId,
    required String memberId,
    required bool canInvite,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> setExternalAIConsent({
    required String familyId,
    required bool allowed,
  }) async {}
}

class _CheckInRepository extends _RepositoryBase implements CheckInRepository {
  final requestedMemberIds = <String>[];

  @override
  Future<FamilyCheckIn> request({
    required String familyId,
    required String memberId,
  }) async {
    requestedMemberIds.add(memberId);
    return FamilyCheckIn(
      id: 'check-in-one',
      familyId: familyId,
      requesterId: _userId,
      memberId: memberId,
      state: 'requested',
      createdAt: DateTime(2026, 8, 13, 10),
    );
  }
}

class _TodayRepository extends _RepositoryBase implements TodayRepository {
  @override
  Stream<TodayOverview> watchToday(String familyId) =>
      Stream<TodayOverview>.value(
        TodayOverview(
          nextPlan: _plan,
          needsReply: <FamilyPlan>[_plan],
          sharedUpdates: const <SharedStatus>[],
        ),
      );
}

class _JourneyRepository extends _RepositoryBase implements JourneyRepository {
  @override
  Stream<List<FamilyJourney>> watchJourneys(String familyId) =>
      Stream<List<FamilyJourney>>.value(const <FamilyJourney>[]);

  @override
  Future<FamilyJourney> createJourney({
    required String familyId,
    required String summary,
    required String status,
    DateTime? eta,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) async =>
      FamilyJourney(
        id: 'journey-one',
        memberId: _userId,
        summary: summary,
        updatedAt: DateTime(2026, 8, 13, 10),
        eta: eta,
        expiresAt: expiresAt,
      );

  @override
  Future<void> endJourney({
    required String familyId,
    required String journeyId,
    bool completed = true,
  }) async {}
}

class _ReminderRepository extends _RepositoryBase
    implements ReminderRepository {
  final updatedIds = <String>[];
  @override
  Stream<List<PlanReminder>> watchReminders(String familyId) =>
      Stream<List<PlanReminder>>.value(const <PlanReminder>[]);

  @override
  Future<PlanReminder> createReminder({
    required String familyId,
    required String planId,
    required String label,
    required DateTime at,
  }) async =>
      PlanReminder(id: 'reminder', label: label, at: at);

  @override
  Future<PlanReminder> updateReminder({
    required String familyId,
    required String reminderId,
    required DateTime at,
  }) async {
    updatedIds.add(reminderId);
    return PlanReminder(id: reminderId, label: 'Updated reminder', at: at);
  }
}
