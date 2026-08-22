import 'package:family_compass/data/family_realtime_client.dart';
import 'package:family_compass/firebase/firebase_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _resourceId = '99999999-9999-4999-8999-999999999999';

void main() {
  test('notification payloads preserve exact supported family links', () {
    for (final entry in <String, FamilyResourceKind>{
      'messages': FamilyResourceKind.messages,
      'plans': FamilyResourceKind.plans,
      'reminders': FamilyResourceKind.reminders,
      'check-ins': FamilyResourceKind.checkIns,
    }.entries) {
      final sentAt = DateTime.utc(2026, 8, 13, 10, 30);
      final envelope = NotificationEnvelope.tryParse(
        RemoteMessage(
          messageId: 'notification-${entry.key}',
          sentTime: sentAt,
          data: <String, dynamic>{
            'event_type': '${entry.key}.updated',
            'family_id': _familyId,
            'resource_id': _resourceId,
            'deep_link':
                'familycompass://families/$_familyId/${entry.key}/$_resourceId',
          },
        ),
      );

      expect(envelope, isNotNull, reason: entry.key);
      expect(envelope!.deepLink.familyId, _familyId);
      expect(envelope.deepLink.kind, entry.value);
      expect(envelope.deepLink.resourceId, _resourceId);
      expect(envelope.messageId, 'notification-${entry.key}');
      expect(envelope.receivedAt, sentAt);
    }
  });

  test('notification payload rejects missing, unknown, or mismatched scope',
      () {
    RemoteMessage message(Map<String, dynamic> data) =>
        RemoteMessage(data: data);

    final valid = <String, dynamic>{
      'event_type': 'message.created',
      'family_id': _familyId,
      'resource_id': _resourceId,
      'deep_link': 'familycompass://families/$_familyId/messages/$_resourceId',
    };

    expect(
      NotificationEnvelope.tryParse(
        message(<String, dynamic>{...valid}..remove('event_type')),
      ),
      isNull,
    );
    expect(
      NotificationEnvelope.tryParse(
        message(<String, dynamic>{
          ...valid,
          'deep_link':
              'familycompass://families/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/messages/$_resourceId',
        }),
      ),
      isNull,
    );
    expect(
      NotificationEnvelope.tryParse(
        message(<String, dynamic>{
          ...valid,
          'resource_id': '88888888-8888-4888-8888-888888888888',
        }),
      ),
      isNull,
    );
    expect(
      NotificationEnvelope.tryParse(
        message(<String, dynamic>{
          ...valid,
          'deep_link':
              'familycompass://families/$_familyId/unknown/$_resourceId',
        }),
      ),
      isNull,
    );
    expect(
      NotificationEnvelope.tryParse(
        message(<String, dynamic>{
          ...valid,
          'deep_link': 'https://example.com/families/$_familyId',
        }),
      ),
      isNull,
    );
  });
}
