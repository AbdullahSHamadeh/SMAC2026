import 'dart:async';

import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/domain/family_models.dart';
import 'package:family_compass/domain/plan_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);
const _phoneLandscape = Size(844, 390);
const _tabletPortrait = Size(1024, 1366);

void main() {
  group('Family Compass shell', () {
    testWidgets('has exactly four destinations and no Journey tab',
        (tester) async {
      final controller = _controller();
      await _pumpApp(tester, controller: controller);

      final destinations = tester
          .widgetList<NavigationDestination>(
            find.byType(NavigationDestination),
          )
          .toList();

      expect(destinations, hasLength(4));
      expect(
        destinations.map((destination) => destination.label),
        orderedEquals(<String>['Today', 'Chat', 'Compass', 'Together']),
      );
      expect(find.byKey(const Key('nav.today')), findsOneWidget);
      expect(find.byKey(const Key('nav.chat')), findsOneWidget);
      expect(find.byKey(const Key('nav.compass')), findsOneWidget);
      expect(find.byKey(const Key('nav.together')), findsOneWidget);
      expect(
        find.textContaining(RegExp('journey', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('switches among all four tabs', (tester) async {
      final controller = _controller();
      await _pumpApp(tester, controller: controller);

      expect(controller.state.ui.selectedTab, 0);

      await _tapAndPump(tester, find.byKey(const Key('nav.chat')));
      expect(controller.state.ui.selectedTab, 1);
      expect(
        find.byKey(const ValueKey('screen.chat')).hitTestable(),
        findsOneWidget,
      );

      await _tapAndPump(tester, find.byKey(const Key('nav.compass')));
      expect(controller.state.ui.selectedTab, 2);
      expect(
        find.byKey(const ValueKey('screen.compass')).hitTestable(),
        findsOneWidget,
      );

      await _tapAndPump(tester, find.byKey(const Key('nav.together')));
      expect(controller.state.ui.selectedTab, 3);

      await _tapAndPump(tester, find.byKey(const Key('nav.today')));
      expect(controller.state.ui.selectedTab, 0);
    });
  });

  group('Dinner gathering scenario', () {
    testWidgets(
        'moves from Chat suggestion through poll, response, nudge, and confirmation',
        (tester) async {
      final controller = _controller();
      await _pumpApp(tester, controller: controller);
      await _tapAndPump(tester, find.byKey(const Key('nav.chat')));

      expect(controller.state.plan?.phase, PlanPhase.opportunity);
      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('chat.turnIntoPlan')),
      );
      expect(controller.state.plan?.phase, PlanPhase.draft);
      expect(
        find.byKey(const ValueKey('chat.compassDraft.fridayDinner')),
        findsOneWidget,
      );

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('chat.reviewPlan')),
      );
      expect(
        find.byKey(const ValueKey('chat.planReview')),
        findsOneWidget,
      );

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('chat.sendPoll')),
      );
      expect(controller.state.plan?.phase, PlanPhase.pollOpen);

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('poll.fridayDinner.respond1930')),
      );
      expect(
        controller.state.plan?.responses['abdullah']?.choice,
        RsvpChoice.going,
      );

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('poll.fridayDinner.nudge')),
      );
      expect(controller.state.plan?.nudgeSent, isTrue);
      expect(controller.state.plan?.responses, contains('sara'));
      expect(controller.state.plan?.phase, PlanPhase.readyToConfirm);

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('poll.fridayDinner.confirm1930')),
      );
      expect(controller.state.plan?.phase, PlanPhase.confirmed);
      expect(controller.state.plan?.confirmedCandidateId, 'friday-1930');
      expect(controller.state.plan?.reminders, hasLength(1));
      expect(
        find.byKey(const ValueKey('plan.friday-dinner.confirmed')),
        findsOneWidget,
      );
    });
  });

  group('Compass answers', () {
    testWidgets('shows the source and freshness for a shared ETA',
        (tester) async {
      final controller = _controller(
        initialScenario: PrototypeScenario.reassuranceAtSeven,
      )..selectTab(2);
      await _pumpApp(tester, controller: controller);

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('compass.example.whereIsDad')),
      );

      expect(find.byKey(const ValueKey('compass.answer')), findsOneWidget);
      expect(
        find.text(
          'Dad shared that he is leaving work and expects to arrive around 7:20 PM.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compass.answer.source')),
        findsOneWidget,
      );
      expect(find.text('Shared by Dad'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('compass.answer.freshness')),
        findsOneWidget,
      );
      expect(find.text('3 minutes ago'), findsOneWidget);
    });

    testWidgets('uses a neutral unknown answer when no update is permitted',
        (tester) async {
      final controller = _controller(
        initialScenario: PrototypeScenario.reassuranceUnknown,
      )..selectTab(2);
      await _pumpApp(tester, controller: controller);

      await _tapAndPump(
        tester,
        find.byKey(const ValueKey('compass.example.whereIsDad')),
      );

      expect(find.text('No recent update'), findsOneWidget);
      expect(
        find.text('No recent permitted information is available.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('compass.answer.source')),
        findsNothing,
      );
      expect(find.text('Shared by Dad'), findsNothing);
      expect(
        find.byKey(const ValueKey('compass.requestCheckIn')),
        findsOneWidget,
      );
    });
  });

  testWidgets('Today retry keeps cached content until reconnect succeeds',
      (tester) async {
    final retry = Completer<void>();
    var retryCalls = 0;
    final controller = _controller(
      initialScenario: PrototypeScenario.offlineCached,
      retryAction: () {
        retryCalls += 1;
        return retry.future;
      },
    );
    await _pumpApp(tester, controller: controller);

    expect(find.text('Showing saved family information'), findsOneWidget);
    await _tapAndPump(tester, find.byKey(const Key('offline.retry')));

    expect(retryCalls, 1);
    expect(controller.state.isRetrying, isTrue);
    expect(controller.state.surfaceState, SurfaceState.offlineCached);
    expect(find.text('Showing saved family information'), findsOneWidget);

    retry.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.state.isRetrying, isFalse);
    expect(controller.state.surfaceState, SurfaceState.ready);
    expect(find.byKey(const Key('offline.retry')), findsNothing);
  });

  testWidgets('compact-height landscape preserves the Chat draft',
      (tester) async {
    final controller = _controller();
    await _pumpApp(
      tester,
      controller: controller,
      size: _phoneLandscape,
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _tapAndPump(tester, find.byKey(const Key('nav.chat')));
    const draft = 'Remember to ask everyone about dessert';
    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      draft,
    );
    await tester.pump();
    expect(controller.state.ui.chatDraft, draft);

    await _tapAndPump(tester, find.byKey(const Key('nav.today')));
    await _tapAndPump(tester, find.byKey(const Key('nav.chat')));

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('chat.composer.input')),
    );
    expect(field.controller?.text, draft);
    expect(controller.state.ui.selectedTab, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded tablet uses a rail and keeps all four areas reachable',
      (tester) async {
    final controller = _controller();
    await _pumpApp(
      tester,
      controller: controller,
      size: _tabletPortrait,
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await _tapAndPump(tester, find.byKey(const Key('nav.together')));
    expect(controller.state.ui.selectedTab, 3);
    expect(
      find.byKey(const ValueKey('together-ideas-section')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('core destinations tolerate 200 percent text on a phone',
      (tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = _controller();
    await _pumpApp(tester, controller: controller);

    expect(find.byKey(const Key('today.next')), findsOneWidget);
    for (final destination in <Key>[
      const Key('nav.chat'),
      const Key('nav.compass'),
      const Key('nav.together'),
      const Key('nav.today'),
    ]) {
      await _tapAndPump(tester, find.byKey(destination));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Arabic locale uses RTL and Arabic navigation labels',
      (tester) async {
    final controller = _controller();
    await _pumpApp(
      tester,
      controller: controller,
      locale: const Locale('ar'),
    );

    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .toList();
    expect(
      destinations.map((destination) => destination.label),
      orderedEquals(<String>['اليوم', 'الدردشة', 'البوصلة', 'معًا']),
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('nav.today'))),
      ),
      TextDirection.rtl,
    );
    expect(find.text('عشاء عائلي'), findsOneWidget);
  });

  testWidgets('a member can pause their own sharing', (tester) async {
    final controller = _controller();
    await _pumpApp(tester, controller: controller);

    await _tapAndPump(tester, find.byKey(const Key('family.menu')));
    await _tapAndPump(tester, find.byKey(const Key('family.mySharing')));

    expect(
      tester.widget<Text>(find.byKey(const Key('sharing.state'))).data,
      'Manual check-in',
    );
    expect(
      controller.state.statuses['abdullah']?.state,
      SharingState.active,
    );

    await _tapAndPump(tester, find.byKey(const Key('sharing.pause')));

    expect(
      controller.state.statuses['abdullah']?.state,
      SharingState.paused,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sharing.state'))).data,
      'Paused',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('sharing.pause')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('dark Arabic keeps RTL and the product palette', (tester) async {
    final controller = _controller();
    await _pumpApp(
      tester,
      controller: controller,
      locale: const Locale('ar'),
      themeMode: ThemeMode.dark,
    );

    final context = tester.element(find.byKey(const Key('nav.today')));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('عشاء عائلي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding reaches the app without requesting location',
      (tester) async {
    final controller = _controller();
    await _pumpApp(
      tester,
      controller: controller,
      startInOnboarding: true,
    );

    expect(find.text('No permanent family map'), findsOneWidget);
    expect(
      find.textContaining(RegExp('location permission', caseSensitive: false)),
      findsNothing,
    );
    for (var step = 0; step < 4; step++) {
      await _tapAndPump(
        tester,
        find.byKey(const Key('onboarding.continue')),
      );
      expect(tester.takeException(), isNull,
          reason: 'after onboarding step $step');
    }
    expect(find.byKey(const Key('nav.today')), findsOneWidget);
  });
}

PrototypeScenarioController _controller({
  PrototypeScenario initialScenario = PrototypeScenario.dinnerOpportunity,
  Future<void> Function()? retryAction,
}) {
  final controller = PrototypeScenarioController(
    initialScenario: initialScenario,
    retryAction: retryAction,
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
  Size size = _phonePortrait,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  bool startInOnboarding = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    FamilyCompassApp(
      controller: controller,
      initialLocale: locale,
      initialThemeMode: themeMode,
      startInOnboarding: startInOnboarding,
    ),
  );
  await tester.pump();
}

Future<void> _tapAndPump(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
