import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/anki_database.dart';
import '../database/anki_schema.dart';
import 'anki_sync_protocol_client.dart';
import 'anki_sync_destination_state.dart';
import 'anki_full_download_recovery.dart';

/// Full collection replacement helpers. Callers confirm destructive actions,
/// and each method leaves a recoverable local database backup.
class AnkiCollectionTransfer {
  const AnkiCollectionTransfer._();

  static const _requiredColumns = <String, Set<String>>{
    'col': {
      'id',
      'crt',
      'mod',
      'scm',
      'ver',
      'dty',
      'usn',
      'ls',
      'conf',
      'models',
      'decks',
      'dconf',
      'tags',
    },
    'notes': {
      'id',
      'guid',
      'mid',
      'mod',
      'usn',
      'tags',
      'flds',
      'sfld',
      'csum',
      'flags',
      'data',
    },
    'cards': {
      'id',
      'nid',
      'did',
      'ord',
      'mod',
      'usn',
      'type',
      'queue',
      'due',
      'ivl',
      'factor',
      'reps',
      'lapses',
      'left',
      'odue',
      'odid',
      'flags',
      'data',
    },
    'revlog': {
      'id',
      'cid',
      'usn',
      'ease',
      'ivl',
      'lastIvl',
      'factor',
      'time',
      'type',
    },
    'graves': {'usn', 'oid', 'type'},
  };
  static const _collectionSidecarSuffixes = ['-wal', '-shm', '-journal'];

  static Future<String> uploadLocalCollection(
    AnkiSyncProtocolClient client, {
    String? documentsPath,
  }) async {
    final collectionPath = await _collectionPath(documentsPath);
    await AnkiDatabase.closeOpenedInstance();
    final collection = File(collectionPath);
    if (!await collection.exists()) {
      throw const AnkiSyncException('本地还没有 collection.anki2');
    }

    await _validateCollection(collectionPath);
    final backupPath = await _createBackup(collection);
    // A server may commit the full collection and lose the response. Mark the
    // local association unresolved before sending, and clear that state only
    // after a successful response confirms which destination received it.
    await AnkiSyncDestinationState.markCollectionFilePending(collectionPath);
    await client.uploadCollectionFile(collection);
    await AnkiSyncDestinationState.markCollectionFile(
      collectionPath,
      client.destinationIdentity,
    );
    return backupPath;
  }

