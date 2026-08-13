import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/domain/family_models.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);

void main() {
  testWidgets(
      'selected recipient IDs persist and names replace placeholder copy',
      (tester) async {
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller: controller);
    await _openSharing(tester);

    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.changeAudience')),
    );
    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.audience.selectedPeople')),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('sharing.audience.save')),
          )
          .onPressed,
      isNull,
    );

    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.recipient.dad')),
    );
    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.recipient.mom')),
    );
    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.audience.save')),
    );

    final status = controller.state.statuses['abdullah'];
    expect(status?.audience, SharingAudience.selectedPeople);
    expect(status?.recipientIds, {'dad', 'mom'});
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('sharing.audience.summary')),
          )
          .data,
      'Dad and Mom',
    );

    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.changeAudience')),
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('sharing.recipient.dad')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('sharing.recipient.mom')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('recipient picker keeps Arabic direction and member names',
      (tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = PrototypeScenarioController();
    addTearDown(controller.dispose);
    await _pumpApp(
      tester,
      controller: controller,
      locale: const Locale('ar'),
    );
    await _openSharing(tester);

    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.changeAudience')),
    );
    final sheet = find.byKey(const Key('sharing.audience.sheet'));
    expect(Directionality.of(tester.element(sheet)), TextDirection.rtl);

    await _tapAndSettle(
      tester,
      find.byKey(const Key('sharing.audience.selectedPeople')),
    );
    expect(find.text('الأب'), findsOneWidget);
    expect(find.text('الأم'), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required PrototypeScenarioController controller,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phonePortrait;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    FamilyCompassApp(
      controller: controller,
      initialLocale: locale,
    ),
  );
  await tester.pump();
}

Future<void> _openSharing(WidgetTester tester) async {
  await _tapAndSettle(tester, find.byKey(const Key('family.menu')));
  await _tapAndSettle(tester, find.byKey(const Key('family.mySharing')));
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
