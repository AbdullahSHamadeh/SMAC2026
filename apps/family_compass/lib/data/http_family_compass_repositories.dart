import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/chat_models.dart';
import '../domain/compass_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';
import 'api_mappers.dart';
import 'family_compass_api_client.dart';
import 'family_compass_repositories.dart';
import 'family_realtime_client.dart';
import 'http_compass_repository.dart';
import 'offline_write_queue.dart';

/// Builds every mobile repository around one authenticated FastAPI client.
class HttpFamilyCompassRepositoryBundle {
  HttpFamilyCompassRepositoryBundle._({
    required this.repositories,
    required this.api,
    required this.queue,
    required this.events,
    required List<HttpSyncableRepository> ownedRepositories,
  }) : _ownedRepositories = ownedRepositories;

  final FamilyCompassRepositories repositories;
  final FamilyCompassApiClient api;
  final OfflineWriteQueue queue;
  final FamilyRealtimeClient events;
  final List<HttpSyncableRepository> _ownedRepositories;

  static Future<HttpFamilyCompassRepositoryBundle> create({
    required String apiBaseUrl,
    required String familyId,
    required String currentUserId,
    String authToken = '',
    ApiCredentialProvider? credentials,
    SharedPreferences? preferences,
  }) async {
    final api = FamilyCompassApiClient(
      baseUrl: apiBaseUrl,
      credentials: credentials ?? BearerApiSession(token: authToken),
    );
    final queue = OfflineWriteQueue(
      api: api,
      ownerUserId: currentUserId,
      familyId: familyId,
      store: preferences == null
          ? MemoryOfflineWriteStore()
          : SharedPreferencesOfflineWriteStore(
              preferences,
              ownerUserId: currentUserId,
              familyId: familyId,
            ),
    );
    final events = FamilyRealtimeClient(
      apiBaseUrl: apiBaseUrl,
      familyId: familyId,
      credentials: api.credentials,
    );
    final session = HttpDevelopmentSessionRepository(api: api);
    final family = HttpFamilyRepository(api: api, currentUserId: currentUserId);
    final chat = HttpChatRepository(
      api: api,
      queue: queue,
      currentUserId: currentUserId,
    );
    final familyRoomCompass = HttpFamilyRoomCompassRepository(api: api);
    final plans = HttpPlanRepository(api: api, defaultFamilyId: familyId);
    final sharing = HttpSharingRepository(api: api, defaultFamilyId: familyId);
    final permissions = HttpPermissionRepository(
      api: api,
      currentUserId: currentUserId,
    );
    final checkIns = HttpCheckInRepository(api: api);
    final today = HttpTodayRepository(api: api);
    final journeys = HttpJourneyRepository(api: api);
    final reminders = HttpReminderRepository(api: api, plans: plans);
    final memberStatuses = HttpMemberStatusRepository(api: api);
    final devices = HttpDeviceRepository(api: api);
    final owned = <HttpSyncableRepository>[
      session,
      family,
      chat,
      familyRoomCompass,
      plans,
      sharing,
      permissions,
      checkIns,
      today,
      journeys,
      reminders,
      memberStatuses,
      devices,
    ];
    return HttpFamilyCompassRepositoryBundle._(
      api: api,
      queue: queue,
      events: events,
      ownedRepositories: owned,
      repositories: FamilyCompassRepositories(
        session: session,
        family: family,
        chat: chat,
        plans: plans,
        sharing: sharing,
        compass: HttpCompassRepository.fromApiClient(
          api: api,
          familyId: familyId,
        ),
        permissions: permissions,
        checkIns: checkIns,
        today: today,
        journeys: journeys,
        reminders: reminders,
        memberStatuses: memberStatuses,
        devices: devices,
        familyRoomCompass: familyRoomCompass,
      ),
    );
  }

  Future<void> dispose() async {
    for (final repository in _ownedRepositories) {
      await repository.close();
    }
    api.close();
  }

  /// Clears private queued content during an explicit account or family exit.
  /// Ordinary process disposal deliberately preserves it for offline recovery.
  Future<void> discardPendingWrites() => queue.clear();
}

abstract class HttpSyncableRepository implements SyncableRepository {
  HttpSyncableRepository({required this.api});

  final FamilyCompassApiClient api;
  final StreamController<RepositoryStatus> _statusController =
      StreamController<RepositoryStatus>.broadcast();
  RepositoryStatus _currentStatus = const RepositoryStatus.idle();

  @override
  Stream<RepositoryStatus> get status async* {
    yield _currentStatus;
    yield* _statusController.stream;
  }

  Future<T> runRequest<T>(Future<T> Function() operation) async {
    _setStatus(const RepositoryStatus(phase: RepositoryPhase.loading));
    try {
      final value = await operation();
      _setStatus(const RepositoryStatus(phase: RepositoryPhase.ready));
      return value;
    } on FamilyCompassApiException catch (error) {
      _setStatus(
        RepositoryStatus(
          phase: error.kind == FamilyCompassApiErrorKind.offline
              ? RepositoryPhase.offline
              : RepositoryPhase.failed,
          message: error.message,
          canRetry: error.canRetry,
        ),
      );
      rethrow;
    } on FormatException catch (error) {
      _setStatus(
        RepositoryStatus(
          phase: RepositoryPhase.failed,
          message: error.message,
          canRetry: true,
        ),
      );
      rethrow;
    }
  }

