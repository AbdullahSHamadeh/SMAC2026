import '../domain/chat_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';

final DateTime planningStart = DateTime(2026, 8, 6, 18);
final DateTime fridaySeven = DateTime(2026, 8, 7, 19);
final DateTime fridaySevenThirty = DateTime(2026, 8, 7, 19, 30);

const familyMembers = <FamilyMember>[
  FamilyMember(
    id: 'abdullah',
    name: 'Abdullah',
    relationship: 'You',
    initials: 'AH',
    role: FamilyRole.coordinator,
  ),
  FamilyMember(
    id: 'dad',
    name: 'Dad',
    relationship: 'Father',
    initials: 'D',
  ),
  FamilyMember(
    id: 'mom',
    name: 'Mom',
    relationship: 'Mother',
    initials: 'M',
  ),
  FamilyMember(
    id: 'sara',
    name: 'Sara',
    relationship: 'Sister',
    initials: 'S',
  ),
];

FamilyPlan fridayDinner({
  required PlanPhase phase,
  required DateTime clock,
  String? confirmedCandidateId,
}) {
  final reminders = phase == PlanPhase.confirmed || phase == PlanPhase.completed
      ? <PlanReminder>[
          PlanReminder(
            id: 'automatic-gathering-reminder',
            label: 'Family dinner starts in 2 hours',
            at: DateTime(2026, 8, 7, 17, 30),
            isAutomatic: true,
          ),
        ]
      : const <PlanReminder>[];
  return FamilyPlan(
    id: 'friday-dinner',
    title: 'Friday family dinner',
    description: 'Dinner together at home',
    coordinatorId: 'abdullah',
    participantIds: const ['abdullah', 'dad', 'mom', 'sara'],
    candidateTimes: [
      CandidateTime(id: 'friday-1900', startsAt: fridaySeven),
      CandidateTime(id: 'friday-1930', startsAt: fridaySevenThirty),
    ],
    phase: phase,
    decisionDeadline: DateTime(2026, 8, 7, 12),
    confirmedCandidateId: confirmedCandidateId,
    reminders: reminders,
  );
}

Map<String, SharedStatus> sharedStatuses({
  required DateTime clock,
  bool includeDad = true,
  SharingState abdullahState = SharingState.active,
}) {
  return <String, SharedStatus>{
    if (includeDad)
      'dad': SharedStatus(
        id: 'dad-leaving-work',
        memberId: 'dad',
        text: 'Leaving work, ETA around 7:20 PM',
        updatedAt: clock.subtract(const Duration(minutes: 3)),
        expiresAt: clock.add(const Duration(hours: 1)),
        audience: SharingAudience.selectedPeople,
        state: SharingState.active,
      ),
    'abdullah': SharedStatus(
      id: 'abdullah-check-in',
      memberId: 'abdullah',
      text: 'At university until 4:30 PM',
      updatedAt: clock.subtract(const Duration(minutes: 8)),
      expiresAt: clock.add(const Duration(hours: 2)),
      audience: SharingAudience.wholeFamily,
      state: abdullahState,
    ),
  };
}

List<ChatItem> openingChat(DateTime clock) => <ChatItem>[
      ChatItem(
        id: 'opening-mom',
        kind: ChatItemKind.message,
        authorId: 'mom',
        text: 'Could we have dinner this Friday?',
        sentAt: clock.subtract(const Duration(minutes: 9)),
      ),
      ChatItem(
        id: 'opening-dad',
        kind: ChatItemKind.message,
        authorId: 'dad',
        text: 'I should be free after work.',
        sentAt: clock.subtract(const Duration(minutes: 6)),
      ),
    ];

FamilyMember memberById(String id) =>
    familyMembers.firstWhere((member) => member.id == id);
