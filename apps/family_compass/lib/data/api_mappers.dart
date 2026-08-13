import '../domain/chat_models.dart';
import '../domain/compass_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';
import 'family_compass_repositories.dart';

Map<String, dynamic> asJsonObject(Object? value, {required String label}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$label is not a JSON object.');
}

List<Map<String, dynamic>> asJsonObjectList(
  Object? value, {
  required String label,
}) {
  if (value is! List) throw FormatException('$label is not a JSON list.');
  return value.map((item) => asJsonObject(item, label: '$label item')).toList();
}

Set<String> asStringSet(Object? value, {required String label}) {
  if (value == null) return const <String>{};
  if (value is! List) throw FormatException('$label is not a JSON list.');
  final result = <String>{};
  for (final item in value) {
    if (item is! String) {
      throw FormatException('$label contains a non-string value.');
    }
    result.add(item);
  }
  return Set.unmodifiable(result);
}

FamilyMember memberFromApi(
  Object? value, {
  required String currentUserId,
}) {
  final json = asJsonObject(value, label: 'Family member');
  final user = asJsonObject(json['user'], label: 'Family member user');
  final id = user['id'] as String;
  final name = user['name'] as String;
  return FamilyMember(
    id: id,
    name: name,
    relationshipKind: id == currentUserId
        ? FamilyRelationshipKind.self
        : FamilyRelationshipKind.familyMember,
    initials: _initials(name),
    role: json['role'] == 'organizer'
        ? FamilyRole.coordinator
        : FamilyRole.member,
    canInvite: json['can_invite'] as bool? ?? false,
  );
}

FamilyInvitation invitationFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Invitation');
  return FamilyInvitation(
    id: json['id'] as String,
    familyId: json['family_id'] as String,
    maskedPhoneNumber: json['masked_phone_number'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    state: _invitationState(json['state'] as String? ?? 'pending'),
  );
}

ChatItem chatItemFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Message');
  return ChatItem(
    id: json['id'] as String,
    clientId: json['client_id'] as String?,
    kind: _chatKind(json['kind'] as String? ?? 'text'),
    authorId: json['sender_id'] as String,
    text: json['body'] as String,
    sentAt: DateTime.parse(json['created_at'] as String),
    mentionedMemberIds:
        asStringSet(json['mentioned_member_ids'], label: 'Mentioned members'),
    referenceId: json['reference_id'] as String?,
  );
}

CompassCitation compassCitationFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Compass citation');
  return CompassCitation(
    sourceId: json['source_id'] as String,
    subjectUserId: json['subject_user_id'] as String?,
    sourceType: _compassFactSource(json['source_type'] as String),
    sourceLabel: json['source_label'] as String,
    audience: _compassFactAudience(json['audience'] as String),
    freshness: _compassFactFreshness(json['freshness'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    text: json['text'] as String,
  );
}

CompassAction compassActionFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Compass action');
  return CompassAction(
    kind: _compassActionKind(json['kind'] as String),
    label: json['label'] as String,
    requiresConfirmation: json['requires_confirmation'] as bool? ?? true,
    targetId: json['target_id'] as String?,
  );
}

FamilyRoomCompassArtifact familyRoomCompassArtifactFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Family-room Compass artifact');
  return FamilyRoomCompassArtifact(
    id: json['id'] as String,
    familyId: json['family_id'] as String,
    requestMessageId: json['request_message_id'] as String,
    requestedBy: json['requested_by'] as String,
    kind: json['kind'] == 'suggestion'
        ? FamilyCompassArtifactKind.suggestion
        : FamilyCompassArtifactKind.answer,
    answer: json['answer'] as String,
    provider: json['provider'] as String,
    citations: asJsonObjectList(
      json['grounded_facts'] ?? const <Object>[],
      label: 'Compass citations',
    ).map(compassCitationFromApi).toList(),
    actions: asJsonObjectList(
      json['actions'] ?? const <Object>[],
      label: 'Compass actions',
    ).map(compassActionFromApi).toList(),
    uncertainty: _compassUncertainty(json['uncertainty'] as String? ?? 'high'),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

SharedStatus sharedStatusFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Shared update');
  final audience =
      _sharingAudience(json['audience'] as String? ?? 'whole_family');
  final selected = (json['selected_member_ids'] as List? ?? const <Object>[])
      .map((id) => id.toString())
      .toSet();
  return SharedStatus(
    id: json['id'] as String,
    memberId: json['subject_user_id'] as String,
    text: json['text'] as String,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    audience: audience,
    recipientIds: audience == SharingAudience.selectedPeople
        ? selected
        : const <String>{},
    state: _sharingState(json['state'] as String? ?? 'active'),
  );
}

