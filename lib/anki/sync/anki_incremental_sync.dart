import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/anki_database.dart';
import '../models/note.dart';
import 'anki_sync_protocol_client.dart';
import 'anki_sync_destination_state.dart';

/// Executes Anki's v10 collection sync sequence against a local schema 11
/// collection. Every local SQLite mutation is held in a single transaction;
/// the server transaction is aborted if any request or validation fails.
class AnkiIncrementalSync {
  const AnkiIncrementalSync._();

  static const int _chunkSize = 250;

  static Future<AnkiCollectionSyncResult> sync(
    AnkiDatabase collection,
    AnkiSyncProtocolClient client,
  ) async {
    final db = collection.db;
    final destination = client.destinationIdentity;
    await _requireSameDestination(db, destination);
    final remote = await client.checkStatus();
    if (!remote.shouldContinue) {
      throw AnkiSyncException(
        remote.message.isEmpty ? '同步服务器要求更新客户端' : remote.message,
      );
    }

    final localRows = await db.query('col', columns: ['mod', 'scm', 'usn']);
    if (localRows.isEmpty) {
      throw const AnkiSyncException('本地 collection 缺少元数据');
    }
    final local = localRows.first;
    final localModified = _int(local['mod']);
    final localSchema = _int(local['scm']);
    final localUsn = _int(local['usn']);
    final hasPending = await _hasPendingChanges(db);
    final needsCollectionSync = localModified != remote.modified ||
        localUsn != remote.usn ||
        hasPending;

    if (localSchema != remote.schema) {
      throw const AnkiSyncFullTransferRequired(
        '本地和服务器的 collection 结构版本不同，请先选择完整上传或下载',
      );
    }

    if (!needsCollectionSync) {
      await db.transaction((txn) async {
        await _requireSameDestination(txn, destination);
        await AnkiSyncDestinationState.mark(txn, destination);
      });
      return const AnkiCollectionSyncResult(
        changedCards: 0,
        changedNotes: 0,
        changedReviews: 0,
        collectionChanged: false,
      );
    }

    final delta =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - remote.serverTime;
    if (remote.serverTime != 0 && delta.abs() > 300) {
      throw const AnkiSyncException('设备时间与同步服务器相差超过 5 分钟');
    }

    try {
      final result = await db.transaction((txn) async {
        await _requireSameDestination(txn, destination);
        final start = await client.requestJson('start', {
          'minUsn': localUsn,
          'lnewer': localModified > remote.modified,
        });
        if (start is! Map<String, dynamic>) {
          throw const AnkiSyncException('同步服务器 start 响应无法解析');
        }

        final rawGraves = start['graves'];
        if (rawGraves is! Map) {
          throw const AnkiSyncException('同步服务器 start 响应缺少有效的 graves');
        }
        final incomingGraves = _map(rawGraves);
        await _sendAndApplyGraves(txn, client, incomingGraves, remote.usn);
        await _exchangeUnchunkedChanges(
          txn,
          client,
          serverUsn: remote.usn,
          localIsNewer: localModified > remote.modified,
        );

        var receivedCards = 0;
        var receivedNotes = 0;
        var receivedReviews = 0;
        while (true) {
          final payload = await client.requestJson('chunk', const {});
          if (payload is! Map<String, dynamic>) {
            throw const AnkiSyncException('同步服务器 chunk 响应无法解析');
          }
          final chunk = _map(payload);
          final done = chunk['done'];
          if (done is! bool) {
            throw const AnkiSyncException('同步服务器 chunk 响应缺少有效的 done 状态');
          }
          receivedCards += await _applyRemoteCards(
            txn,
            _chunkList(chunk, 'cards'),
          );
          receivedNotes += await _applyRemoteNotes(
            txn,
            _chunkList(chunk, 'notes'),
          );
          receivedReviews += await _applyRemoteReviews(
            txn,
            _chunkList(chunk, 'revlog'),
          );
          if (done) break;
        }

        final sent = await _sendLocalChunks(txn, client, remote.usn);
        await _checkSanity(txn, client);

        final finish = await client.requestJson('finish', const {});
        if (finish is! num) {
          throw const AnkiSyncException('同步服务器 finish 响应无法解析');
        }
        final finishedAt = finish.toInt();
        final nextUsn = remote.usn + 1;
        await txn.update(
            'col',
            {
              'ls': finishedAt,
              'usn': nextUsn,
              'mod': finishedAt,
            },
            where: 'id = 1');
        await AnkiSyncDestinationState.mark(txn, destination);
        return AnkiCollectionSyncResult(
          changedCards: receivedCards + sent.cards,
          changedNotes: receivedNotes + sent.notes,
          changedReviews: receivedReviews + sent.reviews,
          collectionChanged: true,
        );
      });
      await collection.col.reload();
      return result;
    } catch (_) {
      try {
        await client.requestJson('abort', const {});
      } catch (_) {
        // Keep the original failure; the server session will expire if abort
        // could not be delivered.
      }
      rethrow;
    }
  }

