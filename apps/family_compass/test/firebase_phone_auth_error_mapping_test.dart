import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:family_compass/firebase/firebase_phone_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal phone policy matches only the normalized configured account',
      () {
    const allowedPhone = '+12025550101';
    final digest = sha256.convert(utf8.encode(allowedPhone)).toString();

    expect(internalTestPhoneMatches(allowedPhone, digest), isTrue);
    expect(internalTestPhoneMatches('+1 (202) 555-0101', digest), isTrue);
    expect(internalTestPhoneMatches('+12025550102', digest), isFalse);
    expect(internalTestPhoneMatches('', digest), isFalse);
  });

  test('billing failure explains the required Firebase plan', () {
    final failure = mapFirebasePhoneAuthError(
      FirebaseAuthException(code: 'billing-not-enabled'),
    );

    expect(failure.kind, PhoneAuthFailureKind.unavailable);
    expect(failure.diagnosticCode, 'billing-not-enabled');
    expect(failure.message, contains('pay-as-you-go billing'));
  });

  test('unknown Firebase failures retain a safe reference code', () {
    final failure = mapFirebasePhoneAuthError(
      FirebaseAuthException(code: 'unexpected-provider-error'),
    );

    expect(failure.kind, PhoneAuthFailureKind.unavailable);
    expect(failure.diagnosticCode, 'unexpected-provider-error');
    expect(failure.message, contains('Reference: unexpected-provider-error'));
  });

  test('web fallback network failure keeps the connection guidance', () {
    final failure = mapFirebasePhoneAuthError(
      FirebaseAuthException(code: 'web-network-request-failed'),
    );

    expect(failure.kind, PhoneAuthFailureKind.network);
    expect(failure.message, contains('internet connection'));
  });
}
