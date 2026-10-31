import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Durable rollback plan for a full collection-and-media download.
///
/// The journal is written before any local files are moved. Small marker files
/// record when each destructive phase is allowed to start, so a process crash
/// can safely distinguish an untouched collection from a partially replaced
/// one.
class AnkiFullDownloadRecovery {
  AnkiFullDownloadRecovery._(this._plan);

  static const _journalName = 'collection.sync-recovery.json';
  static const _sqliteSuffixes = ['', '-wal', '-shm', '-journal'];

  static bool _active = false;
  static Future<void>? _recovering;

  final Map<String, dynamic> _plan;
  String get _documentsPath => _plan['documentsPath'] as String;
  String get _journalPath => p.join(_documentsPath, _journalName);
  String get collectionPath => _plan['collectionPath'] as String;
  String? get collectionBackupPath => _plan['collectionBackupPath'] as String?;
  String get mediaPath => _plan['mediaPath'] as String;
  String get mediaBackupPath => _plan['mediaBackupPath'] as String;
  String get mediaIndexPath => _plan['mediaIndexPath'] as String;
  String get mediaIndexBackupPath => _plan['mediaIndexBackupPath'] as String;
  List<String> get mediaIndexPaths => {
        for (final entry in _plan['mediaIndexFiles'] as List)
          (entry as Map)['rootPath'] as String,
      }.toList();

  String mediaIndexBackupPathFor(String path) =>
      (_plan['mediaIndexFiles'] as List).cast<Map>().firstWhere(
            (entry) => entry['path'] == path,
          )['backupPath'] as String;

