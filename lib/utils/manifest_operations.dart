import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_record.dart';
import 'web_file_store.dart';
import 'folder_path_utils.dart';
import '../services/manifest_database.dart';

// ---- Access helpers (records always use these mixins) -------------------

String _hashOf(dynamic r) => (r as Hashable).hash;
String _storageNameOf(dynamic r) => (r as Storable).storagePath;
String _folderOf(dynamic r) => (r as FileRecord).folder;

T _copyName<T extends FileRecord>(T r, String name) =>
    (r as dynamic).copyWithName(name) as T;
T _copyFolder<T extends FileRecord>(T r, String folder) =>
    (r as dynamic).copyWithFolder(folder) as T;

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

  /// record → Map<String, dynamic> 转换函数
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
  /// Native 上 tts_audio/<hash>.wav  ↔  Web 上 key = "tts_audio/<hash>.wav"
  String _webKey(String fileName) => '$storageDirName/$fileName';

  // ---- Load / Persist ---------------------------------------------------

  Future<List<T>> loadRecords() async {
    if (_cache != null && !_dirty) return _cache!;

    try {
      final rows = await _dbGetAllRecords();
      _cache = rows.map((m) => fromMap(m)).toList();
      _folderCache = (await ManifestDatabase.getAllFolders()).toSet();
      await _cleanEmptyFoldersFromCache();
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey).loadRecords error: $e');
      _cache = [];
      _folderCache = {};
    }
    _dirty = false;
    return _cache!;
  }

  // ---- CRUD -------------------------------------------------------------

  Future<void> addRecord(T record) async {
    await loadRecords();
    await _dbInsertRecord(toMap(record));
    _cache!.add(record);
  }

  Future<void> _deleteEntityFiles(T record) async {
    final storageName = _storageNameOf(record);
    final refCount =
        _cache!.where((r) => _storageNameOf(r) == storageName).length;
    if (refCount <= 1) {
      final name = _storageNameOf(record);
      // Guard against names without extension
      final dotIndex = name.lastIndexOf('.');
      if (dotIndex == -1) return;
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
        _cache!.where((x) => _hashOf(x) == _hashOf(record)).length;
    if (hashRefCount <= 1) {
      final thumbName = '${_hashOf(record)}_thumb$thumbnailExtension';
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
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final record = _cache![index];
    await _deleteEntityFiles(record);
    _cache!.removeAt(index);
    await _dbDeleteRecord(id);
  }

  /// Batch delete: partition list, delete files, then replace cache.
  Future<void> deleteRecords(List<String> ids) async {
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
      final sn = _storageNameOf(r);
      storageCount[sn] = (storageCount[sn] ?? 0) + 1;
      final h = _hashOf(r);
      hashCount[h] = (hashCount[h] ?? 0) + 1;
    }

    for (final r in toDelete) {
      final sn = _storageNameOf(r);
      storageCount[sn] = (storageCount[sn] ?? 1) - 1;
      if (storageCount[sn]! <= 0) {
        final name = _storageNameOf(r);
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
      final h = _hashOf(r);
      hashCount[h] = (hashCount[h] ?? 1) - 1;
      if (hashCount[h]! <= 0) {
        final thumbName = '${_hashOf(r)}_thumb$thumbnailExtension';
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
  }

  Future<void> updateRecord(T updated) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _cache![index] = updated;
      await _dbUpdateRecord(updated.id, toMap(updated));
    }
  }

  Future<void> renameRecord(String id, String newName) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cache![index] = _copyName(_cache![index], newName);
      await _dbUpdateRecord(id, toMap(_cache![index]));
    }
  }

  Future<void> moveRecord(String id, String targetFolder) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cache![index] = _copyFolder(_cache![index], targetFolder);
      await _dbUpdateRecord(id, toMap(_cache![index]));
    }
  }

  Future<T?> getRecord(String id) async {
    await loadRecords();
    try {
      return _cache!.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- File I/O ---------------------------------------------------------

  /// 是否应使用 WebFileStore（包括纯内存测试模式）
  bool get _useWebFileStore => kIsWeb || WebFileStore.isTestMode;

  Future<String> writeFile(String fileName, Uint8List data) async {
    if (_useWebFileStore) {
      await WebFileStore.write(_webKey(fileName), data);
      return fileName;
    }
    final dir = await _storageDir;
    final filePath = p.join(dir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  Future<Uint8List?> readFile(String fileName) async {
    if (_useWebFileStore) {
      return WebFileStore.read(_webKey(fileName));
    }
    final dir = await _storageDir;
    final filePath = p.join(dir, fileName);
    final file = File(filePath);
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  Future<bool> fileExists(String fileName) async {
    if (_useWebFileStore) return WebFileStore.exists(_webKey(fileName));
    final dir = await _storageDir;
    return await File(p.join(dir, fileName)).exists();
  }

  Future<bool> deleteFile(String fileName) async {
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
  }

  /// Get the storage directory path (Native only).
  Future<String> get storageDirPath async {
    if (_useWebFileStore) return '';
    return _storageDir;
  }

  /// Get a file's absolute path on disk (Native only).
  Future<String?> readFilePath(String fileName) async {
    if (_useWebFileStore) {
      final exists = await WebFileStore.exists(_webKey(fileName));
      return exists ? _webKey(fileName) : null;
    }
    final dir = await _storageDir;
    final filePath = p.join(dir, fileName);
    if (await File(filePath).exists()) return filePath;
    return null;
  }

  // ---- Folder management ------------------------------------------------

  Future<List<String>> loadFolders() async {
    await loadRecords();
    return List.unmodifiable(_folderCache.toList());
  }

  Future<void> addFolder(String folderName) async {
    await loadRecords();
    final name = folderName.trim();
    if (name.isEmpty) return;
    final baseName = FolderPathUtils.getFolderBaseName(name);
    final err = FolderPathUtils.validateFolderName(baseName);
    if (err != null) return;
    if (!_folderCache.contains(name)) {
      _folderCache.add(name);
      await ManifestDatabase.insertFolder(name);
    }
  }

  Future<void> addFolderPath(String folderPath) async {
    await loadRecords();
    if (!_folderCache.contains(folderPath)) {
      _folderCache.add(folderPath);
      await ManifestDatabase.insertFolder(folderPath);
    }
  }

  Future<void> removeFolder(String folderName) async {
    await loadRecords();

    final allPaths = <String>{..._folderCache};
    for (final r in _cache ?? []) {
      final f = _folderOf(r);
      if (f.isNotEmpty) allPaths.add(f);
    }
    final descendants =
        FolderPathUtils.getAllDescendantFolderPaths(folderName, allPaths);

    // Collect all records to delete
    final idsToDelete = <String>[];
    final toRemoveRecords = <T>[];

    for (final child in descendants) {
      _folderCache.remove(child);
      final childRecords = _cache!.where((r) => _folderOf(r) == child).toList();
      toRemoveRecords.addAll(childRecords);
      for (final record in childRecords) {
        idsToDelete.add(record.id);
      }
      await ManifestDatabase.deleteFolder(child);
    }

    _folderCache.remove(folderName);

    final folderRecords =
        _cache!.where((r) => _folderOf(r) == folderName).toList();
    toRemoveRecords.addAll(folderRecords);
    for (final record in folderRecords) {
      idsToDelete.add(record.id);
    }
    await ManifestDatabase.deleteFolder(folderName);

    // Pre-count storage names and hash counts across ALL records before deletion
    final storageNameCount = <String, int>{};
    final hashCount = <String, int>{};
    for (final r in _cache!) {
      final sn = _storageNameOf(r);
      storageNameCount[sn] = (storageNameCount[sn] ?? 0) + 1;
      final h = _hashOf(r);
      hashCount[h] = (hashCount[h] ?? 0) + 1;
    }

    // Decrement per record being deleted; only delete file when count reaches 0
    for (final r in toRemoveRecords) {
      final sn = _storageNameOf(r);
      storageNameCount[sn] = (storageNameCount[sn] ?? 1) - 1;
      if (storageNameCount[sn]! <= 0) {
        final name = _storageNameOf(r);
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
      final h = _hashOf(r);
      hashCount[h] = (hashCount[h] ?? 1) - 1;
      if (hashCount[h]! <= 0) {
        final thumbName = '${_hashOf(r)}_thumb$thumbnailExtension';
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
  }

  Future<Set<String>> getAllFolders() async {
    await loadRecords();
    final folders = <String>{};
    folders.addAll(_folderCache);
    for (final r in _cache ?? []) {
      final f = _folderOf(r);
      if (f.isNotEmpty) folders.add(f);
    }
    return folders;
  }

  Future<void> removeFolderFromCache(String folderPath) async {
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
      await ManifestDatabase.deleteFolder(f);
    }

    // Move records in the removed folder path to root
    final folderPrefix = folderPath.isEmpty ? '' : '$folderPath/';
    for (var i = 0; i < (_cache?.length ?? 0); i++) {
      final r = _cache![i];
      final f = _folderOf(r);
      if (f == folderPath ||
          (folderPrefix.isNotEmpty && f.startsWith(folderPrefix))) {
        _cache![i] = _copyFolder(r, '');
        await _dbUpdateRecord(r.id, {...toMap(r), 'folder': ''});
      }
    }
  }

  Future<void> _cleanEmptyFoldersFromCache() async {
    final validFolders = <String>{};
    for (final r in _cache ?? []) {
      final f = _folderOf(r);
      if (f.isNotEmpty) validFolders.add(f);
      var parent = FolderPathUtils.getParentFolderPath(f);
      while (parent.isNotEmpty) {
        validFolders.add(parent);
        parent = FolderPathUtils.getParentFolderPath(parent);
      }
    }
    final toRemove =
        _folderCache.where((f) => !validFolders.contains(f)).toList();
    for (final f in toRemove) {
      _folderCache.remove(f);
      await ManifestDatabase.deleteFolder(f);
    }
  }

  void invalidateCache() {
    _dirty = true;
    _cache = null;
  }
}
