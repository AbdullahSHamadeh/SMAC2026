import 'dart:async';
import 'dart:convert';

import 'api_mappers.dart';
import 'family_compass_api_client.dart';
import 'family_event_transport.dart';

class FamilyEvent {
  const FamilyEvent({
    required this.familyId,
    required this.eventType,
    required this.actorId,
    required this.resourceId,
    required this.occurredAt,
    required this.data,
    this.deepLink,
  });

  final String familyId;
  final String eventType;
  final String actorId;
  final String resourceId;
  final DateTime occurredAt;
  final FamilyCompassDeepLink? deepLink;
  final Map<String, Object?> data;

  static FamilyEvent fromJson(Object? value) {
    final json = asJsonObject(value, label: 'Family event');
    return FamilyEvent(
      familyId: json['family_id'] as String,
      eventType: json['event_type'] as String,
      actorId: json['actor_id'] as String,
      resourceId: json['resource_id'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      deepLink: json['deep_link'] == null
          ? null
          : FamilyCompassDeepLink.tryParse(json['deep_link'] as String),
      data: Map<String, Object?>.from(json['data'] as Map? ?? const {}),
    );
  }
}

enum FamilyResourceKind { messages, plans, reminders, checkIns, unknown }

class FamilyCompassDeepLink {
  const FamilyCompassDeepLink({
    required this.familyId,
    required this.kind,
    required this.resourceId,
  });

  final String familyId;
  final FamilyResourceKind kind;
  final String resourceId;

  static FamilyCompassDeepLink? tryParse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'familycompass' ||
        uri.host != 'families') {
      return null;
    }
    if (uri.pathSegments.length != 3) return null;
    final kind = switch (uri.pathSegments[1]) {
      'messages' => FamilyResourceKind.messages,
      'plans' => FamilyResourceKind.plans,
      'reminders' => FamilyResourceKind.reminders,
      'check-ins' => FamilyResourceKind.checkIns,
      _ => FamilyResourceKind.unknown,
    };
    return FamilyCompassDeepLink(
      familyId: uri.pathSegments[0],
      kind: kind,
      resourceId: uri.pathSegments[2],
    );
  }
}

class FamilyRealtimeClient {
  FamilyRealtimeClient({
    required String apiBaseUrl,
    required this.familyId,
    required this.credentials,
    Stream<String> Function(Uri uri, ApiCredentialProvider credentials)?
        connector,
    List<Duration>? reconnectDelays,
  })  : apiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
        _connector = connector,
        reconnectDelays = List<Duration>.unmodifiable(
          reconnectDelays ??
              const <Duration>[
                Duration(milliseconds: 500),
                Duration(seconds: 1),
                Duration(seconds: 2),
                Duration(seconds: 5),
                Duration(seconds: 10),
              ],
        );

  final String apiBaseUrl;
  final String familyId;
  final ApiCredentialProvider credentials;
  final Stream<String> Function(Uri, ApiCredentialProvider)? _connector;
  final List<Duration> reconnectDelays;

  Stream<FamilyEvent> watch() => Stream<FamilyEvent>.multi((controller) {
        if (reconnectDelays.isEmpty) {
          controller.addError(
            ArgumentError.value(
              reconnectDelays,
              'reconnectDelays',
              'Provide at least one reconnect delay.',
            ),
          );
          controller.close();
          return;
        }
        var cancelled = false;
        var failures = 0;
        StreamSubscription<String>? subscription;
        Timer? reconnectTimer;
        late void Function() connect;

        void scheduleReconnect() {
          if (cancelled) return;
          final delay =
              reconnectDelays[failures.clamp(0, reconnectDelays.length - 1)];
          failures += 1;
          reconnectTimer?.cancel();
          reconnectTimer = Timer(delay, connect);
        }

        void handleTransportError(Object error, StackTrace stackTrace) {
          if (error is FamilyCompassApiException &&
              (error.kind == FamilyCompassApiErrorKind.unauthorized ||
                  error.kind == FamilyCompassApiErrorKind.forbidden)) {
            cancelled = true;
            controller.addError(error, stackTrace);
            controller.close();
            unawaited(subscription?.cancel());
            return;
          }
          scheduleReconnect();
        }

        connect = () {
          if (cancelled) return;
          final source = _connector?.call(eventUri, credentials) ??
              connectFamilyEventTransport(
                uri: eventUri,
                credentials: credentials,
              );
          subscription = source.listen(
            (raw) {
              failures = 0;
              try {
                controller.add(_decodeEvent(raw));
              } on Object catch (error, stackTrace) {
                controller.addError(error, stackTrace);
              }
            },
            onError: handleTransportError,
            onDone: scheduleReconnect,
            cancelOnError: true,
          );
        };

        controller.onCancel = () async {
          cancelled = true;
          reconnectTimer?.cancel();
          await subscription?.cancel();
        };
        connect();
      });

  FamilyEvent _decodeEvent(String raw) {
    try {
      return FamilyEvent.fromJson(jsonDecode(raw));
    } on FormatException {
      throw const FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.malformedResponse,
        message: 'A family event could not be read safely.',
      );
    } on TypeError {
      throw const FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.malformedResponse,
        message: 'A family event could not be read safely.',
      );
    }
  }

  Uri get eventUri {
    final httpUri = Uri.parse(apiBaseUrl);
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/v1/families/$familyId/events',
      query: null,
      fragment: null,
    );
  }
}