  void setOfflineWithPending(int pendingWrites) {
    _setStatus(
      RepositoryStatus(
        phase: RepositoryPhase.offline,
        message: pendingWrites == 1
            ? '1 message is waiting to send.'
            : '$pendingWrites messages are waiting to send.',
        pendingWrites: pendingWrites,
        canRetry: true,
      ),
    );
  }

  void _setStatus(RepositoryStatus value) {
    _currentStatus = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  @override
  Future<void> retryPending() => refresh();

  Future<void> close() => _statusController.close();
}

class HttpDevelopmentSessionRepository extends HttpSyncableRepository
    implements SessionRepository {
  HttpDevelopmentSessionRepository({required super.api});

  final StreamController<AppSession?> _controller =
      StreamController<AppSession?>.broadcast();
  AppSession? _session;
  bool _started = false;

  @override
  Stream<AppSession?> watchSession() async* {
    if (_session case final session?) yield session;
    if (!_started) unawaited(startDevelopmentSession());
    yield* _controller.stream;
  }

  @override
  Future<AppSession> startDevelopmentSession() => runRequest(() async {
        _started = true;
        final me =
            asJsonObject(await api.get('/api/v1/me'), label: 'Current user');
        final families = asJsonObjectList(
          await api.get('/api/v1/families'),
          label: 'Families',
        );
        final session = AppSession(
          userId: me['id'] as String,
          phoneNumber: '',
          familyIds: families.map((family) => family['id'] as String).toList(),
        );
        _session = session;
        _controller.add(session);
        return session;
      });

  @override
  Future<void> requestPhoneCode(String internationalPhoneNumber) =>
      Future<void>.error(
        const BackendCapabilityUnavailableException(
          'Real phone-code authentication',
        ),
      );

  @override
  Future<AppSession> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) =>
      Future<AppSession>.error(
        const BackendCapabilityUnavailableException(
          'Real phone-code authentication',
        ),
      );

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(null);
  }

  @override
  Future<void> refresh() async {
    await startDevelopmentSession();
  }

  @override
  Future<void> close() async {
    await _controller.close();
    await super.close();
  }
}

