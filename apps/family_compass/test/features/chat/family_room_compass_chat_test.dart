import 'dart:async';

import 'package:family_compass/data/family_compass_repositories.dart';
import 'package:family_compass/design_system/design_system.dart';
import 'package:family_compass/domain/compass_models.dart';
import 'package:family_compass/features/chat/chat_screen.dart';
import 'package:family_compass/l10n/l10n.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  testWidgets('demo Chat answers an explicit Compass mention locally',
      (tester) async {
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pumpChat(tester, controller: controller);

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@Compass Where is Dad?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chat.compass.familyPending')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text(
          'Dad shared that he is leaving work and expects to arrive around 7:20 PM.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat.compass.familyPending')),
      findsNothing,
    );
    expect(find.text('Compass'), findsWidgets);
    expect(find.text('Visible to family'), findsOneWidget);
  });

  testWidgets('typing @ opens authorized family mentions and inserts member',
      (tester) async {
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pumpChat(tester, controller: controller);

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat.mention.chooser')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat.mention.compass')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('chat.mention.member.dad')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('chat.mention.member.mom')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('chat.mention.options')),
      const Offset(0, -160),
    );
    await tester.pump();
    expect(
        find.byKey(const ValueKey('chat.mention.member.sara')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('chat.mention.options')),
      const Offset(0, 160),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat.mention.member.mom')));
    await tester.pump();
    expect(controller.state.ui.chatDraft, '@Mom ');
    expect(find.byKey(const ValueKey('chat.mention.chooser')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@Mom Dinner is ready',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('chat.mention.chooser')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump();

    expect(
      controller.state.chatItems.any(
        (item) =>
            item.text == '@Mom Dinner is ready' &&
            item.mentionedMemberIds.contains('mom'),
      ),
      isTrue,
    );
    expect(
        find.byKey(const ValueKey('chat.compass.familyPending')), findsNothing);
  });

  testWidgets('in-sentence Compass mention uses the family-room path',
      (tester) async {
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      'Could you summarize our chat, @Compass?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump();

    expect(
        repository.prompts, <String>['@Compass Could you summarize our chat?']);
    expect(find.byKey(const ValueKey('chat.compass.familyPending')),
        findsOneWidget);
  });

  testWidgets('member mention stays structured in a Compass chat question',
      (tester) async {
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    final composer = find.byKey(const ValueKey('chat.composer.input'));
    await tester.enterText(composer, '@');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.mention.member.mom')));
    await tester.pump();
    await tester.enterText(composer, '@Mom @');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.mention.compass')));
    await tester.pump();
    await tester.enterText(composer, '@Mom @Compass Can Mom join dinner?');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump();

    expect(repository.mentionSets.single, <String>{'mom'});
    expect(repository.prompts.single, '@Compass @Mom Can Mom join dinner?');
  });

  testWidgets('mention chooser reflows in Arabic at 200 percent text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(2),
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.semantics
          .find(find.byKey(const ValueKey('chat.mention.chooser')))
          .getSemanticsData()
          .label,
      contains('اقتراحات الإشارة'),
    );
    final target = tester.getSize(
      find.byKey(const ValueKey('chat.mention.compass')),
    );
    expect(target.height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  test('mention parsing respects cursor, member names, and Compass boundary',
      () {
    expect(
      activeChatMention(
        const TextEditingValue(
          text: 'Hi @Mo',
          selection: TextSelection.collapsed(offset: 6),
        ),
      )?.query,
      'Mo',
    );
    expect(
      activeChatMention(
        const TextEditingValue(
          text: 'email@example.com',
          selection: TextSelection.collapsed(offset: 10),
        ),
      ),
      isNull,
    );
    expect(containsCompassMention('@Compass أين أبي؟'), isTrue);
    expect(containsCompassMention('not@Compass a mention'), isFalse);
    expect(
      canonicalCompassPrompt('Can you help, @Compass: with dinner?'),
      '@Compass Can you help, with dinner?',
    );
    expect(
      activeChatMention(
        const TextEditingValue(
          text: '@Mom Dinner is ready',
          selection: TextSelection.collapsed(offset: 20),
        ),
      ),
      isNull,
    );
  });

  testWidgets('explicit @Compass shows pending then sourced family artifact',
      (tester) async {
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@Compass Where is Dad?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(repository.prompts.single, '@Compass Where is Dad?');
    expect(
      find.byKey(const ValueKey('chat.compass.familyPending')),
      findsOneWidget,
    );
    expect(find.text('Preparing a reply…'), findsOneWidget);
    expect(find.text('@Compass Where is Dad?'), findsNothing);

    repository.complete(_artifact());
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('chat.compass.familyArtifact.artifact-one'),
      ),
      findsOneWidget,
    );
    expect(find.text('Dad shared that he is on the way home.'), findsOneWidget);
    expect(find.text('Dad shared journey'), findsNothing);
    expect(find.textContaining('Whole family'), findsNothing);
    expect(find.text('Some uncertainty'), findsNothing);
    expect(find.text('Sources & details'), findsOneWidget);
    final bubble = find.byKey(
      const ValueKey('chat.compass.familyBubble.artifact-one'),
    );
    expect(bubble, findsOneWidget);
    expect(tester.getSize(bubble).width, lessThan(340));
    expect(find.textContaining('Request a check-in · Confirm'), findsOneWidget);

    final details =
        find.byKey(const ValueKey('chat.compass.details.artifact-one'));
    await tester.ensureVisible(details);
    await tester.pump();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Dad shared journey'), findsOneWidget);
    expect(find.textContaining('Whole family'), findsOneWidget);
    expect(find.text('Some uncertainty'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final artifactTop = tester.getTopLeft(
      find.byKey(
        const ValueKey('chat.compass.familyArtifact.artifact-one'),
      ),
    );
    final composerTop = tester.getTopLeft(
      find.byKey(const ValueKey('chat.composer.input')),
    );
    expect(artifactTop.dy, greaterThanOrEqualTo(0));
    expect(artifactTop.dy, lessThan(composerTop.dy));
  });

  testWidgets('family answer follows an older derived poll chronologically',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    final artifact = _artifact();
    final repository = _ScriptedFamilyRoomRepository(
      initialArtifacts: <FamilyRoomCompassArtifact>[artifact],
    );
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey('chat.compass.familyArtifact.artifact-one'),
            ),
          )
          .dy,
      greaterThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('plan.friday-dinner.poll')),
            )
            .dy,
      ),
    );
  });

  testWidgets('family answer shows one source then expands all public sources',
      (tester) async {
    final now = DateTime.now().toUtc();
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository(
      initialArtifacts: <FamilyRoomCompassArtifact>[
        _artifact(
          citations: <CompassCitation>[
            for (var index = 1; index <= 4; index++)
              CompassCitation(
                sourceId: 'source-$index',
                sourceType: CompassFactSource.chatMessage,
                sourceLabel: 'Public source $index',
                audience: CompassFactAudience.wholeFamily,
                freshness: CompassFactFreshness.recent,
                updatedAt: now.subtract(Duration(minutes: index)),
                expiresAt: now.add(const Duration(hours: 1)),
                text: 'Source text $index',
              ),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    expect(find.text('Public source 1'), findsNothing);
    expect(find.text('Public source 2'), findsNothing);
    expect(find.text('Sources & details'), findsOneWidget);
    final details =
        find.byKey(const ValueKey('chat.compass.details.artifact-one'));
    await tester.ensureVisible(details);
    await tester.pump();
    await tester.tap(details);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chat.compass.sources.details')),
      findsOneWidget,
    );
    for (var index = 1; index <= 4; index++) {
      expect(
        find.text('Public source $index'),
        findsOneWidget,
      );
    }
    expect(find.textContaining('Whole family'), findsNWidgets(4));
    expect(find.textContaining('Recent'), findsNWidgets(4));
  });

  testWidgets('Chat reveal scrolling is immediate when animations are disabled',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@Compass Where is Dad?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump();
    repository.complete(_artifact());
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('chat.compass.familyArtifact.artifact-one'),
      ),
      findsOneWidget,
    );
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('consequential Compass action asks before changing state',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceUnknown,
    );
    final repository = _ScriptedFamilyRoomRepository(
      initialArtifacts: <FamilyRoomCompassArtifact>[_artifact()],
    );
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    final action = find.byKey(
      const ValueKey(
        'chat.compass.action.artifact-one.requestCheckIn',
      ),
    );
    await tester.dragUntilVisible(
      action,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(controller.state.checkInState, CheckInState.none);
    expect(find.text('Confirm this action?'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('chat.compass.action.confirm.requestCheckIn'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.state.checkInState, CheckInState.requested);
  });

  testWidgets('provider error is honest and retry reuses request id',
      (tester) async {
    final controller = PrototypeScenarioController();
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      '@Compass Summarize our family chat.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat.composer.send')));
    await tester.pump(const Duration(milliseconds: 250));
    repository.fail();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chat.compass.familyError')),
      findsOneWidget,
    );
    expect(find.textContaining('question is in the chat'), findsOneWidget);
    final firstId = repository.requestIds.single;

    await tester.tap(
      find.byKey(const ValueKey('chat.compass.familyRetry')),
    );
    await tester.pump();
    expect(repository.requestIds, <String>[firstId, firstId]);
  });

  testWidgets('offline @Compass stays a draft and is never posted',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
    );
    final repository = _ScriptedFamilyRoomRepository();
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    const prompt = '@Compass Where is Dad?';
    await tester.enterText(
      find.byKey(const ValueKey('chat.composer.input')),
      prompt,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('chat.composer.send')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repository.prompts, isEmpty);
    expect(controller.state.ui.chatDraft, prompt);
    expect(
      controller.state.chatItems.any((item) => item.text == prompt),
      isFalse,
    );
  });

  testWidgets('family artifact hides citations outside the whole family',
      (tester) async {
    final controller = PrototypeScenarioController();
    final publicArtifact = _artifact();
    final repository = _ScriptedFamilyRoomRepository(
      initialArtifacts: <FamilyRoomCompassArtifact>[
        _artifact(
          citations: <CompassCitation>[
            ...publicArtifact.citations,
            CompassCitation(
              sourceId: 'private-check-in',
              sourceType: CompassFactSource.checkIn,
              sourceLabel: 'Private check-in',
              audience: CompassFactAudience.onlyMe,
              freshness: CompassFactFreshness.current,
              updatedAt: DateTime.now().toUtc(),
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              text: 'Private detail.',
            ),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    final details =
        find.byKey(const ValueKey('chat.compass.details.artifact-one'));
    await tester.ensureVisible(details);
    await tester.pump();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Dad shared journey'), findsOneWidget);
    expect(find.text('Private check-in'), findsNothing);
    expect(find.text('Only me'), findsNothing);
  });

  testWidgets('consequential action confirms even if a client flag is false',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceUnknown,
    );
    final repository = _ScriptedFamilyRoomRepository(
      initialArtifacts: <FamilyRoomCompassArtifact>[
        _artifact(
          actions: const <CompassAction>[
            CompassAction(
              kind: CompassActionKind.requestCheckIn,
              label: 'Request a check-in',
              requiresConfirmation: false,
              targetId: 'dad',
            ),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(repository.dispose);
    await _pumpChat(
      tester,
      controller: controller,
      repository: repository,
    );

    final action = find.byKey(
      const ValueKey(
        'chat.compass.action.artifact-one.requestCheckIn',
      ),
    );
    await tester.dragUntilVisible(
      action,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(controller.state.checkInState, CheckInState.none);
    expect(find.text('Confirm this action?'), findsOneWidget);
  });
}

Future<void> _pumpChat(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
  FamilyRoomCompassRepository? repository,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: FamilyCompassTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: ChatScreen(
          controller: controller,
          familyRoomCompassRepository: repository,
          familyId: repository == null ? null : _familyId,
        ),
      ),
    ),
  );
  await tester.pump();
}

FamilyRoomCompassArtifact _artifact({
  List<CompassCitation>? citations,
  List<CompassAction>? actions,
}) {
  final now = DateTime.now().toUtc();
  return FamilyRoomCompassArtifact(
    id: 'artifact-one',
    familyId: _familyId,
    requestMessageId: 'message-one',
    requestedBy: 'abdullah',
    kind: FamilyCompassArtifactKind.suggestion,
    answer: 'Dad shared that he is on the way home.',
    provider: 'lm-studio',
    citations: citations ??
        <CompassCitation>[
          CompassCitation(
            sourceId: 'journey-one',
            sourceType: CompassFactSource.journey,
            sourceLabel: 'Dad shared journey',
            audience: CompassFactAudience.wholeFamily,
            freshness: CompassFactFreshness.current,
            updatedAt: now.subtract(const Duration(minutes: 4)),
            expiresAt: now.add(const Duration(hours: 1)),
            text: 'On the way home.',
          ),
        ],
    actions: actions ??
        const <CompassAction>[
          CompassAction(
            kind: CompassActionKind.requestCheckIn,
            label: 'Request a check-in',
            requiresConfirmation: true,
            targetId: 'dad',
          ),
        ],
    uncertainty: CompassUncertainty.medium,
    createdAt: now,
  );
}

class _ScriptedFamilyRoomRepository implements FamilyRoomCompassRepository {
  _ScriptedFamilyRoomRepository({
    List<FamilyRoomCompassArtifact> initialArtifacts = const [],
  }) : _initialArtifacts = initialArtifacts;

  final List<FamilyRoomCompassArtifact> _initialArtifacts;
  final StreamController<List<FamilyRoomCompassArtifact>> _artifacts =
      StreamController<List<FamilyRoomCompassArtifact>>.broadcast();
  Completer<FamilyRoomCompassArtifact>? _pending;
  final List<String> prompts = <String>[];
  final List<String> requestIds = <String>[];
  final List<Set<String>> mentionSets = <Set<String>>[];

  @override
  Stream<RepositoryStatus> get status =>
      Stream<RepositoryStatus>.value(const RepositoryStatus.idle());

  @override
  Stream<List<FamilyRoomCompassArtifact>> watchArtifacts(
      String familyId) async* {
    yield _initialArtifacts;
    yield* _artifacts.stream;
  }

  @override
  Future<FamilyRoomCompassArtifact> ask({
    required String familyId,
    required String prompt,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
  }) {
    prompts.add(prompt);
    requestIds.add(idempotencyKey);
    mentionSets.add(Set<String>.unmodifiable(mentionedMemberIds));
    _pending = Completer<FamilyRoomCompassArtifact>();
    return _pending!.future;
  }

  void complete(FamilyRoomCompassArtifact artifact) {
    _pending!.complete(artifact);
    _artifacts.add(<FamilyRoomCompassArtifact>[artifact]);
  }

  void fail() => _pending!.completeError(StateError('provider unavailable'));

  @override
  Future<void> refresh() async {}

  @override
  Future<void> retryPending() async {}

  Future<void> dispose() => _artifacts.close();
}