FamilyPlan planFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Plan');
  final responseJson = json['responses'];
  final responses = <String, PollResponse>{};
  if (responseJson is Map) {
    for (final entry in responseJson.entries) {
      final response = asJsonObject(entry.value, label: 'Plan response');
      responses[entry.key.toString()] = PollResponse(
        memberId: response['member_id'] as String,
        candidateId: response['candidate_id'] as String,
        choice: _rsvp(response['choice'] as String),
      );
    }
  }
  return FamilyPlan(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['location_label'] as String? ?? '',
    locationLabel: json['location_label'] as String?,
    coordinatorId: json['coordinator_id'] as String,
    participantIds:
        (json['participant_ids'] as List).map((id) => id.toString()).toList(),
    candidateTimes: asJsonObjectList(
      json['candidate_times'],
      label: 'Candidate times',
    )
        .map(
          (candidate) => CandidateTime(
            id: candidate['id'] as String,
            startsAt: DateTime.parse(candidate['starts_at'] as String),
            timeZone: candidate['time_zone'] as String? ?? 'Asia/Dubai',
          ),
        )
        .toList(),
    phase: _planPhase(json['phase'] as String),
    decisionDeadline: DateTime.parse(json['decision_deadline'] as String),
    responses: responses,
    confirmedCandidateId: json['confirmed_candidate_id'] as String?,
    nudgeSent: json['nudge_delivered_at'] != null,
    nudgedAt: _nullableDateTime(json['nudged_at']),
    nudgeDeliveredAt: _nullableDateTime(json['nudge_delivered_at']),
    reminders: asJsonObjectList(
      json['reminders'] ?? const <Object>[],
      label: 'Plan reminders',
    )
        .map(
          (reminder) => PlanReminder(
            id: reminder['id'] as String,
            label: reminder['label'] as String,
            at: DateTime.parse(reminder['at'] as String),
            isAutomatic: reminder['automatic'] as bool? ?? false,
          ),
        )
        .toList(),
    contributions: asJsonObjectList(
      json['contributions'] ?? const <Object>[],
      label: 'Plan contributions',
    )
        .map(
          (contribution) => PlanContribution(
            id: contribution['id'] as String,
            memberId: contribution['member_id'] as String,
            text: contribution['text'] as String,
          ),
        )
        .toList(),
    version: json['version'] as int? ?? 1,
  );
}

DateTime? _nullableDateTime(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

FamilyCheckIn checkInFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Check-in');
  return FamilyCheckIn(
    id: json['id'] as String,
    familyId: json['family_id'] as String,
    requesterId: json['requester_id'] as String,
    memberId: json['subject_user_id'] as String,
    state: json['state'] as String? ?? 'requested',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

FamilyJourney journeyFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Journey');
  return FamilyJourney(
    id: json['id'] as String,
    memberId: (json['member_id'] ?? json['subject_user_id']) as String,
    summary: (json['summary'] ?? json['status']) as String,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    eta: json['eta'] == null ? null : DateTime.parse(json['eta'] as String),
  );
}

PlanReminder reminderFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Reminder');
  return PlanReminder(
    id: json['id'] as String,
    label: json['label'] as String,
    at: DateTime.parse(json['at'] as String),
    isAutomatic: json['automatic'] as bool? ?? false,
  );
}

MemberStatusSummary memberStatusFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Member status');
  return MemberStatusSummary(
    id: json['id'] as String,
    memberId: json['subject_user_id'] as String,
    summary: json['summary'] as String,
    detail: json['detail'] as String?,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    state: _sharingState(json['state'] as String? ?? 'active'),
  );
}

