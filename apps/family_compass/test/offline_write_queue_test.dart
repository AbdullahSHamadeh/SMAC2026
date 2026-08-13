import 'dart:convert';

import 'package:family_compass/data/family_compass_api_client.dart';
import 'package:family_compass/data/http_family_compass_repositories.dart';
import 'package:family_compass/data/offline_write_queue.dart';
import 'package:family_compass/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';
const _familyA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _familyB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _clientId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('durable Chat queue is isolated by account and family and replays once',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final firstApi = _api((_) async => _json(const <Object>[]));
    final firstQueue = _queue(
      api: firstApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );
    final firstChat = HttpChatRepository(
      api: firstApi,
      queue: firstQueue,
      currentUserId: _userA,
    );

    await firstChat.sendText(
      familyId: _familyA,
      text: 'A private queued message',
      idempotencyKey: _clientId,
      mentionedMemberIds: const <String>{_userB},
      queueOnly: true,
    );
    expect(await firstQueue.pendingCount, 1);
    await firstChat.close();
    firstApi.close();

    var userBPosts = 0;
    final userBApi = _api((request) async {
      if (request.method == 'POST') userBPosts += 1;
      return _json(const <Object>[]);
    });
    final userBQueue = _queue(
      api: userBApi,
      preferences: preferences,
      ownerUserId: _userB,
      familyId: _familyA,
    );
    final userBChat = HttpChatRepository(
      api: userBApi,
      queue: userBQueue,
      currentUserId: _userB,
    );
    expect(await userBQueue.pendingCount, 0);
    await userBChat.retryPending();
    expect(userBPosts, 0);

    final otherFamilyApi = _api((_) async => _json(const <Object>[]));
    final otherFamilyQueue = _queue(
      api: otherFamilyApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyB,
    );
    expect(await otherFamilyQueue.pendingCount, 0);

    final accepted = <String, Map<String, Object?>>{};
    var postAttempts = 0;
    final restoredApi = _api((request) async {
      if (request.method == 'POST') {
        postAttempts += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final clientId = body['client_id'] as String;
        accepted.putIfAbsent(
          clientId,
          () => _messageJson(
            familyId: _familyA,
            senderId: _userA,
            clientId: clientId,
            body: body['body'] as String,
            mentionedMemberIds: (body['mentioned_member_ids'] as List<Object?>?)
                ?.cast<String>(),
          ),
        );
        return _json(accepted[clientId]!, statusCode: 201);
      }
      return _json(accepted.values.toList());
    });
    final restoredQueue = _queue(
      api: restoredApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );
    final restoredChat = HttpChatRepository(
      api: restoredApi,
      queue: restoredQueue,
      currentUserId: _userA,
    );

    final restored = await restoredChat.watchMessages(familyId: _familyA).first;
    expect(restored, hasLength(1));
    expect(restored.single.text, 'A private queued message');
    expect(restored.single.mentionedMemberIds, <String>{_userB});
    expect(
      restored.single.deliveryState,
      ChatDeliveryState.waitingToSend,
    );

    await Future.wait(<Future<void>>[
      restoredChat.retryPending(),
      restoredChat.retryPending(),
    ]);
    expect(postAttempts, 1);
    expect(accepted, hasLength(1));
    expect(await restoredQueue.pendingCount, 0);

    final sent = await restoredChat.watchMessages(familyId: _familyA).first;
    expect(sent.single.deliveryState, ChatDeliveryState.sent);
    expect(sent.single.mentionedMemberIds, <String>{_userB});
    await restoredChat.retryPending();
    expect(postAttempts, 1);

    await restoredChat.close();
    restoredApi.close();
    await userBChat.close();
    userBApi.close();
    otherFamilyApi.close();
  });

  test('failed retry survives restart and explicit clearing removes its scope',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final seedApi = _api((_) async => _json(const <Object>[]));
    final seedQueue = _queue(
      api: seedApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );
    final seedChat = HttpChatRepository(
      api: seedApi,
      queue: seedQueue,
      currentUserId: _userA,
    );
    await seedChat.sendText(
      familyId: _familyA,
      text: 'Retry me later',
      idempotencyKey: _clientId,
      queueOnly: true,
    );
    await seedChat.close();
    seedApi.close();

    final offlineApi = _api((request) async {
      if (request.method == 'POST') {
        throw http.ClientException('still offline');
      }
      return _json(const <Object>[]);
    });
    final offlineQueue = _queue(
      api: offlineApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );
    final offlineChat = HttpChatRepository(
      api: offlineApi,
      queue: offlineQueue,
      currentUserId: _userA,
    );
    expect(
      (await offlineChat.watchMessages(familyId: _familyA).first)
          .single
          .deliveryState,
      ChatDeliveryState.waitingToSend,
    );
    await expectLater(
      offlineChat.retryPending(),
      throwsA(isA<FamilyCompassApiException>()),
    );
    expect(
      (await offlineChat.watchMessages(familyId: _familyA).first)
          .single
          .deliveryState,
      ChatDeliveryState.failed,
    );
    await offlineChat.close();
    offlineApi.close();

    final restartedApi = _api((_) async => _json(const <Object>[]));
    final restartedQueue = _queue(
      api: restartedApi,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );
    final restartedChat = HttpChatRepository(
      api: restartedApi,
      queue: restartedQueue,
      currentUserId: _userA,
    );
    expect(
      (await restartedChat.watchMessages(familyId: _familyA).first)
          .single
          .deliveryState,
      ChatDeliveryState.failed,
    );

    final scopedKey = SharedPreferencesOfflineWriteStore.storageKeyFor(
      ownerUserId: _userA,
      familyId: _familyA,
    );
    expect(preferences.containsKey(scopedKey), isTrue);
    await restartedChat.discardPending(familyId: _familyA);
    expect(await restartedQueue.pendingCount, 0);
    expect(preferences.containsKey(scopedKey), isFalse);

    await restartedChat.close();
    restartedApi.close();
  });

  test('unowned legacy queue entries are deleted instead of guessed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesOfflineWriteStore.legacyStorageKey: jsonEncode(
        <Object>[
          <String, Object?>{
            'id': _clientId,
            'method': 'POST',
            'path': '/api/v1/families/$_familyA/messages',
            'body': <String, Object?>{
              'client_id': _clientId,
              'body': 'Legacy private text',
            },
            'created_at': '2026-08-13T10:00:00Z',
            'idempotent': true,
          },
        ],
      ),
    });
    final preferences = await SharedPreferences.getInstance();
    final api = _api((_) async => _json(const <Object>[]));
    final queue = _queue(
      api: api,
      preferences: preferences,
      ownerUserId: _userA,
      familyId: _familyA,
    );

    expect(await queue.pendingCount, 0);
    expect(
      preferences.containsKey(
        SharedPreferencesOfflineWriteStore.legacyStorageKey,
      ),
      isFalse,
    );
    api.close();
  });
}