  static Future<String> downloadAndReplaceLocalCollection(
    AnkiSyncProtocolClient client, {
    String? documentsPath,
    AnkiFullDownloadRecovery? recovery,
  }) async {
    final collectionPath = await _collectionPath(documentsPath);
    final tempPath = '$collectionPath.sync-download.tmp';
    final tempFile = File(tempPath);
    final currentFile = File(collectionPath);
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final displacedPath = '$collectionPath.pre-sync-$stamp';

    try {
      await client.downloadCollectionToFile(tempFile);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw const AnkiSyncException('服务器返回了空 collection');
      }
      await _validateCollection(tempPath);
      await _markFullDownloadSynced(tempPath, client.destinationIdentity);

      await AnkiDatabase.closeOpenedInstance();
      await AnkiDatabase.invalidateLegacySyncMetadataMigrationMarker(
        basePath: documentsPath,
      );
      final backupPath = await _createBackup(
        currentFile,
        backupPath: recovery?.collectionBackupPath,
      );

      // Keep the old file in place until the validated download is ready to
      // move. If the final rename fails, restore the original path.
      final hadOriginal = await currentFile.exists();
      await recovery?.markCollectionReplacementStarted();
      final displacedSidecars = <String>[];
      try {
        if (hadOriginal) await currentFile.rename(displacedPath);
        for (final suffix in _collectionSidecarSuffixes) {
          final sidecar = File('$collectionPath$suffix');
          if (!await sidecar.exists()) continue;
          final displacedSidecar = '$displacedPath$suffix';
          await sidecar.rename(displacedSidecar);
          displacedSidecars.add(displacedSidecar);
        }
        await tempFile.rename(collectionPath);
      } catch (_) {
        if (await currentFile.exists() &&
            (await File(displacedPath).exists() || !hadOriginal)) {
          await currentFile.delete();
        }
        if (hadOriginal && await File(displacedPath).exists()) {
          await File(displacedPath).rename(collectionPath);
        }
        for (final displacedSidecar in displacedSidecars.reversed) {
          final sidecar = File(displacedSidecar);
          if (await sidecar.exists()) {
            await sidecar.rename(
              '$collectionPath${displacedSidecar.substring(displacedPath.length)}',
            );
          }
        }
        rethrow;
      }
      for (final displacedSidecar in displacedSidecars) {
        try {
          final sidecar = File(displacedSidecar);
          if (await sidecar.exists()) await sidecar.delete();
        } catch (_) {
          // The downloaded database is already installed; stale sidecar
          // backups are harmless and the recovery journal remains authoritative.
        }
      }
      if (hadOriginal) {
        final displaced = File(displacedPath);
        if (await displaced.exists()) {
          try {
            await displaced.delete();
          } catch (_) {
            // The retained backup already protects the original. Leaving this
            // duplicate temporary file is safer than reporting a failed
            // download after the replacement has succeeded.
          }
        }
      }
      return backupPath;
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  /// Restore the protected pre-download collection if the subsequent media
  /// transfer fails, keeping a full collection+media download atomic from the
  /// user's point of view.
  static Future<void> restoreLocalCollectionBackup(
    String backupPath, {
    String? documentsPath,
    Future<void> Function(File file)? deleteDisplacedFile,
  }) async {
    final collectionPath = await _collectionPath(documentsPath);
    await AnkiDatabase.closeOpenedInstance();
    await AnkiDatabase.invalidateLegacySyncMetadataMigrationMarker(
      basePath: documentsPath,
    );
    final destination = File(collectionPath);
    if (backupPath.isEmpty) {
      if (await destination.exists()) await destination.delete();
      return;
    }
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw const AnkiSyncException('本地 collection 备份不存在，无法回滚');
    }
    final restorePath = '$collectionPath.restore.tmp';
    final restore = File(restorePath);
    if (await restore.exists()) await restore.delete();
    await backup.copy(restorePath);
    final displacedPath = '$collectionPath.failed-download';
    final displaced = File(displacedPath);
    if (await displaced.exists()) await displaced.delete();
    final hadDownload = await destination.exists();
    if (hadDownload) await destination.rename(displacedPath);
    try {
      await restore.rename(collectionPath);
    } catch (_) {
      if (hadDownload && await displaced.exists()) {
        await displaced.rename(collectionPath);
      }
      rethrow;
    } finally {
      if (await restore.exists()) await restore.delete();
    }
    if (await displaced.exists()) {
      try {
        await (deleteDisplacedFile ?? (file) => file.delete())(displaced);
      } catch (_) {
        // The backup is already restored. A stale failed download is safer
        // than moving it over the restored collection during cleanup.
      }
    }
  }

  static Future<String> _collectionPath(String? documentsPath) async {
    final directoryPath =
        documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    return p.join(directoryPath, 'collection.anki2');
  }

  static Future<String> _createBackup(
    File collection, {
    String? backupPath,
  }) async {
    if (!await collection.exists()) {
      // A new install may have no database before the first Anki page opens.
      return '';
    }
    final path = backupPath ??
        '${collection.path}.sync-backup-'
            '${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await collection.copy(path);
    return path;
  }

  static Future<void> _validateCollection(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true, singleInstance: false);
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const AnkiSyncException('collection 未通过 SQLite 完整性检查');
      }
      for (final entry in _requiredColumns.entries) {
        final info = await db.rawQuery('PRAGMA table_info(${entry.key})');
        final actual = info.map((column) => column['name'] as String).toSet();
        if (!actual.containsAll(entry.value)) {
          throw const AnkiSyncException('collection 缺少同步所需的表或字段');
        }
      }
      final rows = await db.query('col', columns: ['ver'], where: 'id = 1');
      if (rows.isEmpty || (rows.first['ver'] as num?)?.toInt() != 11) {
        throw const AnkiSyncException('collection 不是 schema 11');
      }
    } on AnkiSyncException {
      rethrow;
    } catch (_) {
      throw const AnkiSyncException('collection 无法打开或结构不兼容');
    } finally {
      await db?.close();
    }
  }

  static Future<void> _markFullDownloadSynced(
    String path,
    String destination,
  ) async {
    Database? db;
    try {
      db = await openDatabase(path, singleInstance: false);
      await db.transaction((txn) async {
        await txn.execute('UPDATE col SET ls = mod WHERE id = 1');
        await txn.execute(AnkiSchema.syncDestinationStatement);
        await AnkiSyncDestinationState.mark(txn, destination);
      });
    } catch (_) {
      throw const AnkiSyncException('无法更新下载 collection 的同步时间');
    } finally {
      await db?.close();
    }
  }
}
