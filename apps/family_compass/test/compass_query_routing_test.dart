import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unsupported Compass question abstains instead of using Dad data',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    )..selectTab(2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text("Ask about Dad's shared update"), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('compass.composer.input')),
      'Where is Mom?',
    );
    await tester.tap(find.byKey(const ValueKey('compass.composer.send')));
    await tester.pumpAndSettle();

    expect(find.text('Where is Mom?'), findsOneWidget);
    expect(find.text('No permitted answer'), findsOneWidget);
    expect(
      find.text('No permitted source is available for that question.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Dad shared that he is leaving work'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('compass.requestCheckIn')),
      findsNothing,
    );
  });
}
