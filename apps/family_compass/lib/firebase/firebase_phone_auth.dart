import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/family_compass_api_client.dart';

enum PhoneAuthFailureKind {
  invalidPhoneNumber,
  invalidCode,
  expiredCode,
  quotaExceeded,
  network,
  unsupportedPlatform,
  cancelled,
  unavailable,
}

class PhoneAuthFailure implements Exception {
  const PhoneAuthFailure(this.kind, this.message, {this.diagnosticCode});

  final PhoneAuthFailureKind kind;
  final String message;
  final String? diagnosticCode;

  @override
  String toString() => message;
}

@visibleForTesting
PhoneAuthFailure mapFirebasePhoneAuthError(FirebaseAuthException error) {
  final kind = switch (error.code) {
    'invalid-phone-number' => PhoneAuthFailureKind.invalidPhoneNumber,
    'invalid-verification-code' ||
    'session-expired' =>
      error.code == 'session-expired'
          ? PhoneAuthFailureKind.expiredCode
          : PhoneAuthFailureKind.invalidCode,
    'too-many-requests' ||
    'quota-exceeded' =>
      PhoneAuthFailureKind.quotaExceeded,
    'network-request-failed' ||
    'web-network-request-failed' =>
      PhoneAuthFailureKind.network,
    _ => PhoneAuthFailureKind.unavailable,
  };
  final message = switch (kind) {
    PhoneAuthFailureKind.invalidPhoneNumber =>
      'Enter a valid international phone number.',
    PhoneAuthFailureKind.invalidCode => 'That verification code is not valid.',
    PhoneAuthFailureKind.expiredCode =>
      'That verification code has expired. Request a new one.',
    PhoneAuthFailureKind.quotaExceeded =>
      'Too many verification attempts. Wait before trying again.',
    PhoneAuthFailureKind.network =>
      'Phone verification needs an internet connection.',
    PhoneAuthFailureKind.unsupportedPlatform =>
      'Phone verification is unavailable on this platform.',
    PhoneAuthFailureKind.cancelled => 'Phone verification was cancelled.',
    PhoneAuthFailureKind.unavailable => switch (error.code) {
        'operation-not-allowed' =>
          'Phone sign-in is not enabled for this Firebase project.',
        'billing-not-enabled' =>
          'Real SMS verification requires Firebase pay-as-you-go billing. Reference: billing-not-enabled.',
        'internal-error' =>
          'Firebase rejected the verification request. Check project billing and phone-auth settings. Reference: internal-error.',
        'app-not-authorized' ||
        'app-not-verified' ||
        'app-verification-failed' ||
        'captcha-check-failed' ||
        'invalid-app-credential' ||
        'missing-app-token' =>
          'Firebase could not verify this copy of the app. Try again after app verification is configured.',
        'invalid-api-key' =>
          'The Firebase API key is not configured for phone verification.',
        'web-context-cancelled' =>
          'App verification was cancelled. Tap Send code and complete the verification page.',
        _ => 'Phone verification is temporarily unavailable. '
            'Reference: ${error.code}.',
      },
  };
  return PhoneAuthFailure(
    kind,
    message,
    diagnosticCode: error.code,
  );
}

@visibleForTesting
bool internalTestPhoneMatches(String phone, String allowedSha256) {
  final normalized = normalizeInternationalPhone(phone);
  return normalized != null &&
      sha256.convert(utf8.encode(normalized)).toString() == allowedSha256;
}

@visibleForTesting
String? normalizeInternationalPhone(String value) {
  final trimmed = value.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  final normalized = trimmed.startsWith('+') ? '+$digits' : digits;
  return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(normalized) ? normalized : null;
}

class PhoneCodeChallenge {
  const PhoneCodeChallenge({
    required this.verificationId,
    required this.phoneNumber,
    required this.automaticallyVerified,
    this.resendToken,
  });

  final String verificationId;
  final String phoneNumber;
  final bool automaticallyVerified;
  final int? resendToken;
}

class FirebaseSignedInIdentity {
  const FirebaseSignedInIdentity({
    required this.uid,
    required this.phoneNumber,
  });

  final String uid;
  final String? phoneNumber;
}

abstract interface class PhoneAuthGateway {
  Stream<FirebaseSignedInIdentity?> watchIdentity();

  FirebaseSignedInIdentity? get currentIdentity;

  Future<PhoneCodeChallenge> requestCode(
    String internationalPhoneNumber, {
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  });

  Future<FirebaseSignedInIdentity> verifyCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}

