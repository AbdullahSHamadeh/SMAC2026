import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/data/http_compass_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _familyId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _conversationId = '77777777-7777-7777-7777-777777777777';

void main() {
  group('HTTP Compass failure modes', () {
    test('timeout becomes a recoverable connection error', () async {
      final repository = _repository(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.ask(
          conversationId: _conversationId,
          question: 'Where is Dad?',
        ),
        throwsA(_connectionErrorContaining('too long')),
      );
    });

    test('rate limit keeps the failure honest and retryable', () async {
      final repository = _repository(
        client: MockClient((_) async => http.Response(
              jsonEncode(<String, String>{'detail': 'rate limited'}),
              429,
            )),
      );

      await expectLater(
        repository.ask(
          conversationId: _conversationId,
          question: 'Help plan dinner',
        ),
        throwsA(_connectionErrorContaining('Try again')),
      );
    });

    test('provider policy denial is not described as missing family data',
        () async {
      final repository = _repository(
        client: MockClient((_) async => http.Response(
              jsonEncode(<String, String>{'detail': 'provider denied'}),
              403,
            )),
      );

      await expectLater(
        repository.ask(
          conversationId: _conversationId,
          question: 'Where is Dad?',
        ),
        throwsA(_connectionErrorContaining('not allowed')),
      );
    });

    test('malformed successful output becomes an unreadable-answer error',
        () async {
      final repository = _repository(
        client: MockClient((_) async => http.Response(
              jsonEncode(<Object>['not', 'an', 'object']),
              200,
            )),
      );

      await expectLater(
        repository.ask(
          conversationId: _conversationId,
          question: 'Hello',
        ),
        throwsA(_connectionErrorContaining('unreadable')),
      );
    });

    test('request body contains no client-assembled family context', () async {
      late http.Request captured;
      final repository = _repository(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object>{
              'answer': 'No recent permitted information is available.',
              'provider': 'local',
              'grounded_facts': <Object>[],
              'suggested_actions': <Object>[],
              'has_permitted_information': false,
              'answer_kind': 'abstention',
            }),
            200,
          );
        }),
      );

      await repository.ask(
        conversationId: _conversationId,
        question: 'Where is Dad?',
        visibility: CompassVisibility.familyRoom,
      );

      expect(
        jsonDecode(captured.body),
        <String, Object>{
          'conversation_id': _conversationId,
          'prompt': 'Where is Dad?',
          'visibility': 'family_room',
        },
      );
    });
  });
}

HttpCompassRepository _repository({
  required http.Client client,
  Duration timeout = const Duration(seconds: 1),
}) =>
    HttpCompassRepository(
      apiBaseUrl: 'http://127.0.0.1:8000/',
      familyId: _familyId,
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: client,
      timeout: timeout,
    );

Matcher _connectionErrorContaining(String text) =>
    isA<CompassConnectionException>().having(
      (error) => error.message,
      'message',
      contains(text),
    );
