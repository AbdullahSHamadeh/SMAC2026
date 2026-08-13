import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);

void main() {
  testWidgets('primary navigation keeps labeled 48-pixel tap targets in Arabic',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await _pumpApp(
      tester,
      controller: controller,
      locale: const Locale('ar'),
    );

    for (final entry in <Key, String>{
      const Key('nav.today'): 'اليوم',
      const Key('nav.chat'): 'الدردشة',
      const Key('nav.compass'): 'البوصلة',
      const Key('nav.together'): 'معًا',
    }.entries) {
      final finder = find.byKey(entry.key);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48), reason: entry.value);
      expect(size.height, greaterThanOrEqualTo(48), reason: entry.value);
      final semantics = tester.semantics.find(finder).getSemanticsData();
      expect(semantics.label, contains(entry.value));
    }
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('Arabic shell localizes the profile action and title hint',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await _pumpApp(
      tester,
      controller: controller,
      locale: const Locale('ar'),
    );

    expect(find.byTooltip('العائلة'), findsOneWidget);
    expect(
      find.semantics.byLabel(RegExp('العائلة')),
      findsAtLeastNWidgets(1),
    );
    final titleSemantics =
        tester.semantics.find(find.text('اليوم').first).getSemanticsData();
    expect(titleSemantics.hint, 'اضغط مطولًا لاختيار حالة تجريبية');
    expect(
      find.semantics.byLabel(RegExp('Long press|Family')),
      findsNothing,
    );

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('اليوم'),
    );
    await tester.longPress(appBarTitle);
    await tester.pumpAndSettle();
    expect(find.text('الحالات التجريبية'), findsOneWidget);
    expect(find.text('فرصة لعشاء عائلي'), findsOneWidget);
    expect(find.text('Demo states'), findsNothing);
    expect(find.text('Dinner opportunity'), findsNothing);
    semanticsHandle.dispose();
  });

  testWidgets('grounded Compass answer announces a live evidence region',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    )..selectTab(2);
    addTearDown(controller.dispose);

    await _pumpApp(tester, controller: controller);
    await tester.tap(
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    await tester.pumpAndSettle();

    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.liveRegion == true);
    expect(liveRegions, isNotEmpty);
    expect(
      find.semantics.byLabel(RegExp('Shared by Dad')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.semantics.byLabel(RegExp('3 minutes ago')),
      findsAtLeastNWidgets(1),
    );
    semanticsHandle.dispose();
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
  Locale locale = const Locale('en'),
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
      initialLocale: locale,
    ),
  );
  await tester.pumpAndSettle();
}