/// Mobile Firebase phone authentication behind a narrow application boundary.
class FirebasePhoneAuthGateway implements PhoneAuthGateway {
  FirebasePhoneAuthGateway({
    FirebaseAuth? auth,
    String? internalTestPhoneSha256,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _internalTestPhoneSha256 = internalTestPhoneSha256;

  final FirebaseAuth _auth;
  final String? _internalTestPhoneSha256;

  @override
  Stream<FirebaseSignedInIdentity?> watchIdentity() =>
      _auth.authStateChanges().map(_identityFor);

  @override
  FirebaseSignedInIdentity? get currentIdentity =>
      _identityFor(_auth.currentUser);

  /// Firebase Auth state can survive an app reinstall through the Keychain.
  /// An internal fictional-account build must not restore any other identity.
  Future<void> clearDisallowedPersistedIdentity() async {
    final allowedSha256 = _internalTestPhoneSha256;
    final currentUser = _auth.currentUser;
    if (allowedSha256 == null || currentUser == null) return;
    if (!internalTestPhoneMatches(
      currentUser.phoneNumber ?? '',
      allowedSha256,
    )) {
      await _auth.signOut();
    }
  }

  @override
  Future<PhoneCodeChallenge> requestCode(
    String internationalPhoneNumber, {
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.unsupportedPlatform,
        'This phone verification flow is for the iOS and Android apps.',
      );
    }
    final normalized = normalizeInternationalPhone(internationalPhoneNumber);
    if (normalized == null) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.invalidPhoneNumber,
        'Enter a phone number in international format.',
      );
    }
    final allowedSha256 = _internalTestPhoneSha256;
    if (allowedSha256 != null &&
        !internalTestPhoneMatches(normalized, allowedSha256)) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.invalidPhoneNumber,
        'This internal build accepts its configured fictional test account '
        'only. No SMS was requested.',
      );
    }

    final result = Completer<PhoneCodeChallenge>();
    await _auth.verifyPhoneNumber(
      phoneNumber: normalized,
      forceResendingToken: forceResendingToken,
      timeout: timeout,
      verificationCompleted: (credential) async {
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          if (!result.isCompleted) {
            result.complete(
              PhoneCodeChallenge(
                verificationId: credential.verificationId ?? '',
                phoneNumber: userCredential.user?.phoneNumber ?? normalized,
                automaticallyVerified: true,
              ),
            );
          }
        } on FirebaseAuthException catch (error, stackTrace) {
          if (!result.isCompleted) {
            result.completeError(_mapAuthError(error), stackTrace);
          }
        }
      },
      verificationFailed: (error) {
        if (!result.isCompleted) result.completeError(_mapAuthError(error));
      },
      codeSent: (verificationId, resendToken) {
        if (!result.isCompleted) {
          result.complete(
            PhoneCodeChallenge(
              verificationId: verificationId,
              phoneNumber: normalized,
              automaticallyVerified: false,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!result.isCompleted) {
          result.complete(
            PhoneCodeChallenge(
              verificationId: verificationId,
              phoneNumber: normalized,
              automaticallyVerified: false,
            ),
          );
        }
      },
    );
    return result.future;
  }

  @override
  Future<FirebaseSignedInIdentity> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (verificationId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.invalidCode,
        'Enter the 6-digit verification code.',
      );
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      final identity = _identityFor(result.user);
      if (identity == null) {
        throw const PhoneAuthFailure(
          PhoneAuthFailureKind.unavailable,
          'Firebase did not return a signed-in account.',
        );
      }
      return identity;
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<String> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.cancelled,
        'Sign in again to continue.',
      );
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.unavailable,
        'Firebase did not return an ID token.',
      );
    }
    return token;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static FirebaseSignedInIdentity? _identityFor(User? user) => user == null
      ? null
      : FirebaseSignedInIdentity(
          uid: user.uid,
          phoneNumber: user.phoneNumber,
        );

  static PhoneAuthFailure _mapAuthError(FirebaseAuthException error) =>
      mapFirebasePhoneAuthError(error);
}

/// Supplies the latest Firebase ID token to both HTTP and WebSocket clients.
/// Automatic token changes update the cached bearer value. A backend 401 asks
/// this provider to force-refresh before the API client retries once.
class FirebaseApiCredentialProvider
    implements RefreshableApiCredentialProvider {
  FirebaseApiCredentialProvider._(this._auth, this._token);

  final FirebaseAuth _auth;
  String _token;
  StreamSubscription<User?>? _tokenSubscription;

  static Future<FirebaseApiCredentialProvider> create(
      {FirebaseAuth? auth}) async {
    final resolved = auth ?? FirebaseAuth.instance;
    final initialToken = await resolved.currentUser?.getIdToken() ?? '';
    final provider = FirebaseApiCredentialProvider._(resolved, initialToken);
    provider._tokenSubscription = resolved.idTokenChanges().listen(
      (user) async {
        provider._token = await user?.getIdToken() ?? '';
      },
    );
    return provider;
  }

  @override
  Map<String, String> get headers => <String, String>{
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  @override
  Future<void> refresh({required bool force}) async {
    final user = _auth.currentUser;
    if (user == null) {
      _token = '';
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.cancelled,
        'Sign in again to continue.',
      );
    }
    _token = await user.getIdToken(force) ?? '';
    if (_token.isEmpty) {
      throw const PhoneAuthFailure(
        PhoneAuthFailureKind.unavailable,
        'Firebase did not return an ID token.',
      );
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }
}
