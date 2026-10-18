import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'anki_schema.dart';
import 'card_dao.dart';
import 'note_dao.dart';
import 'revlog_dao.dart';
import 'grave_dao.dart';
import 'col_dao.dart';
import '../models/note.dart';

/// Manages the SQLite connection to collection.anki2.
///
/// Opens the database at [basePath]/collection.anki2 (or the default
/// app documents directory if [basePath] is null). Creates tables
/// and seeds the initial col row on first run.
class AnkiDatabase {
  static const _legacySyncMetadataMigrationVersion = 2;

  Database? _db;
  Future<void>? _opening;
  late final CardDao cards;
  late final NoteDao notes;
  late final RevlogDao revlog;
  late final GraveDao graves;
  late final ColDao col;

  final String? _overridePath;

  /// 最近一次 [open] 的实例（供删除数据库文件前关闭连接，
  /// 避免 Windows 等平台因文件被占用而删除失败）。
  static AnkiDatabase? _openedInstance;

  /// 关闭已打开的 Anki 数据库连接（若有）。
  ///
  /// 在删除 collection.anki2 文件前调用（如清除 Anki 数据场景）。
  static Future<void> closeOpenedInstance() async {
    final instance = _openedInstance;
    _openedInstance = null;
    await instance?.close();
  }

  /// Invalidate the one-time metadata migration cache when the collection file
  /// is replaced, restored, or deleted outside [open].
  static Future<void> invalidateLegacySyncMetadataMigrationMarker({
    String? basePath,
  }) async {
    final directory =
        basePath ?? (await getApplicationDocumentsDirectory()).path;
    final marker = File(
      '${p.join(directory, 'collection.anki2')}'
      '.stroom-sync-metadata-migration',
    );
    final temporaryMarker = File('${marker.path}.tmp');
    if (await marker.exists()) await marker.delete();
    if (await temporaryMarker.exists()) await temporaryMarker.delete();
  }

  AnkiDatabase({String? basePath}) : _overridePath = basePath;

  /// Open (or create) the database.
  Future<void> open() {
    final opening = _opening;
    if (opening != null) return opening;
    if (_db != null) return Future<void>.value();
    final started = _open();
    _opening = started;
    return started.whenComplete(() {
      if (identical(_opening, started)) _opening = null;
    });
  }

  Future<void> _open() async {
    final dir =
        _overridePath ?? (await getApplicationDocumentsDirectory()).path;
    final dbPath = p.join(dir, 'collection.anki2');
    final openedDb = await openDatabase(
      dbPath,
      version: AnkiSchema.schemaVersion,
      onCreate: (db, version) async {
        for (final sql in AnkiSchema.createStatements) {
          await db.execute(sql);
        }
        final collectionRows = await db.query(
          'col',
          columns: ['id'],
          where: 'id = 1',
          limit: 1,
        );
        if (collectionRows.isEmpty) await ColDao.seed(db);
      },
    );
    _db = openedDb;
    try {
      await _migrateNotesSortFieldAffinity(openedDb);
      for (final statement in AnkiSchema.localSupportStatements) {
        await openedDb.execute(statement);
      }
      await _ensureDeckConfigSeeded(openedDb);
      await _migrateLegacySyncMetadataOnce(openedDb, dbPath);
      cards = CardDao(openedDb);
      notes = NoteDao(openedDb);
      revlog = RevlogDao(openedDb);
      graves = GraveDao(openedDb);
      col = ColDao(openedDb, cards, notes, revlog, graves);
      _openedInstance = this;
    } catch (_) {
      _db = null;
      if (identical(this, _openedInstance)) {
        _openedInstance = null;
      }
      try {
        await openedDb.close();
      } catch (_) {
        // Preserve the initialization error so the caller can retry it.
      }
      rethrow;
    }
  }

