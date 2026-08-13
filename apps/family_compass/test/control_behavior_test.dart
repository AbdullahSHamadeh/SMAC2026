import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/features/onboarding/onboarding_screen.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(390, 844);

void main() {
  testWidgets('onboarding blocks invalid verification details', (tester) async {
    await _pumpOnboarding(tester);
    await _tap(tester, find.byKey(const Key('onboarding.continue')));

    await tester.enterText(find.byKey(const Key('onboarding.phone')), '12');
    await _tap(tester, find.byKey(const Key('onboarding.continue')));

    expect(find.byKey(const Key('onboarding.validation')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.phone')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 50 123 4567',
    );
    await tester.enterText(find.byKey(const Key('onboarding.code')), '00');
    await _tap(tester, find.byKey(const Key('onboarding.continue')));

    expect(find.textContaining('4-digit'), findsOneWidget);
    expect(find.byKey(const Key('onboarding.code')), findsOneWidget);
  });

  testWidgets('onboarding returns choices and the prepared invitation',
      (tester) async {
    OnboardingResult? result;
    await _pumpOnboarding(tester, onCompleted: (value) => result = value);

    await _tap(tester, find.byKey(const Key('onboarding.continue')));
    await _tap(tester, find.byKey(const Key('onboarding.continue')));
    await _tap(tester, find.byKey(const Key('onboarding.continue')));

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Abdullah H');
    await tester.enterText(textFields.at(1), '+971 55 000 7788');
    await _tap(tester, find.byKey(const Key('onboarding.prepareInvite')));

    expect(
      find.byKey(const Key('onboarding.preparedInvite')),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const Key('onboarding.continue')));

    expect(result?.name, 'Abdullah H');
    expect(result?.createsFamily, isTrue);
    expect(result?.preparedInvitationPhone, '+971 55 000 7788');
  });

  testWidgets('poll can save and select a valid suggested time',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    addTearDown(controller.dispose);
    controller.selectTab(3);
    await _pump(
      tester,
      FamilyCompassApp(controller: controller),
    );

    await _tap(tester, find.byKey(const ValueKey('together-open-poll')));
    await _tap(tester, find.byKey(const ValueKey('rsvp-maybe')));
    await _tap(tester, find.byKey(const ValueKey('suggest-another-time')));
    await tester.enterText(
      find.byKey(const ValueKey('suggested-time-input')),
      '20:15',
    );
    await _tap(tester, find.byKey(const ValueKey('save-suggested-time')));

    expect(
      controller.state.plan?.candidateTimes.any((candidate) =>
          candidate.startsAt.hour == 20 && candidate.startsAt.minute == 15),
      isTrue,
    );
    expect(find.textContaining('8:15'), findsOneWidget);
  });

  testWidgets('Plan this again creates a draft and opens its builder',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(controller.dispose);
    controller.completeGathering();
    await _pump(tester, FamilyCompassApp(controller: controller));

    await _tap(tester, find.byKey(const Key('nav.together')));
    await _tap(
      tester,
      find.byKey(const ValueKey('together-completed-plan')),
    );

    expect(controller.state.plan?.phase.name, 'draft');
    expect(controller.state.ui.selectedTab, 3);
    expect(find.byKey(const ValueKey('plan-builder')), findsOneWidget);
  });

  testWidgets('chat Send writes one message to shared prototype state',
      (tester) async {
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pump(tester, FamilyCompassApp(controller: controller));

    await _tap(tester, find.byKey(const Key('nav.chat')));
    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      'I will be home at 8',
    );
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('chat.composer.send')));

    expect(
      controller.state.chatItems
          .where((item) => item.text == 'I will be home at 8'),
      hasLength(1),
    );
    expect(find.text('I will be home at 8'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('nav.today')));
    await _tap(tester, find.byKey(const Key('nav.chat')));
    expect(find.text('I will be home at 8'), findsOneWidget);
  });
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  ValueChanged<OnboardingResult>? onCompleted,
}) async {
  await _pump(
    tester,
    MaterialApp(
      home: OnboardingScreen(
        onComplete: () {},
        onCompleted: onCompleted,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phone;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(child);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
