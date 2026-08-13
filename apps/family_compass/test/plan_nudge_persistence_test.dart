import 'dart:convert';

import 'package:family_compass/data/api_mappers.dart';
import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/http_family_compass_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _planId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _nudgedAt = '2026-08-13T10:00:00Z';
const _deliveredAt = '2026-08-13T10:00:01Z';

void main() {
  test('plan mapper distinguishes attempted and delivered nudges', () {
    final failedAttempt = planFromApi(
      _planJson(nudgedAt: _nudgedAt),
    );
    final delivered = planFromApi(
      _planJson(nudgedAt: _nudgedAt, deliveredAt: _deliveredAt),
    );

    expect(failedAttempt.nudgedAt, DateTime.parse(_nudgedAt));
    expect(failedAttempt.nudgeDeliveredAt, isNull);
    expect(failedAttempt.nudgeSent, isFalse);
    expect(failedAttempt.nudgeDeliveryFailed, isTrue);
    expect(delivered.nudgeDeliveredAt, DateTime.parse(_deliveredAt));
    expect(delivered.nudgeSent, isTrue);
    expect(delivered.nudgeDeliveryFailed, isFalse);
  });

  test('delivered nudge stays disabled after repository recreation', () async {
    var planListReads = 0;
    final api = _api((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/plans')) {
        planListReads += 1;
        return _json(<Object?>[
          _planJson(nudgedAt: _nudgedAt, deliveredAt: _deliveredAt),
        ]);
      }
      return _json(<String, Object>{'detail': 'Not found'}, statusCode: 404);
    });
    addTearDown(api.close);

    final firstRepository =
        HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    final firstLoad = await firstRepository.watchPlans(_familyId).first;
    await firstRepository.close();

    final relaunchedRepository =
        HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    addTearDown(relaunchedRepository.close);
    final reloaded = await relaunchedRepository.watchPlans(_familyId).first;

    expect(firstLoad.single.nudgeSent, isTrue);
    expect(reloaded.single.nudgeSent, isTrue);
    expect(reloaded.single.nudgeDeliveredAt, DateTime.parse(_deliveredAt));
    expect(planListReads, 2);
  });

  test('zero-recipient nudge reloads authoritative delivery state', () async {
    var nudgePosts = 0;
    var planReads = 0;
    final api = _api((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/nudge')) {
        nudgePosts += 1;
        return _json(<String, Object>{
          'notified_member_ids': const <String>[],
        });
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/plans/$_planId')) {
        planReads += 1;
        return _json(
          _planJson(nudgedAt: _nudgedAt, deliveredAt: _deliveredAt),
        );
      }
      return _json(<String, Object>{'detail': 'Not found'}, statusCode: 404);
    });
    addTearDown(api.close);
    final repository = HttpPlanRepository(
      api: api,
      defaultFamilyId: _familyId,
    );
    addTearDown(repository.close);

    final plan = await repository.sendNudge(
      familyId: _familyId,
      planId: _planId,
    );

    expect(nudgePosts, 1);
    expect(planReads, 1);
    expect(plan.nudgeSent, isTrue);
    expect(plan.nudgeDeliveredAt, DateTime.parse(_deliveredAt));
  });
}

Map<String, Object?> _planJson({String? nudgedAt, String? deliveredAt}) =>
    <String, Object?>{
      'id': _planId,
      'family_id': _familyId,
      'title': 'Friday dinner',
      'location_label': 'Home',
      'coordinator_id': '11111111-1111-4111-8111-111111111111',
      'participant_ids': const <String>[
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ],
      'candidate_times': const <Object>[
        <String, Object>{
          'id': 'friday-1930',
          'starts_at': '2026-08-14T15:30:00Z',
          'time_zone': 'Asia/Dubai',
        },
      ],
      'phase': 'poll_open',
      'decision_deadline': '2026-08-14T08:00:00Z',
      'responses': const <String, Object>{},
      'confirmed_candidate_id': null,
      'nudged_at': nudgedAt,
      'nudge_delivered_at': deliveredAt,
      'reminders': const <Object>[],
      'contributions': const <Object>[],
      'version': 3,
    };

FamilyCompassApiClient _api(
  Future<http.Response> Function(http.Request request) handler,
) =>
    FamilyCompassApiClient(
      baseUrl: 'http://family-compass.test',
      credentials: const BearerApiSession(token: 'test-token'),
      client: MockClient(handler),
    );

http.Response _json(Object? value, {int statusCode = 200}) => http.Response(
      jsonEncode(value),
      statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );
