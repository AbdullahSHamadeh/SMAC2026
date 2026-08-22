import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/family_compass_repositories.dart';
import '../data/family_realtime_client.dart';
import 'firebase_runtime_config.dart';

@pragma('vm:entry-point')
Future<void> familyCompassFirebaseBackgroundHandler(
  RemoteMessage message,
) async {
  // Notification payloads are displayed by the OS. Data-only messages may use
  // this isolate for short refresh work later, but must never mutate UI state.
  if (FirebaseRuntimeConfig.enabled) {
    await FirebaseRuntimeConfig.initializeIfEnabled();
  }
  NotificationEnvelope.tryParse(message);
}

enum NotificationAuthorizationState {
  notDetermined,
  denied,
  authorized,
  provisional,
}

enum NotificationPreferencePhase {
  idle,
  checking,
  enabling,
  enabled,
  denied,
  disabling,
  failed,
}

class NotificationPreferenceState {
  const NotificationPreferenceState({
    required this.phase,
    this.failure,
  });

  const NotificationPreferenceState.idle()
      : this(phase: NotificationPreferencePhase.idle);

  final NotificationPreferencePhase phase;
  final Object? failure;

  bool get isEnabled => phase == NotificationPreferencePhase.enabled;

  bool get isBusy =>
      phase == NotificationPreferencePhase.checking ||
      phase == NotificationPreferencePhase.enabling ||
      phase == NotificationPreferencePhase.disabling;
}

abstract interface class NotificationPreferenceController
    implements Listenable {
  NotificationPreferenceState get state;

  Future<void> loadStatus();

  Future<void> enable();

  Future<void> disable();
}

class NotificationEnvelope {
  const NotificationEnvelope({
    required this.eventType,
    required this.deepLink,
    required this.messageId,
    required this.receivedAt,
  });

  final String eventType;
  final FamilyCompassDeepLink deepLink;
  final String? messageId;
  final DateTime receivedAt;

  static NotificationEnvelope? tryParse(RemoteMessage message) {
    final data = message.data;
    final rawLink = data['deep_link'];
    final eventType = data['event_type'];
    final familyId = data['family_id'];
    final resourceId = data['resource_id'];
    if (rawLink == null ||
        eventType == null ||
        familyId == null ||
        resourceId == null) {
      return null;
    }
    final link = FamilyCompassDeepLink.tryParse(rawLink);
    if (link == null ||
        link.familyId != familyId ||
        link.resourceId != resourceId ||
        link.kind == FamilyResourceKind.unknown) {
      return null;
    }
    return NotificationEnvelope(
      eventType: eventType,
      deepLink: link,
      messageId: message.messageId,
      receivedAt: message.sentTime ?? DateTime.now().toUtc(),
    );
  }
}

abstract interface class InstallationIdentitySource {
  Future<String> getId();

  Stream<String> get onIdChange;
}

class FirebaseInstallationIdentitySource implements InstallationIdentitySource {
  FirebaseInstallationIdentitySource({FirebaseInstallations? installations})
      : _installations = installations ?? FirebaseInstallations.instance;

  final FirebaseInstallations _installations;

  @override
  Future<String> getId() => _installations.getId();

  @override
  Stream<String> get onIdChange => _installations.onIdChange;
}

/// Owns notification permission, foreground delivery, and notification-open
/// routing. Notification taps emit the same verified custom URI used by native
/// app links, including the terminated-launch path.
class FirebaseNotificationCoordinator {
  FirebaseNotificationCoordinator({
    FirebaseMessaging? messaging,
    InstallationIdentitySource? installations,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _installations = installations ?? FirebaseInstallationIdentitySource();

  final FirebaseMessaging _messaging;
  final InstallationIdentitySource _installations;
  final StreamController<NotificationEnvelope> _foreground =
      StreamController<NotificationEnvelope>.broadcast();
  final StreamController<Uri> _openedLinks = StreamController<Uri>.broadcast();
  final List<StreamSubscription<RemoteMessage>> _subscriptions = [];
  Uri? _initialLink;
  bool _started = false;

  Stream<NotificationEnvelope> get foregroundMessages => _foreground.stream;

  Stream<Uri> get openedLinks async* {
    final initial = _initialLink;
    if (initial != null) {
      _initialLink = null;
      yield initial;
    }
    yield* _openedLinks.stream;
  }

  Stream<String> get installationIdChanges => _installations.onIdChange;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _messaging.setForegroundNotificationPresentationOptions(
      // The Flutter surface below shows a generic, actionable notice. Avoid a
      // second iOS banner that could render untrusted notification copy.
      alert: false,
      badge: true,
      sound: false,
    );
    final initialMessage = await _messaging.getInitialMessage();
    _initialLink = initialMessage == null
        ? null
        : NotificationEnvelope.tryParse(initialMessage)?.deepLinkUri;
    _subscriptions
      ..add(
        FirebaseMessaging.onMessage.listen((message) {
          final envelope = NotificationEnvelope.tryParse(message);
          if (envelope != null && !_foreground.isClosed) {
            _foreground.add(envelope);
          }
        }),
      )
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final envelope = NotificationEnvelope.tryParse(message);
          if (envelope != null && !_openedLinks.isClosed) {
            _openedLinks.add(envelope.deepLinkUri);
          }
        }),
      );
  }

  Future<NotificationAuthorizationState> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return _authorizationState(settings.authorizationStatus);
  }

  Future<NotificationAuthorizationState> authorizationState() async {
    final settings = await _messaging.getNotificationSettings();
    return _authorizationState(settings.authorizationStatus);
  }

  Future<String> installationId() => _installations.getId();

  /// Ensures the FCM SDK has registered this installation before its FID is
  /// uploaded as a notification target. FlutterFire currently exposes this
  /// readiness operation through getToken, even though the backend sends to
  /// the installation ID rather than the deprecated registration token.
  Future<void> ensureMessagingRegistration() async {
    final registrationToken = await _messaging.getToken();
    if (registrationToken == null || registrationToken.isEmpty) {
      throw StateError('FCM did not finish registering this installation.');
    }
  }

  Future<void> setAutoInitEnabled(bool enabled) =>
      _messaging.setAutoInitEnabled(enabled);

  Future<String?> apnsToken() => _messaging.getAPNSToken();

  /// Waits briefly for iOS to finish the asynchronous APNs registration that
  /// follows notification authorization. FCM token creation must not race the
  /// APNs token, but a missing token also must not leave the settings action
  /// waiting forever.
  Future<String> waitForApnsToken({
    int maxAttempts = 20,
    Duration retryDelay = const Duration(milliseconds: 250),
    Future<void> Function(Duration duration)? delay,
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }
    final wait = delay ?? (Duration duration) => Future<void>.delayed(duration);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final token = (await apnsToken())?.trim();
      if (token != null && token.isNotEmpty) return token;
      if (attempt + 1 < maxAttempts) await wait(retryDelay);
    }
    throw StateError(
      'APNs did not provide a device token after a bounded registration wait. '
      'Try enabling notifications again.',
    );
  }

  Future<void> deleteToken() => _messaging.deleteToken();

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _foreground.close();
    await _openedLinks.close();
  }

  static NotificationAuthorizationState _authorizationState(
    AuthorizationStatus status,
  ) =>
      switch (status) {
        AuthorizationStatus.authorized =>
          NotificationAuthorizationState.authorized,
        AuthorizationStatus.provisional =>
          NotificationAuthorizationState.provisional,
        AuthorizationStatus.denied => NotificationAuthorizationState.denied,
        AuthorizationStatus.notDetermined =>
          NotificationAuthorizationState.notDetermined,
      };
}

