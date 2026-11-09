import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';

import 'apkg_result.dart';

/// Imports .apkg files into Stroom's Anki collection.
///
/// The .apkg is a ZIP containing `collection.anki2` (same schema as ours).
/// We open it as a secondary SQLite database, read all records, and merge
/// them into the primary database.
class AnkiApkgImporter {
  /// Import an .apkg file into the database at [targetDbPath].
  /// Returns imported counts; callers localize the user-facing summary.
  static Future<AnkiApkgImportSummary> import(String apkgPath) async {
    // 1. Read ZIP
    final file = File(apkgPath);
    bool sourceExists;
    try {
      sourceExists = file.existsSync();
    } catch (_) {
      throw AnkiApkgException.unexpectedError(apkgPath);
    }
    if (!sourceExists) {
      throw AnkiApkgException.fileNotFound(apkgPath);
    }

    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 2. Extract collection.anki2
    final dbEntry = archive.files.firstWhere(
      (f) => f.name == 'collection.anki2',
      orElse: () => throw const AnkiApkgException(
        AnkiApkgErrorCode.collectionMissing,
      ),
    );

    // Write to temp file
    final tmpDir = await getApplicationDocumentsDirectory();
    final tmpDbPath = p.join(tmpDir.path,
        'tmp_import_${DateTime.now().microsecondsSinceEpoch}.anki2');
    await File(tmpDbPath).writeAsBytes(dbEntry.content as List<int>);

    // 3. Get target DB path
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDbPath = p.join(docsDir.path, 'collection.anki2');
    if (!File(targetDbPath).existsSync()) {
      await File(tmpDbPath).delete();
      throw AnkiApkgException.targetDatabaseMissing(targetDbPath);
    }

    // 4. Open both databases
    Database? importDb;
    Database? targetDb;
    try {
      try {
        importDb = await openDatabase(tmpDbPath, readOnly: true);
      } catch (_) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }
      targetDb = await openDatabase(targetDbPath);

      // Generate unique IDs using timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final nowSec = now ~/ 1000;
      int newId = now + DateTime.now().microsecondsSinceEpoch;

      // Track counts
      int decksImported = 0, notesImported = 0, cardsImported = 0;

      // ── Import decks (merge JSON blobs in col row) ──────
      List<Map<String, Object?>> srcCol;
      try {
        srcCol = await importDb.query('col', where: 'id = 1');
      } catch (_) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }
      List<Map<String, Object?>> tgtCol;
      try {
        tgtCol = await targetDb.query('col', where: 'id = 1');
      } catch (_) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }
      if (srcCol.isEmpty || tgtCol.isEmpty) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }

      final srcDecks =
          jsonDecode(srcCol.first['decks'] as String) as Map<String, dynamic>;
      final tgtDecks =
          jsonDecode(tgtCol.first['decks'] as String) as Map<String, dynamic>;

      final deckMap = <int, int>{}; // old ID → new ID
      for (final entry in srcDecks.entries) {
        final oldId = int.parse(entry.key);
        final deckData = entry.value as Map<String, dynamic>;
        final name = deckData['name'] as String;

        // Duplicate by name?
        final existing =
            tgtDecks.entries.where((e) => (e.value as Map)['name'] == name);
        if (existing.isNotEmpty) {
          deckMap[oldId] = int.parse(existing.first.key);
          continue;
        }

        // New deck
        final id = ++newId;
        deckMap[oldId] = id;
        deckData['id'] = id;
        deckData['mod'] = nowSec;
        deckData['usn'] = -1;
        tgtDecks[id.toString()] = deckData;
        decksImported++;
      }

      // Write back merged decks
      await targetDb.update(
          'col',
          {
            'decks': jsonEncode(tgtDecks),
            'mod': now,
            'dty': 1,
          },
          where: 'id = 1');

      // We also need to update the decks in the col row's conf activeDecks list
      // but for simplicity, we'll just merge and leave the active deck as-is

      // ── Import notes ────────────────────────────────────
      List<Map<String, Object?>> srcNotes;
      try {
        srcNotes = await importDb.rawQuery('SELECT * FROM notes');
      } catch (_) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }
      for (final note in srcNotes) {
        final guid = note['guid'] as String;
        // Check duplicate by GUID
        List<Map<String, Object?>> dup;
        try {
          dup = await targetDb.query(
            'notes',
            where: 'guid = ?',
            whereArgs: [guid],
          );
        } catch (_) {
          throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
        }
        if (dup.isNotEmpty) continue;

        final id = ++newId;
        await targetDb.insert('notes', {
          'id': id,
          'guid': guid,
          'mid': note['mid'],
          'mod': nowSec,
          'usn': -1,
          'tags': note['tags'] ?? '',
          'flds': note['flds'] ?? '',
          'sfld': note['sfld'] ?? '',
          'csum': note['csum'] ?? 0,
          'flags': note['flags'] ?? 0,
          'data': note['data'] ?? '',
        });
        notesImported++;
      }

      // ── Import cards ────────────────────────────────────
      List<Map<String, Object?>> srcCards;
      try {
        srcCards = await importDb.rawQuery('SELECT * FROM cards');
      } catch (_) {
        throw const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
      }
      for (final card in srcCards) {
        final id = ++newId;
        final oldDid = card['did'] as int;
        final newDid = deckMap[oldDid] ?? oldDid;

        await targetDb.insert('cards', {
          'id': id,
          'nid': card['nid'],
          'did': newDid,
          'ord': card['ord'],
          'mod': nowSec,
          'usn': -1,
          'type': card['type'],
          'queue': card['queue'],
          'due': card['due'],
          'ivl': card['ivl'] ?? 0,
          'factor': card['factor'] ?? 2500,
          'reps': card['reps'] ?? 0,
          'lapses': card['lapses'] ?? 0,
          'left': card['left'] ?? 0,
          'odue': 0,
          'odid': 0,
          'flags': card['flags'] ?? 0,
          'data': card['data'] ?? '',
        });
        cardsImported++;
      }

      return AnkiApkgImportSummary(
        decksImported: decksImported,
        notesImported: notesImported,
        cardsImported: cardsImported,
      );
    } finally {
      try {
        if (targetDb != null) await targetDb.close();
      } finally {
        try {
          if (importDb != null) await importDb.close();
        } finally {
          if (File(tmpDbPath).existsSync()) await File(tmpDbPath).delete();
        }
      }
    }
  }
}
