import 'dart:convert';

import 'package:family_compass/data/api_mappers.dart';
import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/data/http_family_compass_repositories.dart';
import 'package:family_compass/data/offline_write_queue.dart';
import 'package:family_compass/domain/chat_models.dart';
import 'package:family_compass/domain/family_models.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _dadId = '22222222-2222-4222-8222-222222222222';
const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _planId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  test('Chat mapping accepts legacy messages and preserves structured mentions',
      () {
    final legacy = chatItemFromApi(
      _messageJson(clientId: _userId, body: 'Legacy message'),
    );
    final mentionIds = <String>{_dadId};
    final structured = chatItemFromApi(
      _messageJson(
        clientId: _userId,
        body: '@Dad Dinner is ready',
        mentionedMemberIds: mentionIds.toList(),
      ),
    );
    mentionIds.clear();

    expect(legacy.mentionedMemberIds, isEmpty);
    expect(structured.mentionedMemberIds, <String>{_dadId});
    expect(
      () => structured.mentionedMemberIds.add(_userId),
      throwsUnsupportedError,
    );
  });

  test('development session verifies identity and sends bearer auth only',
      () async {
    late http.Request captured;
    final api = _api((request) async {
      captured = request;
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{'id': _userId, 'name': 'Abdullah'});
      }
      return _json(<Object>[
        <String, Object>{
          'id': _familyId,
          'name': 'Hamadeh Family',
          'organizer_id': _userId,
          'member_ids': <String>[_userId, _dadId],
        },
      ]);
    });
    final repository = HttpDevelopmentSessionRepository(api: api);
    addTearDown(repository.close);

    final session = await repository.startDevelopmentSession();

    expect(session.userId, _userId);
    expect(session.familyIds, <String>[_familyId]);
    expect(captured.headers['Authorization'], 'Bearer signed-test-token');
    expect(captured.headers.containsKey('X-Demo-User'), isFalse);
    await expectLater(
      repository.requestPhoneCode('+971501234567'),
      throwsA(isA<BackendCapabilityUnavailableException>()),
    );
  });

  test('family adapter combines family, members, invitations and permissions',
      () async {
    final calls = <String>[];
    final api = _api((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/members') ||
          request.url.path.endsWith('/permissions')) {
        return _json(_memberViews);
      }
      if (request.url.path.endsWith('/invitations') &&
          request.method == 'GET') {
        return _json(<Object>[_invitationJson]);
      }
      if (request.url.path.endsWith('/invitations') &&
          request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phone_number'], '+971501112233');
        return _json(_invitationJson, statusCode: 201);
      }
      if (request.url.path.endsWith('/revoke') && request.method == 'POST') {
        return _json(<String, Object>{
          ..._invitationJson,
          'state': 'revoked',
        });
      }
      if (request.url.path.contains('/permissions/') &&
          request.method == 'PATCH') {
        return _json(_memberViews.last);
      }
      if (request.url.path.endsWith('/me/ai-consent')) {
        return _json(<String, Object>{
          'id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'family_id': _familyId,
          'user_id': _userId,
          'role': 'organizer',
          'can_invite': true,
          'allow_external_ai_processing': true,
        });
      }
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      return _json(_familyJson);
    });
    final families = HttpFamilyRepository(api: api, currentUserId: _userId);
    final permissions = HttpPermissionRepository(
      api: api,
      currentUserId: _userId,
    );
    addTearDown(families.close);
    addTearDown(permissions.close);

    final family = await families.watchFamily(_familyId).first;
    final invitations = await families.watchInvitations(_familyId).first;
    final created = await families.inviteByPhone(
      familyId: _familyId,
      internationalPhoneNumber: '+971501112233',
      idempotencyKey: 'invite-one',
    );
    final permission = await permissions.setInvitePermission(
      familyId: _familyId,
      memberId: _dadId,
      canInvite: true,
    );
    await permissions.setExternalAIConsent(
      familyId: _familyId,
      allowed: true,
    );

    expect(family.name, 'Hamadeh Family');
    expect(
      family.members.first.relationshipKind,
      FamilyRelationshipKind.self,
    );
    expect(
      family.members.last.relationshipKind,
      FamilyRelationshipKind.familyMember,
    );
    expect(family.members.last.name, 'Dad');
    expect(invitations.single.maskedPhoneNumber, '+971 50 ••• •233');
    expect(created.state, FamilyInvitationState.pending);
    expect(permission.member.id, _dadId);
    expect(permission.canInvite, isTrue);
    expect(calls, contains('GET /api/v1/families/$_familyId/members'));
    await families.revokeInvitation(created.id);
    expect(
      calls,
      contains(
        'POST /api/v1/families/$_familyId/invitations/${created.id}/revoke',
      ),
    );
    await families.removeMember(familyId: _familyId, memberId: _dadId);
    await families.deleteFamily(_familyId);
    await families.leaveFamily(_familyId);
    expect(
      calls,
      contains('DELETE /api/v1/families/$_familyId/members/$_dadId'),
    );
    expect(
      calls,
      contains('DELETE /api/v1/families/$_familyId'),
    );
    expect(
      calls,
      contains('DELETE /api/v1/families/$_familyId/members/me'),
    );
  });

  test('plan creation sends a replay-safe client identifier', () async {
    late Map<String, dynamic> body;
    final api = _api((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, Object?>{
        ..._planJson,
        'id': body['client_id'] as String,
      }, statusCode: 201);
    });
    final plans = HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    addTearDown(plans.close);

    final created = await plans.createPlan(
      familyId: _familyId,
      title: 'Family dinner',
      participantIds: const <String>[_userId, _dadId],
      candidateTimes: <CandidateTime>[
        CandidateTime(
          id: 'tomorrow',
          startsAt: DateTime.parse('2026-08-14T15:30:00Z'),
        ),
      ],
      decisionDeadline: DateTime.parse('2026-08-14T08:00:00Z'),
    );

    expect(body['client_id'], isA<String>());
    expect(body['publish'], isFalse);
    expect(created.id, body['client_id']);
  });

  test('plan draft publish, time suggestion, and reminder update map safely',
      () async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/publish')) {
        return _json(<String, Object?>{
          ..._planJson,
          'phase': 'poll_open',
          'version': 4,
        });
      }
      if (request.url.path.endsWith('/candidate-times')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(<String, Object?>{
          ..._planJson,
          'candidate_times': <Object?>[
            ...(_planJson['candidate_times']! as List<Object?>),
            body['candidate_time'],
          ],
          'version': 5,
        });
      }
      if (request.method == 'PATCH' &&
          request.url.path.contains('/reminders/')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(<String, Object?>{
          'id': '12121212-1212-4212-8212-121212121212',
          'label': 'Dinner starts in one hour',
          'at': body['at'],
          'automatic': true,
        });
      }
      return _json(<Object>[]);
    });
    final plans = HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    final reminders = HttpReminderRepository(api: api, plans: plans);
    addTearDown(plans.close);
    addTearDown(reminders.close);

    final published = await plans.publishPlan(
      familyId: _familyId,
      planId: _planId,
      candidateIds: const <String>{'friday-1930', 'friday-2000'},
      expectedVersion: 3,
    );
    final suggested = await plans.suggestCandidateTime(
      familyId: _familyId,
      planId: _planId,
      candidate: CandidateTime(
        id: 'friday-2000',
        startsAt: DateTime.parse('2026-08-14T16:00:00Z'),
      ),
      expectedVersion: published.version,
    );
    final adjusted = await reminders.updateReminder(
      familyId: _familyId,
      reminderId: '12121212-1212-4212-8212-121212121212',
      at: DateTime.parse('2026-08-14T14:00:00Z'),
    );

    final publishBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
    final suggestionBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(
        publishBody['candidate_ids'], <String>['friday-1930', 'friday-2000']);
    expect(publishBody['expected_version'], 3);
    expect(suggestionBody['expected_version'], 4);
    expect(suggested.candidateTimes.last.id, 'friday-2000');
    expect(adjusted.at, DateTime.parse('2026-08-14T14:00:00Z'));
  });

  test(
      'chat queues only the idempotent message and retries with same client id',
      () async {
    var online = false;
    final postedClientIds = <String>[];
    final api = _api((request) async {
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        postedClientIds.add(body['client_id'] as String);
        if (!online) throw http.ClientException('offline');
        return _json(
          _messageJson(
            clientId: body['client_id'] as String,
            body: body['body'] as String,
            mentionedMemberIds: (body['mentioned_member_ids'] as List<Object?>?)
                ?.cast<String>(),
          ),
          statusCode: 201,
        );
      }
      return _json(<Object>[]);
    });
    final queue = OfflineWriteQueue(
      api: api,
      ownerUserId: _userId,
      familyId: _familyId,
      store: MemoryOfflineWriteStore(),
    );
    final chat = HttpChatRepository(
      api: api,
      queue: queue,
      currentUserId: _userId,
    );
    addTearDown(chat.close);

    final pending = await chat.sendText(
      familyId: _familyId,
      text: 'Dinner at 7?',
      idempotencyKey: 'local-action',
      mentionedMemberIds: const <String>{_dadId, _userId},
    );

    expect(pending.deliveryState, ChatDeliveryState.waitingToSend);
    expect(pending.mentionedMemberIds, <String>{_dadId, _userId});
    expect(await queue.pendingCount, 1);
    expect(
      (await queue.pending).single.body['mentioned_member_ids'],
      <String>[_userId, _dadId],
    );

    online = true;
    await chat.retryPending();

    expect(await queue.pendingCount, 0);
    expect(postedClientIds, hasLength(2));
    expect(postedClientIds[0], postedClientIds[1]);
    expect(
      (await chat.watchMessages(familyId: _familyId).first)
          .single
          .mentionedMemberIds,
      <String>{_dadId, _userId},
    );
  });

  test('plans, statuses, Today, check-ins and reminders map backend schemas',
      () async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/plans') && request.method == 'GET') {
        return _json(<Object>[_planJson]);
      }
      if (path.endsWith('/responses') || path.endsWith('/confirm')) {
        return _json(_planJson);
      }
      if (path.endsWith('/shared-updates') && request.method == 'GET') {
        return _json(<Object>[_statusJson]);
      }
      if (path.endsWith('/shared-updates') && request.method == 'POST') {
        return _json(_statusJson, statusCode: 201);
      }
      if (path.contains('/shared-updates/') && request.method == 'PATCH') {
        return _json(<String, Object?>{
          ..._statusJson,
          'state': 'paused',
        });
      }
      if (path.endsWith('/today')) {
        return _json(<String, Object?>{
          'next_plan': _planJson,
          'needs_reply': <Object>[_planJson],
          'shared_updates': <Object>[_statusJson],
          'suggestion': <String, Object>{
            'id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            'family_id': _familyId,
            'title': 'Reply to dinner',
            'reason': 'A choice is waiting.',
            'action_label': 'Reply',
          },
        });
      }
      if (path.endsWith('/check-ins')) {
        return _json(
          <String, Object>{
            'id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
            'family_id': _familyId,
            'requester_id': _userId,
            'subject_user_id': _dadId,
            'state': 'requested',
            'created_at': '2026-08-13T10:00:00Z',
          },
          statusCode: 201,
        );
      }
      return _json(<String, Object>{'detail': 'Not found'}, statusCode: 404);
    });
    final plans = HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    final sharing = HttpSharingRepository(api: api, defaultFamilyId: _familyId);
    final today = HttpTodayRepository(api: api);
    final checkIns = HttpCheckInRepository(api: api);
    final reminders = HttpReminderRepository(api: api, plans: plans);
    addTearDown(plans.close);
    addTearDown(sharing.close);
    addTearDown(today.close);
    addTearDown(checkIns.close);
    addTearDown(reminders.close);

    final loadedPlans = await plans.watchPlans(_familyId).first;
    final statuses = await sharing.watchPermittedStatuses(_familyId).first;
    final overview = await today.watchToday(_familyId).first;
    final reminderList = await reminders.watchReminders(_familyId).first;
    final response = await plans.saveResponse(
      planId: _planId,
      candidateId: 'friday-1930',
      choice: RsvpChoice.going,
      expectedVersion: 3,
    );
    final createdStatus = await sharing.shareManualStatus(
      familyId: _familyId,
      text: 'Leaving work',
      audience: SharingAudience.selectedPeople,
      recipientIds: <String>{_userId},
      expiresAt: DateTime.parse('2026-08-13T11:00:00Z'),
    );
    await sharing.pauseStatus(createdStatus.id);
    final checkIn = await checkIns.request(
      familyId: _familyId,
      memberId: _dadId,
    );

    expect(loadedPlans.single.version, 3);
    expect(loadedPlans.single.candidateTimes.single.timeZone, 'Asia/Dubai');
    expect(reminderList.single.label, 'Dinner starts in one hour');
    expect(statuses.single.audience, SharingAudience.selectedPeople);
    expect(statuses.single.recipientIds, <String>{_userId});
    expect(overview.suggestion?.actionLabel, 'Reply');
    expect(response.id, _planId);
    expect(checkIn.memberId, _dadId);
    expect(
      jsonDecode(
        requests
            .firstWhere((request) => request.url.path.endsWith('/responses'))
            .body,
      )['expected_version'],
      3,
    );
  });

  test('status, journey, device and final plan actions match backend contracts',
      () async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/statuses') && request.method == 'GET') {
        return _json(<Object>[_memberStatusJson]);
      }
      if (path.endsWith('/statuses/me') && request.method == 'PUT') {
        return _json(_memberStatusJson);
      }
      if (path.contains('/statuses/') && request.method == 'PATCH') {
        return _json(<String, Object?>{
          ..._memberStatusJson,
          'state': 'paused',
        });
      }
      if (path.endsWith('/journeys') && request.method == 'GET') {
        return _json(<Object>[_journeyJson]);
      }
      if (path.endsWith('/journeys') && request.method == 'POST') {
        return _json(_journeyJson, statusCode: 201);
      }
      if (path.contains('/journeys/') && request.method == 'PATCH') {
        return _json(<String, Object?>{
          ..._journeyJson,
          'state': 'completed',
        });
      }
      if (path == '/api/v1/me/device-tokens' && request.method == 'GET') {
        return _json(<Object>[_deviceJson]);
      }
      if (path == '/api/v1/me/device-tokens' && request.method == 'POST') {
        return _json(_deviceJson, statusCode: 201);
      }
      if (path.startsWith('/api/v1/me/device-tokens/') &&
          request.method == 'DELETE') {
        return http.Response('', 204);
      }
      if (path.endsWith('/nudge') && request.method == 'POST') {
        return _json(<String, Object>{
          'notified_member_ids': <String>[_dadId]
        });
      }
      if (path.endsWith('/plans/$_planId') && request.method == 'GET') {
        return _json(<String, Object?>{
          ..._planJson,
          'nudged_at': '2026-08-13T10:00:00Z',
          'nudge_delivered_at': '2026-08-13T10:00:01Z',
        });
      }
      if (path.endsWith('/complete') && request.method == 'POST') {
        return _json(<String, Object?>{
          ..._planJson,
          'phase': 'completed',
          'version': 4,
        });
      }
      return _json(<String, Object>{'detail': 'Not found'}, statusCode: 404);
    });
    final statuses = HttpMemberStatusRepository(api: api);
    final journeys = HttpJourneyRepository(api: api);
    final devices = HttpDeviceRepository(api: api);
    final plans = HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    addTearDown(statuses.close);
    addTearDown(journeys.close);
    addTearDown(devices.close);
    addTearDown(plans.close);

    final initialStatuses = await statuses.watchStatuses(_familyId).first;
    final ownStatus = await statuses.updateOwnStatus(
      familyId: _familyId,
      summary: 'At the library',
      detail: 'Studying until six',
      audience: SharingAudience.selectedPeople,
      recipientIds: <String>{_dadId},
      expiresAt: DateTime.parse('2026-08-13T14:00:00Z'),
    );
    await statuses.setStatusState(
      familyId: _familyId,
      statusId: ownStatus.id,
      state: SharingState.paused,
    );
    final initialJourneys = await journeys.watchJourneys(_familyId).first;
    final journey = await journeys.createJourney(
      familyId: _familyId,
      summary: 'Heading home',
      status: 'on_time',
      eta: DateTime.parse('2026-08-13T15:30:00Z'),
      audience: SharingAudience.wholeFamily,
      recipientIds: const <String>{},
      expiresAt: DateTime.parse('2026-08-13T16:00:00Z'),
    );
    await journeys.endJourney(
      familyId: _familyId,
      journeyId: journey.id,
    );
    final registered = await devices.register(
      token: 'device-token-long-enough',
      platform: DevicePlatform.ios,
    );
    final listedDevices = await devices.listDevices();
    await devices.unregister(registered.id);
    final nudged = await plans.sendNudge(
      familyId: _familyId,
      planId: _planId,
    );
    final completed = await plans.completePlan(
      familyId: _familyId,
      planId: _planId,
    );

    expect(initialStatuses.single.memberId, _userId);
    expect(ownStatus.summary, 'At the library');
    expect(initialJourneys.single.memberId, _userId);
    expect(journey.summary, 'Heading home');
    expect(registered.platform, DevicePlatform.ios);
    expect(listedDevices.single.enabled, isTrue);
    expect(nudged.nudgeSent, isTrue);
    expect(completed.phase, PlanPhase.completed);
    expect(
      jsonDecode(
        requests
            .firstWhere((request) => request.url.path.endsWith('/statuses/me'))
            .body,
      )['summary'],
      'At the library',
    );
    expect(
      jsonDecode(
        requests
            .firstWhere((request) => request.url.path.endsWith('/statuses/me'))
            .body,
      )['audience'],
      'selected_people',
    );
    expect(
      jsonDecode(
        requests
            .firstWhere(
              (request) =>
                  request.method == 'POST' &&
                  request.url.path.endsWith('/journeys'),
            )
            .body,
      )['audience'],
      'whole_family',
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path.endsWith('/${registered.id}'),
      ),
      isTrue,
    );
  });

  test('missing journey and reminder write routes report backend gaps',
      () async {
    final api = _api(
      (_) async => _json(
        <String, Object>{'detail': 'Not found'},
        statusCode: 404,
      ),
    );
    final journeys = HttpJourneyRepository(api: api);
    final plans = HttpPlanRepository(api: api, defaultFamilyId: _familyId);
    final reminders = HttpReminderRepository(api: api, plans: plans);
    addTearDown(journeys.close);
    addTearDown(plans.close);
    addTearDown(reminders.close);

    await expectLater(
      journeys.watchJourneys(_familyId).first,
      throwsA(isA<BackendCapabilityUnavailableException>()),
    );
    await expectLater(
      reminders.createReminder(
        familyId: _familyId,
        planId: _planId,
        label: 'Buy dessert',
        at: DateTime.parse('2026-08-14T14:00:00Z'),
      ),
      throwsA(isA<BackendCapabilityUnavailableException>()),
    );
  });
}

