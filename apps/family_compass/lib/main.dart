import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_preferences.dart';
import 'app/family_compass_app.dart';
import 'data/http_family_compass_repositories.dart';
import 'firebase/firebase_family_runtime.dart';
import 'firebase/firebase_notifications.dart';
import 'firebase/firebase_phone_auth.dart';
import 'firebase/firebase_runtime_config.dart';
import 'prototype/prototype_scenario_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLinks = AppLinks().uriLinkStream;
  FirebaseNotificationCoordinator? notifications;
  FirebaseApiCredentialProvider? firebaseCredentials;
  FirebasePhoneAuthGateway? phoneAuth;
  Stream<Uri> incomingLinks = appLinks;
  if (FirebaseRuntimeConfig.enabled) {
    await FirebaseRuntimeConfig.initializeIfEnabled();
    final firebaseAuth = FirebaseAuth.instance;
    await FirebaseRuntimeConfig.configureInternalPhoneAuthIfRequested(
      auth: firebaseAuth,
    );
    FirebaseMessaging.onBackgroundMessage(
      familyCompassFirebaseBackgroundHandler,
    );
    notifications = FirebaseNotificationCoordinator();
    await notifications.start();
    phoneAuth = FirebasePhoneAuthGateway(
      auth: firebaseAuth,
      internalTestPhoneSha256: FirebaseRuntimeConfig.internalTestPhoneSha256,
    );
    await phoneAuth.clearDisallowedPersistedIdentity();
    firebaseCredentials = await FirebaseApiCredentialProvider.create(
      auth: firebaseAuth,
    );
    incomingLinks = mergeIncomingLinks(appLinks, notifications.openedLinks);
  }
  final preferencesStore = await _loadPreferences();
  const useHttpBackend = bool.fromEnvironment(
    'FAMILY_COMPASS_USE_HTTP_BACKEND',
  );
  const legacyCompassOnly = bool.fromEnvironment(
    'FAMILY_COMPASS_USE_HTTP_COMPASS',
  );
  final useHttp =
      useHttpBackend || legacyCompassOnly || FirebaseRuntimeConfig.enabled;
  const apiBaseUrl = String.fromEnvironment(
    'FAMILY_COMPASS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  const familyId = String.fromEnvironment(
    'FAMILY_COMPASS_FAMILY_ID',
    defaultValue: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  );
  const demoUserId = String.fromEnvironment(
    'FAMILY_COMPASS_DEMO_USER_ID',
    defaultValue: '11111111-1111-1111-1111-111111111111',
  );
  const authToken = String.fromEnvironment('FAMILY_COMPASS_AUTH_TOKEN');
  final bundle = useHttp && !FirebaseRuntimeConfig.enabled
      ? await HttpFamilyCompassRepositoryBundle.create(
          apiBaseUrl: apiBaseUrl,
          familyId: familyId,
          currentUserId: demoUserId,
          authToken: authToken,
          credentials: firebaseCredentials,
          preferences: preferencesStore is SharedPreferencesAppPreferencesStore
              ? await SharedPreferences.getInstance()
              : null,
        )
      : null;
  SharedPreferences? sharedPreferences;
  if (FirebaseRuntimeConfig.enabled) {
    try {
      sharedPreferences = await SharedPreferences.getInstance();
    } on Object {
      // Runtime repositories and notification registration have memory-backed
      // fallbacks when platform preferences are temporarily unavailable.
    }
  }
  if (FirebaseRuntimeConfig.enabled &&
      firebaseCredentials != null &&
      phoneAuth != null) {
    runApp(
      FirebaseFamilyCompassRuntime(
        apiBaseUrl: apiBaseUrl,
        credentials: firebaseCredentials,
        phoneAuth: phoneAuth,
        preferencesStore: preferencesStore,
        incomingLinks: incomingLinks,
        notifications: notifications,
        sharedPreferences: sharedPreferences,
        internalFirebaseTestAuth: FirebaseRuntimeConfig.internalTestAuthEnabled,
      ),
    );
    return;
  }
  final controller = PrototypeScenarioController(
    repositories: bundle?.repositories,
    familyId: bundle == null ? null : familyId,
    currentUserId: bundle == null ? null : demoUserId,
    familyEvents: bundle?.events.watch(),
  );
  runApp(
    FamilyCompassApp(
      controller: controller,
      preferencesStore: preferencesStore,
      compassRepository: bundle?.repositories.compass,
      repositories: bundle?.repositories,
      familyId: bundle == null ? null : familyId,
      incomingLinks: incomingLinks,
    ),
  );
}

Future<AppPreferencesStore> _loadPreferences() async {
  try {
    return await SharedPreferencesAppPreferencesStore.create();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Family Compass preferences',
        context: ErrorDescription('while loading saved preferences'),
      ),
    );
    return MemoryAppPreferencesStore();
  }
}
