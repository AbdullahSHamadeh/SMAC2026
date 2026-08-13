import 'dart:convert';

import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/http_compass_repository.dart';
import 'package:family_compass/domain/compass_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('HTTP Compass adapter parses a general LM Studio answer', () async {
    late http.Request captured;
    final repository = HttpCompassRepository(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'answer': 'Saturn has many moons.',
            'provider': 'lm-studio',
            'grounded_facts': <Object>[],
            'suggested_actions': <Object>[],
            'has_permitted_information': false,
            'answer_kind': 'general',
          }),
          200,
        );
      }),
    );

    final answer = await repository.ask(
      conversationId: '77777777-7777-7777-7777-777777777777',
      question: 'Tell me about Saturn.',
    );

    expect(answer.text, 'Saturn has many moons.');
    expect(answer.isGeneralKnowledge, isTrue);
    expect(answer.sourceLabel, 'lm-studio · general knowledge');
    expect(captured.headers['Authorization'], 'Bearer signed-test-token');
    expect(captured.headers.containsKey('X-Demo-User'), isFalse);
    expect(jsonDecode(captured.body)['prompt'], 'Tell me about Saturn.');
  });

  test('HTTP Compass adapter gives an honest LM Studio error', () async {
    final repository = HttpCompassRepository(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient((_) async => http.Response(
            '{"detail":"provider unavailable"}',
            503,
          )),
    );

    await expectLater(
      repository.ask(
        conversationId: '77777777-7777-7777-7777-777777777777',
        question: 'Hello',
      ),
      throwsA(
        isA<CompassConnectionException>().having(
          (error) => error.message,
          'message',
          contains('LM Studio'),
        ),
      ),
    );
  });

  test('CompassRepository contract supports general answers', () async {
    final CompassRepository repository = _GeneralAnswerRepository();

    final answer = await repository.ask(
      conversationId: '77777777-7777-7777-7777-777777777777',
      question: 'What is photosynthesis?',
    );

    expect(answer.isGeneralKnowledge, isTrue);
  });

  test('HTTP Compass adapter rejects a malformed successful answer', () async {
    final repository = HttpCompassRepository(
      apiBaseUrl: 'http://127.0.0.1:8000',
      familyId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient((_) async => http.Response(
            jsonEncode(<String, Object?>{
              'answer': <String, Object>{'unexpected': 'object'},
              'provider': 'lm-studio',
              'grounded_facts': <Object>[],
              'suggested_actions': <Object>[],
              'has_permitted_information': false,
              'answer_kind': 'general',
            }),
            200,
          )),
    );

    await expectLater(
      repository.ask(
        conversationId: '77777777-7777-7777-7777-777777777777',
        question: 'Hello',
      ),
      throwsA(
        isA<CompassConnectionException>().having(
          (error) => error.message,
          'message',
          contains('unreadable'),
        ),
      ),
    );
  });
}

class _GeneralAnswerRepository implements CompassRepository {
  @override
  Future<CompassAnswer> ask({
    required String conversationId,
    required String question,
    CompassVisibility visibility = CompassVisibility.private,
  }) async {
    return const CompassAnswer(
      text: 'Plants convert light into chemical energy.',
      sourceLabel: 'lm-studio · general knowledge',
      freshnessLabel: '',
      hasPermittedInformation: false,
      isGeneralKnowledge: true,
    );
  }
}
