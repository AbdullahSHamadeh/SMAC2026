import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/features/onboarding/onboarding_screen.dart';
import 'package:family_compass/firebase/firebase_family_bootstrap.dart';
import 'package:family_compass/firebase/firebase_phone_auth.dart';
import 'package:family_compass/firebase/firebase_phone_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('internal Firebase build is locked to its fictional account',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          internalFirebaseTestAuth: true,
          onComplete: () {},
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));

    expect(find.text('Use test account'), findsOneWidget);
    expect(find.text('INTERNAL TEST · NO SMS'), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding.internalFirebaseTestDisclosure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding.firebasePhoneDisclosure')),
      findsNothing,
    );
    expect(find.textContaining('+971'), findsNothing);
    expect(find.textContaining(RegExp(r'\b\d{6}\b')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+1 202 555 0101',
    );

    await _tap(tester, const Key('onboarding.continue'));
    expect(phoneSession.sentPhone, '+12025550101');
    expect(
      find.text('Enter the 6-digit test code. No SMS was sent.'),
      findsOneWidget,
    );
  });

  testWidgets('Firebase onboarding sends, resends and verifies a 6-digit code',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession();
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          onComplete: () => completed = true,
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byKey(const Key('onboarding.code')), findsNothing);
    expect(
      find.byKey(const Key('onboarding.firebasePhoneDisclosure')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 50 123 4567',
    );
    await _tap(tester, const Key('onboarding.continue'));
    expect(phoneSession.sentPhone, '+971501234567');
    expect(find.byKey(const Key('onboarding.code')), findsOneWidget);
    expect(find.text('Verify and continue'), findsOneWidget);

    await _tap(tester, const Key('onboarding.resendCode'));
    expect(phoneSession.resendCount, 1);

    await tester.enterText(
      find.byKey(const Key('onboarding.code')),
      '123456',
    );
    await _tap(tester, const Key('onboarding.continue'));
    expect(phoneSession.verifiedCode, '123456');
    expect(find.text('Step 3 of 4'), findsOneWidget);

    await _tap(tester, const Key('onboarding.continue'));
    await _tap(tester, const Key('onboarding.continue'));
    expect(phoneSession.registeredName, 'Abdullah');
    expect(completed, isTrue);
  });

  testWidgets('an unbound Firebase account stays behind the family scope gate',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession(authenticated: true);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          canEnterAuthenticatedScope: (_) => false,
          onComplete: () => completed = true,
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    expect(find.text('Step 3 of 4'), findsOneWidget);
    await _tap(tester, const Key('onboarding.continue'));
    await _tap(tester, const Key('onboarding.continue'));

    expect(completed, isFalse);
    expect(find.textContaining('Live family creation'), findsOneWidget);
    expect(find.text('Step 4 of 4'), findsOneWidget);
  });

  testWidgets('join hides outgoing invitation input and explains phone match',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession(authenticated: true);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          onComplete: () {},
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    await tester.tap(find.text('Join by invitation'));
    await tester.pumpAndSettle();
    await _tap(tester, const Key('onboarding.continue'));

    expect(find.byKey(const Key('onboarding.prepareInvite')), findsNothing);
    expect(find.byKey(const Key('onboarding.joinPhoneMatch')), findsOneWidget);
  });

  testWidgets('late automatic verification leaves the code-entry step',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          onComplete: () {},
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 50 123 4567',
    );
    await _tap(tester, const Key('onboarding.continue'));
    expect(find.byKey(const Key('onboarding.code')), findsOneWidget);

    phoneSession.completeAutomaticVerification();
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.byKey(const Key('onboarding.code')), findsNothing);
  });

  testWidgets('repeated-request failure starts a visible local cooldown',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession(
      sendFailure: const PhoneAuthFailure(
        PhoneAuthFailureKind.quotaExceeded,
        'Too many verification attempts. Wait before trying again.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          onComplete: () {},
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 50 123 4567',
    );
    await _tap(tester, const Key('onboarding.continue'));

    expect(find.textContaining('Firebase paused verification'), findsOneWidget);
    expect(find.textContaining('Try again in'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('onboarding.continue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'verified joiner reviews, declines and accepts among multiple invitations',
      (tester) async {
    _phoneViewport(tester);
    final phoneSession = _FakePhoneSession(authenticated: true);
    var pending = <Map<String, Object?>>[_incomingOne, _incomingTwo];
    String? acceptedInvitationId;
    final bootstrap = _bootstrapService((request) async {
      if (request.url.path == '/api/v1/invitations' &&
          request.method == 'GET') {
        return _json(pending);
      }
      if (request.url.path ==
          '/api/v1/invitations/${_incomingOne['id']}/decline') {
        pending = pending
            .where((invitation) => invitation['id'] != _incomingOne['id'])
            .toList();
        return _json(<String, Object?>{
          ..._incomingOne,
          'state': 'declined',
        });
      }
      if (request.url.path ==
          '/api/v1/invitations/${_incomingTwo['id']}/accept') {
        acceptedInvitationId = _incomingTwo['id'] as String;
        return _json(<String, Object?>{
          ..._incomingTwo,
          'state': 'accepted',
        });
      }
      if (request.url.path == '/api/v1/me') {
        return _json(<String, Object>{
          'id': '10000000-0000-4000-8000-000000000001',
          'name': 'Abdullah',
        });
      }
      if (request.url.path == '/api/v1/families') {
        return _json(
          acceptedInvitationId == null
              ? <Object>[]
              : <Object>[
                  <String, Object>{
                    'id': _incomingTwoFamilyId,
                    'name': 'Garden Family',
                    'organizer_id': '40000000-0000-4000-8000-000000000004',
                  },
                ],
        );
      }
      return _json(<String, String>{'detail': 'not found'}, statusCode: 404);
    });
    var completed = false;
    String? selectedInvitationId;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          phoneSession: phoneSession,
          familyBootstrap: bootstrap,
          onAuthenticatedComplete: (result, _) async {
            selectedInvitationId = result.incomingInvitationId;
            await bootstrap.bootstrap(
              displayName: result.name,
              createFamily: result.createsFamily,
              incomingInvitationId: result.incomingInvitationId,
            );
          },
          onComplete: () => completed = true,
        ),
      ),
    );

    await _tap(tester, const Key('onboarding.continue'));
    await tester.tap(find.text('Join by invitation'));
    await tester.pumpAndSettle();
    await _tap(tester, const Key('onboarding.continue'));
    expect(find.text('Review invitations'), findsOneWidget);

    await _tap(tester, const Key('onboarding.continue'));

    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(find.text('Harbor Family'), findsOneWidget);
    expect(find.text('Invited by Mariam'), findsOneWidget);
    expect(find.text('Garden Family'), findsOneWidget);
    expect(find.textContaining('•••• 2233'), findsOneWidget);
    expect(find.textContaining('•••• 7788'), findsOneWidget);
    expect(find.textContaining('+971501112233'), findsNothing);
    expect(find.text('Role: Adult'), findsNWidgets(2));
    expect(find.textContaining('Expires'), findsNWidgets(2));
    expect(find.text('Accept'), findsNWidgets(2));
    expect(find.text('Decline'), findsNWidgets(2));

    await _tap(
      tester,
      Key('onboarding.invitation.${_incomingOne['id']}.decline'),
    );

    expect(find.text('Harbor Family'), findsNothing);
    expect(find.text('Garden Family'), findsOneWidget);
    expect(acceptedInvitationId, isNull);

    await _tap(
      tester,
      Key('onboarding.invitation.${_incomingTwo['id']}.accept'),
    );

    expect(selectedInvitationId, _incomingTwo['id']);
    expect(acceptedInvitationId, _incomingTwo['id']);
    expect(completed, isTrue);
  });
}

