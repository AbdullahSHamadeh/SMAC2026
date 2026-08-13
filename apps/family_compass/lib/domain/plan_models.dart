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
  const CandidateTime({
    required this.id,
    required this.startsAt,
    this.timeZone = 'Asia/Dubai',
  });

  final String id;
  final DateTime startsAt;
  final String timeZone;
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
    this.locationLabel,
    this.version = 1,
    this.responses = const <String, PollResponse>{},
    this.confirmedCandidateId,
    this.nudgeSent = false,
    this.nudgedAt,
    this.nudgeDeliveredAt,
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
  final String? locationLabel;
  final int version;
  final Map<String, PollResponse> responses;
  final String? confirmedCandidateId;
  final bool nudgeSent;
  final DateTime? nudgedAt;
  final DateTime? nudgeDeliveredAt;
  final List<PlanReminder> reminders;
  final List<PlanContribution> contributions;

  /// The server accepted a nudge attempt but did not record delivery. This
  /// state remains retryable after the backend releases its dispatch claim.
  bool get nudgeDeliveryFailed =>
      nudgedAt != null && nudgeDeliveredAt == null && !nudgeSent;

  CandidateTime? get confirmedTime {
    final id = confirmedCandidateId;
    if (id == null) return null;
    for (final candidate in candidateTimes) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  CandidateTime? candidateById(String? id) {
    if (id == null) return null;
    for (final candidate in candidateTimes) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  /// The time the interface should present as the plan's current choice.
  ///
  /// A confirmed time always wins. Before confirmation, a member's own
  /// response is the most relevant choice. Otherwise the strongest family
  /// preference is used, with the latest proposed time breaking a tie.
  CandidateTime? displayCandidate({String? memberId}) {
    final confirmed = confirmedTime;
    if (confirmed != null) return confirmed;

    final memberChoice = candidateById(responses[memberId]?.candidateId);
    if (memberChoice != null) return memberChoice;
    if (candidateTimes.isEmpty) return null;

    var selected = candidateTimes.last;
    var selectedScore = -1;
    for (final candidate in candidateTimes.reversed) {
      final score = responses.values.where((response) {
        return response.candidateId == candidate.id &&
            response.choice != RsvpChoice.cannotMakeIt;
      }).length;
      if (score > selectedScore) {
        selected = candidate;
        selectedScore = score;
      }
    }
    return selected;
  }

  int get attendingCount {
    final selectedId = displayCandidate()?.id;
    final replies = responses.values.where((response) {
      return response.choice != RsvpChoice.cannotMakeIt &&
          (selectedId == null || response.candidateId == selectedId);
    }).length;
    if (replies > 0) return replies;
    return phase == PlanPhase.confirmed || phase == PlanPhase.completed
        ? participantIds.length
        : 0;
  }

  FamilyPlan copyWith({
    PlanPhase? phase,
    DateTime? decisionDeadline,
    List<CandidateTime>? candidateTimes,
    Map<String, PollResponse>? responses,
    String? confirmedCandidateId,
    bool clearConfirmedCandidate = false,
    bool? nudgeSent,
    DateTime? nudgedAt,
    DateTime? nudgeDeliveredAt,
    List<PlanReminder>? reminders,
    List<PlanContribution>? contributions,
    String? locationLabel,
    int? version,
  }) =>
      FamilyPlan(
        id: id,
        title: title,
        description: description,
        coordinatorId: coordinatorId,
        participantIds: participantIds,
        candidateTimes: candidateTimes ?? this.candidateTimes,
        phase: phase ?? this.phase,
        decisionDeadline: decisionDeadline ?? this.decisionDeadline,
        locationLabel: locationLabel ?? this.locationLabel,
        version: version ?? this.version,
        responses: responses ?? this.responses,
        confirmedCandidateId: clearConfirmedCandidate
            ? null
            : confirmedCandidateId ?? this.confirmedCandidateId,
        nudgeSent: nudgeSent ?? this.nudgeSent,
        nudgedAt: nudgedAt ?? this.nudgedAt,
        nudgeDeliveredAt: nudgeDeliveredAt ?? this.nudgeDeliveredAt,
        reminders: reminders ?? this.reminders,
        contributions: contributions ?? this.contributions,
      );
}
