import 'dart:async';

import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/firebase/firebase_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification registration stores the Firebase Installation ID',
      () async {
    final installations = _FakeInstallations('installation-identifier-0001');
    final devices = _FakeDevices();
    final store = MemoryDeviceRegistrationStore();
    final coordinator = FirebaseDeviceRegistrationCoordinator(
      notifications: FirebaseNotificationCoordinator(
        messaging: _FakeMessaging(),
        installations: installations,
      ),
      devices: devices,
      store: store,
    );

    await coordinator.registerCurrentInstallation();

    expect(devices.destinations, ['installation-identifier-0001']);
    expect(store.token, 'installation-identifier-0001');
    await coordinator.dispose();
    await installations.dispose();
  });

  test('APNs readiness retries until the asynchronous token arrives', () async {
    final installations = _FakeInstallations('installation-identifier-0001');
    final messaging = _FakeMessaging(apnsTokens: <String?>[null, '', 'apns']);
    final delays = <Duration>[];
    final notifications = FirebaseNotificationCoordinator(
      messaging: messaging,
      installations: installations,
    );

    final token = await notifications.waitForApnsToken(
      maxAttempts: 5,
      retryDelay: const Duration(milliseconds: 10),
      delay: (duration) async => delays.add(duration),
    );

    expect(token, 'apns');
    expect(messaging.apnsTokenRequests, 3);
    expect(delays, const <Duration>[
      Duration(milliseconds: 10),
      Duration(milliseconds: 10),
    ]);
    await notifications.dispose();
    await installations.dispose();
  });

  test('APNs readiness stops after its bounded retry budget', () async {
    final installations = _FakeInstallations('installation-identifier-0001');
    final messaging = _FakeMessaging(apnsTokens: const <String?>[null]);
    var delayCount = 0;
    final notifications = FirebaseNotificationCoordinator(
      messaging: messaging,
      installations: installations,
    );

    await expectLater(
      notifications.waitForApnsToken(
        maxAttempts: 3,
        retryDelay: Duration.zero,
        delay: (_) async {
          delayCount += 1;
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(messaging.apnsTokenRequests, 3);
    expect(delayCount, 2);
    await notifications.dispose();
    await installations.dispose();
  });
}

class _FakeInstallations implements InstallationIdentitySource {
  _FakeInstallations(this.id);

  final String id;
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  @override
  Future<String> getId() async => id;

  @override
  Stream<String> get onIdChange => _changes.stream;

  Future<void> dispose() => _changes.close();
}

class _FakeMessaging extends Fake implements FirebaseMessaging {
  _FakeMessaging({this.apnsTokens = const <String?>[null]});

  final List<String?> apnsTokens;
  int apnsTokenRequests = 0;

  @override
  Future<String?> getAPNSToken() async {
    final index = apnsTokenRequests < apnsTokens.length
        ? apnsTokenRequests
        : apnsTokens.length - 1;
    apnsTokenRequests += 1;
    return apnsTokens[index];
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async =>
      'deprecated-registration-token-used-only-for-ready-check';
}

class _FakeDevices implements DeviceRepository {
  final List<String> destinations = [];
  final StreamController<RepositoryStatus> _status =
      StreamController<RepositoryStatus>.broadcast();

  @override
  Stream<RepositoryStatus> get status => _status.stream;

  @override
  Future<List<DeviceRegistration>> listDevices() async => const [];

  @override
  Future<DeviceRegistration> register({
    required String token,
    required DevicePlatform platform,
  }) async {
    destinations.add(token);
    return DeviceRegistration(
      id: '10000000-0000-4000-8000-000000000001',
      platform: platform,
      enabled: true,
      createdAt: DateTime.utc(2026),
    );
  }

  @override
  Future<void> unregister(String deviceId) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> retryPending() async {}
}
