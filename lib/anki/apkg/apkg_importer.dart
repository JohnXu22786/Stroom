import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';

import '../database/sqlite_error_classifier.dart';
import 'apkg_result.dart';

/// Imports .apkg files into Stroom's Anki collection.
///
/// The .apkg is a ZIP containing `collection.anki2` (same schema as ours).
/// We open it as a secondary SQLite database, read all records, and merge
/// them into the primary database.
class AnkiApkgImporter {
  /// Import an .apkg file into the database at [targetDbPath].
  /// Returns imported counts; callers localize the user-facing summary.
  static Future<AnkiApkgImportSummary> import(
    String apkgPath, {
    List<int> Function(File file)? readPackageBytes,
  }) async {
    // 1. Read ZIP
    final file = File(apkgPath);
    bool sourceExists;
    try {
      sourceExists = file.existsSync();
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    } catch (_) {
      throw AnkiApkgException.unexpectedError(apkgPath);
    }
    if (!sourceExists) {
      throw AnkiApkgException.fileNotFound(apkgPath);
    }
    late final List<int> bytes;
    try {
      bytes = readPackageBytes?.call(file) ?? file.readAsBytesSync();
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    } catch (_) {
      throw AnkiApkgException.unexpectedError(apkgPath);
    }
    late final Archive archive;
    try {
      if (!_hasEndOfCentralDirectory(bytes)) {
        throw const FormatException('ZIP end record is missing');
      }
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw AnkiApkgException.invalidArchive(apkgPath);
    }

    // 2. Extract collection.anki2
    final dbEntry = archive.files.firstWhere(
      (f) => f.name == 'collection.anki2',
      orElse: () => throw const AnkiApkgException(
        AnkiApkgErrorCode.collectionMissing,
      ),
    );

    // Write to temp file
    late final Directory tmpDir;
    try {
      tmpDir = await getApplicationDocumentsDirectory();
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    }
    final tmpDbPath = p.join(tmpDir.path,
        'tmp_import_${DateTime.now().microsecondsSinceEpoch}.anki2');
    try {
      await File(tmpDbPath).writeAsBytes(dbEntry.content as List<int>);
    } on FileSystemException {
      try {
        final partialFile = File(tmpDbPath);
        if (partialFile.existsSync()) await partialFile.delete();
      } on FileSystemException {
        // Keep reporting the original write failure with its local path.
      }
      throw AnkiApkgException.localFileFailure(tmpDbPath);
    }

    // 3. Get target DB path
    final docsDir = tmpDir;
    final targetDbPath = p.join(docsDir.path, 'collection.anki2');
    bool targetExists;
    try {
      targetExists = File(targetDbPath).existsSync();
    } on FileSystemException {
      await _deleteTemporaryFile(tmpDbPath);
      throw AnkiApkgException.localFileFailure(targetDbPath);
    }
    if (!targetExists) {
      try {
        await File(tmpDbPath).delete();
      } on FileSystemException {
        throw AnkiApkgException.localFileFailure(tmpDbPath);
      }
      throw AnkiApkgException.targetDatabaseMissing(targetDbPath);
    }

    // 4. Open both databases
    Database? importDb;
    Database? targetDb;
    try {
      try {
        importDb = await openDatabase(tmpDbPath, readOnly: true);
      } on DatabaseException catch (error) {
        throw _databaseException(error, tmpDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(tmpDbPath);
      }
      try {
        targetDb = await openDatabase(targetDbPath);
      } on DatabaseException catch (error) {
        throw _databaseException(error, targetDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(targetDbPath);
      }

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
      } on DatabaseException catch (error) {
        throw _databaseException(error, tmpDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(tmpDbPath);
      }
      List<Map<String, Object?>> tgtCol;
      try {
        tgtCol = await targetDb.query('col', where: 'id = 1');
      } on DatabaseException catch (error) {
        throw _databaseException(error, targetDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(targetDbPath);
      }
      if (srcCol.isEmpty) throw AnkiApkgException.unexpectedError(tmpDbPath);
      if (tgtCol.isEmpty) throw AnkiApkgException.unexpectedError(targetDbPath);

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
      } on DatabaseException catch (error) {
        throw _databaseException(error, tmpDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(tmpDbPath);
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
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
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
      } on DatabaseException catch (error) {
        throw _databaseException(error, tmpDbPath);
      } catch (_) {
        throw AnkiApkgException.unexpectedError(tmpDbPath);
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
    } on DatabaseException catch (error) {
      throw _databaseException(error, targetDbPath);
    } finally {
      try {
        if (targetDb != null) await targetDb.close();
      } on DatabaseException catch (error) {
        throw _databaseException(error, targetDbPath);
      } on FileSystemException {
        throw AnkiApkgException.localFileFailure(targetDbPath);
      } finally {
        try {
          if (importDb != null) await importDb.close();
        } on DatabaseException catch (error) {
          throw _databaseException(error, tmpDbPath);
        } on FileSystemException {
          throw AnkiApkgException.localFileFailure(tmpDbPath);
        } finally {
          try {
            final tempFile = File(tmpDbPath);
            if (tempFile.existsSync()) await tempFile.delete();
          } on FileSystemException {
            throw AnkiApkgException.localFileFailure(tmpDbPath);
          }
        }
      }
    }
  }

  static bool _hasEndOfCentralDirectory(List<int> bytes) {
    const signature = [0x50, 0x4b, 0x05, 0x06];
    final start = bytes.length > 65557 ? bytes.length - 65557 : 0;
    for (var index = bytes.length - signature.length; index >= start; index--) {
      if (bytes[index] == signature[0] &&
          bytes[index + 1] == signature[1] &&
          bytes[index + 2] == signature[2] &&
          bytes[index + 3] == signature[3]) {
        return true;
      }
    }
    return false;
  }

  static AnkiApkgException _databaseException(
    DatabaseException error,
    String path,
  ) {
    if (isSqliteLocalFileFailure(error)) {
      return AnkiApkgException.localFileFailure(path);
    }
    if (isSqliteCorruption(error)) {
      return const AnkiApkgException(AnkiApkgErrorCode.databaseCorrupt);
    }
    return AnkiApkgException.unexpectedError(path);
  }

  static Future<void> _deleteTemporaryFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(path);
    }
  }
}
