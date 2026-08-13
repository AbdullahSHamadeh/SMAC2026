import 'dart:async';

import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('incoming message link selects family Chat', (tester) async {
    final links = StreamController<Uri>();
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    addTearDown(links.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        incomingLinks: links.stream,
      ),
    );

    links.add(
      Uri.parse(
        'familycompass://families/demo-family/'
        'messages/opening-mom',
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.state.ui.selectedTab, 1);
    expect(
      find.byKey(const ValueKey<String>('screen.chat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat.linked.opening-mom')),
      findsOneWidget,
    );
  });

  testWidgets('incoming plan link selects Together', (tester) async {
    final links = StreamController<Uri>();
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    addTearDown(links.close);
    addTearDown(controller.dispose);
    final planId = controller.state.plan!.id;

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        incomingLinks: links.stream,
      ),
    );

    links.add(
      Uri.parse(
        'familycompass://families/demo-family/'
        'plans/$planId',
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.state.ui.selectedTab, 3);
    expect(controller.state.ui.selectedPlanId, planId);
    expect(
      find.byKey(const ValueKey<String>('poll-detail')),
      findsOneWidget,
    );
  });

  testWidgets('incoming check-in link selects Today', (tester) async {
    final links = StreamController<Uri>();
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    addTearDown(links.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        incomingLinks: links.stream,
      ),
    );
    controller.selectTab(2);
    await tester.pump();

    links.add(
      Uri.parse(
        'familycompass://families/demo-family/'
        'check-ins/99999999-9999-4999-8999-999999999999',
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.state.ui.selectedTab, 0);
    expect(
      find.byKey(const PageStorageKey<String>('screen.today')),
      findsOneWidget,
    );
  });
}
