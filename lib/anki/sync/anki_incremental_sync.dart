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
    final needsCollectionSync = localModified != remote.modified || hasPending;

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

        final incomingGraves = _map(start);
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
          receivedCards += await _applyRemoteCards(txn, _list(chunk['cards']));
          receivedNotes += await _applyRemoteNotes(txn, _list(chunk['notes']));
          receivedReviews += await _applyRemoteReviews(
            txn,
            _list(chunk['revlog']),
          );
          if (chunk['done'] == true) break;
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

    final cards = _intList(remote['cards']);
    final notes = _intList(remote['notes']);
    final decks = _intList(remote['decks']);
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
      await txn.update('col', {'decks': jsonEncode(deckMap)}, where: 'id = 1');
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
        decks[id.toString()] = value;
      }
    }
    for (final rawConfig in remoteDeckConfigs) {
      final tuple = _list(rawConfig);
      if (tuple.length < 5) continue;
      final id = _int(tuple[0]);
      final mtime = _int(tuple[2]);
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
        'name': tuple[1]?.toString() ?? '',
        'mtime_secs': mtime,
        'usn': _int(tuple[3]),
        'config': jsonEncode(_map(tuple[4])),
      };
      await txn.insert(
        'deck_config',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final configJson = Map<String, dynamic>.from(_map(tuple[4]))
        ..['id'] = _int(tuple[0])
        ..['name'] = tuple[1]?.toString() ?? '';
      deckConfigMap[_int(tuple[0]).toString()] = configJson;
    }
    for (final tag in _list(remote['tags'])) {
      if (tag is String && tag.isNotEmpty) {
        tags.putIfAbsent(tag, () => serverUsn);
      }
    }
    if (remote['conf'] is Map) {
      for (final entry in _map(remote['conf']).entries) {
        collectionConfig[entry.key] = entry.value;
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
      if (e.length < 11) continue;
      final id = _int(e[0]);
      final remoteMtime = _int(e[3]);
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
      final fields = e[6]?.toString() ?? '';
      final firstField = fields.split('\x1f').first;
      final notetype = models[_int(e[2]).toString()];
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
            'guid': e[1]?.toString() ?? '',
            'mid': _int(e[2]),
            'mod': remoteMtime,
            'usn': _int(e[4]),
            'tags': e[5]?.toString() ?? '',
            'flds': fields,
            // Anki's NoteEntry leaves these two tuple values empty. Derive
            // them from the stored fields and notetype instead of trusting
            // the placeholders.
            'sfld': Note.stripHtml(sortField),
            'csum': _checksum(firstField),
            'flags': _int(e[9]),
            'data': e[10]?.toString() ?? '',
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
      if (e.length < 18) continue;
      final id = _int(e[0]);
      final remoteMtime = _int(e[4]);
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
            'nid': _int(e[1]),
            'did': _int(e[2]),
            'ord': _int(e[3]),
            'mod': remoteMtime,
            'usn': _int(e[5]),
            'type': _int(e[6]),
            'queue': _int(e[7]),
            'due': _int(e[8]),
            'ivl': _int(e[9]),
            'factor': _int(e[10]),
            'reps': _int(e[11]),
            'lapses': _int(e[12]),
            'left': _int(e[13]),
            'odue': _int(e[14]),
            'odid': _int(e[15]),
            'flags': _int(e[16]),
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
      if (e.length < 9) continue;
      final id = _int(e[0]);
      final inserted = await txn.insert(
          'revlog',
          {
            'id': id,
            'cid': _int(e[1]),
            'usn': _int(e[2]),
            'ease': _int(e[3]),
            'ivl': _int(e[4]),
            'lastIvl': _int(e[5]),
            'factor': _int(e[6]),
            'time': _int(e[7]),
            'type': _int(e[8]),
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
    final counts = <String, dynamic>{
      // Anki's v10 client sends the default due-count tuple; the server fills
      // its own counts when comparing the rest of the sanity metadata.
      'counts': [0, 0, 0],
      'cards': await _count(txn, 'cards'),
      'notes': await _count(txn, 'notes'),
      'revlog': await _count(txn, 'revlog'),
      'graves': 0,
      'models': _decodeObject(
        (await txn.query(
          'col',
          columns: ['models'],
          where: 'id = 1',
        ))
            .first['models'],
      ).length,
      'decks': _decodeObject(
        (await txn.query(
          'col',
          columns: ['decks'],
          where: 'id = 1',
        ))
            .first['decks'],
      ).length,
      'deck_config': await _count(txn, 'deck_config'),
    };
    final response = await client.requestJson('sanityCheck2', {
      'client': counts,
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

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<dynamic> _list(Object? value) =>
      value is List ? value : const <dynamic>[];

  static List<int> _intList(Object? value) => _list(value).map(_int).toList();

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

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
