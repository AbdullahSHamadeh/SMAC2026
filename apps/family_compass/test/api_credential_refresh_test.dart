import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a 401 forces one token refresh and retries with the new token',
      () async {
    final credentials = _RefreshableCredentials();
    final authorizations = <String?>[];
    final client = MockClient((request) async {
      authorizations.add(request.headers['Authorization']);
      if (authorizations.length == 1) {
        return http.Response(
          jsonEncode(<String, String>{'detail': 'expired'}),
          401,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, bool>{'ok': true}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final api = FamilyCompassApiClient(
      baseUrl: 'https://api.familycompass.test',
      credentials: credentials,
      client: client,
    );

    final result = await api.get('/api/v1/me');

    expect(result, <String, bool>{'ok': true});
    expect(credentials.refreshCount, 1);
    expect(credentials.lastForced, isTrue);
    expect(authorizations, <String>['Bearer expired', 'Bearer refreshed']);
  });

  test('a second 401 is returned without another automatic replay', () async {
    final credentials = _RefreshableCredentials();
    var calls = 0;
    final api = FamilyCompassApiClient(
      baseUrl: 'https://api.familycompass.test',
      credentials: credentials,
      client: MockClient((_) async {
        calls += 1;
        return http.Response(
          jsonEncode(<String, String>{'detail': 'revoked'}),
          401,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.get('/api/v1/me'),
      throwsA(
        isA<FamilyCompassApiException>().having(
          (error) => error.kind,
          'kind',
          FamilyCompassApiErrorKind.unauthorized,
        ),
      ),
    );

    expect(calls, 2);
    expect(credentials.refreshCount, 1);
  });
}

class _RefreshableCredentials implements RefreshableApiCredentialProvider {
  String token = 'expired';
  int refreshCount = 0;
  bool? lastForced;

  @override
  Map<String, String> get headers => <String, String>{
        'Authorization': 'Bearer $token',
      };

  @override
  Future<void> refresh({required bool force}) async {
    refreshCount += 1;
    lastForced = force;
    token = 'refreshed';
  }
}
