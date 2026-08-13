import 'dart:async';
import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/family_realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _messageId = '99999999-9999-4999-8999-999999999999';
const _userId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('deep links resolve family and supported resource kinds', () {
    final link = FamilyCompassDeepLink.tryParse(
      'familycompass://families/$_familyId/messages/$_messageId',
    );

    expect(link, isNotNull);
    expect(link!.familyId, _familyId);
    expect(link.kind, FamilyResourceKind.messages);
    expect(link.resourceId, _messageId);
    expect(
      FamilyCompassDeepLink.tryParse('https://example.com/families/x'),
      isNull,
    );
    expect(
      FamilyCompassDeepLink.tryParse('familycompass://families/too-short'),
      isNull,
    );
    final checkIn = FamilyCompassDeepLink.tryParse(
      'familycompass://families/$_familyId/check-ins/$_messageId',
    );
    expect(checkIn?.kind, FamilyResourceKind.checkIns);
  });

  test('realtime client uses the family websocket and parses events', () async {
    late Uri capturedUri;
    late ApiCredentialProvider capturedCredentials;
    final client = FamilyRealtimeClient(
      apiBaseUrl: 'https://api.familycompass.test/',
      familyId: _familyId,
      credentials: const BearerApiSession(token: 'signed-test-token'),
      connector: (uri, credentials) {
        capturedUri = uri;
        capturedCredentials = credentials;
        return Stream<String>.value(
          jsonEncode(<String, Object?>{
            'family_id': _familyId,
            'event_type': 'message.created',
            'actor_id': _userId,
            'resource_id': _messageId,
            'occurred_at': '2026-08-13T10:00:00Z',
            'deep_link':
                'familycompass://families/$_familyId/messages/$_messageId',
            'data': <String, Object?>{'kind': 'text'},
          }),
        );
      },
    );

    final event = await client.watch().first;

    expect(
      capturedUri.toString(),
      'wss://api.familycompass.test/api/v1/families/$_familyId/events',
    );
    expect(
      capturedCredentials.headers['Authorization'],
      'Bearer signed-test-token',
    );
    expect(event.familyId, _familyId);
    expect(event.eventType, 'message.created');
    expect(event.deepLink?.kind, FamilyResourceKind.messages);
    expect(event.data['kind'], 'text');
  });

  test('malformed realtime payloads fail as safe API errors', () async {
    final client = FamilyRealtimeClient(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: _familyId,
      credentials: const BearerApiSession(token: 'signed-test-token'),
      connector: (_, __) => Stream<String>.value('{not-json'),
    );

    await expectLater(
      client.watch().first,
      throwsA(
        isA<FamilyCompassApiException>().having(
          (error) => error.kind,
          'kind',
          FamilyCompassApiErrorKind.malformedResponse,
        ),
      ),
    );
  });

  test('realtime client reconnects after transport failure', () async {
    var connectionCount = 0;
    final client = FamilyRealtimeClient(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: _familyId,
      credentials: const BearerApiSession(token: 'signed-test-token'),
      reconnectDelays: const <Duration>[Duration.zero],
      connector: (_, __) {
        connectionCount += 1;
        if (connectionCount == 1) {
          return Stream<String>.error(StateError('socket closed'));
        }
        return Stream<String>.value(
          jsonEncode(<String, Object?>{
            'family_id': _familyId,
            'event_type': 'plan.updated',
            'actor_id': _userId,
            'resource_id': _messageId,
            'occurred_at': '2026-08-13T10:00:00Z',
            'data': <String, Object?>{},
          }),
        );
      },
    );

    final event =
        await client.watch().first.timeout(const Duration(seconds: 1));

    expect(connectionCount, 2);
    expect(event.eventType, 'plan.updated');
  });

  test('forbidden realtime transport ends without reconnecting', () async {
    var connectionCount = 0;
    Object? receivedError;
    final done = Completer<void>();
    final client = FamilyRealtimeClient(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: _familyId,
      credentials: const BearerApiSession(token: 'signed-test-token'),
      reconnectDelays: const <Duration>[Duration.zero],
      connector: (_, __) {
        connectionCount += 1;
        return Stream<String>.error(
          const FamilyCompassApiException(
            kind: FamilyCompassApiErrorKind.forbidden,
            message: 'Family membership revoked.',
            statusCode: 403,
          ),
        );
      },
    );

    final subscription = client.watch().listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        receivedError = error;
      },
      onDone: done.complete,
    );
    addTearDown(subscription.cancel);

    await done.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      receivedError,
      isA<FamilyCompassApiException>().having(
        (error) => error.kind,
        'kind',
        FamilyCompassApiErrorKind.forbidden,
      ),
    );
    expect(connectionCount, 1);
  });
}
