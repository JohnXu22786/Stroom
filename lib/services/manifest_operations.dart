import '../utils/atomic_file.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/file_record.dart';
import '../utils/folder_path_utils.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/manifest_operations_shared.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import 'manifest_database.dart';

// ====================================================================
// ManifestOperations — generic CRUD + folder management
// ====================================================================

/// Generic manifest operations shared by audio and image manifests.
///
/// Each record type creates a singleton [ManifestOperations] instance
/// and forwards its static API to it (see [FileManifest] and [ImageManifest]).
class ManifestOperations<T extends FileRecord> {
  final String manifestKey;
  final String storageDirName;
  final bool useAppSupportDir; // false = app documents dir
  final T Function(Map<String, dynamic>) fromMap;

  /// Optional extra cleanup when entity files are deleted (e.g. .txt sidecar).
  final Future<void> Function(T record)? onExtraDelete;

  /// SQLite 表名（如 'image_records' 或 'audio_records'）
  final String tableName;

  /// record → `Map<String, dynamic>` 转换函数
  final Map<String, dynamic> Function(T record) toMap;

  /// 缩略图文件扩展名（含点号），如 '.png' 或 '.jpg'
  final String thumbnailExtension;

  ManifestOperations({
    required this.manifestKey,
    required this.storageDirName,
    this.useAppSupportDir = false,
    required this.fromMap,
    this.onExtraDelete,
    required this.tableName,
    required this.toMap,
    this.thumbnailExtension = '.png',
  });

  // ---- Per-type cache ---------------------------------------------------

  List<T>? _cache;
  bool _dirty = false;
  Set<String> _folderCache = {};
  int _recordRegistrationRevision = 0;

  /// Pauses a forced refresh between reading records and reading folders.
  @visibleForTesting
  Future<void> Function()? beforeFolderLoadForTesting;

  /// Injects a failure before deleting an audio primary file in focused tests.
  @visibleForTesting
  Future<void> Function(String name)? beforeAudioPrimaryDeleteForTesting;

  // ---- 判断当前操作哪张表 ------------------------------------------------

  bool get _isImageTable => tableName == ManifestTables.imageRecords;
  bool get _isVideoTable => tableName == ManifestTables.videoRecords;
  bool get _isTextTable => tableName == ManifestTables.textRecords;
  bool get _isAudioTable => tableName == ManifestTables.audioRecords;

  /// 缩略图文件名：图片表使用带版本号的 v2 命名（旧版 `_thumb.png`
  /// 是被强制缩放成 256×256 的变形产物，已废弃）；其余表保持原命名。
  String _thumbFileNameOf(T record) {
    final hash = hashOf(record);
    return _isImageTable
        ? imageThumbFileName(hash)
        : '${hash}_thumb$thumbnailExtension';
  }

