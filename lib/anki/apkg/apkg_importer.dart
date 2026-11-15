import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
  static const _maxPackageSizeBytes = 128 * 1024 * 1024;
  static const _maxCollectionSizeBytes = 128 * 1024 * 1024;
  static const _maxExpandedArchiveSizeBytes = 256 * 1024 * 1024;
  static const _maxArchiveEntries = 10000;

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
    try {
      if (file.lengthSync() > _maxPackageSizeBytes) {
        throw AnkiApkgException.invalidArchive(apkgPath);
      }
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    } catch (error) {
      if (error is AnkiApkgException) rethrow;
      throw AnkiApkgException.unexpectedError(apkgPath);
    }
    late final List<int> bytes;
    try {
      bytes = readPackageBytes?.call(file) ??
          await readPackageStreamWithLimit(file.openRead());
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    } on FormatException {
      throw AnkiApkgException.invalidArchive(apkgPath);
    } on AnkiApkgException {
      rethrow;
    } catch (_) {
      throw AnkiApkgException.unexpectedError(apkgPath);
    }
    late final Archive archive;
    try {
      if (bytes.length > _maxPackageSizeBytes) {
        throw const FormatException('ZIP package exceeds the size limit');
      }
      if (!_hasEndOfCentralDirectory(bytes)) {
        throw const FormatException('ZIP end record is missing');
      }
      _validateArchiveLimits(bytes);
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw AnkiApkgException.invalidArchive(apkgPath);
    }

    // 2. Extract collection.anki2
    final dbEntry = archive.files.firstWhere(
      (f) => f.name == 'collection.anki2',
      orElse: () =>
          throw const AnkiApkgException(AnkiApkgErrorCode.collectionMissing),
    );
    final sourceCollectionKey =
        sha256.convert(dbEntry.content as List<int>).toString();

    // Write to temp file
    late final Directory tmpDir;
    try {
      tmpDir = await getApplicationDocumentsDirectory();
    } on FileSystemException {
      throw AnkiApkgException.localFileFailure(apkgPath);
    }
    final tmpDbPath = p.join(
      tmpDir.path,
      'tmp_import_${DateTime.now().microsecondsSinceEpoch}.anki2',
    );
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
        await txn.update(
            'col',
            {
              'decks': jsonEncode(tgtDecks),
              'models': jsonEncode(tgtModels),
              'mod': now,
              'dty': 1,
            },
            where: 'id = 1');

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
        final existingCardIds = <(int, int), int>{};
        List<Map<String, Object?>> existingCards;
        try {
          existingCards = await txn.query(
            'cards',
            columns: ['id', 'nid', 'ord'],
          );
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }
        for (final card in existingCards) {
          existingCardIds[(card['nid'] as int, card['ord'] as int)] =
              card['id'] as int;
        }
        final cardMap = <int, int>{}; // source card ID → target card ID
        for (final card in srcCards) {
          final targetNoteId =
              noteMap[card['nid'] as int] ?? card['nid'] as int;
          final cardKey = (targetNoteId, card['ord'] as int);
          final sourceCardId = card['id'] as int;
          final existingCardId = existingCardIds[cardKey];
          if (existingCardId != null) {
            cardMap[sourceCardId] = existingCardId;
            continue;
          }

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
          cardMap[sourceCardId] = id;
          existingCardIds[cardKey] = id;
          cardsImported++;
        }

        // ── Import review history ────────────────────────────
        try {
          // Keep source-to-target identity across imports when a review ID is
          // remapped because another collection already uses it.
          await txn.execute('''
            CREATE TABLE IF NOT EXISTS apkg_revlog_imports (
              source_collection_key TEXT NOT NULL,
              source_card_id INTEGER NOT NULL,
              source_revlog_id INTEGER NOT NULL,
              target_card_id INTEGER NOT NULL,
              target_revlog_id INTEGER NOT NULL,
              PRIMARY KEY (source_collection_key, source_card_id, source_revlog_id)
            )
          ''');
          await txn.execute('''
            CREATE INDEX IF NOT EXISTS apkg_revlog_imports_source_review
            ON apkg_revlog_imports (source_collection_key, source_revlog_id)
          ''');
          await txn.execute('''
            CREATE INDEX IF NOT EXISTS apkg_revlog_imports_target_review
            ON apkg_revlog_imports (target_revlog_id)
          ''');
          await txn.execute('''
            CREATE TRIGGER IF NOT EXISTS apkg_revlog_imports_target_delete
            AFTER DELETE ON revlog
            BEGIN
              DELETE FROM apkg_revlog_imports WHERE target_revlog_id = OLD.id;
            END
          ''');
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }
        try {
          final maxRevlogId = await txn.rawQuery(
            'SELECT COALESCE(MAX(id), 0) AS max_id FROM revlog',
          );
          newId = max(newId, maxRevlogId.single['max_id'] as int);
        } on DatabaseException catch (error) {
          throw _databaseException(error, targetDbPath);
        } catch (_) {
          throw AnkiApkgException.unexpectedError(targetDbPath);
        }

        // Keep only one bounded page of source reviews and matching target rows
        // in memory; target revlog and provenance tables can grow very large.
        const reviewBatchSize = 400;
        int? lastSourceReviewId;
        while (true) {
          List<Map<String, Object?>> srcRevlogs;
          try {
            srcRevlogs = lastSourceReviewId == null
                ? await sourceDb.rawQuery(
                    'SELECT * FROM revlog ORDER BY id LIMIT ?',
                    [reviewBatchSize],
                  )
                : await sourceDb.rawQuery(
                    'SELECT * FROM revlog WHERE id > ? ORDER BY id LIMIT ?',
                    [lastSourceReviewId, reviewBatchSize],
                  );
          } on DatabaseException catch (error) {
            throw _databaseException(error, tmpDbPath);
          } catch (_) {
            throw AnkiApkgException.unexpectedError(tmpDbPath);
          }
          if (srcRevlogs.isEmpty) break;
          lastSourceReviewId = srcRevlogs.last['id'] as int;

          final sourceReviewIds = srcRevlogs
              .map((revlog) => revlog['id'] as int)
              .toList(growable: false);
          final sourceReviewPlaceholders =
              List.filled(sourceReviewIds.length, '?').join(', ');
          List<Map<String, Object?>> importedReviewMappings;
          try {
            importedReviewMappings = await txn.rawQuery(
              '''
                SELECT * FROM apkg_revlog_imports
                WHERE source_collection_key = ?
                  AND source_revlog_id IN ($sourceReviewPlaceholders)
              ''',
              [sourceCollectionKey, ...sourceReviewIds],
            );
          } on DatabaseException catch (error) {
            throw _databaseException(error, targetDbPath);
          } catch (_) {
            throw AnkiApkgException.unexpectedError(targetDbPath);
          }
          final sourceReviewMappings = <(int, int), Map<String, Object?>>{
            for (final mapping in importedReviewMappings)
              (
                mapping['source_card_id'] as int,
                mapping['source_revlog_id'] as int,
              ): mapping,
          };
          final targetReviewIds = <int>{...sourceReviewIds};
          targetReviewIds.addAll(
            importedReviewMappings
                .map((mapping) => mapping['target_revlog_id'] as int),
          );
          final targetReviewPlaceholders =
              List.filled(targetReviewIds.length, '?').join(', ');
          List<Map<String, Object?>> existingRevlogs;
          try {
            existingRevlogs = await txn.rawQuery(
              '''
                SELECT id, cid, ease, ivl, lastIvl, factor, time, type
                FROM revlog WHERE id IN ($targetReviewPlaceholders)
              ''',
              targetReviewIds.toList(growable: false),
            );
          } on DatabaseException catch (error) {
            throw _databaseException(error, targetDbPath);
          } catch (_) {
            throw AnkiApkgException.unexpectedError(targetDbPath);
          }
          final existingRevlogsById = <int, Map<String, Object?>>{
            for (final revlog in existingRevlogs) revlog['id'] as int: revlog,
          };

          for (final revlog in srcRevlogs) {
            final sourceCardId = revlog['cid'] as int;
            final targetCardId = cardMap[sourceCardId];
            if (targetCardId == null) continue;

            final sourceId = revlog['id'] as int;
            final sourceKey = (sourceCardId, sourceId);
            final existingMapping = sourceReviewMappings[sourceKey];
            if (existingMapping != null) {
              final mappedId = existingMapping['target_revlog_id'] as int;
              final existingAtMappedId = existingRevlogsById[mappedId];
              if (existingAtMappedId != null &&
                  _sameReview(
                    existingAtMappedId,
                    revlog,
                    existingMapping['target_card_id'] as int,
                  )) {
                if (existingMapping['target_card_id'] != targetCardId) {
                  final updatedRevlog = <String, Object?>{
                    'cid': targetCardId,
                    'usn': -1,
                    'ease': revlog['ease'],
                    'ivl': revlog['ivl'],
                    'lastIvl': revlog['lastIvl'],
                    'factor': revlog['factor'],
                    'time': revlog['time'],
                    'type': revlog['type'],
                  };
                  await txn.update(
                    'revlog',
                    updatedRevlog,
                    where: 'id = ?',
                    whereArgs: [mappedId],
                  );
                  existingRevlogsById[mappedId] = {
                    'id': mappedId,
                    ...updatedRevlog,
                  };
                  existingMapping['target_card_id'] = targetCardId;
                  await txn.update(
                    'apkg_revlog_imports',
                    {'target_card_id': targetCardId},
                    where: '''
                      source_collection_key = ? AND source_card_id = ? AND source_revlog_id = ?
                    ''',
                    whereArgs: [sourceCollectionKey, sourceCardId, sourceId],
                  );
                }
                continue;
              }
            }

            final existingAtSourceId = existingRevlogsById[sourceId];
            var id = sourceId;
            if (existingAtSourceId != null) {
              do {
                id = ++newId;
              } while (existingRevlogsById.containsKey(id));
            }

            final importedRevlog = <String, Object?>{
              'id': id,
              'cid': targetCardId,
              'usn': -1,
              'ease': revlog['ease'],
              'ivl': revlog['ivl'],
              'lastIvl': revlog['lastIvl'],
              'factor': revlog['factor'],
              'time': revlog['time'],
              'type': revlog['type'],
            };
            await txn.insert('revlog', importedRevlog);
            existingRevlogsById[id] = importedRevlog;
            await txn.insert(
                'apkg_revlog_imports',
                {
                  'source_collection_key': sourceCollectionKey,
                  'source_card_id': sourceCardId,
                  'source_revlog_id': sourceId,
                  'target_card_id': targetCardId,
                  'target_revlog_id': id,
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
            sourceReviewMappings[sourceKey] = {
              'source_collection_key': sourceCollectionKey,
              'source_card_id': sourceCardId,
              'source_revlog_id': sourceId,
              'target_card_id': targetCardId,
              'target_revlog_id': id,
            };
          }
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

  static bool _sameReview(
    Map<String, Object?> existing,
    Map<String, Object?> source,
    int targetCardId,
  ) =>
      existing['cid'] == targetCardId &&
      existing['ease'] == source['ease'] &&
      existing['ivl'] == source['ivl'] &&
      existing['lastIvl'] == source['lastIvl'] &&
      existing['factor'] == source['factor'] &&
      existing['time'] == source['time'] &&
      existing['type'] == source['type'];

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

  static void _validateArchiveLimits(List<int> bytes) {
    final directory = ZipDirectory();
    var entryCount = 0;
    var expandedSize = 0;
    for (final header in directory.headers(
      InputMemoryStream(bytes),
    )) {
      entryCount++;
      if (entryCount > _maxArchiveEntries) {
        throw const FormatException('ZIP contains too many entries');
      }
      final size = header.file?.uncompressedSize ?? header.uncompressedSize;
      if (size < 0 || size > _maxExpandedArchiveSizeBytes - expandedSize) {
        throw const FormatException('ZIP expanded data exceeds the size limit');
      }
      expandedSize += size;
      if (header.filename == 'collection.anki2' &&
          size > _maxCollectionSizeBytes) {
        throw const FormatException('Anki collection exceeds the size limit');
      }
    }
  }

  /// Collects package bytes from [stream] without exceeding [maxSizeBytes].
  static Future<List<int>> readPackageStreamWithLimit(
    Stream<List<int>> stream, {
    int maxSizeBytes = _maxPackageSizeBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    var totalSize = 0;
    await for (final chunk in stream) {
      if (chunk.length > maxSizeBytes - totalSize) {
        throw const FormatException('ZIP package exceeds the size limit');
      }
      totalSize += chunk.length;
      builder.add(chunk);
    }
    return builder.takeBytes();
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
