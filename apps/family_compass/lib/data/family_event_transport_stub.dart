import 'family_compass_api_client.dart';

Stream<String> connectFamilyEventTransport({
  required Uri uri,
  required ApiCredentialProvider credentials,
}) =>
    Stream<String>.error(
      const FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.unavailable,
        message:
            'Authenticated family events are not available on this preview platform.',
      ),
    );
