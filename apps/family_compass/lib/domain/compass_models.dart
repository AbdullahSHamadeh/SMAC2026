enum PrototypeIntent {
  draftFridayDinner,
  whereIsDad,
  explainStatusSource,
  markStatusOutdated,
  requestCheckIn,
  draftPlanChange,
  draftSeparateReminder,
}

enum CompassFactSource {
  chatMessage,
  plan,
  reminder,
  checkIn,
  sharedUpdate,
  memberStatus,
  journey,
}

enum CompassFactAudience {
  wholeFamily,
  selectedPeople,
  onlyMe,
  requestParticipants,
}

enum CompassFactFreshness { current, recent, scheduled }

enum CompassUncertainty { low, medium, high, notApplicable }

enum CompassActionKind { openPlan, startPlan, requestCheckIn, createReminder }

class CompassCitation {
  const CompassCitation({
    required this.sourceId,
    this.subjectUserId,
    required this.sourceType,
    required this.sourceLabel,
    required this.audience,
    required this.freshness,
    required this.updatedAt,
    required this.expiresAt,
    required this.text,
  });

  final String sourceId;
  final String? subjectUserId;
  final CompassFactSource sourceType;
  final String sourceLabel;
  final CompassFactAudience audience;
  final CompassFactFreshness freshness;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String text;
}

class CompassAction {
  const CompassAction({
    required this.kind,
    required this.label,
    required this.requiresConfirmation,
    this.targetId,
  });

  final CompassActionKind kind;
  final String label;
  final bool requiresConfirmation;
  final String? targetId;
}

class CompassAnswer {
  const CompassAnswer({
    required this.text,
    required this.sourceLabel,
    required this.freshnessLabel,
    required this.hasPermittedInformation,
    this.isGeneralKnowledge = false,
    this.actionLabel,
    this.citations = const <CompassCitation>[],
    this.actions = const <CompassAction>[],
    this.familyVisible = false,
    this.uncertainty = CompassUncertainty.high,
  });

  final String text;
  final String sourceLabel;
  final String freshnessLabel;
  final bool hasPermittedInformation;
  final bool isGeneralKnowledge;
  final String? actionLabel;
  final List<CompassCitation> citations;
  final List<CompassAction> actions;
  final bool familyVisible;
  final CompassUncertainty uncertainty;
}

enum FamilyCompassArtifactKind { answer, suggestion }

class FamilyRoomCompassArtifact {
  const FamilyRoomCompassArtifact({
    required this.id,
    required this.familyId,
    required this.requestMessageId,
    required this.requestedBy,
    required this.kind,
    required this.answer,
    required this.provider,
    required this.citations,
    required this.actions,
    required this.uncertainty,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String requestMessageId;
  final String requestedBy;
  final FamilyCompassArtifactKind kind;
  final String answer;
  final String provider;
  final List<CompassCitation> citations;
  final List<CompassAction> actions;
  final CompassUncertainty uncertainty;
  final DateTime createdAt;
}
