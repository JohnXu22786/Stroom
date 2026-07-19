import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';

/// Imports .apkg files into Stroom's Anki collection.
///
/// The .apkg is a ZIP containing `collection.anki2` (same schema as ours).
/// We open it as a secondary SQLite database, read all records, and merge
/// them into the primary database.
class AnkiApkgImporter {
  /// Import an .apkg file into the database at [targetDbPath].
  /// Returns a summary string.
  static Future<String> import(String apkgPath) async {
    // 1. Read ZIP
    final file = File(apkgPath);
    if (!file.existsSync()) throw Exception('文件不存在: $apkgPath');

    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 2. Extract collection.anki2
    final dbEntry = archive.files.firstWhere(
      (f) => f.name == 'collection.anki2',
      orElse: () => throw Exception('.apkg 中缺少 collection.anki2'),
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
      throw Exception('目标数据库不存在，请先打开闪卡功能');
    }

    // 4. Open both databases
    final importDb = await openDatabase(tmpDbPath, readOnly: true);
    final targetDb = await openDatabase(targetDbPath);

    try {
      // Generate unique IDs using timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final nowSec = now ~/ 1000;
      int newId = now + DateTime.now().microsecondsSinceEpoch;

      // Track counts
      int decksImported = 0, notesImported = 0, cardsImported = 0;

      // ── Import decks (merge JSON blobs in col row) ──────
      final srcCol = await importDb.query('col', where: 'id = 1');
      final tgtCol = await targetDb.query('col', where: 'id = 1');
      if (srcCol.isEmpty || tgtCol.isEmpty) throw Exception('数据库损坏');

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
      final srcNotes = await importDb.rawQuery('SELECT * FROM notes');
      for (final note in srcNotes) {
        final guid = note['guid'] as String;
        // Check duplicate by GUID
        final dup =
            await targetDb.query('notes', where: 'guid = ?', whereArgs: [guid]);
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
      final srcCards = await importDb.rawQuery('SELECT * FROM cards');
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

      return '导入完成：$decksImported 个牌组，$notesImported 个笔记，$cardsImported 张卡片';
    } finally {
      await targetDb.close();
      await importDb.close();
      if (File(tmpDbPath).existsSync()) await File(tmpDbPath).delete();
    }
  }
}
