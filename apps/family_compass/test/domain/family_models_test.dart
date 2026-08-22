import 'package:family_compass/domain/family_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedStatus audience recipients', () {
    test('keeps selected recipients as an immutable set', () {
      final originalRecipientIds = <String>{'dad', 'mom'};
      final status = _status(
        audience: SharingAudience.selectedPeople,
        recipientIds: originalRecipientIds,
      );

      originalRecipientIds.add('sara');

      expect(status.recipientIds, {'dad', 'mom'});
      expect(
        () => status.recipientIds.add('sara'),
        throwsUnsupportedError,
      );
    });

    test('rejects selected people without a recipient', () {
      expect(
        () => _status(
          audience: SharingAudience.selectedPeople,
          recipientIds: const {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects recipients for the whole family', () {
      expect(
        () => _status(
          audience: SharingAudience.wholeFamily,
          recipientIds: const {'dad'},
        ),
        throwsArgumentError,
      );
    });

    test('only me has no recipients', () {
      final status = _status(
        audience: SharingAudience.onlyMe,
        recipientIds: const {},
      );

      expect(status.recipientIds, isEmpty);
      expect(
        () => status.copyWith(recipientIds: const {'mom'}),
        throwsArgumentError,
      );
    });
  });
}

SharedStatus _status({
  required SharingAudience audience,
  required Set<String> recipientIds,
}) {
  final now = DateTime(2026, 8, 7, 12);
  return SharedStatus(
    id: 'status',
    memberId: 'abdullah',
    text: 'At university',
    updatedAt: now,
    expiresAt: now.add(const Duration(hours: 1)),
    audience: audience,
    recipientIds: recipientIds,
    state: SharingState.active,
  );
}