  static Future<void> _requireSameDestination(
    DatabaseExecutor db,
    String destination,
  ) async {
    final existing = await AnkiSyncDestinationState.read(db);
    if (existing != null && existing != destination) {
      throw const AnkiSyncFullTransferRequired(
        '此 collection 上次与其他同步账号或服务器同步。切换目标前请先完整上传或下载',
      );
    }
  }

  static Future<void> _sendAndApplyGraves(
    Transaction txn,
    AnkiSyncProtocolClient client,
    Map<String, dynamic> remote,
    int serverUsn,
  ) async {
    final localRows = await txn.query('graves', where: 'usn = -1');
    final sentGraves =
        localRows.map((row) => (_int(row['type']), _int(row['oid']))).toSet();
    if (localRows.isNotEmpty) {
      await txn.update('graves', {'usn': serverUsn}, where: 'usn = -1');
    }
    for (var offset = 0; offset < localRows.length; offset += _chunkSize) {
      final end = (offset + _chunkSize).clamp(0, localRows.length);
      final batchRows = localRows.sublist(offset, end);
      final chunk = <String, List<int>>{'cards': [], 'notes': [], 'decks': []};
      for (final row in batchRows) {
        final type = _int(row['type']);
        final key = switch (type) {
          0 => 'cards',
          1 => 'notes',
          2 => 'decks',
          _ => null,
        };
        if (key != null) chunk[key]!.add(_int(row['oid']));
      }
      await client.requestJson('applyGraves', {'chunk': chunk});
    }

    final cards = _graveIds(remote['cards'], 'cards');
    final notes = _graveIds(remote['notes'], 'notes');
    final decks = _graveIds(remote['decks'], 'decks');
    for (final id in cards) {
      await _retainRemoteGrave(txn, id, 0, sentGraves);
      await txn.delete('revlog', where: 'cid = ?', whereArgs: [id]);
      await txn.delete('cards', where: 'id = ?', whereArgs: [id]);
    }
    for (final id in notes) {
      await _retainRemoteGrave(txn, id, 1, sentGraves);
      final cards = await txn.query(
        'cards',
        columns: ['id'],
        where: 'nid = ?',
        whereArgs: [id],
      );
      for (final card in cards) {
        await txn.delete('revlog', where: 'cid = ?', whereArgs: [card['id']]);
      }
      await txn.delete('cards', where: 'nid = ?', whereArgs: [id]);
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
    }
    if (decks.isNotEmpty) {
      final rows = await txn.query('col', columns: ['decks'], where: 'id = 1');
      final deckMap = _decodeObject(rows.first['decks']);
      for (final id in decks) {
        await _retainRemoteGrave(txn, id, 2, sentGraves);
        deckMap.remove(id.toString());
      }
      final configRows = await txn.query(
        'col',
        columns: ['conf'],
        where: 'id = 1',
      );
      final collectionConfig = _decodeObject(configRows.first['conf']);
      final survivingDeckIds = <int>{};
      int? fallbackDeckId;
      for (final entry in deckMap.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        survivingDeckIds.add(id);
        final deck = entry.value;
        if (fallbackDeckId == null &&
            (deck is! Map || _int(deck['dyn']) != 1)) {
          fallbackDeckId = id;
        }
      }
      int? deckIdFrom(Object? value) {
        if (value is num && value.toInt() == value) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      final activeDecks = <int>[];
      final configuredActiveDecks = collectionConfig['activeDecks'];
      if (configuredActiveDecks is List) {
        for (final value in configuredActiveDecks) {
          final id = deckIdFrom(value);
          if (id != null &&
              survivingDeckIds.contains(id) &&
              !activeDecks.contains(id)) {
            activeDecks.add(id);
          }
        }
      }
      final currentDeckId = deckIdFrom(collectionConfig['curDeck']);
      final selectedDeckId =
          currentDeckId != null && survivingDeckIds.contains(currentDeckId)
              ? currentDeckId
              : activeDecks.isNotEmpty
                  ? activeDecks.first
                  : fallbackDeckId;
      if (selectedDeckId != null && !activeDecks.contains(selectedDeckId)) {
        activeDecks.add(selectedDeckId);
      }
      collectionConfig['curDeck'] = selectedDeckId ?? 0;
      collectionConfig['activeDecks'] = activeDecks;
      await txn.update(
          'col',
          {
            'decks': jsonEncode(deckMap),
            'conf': jsonEncode(collectionConfig),
          },
          where: 'id = 1');
    }
  }

  static Future<void> _retainRemoteGrave(
    Transaction txn,
    int oid,
    int type,
    Set<(int, int)> sentGraves,
  ) async {
    // A matching local tombstone was already sent in this session. Other
    // incoming graves stay pending so the next configured sync destination
    // receives the deletion too.
    if (sentGraves.contains((type, oid))) return;
    final existing = await txn.query(
      'graves',
      columns: ['usn'],
      where: 'oid = ? AND type = ?',
      whereArgs: [oid, type],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert('graves', {'usn': -1, 'oid': oid, 'type': type});
    } else {
      await txn.update(
        'graves',
        {'usn': -1},
        where: 'oid = ? AND type = ?',
        whereArgs: [oid, type],
      );
    }
  }

  static Future<void> _exchangeUnchunkedChanges(
    Transaction txn,
    AnkiSyncProtocolClient client, {
    required int serverUsn,
    required bool localIsNewer,
  }) async {
    final colRows = await txn.query(
      'col',
      columns: ['models', 'decks', 'tags', 'conf', 'crt', 'dconf'],
      where: 'id = 1',
    );
    final row = colRows.first;
    final models = _decodeObject(row['models']);
    final decks = _decodeObject(row['decks']);
    final tags = _decodeObject(row['tags']);
    final deckConfigMap = _decodeObject(row['dconf']);
    final collectionConfig = _decodeObject(row['conf']);

    final changedModels = <Map<String, dynamic>>[];
    for (final entry in models.entries) {
      if (entry.value is Map && _int(entry.value['usn']) < 0) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        value['usn'] = serverUsn;
        changedModels.add(value);
        models[entry.key] = value;
      }
    }
    final changedDecks = <Map<String, dynamic>>[];
    for (final entry in decks.entries) {
      if (entry.value is Map && _int(entry.value['usn']) < 0) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        value['usn'] = serverUsn;
        changedDecks.add(value);
        decks[entry.key] = value;
      }
    }
    final changedTags = <String>[];
    for (final entry in tags.entries) {
      if (_int(entry.value) < 0) {
        changedTags.add(entry.key);
        tags[entry.key] = serverUsn;
      }
    }

