import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/http_family_compass_repositories.dart';
import 'package:family_compass/domain/compass_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _artifactId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _messageId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _userId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _sourceId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';

void main() {
  test('family-room Compass keeps traceability and confirmation contracts',
      () async {
    late Map<String, dynamic> requestBody;
    final api = FamilyCompassApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object>{
            'question_message': <String, Object>{
              'id': _messageId,
              'client_id': _artifactId,
              'family_id': _familyId,
              'sender_id': _userId,
              'kind': 'compass_question',
              'body': '@Compass Where is Dad?',
              'created_at': '2026-08-13T09:00:00Z',
            },
            'artifact': _artifactJson,
          }),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    final repository = HttpFamilyRoomCompassRepository(api: api);
    addTearDown(repository.close);

    final artifact = await repository.ask(
      familyId: _familyId,
      prompt: '@Compass Where is Dad?',
      idempotencyKey: _artifactId,
      mentionedMemberIds: const <String>{
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        _userId,
      },
    );

    expect(requestBody, <String, Object>{
      'client_id': _artifactId,
      'prompt': '@Compass Where is Dad?',
      'mentioned_member_ids': <String>[
        _userId,
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
      ],
    });
    expect(artifact.kind, FamilyCompassArtifactKind.suggestion);
    expect(artifact.uncertainty, CompassUncertainty.medium);
    expect(artifact.citations.single.sourceType, CompassFactSource.journey);
    expect(
      artifact.citations.single.audience,
      CompassFactAudience.wholeFamily,
    );
    expect(artifact.actions.single.kind, CompassActionKind.requestCheckIn);
    expect(artifact.actions.single.requiresConfirmation, isTrue);
    expect(
      (await repository.watchArtifacts(_familyId).first).single.id,
      _artifactId,
    );
  });

  test('family-room Compass omits empty mentions for older backends', () async {
    late Map<String, dynamic> requestBody;
    final api = FamilyCompassApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object>{
            'question_message': <String, Object>{
              'id': _messageId,
              'client_id': _artifactId,
              'family_id': _familyId,
              'sender_id': _userId,
              'kind': 'compass_question',
              'body': '@Compass Help us plan dinner',
              'created_at': '2026-08-13T09:00:00Z',
            },
            'artifact': _artifactJson,
          }),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    final repository = HttpFamilyRoomCompassRepository(api: api);
    addTearDown(repository.close);

    await repository.ask(
      familyId: _familyId,
      prompt: '@Compass Help us plan dinner',
      idempotencyKey: _artifactId,
    );

    expect(requestBody, <String, Object>{
      'client_id': _artifactId,
      'prompt': '@Compass Help us plan dinner',
    });
  });
}

const _artifactJson = <String, Object>{
  'id': _artifactId,
  'family_id': _familyId,
  'request_message_id': _messageId,
  'requested_by': _userId,
  'kind': 'suggestion',
  'answer': 'Dad shared that he is on the way home.',
  'provider': 'lm-studio',
  'audience': 'family_room',
  'uncertainty': 'medium',
  'created_at': '2026-08-13T09:00:01Z',
  'grounded_facts': <Object>[
    <String, Object>{
      'text': 'On the way home. ETA 9:30 PM.',
      'source_id': _sourceId,
      'source_type': 'journey',
      'source_label': 'Dad shared journey',
      'audience': 'whole_family',
      'freshness': 'current',
      'updated_at': '2026-08-13T08:55:00Z',
      'expires_at': '2026-08-13T10:00:00Z',
    },
  ],
  'actions': <Object>[
    <String, Object?>{
      'kind': 'request_check_in',
      'label': 'Request a check-in',
      'requires_confirmation': true,
      'target_id': null,
    },
  ],
};
