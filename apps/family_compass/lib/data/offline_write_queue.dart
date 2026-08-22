import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'family_compass_api_client.dart';

abstract interface class OfflineWriteStore {
  Future<List<QueuedHttpWrite>> load();

  Future<void> save(List<QueuedHttpWrite> writes);

  Future<void> clear();
}

class MemoryOfflineWriteStore implements OfflineWriteStore {
  List<QueuedHttpWrite> _writes = <QueuedHttpWrite>[];

  @override
  Future<List<QueuedHttpWrite>> load() async => List.of(_writes);

  @override
  Future<void> save(List<QueuedHttpWrite> writes) async {
    _writes = List.of(writes);
  }

  @override
  Future<void> clear() async {
    _writes = <QueuedHttpWrite>[];
  }
}

class SharedPreferencesOfflineWriteStore implements OfflineWriteStore {
  SharedPreferencesOfflineWriteStore(
    this.preferences, {
    required this.ownerUserId,
    required this.familyId,
  });

  static const legacyStorageKey = 'family_compass.pending_http_writes.v1';
  static const _storagePrefix = 'family_compass.pending_http_writes.v2';
  final SharedPreferences preferences;
  final String ownerUserId;
  final String familyId;

  String get storageKey => storageKeyFor(
        ownerUserId: ownerUserId,
        familyId: familyId,
      );

  static String storageKeyFor({
    required String ownerUserId,
    required String familyId,
  }) {
    final scope = base64Url
        .encode(utf8.encode('$ownerUserId\u0000$familyId'))
        .replaceAll('=', '');
    return '$_storagePrefix.$scope';
  }

  @override
  Future<List<QueuedHttpWrite>> load() async {
    // Version 1 entries did not record an owning account or family. They can
    // never be replayed safely, so remove them rather than guessing ownership.
    if (preferences.containsKey(legacyStorageKey)) {
      await preferences.remove(legacyStorageKey);
    }
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <QueuedHttpWrite>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await clear();
        return <QueuedHttpWrite>[];
      }
      final decodedWrites = decoded
          .whereType<Map>()
          .map(
            (value) => QueuedHttpWrite.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .where((write) => write.idempotent)
          .toList();
      final ownedWrites = decodedWrites
          .where(
            (write) =>
                write.ownerUserId == ownerUserId && write.familyId == familyId,
          )
          .toList();
      if (ownedWrites.length != decodedWrites.length) {
        await save(ownedWrites);
      }
      return ownedWrites;
    } on Object {
      // Corrupt local queue data is ignored instead of sending an uncertain
      // mutation. The UI can still refresh authoritative server state.
      await clear();
      return <QueuedHttpWrite>[];
    }
  }

  @override
  Future<void> save(List<QueuedHttpWrite> writes) => preferences.setString(
        storageKey,
        jsonEncode(writes.map((write) => write.toJson()).toList()),
      );

  @override
  Future<void> clear() => preferences.remove(storageKey);
}

class OfflineWriteFlushResult {
  const OfflineWriteFlushResult({
    this.sent = const <QueuedHttpWrite>[],
    this.rejected = const <QueuedHttpWrite>[],
  });

  final List<QueuedHttpWrite> sent;
  final List<QueuedHttpWrite> rejected;
}

class OfflineWriteFlushException implements Exception {
  const OfflineWriteFlushException({
    required this.cause,
    required this.partialResult,
  });

  final FamilyCompassApiException cause;
  final OfflineWriteFlushResult partialResult;

  @override
  String toString() => cause.toString();
}

class OfflineWriteQueue {
  OfflineWriteQueue({
    required this.api,
    required this.ownerUserId,
    required this.familyId,
    OfflineWriteStore? store,
  }) : store = store ?? MemoryOfflineWriteStore();

  final FamilyCompassApiClient api;
  final String ownerUserId;
  final String familyId;
  final OfflineWriteStore store;
  List<QueuedHttpWrite>? _cached;
  Future<OfflineWriteFlushResult>? _activeFlush;

  Future<List<QueuedHttpWrite>> get pending async =>
      List.unmodifiable(await _load());

  Future<int> get pendingCount async => (await _load()).length;

  Future<void> enqueue(QueuedHttpWrite write) async {
    if (!write.idempotent) {
      throw ArgumentError.value(
        write.path,
        'write',
        'Only explicitly idempotent requests may be queued.',
      );
    }
    if (write.ownerUserId != ownerUserId || write.familyId != familyId) {
      throw ArgumentError.value(
        '${write.ownerUserId}/${write.familyId}',
        'write',
        'Queued writes must belong to the active account and family.',
      );
    }
    final writes = await _load();
    if (writes.any((existing) => existing.id == write.id)) return;
    writes.add(write);
    await store.save(writes);
  }

  Future<void> remove(Set<String> writeIds) async {
    if (writeIds.isEmpty) return;
    final writes = await _load();
    writes.removeWhere((write) => writeIds.contains(write.id));
    await store.save(writes);
  }

  Future<void> clear() async {
    _cached = <QueuedHttpWrite>[];
    await store.clear();
  }

  Future<OfflineWriteFlushResult> flush() {
    final current = _activeFlush;
    if (current != null) return current;
    final operation = _flush();
    _activeFlush = operation;
    return operation.whenComplete(() => _activeFlush = null);
  }

  Future<OfflineWriteFlushResult> _flush() async {
    final writes = await _load();
    final sent = <QueuedHttpWrite>[];
    final rejected = <QueuedHttpWrite>[];
    while (writes.isNotEmpty) {
      var write = writes.first;
      if (write.lastAttemptFailedAt != null) {
        write = write.copyWith(clearLastAttemptFailedAt: true);
        writes[0] = write;
        await store.save(writes);
      }
      try {
        await api.sendQueued(write);
      } on FamilyCompassApiException catch (error) {
        if (error.canRetry) {
          writes[0] =
              write.copyWith(lastAttemptFailedAt: DateTime.now().toUtc());
          await store.save(writes);
          throw OfflineWriteFlushException(
            cause: error,
            partialResult: OfflineWriteFlushResult(
              sent: List.unmodifiable(sent),
              rejected: List.unmodifiable(rejected),
            ),
          );
        }
        // A permanent rejection must not loop forever or be silently retried.
        // Remove it and let the next authoritative refresh explain the state.
        rejected.add(write);
        writes.removeAt(0);
        await store.save(writes);
        continue;
      }
      sent.add(write);
      writes.removeAt(0);
      await store.save(writes);
    }
    return OfflineWriteFlushResult(
      sent: List.unmodifiable(sent),
      rejected: List.unmodifiable(rejected),
    );
  }

  Future<List<QueuedHttpWrite>> _load() async {
    final cached = _cached;
    if (cached != null) return cached;
    _cached = (await store.load())
        .where(
          (write) =>
              write.ownerUserId == ownerUserId && write.familyId == familyId,
        )
        .toList();
    return _cached!;
  }
}
