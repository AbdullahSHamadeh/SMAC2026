import '../domain/chat_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';

enum PrototypeScenario {
  dinnerOpportunity,
  dinnerPollOpen,
  reassuranceAtSeven,
  reassuranceUnknown,
  todayEmpty,
  offlineCached,
  aiUnavailable,
  sharingPaused,
  notificationDenied,
}

enum SurfaceState { ready, loading, empty, offlineCached }

enum CheckInState { none, requested, responded }

enum SeparateReminderState { none, drafted, confirmed }

enum NotificationPermissionState { notAsked, granted, denied }

class PrototypeUiState {
  const PrototypeUiState({
    this.selectedTab = 0,
    this.chatDraft = '',
    this.planBuilderStep = 0,
    this.selectedCandidateIds = const <String>{},
    this.selectedPollChoice,
    this.selectedPlanId,
    this.hasUnsavedPlanChanges = false,
  });

  final int selectedTab;
  final String chatDraft;
  final int planBuilderStep;
  final Set<String> selectedCandidateIds;
  final RsvpChoice? selectedPollChoice;
  final String? selectedPlanId;
  final bool hasUnsavedPlanChanges;

  PrototypeUiState copyWith({
    int? selectedTab,
    String? chatDraft,
    int? planBuilderStep,
    Set<String>? selectedCandidateIds,
    RsvpChoice? selectedPollChoice,
    bool clearSelectedPollChoice = false,
    String? selectedPlanId,
    bool? hasUnsavedPlanChanges,
  }) =>
      PrototypeUiState(
        selectedTab: selectedTab ?? this.selectedTab,
        chatDraft: chatDraft ?? this.chatDraft,
        planBuilderStep: planBuilderStep ?? this.planBuilderStep,
        selectedCandidateIds: selectedCandidateIds ?? this.selectedCandidateIds,
        selectedPollChoice: clearSelectedPollChoice
            ? null
            : selectedPollChoice ?? this.selectedPollChoice,
        selectedPlanId: selectedPlanId ?? this.selectedPlanId,
        hasUnsavedPlanChanges:
            hasUnsavedPlanChanges ?? this.hasUnsavedPlanChanges,
      );
}

class PrototypeScenarioState {
  const PrototypeScenarioState({
    required this.scenario,
    required this.scenarioNow,
    required this.surfaceState,
    required this.aiAvailable,
    required this.plan,
    required this.statuses,
    required this.chatItems,
    required this.ui,
    required this.notificationPermission,
    this.isRetrying = false,
    this.checkInState = CheckInState.none,
    this.separateReminderState = SeparateReminderState.none,
    this.dadStatusMarkedOutdated = false,
    this.hasPendingPlanChange = false,
  });

  final PrototypeScenario scenario;
  final DateTime scenarioNow;
  final SurfaceState surfaceState;
  final bool aiAvailable;
  final FamilyPlan? plan;
  final Map<String, SharedStatus> statuses;
  final List<ChatItem> chatItems;
  final PrototypeUiState ui;
  final NotificationPermissionState notificationPermission;
  final bool isRetrying;
  final CheckInState checkInState;
  final SeparateReminderState separateReminderState;
  final bool dadStatusMarkedOutdated;
  final bool hasPendingPlanChange;

  bool get hasActiveSuggestion {
    final phase = plan?.phase;
    return phase == PlanPhase.opportunity || phase == PlanPhase.draft;
  }

  PrototypeScenarioState copyWith({
    DateTime? scenarioNow,
    SurfaceState? surfaceState,
    bool? aiAvailable,
    FamilyPlan? plan,
    bool clearPlan = false,
    Map<String, SharedStatus>? statuses,
    List<ChatItem>? chatItems,
    PrototypeUiState? ui,
    NotificationPermissionState? notificationPermission,
    bool? isRetrying,
    CheckInState? checkInState,
    SeparateReminderState? separateReminderState,
    bool? dadStatusMarkedOutdated,
    bool? hasPendingPlanChange,
  }) =>
      PrototypeScenarioState(
        scenario: scenario,
        scenarioNow: scenarioNow ?? this.scenarioNow,
        surfaceState: surfaceState ?? this.surfaceState,
        aiAvailable: aiAvailable ?? this.aiAvailable,
        plan: clearPlan ? null : plan ?? this.plan,
        statuses: statuses ?? this.statuses,
        chatItems: chatItems ?? this.chatItems,
        ui: ui ?? this.ui,
        notificationPermission:
            notificationPermission ?? this.notificationPermission,
        isRetrying: isRetrying ?? this.isRetrying,
        checkInState: checkInState ?? this.checkInState,
        separateReminderState:
            separateReminderState ?? this.separateReminderState,
        dadStatusMarkedOutdated:
            dadStatusMarkedOutdated ?? this.dadStatusMarkedOutdated,
        hasPendingPlanChange: hasPendingPlanChange ?? this.hasPendingPlanChange,
      );
}
