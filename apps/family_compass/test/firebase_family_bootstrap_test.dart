import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/firebase/firebase_family_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
const _familyId = '20000000-0000-4000-8000-000000000002';

void main() {
  test('create binds actual IDs and sends the optional live invitation',
      () async {
    final requests = <http.Request>[];
    var familyCreated = false;
    final service = _service((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{'id': _userId, 'name': 'Amina'});
      }
      if (request.url.path == '/api/v1/families' && request.method == 'GET') {
        return _json(familyCreated ? <Object>[_family] : <Object>[]);
      }
      if (request.url.path == '/api/v1/families' && request.method == 'POST') {
        familyCreated = true;
        expect(jsonDecode(request.body), <String, Object>{
          'name': "Amina's family",
        });
        return _json(_family, statusCode: 201);
      }
      if (request.url.path.endsWith('/invitations')) {
        expect(
          jsonDecode(request.body),
          <String, Object>{
            'phone_number': '+971501112233',
            'role': 'adult',
          },
        );
        return _json(_invitation, statusCode: 201);
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });

    final binding = await service.bootstrap(
      displayName: 'Amina',
      createFamily: true,
      outgoingInvitationPhone: '+971501112233',
    );

    expect(binding.userId, _userId);
    expect(binding.familyId, _familyId);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      containsAllInOrder(<String>[
        'GET /api/v1/me',
        'GET /api/v1/families',
        'POST /api/v1/families',
        'POST /api/v1/families/$_familyId/invitations',
      ]),
    );
  });

  test('join accepts only the invitation explicitly selected by the user',
      () async {
    String? acceptedInvitationId;
    final requests = <String>[];
    final service = _service((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{'id': _userId, 'name': 'Amina'});
      }
      if (request.url.path == '/api/v1/families') {
        return _json(
          acceptedInvitationId == null ? <Object>[] : <Object>[_family],
        );
      }
      if (request.url.path ==
          '/api/v1/invitations/${_invitation['id']}/accept') {
        acceptedInvitationId = _invitation['id'] as String;
        return _json(<String, Object>{..._invitation, 'state': 'accepted'});
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });

    final binding = await service.bootstrap(
      displayName: 'Amina',
      createFamily: false,
      outgoingInvitationPhone: '+971599999999',
      incomingInvitationId: _invitation['id'] as String,
    );

    expect(acceptedInvitationId, _invitation['id']);
    expect(binding.familyId, _familyId);
    expect(requests, isNot(contains('GET /api/v1/invitations')));
    expect(requests, isNot(contains('GET /api/v1/families')));
  });

  test('incoming invitations preserve labels while forcing a safe phone mask',
      () async {
    final service = _service((request) async {
      if (request.url.path == '/api/v1/invitations') {
        return _json(<Object>[
          <String, Object?>{
            ..._invitation,
            'family_name': 'Harbor Family',
            'inviter_name': 'Mariam',
            'masked_phone_number': '+971501112233',
          },
          <String, Object?>{
            ..._invitation,
            'id': '30000000-0000-4000-8000-000000000004',
            'family_name': 'Garden Family',
            'inviter_name': null,
            'masked_phone_number': '•••• 7788',
          },
        ]);
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });

    final invitations = await service.loadIncomingInvitations();

    expect(invitations, hasLength(2));
    expect(invitations.first.familyName, 'Harbor Family');
    expect(invitations.first.inviterName, 'Mariam');
    expect(invitations.first.maskedPhoneNumber, '•••• 2233');
    expect(invitations.first.maskedPhoneNumber, isNot(contains('+971')));
    expect(invitations.last.familyName, 'Garden Family');
    expect(invitations.last.inviterName, isNull);
    expect(invitations.last.maskedPhoneNumber, '•••• 7788');
  });

  test('join requires an explicit selection and decline targets one invite',
      () async {
    final requests = <String>[];
    final service = _service((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{'id': _userId, 'name': 'Amina'});
      }
      if (request.url.path == '/api/v1/families') return _json(<Object>[]);
      if (request.url.path ==
          '/api/v1/invitations/${_invitation['id']}/decline') {
        return _json(<String, Object>{..._invitation, 'state': 'declined'});
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });

    await expectLater(
      service.bootstrap(displayName: 'Amina', createFamily: false),
      throwsA(
        isA<FirebaseFamilyBootstrapFailure>().having(
          (error) => error.english,
          'english',
          contains('Choose an invitation'),
        ),
      ),
    );
    await service.declineIncomingInvitation(_invitation['id'] as String);

    expect(
      requests,
      contains('POST /api/v1/invitations/${_invitation['id']}/decline'),
    );
    expect(requests.where((value) => value.endsWith('/accept')), isEmpty);
  });

  test('notification family binding is returned only for a real membership',
      () async {
    final service = _service((request) async {
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{'id': _userId, 'name': 'Amina'});
      }
      if (request.url.path == '/api/v1/families') {
        return _json(<Object>[_family]);
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });

    final allowed = await service.restoreBindingForFamily(_familyId);
    final foreign = await service.restoreBindingForFamily(
      '90000000-0000-4000-8000-000000000009',
    );

    expect(allowed?.userId, _userId);
    expect(allowed?.familyId, _familyId);
    expect(foreign, isNull);
  });
}

FirebaseFamilyBootstrapService _service(
  Future<http.Response> Function(http.Request request) handler,
) {
  final api = FamilyCompassApiClient(
    baseUrl: 'https://api.familycompass.test',
    credentials: const BearerApiSession(token: 'token'),
    client: MockClient(handler),
  );
  addTearDown(api.close);
  return FirebaseFamilyBootstrapService(api: api);
}

http.Response _json(Object value, {int statusCode = 200}) => http.Response(
      jsonEncode(value),
      statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );

const _family = <String, Object>{
  'id': _familyId,
  'name': 'Amina family',
  'organizer_id': _userId,
};

const _invitation = <String, Object>{
  'id': '30000000-0000-4000-8000-000000000003',
  'family_id': _familyId,
  'invited_by': '40000000-0000-4000-8000-000000000004',
  'masked_phone_number': '+971 50 ••• •233',
  'role': 'adult',
  'state': 'pending',
  'created_at': '2026-08-13T10:00:00Z',
  'expires_at': '2026-08-20T10:00:00Z',
  'family_name': 'Amina family',
  'inviter_name': 'Mariam',
};
