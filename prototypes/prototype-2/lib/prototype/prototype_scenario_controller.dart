import 'package:flutter/foundation.dart';

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
  }) : _retryAction = retryAction ?? _defaultRetry {
    _state = _buildScenario(initialScenario);
  }

  late PrototypeScenarioState _state;
  final Future<void> Function() _retryAction;

  PrototypeScenarioState get state => _state;

  static Future<void> _defaultRetry() =>
      Future<void>.delayed(const Duration(milliseconds: 550));

  void reset(PrototypeScenario scenario) {
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

  void sendPoll() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.draft) return;
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

  void submitAbdullahResponse({
    String candidateId = 'friday-1930',
    RsvpChoice choice = RsvpChoice.going,
  }) {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.pollOpen) return;
    final responses = <String, PollResponse>{
      ...plan.responses,
      'abdullah': PollResponse(
        memberId: 'abdullah',
        candidateId: candidateId,
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

  void sendPollNudge() {
    final plan = _state.plan;
    if (plan == null ||
        plan.nudgeSent ||
        !plan.responses.containsKey('abdullah')) {
      return;
    }
    final responses = <String, PollResponse>{
      ...plan.responses,
      'sara': const PollResponse(
        memberId: 'sara',
        candidateId: 'friday-1930',
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

  void confirmDinner() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.readyToConfirm) return;
    final reminder = PlanReminder(
      id: 'automatic-gathering-reminder',
      label: 'Family dinner starts in 2 hours',
      at: DateTime(2026, 8, 7, 17, 30),
      isAutomatic: true,
    );
    _state = _state.copyWith(
      plan: plan.copyWith(
        phase: PlanPhase.confirmed,
        confirmedCandidateId: 'friday-1930',
        reminders: [reminder],
      ),
      chatItems: [
        ..._state.chatItems,
        ChatItem(
          id: 'confirmed-dinner-card',
          kind: ChatItemKind.confirmedPlan,
          authorId: 'abdullah',
          text: 'Friday dinner is confirmed for 7:30 PM.',
          sentAt: _state.scenarioNow,
          referenceId: plan.id,
        ),
      ],
    );
    notifyListeners();
  }

  void adjustAutomaticReminder() {
    final plan = _state.plan;
    if (plan == null || plan.reminders.isEmpty) return;
    final reminders = [...plan.reminders];
    reminders[0] = reminders[0].copyWith(at: DateTime(2026, 8, 7, 18));
    _state = _state.copyWith(plan: plan.copyWith(reminders: reminders));
    notifyListeners();
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

  void completeGathering() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.confirmed) return;
    _state = _state.copyWith(plan: plan.copyWith(phase: PlanPhase.completed));
    notifyListeners();
  }

  void planAgain() {
    final plan = _state.plan;
    if (plan == null || plan.phase != PlanPhase.completed) return;
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
    _state = _state.copyWith(
      plan: plan.copyWith(confirmedCandidateId: 'friday-1930'),
      hasPendingPlanChange: false,
    );
    notifyListeners();
  }

  void requestCheckIn() {
    if (_state.checkInState != CheckInState.none) return;
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

  void receiveCheckIn() {
    if (_state.checkInState != CheckInState.requested) return;
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

  void correctOwnStatus(String text) {
    final status = _state.statuses['abdullah'];
    if (status == null) return;
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        'abdullah': status.copyWith(text: text, updatedAt: _state.scenarioNow),
      },
    );
    notifyListeners();
  }

  void setOwnAudience(SharingAudience audience) {
    final status = _state.statuses['abdullah'];
    if (status == null) return;
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        'abdullah': status.copyWith(audience: audience),
      },
    );
    notifyListeners();
  }

  void shortenOwnStatus() {
    final status = _state.statuses['abdullah'];
    if (status == null) return;
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        'abdullah': status.copyWith(
          expiresAt: _state.scenarioNow.add(const Duration(minutes: 30)),
        ),
      },
    );
    notifyListeners();
  }

  void pauseOwnSharing() {
    final status = _state.statuses['abdullah'];
    if (status == null) return;
    _state = _state.copyWith(
      statuses: {
        ..._state.statuses,
        'abdullah': status.copyWith(state: SharingState.paused),
      },
    );
    notifyListeners();
  }

  Future<void> retryOffline() async {
    if (_state.surfaceState != SurfaceState.offlineCached ||
        _state.isRetrying) {
      return;
    }
    _state = _state.copyWith(isRetrying: true);
    notifyListeners();
    await _retryAction();
    _state = _state.copyWith(
      surfaceState: SurfaceState.ready,
      isRetrying: false,
    );
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
