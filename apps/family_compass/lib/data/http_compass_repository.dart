import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/compass_models.dart';
import 'api_mappers.dart';
import 'family_compass_api_client.dart';
import 'family_compass_repositories.dart';

class HttpCompassRepository implements CompassRepository {
  HttpCompassRepository({
    required String apiBaseUrl,
    required this.familyId,
    required this.credentials,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : apiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client(),
        _api = null;

  HttpCompassRepository.fromApiClient({
    required FamilyCompassApiClient api,
    required this.familyId,
    this.timeout = const Duration(seconds: 30),
  })  : apiBaseUrl = api.baseUrl,
        credentials = api.credentials,
        _client = http.Client(),
        _api = api;

  final String apiBaseUrl;
  final String familyId;
  final ApiCredentialProvider credentials;
  final Duration timeout;
  final http.Client _client;
  final FamilyCompassApiClient? _api;

  @override
  Future<CompassAnswer> ask({
    required String conversationId,
    required String question,
    CompassVisibility visibility = CompassVisibility.private,
  }) async {
    try {
      final sharedApi = _api;
      if (sharedApi != null) {
        final body = asJsonObject(
          await sharedApi.post(
            '/api/v1/families/$familyId/compass',
            body: <String, Object?>{
              'conversation_id': conversationId,
              'prompt': question,
              'visibility': visibility == CompassVisibility.private
                  ? 'private'
                  : 'family_room',
            },
          ),
          label: 'Compass response',
        );
        return _answerFromBody(body);
      }
      final response = await _client
          .post(
            Uri.parse('$apiBaseUrl/api/v1/families/$familyId/compass'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              ...credentials.headers,
            },
            body: jsonEncode(<String, Object>{
              'conversation_id': conversationId,
              'prompt': question,
              'visibility': visibility == CompassVisibility.private
                  ? 'private'
                  : 'family_room',
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw CompassConnectionException(_messageFor(response));
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Compass response is not an object.');
      }
      return _answerFromBody(body);
    } on FamilyCompassApiException catch (error) {
      throw CompassConnectionException(_messageForApiError(error));
    } on TimeoutException {
      throw const CompassConnectionException(
        'Compass took too long to answer. Check that LM Studio is running, then try again.',
      );
    } on http.ClientException {
      throw const CompassConnectionException(
        'Compass could not reach the local AI service. Check the backend and LM Studio, then try again.',
      );
    } on FormatException {
      throw const CompassConnectionException(
        'Compass received an unreadable answer. Try again.',
      );
    }
  }

  static CompassAnswer _answerFromBody(Map<String, dynamic> body) {
    final text = body['answer'];
    final providerValue = body['provider'];
    final permittedValue = body['has_permitted_information'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Compass answer is missing or invalid.');
    }
    if (providerValue != null && providerValue is! String) {
      throw const FormatException('Compass provider is invalid.');
    }
    if (permittedValue != null && permittedValue is! bool) {
      throw const FormatException('Compass permission result is invalid.');
    }
    final facts = body['grounded_facts'];
    final factValues = facts == null
        ? const <Map<String, dynamic>>[]
        : asJsonObjectList(facts, label: 'Compass citations');
    final citations = factValues.map(compassCitationFromApi).toList();
    final firstFact = factValues.isEmpty ? null : factValues.first;
    final actionValues = body['action_artifacts'] == null
        ? const <Map<String, dynamic>>[]
        : asJsonObjectList(
            body['action_artifacts'],
            label: 'Compass actions',
          );
    final actions = actionValues.map(compassActionFromApi).toList();
    final answerKind = body['answer_kind'] as String? ?? '';
    final general = answerKind == 'general';
    final provider = providerValue as String? ?? 'Compass';
    final uncertainty = switch (body['uncertainty']) {
      'low' => CompassUncertainty.low,
      'medium' => CompassUncertainty.medium,
      'not_applicable' => CompassUncertainty.notApplicable,
      _ => CompassUncertainty.high,
    };
    return CompassAnswer(
      text: text,
      sourceLabel: general
          ? '$provider · general knowledge'
          : firstFact?['source_label'] as String? ?? 'No permitted source',
      freshnessLabel: firstFact == null
          ? ''
          : _freshnessLabel(firstFact['updated_at'] as String?),
      hasPermittedInformation: permittedValue as bool? ?? false,
      isGeneralKnowledge: general,
      actionLabel: actions.isEmpty
          ? _firstSuggestedAction(body['suggested_actions'])
          : actions.first.label,
      citations: citations,
      actions: actions,
      familyVisible: body['audience'] == 'family_room',
      uncertainty: uncertainty,
    );
  }

  static String _messageForApiError(FamilyCompassApiException error) {
    if (error.kind == FamilyCompassApiErrorKind.unavailable) {
      return 'Compass could not reach LM Studio. Make sure its local server and a model are running, then try again.';
    }
    if (error.kind == FamilyCompassApiErrorKind.forbidden) {
      return 'Compass is not allowed to process this request with the configured provider.';
    }
    if (error.kind == FamilyCompassApiErrorKind.offline) {
      return 'Compass could not reach the local AI service. Check the backend and LM Studio, then try again.';
    }
    return error.message;
  }

  String _messageFor(http.Response response) {
    if (response.statusCode == 503) {
      return 'Compass could not reach LM Studio. Make sure its local server and a model are running, then try again.';
    }
    if (response.statusCode == 403) {
      return 'Compass is not allowed to process this request with the configured provider.';
    }
    return 'Compass could not answer right now. Try again.';
  }

  static String _freshnessLabel(String? value) {
    final updatedAt = value == null ? null : DateTime.tryParse(value);
    if (updatedAt == null) return 'Time unavailable';
    final minutes =
        DateTime.now().toUtc().difference(updatedAt.toUtc()).inMinutes;
    if (minutes <= 0) return 'Just now';
    return '$minutes minutes ago';
  }

  static String? _firstSuggestedAction(Object? value) {
    if (value is! List || value.isEmpty || value.first is! String) return null;
    return value.first as String;
  }
}

class CompassConnectionException implements Exception {
  const CompassConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}
