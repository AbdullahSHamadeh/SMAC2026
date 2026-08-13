import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api_mappers.dart';
import '../data/family_compass_api_client.dart';
import '../data/family_compass_repositories.dart';
import 'firebase_phone_auth.dart';

enum FirebasePhoneSessionPhase {
  signedOut,
  sendingCode,
  codeSent,
  verifyingCode,
  authenticated,
  registeringBackendAccount,
  ready,
  failed,
}

abstract interface class PhoneOnboardingController implements Listenable {
  FirebasePhoneSessionState get state;

  Future<void> sendCode(String internationalPhoneNumber);

  Future<void> resendCode();

  Future<void> verifyCode(String smsCode);

  Future<AppSession> registerBackendAccount(String displayName);

  Future<void> signOut({Future<void> Function()? beforeFirebaseSignOut});
}

class FirebasePhoneSessionState {
  const FirebasePhoneSessionState({
    required this.phase,
    this.challenge,
    this.identity,
    this.session,
    this.failure,
  });

  const FirebasePhoneSessionState.signedOut()
      : this(phase: FirebasePhoneSessionPhase.signedOut);

  final FirebasePhoneSessionPhase phase;
  final PhoneCodeChallenge? challenge;
  final FirebaseSignedInIdentity? identity;
  final AppSession? session;
  final Object? failure;
}

/// UI-ready state machine for SMS verification and local backend account
/// registration. It contains no widgets, so onboarding can present the flow in
/// either language without depending on Firebase callback shapes.
class FirebasePhoneSessionController extends ChangeNotifier
    implements PhoneOnboardingController {
  FirebasePhoneSessionController({
    required this.auth,
    required this.credentials,
    required this.api,
  }) {
    final identity = auth.currentIdentity;
    if (identity != null) {
      _state = FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.authenticated,
        identity: identity,
      );
    }
    _identitySubscription = auth.watchIdentity().listen(_identityChanged);
  }

  final PhoneAuthGateway auth;
  final RefreshableApiCredentialProvider credentials;
  final FamilyCompassApiClient api;

  FirebasePhoneSessionState _state =
      const FirebasePhoneSessionState.signedOut();
  StreamSubscription<FirebaseSignedInIdentity?>? _identitySubscription;

  @override
  FirebasePhoneSessionState get state => _state;

  @override
  Future<void> sendCode(String internationalPhoneNumber) async {
    _setState(
      const FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.sendingCode,
      ),
    );
    try {
      final challenge = await auth.requestCode(internationalPhoneNumber);
      final identity = auth.currentIdentity;
      _setState(
        FirebasePhoneSessionState(
          phase: challenge.automaticallyVerified
              ? FirebasePhoneSessionPhase.authenticated
              : FirebasePhoneSessionPhase.codeSent,
          challenge: challenge,
          identity: identity,
        ),
      );
    } on Object catch (error) {
      _setFailure(error);
      rethrow;
    }
  }

  @override
  Future<void> resendCode() async {
    final challenge = _state.challenge;
    if (challenge == null) {
      throw StateError('Request a verification code first.');
    }
    _setState(
      FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.sendingCode,
        challenge: challenge,
      ),
    );
    try {
      final next = await auth.requestCode(
        challenge.phoneNumber,
        forceResendingToken: challenge.resendToken,
      );
      _setState(
        FirebasePhoneSessionState(
          phase: next.automaticallyVerified
              ? FirebasePhoneSessionPhase.authenticated
              : FirebasePhoneSessionPhase.codeSent,
          challenge: next,
          identity: auth.currentIdentity,
        ),
      );
    } on Object catch (error) {
      _setFailure(error);
      rethrow;
    }
  }

  @override
  Future<void> verifyCode(String smsCode) async {
    final challenge = _state.challenge;
    if (challenge == null) {
      throw StateError('Request a verification code first.');
    }
    _setState(
      FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.verifyingCode,
        challenge: challenge,
      ),
    );
    try {
      final identity = await auth.verifyCode(
        verificationId: challenge.verificationId,
        smsCode: smsCode.trim(),
      );
      await credentials.refresh(force: true);
      _setState(
        FirebasePhoneSessionState(
          phase: FirebasePhoneSessionPhase.authenticated,
          challenge: challenge,
          identity: identity,
        ),
      );
    } on Object catch (error) {
      _setFailure(error);
      rethrow;
    }
  }

  @override
  Future<AppSession> registerBackendAccount(String displayName) async {
    final identity = _state.identity ?? auth.currentIdentity;
    if (identity == null) throw StateError('Verify the phone number first.');
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    _setState(
      FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.registeringBackendAccount,
        challenge: _state.challenge,
        identity: identity,
      ),
    );
    try {
      await credentials.refresh(force: false);
      await api.post(
        '/api/v1/auth/phone/register',
        body: <String, Object?>{'name': name},
      );
      final me = asJsonObject(
        await api.get('/api/v1/me'),
        label: 'Current user',
      );
      final families = asJsonObjectList(
        await api.get('/api/v1/families'),
        label: 'Families',
      );
      final session = AppSession(
        userId: me['id'] as String,
        phoneNumber: identity.phoneNumber ?? '',
        familyIds: families.map((family) => family['id'] as String).toList(),
      );
      _setState(
        FirebasePhoneSessionState(
          phase: FirebasePhoneSessionPhase.ready,
          identity: identity,
          session: session,
        ),
      );
      return session;
    } on Object catch (error) {
      _setFailure(error);
      rethrow;
    }
  }

  @override
  Future<void> signOut({Future<void> Function()? beforeFirebaseSignOut}) async {
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await beforeFirebaseSignOut?.call();
    } on Object catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    Object? signOutError;
    StackTrace? signOutStackTrace;
    try {
      await auth.signOut();
    } on Object catch (error, stackTrace) {
      signOutError = error;
      signOutStackTrace = stackTrace;
    } finally {
      _setState(const FirebasePhoneSessionState.signedOut());
    }
    if (signOutError != null) {
      Error.throwWithStackTrace(signOutError, signOutStackTrace!);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  void _identityChanged(FirebaseSignedInIdentity? identity) {
    if (identity == null) {
      if (_state.identity != null) {
        _setState(const FirebasePhoneSessionState.signedOut());
      }
      return;
    }
    if (_state.identity?.uid == identity.uid &&
        (_state.phase == FirebasePhoneSessionPhase.authenticated ||
            _state.phase == FirebasePhoneSessionPhase.ready ||
            _state.phase ==
                FirebasePhoneSessionPhase.registeringBackendAccount)) {
      return;
    }
    _setState(
      FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.authenticated,
        challenge: _state.challenge,
        identity: identity,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_identitySubscription?.cancel());
    super.dispose();
  }

  void _setFailure(Object error) {
    _setState(
      FirebasePhoneSessionState(
        phase: FirebasePhoneSessionPhase.failed,
        challenge: _state.challenge,
        identity: _state.identity,
        session: _state.session,
        failure: error,
      ),
    );
  }

  void _setState(FirebasePhoneSessionState value) {
    _state = value;
    notifyListeners();
  }
}
