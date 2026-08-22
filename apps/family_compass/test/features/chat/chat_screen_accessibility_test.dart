import 'package:family_compass/design_system/design_system.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/features/chat/chat_screen.dart';
import 'package:family_compass/l10n/l10n.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);

void main() {
  testWidgets(
    'Turn into a plan remains a semantic button and can be activated',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final controller = PrototypeScenarioController();
      addTearDown(controller.dispose);

      await _pumpChat(tester, controller: controller);

      expect(
        find.semantics.byLabel(
          RegExp(
            r'^Compass · Family visible\..*No action taken$',
          ),
        ),
        findsOneWidget,
      );

      final actionFinder = find.byKey(const ValueKey('chat.turnIntoPlan'));
      await tester.ensureVisible(actionFinder);
      await tester.pump();

      final node = tester.semantics.find(actionFinder);
      final data = node.getSemanticsData();
      expect(data.label, contains('Turn into a plan'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(
        find.semantics.byLabel('Turn into a plan'),
      );
      await tester.pump();

      expect(controller.state.plan?.phase, PlanPhase.draft);
      expect(
        find.byKey(const ValueKey('chat.reviewPlan')),
        findsOneWidget,
      );
      semanticsHandle.dispose();
    },
  );

  testWidgets(
    'Review plan remains a semantic button and opens the review sheet',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final controller = PrototypeScenarioController()..draftFridayDinner();
      addTearDown(controller.dispose);

      await _pumpChat(tester, controller: controller);

      expect(
        find.semantics.byLabel(
          RegExp(
            r'^Compass draft · Family visible\..*Nothing sent$',
          ),
        ),
        findsOneWidget,
      );

      final actionFinder = find.byKey(const ValueKey('chat.reviewPlan'));
      await tester.ensureVisible(actionFinder);
      await tester.pump();

      final node = tester.semantics.find(actionFinder);
      final data = node.getSemanticsData();
      expect(data.label, contains('Review plan'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(
        find.semantics.byLabel('Review plan'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chat.planReview')),
        findsOneWidget,
      );
      expect(controller.state.plan?.phase, PlanPhase.draft);
      semanticsHandle.dispose();
    },
  );
}

Future<void> _pumpChat(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phonePortrait;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: FamilyCompassTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChatScreen(controller: controller)),
    ),
  );
  await tester.pump();
}