OfflineWriteQueue _queue({
  required FamilyCompassApiClient api,
  required SharedPreferences preferences,
  required String ownerUserId,
  required String familyId,
}) =>
    OfflineWriteQueue(
      api: api,
      ownerUserId: ownerUserId,
      familyId: familyId,
      store: SharedPreferencesOfflineWriteStore(
        preferences,
        ownerUserId: ownerUserId,
        familyId: familyId,
      ),
    );

FamilyCompassApiClient _api(
  Future<http.Response> Function(http.Request request) handler,
) =>
    FamilyCompassApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      credentials: const BearerApiSession(token: 'test-token'),
      client: MockClient(handler),
    );

http.Response _json(Object value, {int statusCode = 200}) => http.Response(
      jsonEncode(value),
      statusCode,
      headers: <String, String>{'content-type': 'application/json'},
    );

Map<String, Object?> _messageJson({
  required String familyId,
  required String senderId,
  required String clientId,
  required String body,
  List<String>? mentionedMemberIds,
}) =>
    <String, Object?>{
      'id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'client_id': clientId,
      'family_id': familyId,
      'sender_id': senderId,
      'kind': 'text',
      'body': body,
      if (mentionedMemberIds != null)
        'mentioned_member_ids': mentionedMemberIds,
      'reference_id': null,
      'created_at': '2026-08-13T10:00:00Z',
    };
