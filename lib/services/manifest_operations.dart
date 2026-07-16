import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/file_record.dart';
import '../utils/web_file_store.dart';
import '../utils/folder_path_utils.dart';
import '../utils/manifest_operations_shared.dart';
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

  // ---- 判断当前操作哪张表 ------------------------------------------------

  bool get _isImageTable => tableName == ManifestTables.imageRecords;
  bool get _isVideoTable => tableName == ManifestTables.videoRecords;
  bool get _isTextTable => tableName == ManifestTables.textRecords;

  // ---- 数据库代理方法（根据 tableName 路由到正确的表操作） ---------------

  Future<List<Map<String, dynamic>>> _dbGetAllRecords() async {
    if (_isImageTable) return ManifestDatabase.getAllImageRecords();
    if (_isVideoTable) return ManifestDatabase.getAllVideoRecords();
    if (_isTextTable) return ManifestDatabase.getAllTextRecords();
    return ManifestDatabase.getAllAudioRecords();
  }

  Future<void> _dbInsertRecord(Map<String, dynamic> record) async {
    if (_isImageTable) {
      await ManifestDatabase.insertImageRecord(record);
    } else if (_isVideoTable) {
      await ManifestDatabase.insertVideoRecord(record);
    } else if (_isTextTable) {
      await ManifestDatabase.insertTextRecord(record);
    } else {
      await ManifestDatabase.insertAudioRecord(record);
    }
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

  /// Web 上用 "storageDirName/fileName" 做前缀，与 Native 目录结构保持一致。
  /// Native 上 `tts_audio/<hash>.wav`  ↔  Web 上 key = `"tts_audio/<hash>.wav"`
  String _webKey(String fileName) => '$storageDirName/$fileName';

  // ---- Load / Persist ---------------------------------------------------

  Future<List<T>> loadRecords() async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'loadRecords called');
    if (_cache != null && !_dirty) return _cache!;

    try {
      final rows = await _dbGetAllRecords();
      _cache = rows.map((m) => fromMap(m)).toList();
      _folderCache =
          (await ManifestDatabase.getAllFolders(recordTable: tableName))
              .toSet();
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey).loadRecords error: $e');
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'loadRecords failed', e);
      _cache = [];
      _folderCache = {};
    }
    _dirty = false;
    await AppLogService.info('ManifestOperations($manifestKey)',
        'loadRecords completed [count=${_cache?.length}]');
    return _cache!;
  }

  // ---- CRUD -------------------------------------------------------------

  Future<void> addRecord(T record) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'addRecord called [id=${record.id}, type=${record.runtimeType}]');
    try {
      await loadRecords();
      await _dbInsertRecord(toMap(record));
      _cache!.add(record);
      await _ensureFolderPathTracked(folderOf(record));
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'addRecord completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> _deleteEntityFiles(T record) async {
    final storageName = storageNameOf(record);
    final refCount =
        _cache!.where((r) => storageNameOf(r) == storageName).length;
    if (refCount <= 1) {
      final name = storageNameOf(record);
      // Guard against names without extension
      final dotIndex = name.lastIndexOf('.');
      if (dotIndex == -1) return;
      await AppLogService.info('ManifestOperations($manifestKey)',
          '_deleteEntityFiles deleting file [$name]');
      if (kIsWeb) {
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
      final thumbName = '${hashOf(record)}_thumb$thumbnailExtension';
      await AppLogService.info('ManifestOperations($manifestKey)',
          '_deleteEntityFiles deleting thumbnail [$thumbName]');
      if (kIsWeb) {
        await WebFileStore.delete(_webKey(thumbName));
      } else {
        final dir = await _storageDir;
        final thumbFile = File(p.join(dir, thumbName));
        if (await thumbFile.exists()) await thumbFile.delete();
      }
    }
  }

  Future<void> deleteRecord(String id) async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'deleteRecord called [id=$id]');
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index == -1) return;
      final record = _cache![index];
      await _deleteEntityFiles(record);
      _cache!.removeAt(index);
      await _dbDeleteRecord(id);
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'deleteRecord completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteRecord failed', e, st);
      rethrow;
    }
  }

  /// Batch delete: partition list, delete files, then replace cache.
  Future<void> deleteRecords(List<String> ids) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'deleteRecords called [count=${ids.length}]');
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

      for (final r in toDelete) {
        final sn = storageNameOf(r);
        storageCount[sn] = (storageCount[sn] ?? 1) - 1;
        if (storageCount[sn]! <= 0) {
          final name = storageNameOf(r);
          // Guard against names without extension
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex == -1) continue;
          if (kIsWeb) {
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
          final thumbName = '${hashOf(r)}_thumb$thumbnailExtension';
          if (kIsWeb) {
            await WebFileStore.delete(_webKey(thumbName));
          } else {
            final dir = await _storageDir;
            final thumbFile = File(p.join(dir, thumbName));
            if (await thumbFile.exists()) await thumbFile.delete();
          }
        }
      }
      _cache = remaining;
      await _dbDeleteRecords(ids);
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'deleteRecords completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteRecords failed', e, st);
      rethrow;
    }
  }

  Future<void> updateRecord(T updated) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'updateRecord called [id=${updated.id}]');
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        _cache![index] = updated;
        await _dbUpdateRecord(updated.id, toMap(updated));
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'updateRecord completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'updateRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> renameRecord(String id, String newName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'renameRecord called [id=$id, newName=$newName]');
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index != -1) {
        _cache![index] = copyName(_cache![index], newName);
        await _dbUpdateRecord(id, toMap(_cache![index]));
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'renameRecord completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'renameRecord failed', e, st);
      rethrow;
    }
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'moveRecord called [id=$id, targetFolder=$targetFolder]');
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index != -1) {
        _cache![index] = copyFolder(_cache![index], targetFolder);
        await _dbUpdateRecord(id, toMap(_cache![index]));
        await _ensureFolderPathTracked(targetFolder);
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'moveRecord completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'moveRecord failed', e, st);
      rethrow;
    }
  }

  Future<T?> getRecord(String id) async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'getRecord called [id=$id]');
    try {
      await loadRecords();
      final result = _cache!.firstWhere((r) => r.id == id);
      await AppLogService.info('ManifestOperations($manifestKey)',
          'getRecord completed [found=true]');
      return result;
    } on StateError {
      await AppLogService.warning('ManifestOperations($manifestKey)',
          'getRecord: record not found for id=$id');
      return null;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'getRecord failed', e, st);
      return null;
    }
  }

  // ---- File I/O ---------------------------------------------------------

  /// 是否应使用 WebFileStore（包括纯内存测试模式）
  bool get _useWebFileStore => kIsWeb || WebFileStore.isTestMode;

  Future<String> writeFile(String fileName, Uint8List data) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'writeFile called [fileName=$fileName, size=${data.length}]');
    try {
      if (_useWebFileStore) {
        await WebFileStore.write(_webKey(fileName), data);
        await AppLogService.info(
            'ManifestOperations($manifestKey)', 'writeFile completed');
        return fileName;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      await File(filePath).writeAsBytes(data);
      await AppLogService.info('ManifestOperations($manifestKey)',
          'writeFile completed [path=$filePath]');
      return filePath;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'writeFile failed', e, st);
      rethrow;
    }
  }

  Future<Uint8List?> readFile(String fileName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'readFile called [fileName=$fileName]');
    try {
      if (_useWebFileStore) {
        final result = await WebFileStore.read(_webKey(fileName));
        await AppLogService.info('ManifestOperations($manifestKey)',
            'readFile completed [found=${result != null}]');
        return result;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        final result = await file.readAsBytes();
        await AppLogService.info('ManifestOperations($manifestKey)',
            'readFile completed [found=true]');
        return result;
      }
      await AppLogService.info('ManifestOperations($manifestKey)',
          'readFile completed [found=false]');
      return null;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'readFile failed', e, st);
      return null;
    }
  }

  Future<bool> fileExists(String fileName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'fileExists called [fileName=$fileName]');
    try {
      if (_useWebFileStore) {
        final result = await WebFileStore.exists(_webKey(fileName));
        await AppLogService.info('ManifestOperations($manifestKey)',
            'fileExists completed [$result]');
        return result;
      }
      final dir = await _storageDir;
      final result = await File(p.join(dir, fileName)).exists();
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'fileExists completed [$result]');
      return result;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'fileExists failed', e, st);
      return false;
    }
  }

  Future<bool> deleteFile(String fileName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'deleteFile called [fileName=$fileName]');
    try {
      if (_useWebFileStore) {
        await WebFileStore.delete(_webKey(fileName));
        await AppLogService.info(
            'ManifestOperations($manifestKey)', 'deleteFile completed [true]');
        return true;
      }
      final dir = await _storageDir;
      final file = File(p.join(dir, fileName));
      if (await file.exists()) {
        await file.delete();
        await AppLogService.info(
            'ManifestOperations($manifestKey)', 'deleteFile completed [true]');
        return true;
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'deleteFile completed [false]');
      return false;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'deleteFile failed', e, st);
      return false;
    }
  }

  /// Get the storage directory path (Native only).
  Future<String> get storageDirPath async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'storageDirPath called');
    if (_useWebFileStore) return '';
    return _storageDir;
  }

  /// Get a file's absolute path on disk (Native only).
  Future<String?> readFilePath(String fileName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'readFilePath called [fileName=$fileName]');
    try {
      if (_useWebFileStore) {
        final exists = await WebFileStore.exists(_webKey(fileName));
        final result = exists ? _webKey(fileName) : null;
        await AppLogService.info('ManifestOperations($manifestKey)',
            'readFilePath completed [found=$exists]');
        return result;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      if (await File(filePath).exists()) {
        await AppLogService.info('ManifestOperations($manifestKey)',
            'readFilePath completed [found=true]');
        return filePath;
      }
      await AppLogService.info('ManifestOperations($manifestKey)',
          'readFilePath completed [found=false]');
      return null;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'readFilePath failed', e, st);
      return null;
    }
  }

  // ---- Folder management ------------------------------------------------

  Future<List<String>> loadFolders() async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'loadFolders called');
    try {
      await loadRecords();
      await AppLogService.info('ManifestOperations($manifestKey)',
          'loadFolders completed [count=${_folderCache.length}]');
      return List.unmodifiable(_folderCache.toList());
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'loadFolders failed', e, st);
      rethrow;
    }
  }

  Future<void> addFolder(String folderName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'addFolder called [folderName=$folderName]');
    try {
      await loadRecords();
      final name = folderName.trim();
      if (name.isEmpty) return;
      final baseName = FolderPathUtils.getFolderBaseName(name);
      final err = FolderPathUtils.validateFolderName(baseName);
      if (err != null) return;
      if (!_folderCache.contains(name)) {
        _folderCache.add(name);
        await ManifestDatabase.insertFolder(name, recordTable: tableName);
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'addFolder completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addFolder failed', e, st);
      rethrow;
    }
  }

  Future<void> addFolderPath(String folderPath) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'addFolderPath called [folderPath=$folderPath]');
    try {
      await loadRecords();
      if (!_folderCache.contains(folderPath)) {
        _folderCache.add(folderPath);
        await ManifestDatabase.insertFolder(folderPath, recordTable: tableName);
      }
      await AppLogService.info(
          'ManifestOperations($manifestKey)', 'addFolderPath completed');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'addFolderPath failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFolder(String folderName) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'removeFolder called [folderName=$folderName]');
    try {
      await loadRecords();

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
          if (kIsWeb) {
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
          final thumbName = '${hashOf(r)}_thumb$thumbnailExtension';
          if (kIsWeb) {
            await WebFileStore.delete(_webKey(thumbName));
          } else {
            final dir = await _storageDir;
            final thumbFile = File(p.join(dir, thumbName));
            if (await thumbFile.exists()) await thumbFile.delete();
          }
        }
      }

      _cache!.removeWhere((r) => idsToDelete.contains(r.id));

      // Delete records from DB
      if (idsToDelete.isNotEmpty) {
        await _dbDeleteRecords(idsToDelete);
      }
      await AppLogService.info('ManifestOperations($manifestKey)',
          'removeFolder completed [recordsDeleted=${idsToDelete.length}]');
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'removeFolder failed', e, st);
      rethrow;
    }
  }

  Future<Set<String>> getAllFolders() async {
    await AppLogService.info(
        'ManifestOperations($manifestKey)', 'getAllFolders called');
    try {
      await loadRecords();
      final folders = <String>{};
      folders.addAll(_folderCache);
      for (final r in _cache ?? []) {
        final f = folderOf(r);
        if (f.isNotEmpty) folders.add(f);
      }
      await AppLogService.info('ManifestOperations($manifestKey)',
          'getAllFolders completed [count=${folders.length}]');
      return folders;
    } catch (e, st) {
      await AppLogService.error(
          'ManifestOperations($manifestKey)', 'getAllFolders failed', e, st);
      rethrow;
    }
  }

  Future<void> removeFolderFromCache(String folderPath) async {
    await AppLogService.info('ManifestOperations($manifestKey)',
        'removeFolderFromCache called [folderPath=$folderPath]');
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
      var movedCount = 0;
      for (var i = 0; i < (_cache?.length ?? 0); i++) {
        final r = _cache![i];
        final f = folderOf(r);
        if (f == folderPath ||
            (folderPrefix.isNotEmpty && f.startsWith(folderPrefix))) {
          _cache![i] = copyFolder(r, '');
          await _dbUpdateRecord(r.id, {...toMap(r), 'folder': ''});
          movedCount++;
        }
      }
      await AppLogService.info('ManifestOperations($manifestKey)',
          'removeFolderFromCache completed [recordsMoved=$movedCount]');
    } catch (e, st) {
      await AppLogService.error('ManifestOperations($manifestKey)',
          'removeFolderFromCache failed', e, st);
      rethrow;
    }
  }

  /// Ensure a folder path (and all its ancestors) is tracked in [_folderCache]
  /// and the database, so the folder won't disappear when all records are removed.
  Future<void> _ensureFolderPathTracked(String folderPath) async {
    if (folderPath.isEmpty) return;
    final pathsToAdd = <String>[folderPath];
    var parent = FolderPathUtils.getParentFolderPath(folderPath);
    while (parent.isNotEmpty) {
      pathsToAdd.add(parent);
      parent = FolderPathUtils.getParentFolderPath(parent);
    }
    for (final p in pathsToAdd) {
      if (!_folderCache.contains(p)) {
        _folderCache.add(p);
        await ManifestDatabase.insertFolder(p, recordTable: tableName);
      }
    }
  }

  // _cleanEmptyFoldersFromCache was intentionally removed.
  // See git history for the deleted implementation.

  void invalidateCache() {
    AppLogService.info(
        'ManifestOperations($manifestKey)', 'invalidateCache called');
    _dirty = true;
    _cache = null;
  }
}
