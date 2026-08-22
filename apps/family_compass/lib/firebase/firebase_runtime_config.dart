import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Opt-in Firebase configuration that keeps the checked-in demo build
/// independent from any external Firebase project.
///
/// Configured native builds can use their platform Firebase file. The explicit
/// client identifiers supported for CI are not server credentials and should
/// not be hard-coded in source.
class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig._();

  static const enabled = bool.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_ENABLED',
  );

  /// Enables Firebase's fictional-phone flow for an internal Profile build.
  ///
  /// This is intentionally available only in Profile builds. The matching
  /// phone number is represented by a SHA-256 digest, so neither the phone nor
  /// the verification code is embedded in the app.
  static const _internalTestPhoneRequested = bool.fromEnvironment(
    'FAMILY_COMPASS_INTERNAL_FIREBASE_TEST_AUTH',
  );
  static const _internalTestPhoneSha256 = String.fromEnvironment(
    'FAMILY_COMPASS_INTERNAL_FIREBASE_TEST_PHONE_SHA256',
  );

  static bool get internalTestAuthEnabled => resolveInternalTestAuth(
        firebaseEnabled: enabled,
        requested: _internalTestPhoneRequested,
        isProfile: kProfileMode,
      );

  static String? get internalTestPhoneSha256 {
    if (!internalTestAuthEnabled) return null;
    return validateInternalTestPhoneSha256(_internalTestPhoneSha256);
  }

  static const _apiKey = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_API_KEY',
  );
  static const _appId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_APP_ID',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_PROJECT_ID',
  );
  static const _authDomain = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_AUTH_DOMAIN',
  );
  static const _storageBucket = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_STORAGE_BUCKET',
  );
  static const _measurementId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_MEASUREMENT_ID',
  );
  static const _iosBundleId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.smac.familycompass',
  );
  static const _iosClientId = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_IOS_CLIENT_ID',
  );
  static const _iosUrlScheme = String.fromEnvironment(
    'FAMILY_COMPASS_FIREBASE_IOS_URL_SCHEME',
  );

  static bool get _hasAnyExplicitRequiredValue =>
      _apiKey.isNotEmpty ||
      _appId.isNotEmpty ||
      _messagingSenderId.isNotEmpty ||
      _projectId.isNotEmpty;

  @visibleForTesting
  static bool resolveInternalTestAuth({
    required bool firebaseEnabled,
    required bool requested,
    required bool isProfile,
  }) {
    return firebaseEnabled && requested && isProfile;
  }

  @visibleForTesting
  static String validateInternalTestPhoneSha256(String value) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw StateError(
        'Internal Firebase test auth requires a lowercase SHA-256 phone '
        'digest in FAMILY_COMPASS_INTERNAL_FIREBASE_TEST_PHONE_SHA256.',
      );
    }
    return value;
  }

  /// Whether Firebase should read the default app from the native platform
  /// configuration instead of Dart build values.
  ///
  /// A partially supplied explicit configuration deliberately returns false.
  /// That path is validated by [options] and fails with the missing value
  /// names instead of silently selecting a different native Firebase project.
  @visibleForTesting
  static bool shouldUseNativePlatformConfiguration({
    required bool isEnabled,
    required bool isWeb,
    required TargetPlatform targetPlatform,
    required bool hasAnyExplicitRequiredValue,
  }) {
    if (!isEnabled || isWeb || hasAnyExplicitRequiredValue) return false;
    return switch (targetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        false,
    };
  }

  static bool get _usesNativePlatformConfiguration =>
      shouldUseNativePlatformConfiguration(
        isEnabled: enabled,
        isWeb: kIsWeb,
        targetPlatform: defaultTargetPlatform,
        hasAnyExplicitRequiredValue: _hasAnyExplicitRequiredValue,
      );

  static FirebaseOptions get options {
    if (!enabled) {
      throw StateError(
        'Firebase is disabled. Set FAMILY_COMPASS_FIREBASE_ENABLED=true only '
        'for a configured Firebase build.',
      );
    }
    final missing = <String>[
      if (_apiKey.isEmpty) 'FAMILY_COMPASS_FIREBASE_API_KEY',
      if (_appId.isEmpty) 'FAMILY_COMPASS_FIREBASE_APP_ID',
      if (_messagingSenderId.isEmpty)
        'FAMILY_COMPASS_FIREBASE_MESSAGING_SENDER_ID',
      if (_projectId.isEmpty) 'FAMILY_COMPASS_FIREBASE_PROJECT_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Firebase is enabled but required build values are missing: '
        '${missing.join(', ')}.',
      );
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _authDomain.isEmpty ? null : _authDomain,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      measurementId: _measurementId.isEmpty ? null : _measurementId,
      iosBundleId:
          defaultTargetPlatform == TargetPlatform.iOS ? _iosBundleId : null,
      iosClientId: _iosClientId.isEmpty ? null : _iosClientId,
      deepLinkURLScheme: _iosUrlScheme.isEmpty ? null : _iosUrlScheme,
    );
  }

  static Future<FirebaseApp?> initializeIfEnabled() async {
    if (!enabled) return null;
    if (Firebase.apps.isNotEmpty) return Firebase.app();
    if (_usesNativePlatformConfiguration) {
      return Firebase.initializeApp();
    }
    return Firebase.initializeApp(options: options);
  }

  /// Disables Firebase app verification only for the explicitly selected,
  /// Profile-only fictional-phone build.
  static Future<void> configureInternalPhoneAuthIfRequested({
    FirebaseAuth? auth,
  }) async {
    if (!internalTestAuthEnabled) return;
    // Resolve and validate the policy before disabling app verification.
    internalTestPhoneSha256;
    await (auth ?? FirebaseAuth.instance).setSettings(
      appVerificationDisabledForTesting: true,
    );
  }
}
