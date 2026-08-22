import '../data/api_mappers.dart';
import '../data/family_compass_api_client.dart';

class FirebaseFamilyBinding {
  const FirebaseFamilyBinding({
    required this.userId,
    required this.familyId,
  });

  final String userId;
  final String familyId;
}

class FirebaseIncomingInvitation {
  const FirebaseIncomingInvitation({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.maskedPhoneNumber,
    required this.role,
    required this.expiresAt,
    this.inviterName,
  });

  final String id;
  final String familyId;
  final String familyName;
  final String? inviterName;
  final String maskedPhoneNumber;
  final String role;
  final DateTime expiresAt;

  static FirebaseIncomingInvitation fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id', label: 'Invitation');
    final familyId = _requiredString(json, 'family_id', label: 'Invitation');
    final familyName = _requiredString(
      json,
      'family_name',
      label: 'Invitation',
    );
    final role = _requiredString(json, 'role', label: 'Invitation');
    final expiresAtValue = _requiredString(
      json,
      'expires_at',
      label: 'Invitation',
    );
    final expiresAt = DateTime.tryParse(expiresAtValue);
    if (expiresAt == null) {
      throw const FormatException('Invitation expiry is invalid.');
    }
    final inviterNameValue = json['inviter_name'];
    final inviterName =
        inviterNameValue is String && inviterNameValue.trim().isNotEmpty
            ? inviterNameValue.trim()
            : null;
    return FirebaseIncomingInvitation(
      id: id,
      familyId: familyId,
      familyName: familyName,
      inviterName: inviterName,
      maskedPhoneNumber: _privacySafePhoneMask(
        _requiredString(
          json,
          'masked_phone_number',
          label: 'Invitation',
        ),
      ),
      role: role,
      expiresAt: expiresAt,
    );
  }
}

class FirebaseFamilyBootstrapFailure implements Exception {
  const FirebaseFamilyBootstrapFailure({
    required this.english,
    required this.arabic,
  });

  final String english;
  final String arabic;

  String localized({required bool isArabic}) => isArabic ? arabic : english;

  @override
  String toString() => english;
}

/// Resolves the authenticated backend identity and one explicitly authorized
/// family before any family-scoped repositories are constructed.
class FirebaseFamilyBootstrapService {
  const FirebaseFamilyBootstrapService({required this.api});

  final FamilyCompassApiClient api;

  Future<FirebaseFamilyBinding?> restoreExistingBinding() async {
    final me = asJsonObject(
      await api.get('/api/v1/me'),
      label: 'Current user',
    );
    final families = await _families();
    if (families.isEmpty) return null;
    return FirebaseFamilyBinding(
      userId: me['id'] as String,
      familyId: families.first['id'] as String,
    );
  }

  Future<FirebaseFamilyBinding?> restoreBindingForFamily(
      String familyId) async {
    final me = asJsonObject(
      await api.get('/api/v1/me'),
      label: 'Current user',
    );
    final families = await _families();
    if (!families.any((family) => family['id'] == familyId)) return null;
    return FirebaseFamilyBinding(
      userId: me['id'] as String,
      familyId: familyId,
    );
  }

  Future<FirebaseFamilyBinding> bootstrap({
    required String displayName,
    required bool createFamily,
    String? outgoingInvitationPhone,
    String? incomingInvitationId,
  }) async {
    final me = asJsonObject(
      await api.get('/api/v1/me'),
      label: 'Current user',
    );
    final userId = me['id'] as String;
    String familyId;

    if (!createFamily) {
      final invitationId = incomingInvitationId?.trim();
      if (invitationId == null || invitationId.isEmpty) {
        throw const FirebaseFamilyBootstrapFailure(
          english: 'Choose an invitation and tap Accept to join a family.',
          arabic: 'اختر دعوة واضغط على قبول للانضمام إلى عائلة.',
        );
      }
      final accepted = asJsonObject(
        await api.post(
          '/api/v1/invitations/${Uri.encodeComponent(invitationId)}/accept',
        ),
        label: 'Accepted invitation',
      );
      familyId = _requiredString(
        accepted,
        'family_id',
        label: 'Accepted invitation',
      );
    } else {
      final families = await _families();
      if (families.isNotEmpty) {
        familyId = families.first['id'] as String;
      } else {
        final family = asJsonObject(
          await api.post(
            '/api/v1/families',
            body: <String, Object?>{
              'name': "${displayName.trim()}'s family",
            },
          ),
          label: 'Family',
        );
        familyId = family['id'] as String;
      }
    }

    final outgoingPhone = outgoingInvitationPhone?.trim();
    if (createFamily && outgoingPhone != null && outgoingPhone.isNotEmpty) {
      try {
        await api.post(
          '/api/v1/families/$familyId/invitations',
          body: <String, Object?>{
            'phone_number': outgoingPhone,
            'role': 'adult',
          },
        );
      } on Object catch (error) {
        throw FirebaseFamilyBootstrapFailure(
          english:
              'Your family was created, but the invitation could not be sent. Check the number or connection and try again. ($error)',
          arabic:
              'تم إنشاء العائلة، لكن تعذر إرسال الدعوة. تحقق من الرقم أو الاتصال وحاول مرة أخرى. ($error)',
        );
      }
    }

    return FirebaseFamilyBinding(userId: userId, familyId: familyId);
  }

  Future<List<FirebaseIncomingInvitation>> loadIncomingInvitations() async {
    final invitations = asJsonObjectList(
      await api.get('/api/v1/invitations'),
      label: 'Incoming invitations',
    );
    return invitations.map(FirebaseIncomingInvitation.fromJson).toList();
  }

  Future<void> declineIncomingInvitation(String invitationId) async {
    final normalizedId = invitationId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(invitationId, 'invitationId');
    }
    await api.post(
      '/api/v1/invitations/${Uri.encodeComponent(normalizedId)}/decline',
    );
  }

  Future<List<Map<String, dynamic>>> _families() =>
      api.get('/api/v1/families').then(
            (value) => asJsonObjectList(value, label: 'Families'),
          );
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String label,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$label is missing $key.');
  }
  return value.trim();
}

String _privacySafePhoneMask(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final suffix =
      digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  return suffix.isEmpty ? '••••' : '•••• $suffix';
}