FamilyCompassApiClient _api(
  Future<http.Response> Function(http.Request) handler,
) =>
    FamilyCompassApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      credentials: const BearerApiSession(token: 'signed-test-token'),
      client: MockClient(handler),
    );

http.Response _json(Object value, {int statusCode = 200}) => http.Response(
      jsonEncode(value),
      statusCode,
      headers: <String, String>{'content-type': 'application/json'},
    );

const _familyJson = <String, Object>{
  'id': _familyId,
  'name': 'Hamadeh Family',
  'organizer_id': _userId,
  'member_ids': <String>[_userId, _dadId],
};

const _memberViews = <Map<String, Object>>[
  <String, Object>{
    'user': <String, Object>{'id': _userId, 'name': 'Abdullah'},
    'role': 'organizer',
    'can_invite': true,
  },
  <String, Object>{
    'user': <String, Object>{'id': _dadId, 'name': 'Dad'},
    'role': 'adult',
    'can_invite': true,
  },
];

const _invitationJson = <String, Object>{
  'id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'family_id': _familyId,
  'invited_by': _userId,
  'masked_phone_number': '+971 50 ••• •233',
  'role': 'adult',
  'state': 'pending',
  'created_at': '2026-08-13T09:00:00Z',
  'expires_at': '2026-08-20T09:00:00Z',
};

