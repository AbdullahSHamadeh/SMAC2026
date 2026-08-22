import 'dart:async';
import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/firebase/firebase_phone_auth.dart';
import 'package:family_compass/firebase/firebase_phone_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('late automatic verification advances a code-sent session', () async {
    final auth = _FakePhoneAuthGateway();
    final controller = _controller(auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await controller.sendCode('+971501234567');
    expect(controller.state.phase, FirebasePhoneSessionPhase.codeSent);

    auth.emitIdentity(
      const FirebaseSignedInIdentity(
        uid: 'firebase-user',
        phoneNumber: '+971501234567',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.phase, FirebasePhoneSessionPhase.authenticated);
    expect(controller.state.identity?.uid, 'firebase-user');
  });

  test('notification cleanup failure never prevents Firebase sign-out',
      () async {
    final auth = _FakePhoneAuthGateway(
      identity: const FirebaseSignedInIdentity(
        uid: 'firebase-user',
        phoneNumber: '+971501234567',
      ),
    );
    final controller = _controller(auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await expectLater(
      controller.signOut(
        beforeFirebaseSignOut: () =>
            Future<void>.error(StateError('notification cleanup failed')),
      ),
      throwsA(isA<StateError>()),
    );

    expect(auth.signOutCount, 1);
    expect(controller.state.phase, FirebasePhoneSessionPhase.signedOut);
  });
}

FirebasePhoneSessionController _controller(_FakePhoneAuthGateway auth) {
  final api = FamilyCompassApiClient(
    baseUrl: 'https://api.familycompass.test',
    credentials: _Credentials(),
    client: MockClient(
      (_) async => http.Response(
        jsonEncode(<String, String>{'detail': 'unused'}),
        404,
        headers: const <String, String>{'content-type': 'application/json'},
      ),
    ),
  );
  addTearDown(api.close);
  return FirebasePhoneSessionController(
    auth: auth,
    credentials: _Credentials(),
    api: api,
  );
}

class _Credentials implements RefreshableApiCredentialProvider {
  @override
  Map<String, String> get headers => const <String, String>{};

  @override
  Future<void> refresh({required bool force}) async {}
}

class _FakePhoneAuthGateway implements PhoneAuthGateway {
  _FakePhoneAuthGateway({FirebaseSignedInIdentity? identity})
      : _identity = identity;

  final StreamController<FirebaseSignedInIdentity?> _identities =
      StreamController<FirebaseSignedInIdentity?>.broadcast();
  FirebaseSignedInIdentity? _identity;
  int signOutCount = 0;

  @override
  FirebaseSignedInIdentity? get currentIdentity => _identity;

  @override
  Stream<FirebaseSignedInIdentity?> watchIdentity() => _identities.stream;

  void emitIdentity(FirebaseSignedInIdentity identity) {
    _identity = identity;
    _identities.add(identity);
  }

  @override
  Future<PhoneCodeChallenge> requestCode(
    String internationalPhoneNumber, {
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async =>
      PhoneCodeChallenge(
        verificationId: 'verification-one',
        phoneNumber: internationalPhoneNumber,
        automaticallyVerified: false,
      );

  @override
  Future<FirebaseSignedInIdentity> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _identity = null;
    _identities.add(null);
  }

  Future<void> dispose() => _identities.close();
}