  Future<void> _migrateNotesSortFieldAffinity(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    final sortField = columns.where((column) => column['name'] == 'sfld');
    if (sortField.isEmpty ||
        sortField.first['type'].toString().toUpperCase() == 'INTEGER') {
      return;
    }

    final indexes = await db.rawQuery(
      "SELECT sql FROM sqlite_master "
      "WHERE type = 'index' AND tbl_name = 'notes' AND sql IS NOT NULL",
    );
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE notes_sfld_migration (
          id INTEGER PRIMARY KEY,
          guid TEXT NOT NULL,
          mid INTEGER NOT NULL,
          mod INTEGER NOT NULL,
          usn INTEGER NOT NULL,
          tags TEXT NOT NULL,
          flds TEXT NOT NULL,
          sfld INTEGER NOT NULL,
          csum INTEGER NOT NULL,
          flags INTEGER NOT NULL,
          data TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        INSERT INTO notes_sfld_migration
        SELECT id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data
        FROM notes
      ''');
      await txn.execute('DROP TABLE notes');
      await txn.execute('ALTER TABLE notes_sfld_migration RENAME TO notes');
      for (final index in indexes) {
        await txn.execute(index['sql'] as String);
      }
    });
  }

  Future<void> _ensureDeckConfigSeeded(Database db) async {
    final existingIds = (await db.query(
      'deck_config',
      columns: ['id'],
    ))
        .map((row) => (row['id'] as num).toInt())
        .toSet();
    final colRows = await db.query('col', columns: ['dconf'], where: 'id = 1');
    if (colRows.isEmpty) return;
    try {
      final configs = jsonDecode(colRows.first['dconf'] as String);
      if (configs is! Map) return;
      for (final entry in configs.entries) {
        final id = int.tryParse(entry.key.toString());
        if (id == null || existingIds.contains(id) || entry.value is! Map) {
          continue;
        }
        final config = Map<String, dynamic>.from(entry.value as Map)
          ..remove('id')
          ..remove('name');
        await db.insert(
            'deck_config',
            {
              'id': id,
              'name': entry.value['name']?.toString() ?? 'Default',
              'mtime_secs': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'usn': -1,
              'config': jsonEncode(config),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        existingIds.add(id);
      }
    } on FormatException {
      // Keep an invalid legacy configuration available for manual repair;
      // normal sync validation will refuse a mismatched collection.
    }
  }

  Future<void> _migrateLegacySyncMetadata(Database db) async {
    final colRows = await db.query(
      'col',
      columns: ['models', 'decks'],
      where: 'id = 1',
    );
    final collectionRow = colRows.isEmpty ? null : colRows.first;
    final models = _tryJsonMap(collectionRow?['models']);
    for (final row in await db.query('notes')) {
      final oldMod = (row['mod'] as num).toInt();
      final mod = oldMod > 100000000000 ? oldMod ~/ 1000 : oldMod;
      final oldSortField = row['sfld']?.toString() ?? '';
      final fields = (row['flds'] as String? ?? '').split('\u001f');
      final notetype = models?[(row['mid'] as num).toInt().toString()];
      final rawSortIndex = notetype is Map ? notetype['sortf'] : null;
      final sortFieldIndex = rawSortIndex is num ? rawSortIndex.toInt() : 0;
      final sortField = models == null
          ? null
          : sortFieldIndex >= 0 && sortFieldIndex < fields.length
              ? Note.stripHtml(fields[sortFieldIndex])
              : '';
      final checksum = Note.computeChecksum(fields.first);
      final oldChecksum = (row['csum'] as num?)?.toInt();
      final changes = <String, Object?>{};
      if (mod != oldMod) changes['mod'] = mod;
      if (oldChecksum != checksum) changes['csum'] = checksum;
      if (sortField != null && oldSortField != sortField) {
        changes['sfld'] = sortField;
      }
      if (changes.isNotEmpty) {
        changes['usn'] = -1;
        await db.update(
          'notes',
          changes,
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    for (final row in await db.query('cards', columns: ['id', 'mod'])) {
      final oldMod = (row['mod'] as num).toInt();
      if (oldMod > 100000000000) {
        await db.update(
          'cards',
          {'mod': oldMod ~/ 1000, 'usn': -1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    if (collectionRow != null) {
      final decks = _tryJsonMap(collectionRow['decks']);
      final collectionChanges = <String, Object?>{};
      if (models != null) {
        var modelsChanged = false;
        for (final value in models.values) {
          if (value is Map && (value['mod'] as num? ?? 0) > 100000000000) {
            value['mod'] = ((value['mod'] as num).toInt() ~/ 1000);
            value['usn'] = -1;
            modelsChanged = true;
          }
        }
        if (modelsChanged) collectionChanges['models'] = jsonEncode(models);
      }
      if (decks != null) {
        var decksChanged = false;
        for (final value in decks.values) {
          if (value is Map) {
            if ((value['mod'] as num? ?? 0) > 100000000000) {
              value['mod'] = ((value['mod'] as num).toInt() ~/ 1000);
              value['usn'] = -1;
              decksChanged = true;
            }
          }
        }
        decksChanged |= _normalizeLegacyDeckCreationDates(decks);
        if (decksChanged) collectionChanges['decks'] = jsonEncode(decks);
      }
      if (collectionChanges.isNotEmpty) {
        await db.update('col', collectionChanges, where: 'id = 1');
      }
    }
  }

  Future<void> _migrateLegacySyncMetadataOnce(
    Database db,
    String dbPath,
  ) async {
    final collectionRows = await db.query(
      'col',
      columns: ['crt'],
      where: 'id = 1',
    );
    if (collectionRows.isEmpty) return;

    // `crt` is stable for one Anki collection and changes when a different
    // collection replaces it. Keep this cache beside the local file so it
    // never enters the synced collection or exported backup.
    final created = (collectionRows.first['crt'] as num).toInt();
    final marker = File('$dbPath.stroom-sync-metadata-migration');
    final markerValue = '$_legacySyncMetadataMigrationVersion:$created';
    String? previousMarkerValue;
    if (await marker.exists()) {
      try {
        previousMarkerValue = (await marker.readAsString()).trim();
        if (previousMarkerValue == markerValue) return;
      } on FileSystemException {
        // Treat an unreadable marker as absent and retry the idempotent work.
      }
    }

    if (_isVersionOneMarkerForCollection(previousMarkerValue, created)) {
      await _migrateLegacyDeckCreationDates(db);
    } else {
      await _migrateLegacySyncMetadata(db);
    }

    final temporaryMarker = File('${marker.path}.tmp');
    try {
      if (await temporaryMarker.exists()) await temporaryMarker.delete();
      await temporaryMarker.writeAsString(markerValue, flush: true);
      if (await marker.exists()) await marker.delete();
      await temporaryMarker.rename(marker.path);
    } finally {
      if (await temporaryMarker.exists()) await temporaryMarker.delete();
    }
  }

  bool _isVersionOneMarkerForCollection(String? marker, int created) {
    if (_legacySyncMetadataMigrationVersion != 2 || marker == null) {
      return false;
    }
    final parts = marker.split(':');
    return parts.length == 2 &&
        int.tryParse(parts[0]) == 1 &&
        int.tryParse(parts[1]) == created;
  }

  Future<void> _migrateLegacyDeckCreationDates(Database db) async {
    final rows = await db.query('col', columns: ['decks'], where: 'id = 1');
    if (rows.isEmpty) return;
    final decks = _tryJsonMap(rows.first['decks']);
    if (decks == null) return;
    if (!_normalizeLegacyDeckCreationDates(decks)) return;
    await db.update('col', {'decks': jsonEncode(decks)}, where: 'id = 1');
  }

  bool _normalizeLegacyDeckCreationDates(Map<String, dynamic> decks) {
    var changed = false;
    for (final value in decks.values) {
      if (value is Map && (value['crt'] as num? ?? 0) > 100000000000) {
        value['crt'] = ((value['crt'] as num).toInt() ~/ 1000);
        value['usn'] = -1;
        changed = true;
      }
    }
    return changed;
  }

  Map<String, dynamic>? _tryJsonMap(Object? source) {
    if (source is! String) return null;
    try {
      final parsed = jsonDecode(source);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // Opening already closes its database handle when initialization fails.
      }
    }
    await _db?.close();
    _db = null;
    if (identical(this, _openedInstance)) {
      _openedInstance = null;
    }
  }

  Database get db {
    if (_db == null) throw StateError('AnkiDatabase not opened');
    return _db!;
  }
}
