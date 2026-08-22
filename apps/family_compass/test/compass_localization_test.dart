import 'package:family_compass/design_system/design_system.dart';
import 'package:family_compass/features/compass/compass_screen.dart';
import 'package:family_compass/l10n/l10n.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Compass reveal scrolling is immediate with reduced motion',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(controller.dispose);
    await _pumpCompass(tester, controller);

    await tester.tap(
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('compass.answer')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('Arabic grounded answer localizes evidence and explanation',
      (tester) async {
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(controller.dispose);
    await _pumpCompass(tester, controller);

    expect(find.text('أين أبي؟'), findsOneWidget);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );

    expect(find.text('إجابة من معلومات تمت مشاركتها'), findsOneWidget);
    expect(
      find.text(
        'شارك الأب أنه يغادر العمل ويتوقع الوصول نحو الساعة 7:20 م.',
      ),
      findsOneWidget,
    );
    expect(find.text('مشاركة من الأب'), findsOneWidget);
    expect(find.text('قبل 3 دقائق'), findsOneWidget);
    expect(find.text('من يرى الإجابة'), findsOneWidget);
    expect(find.text('تحديث يدوي، وليس موقعًا مباشرًا'), findsOneWidget);
    expect(find.text('لماذا هذه الإجابة؟'), findsOneWidget);
    expect(find.text('اعتبار التحديث قديمًا'), findsOneWidget);
    expect(
      find.text(
        'Dad shared that he is leaving work and expects to arrive around 7:20 PM.',
      ),
      findsNothing,
    );
    _expectOnlyProductHandleUsesLatinText(tester);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.why')),
    );
    expect(
      find.byKey(const ValueKey('compass.why.sheet')),
      findsOneWidget,
    );
    expect(find.text('ما لم يُستخدم'), findsOneWidget);
    expect(
      find.text(
        'لم تستخدم هذه الإجابة خريطة مباشرة أو مشاركة موقع مستمرة.',
      ),
      findsOneWidget,
    );
    _expectOnlyProductHandleUsesLatinText(tester);
  });

  testWidgets('Arabic unknown and unavailable states remain neutral',
      (tester) async {
    final unknownController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceUnknown,
    );
    addTearDown(unknownController.dispose);
    await _pumpCompass(tester, unknownController);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    expect(find.text('لا يوجد تحديث حديث'), findsOneWidget);
    expect(
      find.text('لا تتوفر معلومات حديثة مسموح لك برؤيتها.'),
      findsOneWidget,
    );
    expect(
      find.text('لم تستنتج البوصلة موقعًا من عدم الرد أو من الروتين'),
      findsOneWidget,
    );
    expect(find.text('طلب الاطمئنان'), findsOneWidget);
    expect(find.text('No recent update'), findsNothing);
    _expectOnlyProductHandleUsesLatinText(tester);

    final unavailableController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.aiUnavailable,
    );
    addTearDown(unavailableController.dispose);
    await _pumpCompass(tester, unavailableController);
    expect(find.text('البوصلة غير متاحة الآن'), findsOneWidget);
    expect(
      find.text('لا تزال خطط العائلة والدردشة تعملان.'),
      findsOneWidget,
    );
    expect(find.text('Compass is unavailable right now'), findsNothing);
    _expectOnlyProductHandleUsesLatinText(tester);
  });

  testWidgets('Arabic plan and reminder review artifacts are localized',
      (tester) async {
    final planController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(planController.dispose);
    await _pumpCompass(tester, planController);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.planChange.draft')),
    );
    expect(find.text('مسودة تغيير الخطة'), findsOneWidget);
    expect(
      find.text('عشاء العائلة يوم الجمعة: من 7:00 م إلى 7:30 م'),
      findsOneWidget,
    );
    expect(find.text('تأكيد التغيير'), findsOneWidget);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.planChange.apply')),
    );
    expect(find.text('تم تغيير الخطة إلى 7:30 م'), findsOneWidget);
    _expectOnlyProductHandleUsesLatinText(tester);

    final reminderController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(reminderController.dispose);
    await _pumpCompass(tester, reminderController);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.reminder.draftAction')),
    );
    expect(find.text('مسودة تذكير شخصي'), findsOneWidget);
    expect(
      find.text('شراء الحلوى · الجمعة الساعة 5:00 م'),
      findsOneWidget,
    );
    expect(find.text('تأكيد التذكير'), findsOneWidget);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.reminder.confirm')),
    );
    expect(find.text('تم تأكيد التذكير'), findsOneWidget);
    _expectOnlyProductHandleUsesLatinText(tester);
  });

  testWidgets('Arabic expanded pane and offline state are localized',
      (tester) async {
    final groundedController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.reassuranceAtSeven,
    );
    addTearDown(groundedController.dispose);
    await _pumpCompass(
      tester,
      groundedController,
      size: const Size(1200, 900),
    );
    expect(find.text('المصدر والخصوصية'), findsOneWidget);
    expect(
      find.text(
        'اطرح سؤالًا لعرض مصدر الإجابة ووقت تحديثها ومن يراها ودرجة اليقين هنا.',
      ),
      findsOneWidget,
    );
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('compass.example.whereIsDad')),
    );
    expect(
      find.text('اختار الأب مشاركة هذا التحديث مع عبدالله.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'لم تُستخدم خريطة مباشرة أو مشاركة موقع مستمرة أو سجل محادثاتك الخاصة مع البوصلة.',
      ),
      findsOneWidget,
    );
    _expectOnlyProductHandleUsesLatinText(tester);

    final offlineController = PrototypeScenarioController(
      initialScenario: PrototypeScenario.offlineCached,
    );
    addTearDown(offlineController.dispose);
    await _pumpCompass(tester, offlineController);
    expect(
      find.text(
        'تحتاج البوصلة إلى اتصال بالإنترنت. تبقى خطط العائلة المحفوظة متاحة.',
      ),
      findsOneWidget,
    );
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('compass.composer.input')),
    );
    expect(composer.enabled, isFalse);
    _expectOnlyProductHandleUsesLatinText(tester);
  });
}

Future<void> _pumpCompass(
  WidgetTester tester,
  PrototypeScenarioController controller, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<PrototypeScenarioController>(controller),
      debugShowCheckedModeBanner: false,
      theme: FamilyCompassTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CompassScreen(
          key: ValueKey<PrototypeScenarioController>(controller),
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectOnlyProductHandleUsesLatinText(WidgetTester tester) {
  final latinText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .where((text) => RegExp(r'[A-Za-z]').hasMatch(text))
      .toList();
  expect(
    latinText,
    everyElement(
      predicate<String>(
        (text) => text.contains('@Compass'),
        'contains only the localized @Compass product handle',
      ),
    ),
  );
}
