import 'package:family_compass/firebase/firebase_runtime_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase native platform configuration selection', () {
    test('stays off when Firebase is disabled', () {
      expect(
        FirebaseRuntimeConfig.shouldUseNativePlatformConfiguration(
          isEnabled: false,
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          hasAnyExplicitRequiredValue: false,
        ),
        isFalse,
      );
    });

    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      test('uses native configuration on ${platform.name}', () {
        expect(
          FirebaseRuntimeConfig.shouldUseNativePlatformConfiguration(
            isEnabled: true,
            isWeb: false,
            targetPlatform: platform,
            hasAnyExplicitRequiredValue: false,
          ),
          isTrue,
        );
      });
    }

    test('web still requires explicit options', () {
      expect(
        FirebaseRuntimeConfig.shouldUseNativePlatformConfiguration(
          isEnabled: true,
          isWeb: true,
          targetPlatform: TargetPlatform.android,
          hasAnyExplicitRequiredValue: false,
        ),
        isFalse,
      );
    });

    test('explicit values retain the explicit-options path', () {
      expect(
        FirebaseRuntimeConfig.shouldUseNativePlatformConfiguration(
          isEnabled: true,
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          hasAnyExplicitRequiredValue: true,
        ),
        isFalse,
      );
    });

    for (final platform in <TargetPlatform>[
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      test('${platform.name} still requires explicit options', () {
        expect(
          FirebaseRuntimeConfig.shouldUseNativePlatformConfiguration(
            isEnabled: true,
            isWeb: false,
            targetPlatform: platform,
            hasAnyExplicitRequiredValue: false,
          ),
          isFalse,
        );
      });
    }
  });

  group('internal Firebase fictional-phone build', () {
    test('enables only for an explicitly requested Profile Firebase build', () {
      expect(
        FirebaseRuntimeConfig.resolveInternalTestAuth(
          firebaseEnabled: true,
          requested: true,
          isProfile: true,
        ),
        isTrue,
      );
    });

    test('stays off when not requested, Firebase is off, or not Profile', () {
      for (final values in <(bool, bool, bool)>[
        (true, false, true),
        (false, true, true),
        (true, true, false),
      ]) {
        expect(
          FirebaseRuntimeConfig.resolveInternalTestAuth(
            firebaseEnabled: values.$1,
            requested: values.$2,
            isProfile: values.$3,
          ),
          isFalse,
        );
      }
    });

    test('accepts only a lowercase 64-character phone digest', () {
      const digest =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      expect(
        FirebaseRuntimeConfig.validateInternalTestPhoneSha256(digest),
        digest,
      );
      expect(
        () => FirebaseRuntimeConfig.validateInternalTestPhoneSha256(''),
        throwsStateError,
      );
      expect(
        () => FirebaseRuntimeConfig.validateInternalTestPhoneSha256(
          digest.toUpperCase(),
        ),
        throwsStateError,
      );
    });
  });
}
