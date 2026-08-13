import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum FamilyCompassApiErrorKind {
  offline,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  invalidRequest,
  unavailable,
  server,
  malformedResponse,
}

class FamilyCompassApiException implements Exception {
  const FamilyCompassApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.path,
  });

  final FamilyCompassApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? path;

  bool get canRetry =>
      kind == FamilyCompassApiErrorKind.offline ||
      kind == FamilyCompassApiErrorKind.unavailable ||
      kind == FamilyCompassApiErrorKind.server;

  @override
  String toString() => message;
}

abstract interface class ApiCredentialProvider {
  Map<String, String> get headers;
}

/// Credentials that can obtain a fresh bearer token after the backend rejects
/// an expired or revoked session.
///
/// Firebase implements this with `getIdToken(true)`. The API client retries a
/// request only once, and only after a 401 response, so ordinary server errors
/// and mutations are never replayed by this mechanism.
abstract interface class RefreshableApiCredentialProvider
    implements ApiCredentialProvider {
  Future<void> refresh({required bool force});
}

/// A short-lived signed development token or a verified Firebase ID token.
/// The mobile client never receives the signing secret.
class BearerApiSession implements ApiCredentialProvider {
  const BearerApiSession({required this.token});

  final String token;

  @override
  Map<String, String> get headers => <String, String>{
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}

class FamilyCompassApiClient {
  FamilyCompassApiClient({
    required String baseUrl,
    required this.credentials,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final ApiCredentialProvider credentials;
  final Duration timeout;
  final http.Client _client;

  Future<Object?> get(String path) => _send('GET', path);

  Future<Object?> post(String path, {Map<String, Object?>? body}) =>
      _send('POST', path, body: body);

  Future<Object?> patch(String path, {Map<String, Object?>? body}) =>
      _send('PATCH', path, body: body);

  Future<Object?> put(String path, {Map<String, Object?>? body}) =>
      _send('PUT', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  Future<Object?> sendQueued(QueuedHttpWrite request) => _send(
        request.method,
        request.path,
        body: request.body,
      );

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool retriedAfterRefresh = false,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      ...credentials.headers,
      if (body != null) 'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.offline,
        message: 'The Family Compass service did not respond in time.',
        path: path,
      );
    } on http.ClientException {
      throw FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.offline,
        message:
            'Family Compass is offline. Your safe pending writes remain queued.',
        path: path,
      );
    }

    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response.body, path: path);
    if (response.statusCode == 401 &&
        !retriedAfterRefresh &&
        credentials is RefreshableApiCredentialProvider) {
      final refreshable = credentials as RefreshableApiCredentialProvider;
      await refreshable.refresh(force: true);
      return _send(
        method,
        path,
        body: body,
        retriedAfterRefresh: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFor(response.statusCode, decoded, path);
    }
    return decoded;
  }

  Object? _decode(String body, {required String path}) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw FamilyCompassApiException(
        kind: FamilyCompassApiErrorKind.malformedResponse,
        message: 'The Family Compass service returned an unreadable response.',
        path: path,
      );
    }
  }

  FamilyCompassApiException _errorFor(
    int statusCode,
    Object? decoded,
    String path,
  ) {
    final detail =
        decoded is Map<String, dynamic> ? decoded['detail']?.toString() : null;
    final kind = switch (statusCode) {
      401 => FamilyCompassApiErrorKind.unauthorized,
      403 => FamilyCompassApiErrorKind.forbidden,
      404 => FamilyCompassApiErrorKind.notFound,
      409 => FamilyCompassApiErrorKind.conflict,
      422 => FamilyCompassApiErrorKind.invalidRequest,
      503 => FamilyCompassApiErrorKind.unavailable,
      >= 500 => FamilyCompassApiErrorKind.server,
      _ => FamilyCompassApiErrorKind.invalidRequest,
    };
    return FamilyCompassApiException(
      kind: kind,
      message: detail ?? _defaultMessage(kind),
      statusCode: statusCode,
      path: path,
    );
  }

  static String _defaultMessage(FamilyCompassApiErrorKind kind) =>
      switch (kind) {
        FamilyCompassApiErrorKind.unauthorized =>
          'Your development session is no longer valid.',
        FamilyCompassApiErrorKind.forbidden =>
          'You do not have permission for this family action.',
        FamilyCompassApiErrorKind.notFound =>
          'The requested family item is no longer available.',
        FamilyCompassApiErrorKind.conflict =>
          'This item changed on another device. Refresh and try again.',
        FamilyCompassApiErrorKind.invalidRequest =>
          'Check the information and try again.',
        FamilyCompassApiErrorKind.unavailable =>
          'The Family Compass service is temporarily unavailable.',
        FamilyCompassApiErrorKind.server =>
          'The Family Compass service could not complete the request.',
        FamilyCompassApiErrorKind.offline => 'Family Compass is offline.',
        FamilyCompassApiErrorKind.malformedResponse =>
          'The Family Compass service returned an unreadable response.',
      };

  void close() => _client.close();
}

/// Serializable HTTP write used by the conservative offline queue.
class QueuedHttpWrite {
  const QueuedHttpWrite({
    required this.id,
    required this.ownerUserId,
    required this.familyId,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    required this.idempotent,
    this.lastAttemptFailedAt,
  });

  final String id;
  final String ownerUserId;
  final String familyId;
  final String method;
  final String path;
  final Map<String, Object?> body;
  final DateTime createdAt;
  final bool idempotent;
  final DateTime? lastAttemptFailedAt;

  QueuedHttpWrite copyWith({
    DateTime? lastAttemptFailedAt,
    bool clearLastAttemptFailedAt = false,
  }) =>
      QueuedHttpWrite(
        id: id,
        ownerUserId: ownerUserId,
        familyId: familyId,
        method: method,
        path: path,
        body: body,
        createdAt: createdAt,
        idempotent: idempotent,
        lastAttemptFailedAt: clearLastAttemptFailedAt
            ? null
            : lastAttemptFailedAt ?? this.lastAttemptFailedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'owner_user_id': ownerUserId,
        'family_id': familyId,
        'method': method,
        'path': path,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
        'idempotent': idempotent,
        if (lastAttemptFailedAt != null)
          'last_attempt_failed_at':
              lastAttemptFailedAt!.toUtc().toIso8601String(),
      };

  static QueuedHttpWrite fromJson(Map<String, dynamic> json) => QueuedHttpWrite(
        id: json['id'] as String,
        ownerUserId: json['owner_user_id'] as String,
        familyId: json['family_id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        body: Map<String, Object?>.from(json['body'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
        idempotent: json['idempotent'] as bool,
        lastAttemptFailedAt: json['last_attempt_failed_at'] == null
            ? null
            : DateTime.parse(json['last_attempt_failed_at'] as String),
      );
}
