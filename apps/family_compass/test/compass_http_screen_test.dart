import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/data/http_compass_repository.dart';
import 'package:family_compass/domain/compass_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Compass shows a normal model answer', (tester) async {
    final controller = PrototypeScenarioController()..selectTab(2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        compassRepository: _ScriptedRepository(<Object>[
          const CompassAnswer(
            text: 'Photosynthesis lets plants store energy from light.',
            sourceLabel: 'lm-studio · general knowledge',
            freshnessLabel: '',
            hasPermittedInformation: false,
            isGeneralKnowledge: true,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('compass.composer.input')),
      'What is photosynthesis?',
    );
    await tester.tap(find.byKey(const ValueKey('compass.composer.send')));
    await tester.pumpAndSettle();

    expect(find.text('General answer'), findsOneWidget);
    expect(
      find.text('Photosynthesis lets plants store energy from light.'),
      findsOneWidget,
    );
    expect(find.text('No permitted answer'), findsNothing);
  });

  testWidgets('Compass exposes a retry after a provider error', (tester) async {
    final controller = PrototypeScenarioController()..selectTab(2);
    addTearDown(controller.dispose);
    final repository = _ScriptedRepository(<Object>[
      const CompassConnectionException('LM Studio is not responding.'),
      const CompassAnswer(
        text: 'The second attempt worked.',
        sourceLabel: 'lm-studio · general knowledge',
        freshnessLabel: '',
        hasPermittedInformation: false,
        isGeneralKnowledge: true,
      ),
    ]);
    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        compassRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('compass.composer.input')),
      'Hello',
    );
    await tester.tap(find.byKey(const ValueKey('compass.composer.send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compass.answer.error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compass.answer.retry')));
    await tester.pumpAndSettle();
    expect(find.text('The second attempt worked.'), findsOneWidget);
    expect(repository.questions, <String>['Hello', 'Hello']);
  });

  testWidgets('live Compass renders returned evidence and confirms actions',
      (tester) async {
    final controller = PrototypeScenarioController()..selectTab(2);
    addTearDown(controller.dispose);
    final updatedAt =
        DateTime.now().toUtc().subtract(const Duration(minutes: 4));
    final repository = _ScriptedRepository(<Object>[
      CompassAnswer(
        text: 'Sara shared that she is home until 8:00 PM.',
        sourceLabel: 'Sara shared status',
        freshnessLabel: '4 minutes ago',
        hasPermittedInformation: true,
        citations: <CompassCitation>[
          CompassCitation(
            sourceId: 'status-sara',
            subjectUserId: 'sara',
            sourceType: CompassFactSource.memberStatus,
            sourceLabel: 'Sara shared status',
            audience: CompassFactAudience.selectedPeople,
            freshness: CompassFactFreshness.current,
            updatedAt: updatedAt,
            expiresAt: updatedAt.add(const Duration(hours: 1)),
            text: 'Home until 8:00 PM.',
          ),
        ],
        actions: const <CompassAction>[
          CompassAction(
            kind: CompassActionKind.startPlan,
            label: 'Start a family plan',
            requiresConfirmation: true,
          ),
        ],
        uncertainty: CompassUncertainty.low,
      ),
    ]);
    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        compassRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('compass.composer.input')),
      'What did Sara share?',
    );
    await tester.tap(find.byKey(const ValueKey('compass.composer.send')));
    await tester.pumpAndSettle();

    expect(find.text('Sara shared status'), findsOneWidget);
    expect(find.text('Shared with selected people'), findsOneWidget);
    expect(find.textContaining('Low uncertainty'), findsOneWidget);
    expect(find.byKey(const ValueKey('compass.markOutdated')), findsNothing);
    expect(find.byKey(const ValueKey('compass.reminder.draftAction')),
        findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('compass.liveAction.startPlan')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review this action'), findsOneWidget);
    expect(controller.state.ui.selectedTab, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(controller.state.ui.selectedTab, 3);
  });
}

class _ScriptedRepository implements CompassRepository {
  _ScriptedRepository(this.results);

  final List<Object> results;
  final List<String> questions = <String>[];

  @override
  Future<CompassAnswer> ask({
    required String conversationId,
    required String question,
    CompassVisibility visibility = CompassVisibility.private,
  }) async {
    questions.add(question);
    final result = results.removeAt(0);
    if (result is CompassConnectionException) throw result;
    return result as CompassAnswer;
  }
}
