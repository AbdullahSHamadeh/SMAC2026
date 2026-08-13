import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline Chat keeps a draft and never presents it as sent',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
    )..selectTab(1);
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      'Please save this for later',
    );
    await tester.pump();

    final send = tester.widget<IconButton>(
      find.byKey(const ValueKey('chat.composer.send')),
    );
    expect(send.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('chat.composer.offlineStatus')),
      findsOneWidget,
    );
    expect(controller.state.ui.chatDraft, 'Please save this for later');
    expect(find.text('Please save this for later'), findsOneWidget);
  });

  testWidgets('failed retry restores the retry action and explains recovery',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
      retryAction: () async => throw StateError('still offline'),
    );
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    await tester.tap(find.byKey(const ValueKey('offline.retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.state.surfaceState, SurfaceState.offlineCached);
    expect(controller.state.isRetrying, isFalse);
    expect(controller.state.retryFailed, isTrue);
    expect(find.text("Couldn't reconnect"), findsOneWidget);
    final retry = tester.widget<TextButton>(
      find.byKey(const ValueKey('offline.retry')),
    );
    expect(retry.onPressed, isNotNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  PrototypeScenarioController controller,
) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(FamilyCompassApp(controller: controller));
  await tester.pumpAndSettle();
}
