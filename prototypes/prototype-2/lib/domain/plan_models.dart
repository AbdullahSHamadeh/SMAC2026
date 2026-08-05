enum PlanPhase {
  opportunity,
  draft,
  pollOpen,
  readyToConfirm,
  confirmed,
  completed,
}

enum RsvpChoice { going, maybe, cannotMakeIt }

class CandidateTime {
  const CandidateTime({required this.id, required this.startsAt});

  final String id;
  final DateTime startsAt;
}

class PollResponse {
  const PollResponse({
    required this.memberId,
    required this.candidateId,
    required this.choice,
  });

  final String memberId;
  final String candidateId;
  final RsvpChoice choice;
}

class PlanReminder {
  const PlanReminder({
    required this.id,
    required this.label,
    required this.at,
    this.isAutomatic = false,
    this.isConfirmed = true,
  });

  final String id;
  final String label;
  final DateTime at;
  final bool isAutomatic;
  final bool isConfirmed;

  PlanReminder copyWith({DateTime? at, bool? isConfirmed}) => PlanReminder(
        id: id,
        label: label,
        at: at ?? this.at,
        isAutomatic: isAutomatic,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );
}

class PlanContribution {
  const PlanContribution({
    required this.id,
    required this.memberId,
    required this.text,
  });

  final String id;
  final String memberId;
  final String text;
}

class FamilyPlan {
  const FamilyPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.coordinatorId,
    required this.participantIds,
    required this.candidateTimes,
    required this.phase,
    required this.decisionDeadline,
    this.responses = const <String, PollResponse>{},
    this.confirmedCandidateId,
    this.nudgeSent = false,
    this.reminders = const <PlanReminder>[],
    this.contributions = const <PlanContribution>[],
  });

  final String id;
  final String title;
  final String description;
  final String coordinatorId;
  final List<String> participantIds;
  final List<CandidateTime> candidateTimes;
  final PlanPhase phase;
  final DateTime decisionDeadline;
  final Map<String, PollResponse> responses;
  final String? confirmedCandidateId;
  final bool nudgeSent;
  final List<PlanReminder> reminders;
  final List<PlanContribution> contributions;

  CandidateTime? get confirmedTime {
    final id = confirmedCandidateId;
    if (id == null) return null;
    for (final candidate in candidateTimes) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  FamilyPlan copyWith({
    PlanPhase? phase,
    DateTime? decisionDeadline,
    Map<String, PollResponse>? responses,
    String? confirmedCandidateId,
    bool clearConfirmedCandidate = false,
    bool? nudgeSent,
    List<PlanReminder>? reminders,
    List<PlanContribution>? contributions,
  }) =>
      FamilyPlan(
        id: id,
        title: title,
        description: description,
        coordinatorId: coordinatorId,
        participantIds: participantIds,
        candidateTimes: candidateTimes,
        phase: phase ?? this.phase,
        decisionDeadline: decisionDeadline ?? this.decisionDeadline,
        responses: responses ?? this.responses,
        confirmedCandidateId: clearConfirmedCandidate
            ? null
            : confirmedCandidateId ?? this.confirmedCandidateId,
        nudgeSent: nudgeSent ?? this.nudgeSent,
        reminders: reminders ?? this.reminders,
        contributions: contributions ?? this.contributions,
      );
}
