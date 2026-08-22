import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan presentation follows real candidates and responses', () {
    final plan = FamilyPlan(
      id: 'reunion',
      title: 'Family reunion',
      description: 'Lunch at home',
      coordinatorId: 'one',
      participantIds: const ['one', 'two', 'three'],
      candidateTimes: [
        CandidateTime(id: 'morning', startsAt: DateTime(2031, 2, 12, 10)),
        CandidateTime(id: 'lunch', startsAt: DateTime(2031, 2, 12, 13, 15)),
      ],
      phase: PlanPhase.readyToConfirm,
      decisionDeadline: DateTime(2031, 2, 10, 18),
      responses: const {
        'one': PollResponse(
          memberId: 'one',
          candidateId: 'lunch',
          choice: RsvpChoice.going,
        ),
        'two': PollResponse(
          memberId: 'two',
          candidateId: 'lunch',
          choice: RsvpChoice.maybe,
        ),
        'three': PollResponse(
          memberId: 'three',
          candidateId: 'morning',
          choice: RsvpChoice.cannotMakeIt,
        ),
      },
    );

    expect(plan.displayCandidate()?.id, 'lunch');
    expect(plan.displayCandidate(memberId: 'three')?.id, 'morning');
    expect(plan.attendingCount, 2);
    expect(
      plan.copyWith(confirmedCandidateId: 'morning').displayCandidate()?.id,
      'morning',
    );
  });

  testWidgets('Chat opens on the newest poll action at 200 percent text',
      (tester) async {
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
      initialScenario: PrototypeScenario.dinnerPollOpen,
    )..selectTab(1);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('poll.fridayDinner.respond1930')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape Together keeps the active action first',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(844, 390);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    )..selectTab(3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    final activeActions = find.text('Respond').hitTestable();
    expect(activeActions, findsWidgets);
    expect(tester.getTopLeft(activeActions.first).dx, lessThan(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone poll omits the screen-long thread seam',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    )..selectTab(3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('together-open-poll')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('together-thread-segment')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('poll-detail-folio')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opportunity language stays undecided across Today and Chat',
      (tester) async {
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

    expect(find.text('2 possible times'), findsOneWidget);
    expect(find.textContaining('7:00 PM · Fri 7:30 PM'), findsOneWidget);
    expect(find.text('Review idea'), findsOneWidget);
    expect(find.text('From family chat'), findsNothing);
    expect(find.text('Nothing has been sent yet.'), findsNothing);
    expect(find.text('4 family members invited'), findsNothing);
    expect(find.text('View plan'), findsNothing);

    await tester.tap(find.byKey(const Key('nav.chat')));
    await tester.pump();

    expect(find.byKey(const ValueKey('chat.turnIntoPlan')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat.composer.compassShortcut')),
      findsNothing,
    );
  });

  testWidgets('landscape Today clears horizontal device cutouts',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(844, 390)
      ..padding = const FakeViewPadding(left: 59, right: 59);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FamilyCompassApp(controller: controller));
    await tester.pump();

    final folioBounds = tester.getRect(find.byKey(const Key('today.next')));
    expect(folioBounds.left, greaterThanOrEqualTo(59));
    expect(folioBounds.right, lessThanOrEqualTo(844 - 59));
    final planInChat = find.text('Plan in Chat');
    expect(planInChat, findsOneWidget);
    expect(tester.getTopLeft(planInChat).dx, greaterThanOrEqualTo(59));
    expect(tester.getTopLeft(planInChat).dx, lessThan(844 - 59));
    expect(tester.takeException(), isNull);
  });
}
