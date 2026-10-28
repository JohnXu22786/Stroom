import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/stroom_conversation.dart';
import 'conversation_repository.dart';

class SqfliteConversationRepository implements ConversationRepository {
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    if (_opening != null) return _opening!;
    final opening = _openDatabase();
    _opening = opening;
    try {
      return await opening;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final database = await openDatabase(
      p.join(directory.path, 'stroom_conversations.db'),
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            record_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            record_json TEXT NOT NULL,
            FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
            PRIMARY KEY(conversation_id, id)
          )
        ''');
        await db.execute(
          'CREATE INDEX messages_by_conversation ON messages(conversation_id, sequence, id)',
        );
        await db.execute('''
          CREATE TABLE repository_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE repository_metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<void> initialize() async {
    await _db;
  }

  @override
  Future<List<ConversationSummary>> listSummaries({int? limit}) async {
    final rows = await (await _db).rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id) AS message_count
      FROM conversations c
      ORDER BY c.sort_order ASC, c.updated_at DESC, c.id ASC
      ${limit == null ? '' : 'LIMIT ?'}
    ''', limit == null ? null : [limit]);
    return rows.map(_summaryFromRow).toList();
  }

  @override
  Future<StroomConversation?> getConversation(String id) async {
    final rows = await (await _db).query(
      'conversations',
      columns: ['record_json'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StroomConversation.fromJson(rows.single['record_json']! as String);
  }

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 || limit < 0) throw ArgumentError('Invalid message page.');
    final rows = await (await _db).query(
      'messages',
      columns: ['record_json'],
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sequence ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (row) => StroomMessage.fromMap(
            Map<String, dynamic>.from(
              jsonDecode(row['record_json']! as String),
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertConversation(StroomConversation conversation) async {
    final record = _withoutMessages(conversation);
    final values = {
      'id': conversation.id,
      'title': conversation.title,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
      'record_json': record.toJson(),
    };
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'conversations',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
    });
  }

  @override
  Future<void> applyConversationChanges(
    StroomConversation conversation, {
    List<StroomMessage> upsertMessages = const [],
    List<String> deleteMessageIds = const [],
  }) async {
    final record = _withoutMessages(conversation);
    final values = {
      'id': conversation.id,
      'title': conversation.title,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
      'record_json': record.toJson(),
    };
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'conversations',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
      for (final id in deleteMessageIds) {
        await txn.delete(
          'messages',
          where: 'conversation_id = ? AND id = ?',
          whereArgs: [conversation.id, id],
        );
      }
      for (final message in upsertMessages) {
        await _insertMessage(txn, conversation.id, message);
      }
    });
  }

  @override
  Future<void> applySnapshotChanges({
    required List<ConversationRepositoryChange> changes,
    required List<String> conversationOrder,
    required List<String> deleteConversationIds,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final change in changes) {
        final conversation = change.conversation;
        final record = _withoutMessages(conversation);
        final values = {
          'id': conversation.id,
          'title': conversation.title,
          'created_at': conversation.createdAt.millisecondsSinceEpoch,
          'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
          'record_json': record.toJson(),
        };
        await txn.insert(
          'conversations',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(
          'conversations',
          values,
          where: 'id = ?',
          whereArgs: [conversation.id],
        );
        for (final id in change.deleteMessageIds) {
          await txn.delete(
            'messages',
            where: 'conversation_id = ? AND id = ?',
            whereArgs: [conversation.id, id],
          );
        }
        for (final message in change.upsertMessages) {
          await _insertMessage(txn, conversation.id, message);
        }
      }
      for (final id in deleteConversationIds) {
        await txn.delete(
          'messages',
          where: 'conversation_id = ?',
          whereArgs: [id],
        );
        await txn.delete('conversations', where: 'id = ?', whereArgs: [id]);
      }
      final rows = await txn.query(
        'conversations',
        columns: ['id', 'sort_order'],
        orderBy: 'sort_order ASC',
      );
      final currentIds = rows.map((row) => row['id']! as String).toList();
      final wanted = <String>[
        ...conversationOrder.where(currentIds.contains),
        ...currentIds.where((id) => !conversationOrder.contains(id)),
      ];
      for (var index = 0; index < wanted.length; index++) {
        if (rows.asMap().entries.any(
              (entry) =>
                  entry.value['id'] == wanted[index] &&
                  entry.value['sort_order'] == index,
            )) {
          continue;
        }
        await txn.update(
          'conversations',
          {'sort_order': index},
          where: 'id = ?',
          whereArgs: [wanted[index]],
        );
      }
    });
  }

  @override
  Future<void> importConversation(StroomConversation conversation) async {
    final record = _withoutMessages(conversation);
    final values = {
      'id': conversation.id,
      'title': conversation.title,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
      'record_json': record.toJson(),
    };
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'conversations',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
      await txn.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversation.id],
      );
      for (final message in conversation.messages) {
        await _insertMessage(txn, conversation.id, message);
      }
    });
  }

  @override
  Future<void> setConversationOrder(List<String> conversationIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'conversations',
        columns: ['id', 'sort_order'],
        orderBy: 'sort_order ASC',
      );
      final currentIds = rows.map((row) => row['id']! as String).toList();
      final wanted = <String>[
        ...conversationIds.where((id) => currentIds.contains(id)),
        ...currentIds.where((id) => !conversationIds.contains(id)),
      ];
      if (_sameIds(currentIds, wanted) &&
          rows.asMap().entries.every(
                (entry) => entry.value['sort_order'] == entry.key,
              )) {
        return;
      }
      for (var index = 0; index < wanted.length; index++) {
        if (index < rows.length &&
            rows[index]['id'] == wanted[index] &&
            rows[index]['sort_order'] == index) continue;
        await txn.update(
          'conversations',
          {'sort_order': index},
          where: 'id = ?',
          whereArgs: [wanted[index]],
        );
      }
    });
  }

  @override
  Future<void> clearConversations() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('conversations');
      await txn.delete(
        'repository_metadata',
        where: 'key = ?',
        whereArgs: ['migration_source_hash'],
      );
    });
  }

  @override
  Future<void> replaceMessages(
    String conversationId,
    List<StroomMessage> messages,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _requireConversation(txn, conversationId);
      await txn.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      for (final message in messages) {
        await _insertMessage(txn, conversationId, message);
      }
    });
  }

  @override
  Future<void> upsertMessage(
    String conversationId,
    StroomMessage message,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _requireConversation(txn, conversationId);
      await _insertMessage(txn, conversationId, message);
    });
  }

  Future<void> _insertMessage(
    DatabaseExecutor db,
    String conversationId,
    StroomMessage message,
  ) =>
      db.insert(
          'messages',
          {
            'id': message.id,
            'conversation_id': conversationId,
            'sequence': message.sequence,
            'created_at': message.createdAt.millisecondsSinceEpoch,
            'record_json': jsonEncode(message.toMap()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _requireConversation(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'conversations',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Unknown conversation: $id');
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await (await _db).delete(
      'messages',
      where: 'conversation_id = ? AND id = ?',
      whereArgs: [conversationId, messageId],
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await (await _db).delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  @override
  Future<int> countConversations() async =>
      Sqflite.firstIntValue(
        await (await _db).rawQuery('SELECT COUNT(*) FROM conversations'),
      ) ??
      0;

  @override
  Future<int> countMessages({String? conversationId}) async =>
      conversationId == null
          ? Sqflite.firstIntValue(
                await (await _db).rawQuery('SELECT COUNT(*) FROM messages'),
              ) ??
              0
          : Sqflite.firstIntValue(
                await (await _db).rawQuery(
                  'SELECT COUNT(*) FROM messages WHERE conversation_id = ?',
                  [conversationId],
                ),
              ) ??
              0;

  @override
  Future<String?> migrationSourceHash() async {
    final rows = await (await _db).query(
      'repository_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['migration_source_hash'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String?;
  }

  @override
  Future<void> setMigrationSourceHash(String sourceHash) async {
    await (await _db).insert(
        'repository_metadata',
        {
          'key': 'migration_source_hash',
          'value': sourceHash,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final db = await _db;
    final conversations = await db.query(
      'conversations',
      orderBy: 'sort_order ASC, id ASC',
    );
    final messages = await db.query(
      'messages',
      orderBy: 'conversation_id ASC, sequence ASC, id ASC',
    );
    final sourceHash = await migrationSourceHash();
    return {
      'schemaVersion': 1,
      'messageEnvelopeVersion': 1,
      if (sourceHash != null) 'migrationSourceHash': sourceHash,
      'conversationOrder':
          conversations.map((row) => row['id'] as String).toList(),
      'conversations': conversations
          .map((row) => jsonDecode(row['record_json']! as String))
          .toList(),
      'messages': [
        for (final row in messages)
          {
            'conversationId': row['conversation_id'],
            'record': Map<String, dynamic>.from(
              jsonDecode(row['record_json']! as String),
            ),
          },
      ],
    };
  }

  @override
  Future<void> restoreData(Map<String, dynamic> data) async {
    final rawConversations = data['conversations'];
    final rawMessages = data['messages'];
    if (rawConversations is! List || rawMessages is! List) {
      throw const FormatException('Invalid conversation repository backup.');
    }
    final conversations = <String, StroomConversation>{};
    for (final raw in rawConversations) {
      if (raw is! Map)
        throw const FormatException('Invalid conversation record.');
      final conversation = StroomConversation.fromMap(
        Map<String, dynamic>.from(raw),
      );
      if (conversation.id.isEmpty ||
          conversations.containsKey(conversation.id)) {
        throw const FormatException('Invalid or duplicate conversation id.');
      }
      conversations[conversation.id] = _withoutMessages(conversation);
    }
    final messages = <String, List<StroomMessage>>{
      for (final id in conversations.keys) id: <StroomMessage>[],
    };
    final seenMessageIds = <String>{};
    for (final raw in rawMessages) {
      if (raw is! Map) throw const FormatException('Invalid message record.');
      final row = Map<String, dynamic>.from(raw);
      final conversationId = row.remove('conversationId');
      if (conversationId is! String ||
          !conversations.containsKey(conversationId)) {
        throw const FormatException(
          'Message references a missing conversation.',
        );
      }
      final record = data['messageEnvelopeVersion'] == 1 ? row['record'] : row;
      if (record is! Map) {
        throw const FormatException('Invalid message envelope.');
      }
      final message = StroomMessage.fromMap(Map<String, dynamic>.from(record));
      final compositeId = '$conversationId\u0000${message.id}';
      if (message.id.isEmpty || !seenMessageIds.add(compositeId)) {
        throw const FormatException('Invalid or duplicate message id.');
      }
      messages[conversationId]!.add(message);
    }
    final db = await _db;
    final rawOrder = data['conversationOrder'];
    final orderedIds = rawOrder is List
        ? [
            ...rawOrder.whereType<String>().where(conversations.containsKey),
            ...conversations.keys.where(
              (id) => !rawOrder.whereType<String>().contains(id),
            ),
          ]
        : conversations.keys.toList();
    final migrationSourceHash = data['migrationSourceHash'];
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
      await txn.delete(
        'repository_metadata',
        where: 'key = ?',
        whereArgs: ['migration_source_hash'],
      );
      if (migrationSourceHash is String) {
        await txn.insert('repository_metadata', {
          'key': 'migration_source_hash',
          'value': migrationSourceHash,
        });
      }
      for (final conversation in conversations.values) {
        await txn.insert('conversations', {
          'id': conversation.id,
          'title': conversation.title,
          'created_at': conversation.createdAt.millisecondsSinceEpoch,
          'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
          'sort_order': orderedIds.indexOf(conversation.id),
          'record_json': conversation.toJson(),
        });
        for (final message in messages[conversation.id]!) {
          await _insertMessage(txn, conversation.id, message);
        }
      }
    });
  }

  @override
  Future<List<ConversationIntegrityIssue>> checkIntegrity({
    required Future<Uint8List?> Function(String reference) readMedia,
  }) async {
    final issues = <ConversationIntegrityIssue>[];
    final conversations = await (await _db).query(
      'conversations',
      columns: ['id'],
    );
    for (final row in conversations) {
      final id = row['id']! as String;
      final record = await getConversation(id);
      final messages = await getMessages(
        id,
        limit: await countMessages(conversationId: id),
      );
      for (final message in messages) {
        for (final reference in conversationMessageMediaReferences(message)) {
          await _validateMediaReference(
            issues,
            id,
            message.id,
            reference,
            readMedia,
          );
        }
      }
      if (record != null) {
        for (final reference in conversationDraftAttachmentReferences(record)) {
          await _validateMediaReference(
            issues,
            id,
            'conversation',
            reference,
            readMedia,
          );
        }
      }
    }
    return issues;
  }

  static Future<void> _validateMediaReference(
    List<ConversationIntegrityIssue> issues,
    String conversationId,
    String messageId,
    Map<String, dynamic> reference,
    Future<Uint8List?> Function(String reference) readMedia,
  ) async {
    final path = conversationLocalMediaPath(reference['reference']) ??
        conversationLocalMediaPath(reference['storagePath']);
    if (path == null) {
      final thumbnailPath =
          conversationLocalMediaPath(reference['thumbnailPath']);
      if (!conversationIsExternalMediaUri(reference['reference']) &&
          !conversationIsExternalMediaUri(reference['storagePath']) &&
          thumbnailPath == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: '',
            reason: 'missing_reference',
          ),
        );
      }
    } else {
      final bytes = await readMedia(path);
      if (bytes == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: path,
            reason: 'missing_media',
          ),
        );
      } else {
        final size = reference['size'] ?? reference['fileSize'];
        if (!conversationMediaHashMatches(reference, bytes)) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: path,
              reason: 'hash_mismatch',
            ),
          );
        }
        if (size is num && size.toInt() != bytes.length) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: path,
              reason: 'size_mismatch',
            ),
          );
        }
      }
    }
    final rawThumbnailPath = reference['thumbnailPath'];
    final thumbnailPath = conversationLocalMediaPath(rawThumbnailPath);
    if (thumbnailPath != null && thumbnailPath != path) {
      final thumbnailBytes = await readMedia(thumbnailPath);
      if (thumbnailBytes == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: thumbnailPath,
            reason: 'missing_media',
          ),
        );
      } else {
        final thumbnailReference = <String, dynamic>{
          if (reference['thumbnailSha256'] is String)
            'sha256': reference['thumbnailSha256'],
          if (reference['thumbnailHash'] is String)
            'hash': reference['thumbnailHash'],
        };
        if (thumbnailReference.isNotEmpty &&
            !conversationMediaHashMatches(thumbnailReference, thumbnailBytes)) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: thumbnailPath,
              reason: 'hash_mismatch',
            ),
          );
        }
        final thumbnailSize = reference['thumbnailSize'];
        if (thumbnailSize is num &&
            thumbnailSize.toInt() != thumbnailBytes.length) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: thumbnailPath,
              reason: 'size_mismatch',
            ),
          );
        }
      }
    } else if (rawThumbnailPath != null && rawThumbnailPath is! String) {
      issues.add(
        ConversationIntegrityIssue(
          conversationId: conversationId,
          messageId: messageId,
          reference: '',
          reason: 'missing_reference',
        ),
      );
    }
  }

  static ConversationSummary _summaryFromRow(Map<String, Object?> row) {
    final record = StroomConversation.fromJson(row['record_json']! as String);
    return ConversationSummary.fromConversation(
      record,
      messageCount: (row['message_count'] as num).toInt(),
    );
  }

  static StroomConversation _withoutMessages(StroomConversation source) =>
      StroomConversation(
        schemaVersion: source.schemaVersion,
        id: source.id,
        title: source.title,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        extensions: source.extensions,
        extraFields: source.extraFields,
      );

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }
}