class HttpFamilyRepository extends HttpSyncableRepository
    implements FamilyRepository {
  HttpFamilyRepository({
    required super.api,
    required this.currentUserId,
  });

  final String currentUserId;
  final Map<String, FamilySummary> _families = <String, FamilySummary>{};
  final Map<String, List<FamilyInvitation>> _invitations =
      <String, List<FamilyInvitation>>{};
  final Map<String, StreamController<FamilySummary>> _familyControllers = {};
  final Map<String, StreamController<List<FamilyInvitation>>>
      _invitationControllers = {};

  @override
  Future<FamilySummary> createFamily(String name) => runRequest(() async {
        final value = asJsonObject(
          await api.post(
            '/api/v1/families',
            body: <String, Object?>{'name': name},
          ),
          label: 'Family',
        );
        return _fetchFamily(value['id'] as String);
      });

  @override
  Future<List<FamilySummary>> listFamilies() => runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families'),
          label: 'Families',
        );
        final families = await Future.wait(
          values.map((value) => _fetchFamily(value['id'] as String)),
        );
        return families;
      });

  @override
  Stream<FamilySummary> watchFamily(String familyId) async* {
    if (_families[familyId] case final cached?) yield cached;
    final controller = _familyControllers.putIfAbsent(
      familyId,
      () => StreamController<FamilySummary>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Stream<List<FamilyInvitation>> watchInvitations(String familyId) async* {
    if (_invitations[familyId] case final cached?) {
      yield List.unmodifiable(cached);
    }
    final controller = _invitationControllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyInvitation>>.broadcast(),
    );
    unawaited(_refreshInvitations(familyId));
    yield* controller.stream;
  }

  @override
  Future<FamilyInvitation> inviteByPhone({
    required String familyId,
    required String internationalPhoneNumber,
    required String idempotencyKey,
  }) =>
      runRequest(() async {
        final invitation = invitationFromApi(
          await api.post(
            '/api/v1/families/$familyId/invitations',
            body: <String, Object?>{
              'phone_number': internationalPhoneNumber,
              'role': 'adult',
            },
          ),
        );
        final values = <FamilyInvitation>[
          ...?_invitations[familyId],
          invitation,
        ];
        _invitations[familyId] = values;
        _invitationControllers[familyId]?.add(List.unmodifiable(values));
        return invitation;
      });

  @override
  Future<void> respondToInvitation({
    required String invitationId,
    required InvitationResponse response,
  }) =>
      runRequest(() async {
        final action =
            response == InvitationResponse.accept ? 'accept' : 'decline';
        await api.post('/api/v1/invitations/$invitationId/$action');
        await refresh();
      });

  @override
  Future<void> revokeInvitation(String invitationId) => runRequest(() async {
        final match = _invitations.entries
            .where(
              (entry) => entry.value.any(
                (invitation) => invitation.id == invitationId,
              ),
            )
            .firstOrNull;
        final familyId = match?.key;
        if (familyId == null) {
          throw const BackendCapabilityUnavailableException(
            'Revoking an invitation that has not been loaded',
          );
        }
        await api.post(
          '/api/v1/families/$familyId/invitations/$invitationId/revoke',
        );
        await _refreshInvitations(familyId);
      });

  @override
  Future<void> leaveFamily(String familyId) => runRequest(() async {
        await api.delete('/api/v1/families/$familyId/members/me');
        _families.remove(familyId);
        _invitations.remove(familyId);
        await refresh();
      });

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberId,
  }) =>
      runRequest(() async {
        await api.delete('/api/v1/families/$familyId/members/$memberId');
        await _refreshFamily(familyId);
      });

  @override
  Future<void> deleteFamily(String familyId) => runRequest(() async {
        await api.delete('/api/v1/families/$familyId');
        _families.remove(familyId);
        _invitations.remove(familyId);
        await refresh();
      });

  Future<FamilySummary> _fetchFamily(String familyId) async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      api.get('/api/v1/families/$familyId'),
      api.get('/api/v1/families/$familyId/members'),
    ]);
    final familyJson = asJsonObject(results[0], label: 'Family');
    final members = asJsonObjectList(results[1], label: 'Family members')
        .map((value) => memberFromApi(value, currentUserId: currentUserId))
        .toList();
    final family = FamilySummary(
      id: familyJson['id'] as String,
      name: familyJson['name'] as String,
      members: members,
      organizerId: familyJson['organizer_id'] as String?,
    );
    _families[familyId] = family;
    _familyControllers[familyId]?.add(family);
    return family;
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() => _fetchFamily(familyId));
    } on Object catch (error, stackTrace) {
      if (!_families.containsKey(familyId)) {
        _familyControllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  Future<void> _refreshInvitations(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/invitations'),
          label: 'Invitations',
        ).map(invitationFromApi).toList();
        _invitations[familyId] = values;
        _invitationControllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_invitations.containsKey(familyId)) {
        _invitationControllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    final familyIds = <String>{
      ..._families.keys,
      ..._familyControllers.keys,
      ..._invitationControllers.keys,
    };
    if (familyIds.isEmpty) {
      await listFamilies();
      return;
    }
    for (final familyId in familyIds) {
      await _refreshFamily(familyId);
      if (_invitationControllers.containsKey(familyId)) {
        await _refreshInvitations(familyId);
      }
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _familyControllers.values) {
      await controller.close();
    }
    for (final controller in _invitationControllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpChatRepository extends HttpSyncableRepository
    implements ChatRepository {
  HttpChatRepository({
    required super.api,
    required this.queue,
    required this.currentUserId,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final OfflineWriteQueue queue;
  final String currentUserId;
  final Uuid _uuid;
  final Map<String, List<ChatItem>> _messages = <String, List<ChatItem>>{};
  final Map<String, StreamController<List<ChatItem>>> _controllers = {};

  @override
  Stream<List<ChatItem>> watchMessages({
    required String familyId,
    String? afterMessageId,
  }) async* {
    await _restorePendingMessages(familyId);
    if (_messages[familyId] case final cached?) yield List.unmodifiable(cached);
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<ChatItem>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<ChatItem> getMessage({
    required String familyId,
    required String messageId,
  }) =>
      runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/messages'),
          label: 'Messages',
        ).map(chatItemFromApi).toList();
        for (final value in values) {
          _mergeMessage(familyId, value);
          if (value.id == messageId) return value;
        }
        throw FamilyCompassApiException(
          kind: FamilyCompassApiErrorKind.notFound,
          message: 'This family message is no longer available.',
          statusCode: 404,
          path: '/api/v1/families/$familyId/messages/$messageId',
        );
      });

  @override
  Future<ChatItem> sendText({
    required String familyId,
    required String text,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
    bool queueOnly = false,
  }) async {
    final clientId = _validUuid(idempotencyKey) ? idempotencyKey : _uuid.v4();
    final stableMentionIds = mentionedMemberIds.toList(growable: false)..sort();
    final path = '/api/v1/families/$familyId/messages';
    final body = <String, Object?>{
      'client_id': clientId,
      'body': text,
      if (stableMentionIds.isNotEmpty) 'mentioned_member_ids': stableMentionIds,
    };
    if (queueOnly) {
      return _enqueuePendingMessage(
        familyId: familyId,
        clientId: clientId,
        path: path,
        body: body,
      );
    }
    try {
      final item = await runRequest(
        () async => chatItemFromApi(await api.post(path, body: body)),
      );
      _mergeMessage(familyId, item);
      return item;
    } on FamilyCompassApiException catch (error) {
      if (!error.canRetry) rethrow;
      return _enqueuePendingMessage(
        familyId: familyId,
        clientId: clientId,
        path: path,
        body: body,
      );
    }
  }

  Future<ChatItem> _enqueuePendingMessage({
    required String familyId,
    required String clientId,
    required String path,
    required Map<String, Object?> body,
  }) async {
    final pending = ChatItem(
      id: 'pending-$clientId',
      clientId: clientId,
      kind: ChatItemKind.message,
      authorId: currentUserId,
      text: body['body'] as String,
      mentionedMemberIds: {
        for (final value in body['mentioned_member_ids'] as List<Object?>? ??
            const <Object?>[])
          if (value is String) value,
      },
      sentAt: DateTime.now().toUtc(),
      deliveryState: ChatDeliveryState.waitingToSend,
    );
    await queue.enqueue(
      QueuedHttpWrite(
        id: clientId,
        ownerUserId: currentUserId,
        familyId: familyId,
        method: 'POST',
        path: path,
        body: body,
        createdAt: pending.sentAt,
        idempotent: true,
      ),
    );
    _mergeMessage(familyId, pending);
    setOfflineWithPending(await queue.pendingCount);
    return pending;
  }

  Future<void> _restorePendingMessages(String familyId) async {
    final expectedPath = '/api/v1/families/$familyId/messages';
    for (final write in await queue.pending) {
      final text = write.body['body'];
      final clientId = write.body['client_id'];
      final rawMentionedMemberIds = write.body['mentioned_member_ids'];
      if (write.familyId != familyId ||
          write.path != expectedPath ||
          text is! String ||
          clientId is! String ||
          clientId != write.id) {
        continue;
      }
      _mergeMessage(
        familyId,
        ChatItem(
          id: 'pending-${write.id}',
          clientId: write.id,
          kind: ChatItemKind.message,
          authorId: currentUserId,
          text: text,
          mentionedMemberIds: {
            for (final value in rawMentionedMemberIds is List
                ? rawMentionedMemberIds
                : const <Object?>[])
              if (value is String) value,
          },
          sentAt: write.createdAt,
          deliveryState: write.lastAttemptFailedAt == null
              ? ChatDeliveryState.waitingToSend
              : ChatDeliveryState.failed,
        ),
      );
    }
    final pendingCount = await queue.pendingCount;
    if (pendingCount > 0) setOfflineWithPending(pendingCount);
  }

  void _mergeMessage(String familyId, ChatItem message) {
    final values = <ChatItem>[...?_messages[familyId]];
    values.removeWhere(
      (existing) =>
          existing.id == message.id ||
          (message.clientId != null && existing.clientId == message.clientId),
    );
    values.add(message);
    values.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    _messages[familyId] = values;
    _controllers[familyId]?.add(List.unmodifiable(values));
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final remote = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/messages'),
          label: 'Messages',
        ).map(chatItemFromApi).toList();
        final remoteClientIds =
            remote.map((item) => item.clientId).whereType<String>().toSet();
        await queue.remove(remoteClientIds);
        final pending = _messages[familyId]
                ?.where(
                  (item) => item.id.startsWith('pending-'),
                )
                .toList() ??
            const <ChatItem>[];
        final merged = <ChatItem>[
          ...remote,
          ...pending.where((item) => !remoteClientIds.contains(item.clientId)),
        ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        _messages[familyId] = merged;
        _controllers[familyId]?.add(List.unmodifiable(merged));
      });
    } on Object catch (error, stackTrace) {
      if (error is FamilyCompassApiException &&
          (error.kind == FamilyCompassApiErrorKind.unauthorized ||
              error.kind == FamilyCompassApiErrorKind.forbidden ||
              error.kind == FamilyCompassApiErrorKind.notFound)) {
        await discardPending(familyId: familyId);
      }
      if (!_messages.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> retryPending() async {
    final pendingBeforeRetry = await queue.pending;
    _setDeliveryState(
      pendingBeforeRetry.map((write) => write.id).toSet(),
      ChatDeliveryState.waitingToSend,
    );
    try {
      final result = await queue.flush();
      _applyFlushResult(result);
      await refresh();
      if (result.rejected.isNotEmpty) {
        _setStatus(
          const RepositoryStatus(
            phase: RepositoryPhase.failed,
            message: 'A queued message could not be sent.',
            canRetry: false,
          ),
        );
      }
    } on OfflineWriteFlushException catch (error) {
      _applyFlushResult(error.partialResult);
      _setDeliveryState(
        (await queue.pending).map((write) => write.id).toSet(),
        ChatDeliveryState.failed,
      );
      setOfflineWithPending(await queue.pendingCount);
      throw error.cause;
    }
  }

  void _applyFlushResult(OfflineWriteFlushResult result) {
    _setDeliveryState(
      result.sent.map((write) => write.id).toSet(),
      ChatDeliveryState.sent,
    );
    _setDeliveryState(
      result.rejected.map((write) => write.id).toSet(),
      ChatDeliveryState.failed,
    );
  }

  void _setDeliveryState(
    Set<String> clientIds,
    ChatDeliveryState deliveryState,
  ) {
    if (clientIds.isEmpty) return;
    for (final entry in _messages.entries) {
      var changed = false;
      final updated = entry.value.map((item) {
        if (item.clientId == null || !clientIds.contains(item.clientId)) {
          return item;
        }
        changed = changed || item.deliveryState != deliveryState;
        return item.copyWith(deliveryState: deliveryState);
      }).toList();
      if (!changed) continue;
      _messages[entry.key] = updated;
      _controllers[entry.key]?.add(List.unmodifiable(updated));
    }
  }

  @override
  Future<void> discardPending({required String familyId}) async {
    if (familyId != queue.familyId) return;
    await queue.clear();
    final messages = _messages[familyId];
    if (messages == null) return;
    final retained =
        messages.where((item) => !item.id.startsWith('pending-')).toList();
    _messages[familyId] = retained;
    _controllers[familyId]?.add(List.unmodifiable(retained));
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpFamilyRoomCompassRepository extends HttpSyncableRepository
    implements FamilyRoomCompassRepository {
  HttpFamilyRoomCompassRepository({required super.api});

  final Map<String, List<FamilyRoomCompassArtifact>> _artifacts =
      <String, List<FamilyRoomCompassArtifact>>{};
  final Map<String, StreamController<List<FamilyRoomCompassArtifact>>>
      _controllers =
      <String, StreamController<List<FamilyRoomCompassArtifact>>>{};

  @override
  Stream<List<FamilyRoomCompassArtifact>> watchArtifacts(
      String familyId) async* {
    if (_artifacts[familyId] case final cached?) {
      yield List.unmodifiable(cached);
    }
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyRoomCompassArtifact>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<FamilyRoomCompassArtifact> ask({
    required String familyId,
    required String prompt,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
  }) =>
      runRequest(() async {
        final stableMentionIds = mentionedMemberIds.toList(growable: false)
          ..sort();
        final response = asJsonObject(
          await api.post(
            '/api/v1/families/$familyId/compass/family-room',
            body: <String, Object?>{
              'client_id': idempotencyKey,
              'prompt': prompt,
              if (stableMentionIds.isNotEmpty)
                'mentioned_member_ids': stableMentionIds,
            },
          ),
          label: 'Family-room Compass exchange',
        );
        final artifact = familyRoomCompassArtifactFromApi(response['artifact']);
        _merge(familyId, artifact);
        return artifact;
      });

  void _merge(String familyId, FamilyRoomCompassArtifact artifact) {
    final values = <FamilyRoomCompassArtifact>[...?_artifacts[familyId]];
    values.removeWhere((value) => value.id == artifact.id);
    values.add(artifact);
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _artifacts[familyId] = values;
    _controllers[familyId]?.add(List.unmodifiable(values));
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/compass/family-room'),
          label: 'Family-room Compass artifacts',
        ).map(familyRoomCompassArtifactFromApi).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _artifacts[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_artifacts.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpPlanRepository extends HttpSyncableRepository
    implements PlanRepository {
  HttpPlanRepository({
    required super.api,
    required this.defaultFamilyId,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final String defaultFamilyId;
  final Uuid _uuid;
  final Map<String, List<FamilyPlan>> _plans = <String, List<FamilyPlan>>{};
  final Map<String, StreamController<List<FamilyPlan>>> _controllers = {};

  @override
  Future<FamilyPlan> createPlan({
    required String familyId,
    required String title,
    String? locationLabel,
    required List<String> participantIds,
    required List<CandidateTime> candidateTimes,
    required DateTime decisionDeadline,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.post(
            '/api/v1/families/$familyId/plans',
            body: <String, Object?>{
              'client_id': _uuid.v4(),
              'title': title,
              'location_label': locationLabel,
              'participant_ids': participantIds,
              'candidate_times': <Object>[
                for (final candidate in candidateTimes)
                  <String, Object>{
                    'id': candidate.id,
                    'starts_at': candidate.startsAt.toUtc().toIso8601String(),
                    'time_zone': candidate.timeZone,
                  },
              ],
              'decision_deadline': decisionDeadline.toUtc().toIso8601String(),
              'publish': false,
            },
          ),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Future<FamilyPlan> publishPlan({
    required String familyId,
    required String planId,
    required Set<String> candidateIds,
    required int expectedVersion,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.post(
            '/api/v1/families/$familyId/plans/$planId/publish',
            body: <String, Object?>{
              'candidate_ids': candidateIds.toList(growable: false),
              'expected_version': expectedVersion,
            },
          ),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Future<FamilyPlan> suggestCandidateTime({
    required String familyId,
    required String planId,
    required CandidateTime candidate,
    required int expectedVersion,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.post(
            '/api/v1/families/$familyId/plans/$planId/candidate-times',
            body: <String, Object?>{
              'candidate_time': <String, Object?>{
                'id': candidate.id,
                'starts_at': candidate.startsAt.toUtc().toIso8601String(),
                'time_zone': candidate.timeZone,
              },
              'expected_version': expectedVersion,
            },
          ),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Stream<List<FamilyPlan>> watchPlans(String familyId) async* {
    if (_plans[familyId] case final cached?) yield List.unmodifiable(cached);
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyPlan>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<FamilyPlan> getPlan({
    required String familyId,
    required String planId,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.get('/api/v1/families/$familyId/plans/$planId'),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Future<FamilyPlan> getPlanForReminder({
    required String familyId,
    required String reminderId,
  }) =>
      runRequest(() async {
        final plans = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/plans'),
          label: 'Plans',
        ).map(planFromApi).toList();
        for (final plan in plans) {
          _mergePlan(familyId, plan);
          if (plan.reminders.any((reminder) => reminder.id == reminderId)) {
            return plan;
          }
        }
        throw FamilyCompassApiException(
          kind: FamilyCompassApiErrorKind.notFound,
          message: 'This family reminder is no longer available.',
          statusCode: 404,
          path: '/api/v1/families/$familyId/reminders/$reminderId',
        );
      });

  @override
  Future<FamilyPlan> saveResponse({
    required String planId,
    required String candidateId,
    required RsvpChoice choice,
    required int expectedVersion,
  }) =>
      _mutatePlan(
        '/api/v1/families/$defaultFamilyId/plans/$planId/responses',
        <String, Object?>{
          'candidate_id': candidateId,
          'choice': _rsvpValue(choice),
          'expected_version': expectedVersion,
        },
      );

  @override
  Future<FamilyPlan> confirmPlan({
    required String planId,
    required String candidateId,
    required int expectedVersion,
  }) =>
      _mutatePlan(
        '/api/v1/families/$defaultFamilyId/plans/$planId/confirm',
        <String, Object?>{
          'candidate_id': candidateId,
          'expected_version': expectedVersion,
        },
      );

  @override
  Future<FamilyPlan> addContribution({
    required String familyId,
    required String planId,
    required String text,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.post(
            '/api/v1/families/$familyId/plans/$planId/contributions',
            body: <String, Object?>{'text': text},
          ),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Future<FamilyPlan> sendNudge({
    required String familyId,
    required String planId,
  }) =>
      runRequest(() async {
        await api.post('/api/v1/families/$familyId/plans/$planId/nudge');
        // A zero-recipient response can mean another request already delivered
        // the nudge or that delivery failed. Reload the authoritative timestamps
        // instead of inferring success from HTTP 200.
        final plan = await getPlan(familyId: familyId, planId: planId);
        _mergePlan(familyId, plan);
        return plan;
      });

  @override
  Future<FamilyPlan> completePlan({
    required String familyId,
    required String planId,
  }) =>
      runRequest(() async {
        final plan = planFromApi(
          await api.post(
            '/api/v1/families/$familyId/plans/$planId/complete',
          ),
        );
        _mergePlan(familyId, plan);
        return plan;
      });

  Future<FamilyPlan> _mutatePlan(
    String path,
    Map<String, Object?> body,
  ) =>
      runRequest(() async {
        final plan = planFromApi(await api.post(path, body: body));
        _mergePlan(defaultFamilyId, plan);
        return plan;
      });

  void _mergePlan(String familyId, FamilyPlan plan) {
    final values = <FamilyPlan>[...?_plans[familyId]];
    values.removeWhere((existing) => existing.id == plan.id);
    values.add(plan);
    _plans[familyId] = values;
    _controllers[familyId]?.add(List.unmodifiable(values));
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/plans'),
          label: 'Plans',
        ).map(planFromApi).toList();
        _plans[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_plans.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    final ids = _controllers.keys.isEmpty
        ? <String>[defaultFamilyId]
        : _controllers.keys.toList();
    for (final familyId in ids) {
      await _refreshFamily(familyId);
    }
  }

  List<FamilyPlan> cachedPlans(String familyId) =>
      List.unmodifiable(_plans[familyId] ?? const <FamilyPlan>[]);

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpSharingRepository extends HttpSyncableRepository
    implements SharingRepository {
  HttpSharingRepository({required super.api, required this.defaultFamilyId});

  final String defaultFamilyId;
  final Map<String, List<SharedStatus>> _statuses = {};
  final Map<String, StreamController<List<SharedStatus>>> _controllers = {};

  @override
  Stream<List<SharedStatus>> watchPermittedStatuses(String familyId) async* {
    if (_statuses[familyId] case final cached?) yield List.unmodifiable(cached);
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<SharedStatus>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<SharedStatus> shareManualStatus({
    required String familyId,
    required String text,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) =>
      runRequest(() async {
        final status = sharedStatusFromApi(
          await api.post(
            '/api/v1/families/$familyId/shared-updates',
            body: <String, Object?>{
              'text': text,
              'expires_at': expiresAt.toUtc().toIso8601String(),
              'audience': _audienceValue(audience),
              'selected_member_ids': recipientIds.toList(),
            },
          ),
        );
        _mergeStatus(familyId, status);
        return status;
      });

  @override
  Future<void> pauseStatus(String statusId) => _changeState(statusId, 'paused');

  @override
  Future<void> revokeStatus(String statusId) =>
      _changeState(statusId, 'revoked');

  Future<void> _changeState(String statusId, String state) =>
      runRequest(() async {
        final status = sharedStatusFromApi(
          await api.patch(
            '/api/v1/families/$defaultFamilyId/shared-updates/$statusId',
            body: <String, Object?>{'state': state},
          ),
        );
        _mergeStatus(defaultFamilyId, status);
      });

  void _mergeStatus(String familyId, SharedStatus status) {
    final values = <SharedStatus>[...?_statuses[familyId]];
    values.removeWhere((existing) => existing.id == status.id);
    values.add(status);
    _statuses[familyId] = values;
    _controllers[familyId]?.add(List.unmodifiable(values));
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/shared-updates'),
          label: 'Shared updates',
        ).map(sharedStatusFromApi).toList();
        _statuses[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_statuses.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    final ids = _controllers.keys.isEmpty
        ? <String>[defaultFamilyId]
        : _controllers.keys.toList();
    for (final familyId in ids) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpPermissionRepository extends HttpSyncableRepository
    implements PermissionRepository {
  HttpPermissionRepository({
    required super.api,
    required this.currentUserId,
  });

  final String currentUserId;
  final Map<String, List<FamilyPermission>> _permissions = {};
  final Map<String, StreamController<List<FamilyPermission>>> _controllers = {};

  @override
  Stream<List<FamilyPermission>> watchPermissions(String familyId) async* {
    if (_permissions[familyId] case final cached?) {
      yield List.unmodifiable(cached);
    }
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyPermission>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<FamilyPermission> setInvitePermission({
    required String familyId,
    required String memberId,
    required bool canInvite,
  }) =>
      runRequest(() async {
        final memberJson = await api.patch(
          '/api/v1/families/$familyId/permissions/$memberId',
          body: <String, Object?>{'can_invite': canInvite},
        );
        final member = memberFromApi(memberJson, currentUserId: currentUserId);
        final permission =
            FamilyPermission(member: member, canInvite: canInvite);
        final values = <FamilyPermission>[...?_permissions[familyId]];
        values.removeWhere((value) => value.member.id == memberId);
        values.add(permission);
        _permissions[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
        return permission;
      });

  @override
  Future<void> setExternalAIConsent({
    required String familyId,
    required bool allowed,
  }) =>
      runRequest(() async {
        await api.patch(
          '/api/v1/families/$familyId/me/ai-consent',
          body: <String, Object?>{'allow_external_ai_processing': allowed},
        );
      });

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/permissions'),
          label: 'Permissions',
        )
            .map((value) => memberFromApi(value, currentUserId: currentUserId))
            .map(
              (member) => FamilyPermission(
                member: member,
                canInvite: member.canInvite,
              ),
            )
            .toList();
        _permissions[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_permissions.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpCheckInRepository extends HttpSyncableRepository
    implements CheckInRepository {
  HttpCheckInRepository({required super.api});

  @override
  Future<FamilyCheckIn> request({
    required String familyId,
    required String memberId,
  }) =>
      runRequest(() async => checkInFromApi(
            await api.post(
              '/api/v1/families/$familyId/check-ins',
              body: <String, Object?>{'subject_user_id': memberId},
            ),
          ));

  @override
  Future<void> refresh() async {}
}

class HttpTodayRepository extends HttpSyncableRepository
    implements TodayRepository {
  HttpTodayRepository({required super.api});

  final Map<String, TodayOverview> _today = {};
  final Map<String, StreamController<TodayOverview>> _controllers = {};

  @override
  Stream<TodayOverview> watchToday(String familyId) async* {
    if (_today[familyId] case final cached?) yield cached;
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<TodayOverview>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final json = asJsonObject(
          await api.get('/api/v1/families/$familyId/today'),
          label: 'Today',
        );
        final suggestionJson = json['suggestion'];
        final suggestion = suggestionJson == null
            ? null
            : asJsonObject(suggestionJson, label: 'Suggestion');
        final overview = TodayOverview(
          nextPlan:
              json['next_plan'] == null ? null : planFromApi(json['next_plan']),
          needsReply: asJsonObjectList(
            json['needs_reply'],
            label: 'Plans needing a reply',
          ).map(planFromApi).toList(),
          sharedUpdates: asJsonObjectList(
            json['shared_updates'],
            label: 'Today shared updates',
          ).map(sharedStatusFromApi).toList(),
          suggestion: suggestion == null
              ? null
              : FamilySuggestion(
                  id: suggestion['id'] as String,
                  title: suggestion['title'] as String,
                  reason: suggestion['reason'] as String,
                  actionLabel: suggestion['action_label'] as String,
                ),
        );
        _today[familyId] = overview;
        _controllers[familyId]?.add(overview);
      });
    } on Object catch (error, stackTrace) {
      if (!_today.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpJourneyRepository extends HttpSyncableRepository
    implements JourneyRepository {
  HttpJourneyRepository({required super.api});

  final Map<String, List<FamilyJourney>> _journeys = {};
  final Map<String, StreamController<List<FamilyJourney>>> _controllers = {};

  @override
  Future<FamilyJourney> createJourney({
    required String familyId,
    required String summary,
    required String status,
    DateTime? eta,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) =>
      runRequest(() async {
        final journey = journeyFromApi(
          await api.post(
            '/api/v1/families/$familyId/journeys',
            body: <String, Object?>{
              'summary': summary,
              'status': status,
              'eta': eta?.toUtc().toIso8601String(),
              'audience': _audienceValue(audience),
              'selected_member_ids': recipientIds.toList(),
              'expires_at': expiresAt.toUtc().toIso8601String(),
            },
          ),
        );
        await _refreshFamily(familyId);
        return journey;
      });

  @override
  Future<void> endJourney({
    required String familyId,
    required String journeyId,
    bool completed = true,
  }) =>
      runRequest(() async {
        await api.patch(
          '/api/v1/families/$familyId/journeys/$journeyId',
          body: <String, Object?>{
            'state': completed ? 'completed' : 'cancelled',
          },
        );
        await _refreshFamily(familyId);
      });

  @override
  Stream<List<FamilyJourney>> watchJourneys(String familyId) async* {
    if (_journeys[familyId] case final cached?) yield List.unmodifiable(cached);
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyJourney>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/journeys'),
          label: 'Journeys',
        ).map(journeyFromApi).toList();
        _journeys[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on FamilyCompassApiException catch (error, stackTrace) {
      final reported = error.kind == FamilyCompassApiErrorKind.notFound
          ? const BackendCapabilityUnavailableException(
              'Temporary journey summaries',
            )
          : error;
      if (!_journeys.containsKey(familyId)) {
        _controllers[familyId]?.addError(reported, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpReminderRepository extends HttpSyncableRepository
    implements ReminderRepository {
  HttpReminderRepository({required super.api, required this.plans});

  final HttpPlanRepository plans;

  @override
  Stream<List<PlanReminder>> watchReminders(String familyId) => plans
      .watchPlans(familyId)
      .map((values) => values.expand((plan) => plan.reminders).toList());

  @override
  Future<PlanReminder> createReminder({
    required String familyId,
    required String planId,
    required String label,
    required DateTime at,
  }) async {
    try {
      return await runRequest(() async => reminderFromApi(
            await api.post(
              '/api/v1/families/$familyId/plans/$planId/reminders',
              body: <String, Object?>{
                'label': label,
                'at': at.toUtc().toIso8601String(),
              },
            ),
          ));
    } on FamilyCompassApiException catch (error) {
      if (error.kind == FamilyCompassApiErrorKind.notFound) {
        throw const BackendCapabilityUnavailableException(
          'Standalone reminder creation',
        );
      }
      rethrow;
    }
  }

  @override
  Future<PlanReminder> updateReminder({
    required String familyId,
    required String reminderId,
    required DateTime at,
  }) async {
    final reminder = await runRequest(() async => reminderFromApi(
          await api.patch(
            '/api/v1/families/$familyId/reminders/$reminderId',
            body: <String, Object?>{
              'at': at.toUtc().toIso8601String(),
            },
          ),
        ));
    await plans.refresh();
    return reminder;
  }

  @override
  Future<void> refresh() => plans.refresh();
}

class HttpMemberStatusRepository extends HttpSyncableRepository
    implements MemberStatusRepository {
  HttpMemberStatusRepository({required super.api});

  final Map<String, List<MemberStatusSummary>> _statuses = {};
  final Map<String, StreamController<List<MemberStatusSummary>>> _controllers =
      {};

  @override
  Stream<List<MemberStatusSummary>> watchStatuses(String familyId) async* {
    if (_statuses[familyId] case final cached?) yield List.unmodifiable(cached);
    final controller = _controllers.putIfAbsent(
      familyId,
      () => StreamController<List<MemberStatusSummary>>.broadcast(),
    );
    unawaited(_refreshFamily(familyId));
    yield* controller.stream;
  }

  @override
  Future<MemberStatusSummary> updateOwnStatus({
    required String familyId,
    required String summary,
    String? detail,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  }) =>
      runRequest(() async {
        final status = memberStatusFromApi(
          await api.put(
            '/api/v1/families/$familyId/statuses/me',
            body: <String, Object?>{
              'summary': summary,
              'detail': detail,
              'audience': _audienceValue(audience),
              'selected_member_ids': recipientIds.toList(),
              'expires_at': expiresAt.toUtc().toIso8601String(),
            },
          ),
        );
        await _refreshFamily(familyId);
        return status;
      });

  @override
  Future<void> setStatusState({
    required String familyId,
    required String statusId,
    required SharingState state,
  }) =>
      runRequest(() async {
        await api.patch(
          '/api/v1/families/$familyId/statuses/$statusId',
          body: <String, Object?>{
            'state': switch (state) {
              SharingState.active => 'active',
              SharingState.paused => 'paused',
              SharingState.revoked || SharingState.notSharing => 'revoked',
            },
          },
        );
        await _refreshFamily(familyId);
      });

  Future<void> _refreshFamily(String familyId) async {
    try {
      await runRequest(() async {
        final values = asJsonObjectList(
          await api.get('/api/v1/families/$familyId/statuses'),
          label: 'Member statuses',
        ).map(memberStatusFromApi).toList();
        _statuses[familyId] = values;
        _controllers[familyId]?.add(List.unmodifiable(values));
      });
    } on Object catch (error, stackTrace) {
      if (!_statuses.containsKey(familyId)) {
        _controllers[familyId]?.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final familyId in _controllers.keys) {
      await _refreshFamily(familyId);
    }
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    await super.close();
  }
}

class HttpDeviceRepository extends HttpSyncableRepository
    implements DeviceRepository {
  HttpDeviceRepository({required super.api});

  @override
  Future<List<DeviceRegistration>> listDevices() =>
      runRequest(() async => asJsonObjectList(
            await api.get('/api/v1/me/device-tokens'),
            label: 'Device registrations',
          ).map(deviceFromApi).toList());

  @override
  Future<DeviceRegistration> register({
    required String token,
    required DevicePlatform platform,
  }) =>
      runRequest(() async => deviceFromApi(
            await api.post(
              '/api/v1/me/device-tokens',
              body: <String, Object?>{
                'token': token,
                'platform': platform.name,
              },
            ),
          ));

  @override
  Future<void> unregister(String deviceId) => runRequest(() async {
        await api.delete('/api/v1/me/device-tokens/$deviceId');
      });

  @override
  Future<void> refresh() async {
    await listDevices();
  }
}

bool _validUuid(String value) => RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);

String _rsvpValue(RsvpChoice choice) => switch (choice) {
      RsvpChoice.going => 'going',
      RsvpChoice.maybe => 'maybe',
      RsvpChoice.cannotMakeIt => 'cannot_make_it',
    };

String _audienceValue(SharingAudience audience) => switch (audience) {
      SharingAudience.wholeFamily => 'whole_family',
      SharingAudience.selectedPeople => 'selected_people',
      SharingAudience.onlyMe => 'self_only',
    };
