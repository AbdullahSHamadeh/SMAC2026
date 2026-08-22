import 'package:flutter/foundation.dart';

import '../../data/family_compass_repositories.dart';

typedef InvitationClock = DateTime Function();

@immutable
class FamilyInvitationRecord {
  const FamilyInvitationRecord({
    this.id,
    required this.phoneNumber,
    required this.createdAt,
    required this.expiresAt,
  });

  final String? id;
  final String phoneNumber;
  final DateTime createdAt;
  final DateTime expiresAt;

  String get maskedPhoneNumber => maskPhoneNumber(phoneNumber);
}

class FamilyInvitationController extends ChangeNotifier {
  FamilyInvitationController({
    FamilyInvitationRecord? initialInvitation,
    InvitationClock? clock,
    FamilyRepository? repository,
    String? familyId,
  })  : _clock = clock ?? DateTime.now,
        _repository = repository,
        _familyId = familyId,
        _pendingInvitation = initialInvitation;

  factory FamilyInvitationController.withDemoInvitation({
    InvitationClock? clock,
  }) {
    final resolvedClock = clock ?? DateTime.now;
    final now = resolvedClock();
    return FamilyInvitationController(
      clock: resolvedClock,
      initialInvitation: FamilyInvitationRecord(
        phoneNumber: '+971509876543',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 3)),
      ),
    );
  }

  final InvitationClock _clock;
  final FamilyRepository? _repository;
  final String? _familyId;
  FamilyInvitationRecord? _pendingInvitation;

  FamilyInvitationRecord? get pendingInvitation => _pendingInvitation;

  bool get usesBackend => _repository != null && _familyId != null;

  FamilyInvitationRecord prepareInvitation(String input) {
    final phoneNumber = normalizePhoneNumber(input);
    if (phoneNumber == null) {
      throw const FormatException(
        'Enter a valid international phone number with 8 to 15 digits.',
      );
    }

    final now = _clock();
    final invitation = FamilyInvitationRecord(
      phoneNumber: phoneNumber,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 3)),
    );
    _pendingInvitation = invitation;
    notifyListeners();
    return invitation;
  }

  Future<FamilyInvitationRecord> sendInvitation(String input) async {
    final phoneNumber = normalizePhoneNumber(input);
    if (phoneNumber == null) {
      throw const FormatException(
        'Enter a valid international phone number with 8 to 15 digits.',
      );
    }
    final repository = _repository;
    final familyId = _familyId;
    if (repository == null || familyId == null) {
      return prepareInvitation(phoneNumber);
    }

    final now = _clock();
    final backendInvitation = await repository.inviteByPhone(
      familyId: familyId,
      internationalPhoneNumber: phoneNumber,
      idempotencyKey: 'invite-${now.microsecondsSinceEpoch}',
    );
    final invitation = FamilyInvitationRecord(
      id: backendInvitation.id,
      phoneNumber: phoneNumber,
      createdAt: now,
      expiresAt: backendInvitation.expiresAt,
    );
    _pendingInvitation = invitation;
    notifyListeners();
    return invitation;
  }

  Future<void> cancelPendingInvitation() async {
    final invitation = _pendingInvitation;
    if (invitation == null) return;
    final repository = _repository;
    final invitationId = invitation.id;
    if (repository != null && invitationId != null) {
      await repository.revokeInvitation(invitationId);
    }
    _pendingInvitation = null;
    notifyListeners();
  }
}

String? normalizePhoneNumber(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith('+') ||
      !RegExp(r'^\+[0-9\s().-]+$').hasMatch(trimmed)) {
    return null;
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) return null;
  return '+$digits';
}

String maskPhoneNumber(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return '••••';

  final suffix = digits.substring(digits.length - 3);
  if (digits.startsWith('971') && digits.length >= 8) {
    final network = digits.substring(3, 5);
    return '+971 $network ••• •$suffix';
  }

  final prefixLength = digits.length > 9 ? 3 : 2;
  final prefix = digits.substring(0, prefixLength);
  return '+$prefix ••• •$suffix';
}
