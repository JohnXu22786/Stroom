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

  ManifestOperations({
    required this.manifestKey,
    required this.storageDirName,
    this.useAppSupportDir = false,
    required this.fromMap,
    this.onExtraDelete,
    required this.tableName,
    required this.toMap,
  });

  // ---- Per-type cache ---------------------------------------------------

  List<T>? _cache;
  bool _dirty = false;
  List<String> _folderCache = [];

  // ---- 判断当前操作哪张表 ------------------------------------------------

  bool get _isImageTable => tableName == ManifestTables.imageRecords;

  // ---- 数据库代理方法（根据 tableName 路由到正确的表操作） ---------------

  Future<List<Map<String, dynamic>>> _dbGetAllRecords() async {
    if (_isImageTable) return ManifestDatabase.getAllImageRecords();
    return ManifestDatabase.getAllAudioRecords();
  }

  Future<void> _dbInsertRecord(Map<String, dynamic> record) async {
    if (_isImageTable) {
      await ManifestDatabase.insertImageRecord(record);
    } else {
      await ManifestDatabase.insertAudioRecord(record);
    }
  }

  Future<void> _dbUpdateRecord(String id, Map<String, dynamic> updates) async {
    if (_isImageTable) {
      await ManifestDatabase.updateImageRecord(id, updates);
    } else {
      await ManifestDatabase.updateAudioRecord(id, updates);
    }
  }

  Future<void> _dbDeleteRecord(String id) async {
    if (_isImageTable) {
      await ManifestDatabase.deleteImageRecord(id);
    } else {
      await ManifestDatabase.deleteAudioRecord(id);
    }
  }

  Future<void> _dbDeleteRecords(List<String> ids) async {
    if (_isImageTable) {
      await ManifestDatabase.deleteImageRecords(ids);
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
      _folderCache = await ManifestDatabase.getAllFolders();
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey).loadRecords error: $e');
      _cache = [];
      _folderCache = [];
    }
    _dirty = false;
    return _cache!;
  }

  // ---- CRUD -------------------------------------------------------------

  Future<void> addRecord(T record) async {
    await loadRecords();
    _cache!.add(record);
    await _dbInsertRecord(toMap(record));
  }

  Future<void> _deleteEntityFiles(T record) async {
    final refCount = _cache!.where((r) => _hashOf(r) == _hashOf(record)).length;
    if (refCount <= 1) {
      final name = _storageNameOf(record);
      if (kIsWeb) {
        await WebFileStore.delete(_webKey(name));
      } else {
        final dir = await _storageDir;
        final file = File(p.join(dir, name));
        if (await file.exists()) await file.delete();
      }
      await onExtraDelete?.call(record);
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

    for (final r in toDelete) {
      // Compute refCount among ALL records before deletion
      final allRecords = [...remaining, ...toDelete];
      final refCount = allRecords.where((x) => _hashOf(x) == _hashOf(r)).length;
      if (refCount <= 1) {
        final name = _storageNameOf(r);
        if (kIsWeb) {
          await WebFileStore.delete(_webKey(name));
        } else {
          final dir = await _storageDir;
          final file = File(p.join(dir, name));
          if (await file.exists()) await file.delete();
        }
        await onExtraDelete?.call(r);
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

  Future<String> writeFile(String fileName, Uint8List data) async {
    if (kIsWeb) {
      await WebFileStore.write(_webKey(fileName), data);
      return fileName;
    }
    final dir = await _storageDir;
    final filePath = p.join(dir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  Future<Uint8List?> readFile(String fileName) async {
    if (kIsWeb) {
      return WebFileStore.read(_webKey(fileName));
    }
    final dir = await _storageDir;
    final filePath = p.join(dir, fileName);
    final file = File(filePath);
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  Future<bool> fileExists(String fileName) async {
    if (kIsWeb) return WebFileStore.exists(_webKey(fileName));
    final dir = await _storageDir;
    return await File(p.join(dir, fileName)).exists();
  }

  Future<bool> deleteFile(String fileName) async {
    if (kIsWeb) {
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
    if (kIsWeb) return '';
    return _storageDir;
  }

  /// Get a file's absolute path on disk (Native only).
  Future<String?> readFilePath(String fileName) async {
    if (kIsWeb) {
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
    return List.unmodifiable(_folderCache);
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

    // 收集所有需要从 DB 删除的记录 ID
    final idsToDelete = <String>[];

    for (final child in descendants) {
      _folderCache.remove(child);
      final childRecords = _cache!.where((r) => _folderOf(r) == child).toList();
      for (final record in childRecords) {
        idsToDelete.add(record.id);
        await _deleteEntityFiles(record);
        _cache!.remove(record);
      }
      await ManifestDatabase.deleteFolder(child);
    }

    _folderCache.remove(folderName);

    final toRemove = _cache!.where((r) => _folderOf(r) == folderName).toList();
    for (final record in toRemove) {
      idsToDelete.add(record.id);
      await _deleteEntityFiles(record);
      _cache!.remove(record);
    }
    await ManifestDatabase.deleteFolder(folderName);

    // 从 DB 删除受影响的记录
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
  }

  void invalidateCache() {
    _dirty = true;
    _cache = null;
  }
}
