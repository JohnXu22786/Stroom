import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:crypto/crypto.dart' show md5;
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

  static final RegExp _textContentHashPattern = RegExp(
    r'^[0-9a-f]{32}$',
    caseSensitive: false,
  );

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
  Future<void> _textRecordMutationQueue = Future<void>.value();

  Future<R> _serializeTextRecordMutation<R>(
    Future<R> Function() operation,
  ) async {
    final previous = _textRecordMutationQueue;
    final release = Completer<void>();
    _textRecordMutationQueue = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  // ---- 判断当前操作哪张表 ------------------------------------------------

  bool get _isImageTable => tableName == ManifestTables.imageRecords;
  bool get _isVideoTable => tableName == ManifestTables.videoRecords;
  bool get _isTextTable => tableName == ManifestTables.textRecords;

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
      debugPrint(
        'ManifestOperations($manifestKey) '
        'delete legacy thumbnail failed: $e',
      );
    }
  }

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

  // ---- Load / Persist ---------------------------------------------------

  Future<List<T>> loadRecords({
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    if (_cache != null && !_dirty && !forceRefresh) return _cache!;

    try {
      final rows = await _dbGetAllRecords();
      final records = rows.map((m) => fromMap(m)).toList();
      final folders = (await ManifestDatabase.getAllFolders(
        recordTable: tableName,
      )).toSet();
      _cache = records;
      _folderCache = folders;
      _dirty = false;
    } catch (e) {
      debugPrint('ManifestOperations($manifestKey).loadRecords error: $e');
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'loadRecords failed',
        e,
      );
      if (throwOnError) {
        _dirty = true;
        rethrow;
      }
      _cache = [];
      _folderCache = {};
      _dirty = false;
    }
    return _cache!;
  }

  // ---- CRUD -------------------------------------------------------------

  Future<void> addRecord(T record) => _isTextTable
      ? _serializeTextRecordMutation(() => _addRecord(record))
      : _addRecord(record);

  Future<String> addTextRecordWithContent(T record, Uint8List contentBytes) {
    if (!_isTextTable) {
      throw StateError('Text content writes are only for text records.');
    }
    final hash = hashOf(record);
    if (!_textContentHashPattern.hasMatch(hash)) {
      throw ArgumentError.value(
        hash,
        'record.hash',
        'Invalid text content hash.',
      );
    }
    if (md5.convert(contentBytes).toString() != hash) {
      throw ArgumentError('Text content bytes do not match record.hash.');
    }
    return _serializeTextRecordMutation(() async {
      final filePath = await writeFile(storageNameOf(record), contentBytes);
      try {
        await _addRecord(record);
      } catch (_) {
        await _deleteTextFileIfUnreferenced(hashOf(record));
        rethrow;
      }
      return filePath;
    });
  }

  Future<void> _addRecord(T record) async {
    try {
      await loadRecords();
      if (_isTextTable) {
        final hash = hashOf(record);
        if (!_textContentHashPattern.hasMatch(hash)) {
          throw StateError('Text content hash is invalid.');
        }
        if (await readFile(storageNameOf(record)) == null) {
          throw StateError('Text content file is missing.');
        }
      }
      await _dbInsertRecord(toMap(record));
      _cache!.add(record);
      try {
        await _ensureFolderPathTracked(folderOf(record));
      } catch (error) {
        // The record itself carries its folder, so a failure to update the
        // auxiliary folder index must not report this committed add as failed.
        await AppLogService.warning(
          'ManifestOperations($manifestKey)',
          'Record ${record.id} was added, but folder tracking failed: $error',
        );
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'addRecord failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> _deleteEntityFiles(T record) async {
    final storageName = storageNameOf(record);
    final refCount = _cache!
        .where((r) => storageNameOf(r) == storageName)
        .length;
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
    final hashRefCount = _cache!
        .where((x) => hashOf(x) == hashOf(record))
        .length;
    if (hashRefCount <= 1) {
      final thumbName = _thumbFileNameOf(record);
      debugPrint(
        'ManifestOperations($manifestKey) deleting thumbnail [$thumbName]',
      );
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

  Future<void> deleteRecord(String id, {bool preserveFiles = false}) =>
      _isTextTable
      ? _serializeTextRecordMutation(
          () => _deleteRecord(id, preserveFiles: preserveFiles),
        )
      : _deleteRecord(id, preserveFiles: preserveFiles);

  Future<void> _deleteRecord(String id, {bool preserveFiles = false}) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index == -1) return;
      final record = _cache![index];
      // A caller undoing a just-added record cannot know whether another
      // writer has begun using the same content-addressed file. In that
      // case, remove only its metadata and retain the shared bytes.
      if (_isTextTable) {
        await _dbDeleteRecord(id);
        if (!preserveFiles) {
          try {
            await _deleteEntityFiles(record);
          } catch (error) {
            await AppLogService.warning(
              'ManifestOperations($manifestKey)',
              'Text record $id was deleted, but content cleanup failed: $error',
            );
          }
        }
        _cache!.removeAt(index);
      } else {
        if (!preserveFiles) await _deleteEntityFiles(record);
        _cache!.removeAt(index);
        await _dbDeleteRecord(id);
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'deleteRecord failed',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Batch delete: partition list, delete files, then replace cache.
  Future<void> deleteRecords(List<String> ids) => _isTextTable
      ? _serializeTextRecordMutation(() => _deleteRecords(ids))
      : _deleteRecords(ids);

  Future<void> _deleteRecords(List<String> ids) async {
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

      if (_isTextTable) {
        await _dbDeleteRecords(ids);
      }

      try {
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
      } catch (error) {
        if (!_isTextTable) rethrow;
        await AppLogService.warning(
          'ManifestOperations($manifestKey)',
          'Text records were deleted, but content cleanup failed: $error',
        );
      }
      _cache = remaining;
      if (!_isTextTable) await _dbDeleteRecords(ids);
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'deleteRecords failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> updateRecord(T updated) => _isTextTable
      ? _serializeTextRecordMutation(() => _updateRecord(updated))
      : _updateRecord(updated);

  Future<void> _updateRecord(T updated) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        _cache![index] = updated;
        await _dbUpdateRecord(updated.id, toMap(updated));
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'updateRecord failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<bool> updateTextRecordMetadata(
    String id,
    T Function(T current) update,
  ) {
    if (!_isTextTable) {
      throw StateError('Metadata updates are only for text records.');
    }
    return _serializeTextRecordMutation(() async {
      try {
        await loadRecords(forceRefresh: true);
        final index = _cache!.indexWhere((record) => record.id == id);
        if (index == -1) return false;
        final updated = update(_cache![index]);
        if (updated.id != id) {
          throw StateError('Text metadata updates cannot change record IDs.');
        }
        await _dbUpdateRecord(updated.id, toMap(updated));
        _cache![index] = updated;
        try {
          await _ensureFolderPathTracked(folderOf(updated));
        } catch (error) {
          await AppLogService.warning(
            'ManifestOperations($manifestKey)',
            'Text record $id was updated, but folder tracking failed: $error',
          );
        }
        return true;
      } catch (e, st) {
        await AppLogService.error(
          'ManifestOperations($manifestKey)',
          'update text metadata failed',
          e,
          st,
        );
        rethrow;
      }
    });
  }

  /// Holds the text-record mutation queue while a tool reads record metadata
  /// and its referenced content as one consistent snapshot.
  Future<R> withSerializedTextRead<R>(Future<R> Function() read) {
    if (!_isTextTable) {
      throw StateError('Serialized text reads are only for text records.');
    }
    return _serializeTextRecordMutation(read);
  }

  /// Update a text record only while its content hash matches the caller's
  /// snapshot, so concurrent edits cannot silently overwrite one another.
  Future<bool> updateTextRecordIfHash(
    String id,
    String expectedHash,
    Map<String, dynamic> expectedMetadata,
    T updated,
  ) => _serializeTextRecordMutation(
    () => _updateTextRecordIfHash(id, expectedHash, expectedMetadata, updated),
  );

  Future<bool> updateTextRecordIfHashWithContent(
    String id,
    String expectedHash,
    Map<String, dynamic> expectedMetadata,
    T updated,
    Uint8List contentBytes,
  ) {
    if (!_isTextTable) {
      throw StateError('Conditional hash updates are only for text records.');
    }
    if (updated.id != id) {
      throw ArgumentError('Conditional text updates cannot change record IDs.');
    }
    final updatedHash = hashOf(updated);
    if (!_textContentHashPattern.hasMatch(updatedHash)) {
      throw ArgumentError.value(
        updatedHash,
        'updated.hash',
        'Invalid text content hash.',
      );
    }
    if (md5.convert(contentBytes).toString() != updatedHash) {
      throw ArgumentError('Text content bytes do not match updated.hash.');
    }
    return _serializeTextRecordMutation(() async {
      await loadRecords(forceRefresh: true);
      final oldIndex = _cache!.indexWhere((record) => record.id == id);
      final oldHash = oldIndex == -1 ? null : hashOf(_cache![oldIndex]);
      await writeFile(storageNameOf(updated), contentBytes);
      late final bool replaced;
      try {
        replaced = await _updateTextRecordIfHash(
          id,
          expectedHash,
          expectedMetadata,
          updated,
        );
      } catch (_) {
        await _deleteTextFileIfUnreferenced(hashOf(updated));
        rethrow;
      }
      final cleanupHash = replaced ? oldHash : hashOf(updated);
      if (cleanupHash != null && cleanupHash != hashOf(updated)) {
        await _deleteTextFileIfUnreferenced(cleanupHash);
      } else if (!replaced) {
        await _deleteTextFileIfUnreferenced(hashOf(updated));
      }
      return replaced;
    });
  }

  Future<void> _deleteTextFileIfUnreferenced(String hash) async {
    if (!_textContentHashPattern.hasMatch(hash)) return;
    if (_cache == null || _dirty) await loadRecords(forceRefresh: true);
    final storageName = '$hash.txt';
    if (_cache!.any((record) => storageNameOf(record) == storageName)) return;
    try {
      await deleteFile(storageName);
    } catch (error) {
      debugPrint(
        'ManifestOperations($manifestKey) cleanup of unreferenced text '
        'content [$storageName] failed: $error',
      );
      await AppLogService.warning(
        'ManifestOperations($manifestKey)',
        'Failed to clean up unreferenced text content [$storageName].',
      );
    }
  }

  Future<bool> _updateTextRecordIfHash(
    String id,
    String expectedHash,
    Map<String, dynamic> expectedMetadata,
    T updated,
  ) async {
    if (!_isTextTable) {
      throw StateError('Conditional hash updates are only for text records.');
    }
    if (updated.id != id) {
      throw ArgumentError('Conditional text updates cannot change record IDs.');
    }
    try {
      await loadRecords(forceRefresh: true);
      final index = _cache!.indexWhere((record) => record.id == id);
      if (index == -1 || hashOf(_cache![index]) != expectedHash) return false;
      final changed = await ManifestDatabase.updateTextRecordIfHash(
        id,
        expectedHash,
        expectedMetadata,
        toMap(updated),
      );
      if (!changed) {
        _dirty = true;
        return false;
      }
      _cache![index] = updated;
      try {
        await _ensureFolderPathTracked(folderOf(updated));
      } catch (error) {
        await AppLogService.warning(
          'ManifestOperations($manifestKey)',
          'Text record $id was updated, but folder tracking failed: $error',
        );
      }
      return true;
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'conditional text update failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> renameRecord(String id, String newName) => _isTextTable
      ? _serializeTextRecordMutation(() => _renameRecord(id, newName))
      : _renameRecord(id, newName);

  Future<void> _renameRecord(String id, String newName) async {
    try {
      await loadRecords();
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index != -1) {
        _cache![index] = copyName(_cache![index], newName);
        await _dbUpdateRecord(id, toMap(_cache![index]));
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'renameRecord failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> moveRecord(String id, String targetFolder) => _isTextTable
      ? _serializeTextRecordMutation(() => _moveRecord(id, targetFolder))
      : _moveRecord(id, targetFolder);

  Future<void> _moveRecord(String id, String targetFolder) async {
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
        'ManifestOperations($manifestKey)',
        'moveRecord failed',
        e,
        st,
      );
      rethrow;
    }
  }

  // ---- File I/O ---------------------------------------------------------

  /// 是否应使用 WebFileStore（包括纯内存测试模式）
  bool get _useWebFileStore => kIsWeb || WebFileStore.isTestMode;

  Future<String> writeFile(String fileName, Uint8List data) async {
    try {
      if (_useWebFileStore) {
        await WebFileStore.write(_webKey(fileName), data);
        return fileName;
      }
      final dir = await _storageDir;
      final filePath = p.join(dir, fileName);
      await File(filePath).writeAsBytes(data);
      return filePath;
    } catch (e, st) {
      debugPrint('ManifestOperations($manifestKey).writeFile error: $e');
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'writeFile failed',
        e,
        st,
      );
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
        'ManifestOperations($manifestKey)',
        'readFile failed',
        e,
        st,
      );
      return null;
    }
  }

  Future<Uint8List?> readFileLimited(String fileName, int maxBytes) async {
    if (_useWebFileStore) {
      return WebFileStore.readLimited(_webKey(fileName), maxBytes);
    }
    final dir = await _storageDir;
    final file = File(p.join(dir, fileName));
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      throw StoredFileSizeLimitExceeded(maxBytes);
    }
    final data = await file.readAsBytes();
    if (data.lengthInBytes > maxBytes) {
      throw StoredFileSizeLimitExceeded(maxBytes);
    }
    return data;
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
        'ManifestOperations($manifestKey)',
        'deleteFile failed',
        e,
        st,
      );
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
        'ManifestOperations($manifestKey)',
        'readFilePath failed',
        e,
        st,
      );
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
        _folderCache.add(name);
        await ManifestDatabase.insertFolder(name, recordTable: tableName);
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'addFolder failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> addFolderPath(String folderPath) async {
    try {
      await loadRecords();
      if (!_folderCache.contains(folderPath)) {
        _folderCache.add(folderPath);
        await ManifestDatabase.insertFolder(folderPath, recordTable: tableName);
      }
    } catch (e, st) {
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'addFolderPath failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> removeFolder(String folderName) => _isTextTable
      ? _serializeTextRecordMutation(() => _removeFolder(folderName))
      : _removeFolder(folderName);

  Future<void> _removeFolder(String folderName) async {
    try {
      await loadRecords();
      // 空字符串表示根目录，绝不能把全部记录连带文件删除
      if (folderName.isEmpty) return;

      final allPaths = <String>{..._folderCache};
      for (final r in _cache ?? []) {
        final f = folderOf(r);
        if (f.isNotEmpty) allPaths.add(f);
      }
      final descendants = FolderPathUtils.getAllDescendantFolderPaths(
        folderName,
        allPaths,
      );

      // Collect all records to delete
      final idsToDelete = <String>[];
      final toRemoveRecords = <T>[];

      for (final child in descendants) {
        _folderCache.remove(child);
        final childRecords = _cache!
            .where((r) => folderOf(r) == child)
            .toList();
        toRemoveRecords.addAll(childRecords);
        for (final record in childRecords) {
          idsToDelete.add(record.id);
        }
        await ManifestDatabase.deleteFolder(child, recordTable: tableName);
      }

      _folderCache.remove(folderName);

      final folderRecords = _cache!
          .where((r) => folderOf(r) == folderName)
          .toList();
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
        'ManifestOperations($manifestKey)',
        'removeFolder failed',
        e,
        st,
      );
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
        'ManifestOperations($manifestKey)',
        'getAllFolders failed',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> removeFolderFromCache(String folderPath) async {
    if (_isTextTable) {
      return _serializeTextRecordMutation(
        () => _removeFolderFromCache(folderPath),
      );
    }
    return _removeFolderFromCache(folderPath);
  }

  Future<void> _removeFolderFromCache(String folderPath) async {
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
      await AppLogService.error(
        'ManifestOperations($manifestKey)',
        'removeFolderFromCache failed',
        e,
        st,
      );
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
    _dirty = true;
    _cache = null;
  }
}
