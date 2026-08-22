import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);

void main() {
  testWidgets('overview shows an opportunity once under Ideas to revisit',
      (tester) async {
    final controller = PrototypeScenarioController();
    await _pumpTogether(tester, controller);

    expect(
      find.byKey(const ValueKey('together-ideas-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-dinner-idea')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-needs-you-section')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('together-waiting-section')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('together-next-section')), findsNothing);
    expect(find.byKey(const ValueKey('together-decide-section')), findsNothing);
    expect(find.byKey(const ValueKey('together-later-section')), findsNothing);
  });

  testWidgets('overview supports Arabic RTL and 200 percent text',
      (tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = PrototypeScenarioController();
    await _pumpTogether(tester, controller, locale: const Locale('ar'));

    final heading = find.byKey(const ValueKey('together-ideas-section'));
    expect(heading, findsOneWidget);
    expect(Directionality.of(tester.element(heading)), TextDirection.rtl);
    expect(find.text('أفكار للعودة إليها'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview keeps its hierarchy in the dark Sunday Table theme',
      (tester) async {
    final controller = PrototypeScenarioController();
    await _pumpTogether(tester, controller, themeMode: ThemeMode.dark);

    final heading = find.byKey(const ValueKey('together-ideas-section'));
    expect(heading, findsOneWidget);
    expect(
      Theme.of(tester.element(heading)).colorScheme.brightness,
      Brightness.dark,
    );
    expect(
      find.text('Find the next time everyone can be together.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open poll moves from Needs you to Waiting for family',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    await _pumpTogether(tester, controller);

    expect(
      find.byKey(const ValueKey('together-needs-you-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-open-poll')),
      findsOneWidget,
    );

    controller.submitAbdullahResponse();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('together-needs-you-section')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('together-waiting-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-open-poll')),
      findsOneWidget,
    );
  });

  testWidgets('a confirmed plan moves once from Coming up to Past moments',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    await _pumpTogether(tester, controller);

    expect(
      find.byKey(const ValueKey('together-coming-up-section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('together-next-plan')), findsOneWidget);

    controller.completeGathering();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('together-coming-up-section')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('together-past-moments-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-completed-plan')),
      findsOneWidget,
    );
  });

  testWidgets('Past moments can start the same plan again', (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    )..completeGathering();
    await _pumpTogether(tester, controller);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('together-completed-plan')),
    );

    expect(controller.state.plan?.phase, PlanPhase.draft);
    expect(find.byKey(const ValueKey('plan-builder')), findsOneWidget);
  });

  testWidgets('system Back guards an unsent plan-builder change',
      (tester) async {
    final controller = PrototypeScenarioController();
    await _pumpTogether(tester, controller);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('together-dinner-idea')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('plan-builder-next')),
    );
    expect(controller.state.ui.hasUnsavedPlanChanges, isTrue);
    expect(
      find.byKey(const ValueKey('plan-builder-step-1')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave this draft?'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-builder')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('keep-editing-plan-draft')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-builder')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discard-plan-draft')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-builder')), findsNothing);
    expect(
      find.byKey(const ValueKey('together-needs-you-section')),
      findsOneWidget,
    );
    expect(controller.state.plan?.phase, PlanPhase.draft);
  });

  testWidgets('system Back returns a clean poll to Together overview',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    await _pumpTogether(tester, controller);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('together-open-poll')),
    );
    expect(find.byKey(const ValueKey('poll-detail')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('poll-detail')), findsNothing);
    expect(
      find.byKey(const ValueKey('together-needs-you-section')),
      findsOneWidget,
    );
    expect(find.text('Leave this draft?'), findsNothing);
    expect(controller.state.plan?.phase, PlanPhase.pollOpen);
  });

  testWidgets('system Back returns a confirmed plan to Together overview',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    await _pumpTogether(tester, controller);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('together-next-plan')),
    );
    expect(find.byKey(const ValueKey('confirmed-plan')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('confirmed-plan')), findsNothing);
    expect(
      find.byKey(const ValueKey('together-coming-up-section')),
      findsOneWidget,
    );
    expect(find.text('Leave this draft?'), findsNothing);
    expect(controller.state.plan?.phase, PlanPhase.confirmed);
  });
}

Future<void> _pumpTogether(
  WidgetTester tester,
  PrototypeScenarioController controller, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phonePortrait;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    controller.dispose();
  });

  controller.selectTab(3);
  await tester.pumpWidget(
    FamilyCompassApp(
      controller: controller,
      initialLocale: locale,
      initialThemeMode: themeMode,
    ),
  );
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