extension on NotificationEnvelope {
  Uri get deepLinkUri => Uri(
        scheme: 'familycompass',
        host: 'families',
        pathSegments: <String>[
          deepLink.familyId,
          switch (deepLink.kind) {
            FamilyResourceKind.messages => 'messages',
            FamilyResourceKind.plans => 'plans',
            FamilyResourceKind.reminders => 'reminders',
            FamilyResourceKind.checkIns => 'check-ins',
            FamilyResourceKind.unknown => 'unknown',
          },
          deepLink.resourceId,
        ],
      );
}

abstract interface class DeviceRegistrationStore {
  String? get deviceId;

  String? get token;

  Future<void> save({required String deviceId, required String token});

  Future<void> clear();
}

class SharedPreferencesDeviceRegistrationStore
    implements DeviceRegistrationStore {
  SharedPreferencesDeviceRegistrationStore(this._preferences);

  static const _deviceIdKey = 'firebase.device_registration_id';
  static const _tokenKey = 'firebase.device_registration_token';

  final SharedPreferences _preferences;

  @override
  String? get deviceId => _preferences.getString(_deviceIdKey);

  @override
  String? get token => _preferences.getString(_tokenKey);

  @override
  Future<void> save({required String deviceId, required String token}) async {
    await _preferences.setString(_deviceIdKey, deviceId);
    await _preferences.setString(_tokenKey, token);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_deviceIdKey);
    await _preferences.remove(_tokenKey);
  }
}

class MemoryDeviceRegistrationStore implements DeviceRegistrationStore {
  @override
  String? deviceId;

  @override
  String? token;

  @override
  Future<void> save({required String deviceId, required String token}) async {
    this.deviceId = deviceId;
    this.token = token;
  }

  @override
  Future<void> clear() async {
    deviceId = null;
    token = null;
  }
}

/// Keeps the current Firebase Installation ID (FID) registered to the
/// authenticated backend account and removes the association during sign-out.
class FirebaseDeviceRegistrationCoordinator {
  FirebaseDeviceRegistrationCoordinator({
    required this.notifications,
    required this.devices,
    required this.store,
  });

  final FirebaseNotificationCoordinator notifications;
  final DeviceRepository devices;
  final DeviceRegistrationStore store;
  StreamSubscription<String>? _refreshSubscription;
  Future<void> _serial = Future<void>.value();

  Future<NotificationAuthorizationState> requestPermissionAndRegister() async {
    final authorization = await notifications.requestPermission();
    if (authorization != NotificationAuthorizationState.authorized &&
        authorization != NotificationAuthorizationState.provisional) {
      return authorization;
    }
    await notifications.setAutoInitEnabled(true);
    await registerCurrentInstallation();
    _refreshSubscription ??= notifications.installationIdChanges.listen(
      (installationId) => _enqueue(() async {
        await notifications.ensureMessagingRegistration();
        await _replaceRegistration(installationId);
      }),
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Family Compass notifications',
            context: ErrorDescription('while refreshing an installation ID'),
          ),
        );
      },
    );
    return authorization;
  }

  Future<void> registerCurrentInstallation() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await notifications.waitForApnsToken();
    }
    await notifications.ensureMessagingRegistration();
    final installationId = await notifications.installationId();
    if (installationId.isEmpty) {
      throw StateError('Firebase did not provide an installation ID.');
    }
    await _enqueue(() => _replaceRegistration(installationId));
  }

  Future<void> unregisterAndDeleteToken() => _enqueue(() async {
        final currentDeviceId = store.deviceId;
        if (currentDeviceId != null) {
          try {
            await devices.unregister(currentDeviceId);
          } on Object {
            // The backend may already have expired or deleted this device.
          }
        }
        await notifications.deleteToken();
        await notifications.setAutoInitEnabled(false);
        await store.clear();
      });

  Future<void> _replaceRegistration(String installationId) async {
    if (store.token == installationId && store.deviceId != null) return;
    final previousDeviceId = store.deviceId;
    final registration = await devices.register(
      token: installationId,
      platform: _platform,
    );
    await store.save(deviceId: registration.id, token: installationId);
    if (previousDeviceId != null && previousDeviceId != registration.id) {
      try {
        await devices.unregister(previousDeviceId);
      } on Object {
        // The new token is authoritative; stale cleanup is best-effort.
      }
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _serial.then((_) => operation());
    _serial = next.catchError((_) {});
    return next;
  }

  DevicePlatform get _platform {
    if (kIsWeb) return DevicePlatform.web;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? DevicePlatform.ios
        : DevicePlatform.android;
  }

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    await _serial;
  }
}