DeviceRegistration deviceFromApi(Object? value) {
  final json = asJsonObject(value, label: 'Device registration');
  return DeviceRegistration(
    id: json['id'] as String,
    platform: switch (json['platform']) {
      'android' => DevicePlatform.android,
      'web' => DevicePlatform.web,
      _ => DevicePlatform.ios,
    },
    enabled: json['enabled'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  return words
      .take(2)
      .where((word) => word.isNotEmpty)
      .map((word) => word[0])
      .join();
}

FamilyInvitationState _invitationState(String value) => switch (value) {
      'accepted' => FamilyInvitationState.accepted,
      'declined' => FamilyInvitationState.declined,
      'revoked' => FamilyInvitationState.revoked,
      'expired' => FamilyInvitationState.expired,
      _ => FamilyInvitationState.pending,
    };

ChatItemKind _chatKind(String value) => switch (value) {
      'compass_question' => ChatItemKind.message,
      'check_in' => ChatItemKind.checkInRequest,
      'plan' => ChatItemKind.compassDraft,
      'poll' => ChatItemKind.poll,
      'reminder' => ChatItemKind.reminderConfirmed,
      _ => ChatItemKind.message,
    };

CompassFactSource _compassFactSource(String value) => switch (value) {
      'chat_message' => CompassFactSource.chatMessage,
      'plan' => CompassFactSource.plan,
      'reminder' => CompassFactSource.reminder,
      'check_in' => CompassFactSource.checkIn,
      'member_status' => CompassFactSource.memberStatus,
      'journey' => CompassFactSource.journey,
      _ => CompassFactSource.sharedUpdate,
    };

CompassFactAudience _compassFactAudience(String value) => switch (value) {
      'selected_people' => CompassFactAudience.selectedPeople,
      'self_only' => CompassFactAudience.onlyMe,
      'request_participants' => CompassFactAudience.requestParticipants,
      _ => CompassFactAudience.wholeFamily,
    };

CompassFactFreshness _compassFactFreshness(String value) => switch (value) {
      'recent' => CompassFactFreshness.recent,
      'scheduled' => CompassFactFreshness.scheduled,
      _ => CompassFactFreshness.current,
    };

CompassUncertainty _compassUncertainty(String value) => switch (value) {
      'low' => CompassUncertainty.low,
      'medium' => CompassUncertainty.medium,
      'not_applicable' => CompassUncertainty.notApplicable,
      _ => CompassUncertainty.high,
    };

CompassActionKind _compassActionKind(String value) => switch (value) {
      'open_plan' => CompassActionKind.openPlan,
      'start_plan' => CompassActionKind.startPlan,
      'create_reminder' => CompassActionKind.createReminder,
      _ => CompassActionKind.requestCheckIn,
    };

SharingAudience _sharingAudience(String value) => switch (value) {
      'selected_people' => SharingAudience.selectedPeople,
      'self_only' => SharingAudience.onlyMe,
      _ => SharingAudience.wholeFamily,
    };

SharingState _sharingState(String value) => switch (value) {
      'paused' => SharingState.paused,
      'revoked' => SharingState.revoked,
      _ => SharingState.active,
    };

PlanPhase _planPhase(String value) => switch (value) {
      'draft' => PlanPhase.draft,
      'poll_open' => PlanPhase.pollOpen,
      'ready_to_confirm' => PlanPhase.readyToConfirm,
      'confirmed' => PlanPhase.confirmed,
      'completed' => PlanPhase.completed,
      // The current mobile domain has no cancelled-plan presentation yet.
      // Treat it as closed until that state is designed across all surfaces.
      'cancelled' => PlanPhase.completed,
      _ => PlanPhase.opportunity,
    };

RsvpChoice _rsvp(String value) => switch (value) {
      'maybe' => RsvpChoice.maybe,
      'cannot_make_it' => RsvpChoice.cannotMakeIt,
      _ => RsvpChoice.going,
    };
