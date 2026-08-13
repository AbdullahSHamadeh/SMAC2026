enum FamilyRole { coordinator, member }

enum FamilyRelationshipKind {
  self,
  familyMember,
  father,
  mother,
  sister,
  custom,
}

enum SharingAudience { wholeFamily, selectedPeople, onlyMe }

enum SharingState { notSharing, active, paused, revoked }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    this.relationship = '',
    this.relationshipKind = FamilyRelationshipKind.custom,
    required this.initials,
    this.role = FamilyRole.member,
    this.canInvite = false,
  });

  final String id;
  final String name;

  /// Free-form relationship copy supplied by a person or trusted fixture.
  /// Machine-authored relationship categories belong in [relationshipKind].
  final String relationship;
  final FamilyRelationshipKind relationshipKind;
  final String initials;
  final FamilyRole role;
  final bool canInvite;
}

/// A short-lived journey summary, when a separately consented backend feature
/// is available. Family Compass never exposes route geometry or coordinates.
class FamilyJourney {
  const FamilyJourney({
    required this.id,
    required this.memberId,
    required this.summary,
    required this.updatedAt,
    required this.expiresAt,
    this.eta,
  });

  final String id;
  final String memberId;
  final String summary;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? eta;
}

class SharedStatus {
  SharedStatus({
    required this.id,
    required this.memberId,
    required this.text,
    required this.updatedAt,
    required this.expiresAt,
    required this.audience,
    required Set<String> recipientIds,
    required this.state,
  }) : recipientIds = _validatedRecipientIds(audience, recipientIds);

  final String id;
  final String memberId;
  final String text;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final SharingAudience audience;
  final Set<String> recipientIds;
  final SharingState state;

  static Set<String> _validatedRecipientIds(
    SharingAudience audience,
    Set<String> recipientIds,
  ) {
    final immutableIds = Set<String>.unmodifiable(recipientIds);
    if (immutableIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Recipient IDs cannot be blank.',
      );
    }
    if (audience == SharingAudience.selectedPeople && immutableIds.isEmpty) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Selected people requires at least one recipient.',
      );
    }
    if (audience != SharingAudience.selectedPeople && immutableIds.isNotEmpty) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Recipient IDs are only valid for selected people.',
      );
    }
    return immutableIds;
  }

  bool isUsableAt(DateTime now) =>
      state == SharingState.active && expiresAt.isAfter(now);

  SharedStatus copyWith({
    String? text,
    DateTime? updatedAt,
    DateTime? expiresAt,
    SharingAudience? audience,
    Set<String>? recipientIds,
    SharingState? state,
  }) =>
      SharedStatus(
        id: id,
        memberId: memberId,
        text: text ?? this.text,
        updatedAt: updatedAt ?? this.updatedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        audience: audience ?? this.audience,
        recipientIds: recipientIds ?? this.recipientIds,
        state: state ?? this.state,
      );
}
