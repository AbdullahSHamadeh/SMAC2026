import 'package:family_compass/app/app_preferences.dart';
import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/features/family/family_invitation_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phonePortrait = Size(390, 844);

void main() {
  test('saved preferences are restored by a new store instance', () async {
    SharedPreferences.setMockInitialValues({});
    final firstStore = await SharedPreferencesAppPreferencesStore.create();
    await firstStore.saveLocale(const Locale('ar'));
    await firstStore.saveThemeMode(ThemeMode.dark);

    final reconstructedStore =
        await SharedPreferencesAppPreferencesStore.create();
    expect(reconstructedStore.value.locale.languageCode, 'ar');
    expect(reconstructedStore.value.themeMode, ThemeMode.dark);
  });

  testWidgets(
    'language and appearance update the open route and survive reconstruction',
    (tester) async {
      final preferences = MemoryAppPreferencesStore();
      final controller = PrototypeScenarioController();
      addTearDown(controller.dispose);

      await _pumpApp(
        tester,
        controller: controller,
        preferencesStore: preferences,
      );
      await _tapAndPump(tester, find.byKey(const Key('family.menu')));

      await _tapAndPump(
        tester,
        find.byKey(const Key('family.language.arabic')),
      );

      expect(find.text('العائلة'), findsOneWidget);
      expect(find.text('الأفراد'), findsOneWidget);
      expect(find.text('إعداداتك'), findsOneWidget);
      expect(find.text('المنسق'), findsOneWidget);
      expect(find.text('الأب'), findsOneWidget);
      expect(find.text('الأم'), findsOneWidget);
      expect(find.text('الأخت'), findsOneWidget);
      expect(find.text('Family members'), findsNothing);
      expect(find.text('Privacy and preferences'), findsNothing);
      expect(find.text('Coordinator'), findsNothing);
      expect(find.text('Father'), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('family.language'))),
        ),
        TextDirection.rtl,
      );
      expect(preferences.value.locale.languageCode, 'ar');

      await _tapAndPump(tester, find.byKey(const Key('family.darkMode')));
      expect(preferences.value.themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byKey(const Key('family.darkMode'))))
            .brightness,
        Brightness.dark,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpApp(
        tester,
        controller: controller,
        preferencesStore: preferences,
      );

      expect(find.text('اليوم'), findsNWidgets(2));
      final appContext = tester.element(find.byKey(const Key('nav.today')));
      expect(Directionality.of(appContext), TextDirection.rtl);
      expect(Theme.of(appContext).brightness, Brightness.dark);
    },
  );

  testWidgets(
    'invitation validates, masks the entered phone, and keeps cancellation',
    (tester) async {
      final now = DateTime(2026, 8, 13, 12);
      final invitations = FamilyInvitationController.withDemoInvitation(
        clock: () => now,
      );
      final controller = PrototypeScenarioController();
      addTearDown(invitations.dispose);
      addTearDown(controller.dispose);

      await _pumpApp(
        tester,
        controller: controller,
        invitationController: invitations,
      );
      await _tapAndPump(tester, find.byKey(const Key('family.menu')));

      expect(invitations.pendingInvitation?.phoneNumber, '+971509876543');
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('family.invitation.maskedPhone')),
            )
            .data,
        '+971 50 ••• •543 · expires in 3 days',
      );

      await _tapAndPump(
        tester,
        find.byKey(const Key('family.invitation.cancel')),
      );
      expect(invitations.pendingInvitation, isNull);
      expect(
        find.byKey(const Key('family.invitation.maskedPhone')),
        findsNothing,
      );

      await _tapAndPump(tester, find.byType(BackButton));
      await _tapAndPump(tester, find.byKey(const Key('family.menu')));
      expect(find.text('Invitation pending'), findsNothing);

      await _tapAndPump(tester, find.byKey(const Key('family.invite')));
      await tester.enterText(
        find.byKey(const Key('family.invite.phone')),
        'not a phone',
      );
      await _tapAndPump(
        tester,
        find.byKey(const Key('family.invite.prepare')),
      );

      expect(
        find.text(
          'Enter a valid international number with 8 to 15 digits.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send invitation'), findsOneWidget);
      expect(invitations.pendingInvitation, isNull);

      await tester.enterText(
        find.byKey(const Key('family.invite.phone')),
        '+971 55 123 4567',
      );
      await _tapAndPump(
        tester,
        find.byKey(const Key('family.invite.prepare')),
      );

      expect(invitations.pendingInvitation?.phoneNumber, '+971551234567');
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('family.invitation.maskedPhone')),
            )
            .data,
        '+971 55 ••• •567 · expires in 3 days',
      );

      await _tapAndPump(tester, find.byType(BackButton));
      await _tapAndPump(tester, find.byKey(const Key('family.menu')));
      expect(
        find.byKey(const Key('family.invitation.maskedPhone')),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
  AppPreferencesStore? preferencesStore,
  FamilyInvitationController? invitationController,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phonePortrait;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    FamilyCompassApp(
      controller: controller,
      preferencesStore: preferencesStore,
      invitationController: invitationController,
    ),
  );
  await tester.pump();
}

Future<void> _tapAndPump(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