  static Future<AnkiFullDownloadRecovery> begin({
    required String documentsPath,
    required String destinationIdentity,
  }) async {
    await recoverIfNeeded(documentsPath);
    if (_active) {
      throw const FileSystemException('已有全量下载恢复任务正在进行');
    }
    _active = true;
    try {
      final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
      final collectionPath = p.join(documentsPath, 'collection.anki2');
      final collectionExists = await File(collectionPath).exists();
      final mediaPath = p.join(documentsPath, 'collection.media');
      final journalPath = p.join(documentsPath, _journalName);
      final mediaIndexPath = _indexPath(documentsPath, destinationIdentity);
      final indexRoots = <String>{mediaIndexPath};
      final indexPattern = RegExp(
        r'^(collection\.media\.sync\.[0-9a-f]{64}\.db)(?:-(?:wal|shm|journal))?$',
      );
      final documentsDirectory = Directory(documentsPath);
      if (await documentsDirectory.exists()) {
        await for (final entity in documentsDirectory.list(
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final match = indexPattern.firstMatch(p.basename(entity.path));
          if (match != null) {
            indexRoots.add(p.join(documentsPath, match.group(1)!));
          }
        }
      }
      final indexFiles = <Map<String, Object>>[];
      for (final rootPath in indexRoots) {
        for (final suffix in _sqliteSuffixes) {
          final path = '$rootPath$suffix';
          final markerId = sha256.convert(utf8.encode(path));
          indexFiles.add({
            'path': path,
            'rootPath': rootPath,
            'backupPath': '$rootPath.pre-sync-$stamp$suffix',
            'existed': await File(path).exists(),
            'suffix': suffix,
            'moveStartedMarker': '$journalPath.$stamp.index-$markerId-moving',
            'movedMarker': '$journalPath.$stamp.index-$markerId-moved',
          });
        }
      }
      final collectionSidecars = <Map<String, Object>>[];
      for (final suffix in _sqliteSuffixes.skip(1)) {
        final path = '$collectionPath$suffix';
        collectionSidecars.add({
          'path': path,
          'backupPath': '$collectionPath.sync-backup-$stamp$suffix',
          'existed': await File(path).exists(),
          'suffix': suffix,
        });
      }
      final plan = <String, dynamic>{
        'documentsPath': documentsPath,
        'collectionPath': collectionPath,
        'collectionExisted': collectionExists,
        'collectionBackupPath':
            collectionExists ? '$collectionPath.sync-backup-$stamp' : null,
        'collectionSidecars': collectionSidecars,
        'mediaPath': mediaPath,
        'mediaExisted': await Directory(mediaPath).exists(),
        'mediaBackupPath': '$mediaPath.pre-sync-$stamp',
        'mediaMoveStartedMarker': '$journalPath.$stamp.media-moving',
        'mediaMovedMarker': '$journalPath.$stamp.media-moved',
        'mediaIndexPath': mediaIndexPath,
        'mediaIndexBackupPath': '$mediaIndexPath.pre-sync-$stamp',
        'mediaIndexFiles': indexFiles,
        'mediaStartedMarker': '$journalPath.$stamp.media-started',
        'collectionStartedMarker': '$journalPath.$stamp.collection-started',
      };
      final recovery = AnkiFullDownloadRecovery._(plan);
      await recovery._writeJournal();
      for (final sidecar in collectionSidecars) {
        if (sidecar['existed'] == true) {
          await File(sidecar['path'] as String)
              .copy(sidecar['backupPath'] as String);
        }
      }
      return recovery;
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  Future<void> markMediaResetStarted() =>
      _createMarker(_plan['mediaStartedMarker'] as String);

  Future<void> markMediaMoved() =>
      _createMarker(_plan['mediaMovedMarker'] as String);

  Future<void> markMediaMoveStarted() =>
      _createMarker(_plan['mediaMoveStartedMarker'] as String);

  Future<void> markMediaIndexFileMoveStarted(String path) async {
    final indexFiles = _plan['mediaIndexFiles'] as List;
    final entry = indexFiles.cast<Map>().firstWhere(
          (item) => item['path'] == path,
        );
    await _createMarker(entry['moveStartedMarker'] as String);
  }

  Future<void> markMediaIndexFileMoved(String path) async {
    final indexFiles = _plan['mediaIndexFiles'] as List;
    final entry = indexFiles.cast<Map>().firstWhere(
          (item) => item['path'] == path,
        );
    await _createMarker(entry['movedMarker'] as String);
  }

  Future<void> markCollectionReplacementStarted() =>
      _createMarker(_plan['collectionStartedMarker'] as String);

  Future<void> commit() async {
    await _clearJournal();
    _active = false;
  }

  Future<void> rollback() async {
    try {
      await _recover(_plan, _journalPath);
    } finally {
      // If rollback fails, keep the journal so the next database open retries.
      _active = false;
    }
  }

  static Future<bool> hasPending(String documentsPath) async =>
      File(p.join(documentsPath, _journalName)).exists();

  static void simulateProcessRestartForTesting() {
    _active = false;
    _recovering = null;
  }

  /// Called before opening collection.anki2, so a restarted app never opens a
  /// half-replaced local database before attempting rollback.
  static Future<void> recoverIfNeeded(String documentsPath) async {
    if (_active) return;
    final running = _recovering;
    if (running != null) return running;
    final recovery = _recoverAt(documentsPath);
    _recovering = recovery;
    try {
      await recovery;
    } finally {
      if (identical(_recovering, recovery)) _recovering = null;
    }
  }

  static Future<void> _recoverAt(String documentsPath) async {
    final journal = File(p.join(documentsPath, _journalName));
    if (!await journal.exists()) return;
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Anki 同步恢复记录格式无效');
    }
    final plan = Map<String, dynamic>.from(decoded);
    if (plan['documentsPath'] != documentsPath) {
      throw const FormatException('Anki 同步恢复记录路径不匹配');
    }
    await _recover(plan, journal.path);
  }

  static Future<void> _recover(
    Map<String, dynamic> plan,
    String journalPath,
  ) async {
    final mediaStarted =
        await File(plan['mediaStartedMarker'] as String).exists();
    if (mediaStarted) await _restoreMedia(plan);

    final collectionStarted = await File(
      plan['collectionStartedMarker'] as String,
    ).exists();
    if (collectionStarted) await _restoreCollection(plan);

    final downloadTemp = File('${plan['collectionPath']}.sync-download.tmp');
    if (await downloadTemp.exists()) await downloadTemp.delete();
    await _clearJournalAt(journalPath, plan);
  }

  static Future<void> _restoreMedia(Map<String, dynamic> plan) async {
    final mediaPath = plan['mediaPath'] as String;
    final mediaBackupPath = plan['mediaBackupPath'] as String;
    final media = Directory(mediaPath);
    final backup = Directory(mediaBackupPath);
    if (await backup.exists()) {
      if (await media.exists()) await media.delete(recursive: true);
      await _deleteMarker(plan['mediaMoveStartedMarker'] as String);
      await _deleteMarker(plan['mediaMovedMarker'] as String);
      await backup.rename(mediaPath);
    } else if (plan['mediaExisted'] == true) {
      final moveStarted =
          await File(plan['mediaMoveStartedMarker'] as String).exists();
      if (await File(plan['mediaMovedMarker'] as String).exists() ||
          (moveStarted && !await media.exists())) {
        throw const FileSystemException('Anki 全量下载的本地媒体备份丢失，已阻止打开不完整数据');
      }
    } else if (await media.exists()) {
      await media.delete(recursive: true);
    }

    final entries = plan['mediaIndexFiles'];
    if (entries is! List) {
      throw const FormatException('Anki 媒体恢复记录缺少索引文件');
    }
    for (final entry in entries) {
      if (entry is! Map) {
        throw const FormatException('Anki 媒体索引恢复记录无效');
      }
      final path = entry['path'] as String;
      final backupPath = entry['backupPath'] as String;
      final file = File(path);
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        if (await file.exists()) await file.delete();
        await _deleteMarker(entry['moveStartedMarker'] as String);
        await _deleteMarker(entry['movedMarker'] as String);
        await backupFile.rename(path);
      } else if (entry['existed'] == true) {
        final moveStarted =
            await File(entry['moveStartedMarker'] as String).exists();
        if (await File(entry['movedMarker'] as String).exists() ||
            (moveStarted && !await file.exists())) {
          throw const FileSystemException('Anki 全量下载的本地媒体索引备份丢失，已阻止打开不一致数据');
        }
      } else if (entry['existed'] != true && await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> _restoreCollection(Map<String, dynamic> plan) async {
    final collectionPath = plan['collectionPath'] as String;
    final backupPath = plan['collectionBackupPath'] as String?;
    final sidecars = plan['collectionSidecars'] as List;
    for (final sidecar in sidecars) {
      if (sidecar is! Map) {
        throw const FormatException('Anki collection 侧文件恢复记录无效');
      }
      if (sidecar['existed'] == true &&
          !await File(sidecar['backupPath'] as String).exists()) {
        throw const FileSystemException(
          'Anki 全量下载的本地 collection 侧文件备份丢失，已阻止打开不完整数据',
        );
      }
    }
    if (backupPath != null && await File(backupPath).exists()) {
      final current = File(collectionPath);
      final displaced = File('$collectionPath.failed-recovery');
      final restore = File('$collectionPath.recovery.tmp');
      if (await restore.exists()) await restore.delete();
      await File(backupPath).copy(restore.path);
      if (await displaced.exists()) await displaced.delete();
      await _clearCollectionSidecars(sidecars);
      final hadCurrent = await current.exists();
      if (hadCurrent) await current.rename(displaced.path);
      try {
        await restore.rename(collectionPath);
      } catch (_) {
        if (hadCurrent && await displaced.exists()) {
          await displaced.rename(collectionPath);
        }
        rethrow;
      }
      if (await displaced.exists()) await displaced.delete();
      await _restoreCollectionSidecars(sidecars);
    } else if (plan['collectionExisted'] == true) {
      throw const FileSystemException(
        'Anki 全量下载的本地 collection 备份丢失，已阻止打开不完整数据',
      );
    } else {
      final collection = File(collectionPath);
      if (await collection.exists()) await collection.delete();
      await _clearCollectionSidecars(sidecars);
    }
  }

  static Future<void> _clearCollectionSidecars(List sidecars) async {
    for (final sidecar in sidecars) {
      final file = File((sidecar as Map)['path'] as String);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<void> _restoreCollectionSidecars(List sidecars) async {
    for (final sidecar in sidecars) {
      final entry = sidecar as Map;
      if (entry['existed'] != true) continue;
      final path = entry['path'] as String;
      final backupPath = entry['backupPath'] as String;
      final restore = File('$path.recovery.tmp');
      if (await restore.exists()) await restore.delete();
      await File(backupPath).copy(restore.path);
      final destination = File(path);
      if (await destination.exists()) await destination.delete();
      await restore.rename(path);
    }
  }

  Future<void> _createMarker(String path) async {
    await File(path).writeAsString('started', flush: true);
  }

  static Future<void> _deleteMarker(String path) async {
    final marker = File(path);
    if (await marker.exists()) await marker.delete();
  }

  Future<void> _writeJournal() async {
    final journal = File(_journalPath);
    final temporary = File('${journal.path}.tmp');
    await temporary.writeAsString(jsonEncode(_plan), flush: true);
    await temporary.rename(journal.path);
  }

  Future<void> _clearJournal() => _clearJournalAt(_journalPath, _plan);

  static Future<void> _clearJournalAt(
    String journalPath,
    Map<String, dynamic> plan,
  ) async {
    final journal = File(journalPath);
    if (await journal.exists()) await journal.delete();
    for (final path in _markerPaths(plan)) {
      final marker = File(path);
      try {
        if (await marker.exists()) await marker.delete();
      } catch (_) {
        // Orphan markers are ignored without their journal.
      }
    }
    for (final sidecar in plan['collectionSidecars'] as List) {
      final entry = sidecar as Map;
      for (final path in [
        entry['backupPath'] as String,
        '${entry['path']}.recovery.tmp',
      ]) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // The durable journal is already cleared; leftover sidecars are inert.
        }
      }
    }
    for (final entry in plan['mediaIndexFiles'] as List) {
      try {
        final file = File((entry as Map)['backupPath'] as String);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // An index backup left after journal cleanup is inert.
      }
    }
    final temporary = File('$journalPath.tmp');
    try {
      if (await temporary.exists()) await temporary.delete();
    } catch (_) {
      // A stale journal temp has no effect on collection recovery.
    }
  }

  static Iterable<String> _markerPaths(Map<String, dynamic> plan) sync* {
    yield plan['mediaStartedMarker'] as String;
    yield plan['mediaMoveStartedMarker'] as String;
    yield plan['mediaMovedMarker'] as String;
    yield plan['collectionStartedMarker'] as String;
    for (final entry in plan['mediaIndexFiles'] as List) {
      yield (entry as Map)['moveStartedMarker'] as String;
      yield entry['movedMarker'] as String;
    }
  }

  static String _indexPath(String documentsPath, String identity) {
    final digest = sha256.convert(utf8.encode(identity)).toString();
    return p.join(documentsPath, 'collection.media.sync.$digest.db');
  }
}
