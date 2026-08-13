import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/firebase/firebase_notifications.dart';
import 'package:family_compass/firebase/firebase_phone_session.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings enables notifications only after an explicit tap',
      (tester) async {
    _phoneViewport(tester);
    final notifications = _FakeNotifications();
    final scenario = PrototypeScenarioController();
    addTearDown(scenario.dispose);
    await tester.pumpWidget(
      FamilyCompassApp(
        controller: scenario,
        notificationPreferences: notifications,
      ),
    );

    expect(notifications.enableCount, 0);
    await tester.tap(find.byKey(const Key('family.menu')));
    await tester.pumpAndSettle();
    expect(notifications.loadCount, 1);
    expect(notifications.enableCount, 0);

    await tester.ensureVisible(find.byKey(const Key('family.notifications')));
    await tester.tap(find.byKey(const Key('family.notifications')));
    await tester.pumpAndSettle();
    expect(notifications.enableCount, 1);
    expect(notifications.state.isEnabled, isTrue);
  });

  testWidgets('sign out unregisters notifications before the auth session',
      (tester) async {
    _phoneViewport(tester);
    final order = <String>[];
    final notifications = _FakeNotifications(order: order);
    final phone = _FakePhoneSession(order);
    final scenario = PrototypeScenarioController();
    addTearDown(scenario.dispose);
    await tester.pumpWidget(
      FamilyCompassApp(
        controller: scenario,
        notificationPreferences: notifications,
        phoneSession: phone,
      ),
    );

    await tester.tap(find.byKey(const Key('family.menu')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('family.signOut')));
    await tester.tap(find.byKey(const Key('family.signOut')));
    await tester.pumpAndSettle();

    expect(order, ['notifications-disabled', 'firebase-signed-out']);
    expect(find.byKey(const Key('onboarding.continue')), findsOneWidget);
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

class _FakeNotifications extends ChangeNotifier
    implements NotificationPreferenceController {
  _FakeNotifications({this.order});

  final List<String>? order;
  NotificationPreferenceState _state = const NotificationPreferenceState.idle();
  int loadCount = 0;
  int enableCount = 0;

  @override
  NotificationPreferenceState get state => _state;

  @override
  Future<void> loadStatus() async {
    loadCount += 1;
  }

  @override
  Future<void> enable() async {
    enableCount += 1;
    _state = const NotificationPreferenceState(
      phase: NotificationPreferencePhase.enabled,
    );
    notifyListeners();
  }

  @override
  Future<void> disable() async {
    order?.add('notifications-disabled');
    _state = const NotificationPreferenceState.idle();
    notifyListeners();
  }
}

class _FakePhoneSession extends ChangeNotifier
    implements PhoneOnboardingController {
  _FakePhoneSession(this.order);

  final List<String> order;

  @override
  FirebasePhoneSessionState get state =>
      const FirebasePhoneSessionState.signedOut();

  @override
  Future<void> signOut({Future<void> Function()? beforeFirebaseSignOut}) async {
    await beforeFirebaseSignOut?.call();
    order.add('firebase-signed-out');
  }

  @override
  Future<void> sendCode(String internationalPhoneNumber) =>
      throw UnimplementedError();

  @override
  Future<void> resendCode() => throw UnimplementedError();

  @override
  Future<void> verifyCode(String smsCode) => throw UnimplementedError();

  @override
  Future<AppSession> registerBackendAccount(String displayName) =>
      throw UnimplementedError();
}
