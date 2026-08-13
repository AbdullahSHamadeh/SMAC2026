import 'dart:async';

import 'package:family_compass/app/family_compass_app.dart';
import 'package:family_compass/data/family_realtime_client.dart';
import 'package:family_compass/firebase/firebase_notifications.dart';
import 'package:family_compass/prototype/prototype_scenario_controller.dart';
import 'package:family_compass/prototype/prototype_scenario_state.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = 'demo-family';
const _messageId = 'opening-mom';

void main() {
  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      'foreground notification is generic and opens its exact link on '
      '${platform.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final foreground = StreamController<NotificationEnvelope>();
        final controller = PrototypeScenarioController(
          initialScenario: PrototypeScenario.dinnerPollOpen,
        );
        addTearDown(foreground.close);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          FamilyCompassApp(
            controller: controller,
            foregroundNotifications: foreground.stream,
          ),
        );

        final envelope = NotificationEnvelope.tryParse(
          const RemoteMessage(
            notification: RemoteNotification(
              title: 'Mom',
              body: 'Private message text must not appear here.',
            ),
            data: <String, dynamic>{
              'event_type': 'message.created',
              'family_id': _familyId,
              'resource_id': _messageId,
              'deep_link':
                  'familycompass://families/$_familyId/messages/$_messageId',
            },
          ),
        );
        foreground.add(envelope!);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('A new family message arrived.'), findsOneWidget);
        expect(
          find.text('Private message text must not appear here.'),
          findsNothing,
        );

        tester
            .widget<SnackBarAction>(
              find.byKey(const Key('notification.foreground.open')),
            )
            .onPressed();
        await tester.pumpAndSettle();

        expect(controller.state.ui.selectedTab, 1);
        expect(
          find.byKey(const ValueKey<String>('chat.linked.$_messageId')),
          findsOneWidget,
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('foreground notification copy follows Arabic app locale',
      (tester) async {
    final foreground = StreamController<NotificationEnvelope>();
    final controller = PrototypeScenarioController(
      initialScenario: PrototypeScenario.dinnerPollOpen,
    );
    addTearDown(foreground.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      FamilyCompassApp(
        controller: controller,
        initialLocale: const Locale('ar'),
        foregroundNotifications: foreground.stream,
      ),
    );
    foreground.add(
      NotificationEnvelope(
        eventType: 'plan.updated',
        deepLink: const FamilyCompassDeepLink(
          familyId: _familyId,
          kind: FamilyResourceKind.plans,
          resourceId: 'dinner-plan',
        ),
        messageId: 'notification-plan',
        receivedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('تم تحديث إحدى خطط العائلة.'), findsOneWidget);
    expect(find.text('فتح'), findsOneWidget);
  });
}