Map<String, Object?> _messageJson({
  required String clientId,
  required String body,
  List<String>? mentionedMemberIds,
}) =>
    <String, Object?>{
      'id': '99999999-9999-4999-8999-999999999999',
      'client_id': clientId,
      'family_id': _familyId,
      'sender_id': _userId,
      'kind': 'text',
      'body': body,
      if (mentionedMemberIds != null)
        'mentioned_member_ids': mentionedMemberIds,
      'reference_id': null,
      'created_at': '2026-08-13T10:00:00Z',
    };

const _planJson = <String, Object?>{
  'id': _planId,
  'family_id': _familyId,
  'title': 'Friday dinner',
  'location_label': 'Home',
  'coordinator_id': _userId,
  'participant_ids': <String>[_userId, _dadId],
  'candidate_times': <Object>[
    <String, Object>{
      'id': 'friday-1930',
      'starts_at': '2026-08-14T15:30:00Z',
      'time_zone': 'Asia/Dubai',
    },
  ],
  'phase': 'poll_open',
  'decision_deadline': '2026-08-14T08:00:00Z',
  'responses': <String, Object>{},
  'confirmed_candidate_id': null,
  'reminders': <Object>[
    <String, Object>{
      'id': '12121212-1212-4212-8212-121212121212',
      'label': 'Dinner starts in one hour',
      'at': '2026-08-14T14:30:00Z',
      'automatic': true,
    },
  ],
  'contributions': <Object>[],
  'version': 3,
  'created_at': '2026-08-13T09:00:00Z',
  'updated_at': '2026-08-13T09:00:00Z',
};