void _phoneViewport(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _FakePhoneSession extends ChangeNotifier
    implements PhoneOnboardingController {
  _FakePhoneSession({bool authenticated = false, this.sendFailure})
      : _state = authenticated
            ? const FirebasePhoneSessionState(
                phase: FirebasePhoneSessionPhase.authenticated,
                identity: FirebaseSignedInIdentity(
                  uid: 'firebase-user-one',
                  phoneNumber: '+971501234567',
                ),
              )
            : const FirebasePhoneSessionState.signedOut();

  FirebasePhoneSessionState _state;
  final PhoneAuthFailure? sendFailure;
  String? sentPhone;
  String? verifiedCode;
  String? registeredName;
  int resendCount = 0;

  void completeAutomaticVerification() {
    _state = FirebasePhoneSessionState(
      phase: FirebasePhoneSessionPhase.authenticated,
      challenge: _state.challenge,
      identity: const FirebaseSignedInIdentity(
        uid: 'firebase-user-one',
        phoneNumber: '+971501234567',
      ),
    );
    notifyListeners();
  }

  @override
  FirebasePhoneSessionState get state => _state;

  @override
  Future<void> sendCode(String internationalPhoneNumber) async {
    sentPhone = internationalPhoneNumber;
    final failure = sendFailure;
    if (failure != null) throw failure;
    _state = FirebasePhoneSessionState(
      phase: FirebasePhoneSessionPhase.codeSent,
      challenge: PhoneCodeChallenge(
        verificationId: 'verification-one',
        phoneNumber: internationalPhoneNumber,
        automaticallyVerified: false,
        resendToken: 7,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> resendCode() async {
    resendCount += 1;
    notifyListeners();
  }

  @override
  Future<void> verifyCode(String smsCode) async {
    verifiedCode = smsCode;
    _state = FirebasePhoneSessionState(
      phase: FirebasePhoneSessionPhase.authenticated,
      challenge: _state.challenge,
      identity: const FirebaseSignedInIdentity(
        uid: 'firebase-user-one',
        phoneNumber: '+971501234567',
      ),
    );
    notifyListeners();
  }

  @override
  Future<AppSession> registerBackendAccount(String displayName) async {
    registeredName = displayName;
    const session = AppSession(
      userId: '10000000-0000-4000-8000-000000000001',
      phoneNumber: '+971501234567',
      familyIds: [],
    );
    _state = FirebasePhoneSessionState(
      phase: FirebasePhoneSessionPhase.ready,
      identity: _state.identity,
      session: session,
    );
    notifyListeners();
    return session;
  }

  @override
  Future<void> signOut({Future<void> Function()? beforeFirebaseSignOut}) async {
    await beforeFirebaseSignOut?.call();
    _state = const FirebasePhoneSessionState.signedOut();
    notifyListeners();
  }
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

FirebaseFamilyBootstrapService _bootstrapService(
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

const _incomingOneFamilyId = '20000000-0000-4000-8000-000000000002';
const _incomingTwoFamilyId = '20000000-0000-4000-8000-000000000003';

const _incomingOne = <String, Object?>{
  'id': '30000000-0000-4000-8000-000000000001',
  'family_id': _incomingOneFamilyId,
  'family_name': 'Harbor Family',
  'invited_by': '40000000-0000-4000-8000-000000000004',
  'inviter_name': 'Mariam',
  'masked_phone_number': '+971501112233',
  'role': 'adult',
  'state': 'pending',
  'created_at': '2026-08-13T10:00:00Z',
  'expires_at': '2026-08-20T10:00:00Z',
};

const _incomingTwo = <String, Object?>{
  'id': '30000000-0000-4000-8000-000000000002',
  'family_id': _incomingTwoFamilyId,
  'family_name': 'Garden Family',
  'invited_by': '40000000-0000-4000-8000-000000000005',
  'inviter_name': null,
  'masked_phone_number': '•••• 7788',
  'role': 'adult',
  'state': 'pending',
  'created_at': '2026-08-12T10:00:00Z',
  'expires_at': '2026-08-19T10:00:00Z',
};
