import 'dart:ui' show Tristate;

import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:family_compass/widgets/prototype_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iPhone uses a native Cupertino family tab bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = PrototypeScenarioController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(FamilyCompassApp(controller: controller));
      await tester.pump();

      final tabBar = tester.widget<CupertinoTabBar>(
        find.byKey(const Key('shell.cupertinoTabBar')),
      );
      expect(tabBar.items, hasLength(4));
      expect(
        tabBar.items.map((item) => item.label),
        orderedEquals(<String>['Today', 'Chat', 'Compass', 'Together']),
      );
      expect(find.byType(NavigationBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iPhone tab bar stays native and accessible at maximum text size',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final semantics = tester.ensureSemantics();
    try {
      tester.binding.platformDispatcher.textScaleFactorTestValue = 3.2;
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = PrototypeScenarioController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(FamilyCompassApp(controller: controller));
      await tester.pump();

      final today = find.byKey(const Key('nav.today'));
      final todayNode = tester.semantics.find(today);
      final todaySemantics = todayNode.getSemanticsData();
      expect(MediaQuery.textScalerOf(tester.element(today)).scale(10), 10);
      expect(todaySemantics.label, contains('Today'));
      expect(todaySemantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('nav.together')));
      await tester.pump();
      final togetherNode =
          tester.semantics.find(find.byKey(const Key('nav.together')));
      final togetherSemantics = togetherNode.getSemanticsData();
      expect(togetherSemantics.label, contains('Together'));
      expect(togetherSemantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Together plan reads as a family event instead of a task card',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = PrototypeScenarioController()..selectTab(3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    final plan = find.byKey(const ValueKey('together-dinner-idea'));
    expect(plan, findsOneWidget);
    expect(
      find.descendant(of: plan, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: plan, matching: find.byType(FamilyIdentityStack)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-family-intro')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today uses natural singular copy for one missing reply',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    )..submitAbdullahResponse();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    expect(find.text('Waiting for 1 reply'), findsOneWidget);
    expect(find.text('Waiting for 1 replies'), findsNothing);
  });

  testWidgets('Today summarizes people instead of Compass questions',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = PrototypeScenarioController()
      ..sendHumanMessage('@Mom Dinner is ready')
      ..sendHumanMessage('@Compass What did Dad say?');
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    expect(find.text('@Compass What did Dad say?'), findsNothing);
    expect(find.text('@Mom Dinner is ready'), findsOneWidget);
  });

  testWidgets('debug scenario title retains a 48-pixel long-press target',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    final titleTarget = find.byKey(const Key('shell.debugScenarioPicker'));
    expect(titleTarget, findsOneWidget);
    expect(tester.getSize(titleTarget).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(titleTarget).height, greaterThanOrEqualTo(48));
    final titleSemantics =
        tester.semantics.find(find.text('Today').first).getSemanticsData();
    expect(titleSemantics.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('family identity header reflows at 200 percent text',
      (tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.tap(find.byKey(const Key('family.menu')));
    await tester.pumpAndSettle();

    expect(find.text('Hamadeh Family'), findsOneWidget);
    expect(find.textContaining('4 family members'), findsOneWidget);
    expect(find.byType(FamilyIdentityStack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