/// State exposed to the settings screen. Merely creating this controller never
/// requests notification permission; the prompt appears only after `enable` is
/// called from the person's explicit settings action.
class FirebaseNotificationPreferenceController extends ChangeNotifier
    implements NotificationPreferenceController {
  FirebaseNotificationPreferenceController({required this.registration});

  final FirebaseDeviceRegistrationCoordinator registration;

  NotificationPreferenceState _state = const NotificationPreferenceState.idle();

  @override
  NotificationPreferenceState get state => _state;

  @override
  Future<void> loadStatus() async {
    if (_state.isBusy) return;
    _setState(
      const NotificationPreferenceState(
        phase: NotificationPreferencePhase.checking,
      ),
    );
    try {
      final authorization =
          await registration.notifications.authorizationState();
      final registered = registration.store.deviceId != null;
      _setState(
        NotificationPreferenceState(
          phase: authorization == NotificationAuthorizationState.denied
              ? NotificationPreferencePhase.denied
              : registered
                  ? NotificationPreferencePhase.enabled
                  : NotificationPreferencePhase.idle,
        ),
      );
    } on Object catch (error) {
      _setState(
        NotificationPreferenceState(
          phase: NotificationPreferencePhase.failed,
          failure: error,
        ),
      );
    }
  }

  @override
  Future<void> enable() async {
    if (_state.isBusy) return;
    _setState(
      const NotificationPreferenceState(
        phase: NotificationPreferencePhase.enabling,
      ),
    );
    try {
      final authorization = await registration.requestPermissionAndRegister();
      _setState(
        NotificationPreferenceState(
          phase: authorization == NotificationAuthorizationState.authorized ||
                  authorization == NotificationAuthorizationState.provisional
              ? NotificationPreferencePhase.enabled
              : NotificationPreferencePhase.denied,
        ),
      );
    } on Object catch (error) {
      _setState(
        NotificationPreferenceState(
          phase: NotificationPreferencePhase.failed,
          failure: error,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> disable() async {
    if (_state.isBusy) return;
    _setState(
      const NotificationPreferenceState(
        phase: NotificationPreferencePhase.disabling,
      ),
    );
    try {
      await registration.unregisterAndDeleteToken();
      _setState(const NotificationPreferenceState.idle());
    } on Object catch (error) {
      _setState(
        NotificationPreferenceState(
          phase: NotificationPreferencePhase.failed,
          failure: error,
        ),
      );
      rethrow;
    }
  }

  void _setState(NotificationPreferenceState value) {
    _state = value;
    notifyListeners();
  }

  Future<void> disposeAsync() async {
    await registration.dispose();
    dispose();
  }
}

Stream<Uri> mergeIncomingLinks(Stream<Uri> first, Stream<Uri> second) =>
    Stream<Uri>.multi((controller) {
      late final StreamSubscription<Uri> firstSubscription;
      late final StreamSubscription<Uri> secondSubscription;
      var firstDone = false;
      var secondDone = false;

      void closeWhenDone() {
        if (firstDone && secondDone) controller.close();
      }

      firstSubscription = first.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          firstDone = true;
          closeWhenDone();
        },
      );
      secondSubscription = second.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          secondDone = true;
          closeWhenDone();
        },
      );
      controller.onCancel = () async {
        await firstSubscription.cancel();
        await secondSubscription.cancel();
      };
    });