    final deckConfigRows = await txn.query('deck_config', where: 'usn < 0');
    final changedDeckConfigs = <List<dynamic>>[];
    for (final config in deckConfigRows) {
      await txn.update(
        'deck_config',
        {'usn': serverUsn},
        where: 'id = ?',
        whereArgs: [config['id']],
      );
      changedDeckConfigs.add([
        _int(config['id']),
        config['name'],
        _int(config['mtime_secs']),
        serverUsn,
        _decodeObject(config['config']),
      ]);
    }

    final localChanges = <String, dynamic>{
      'models': changedModels,
      'decks': [changedDecks, changedDeckConfigs],
      'tags': changedTags,
    };
    if (localIsNewer) {
      localChanges['conf'] = collectionConfig;
      localChanges['crt'] = _int(row['crt']);
      await txn.delete('config');
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final entry in collectionConfig.entries) {
        await txn.insert('config', {
          'key': entry.key,
          'usn': serverUsn,
          'mtime_secs': nowSecs,
          'config': jsonEncode(entry.value),
        });
      }
      await txn.update('config', {'usn': serverUsn});
    }

    await txn.update(
        'col',
        {
          'models': jsonEncode(models),
          'decks': jsonEncode(decks),
          'tags': jsonEncode(tags),
        },
        where: 'id = 1');

    final response = await client.requestJson('applyChanges', {
      'changes': localChanges,
    });
    if (response is! Map<String, dynamic>) {
      throw const AnkiSyncException('同步服务器 applyChanges 响应无法解析');
    }
    final remote = _map(response);
    final remoteModels = _list(remote['models']);
    final remoteDecksPayload = _list(remote['decks']);
    final remoteDecks =
        remoteDecksPayload.isNotEmpty && remoteDecksPayload.first is List
            ? _list(remoteDecksPayload.first)
            : remoteDecksPayload;
    final remoteDeckConfigs =
        remoteDecksPayload.length > 1 && remoteDecksPayload[1] is List
            ? _list(remoteDecksPayload[1])
            : const <dynamic>[];

    for (final model in remoteModels) {
      if (model is! Map) continue;
      final value = Map<String, dynamic>.from(model);
      final id = _int(value['id']);
      final existing = models[id.toString()];
      if (existing is! Map || _int(existing['mod']) <= _int(value['mod'])) {
        models[id.toString()] = value;
      }
    }
    for (final deck in remoteDecks) {
      if (deck is! Map) continue;
      final value = Map<String, dynamic>.from(deck);
      final id = _int(value['id']);
      final existing = decks[id.toString()];
      if (existing is! Map || _int(existing['mod']) <= _int(value['mod'])) {
        final name = value['name'];
        if (name is String) {
          final uniqueName = _uniqueDeckName(name, decks, id);
          if (uniqueName != name) {
            value['name'] = uniqueName;
            value['mod'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            value['usn'] = -1;
          }
        }
        decks[id.toString()] = value;
      }
    }
    for (final rawConfig in remoteDeckConfigs) {
      final tuple = _list(rawConfig);
      if (tuple.length < 5 || tuple[4] is! Map || tuple[1] is! String) {
        throw const AnkiSyncException('同步服务器 deck config 数据不完整');
      }
      final id = _tupleInt(tuple[0], 'deck config');
      final mtime = _tupleInt(tuple[2], 'deck config');
      final usn = _tupleInt(tuple[3], 'deck config');
      final config = _map(tuple[4]);
      final localRows = await txn.query(
        'deck_config',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (localRows.isNotEmpty && _int(localRows.first['mtime_secs']) > mtime) {
        continue;
      }
      final values = {
        'id': id,
        'name': tuple[1],
        'mtime_secs': mtime,
        'usn': usn,
        'config': jsonEncode(config),
      };
      await txn.insert(
        'deck_config',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final configJson = Map<String, dynamic>.from(config)
        ..['id'] = id
        ..['name'] = tuple[1];
      deckConfigMap[id.toString()] = configJson;
    }
    for (final tag in _list(remote['tags'])) {
      if (tag is String && tag.isNotEmpty) {
        tags.putIfAbsent(tag, () => serverUsn);
      }
    }
    if (remote['conf'] is Map) {
      final remoteConfig = _map(remote['conf']);
      collectionConfig
        ..clear()
        ..addAll(remoteConfig);
      await txn.delete('config');
      for (final entry in remoteConfig.entries) {
        await txn.insert(
            'config',
            {
              'key': entry.key,
              'usn': serverUsn,
              'mtime_secs': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'config': jsonEncode(entry.value),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    final updates = <String, Object?>{
      'models': jsonEncode(models),
      'decks': jsonEncode(decks),
      'tags': jsonEncode(tags),
      'dconf': jsonEncode(deckConfigMap),
    };
    if (remote['conf'] is Map) {
      updates['conf'] = jsonEncode(collectionConfig);
    }
    if (remote['crt'] is num) updates['crt'] = _int(remote['crt']);
    await txn.update('col', updates, where: 'id = 1');
  }

  static Future<int> _applyRemoteNotes(
    Transaction txn,
    List<dynamic> entries,
  ) async {
    var applied = 0;
    final collectionRows = await txn.query(
      'col',
      columns: ['models'],
      where: 'id = 1',
    );
    final models = collectionRows.isEmpty
        ? <String, dynamic>{}
        : _decodeObject(collectionRows.first['models']);
    for (final raw in entries) {
      final e = _list(raw);
      if (e.length < 11) {
        throw const AnkiSyncException('同步服务器 note 数据不完整');
      }
      final id = _tupleInt(e[0], 'note');
      final modelId = _tupleInt(e[2], 'note');
      final remoteMtime = _tupleInt(e[3], 'note');
      final remoteUsn = _tupleInt(e[4], 'note');
      final guid = _tupleString(e[1], 'note');
      final tags = _tupleString(e[5], 'note');
      final fields = _tupleString(e[6], 'note');
      final flags = _tupleInt(e[9], 'note');
      final data = _tupleString(e[10], 'note');
      final existing = await txn.query(
        'notes',
        columns: ['usn', 'mod'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty &&
          _int(existing.first['usn']) == -1 &&
          _int(existing.first['mod']) >= remoteMtime) {
        continue;
      }
      final firstField = fields.split('\x1f').first;
      final notetype = models[modelId.toString()];
      final rawSortIndex = notetype is Map ? notetype['sortf'] : null;
      final sortIndex = rawSortIndex is num ? rawSortIndex.toInt() : 0;
      final noteFields = fields.split('\x1f');
      final sortField = sortIndex >= 0 && sortIndex < noteFields.length
          ? noteFields[sortIndex]
          : firstField;
      await txn.insert(
          'notes',
          {
            'id': id,
            'guid': guid,
            'mid': modelId,
            'mod': remoteMtime,
            'usn': remoteUsn,
            'tags': tags,
            'flds': fields,
            // Anki's NoteEntry leaves these two tuple values empty. Derive
            // them from the stored fields and notetype instead of trusting
            // the placeholders.
            'sfld': Note.stripHtml(sortField),
            'csum': _checksum(firstField),
            'flags': flags,
            'data': data,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      applied++;
    }
    return applied;
  }

  static Future<int> _applyRemoteCards(
    Transaction txn,
    List<dynamic> entries,
  ) async {
    var applied = 0;
    for (final raw in entries) {
      final e = _list(raw);
      if (e.length < 18) {
        throw const AnkiSyncException('同步服务器 card 数据不完整');
      }
      final id = _tupleInt(e[0], 'card');
      final noteId = _tupleInt(e[1], 'card');
      final deckId = _tupleInt(e[2], 'card');
      final ordinal = _tupleInt(e[3], 'card');
      final remoteMtime = _tupleInt(e[4], 'card');
      final remoteUsn = _tupleInt(e[5], 'card');
      final type = _tupleInt(e[6], 'card');
      final queue = _tupleInt(e[7], 'card');
      final due = _tupleInt(e[8], 'card');
      final interval = _tupleInt(e[9], 'card');
      final factor = _tupleInt(e[10], 'card');
      final reps = _tupleInt(e[11], 'card');
      final lapses = _tupleInt(e[12], 'card');
      final left = _tupleInt(e[13], 'card');
      final originalDue = _tupleInt(e[14], 'card');
      final originalDeckId = _tupleInt(e[15], 'card');
      final flags = _tupleInt(e[16], 'card');
      final existing = await txn.query(
        'cards',
        columns: ['usn', 'mod'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty &&
          _int(existing.first['usn']) == -1 &&
          _int(existing.first['mod']) >= remoteMtime) {
        continue;
      }
      await txn.insert(
          'cards',
          {
            'id': id,
            'nid': noteId,
            'did': deckId,
            'ord': ordinal,
            'mod': remoteMtime,
            'usn': remoteUsn,
            'type': type,
            'queue': queue,
            'due': due,
            'ivl': interval,
            'factor': factor,
            'reps': reps,
            'lapses': lapses,
            'left': left,
            'odue': originalDue,
            'odid': originalDeckId,
            'flags': flags,
            'data': e[17]?.toString() ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      applied++;
    }
    return applied;
  }

  static Future<int> _applyRemoteReviews(
    Transaction txn,
    List<dynamic> entries,
  ) async {
    var applied = 0;
    for (final raw in entries) {
      final e = _list(raw);
      if (e.length < 9) {
        throw const AnkiSyncException('同步服务器 review 数据不完整');
      }
      final id = _tupleInt(e[0], 'review');
      final cardId = _tupleInt(e[1], 'review');
      final remoteUsn = _tupleInt(e[2], 'review');
      final ease = _tupleInt(e[3], 'review');
      final interval = _tupleInt(e[4], 'review');
      final lastInterval = _tupleInt(e[5], 'review');
      final factor = _tupleInt(e[6], 'review');
      final time = _tupleInt(e[7], 'review');
      final type = _tupleInt(e[8], 'review');
      final inserted = await txn.insert(
          'revlog',
          {
            'id': id,
            'cid': cardId,
            'usn': remoteUsn,
            'ease': ease,
            'ivl': interval,
            'lastIvl': lastInterval,
            'factor': factor,
            'time': time,
            'type': type,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (inserted != 0) applied++;
    }
    return applied;
  }

  static Future<({int cards, int notes, int reviews})> _sendLocalChunks(
    Transaction txn,
    AnkiSyncProtocolClient client,
    int serverUsn,
  ) async {
    final notes = await txn.query('notes', where: 'usn = -1', orderBy: 'id');
    final cards = await txn.query('cards', where: 'usn = -1', orderBy: 'id');
    final revlog = await txn.query('revlog', where: 'usn = -1', orderBy: 'id');
    final all = <({String table, Map<String, Object?> row})>[
      ...notes.map((row) => (table: 'notes', row: row)),
      ...cards.map((row) => (table: 'cards', row: row)),
      ...revlog.map((row) => (table: 'revlog', row: row)),
    ];
    if (all.isEmpty) {
      await client.requestJson('applyChunk', {
        'chunk': {'done': true},
      });
      return (cards: 0, notes: 0, reviews: 0);
    }
    var sentNotes = 0;
    var sentCards = 0;
    var sentReviews = 0;
    for (var offset = 0; offset < all.length; offset += _chunkSize) {
      final end = (offset + _chunkSize).clamp(0, all.length);
      final batch = all.sublist(offset, end);
      final chunk = <String, dynamic>{
        'done': end == all.length,
        'notes': <List<dynamic>>[],
        'cards': <List<dynamic>>[],
        'revlog': <List<dynamic>>[],
      };
      for (final item in batch) {
        final r = item.row;
        await txn.update(
          item.table,
          {'usn': serverUsn},
          where: 'id = ? AND usn = -1',
          whereArgs: [r['id']],
        );
        if (item.table == 'notes') {
          sentNotes++;
          (chunk['notes'] as List<List<dynamic>>).add([
            _int(r['id']),
            r['guid'],
            _int(r['mid']),
            _int(r['mod']),
            serverUsn,
            r['tags'],
            r['flds'],
            '', // Anki's v10 NoteEntry always leaves sfld empty.
            '', // Anki's v10 NoteEntry always leaves csum empty.
            _int(r['flags']),
            r['data'],
          ]);
        } else if (item.table == 'cards') {
          sentCards++;
          (chunk['cards'] as List<List<dynamic>>).add([
            _int(r['id']),
            _int(r['nid']),
            _int(r['did']),
            _int(r['ord']),
            _int(r['mod']),
            serverUsn,
            _int(r['type']),
            _int(r['queue']),
            _int(r['due']),
            _int(r['ivl']),
            _int(r['factor']),
            _int(r['reps']),
            _int(r['lapses']),
            _int(r['left']),
            _int(r['odue']),
            _int(r['odid']),
            _int(r['flags']),
            r['data'],
          ]);
        } else {
          sentReviews++;
          (chunk['revlog'] as List<List<dynamic>>).add([
            _int(r['id']),
            _int(r['cid']),
            serverUsn,
            _int(r['ease']),
            _int(r['ivl']),
            _int(r['lastIvl']),
            _int(r['factor']),
            _int(r['time']),
            _int(r['type']),
          ]);
        }
      }
      await client.requestJson('applyChunk', {'chunk': chunk});
    }
    return (cards: sentCards, notes: sentNotes, reviews: sentReviews);
  }

  static Future<void> _checkSanity(
    Transaction txn,
    AnkiSyncProtocolClient client,
  ) async {
    final clientCounts = <dynamic>[
      // Anki's v10 client sends the default due-count tuple; the server fills
      // its own counts when comparing the rest of the sanity metadata.
      [0, 0, 0],
      await _count(txn, 'cards'),
      await _count(txn, 'notes'),
      await _count(txn, 'revlog'),
      0,
      _decodeObject(
        (await txn.query(
          'col',
          columns: ['models'],
          where: 'id = 1',
        ))
            .first['models'],
      ).length,
      _decodeObject(
        (await txn.query(
          'col',
          columns: ['decks'],
          where: 'id = 1',
        ))
            .first['decks'],
      ).length,
      await _count(txn, 'deck_config'),
    ];
    final response = await client.requestJson('sanityCheck2', {
      'client': clientCounts,
    });
    if (response is! Map<String, dynamic> || response['status'] != 'ok') {
      throw const AnkiSyncException('同步数据校验失败，本地事务已回滚；请完整下载服务器 collection 后重试');
    }
  }

  static Future<int> _count(Transaction txn, String table) async {
    final row = (await txn.rawQuery('SELECT COUNT(*) AS n FROM $table')).first;
    return _int(row['n']);
  }

  static Future<bool> _hasPendingChanges(Database db) async {
    for (final table in ['notes', 'cards', 'revlog']) {
      final row = (await db.rawQuery(
        'SELECT 1 FROM $table WHERE usn < 0 LIMIT 1',
      ));
      if (row.isNotEmpty) return true;
    }
    final graves = await db.query(
      'graves',
      columns: ['oid'],
      where: 'usn < 0',
      limit: 1,
    );
    if (graves.isNotEmpty) return true;
    final col = (await db.query(
      'col',
      columns: ['models', 'decks', 'tags'],
      where: 'id = 1',
    ))
        .first;
    for (final values in [
      _decodeObject(col['models']).values,
      _decodeObject(col['decks']).values,
    ]) {
      if (values.any((value) => value is Map && _int(value['usn']) < 0)) {
        return true;
      }
    }
    if (_decodeObject(col['tags']).values.any((value) => _int(value) < 0)) {
      return true;
    }
    if (await db
        .query('deck_config', where: 'usn < 0', limit: 1)
        .then((r) => r.isNotEmpty)) {
      return true;
    }
    return false;
  }

  static Map<String, dynamic> _decodeObject(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String || raw.isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(raw);
      return value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _uniqueDeckName(
    String name,
    Map<String, dynamic> decks,
    int incomingId,
  ) {
    final usedNames = <String>{};
    for (final entry in decks.entries) {
      if (entry.key == incomingId.toString() || entry.value is! Map) continue;
      final existingName = (entry.value as Map)['name'];
      if (existingName is String) usedNames.add(existingName);
    }
    if (!usedNames.contains(name)) return name;

    final base = '$name (sync conflict $incomingId)';
    var uniqueName = base;
    var suffix = 2;
    while (usedNames.contains(uniqueName)) {
      uniqueName = '$base $suffix';
      suffix++;
    }
    return uniqueName;
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<dynamic> _list(Object? value) =>
      value is List ? value : const <dynamic>[];

  static List<dynamic> _chunkList(Map<String, dynamic> chunk, String key) {
    // The v10 server omits empty arrays, so absence represents an empty
    // collection. A present non-array value is malformed and must not be
    // silently treated as an empty chunk.
    if (!chunk.containsKey(key)) return const <dynamic>[];
    final value = chunk[key];
    if (value is List) return value;
    throw AnkiSyncException('同步服务器 chunk $key 数据无法解析');
  }

  static List<int> _graveIds(Object? value, String type) {
    if (value is! List) {
      throw AnkiSyncException('同步服务器 graves $type 数据无法解析');
    }
    return value.map((raw) {
      final id = _tupleInt(raw, 'grave $type');
      if (id <= 0) {
        throw AnkiSyncException('同步服务器 graves $type 数据包含无效 ID');
      }
      return id;
    }).toList();
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static int _tupleInt(Object? value, String type) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.toInt()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw AnkiSyncException('同步服务器 $type 数据包含无效数字');
  }

  static String _tupleString(Object? value, String type) {
    if (value is String) return value;
    throw AnkiSyncException('同步服务器 $type 数据包含无效文本');
  }

  static int _checksum(String text) {
    return Note.computeChecksum(text);
  }
}

class AnkiCollectionSyncResult {
  final int changedCards;
  final int changedNotes;
  final int changedReviews;
  final bool collectionChanged;

  const AnkiCollectionSyncResult({
    required this.changedCards,
    required this.changedNotes,
    required this.changedReviews,
    required this.collectionChanged,
  });
}

class AnkiSyncFullTransferRequired implements Exception {
  final String message;
  const AnkiSyncFullTransferRequired(this.message);

  @override
  String toString() => message;
}