const _statusJson = <String, Object?>{
  'id': '13131313-1313-4313-8313-131313131313',
  'family_id': _familyId,
  'subject_user_id': _dadId,
  'text': 'Leaving work',
  'source': 'member_shared',
  'updated_at': '2026-08-13T10:00:00Z',
  'expires_at': '2026-08-13T11:00:00Z',
  'audience': 'selected_people',
  'selected_member_ids': <String>[_userId],
  'state': 'active',
};

const _memberStatusJson = <String, Object?>{
  'id': '14141414-1414-4414-8414-141414141414',
  'family_id': _familyId,
  'subject_user_id': _userId,
  'summary': 'At the library',
  'detail': 'Studying until six',
  'updated_at': '2026-08-13T10:00:00Z',
  'expires_at': '2026-08-13T14:00:00Z',
  'state': 'active',
};

const _journeyJson = <String, Object?>{
  'id': '15151515-1515-4515-8515-151515151515',
  'family_id': _familyId,
  'subject_user_id': _userId,
  'summary': 'Heading home',
  'status': 'on_time',
  'eta': '2026-08-13T15:30:00Z',
  'updated_at': '2026-08-13T15:00:00Z',
  'expires_at': '2026-08-13T16:00:00Z',
  'state': 'active',
};

const _deviceJson = <String, Object?>{
  'id': '16161616-1616-4616-8616-161616161616',
  'platform': 'ios',
  'enabled': true,
  'created_at': '2026-08-13T10:00:00Z',
};