  /// 删除记录时一并清理图片表旧版（变形）缩略图残留文件
  /// `{hash}_thumb.png`（升级前的安装可能遗留，加载器只在重新生成
  /// v2 时清理）。删除失败仅记日志，不影响删除主流程。
  Future<void> _deleteLegacyThumbIfImage(String hash) async {
    if (!_isImageTable) return;
    try {
      if (_useWebFileStore) {
        await WebFileStore.delete(_webKey('${hash}_thumb.png'));
      } else {
        final dir = await _storageDir;
        final legacy = File(p.join(dir, '${hash}_thumb.png'));
        if (await legacy.exists()) await legacy.delete();
      }
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey) '
          'delete legacy thumbnail failed: $e');
    }
  }

  // ---- 数据库代理方法（根据 tableName 路由到正确的表操作） ---------------

  Future<List<Map<String, dynamic>>> _dbGetAllRecords() async {
    if (_isImageTable) return ManifestDatabase.getAllImageRecords();
    if (_isVideoTable) return ManifestDatabase.getAllVideoRecords();
    if (_isTextTable) return ManifestDatabase.getAllTextRecords();
    return ManifestDatabase.getAllAudioRecords();
  }

  Future<void> _dbUpdateRecord(String id, Map<String, dynamic> updates) async {
    if (_isImageTable) {
      await ManifestDatabase.updateImageRecord(id, updates);
    } else if (_isVideoTable) {
      await ManifestDatabase.updateVideoRecord(id, updates);
    } else if (_isTextTable) {
      await ManifestDatabase.updateTextRecord(id, updates);
    } else {
      await ManifestDatabase.updateAudioRecord(id, updates);
    }
  }

  Future<void> _dbDeleteRecord(String id) async {
    if (_isImageTable) {
      await ManifestDatabase.deleteImageRecord(id);
    } else if (_isVideoTable) {
      await ManifestDatabase.deleteVideoRecord(id);
    } else if (_isTextTable) {
      await ManifestDatabase.deleteTextRecord(id);
    } else {
      await ManifestDatabase.deleteAudioRecord(id);
    }
  }

  Future<void> _dbDeleteRecords(List<String> ids) async {
    if (_isImageTable) {
      await ManifestDatabase.deleteImageRecords(ids);
    } else if (_isVideoTable) {
      await ManifestDatabase.deleteVideoRecords(ids);
    } else if (_isTextTable) {
      await ManifestDatabase.deleteTextRecords(ids);
    } else {
      await ManifestDatabase.deleteAudioRecords(ids);
    }
  }

  // ---- Storage directory ------------------------------------------------

  Future<String> get _storageDir async {
    if (kIsWeb) return '';
    final appDir = useAppSupportDir
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    final dir = p.join(appDir.path, storageDirName);
    final d = Directory(dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return dir;
  }

  /// Storage directory path (Native only).
  ///
  /// Exposed for callers that need the directory itself (e.g. copying a
  /// large already-downloaded file into hash-addressed storage without
  /// buffering it in memory — [writeFile] would need the full bytes).
  /// Matches the ancestors' guard: in web/test-mode file stores (which
  /// have no real directory) this returns '' like every other API here.
  Future<String> get storageDirPath async {
    if (_useWebFileStore) return '';
    return _storageDir;
  }

  /// Web 上用 "storageDirName/fileName" 做前缀，与 Native 目录结构保持一致。
  /// Native 上 `tts_audio/<hash>.wav`  ↔  Web 上 key = `"tts_audio/<hash>.wav"`
  String _webKey(String fileName) => '$storageDirName/$fileName';

  Future<void> _deleteStoredFile(String name) async {
    if (_useWebFileStore) {
      await WebFileStore.delete(_webKey(name));
    } else {
      final dir = await _storageDir;
      final file = File(p.join(dir, name));
      if (await file.exists()) await file.delete();
    }
  }

  Future<bool> _storedFileExists(String name) async {
    if (_useWebFileStore) return WebFileStore.exists(_webKey(name));
    final dir = await _storageDir;
    return File(p.join(dir, name)).exists();
  }

  Future<Uint8List?> _readStoredFile(String name) async {
    if (_useWebFileStore) return WebFileStore.read(_webKey(name));
    final dir = await _storageDir;
    final file = File(p.join(dir, name));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> _writeStoredFile(String name, Uint8List bytes) async {
    if (_useWebFileStore) {
      await WebFileStore.write(_webKey(name), bytes);
    } else {
      final dir = await _storageDir;
      await File(p.join(dir, name)).writeAsBytes(bytes, flush: true);
    }
  }

  Future<Map<String, Uint8List>> _snapshotAudioSidecars(
    Iterable<T> records,
    Map<String, int> storageCount,
  ) async {
    final remainingCount = Map<String, int>.from(storageCount);
    final sidecarNames = <String>{};
    for (final record in records) {
      final storageName = storageNameOf(record);
      remainingCount[storageName] = (remainingCount[storageName] ?? 1) - 1;
      if (remainingCount[storageName]! <= 0 &&
          storageName.lastIndexOf('.') != -1) {
        sidecarNames.add('${hashOf(record)}.txt');
      }
    }

    final sidecars = <String, Uint8List>{};
    for (final name in sidecarNames) {
      final bytes = await _readStoredFile(name);
      if (bytes != null) sidecars[name] = bytes;
    }
    return sidecars;
  }

  Future<void> _restoreAudioSidecars(
    Map<String, Uint8List> sidecars, {
    Set<String>? hashes,
  }) async {
    for (final entry in sidecars.entries) {
      if (hashes != null &&
          !hashes.contains(entry.key.substring(0, entry.key.length - 4))) {
        continue;
      }
      try {
        final currentBytes = await _readStoredFile(entry.key);
        if (currentBytes == null) {
          await _writeStoredFile(entry.key, entry.value);
        }
      } catch (error, stackTrace) {
        await AppLogService.error(
          'ManifestOperations($manifestKey)',
          'failed to restore audio sidecar after file cleanup failure',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<List<T>> _recordsWithStoredAudioFiles(
    Iterable<T> records,
  ) async {
    final available = <T>[];
    for (final record in records) {
      try {
        if (await _storedFileExists(storageNameOf(record))) {
          available.add(record);
        }
      } catch (error, stackTrace) {
        await AppLogService.error(
          'ManifestOperations($manifestKey)',
          'failed to check audio file after cleanup failure',
          error,
          stackTrace,
        );
      }
    }
    return available;
  }

  Future<List<T>> _restoreAudioMetadataAfterFileDeleteFailure(
    Iterable<T> records,
  ) async {
    final restored = <T>[];
    for (final record in records) {
      try {
        await ManifestDatabase.insertRecordWithFolders(
          recordTable: tableName,
          record: toMap(record),
          folderPaths: const [],
        );
        restored.add(record);
      } catch (error, stackTrace) {
        await AppLogService.error(
          'ManifestOperations($manifestKey)',
          'failed to restore audio metadata after file cleanup failure',
          error,
          stackTrace,
        );
      }
    }
    return restored;
  }

  Future<void> _deleteAudioEntityFiles(T record) async {
    final storageName = storageNameOf(record);
    final refCount =
        _cache!.where((r) => storageNameOf(r) == storageName).length;
    if (refCount <= 1 && storageName.lastIndexOf('.') == -1) return;

    final hashRefCount =
        _cache!.where((item) => hashOf(item) == hashOf(record)).length;

    // Delete failure-prone sidecars and thumbnails before the primary audio
    // bytes, so a cleanup error leaves the audio available for a retry.
    if (refCount <= 1 && hashRefCount <= 1) {
      await onExtraDelete?.call(record);
    }
    if (hashRefCount <= 1) {
      await _deleteStoredFile(_thumbFileNameOf(record));
    }
    if (refCount <= 1) {
      await beforeAudioPrimaryDeleteForTesting?.call(storageName);
      await _deleteStoredFile(storageName);
    }
  }

  Future<void> _deleteAudioBatchFiles(
    List<T> records,
    Map<String, int> storageCount,
    Map<String, int> hashCount,
  ) async {
    final primaryFilesToDelete = <String>[];

    // Remove sidecars and thumbnails for the whole batch before deleting any
    // primary audio bytes. If ancillary cleanup fails, every audio file is
    // still available while the rows are restored for a retry.
    for (final record in records) {
      final storageName = storageNameOf(record);
      storageCount[storageName] = (storageCount[storageName] ?? 1) - 1;
      final hash = hashOf(record);
      hashCount[hash] = (hashCount[hash] ?? 1) - 1;
      final lastStorageReference = storageCount[storageName]! <= 0;
      final lastHashReference = hashCount[hash]! <= 0;
      if (lastStorageReference && storageName.lastIndexOf('.') != -1) {
        if (lastHashReference) await onExtraDelete?.call(record);
        primaryFilesToDelete.add(storageName);
      }

      if (lastHashReference) {
        await _deleteStoredFile(_thumbFileNameOf(record));
      }
    }

    for (final name in primaryFilesToDelete) {
      await beforeAudioPrimaryDeleteForTesting?.call(name);
      await _deleteStoredFile(name);
    }
  }

  // ---- Load / Persist ---------------------------------------------------

  /// Read authoritative rows without replacing shared record/folder caches.
  Future<List<T>> loadRecordsUncached() async =>
      (await _dbGetAllRecords()).map(fromMap).toList();

  Future<List<T>> loadRecords({
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    if (_cache != null && !_dirty && !forceRefresh) return _cache!;

    final revision = _recordRegistrationRevision;
    try {
      final rows = await _dbGetAllRecords();
      final records = rows.map((m) => fromMap(m)).toList();
      await beforeFolderLoadForTesting?.call();
      final folders =
          (await ManifestDatabase.getAllFolders(recordTable: tableName))
              .toSet();
      if (_recordRegistrationRevision == revision) {
        _cache = records;
        _folderCache = folders;
        _dirty = false;
      }
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey).loadRecords error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'loadRecords failed', e);
      if (throwOnError) {
        if (_recordRegistrationRevision == revision) _dirty = true;
        rethrow;
      }
      if (_recordRegistrationRevision == revision) {
        _cache = [];
        _folderCache = {};
        _dirty = false;
      }
    }
    return _cache!;
  }

  // ---- CRUD -------------------------------------------------------------

  Future<void> addRecord(T record, {void Function()? beforeCommit}) async {
    try {
      await loadRecords();
      beforeCommit?.call();
      final folders = _folderPathAndAncestors(folderOf(record));
      await ManifestDatabase.insertRecordWithFolders(
        recordTable: tableName,
        record: toMap(record),
        folderPaths: folders,
        beforeCommit: beforeCommit,
      );
      _cache!.add(record);
      _folderCache.addAll(folders);
      _recordRegistrationRevision++;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> _deleteEntityFiles(T record) async {
    if (_isAudioTable) {
      await _deleteAudioEntityFiles(record);
      return;
    }

    final storageName = storageNameOf(record);
    final refCount =
        _cache!.where((r) => storageNameOf(r) == storageName).length;
    if (refCount <= 1) {
      final name = storageNameOf(record);
      // Guard against names without extension
      final dotIndex = name.lastIndexOf('.');
      if (dotIndex == -1) return;
      debugPrint('ManifestOperations($manifestKey) deleting file [$name]');
      if (_useWebFileStore) {
        await WebFileStore.delete(_webKey(name));
      } else {
        final dir = await _storageDir;
        final file = File(p.join(dir, name));
        if (await file.exists()) await file.delete();
      }
      await onExtraDelete?.call(record);
    }
    // Thumbnail deletion: keyed by hash, not storageName
    final hashRefCount =
        _cache!.where((x) => hashOf(x) == hashOf(record)).length;
    if (hashRefCount <= 1) {
      final thumbName = _thumbFileNameOf(record);
      debugPrint(
          'ManifestOperations($manifestKey) deleting thumbnail [$thumbName]');
      if (_useWebFileStore) {
        await WebFileStore.delete(_webKey(thumbName));
      } else {
        final dir = await _storageDir;
        final thumbFile = File(p.join(dir, thumbName));
        if (await thumbFile.exists()) await thumbFile.delete();
      }
      await _deleteLegacyThumbIfImage(hashOf(record));
    }
  }

  Future<void> deleteRecord(String id, {bool preserveFiles = false}) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index == -1) return;
      final record = _cache![index];
      if (_isAudioTable) {
        final storageName = storageNameOf(record);
        final refCount =
            _cache!.where((item) => storageNameOf(item) == storageName).length;
        final sidecars = preserveFiles
            ? <String, Uint8List>{}
            : await _snapshotAudioSidecars(
                [record],
                {storageName: refCount},
              );
        // Keep audio bytes and the cached row available if metadata persistence
        // fails, so callers can retry the deletion.
        await _dbDeleteRecord(id);
        if (!preserveFiles) {
          try {
            await _deleteEntityFiles(record);
          } catch (error, stackTrace) {
            final availableRecords =
                await _recordsWithStoredAudioFiles([record]);
            await _restoreAudioSidecars(
              sidecars,
              hashes: availableRecords.map(hashOf).toSet(),
            );
            final restored = await _restoreAudioMetadataAfterFileDeleteFailure(
              availableRecords,
            );
            if (!restored.any((item) => item.id == record.id)) {
              _cache!.removeWhere((item) => item.id == record.id);
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
        }
        _cache!.removeAt(index);
        return;
      }
      // A caller undoing a just-added record cannot know whether another
      // writer has begun using the same content-addressed file. In that
      // case, remove only its metadata and retain the shared bytes.
      if (!preserveFiles) await _deleteEntityFiles(record);
      _cache!.removeAt(index);
      await _dbDeleteRecord(id);
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteRecord failed', e, st);
      rethrow;
    }
  }

  /// Batch delete: partition list, delete files, then replace cache.
  Future<void> deleteRecords(List<String> ids) async {
    try {
      await loadRecords();
      final idSet = ids.toSet();
      final toDelete = <T>[];
      final remaining = <T>[];
      for (final r in _cache!) {
        if (idSet.contains(r.id)) {
          toDelete.add(r);
        } else {
          remaining.add(r);
        }
      }
      if (toDelete.isEmpty) return;

      // Pre-compute storage name counts and hash counts across all records before deletion
      final storageCount = <String, int>{};
      final hashCount = <String, int>{};
      for (final r in _cache!) {
        final sn = storageNameOf(r);
        storageCount[sn] = (storageCount[sn] ?? 0) + 1;
        final h = hashOf(r);
        hashCount[h] = (hashCount[h] ?? 0) + 1;
      }

      final sidecars = _isAudioTable
          ? await _snapshotAudioSidecars(toDelete, storageCount)
          : <String, Uint8List>{};

      // Commit audio metadata first so a persistence error leaves its cache and
      // files available for retry. If later file cleanup fails, restore those
      // rows so a restart or retry can still find the records.
      if (_isAudioTable) {
        await _dbDeleteRecords(ids);
        try {
          await _deleteAudioBatchFiles(toDelete, storageCount, hashCount);
        } catch (error, stackTrace) {
          final availableRecords = await _recordsWithStoredAudioFiles(toDelete);
          await _restoreAudioSidecars(
            sidecars,
            hashes: availableRecords.map(hashOf).toSet(),
          );
          final restored = await _restoreAudioMetadataAfterFileDeleteFailure(
            availableRecords,
          );
          final restoredIds = restored.map((record) => record.id).toSet();
          _cache = _cache!
              .where((record) =>
                  !idSet.contains(record.id) || restoredIds.contains(record.id))
              .toList();
          Error.throwWithStackTrace(error, stackTrace);
        }
        // Preserve mutations to records that survived this batch while file
        // cleanup was awaiting I/O. Audio updates can update the cache before
        // their JSON write joins the mutation queue held by this deletion.
        _cache!.removeWhere((record) => idSet.contains(record.id));
        return;
      }

      for (final r in toDelete) {
        final sn = storageNameOf(r);
        storageCount[sn] = (storageCount[sn] ?? 1) - 1;
        if (storageCount[sn]! <= 0) {
          final name = storageNameOf(r);
          // Guard against names without extension
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex == -1) continue;
          if (_useWebFileStore) {
            await WebFileStore.delete(_webKey(name));
          } else {
            final dir = await _storageDir;
            final file = File(p.join(dir, name));
            if (await file.exists()) await file.delete();
          }
          await onExtraDelete?.call(r);
        }
        // Thumbnail deletion: keyed by hash, not storageName
        final h = hashOf(r);
        hashCount[h] = (hashCount[h] ?? 1) - 1;
        if (hashCount[h]! <= 0) {
          final thumbName = _thumbFileNameOf(r);
          if (_useWebFileStore) {
            await WebFileStore.delete(_webKey(thumbName));
          } else {
            final dir = await _storageDir;
            final thumbFile = File(p.join(dir, thumbName));
            if (await thumbFile.exists()) await thumbFile.delete();
          }
          await _deleteLegacyThumbIfImage(h);
        }
      }
      _cache = remaining;
      await _dbDeleteRecords(ids);
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteRecords failed', e, st);
      rethrow;
    }
  }

  Future<void> updateRecord(T updated) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        _cache![index] = updated;
        await _dbUpdateRecord(updated.id, toMap(updated));
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'updateRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> renameRecord(String id, String newName) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index != -1) {
        _cache![index] = copyName(_cache![index], newName);
        await _dbUpdateRecord(id, toMap(_cache![index]));
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'renameRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index != -1) {
        _cache![index] = copyFolder(_cache![index], targetFolder);
        await _dbUpdateRecord(id, toMap(_cache![index]));
        await _ensureFolderPathTracked(targetFolder);
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'moveRecord failed', e, st);
      rethrow;
    }
  }

  // ---- File I/O ---------------------------------------------------------

  /// 是否应使用 WebFileStore（包括纯内存测试模式）
  bool get _useWebFileStore => kIsWeb || WebFileStore.isTestMode;

  Future<String> writeFile(String fileName, Uint8List data,
      {void Function()? beforeCommit}) async {
    try {
      if (_useWebFileStore) {
        await WebFileStore.write(_webKey(fileName), data,
            beforeCommit: beforeCommit);
        return fileName;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      if (beforeCommit == null) {
        await File(filePath).writeAsBytes(data);
      } else {
        await AtomicFile.writeBytes(File(filePath), data,
            beforeCommit: beforeCommit);
      }
      return filePath;
    } catch (e, st) {
      debugPrint('ManifestOperations($manifestKey).writeFile error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'writeFile failed', e, st);
      rethrow;
    }
  }

  Future<Uint8List?> readFile(String fileName) async {
    try {
      if (_useWebFileStore) {
        return WebFileStore.read(_webKey(fileName));
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e, st) {
      debugPrint('ManifestOperations($manifestKey).readFile error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'readFile failed', e, st);
      return null;
    }
  }

  Future<bool> deleteFile(String fileName) async {
    try {
      if (_useWebFileStore) {
        await WebFileStore.delete(_webKey(fileName));
        return true;
      }
      final dir = await _storageDir;
      final file = File(p.join(dir, fileName));
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('ManifestOperations($manifestKey).deleteFile error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteFile failed', e, st);
      return false;
    }
  }

  /// Get a file's absolute path on disk (Native only).
  Future<String?> readFilePath(String fileName) async {
    try {
      if (_useWebFileStore) {
        final exists = await WebFileStore.exists(_webKey(fileName));
        return exists ? _webKey(fileName) : null;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      if (await File(filePath).exists()) {
        return filePath;
      }
      return null;
    } catch (e, st) {
      debugPrint('ManifestOperations($manifestKey).readFilePath error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'readFilePath failed', e, st);
      return null;
    }
  }

  // ---- Folder management ------------------------------------------------

  Future<void> addFolder(String folderName) async {
    try {
      await loadRecords();
      final name = folderName.trim();
      if (name.isEmpty) return;
      final baseName = FolderPathUtils.getFolderBaseName(name);
      final err = FolderPathUtils.validateFolderName(baseName);
      if (err != null) return;
      if (!_folderCache.contains(name)) {
        await ManifestDatabase.insertFolder(name, recordTable: tableName);
        _folderCache.add(name);
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addFolder failed', e, st);
      rethrow;
    }
  }

  Future<void> addFolderPath(String folderPath) async {
    try {
      await loadRecords();
      if (!_folderCache.contains(folderPath)) {
        await ManifestDatabase.insertFolder(folderPath, recordTable: tableName);
        _folderCache.add(folderPath);
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addFolderPath failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFolder(String folderName) async {
    try {
      await loadRecords();
      // 空字符串表示根目录，绝不能把全部记录连带文件删除
      if (folderName.isEmpty) return;

      final allPaths = <String>{..._folderCache};
      for (final r in _cache ?? []) {
        final f = folderOf(r);
        if (f.isNotEmpty) allPaths.add(f);
      }
      final descendants =
          FolderPathUtils.getAllDescendantFolderPaths(folderName, allPaths);

      // Collect all records to delete
      final idsToDelete = <String>[];
      final toRemoveRecords = <T>[];

      for (final child in descendants) {
        _folderCache.remove(child);
        final childRecords =
            _cache!.where((r) => folderOf(r) == child).toList();
        toRemoveRecords.addAll(childRecords);
        for (final record in childRecords) {
          idsToDelete.add(record.id);
        }
        await ManifestDatabase.deleteFolder(child, recordTable: tableName);
      }

      _folderCache.remove(folderName);

      final folderRecords =
          _cache!.where((r) => folderOf(r) == folderName).toList();
      toRemoveRecords.addAll(folderRecords);
      for (final record in folderRecords) {
        idsToDelete.add(record.id);
      }
      await ManifestDatabase.deleteFolder(folderName, recordTable: tableName);

      // Pre-count storage names and hash counts across ALL records before deletion
      final storageNameCount = <String, int>{};
      final hashCount = <String, int>{};
      for (final r in _cache!) {
        final sn = storageNameOf(r);
        storageNameCount[sn] = (storageNameCount[sn] ?? 0) + 1;
        final h = hashOf(r);
        hashCount[h] = (hashCount[h] ?? 0) + 1;
      }

      // Decrement per record being deleted; only delete file when count reaches 0
      for (final r in toRemoveRecords) {
        final sn = storageNameOf(r);
        storageNameCount[sn] = (storageNameCount[sn] ?? 1) - 1;
        if (storageNameCount[sn]! <= 0) {
          final name = storageNameOf(r);
          // Guard against names without extension
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex == -1) continue;
          if (_useWebFileStore) {
            await WebFileStore.delete(_webKey(name));
          } else {
            final dir = await _storageDir;
            final file = File(p.join(dir, name));
            if (await file.exists()) await file.delete();
          }
          await onExtraDelete?.call(r);
        }
        // Thumbnail deletion: keyed by hash, not storageName
        final h = hashOf(r);
        hashCount[h] = (hashCount[h] ?? 1) - 1;
        if (hashCount[h]! <= 0) {
          final thumbName = _thumbFileNameOf(r);
          if (_useWebFileStore) {
            await WebFileStore.delete(_webKey(thumbName));
          } else {
            final dir = await _storageDir;
            final thumbFile = File(p.join(dir, thumbName));
            if (await thumbFile.exists()) await thumbFile.delete();
          }
          await _deleteLegacyThumbIfImage(h);
        }
      }

      _cache!.removeWhere((r) => idsToDelete.contains(r.id));

      // Delete records from DB
      if (idsToDelete.isNotEmpty) {
        await _dbDeleteRecords(idsToDelete);
      }
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'removeFolder failed', e, st);
      rethrow;
    }
  }

  Future<Set<String>> getAllFolders() async {
    try {
      await loadRecords();
      final folders = <String>{};
      folders.addAll(_folderCache);
      for (final r in _cache ?? []) {
        final f = folderOf(r);
        if (f.isNotEmpty) folders.add(f);
      }
      return folders;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'getAllFolders failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFolderFromCache(String folderPath) async {
    try {
      await loadRecords();
      final prefix = folderPath.isEmpty ? '' : '$folderPath/';
      final toRemove = <String>[];
      for (final f in _folderCache) {
        if (f == folderPath || f.startsWith(prefix)) {
          toRemove.add(f);
        }
      }
      for (final f in toRemove) {
        _folderCache.remove(f);
        await ManifestDatabase.deleteFolder(f, recordTable: tableName);
      }

      // Move records in the removed folder path to root
      final folderPrefix = folderPath.isEmpty ? '' : '$folderPath/';
      for (var i = 0; i < (_cache?.length ?? 0); i++) {
        final r = _cache![i];
        final f = folderOf(r);
        if (f == folderPath ||
            (folderPrefix.isNotEmpty && f.startsWith(folderPrefix))) {
          _cache![i] = copyFolder(r, '');
          await _dbUpdateRecord(r.id, {...toMap(r), 'folder': ''});
        }
      }
    } catch (e, st) {
      await AppLogService.error('ManifestOperations($manifestKey)',
          'removeFolderFromCache failed', e, st);
      rethrow;
    }
  }

  /// Ensure a folder path (and all its ancestors) is tracked in [_folderCache]
  /// and the database, so the folder won't disappear when all records are removed.
  Future<void> _ensureFolderPathTracked(String folderPath) async {
    for (final p in _folderPathAndAncestors(folderPath)) {
      if (!_folderCache.contains(p)) {
        _folderCache.add(p);
        await ManifestDatabase.insertFolder(p, recordTable: tableName);
      }
    }
  }

  List<String> _folderPathAndAncestors(String folderPath) {
    final paths = <String>[];
    var path = folderPath;
    while (path.isNotEmpty) {
      paths.add(path);
      path = FolderPathUtils.getParentFolderPath(path);
    }
    return paths;
  }

  // _cleanEmptyFoldersFromCache was intentionally removed.
  // See git history for the deleted implementation.

  void invalidateCache() {
    _dirty = true;
    _cache = null;
  }
}
