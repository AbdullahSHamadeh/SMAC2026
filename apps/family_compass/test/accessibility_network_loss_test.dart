import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'visible primary destinations meet automated accessibility checks',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    for (final destination in <Key>[
      const Key('nav.today'),
      const Key('nav.chat'),
      const Key('nav.compass'),
      const Key('nav.together'),
    ]) {
      await tester.tap(find.byKey(destination));
      await tester.pump();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    semantics.dispose();
  });

  testWidgets('Arabic offline Today reflows at 200 percent text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
      retryAction: () async => throw StateError('still offline'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        initialLocale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('عرض معلومات العائلة المحفوظة'), findsOneWidget);
    expect(
        find.byKey(const Key('offline.retry')).hitTestable(), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('offline.retry')))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Arabic offline Chat reflows at 200 percent text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
      retryAction: () async => throw StateError('still offline'),
    )..selectTab(1);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        initialLocale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chat.composer.offlineStatus')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat.offline.retry')).hitTestable(),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('chat.offline.retry'))),
      ),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
