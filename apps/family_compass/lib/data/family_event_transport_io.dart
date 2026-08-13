import 'dart:async';

import 'package:web_socket_channel/io.dart';

import 'family_compass_api_client.dart';

Stream<String> connectFamilyEventTransport({
  required Uri uri,
  required ApiCredentialProvider credentials,
}) {
  final channel = IOWebSocketChannel.connect(
    uri,
    headers: credentials.headers,
    pingInterval: const Duration(seconds: 25),
    connectTimeout: const Duration(seconds: 10),
  );
  final controller = StreamController<String>();
  late final StreamSubscription<Object?> subscription;
  subscription = channel.stream.listen(
    (event) => controller.add(event.toString()),
    onError: controller.addError,
    onDone: () {
      final code = channel.closeCode;
      if (code == 4401) {
        controller.addError(
          const FamilyCompassApiException(
            kind: FamilyCompassApiErrorKind.unauthorized,
            message: 'Your authenticated family session has ended.',
            statusCode: 401,
          ),
        );
      } else if (code == 4403) {
        controller.addError(
          const FamilyCompassApiException(
            kind: FamilyCompassApiErrorKind.forbidden,
            message: 'Access to this family has ended.',
            statusCode: 403,
          ),
        );
      }
      controller.close();
    },
  );
  controller.onCancel = subscription.cancel;
  return controller.stream;
}
