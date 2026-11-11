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

      final sourceDb = importDb;
      return await targetDb.transaction((txn) async {
        // Generate unique IDs using timestamp
        final now = DateTime.now().millisecondsSinceEpoch;
        final nowSec = now ~/ 1000;
        int newId = now + DateTime.now().microsecondsSinceEpoch;

        // Track counts
        int decksImported = 0, notesImported = 0, cardsImported = 0;

        // ── Import decks (merge JSON blobs in col row) ──────
        List<Map<String, Object?>> srcCol;
        try {
          srcCol = await sourceDb.query('col', where: 'id = 1');
        } on DatabaseException catch (error) {
          throw _databaseException(error, tmpDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(tmpDbPath);
        }
        List<Map<String, Object?>> tgtCol;
        try {
          tgtCol = await txn.query('col', where: 'id = 1');
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }
        if (srcCol.isEmpty) throw AnkiApkgException.unexpectedError(tmpDbPath);
        if (tgtCol.isEmpty) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }

        final srcDecks =
            jsonDecode(srcCol.first['decks'] as String) as Map<String, dynamic>;
        final tgtDecks =
            jsonDecode(tgtCol.first['decks'] as String) as Map<String, dynamic>;
        final srcModels = jsonDecode(
          srcCol.first['models'] as String,
        ) as Map<String, dynamic>;
        final tgtModels = jsonDecode(
          tgtCol.first['models'] as String,
        ) as Map<String, dynamic>;

        final deckMap = <int, int>{}; // old ID → new ID
        for (final entry in srcDecks.entries) {
          final oldId = int.parse(entry.key);
          final deckData = entry.value as Map<String, dynamic>;
          final name = deckData['name'] as String;

          // Duplicate by name?
          final existing = tgtDecks.entries.where(
            (e) => (e.value as Map)['name'] == name,
          );
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

        // Preserve package note type definitions, remapping IDs that collide
        // with a different target definition. Note type deck references use
        // the same mapping as the imported decks.
        final modelMap = <int, int>{};
        for (final entry in srcModels.entries) {
          final sourceId = int.parse(entry.key);
          final sourceModel = Map<String, dynamic>.from(entry.value as Map);
          _remapModelDecks(sourceModel, deckMap);
          final existingModel = tgtModels[entry.key];
          var targetId = sourceId;
          if (existingModel != null &&
              !_sameModelDefinition(
                sourceModel,
                Map<String, dynamic>.from(existingModel as Map),
              )) {
            do {
              targetId = ++newId;
            } while (tgtModels.containsKey(targetId.toString()));
          }
          modelMap[sourceId] = targetId;
          if (existingModel != null && targetId == sourceId) continue;

          final model = sourceModel
            ..['id'] = targetId
            ..['mod'] = nowSec
            ..['usn'] = -1;
          tgtModels[targetId.toString()] = model;
        }

        // Write back merged decks
        await txn.update('col', {
          'decks': jsonEncode(tgtDecks),
          'models': jsonEncode(tgtModels),
          'mod': now,
          'dty': 1,
        }, where: 'id = 1');

        // We also need to update the decks in the col row's conf activeDecks list
        // but for simplicity, we'll just merge and leave the active deck as-is

        // ── Import notes ────────────────────────────────────
        final noteMap = <int, int>{}; // source note ID → target note ID
        List<Map<String, Object?>> srcNotes;
        try {
          srcNotes = await sourceDb.rawQuery('SELECT * FROM notes');
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
            dup = await txn.query(
              'notes',
              where: 'guid = ?',
              whereArgs: [guid],
            );
          } on DatabaseException catch (error) {
            throw _databaseException(error, targetDbPath);
          } catch (_) {
            throw AnkiApkgException.unexpectedError(targetDbPath);
          }
          final sourceId = note['id'] as int;
          if (dup.isNotEmpty) {
            noteMap[sourceId] = dup.first['id'] as int;
            continue;
          }

          final id = ++newId;
          noteMap[sourceId] = id;
          final sourceModelId = note['mid'] as int;
          final targetModelId = modelMap[sourceModelId];
          if (targetModelId == null) {
            throw AnkiApkgException.unexpectedError(tmpDbPath);
          }
          await txn.insert('notes', {
            'id': id,
            'guid': guid,
            'mid': targetModelId,
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
          srcCards = await sourceDb.rawQuery('SELECT * FROM cards');
        } on DatabaseException catch (error) {
          throw _databaseException(error, tmpDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(tmpDbPath);
        }
        final existingCardKeys = <(int, int)>{};
        List<Map<String, Object?>> existingCards;
        try {
          existingCards = await txn.query('cards', columns: ['nid', 'ord']);
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }
        for (final card in existingCards) {
          existingCardKeys.add((card['nid'] as int, card['ord'] as int));
        }
        for (final card in srcCards) {
          final targetNoteId =
              noteMap[card['nid'] as int] ?? card['nid'] as int;
          final cardKey = (targetNoteId, card['ord'] as int);
          if (existingCardKeys.contains(cardKey)) continue;

          final id = ++newId;
          final oldDid = card['did'] as int;
          final newDid = deckMap[oldDid] ?? oldDid;

          await txn.insert('cards', {
            'id': id,
            'nid': targetNoteId,
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
          existingCardKeys.add(cardKey);
          cardsImported++;
        }

        return AnkiApkgImportSummary(
          decksImported: decksImported,
          notesImported: notesImported,
          cardsImported: cardsImported,
        );
      });
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

  static void _remapModelDecks(
    Map<String, dynamic> model,
    Map<int, int> deckMap,
  ) {
    final did = model['did'];
    if (did is int) model['did'] = deckMap[did] ?? did;
    final templates = model['tmpls'];
    if (templates is! List) return;
    for (var index = 0; index < templates.length; index++) {
      final template = templates[index];
      if (template is! Map) continue;
      final templateData = Map<String, dynamic>.from(template);
      final templateDid = templateData['did'];
      if (templateDid is int) {
        templateData['did'] = deckMap[templateDid] ?? templateDid;
      }
      templates[index] = templateData;
    }
  }

  static bool _sameModelDefinition(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftDefinition = Map<String, dynamic>.from(left)
      ..remove('id')
      ..remove('mod')
      ..remove('usn');
    final rightDefinition = Map<String, dynamic>.from(right)
      ..remove('id')
      ..remove('mod')
      ..remove('usn');
    return _sameJsonValue(leftDefinition, rightDefinition);
  }

  static bool _sameJsonValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_sameJsonValue(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameJsonValue(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
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
