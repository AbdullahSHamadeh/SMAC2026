enum FamilyRole { coordinator, member }

enum SharingAudience { wholeFamily, selectedPeople }

enum SharingState { notSharing, active, paused }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.initials,
    this.role = FamilyRole.member,
  });

  final String id;
  final String name;
  final String relationship;
  final String initials;
  final FamilyRole role;
}

class SharedStatus {
  const SharedStatus({
    required this.id,
    required this.memberId,
    required this.text,
    required this.updatedAt,
    required this.expiresAt,
    required this.audience,
    required this.state,
  });

  final String id;
  final String memberId;
  final String text;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final SharingAudience audience;
  final SharingState state;

  bool isUsableAt(DateTime now) =>
      state == SharingState.active && expiresAt.isAfter(now);

  SharedStatus copyWith({
    String? text,
    DateTime? updatedAt,
    DateTime? expiresAt,
    SharingAudience? audience,
    SharingState? state,
  }) =>
      SharedStatus(
        id: id,
        memberId: memberId,
        text: text ?? this.text,
        updatedAt: updatedAt ?? this.updatedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        audience: audience ?? this.audience,
        state: state ?? this.state,
      );
}
