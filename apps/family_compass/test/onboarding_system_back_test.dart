import 'package:family_compass/design_system/design_system.dart';
import 'package:family_compass/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _phonePortrait = Size(390, 844);

void main() {
  testWidgets('system Back rewinds one step and preserves onboarding state',
      (tester) async {
    await _pumpOnboarding(tester);

    await _tapVisible(tester, find.byKey(const Key('onboarding.continue')));
    expect(find.text('Step 2 of 4'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 55 111 2233',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding.code')),
      '9753',
    );
    await _tapVisible(tester, find.byKey(const Key('onboarding.continue')));
    expect(find.text('Step 3 of 4'), findsOneWidget);

    await _tapVisible(tester, find.text('Join by invitation'));
    expect(
      tester
          .widget<SegmentedButton<bool>>(
            find.byKey(const Key('onboarding.familyChoice')),
          )
          .selected,
      <bool>{false},
    );

    await _tapVisible(tester, find.byKey(const Key('onboarding.continue')));
    expect(find.text('Step 4 of 4'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<bool>>(
            find.byKey(const Key('onboarding.familyChoice')),
          )
          .selected,
      <bool>{false},
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('onboarding.phone')))
          .controller
          ?.text,
      '+971 55 111 2233',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('onboarding.code')))
          .controller
          ?.text,
      '9753',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible Back still returns to the previous onboarding step',
      (tester) async {
    await _pumpOnboarding(tester);

    await _tapVisible(tester, find.byKey(const Key('onboarding.continue')));
    await tester.enterText(
      find.byKey(const Key('onboarding.phone')),
      '+971 52 444 7788',
    );
    await _tapVisible(tester, find.byKey(const Key('onboarding.back')));

    expect(find.text('Step 1 of 4'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('onboarding.continue')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('onboarding.phone')))
          .controller
          ?.text,
      '+971 52 444 7788',
    );
  });

  testWidgets('system Back at step zero is handled by the enclosing route',
      (tester) async {
    await _setPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: FamilyCompassTheme.light,
        initialRoute: '/onboarding',
        routes: {
          '/': (_) => const Scaffold(
                body: Center(
                  child: Text(
                    'Before onboarding',
                    key: Key('before-onboarding'),
                  ),
                ),
              ),
          '/onboarding': (_) => OnboardingScreen(onComplete: () {}),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('before-onboarding')), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsNothing);
  });
}

Future<void> _pumpOnboarding(WidgetTester tester) async {
  await _setPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: FamilyCompassTheme.light,
      home: OnboardingScreen(onComplete: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _phonePortrait;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
