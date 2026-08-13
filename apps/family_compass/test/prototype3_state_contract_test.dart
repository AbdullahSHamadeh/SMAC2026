import 'package:family_compass/domain/chat_models.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Prototype 3 state contracts', () {
    test('publishing a poll removes the suggestion and is idempotent', () {
      final controller = PrototypeScenarioController();
      addTearDown(controller.dispose);

      expect(controller.state.hasActiveSuggestion, isTrue);
      controller.draftFridayDinner();
      expect(controller.state.hasActiveSuggestion, isTrue);

      controller.sendPoll();
      controller.sendPoll();

      expect(controller.state.plan?.phase, PlanPhase.pollOpen);
      expect(controller.state.hasActiveSuggestion, isFalse);
      expect(
        controller.state.chatItems
            .where((item) => item.kind == ChatItemKind.poll),
        hasLength(1),
      );
    });

    test('check-in transitions are explicit, ordered, and idempotent', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.reassuranceUnknown,
      );
      addTearDown(controller.dispose);

      controller.receiveCheckIn();
      expect(controller.state.checkInState, CheckInState.none);

      controller.requestCheckIn();
      controller.requestCheckIn();
      expect(controller.state.checkInState, CheckInState.requested);
      expect(
        controller.state.chatItems
            .where((item) => item.kind == ChatItemKind.checkInRequest),
        hasLength(1),
      );

      controller.receiveCheckIn();
      controller.receiveCheckIn();
      expect(controller.state.checkInState, CheckInState.responded);
      final responses = controller.state.chatItems
          .where((item) => item.kind == ChatItemKind.checkInResponse)
          .toList();
      expect(responses, hasLength(1));
      expect(responses.single.authorId, 'sara');
    });

    test('a personal reminder has a separate confirmation boundary', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.reassuranceAtSeven,
      );
      addTearDown(controller.dispose);
      final automaticReminderCount =
          controller.state.plan?.reminders.length ?? 0;

      controller.confirmSeparateReminder();
      expect(
        controller.state.separateReminderState,
        SeparateReminderState.none,
      );
      expect(
        controller.state.plan?.reminders,
        hasLength(automaticReminderCount),
      );

      controller.draftSeparateReminder();
      expect(
        controller.state.separateReminderState,
        SeparateReminderState.drafted,
      );
      expect(
        controller.state.plan?.reminders,
        hasLength(automaticReminderCount),
      );

      controller.confirmSeparateReminder();
      controller.confirmSeparateReminder();
      expect(
        controller.state.separateReminderState,
        SeparateReminderState.confirmed,
      );
      expect(
        controller.state.plan?.reminders
            .where((reminder) => reminder.id == 'dessert-reminder'),
        hasLength(1),
      );
    });

    test('a poll nudge requires a reply and remains single-use', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.dinnerPollOpen,
      );
      addTearDown(controller.dispose);

      controller.sendPollNudge();
      expect(controller.state.plan?.nudgeSent, isFalse);
      expect(controller.state.plan?.responses, isNot(contains('sara')));

      controller.submitAbdullahResponse();
      controller.sendPollNudge();
      controller.sendPollNudge();

      expect(controller.state.plan?.nudgeSent, isTrue);
      expect(controller.state.plan?.phase, PlanPhase.readyToConfirm);
      expect(controller.state.plan?.responses.keys, contains('sara'));
      expect(controller.state.plan?.responses, hasLength(4));
    });

    test('notification denial does not change a confirmed plan', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.reassuranceAtSeven,
      );
      addTearDown(controller.dispose);
      final originalPlan = controller.state.plan;

      controller.denyNotifications();

      expect(
        controller.state.notificationPermission,
        NotificationPermissionState.denied,
      );
      expect(controller.state.plan, same(originalPlan));
      expect(controller.state.plan?.phase, PlanPhase.confirmed);
    });

    test('freshness uses the fixed scenario clock, not wall-clock time', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.reassuranceAtSeven,
      );
      addTearDown(controller.dispose);

      final answer = controller.answerForDad();

      expect(answer.hasPermittedInformation, isTrue);
      expect(answer.sourceLabel, 'Shared by Dad');
      expect(answer.freshnessLabel, '3 minutes ago');
    });

    test('AI failure preserves manual plans and chat', () {
      final controller = PrototypeScenarioController(
        initialScenario: PrototypeScenario.aiUnavailable,
      );
      addTearDown(controller.dispose);
      final plan = controller.state.plan;
      final chatItems = controller.state.chatItems;

      final answer = controller.answerForDad();

      expect(answer.hasPermittedInformation, isFalse);
      expect(answer.sourceLabel, 'AI unavailable');
      expect(controller.state.plan, same(plan));
      expect(controller.state.chatItems, same(chatItems));
      expect(controller.state.plan?.phase, PlanPhase.pollOpen);
    });
  });
}
