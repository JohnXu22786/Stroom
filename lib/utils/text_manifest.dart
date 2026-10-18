import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';
import 'file_record.dart';
import '../services/manifest_operations.dart';
import 'folder_path_utils.dart';

// ====================================================================
// TextRecord
// ====================================================================

/// 文本文件记录（manifest 中的一条记录）
class TextRecord
    with Hashable, Storable, Renamable<TextRecord>, Movable<TextRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name; // 用户设置的文件名（不含扩展名）
  @override
  final String hash; // 文本内容的 MD5 哈希值
  @override
  final String format; // 文件格式（txt/srt/vtt 等）
  @override
  final DateTime createdAt;
  @override
  final DateTime modifiedAt; // 内容最后修改时间（未修改时等于 createdAt）
  @override
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）
  final int textLength; // 文本字符长度

  TextRecord({
    String? id,
    required this.name,
    required this.hash,
    this.format = 'txt',
    required this.createdAt,
    DateTime? modifiedAt,
    required this.size,
    this.folder = '',
    this.textLength = 0,
  })  : modifiedAt = modifiedAt ?? createdAt,
        id = id ?? 'txt_${const Uuid().v4()}';

  /// 实体文件存储名
  String get storageFileName {
    final extension = format == 'srt' || format == 'vtt' ? format : 'txt';
    return '$hash.$extension';
  }

  @override
  String get storagePath => storageFileName;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hash': hash,
        'format': format,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'size': size,
        'folder': folder,
        'textLength': textLength,
      };

  factory TextRecord.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now();
    return TextRecord(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      format: map['format'] as String? ?? 'txt',
      createdAt: createdAt,
      // 旧记录没有 modifiedAt：回退为 createdAt（向后兼容）
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : createdAt,
      size: (map['size'] as num?)?.toInt() ?? 0,
      folder: map['folder'] as String? ?? '',
      textLength: (map['textLength'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  TextRecord copyWithName(String name) => TextRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
        textLength: textLength,
      );

  /// 修改文件格式（重命名时通过下拉框切换扩展名）
  TextRecord copyWithFormat(String format) => TextRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
        textLength: textLength,
      );

  @override
  TextRecord copyWithFolder(String folder) => TextRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
        textLength: textLength,
      );

  TextRecord copyWith({
    String? name,
    String? folder,
    int? size,
    int? textLength,
    DateTime? modifiedAt,
  }) =>
      TextRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        size: size ?? this.size,
        folder: folder ?? this.folder,
        textLength: textLength ?? this.textLength,
      );
}

/// 计算文本数据的 MD5 哈希值
String computeTextHash(Uint8List data) {
  final digest = md5.convert(data);
  return digest.toString();
}

// ====================================================================
// TextManifest — thin wrapper around ManifestOperations
// ====================================================================

/// Text file manifest — delegates to [ManifestOperations].
class TextManifest {
  static final Map<String, Future<void>> _pendingSaves = {};
  static final Object _saveLockZoneKey = Object();
  static Future<void>? _pendingRecordMutation;
  static final Object _recordMutationZoneKey = Object();

  /// Serialize file and record mutations by content hash so a deletion cannot
  /// remove text while OCR is publishing a new reference to it.
  static Future<T> withSaveLock<T>(
      String hash, Future<T> Function() action) async {
    final held = Zone.current[_saveLockZoneKey] as Set<String>? ?? const {};
    if (held.contains(hash)) return action();
    final previous = _pendingSaves[hash] ?? Future<void>.value();
    final release = Completer<void>();
    final pending = previous.then((_) => release.future);
    _pendingSaves[hash] = pending;
    await previous;
    try {
      return await runZoned(action, zoneValues: {
        _saveLockZoneKey: {...held, hash}
      });
    } finally {
      release.complete();
      if (identical(_pendingSaves[hash], pending)) _pendingSaves.remove(hash);
    }
  }

  static Future<T> _withSaveLocks<T>(
      Iterable<String> hashes, Future<T> Function() action) {
    final ordered = hashes.toSet().toList()..sort();
    Future<T> acquire(int index) {
      if (index == ordered.length) return action();
      return withSaveLock(ordered[index], () => acquire(index + 1));
    }

    return acquire(0);
  }

  /// Serializes text-row and folder membership changes with folder deletion.
  /// Callers that also need a content hash lock must acquire that lock first.
  static Future<T> _withRecordMutationLock<T>(
    Future<T> Function() action,
  ) async {
    final held = Zone.current[_recordMutationZoneKey] as bool? ?? false;
    if (held) return action();

    final previous = _pendingRecordMutation ?? Future<void>.value();
    final release = Completer<void>();
    final pending = previous.then((_) => release.future);
    _pendingRecordMutation = pending;
    await previous;
    try {
      return await runZoned(action, zoneValues: {_recordMutationZoneKey: true});
    } finally {
      release.complete();
      if (identical(_pendingRecordMutation, pending)) {
        _pendingRecordMutation = null;
      }
    }
  }

  /// Keeps a text-row insertion ordered with folder removal. Hash comes first
  /// to keep one lock order across content saves and deletes.
  static Future<T> withRecordSaveLock<T>(
    String hash,
    Future<T> Function() action,
  ) => withSaveLock(hash, () => _withRecordMutationLock(action));

  /// Serializes every hash-changing row update with saves, deletes, and folder
  /// membership changes. Holding both current and destination hashes keeps a
  /// delete from reselecting a repointed row under only its old hash.
  static Future<bool> withRecordSaveLocks(
    String id,
    String hash,
    Future<void> Function() action,
  ) async {
    while (true) {
      final records = await loadRecordsUncached();
      final currentHashes = records
          .where((record) => record.id == id)
          .map((record) => record.hash)
          .toSet();
      if (currentHashes.isEmpty) return false;
      final hashes = {...currentHashes, hash};
      var retry = false;
      var found = false;

      await _withSaveLocks(hashes, () async {
        await _withRecordMutationLock(() async {
          final lockedHashes = (await loadRecordsUncached())
              .where((record) => record.id == id)
              .map((record) => record.hash)
              .toSet();
          if (lockedHashes.isEmpty) return;
          if (!hashes.containsAll(lockedHashes)) {
            retry = true;
            return;
          }
          found = true;
          await action();
        });
      });

      if (!retry) return found;
    }
  }

  /// Pauses a deletion after its hash check, before the manifest operation.
  @visibleForTesting
  static Future<void> Function()? beforeDeleteWithCurrentHashLocksForTesting;

  /// Pauses folder deletion after its initial row selection, before locks.
  @visibleForTesting
  static Future<void> Function()? beforeFolderDeleteLocksForTesting;

  /// Recheck rows after locking their hashes and retry if any row was
  /// repointed while the locks were being acquired.
  static Future<void> _deleteRecordsWithCurrentHashLocks(
    Set<String> Function(List<TextRecord> records) selectIds,
    Future<void> Function() delete, {
    bool pauseBeforeLocksForTesting = false,
  }) async {
    while (true) {
      final records = await loadRecordsUncached();
      final ids = selectIds(records);
      final selectedHashes = <String, String>{
        for (final record in records)
          if (ids.contains(record.id)) record.id: record.hash,
      };
      final hashes = selectedHashes.values.toSet();
      var retry = false;

      if (pauseBeforeLocksForTesting) {
        await beforeFolderDeleteLocksForTesting?.call();
      }

      await _withSaveLocks(hashes, () async {
        await _withRecordMutationLock(() async {
          final currentRecords = await loadRecordsUncached();
          final currentIds = selectIds(currentRecords);
          final currentHashes = <String, String>{
            for (final record in currentRecords)
              if (currentIds.contains(record.id)) record.id: record.hash,
          };
          if (!_sameRecordHashes(selectedHashes, currentHashes) ||
              !hashes.containsAll(currentHashes.values)) {
            retry = true;
            return;
          }
          await beforeDeleteWithCurrentHashLocksForTesting?.call();
          await delete();
        });
      });

      if (!retry) return;
    }
  }

  static bool _sameRecordHashes(
    Map<String, String> first,
    Map<String, String> second,
  ) {
    if (first.length != second.length) return false;
    return first.entries.every((entry) => second[entry.key] == entry.value);
  }

  static final _ops = ManifestOperations<TextRecord>(
    manifestKey: 'text_manifest',
    storageDirName: 'texts',
    useAppSupportDir: false,
    fromMap: TextRecord.fromMap,
    tableName: 'text_records',
    toMap: (r) => r.toMap(),
  );

  /// Pauses a folder load in tests to exercise callers that await it.
  @visibleForTesting
  static set beforeFolderLoadForTesting(Future<void> Function()? callback) {
    _ops.beforeFolderLoadForTesting = callback;
  }

  /// Pauses cache invalidation in tests after it acquires the mutation lock.
  @visibleForTesting
  static Future<void> Function()? beforeCacheInvalidationForTesting;

  /// Cached refreshes share the mutation lock because they can otherwise
  /// install a snapshot read before a hash update; deletes use this cache for
  /// file reference counts after rechecking authoritative rows.
  static Future<List<TextRecord>> loadRecords() =>
      _withRecordMutationLock(() => _ops.loadRecords());
  static Future<List<TextRecord>> loadRecordsUncached() =>
      _ops.loadRecordsUncached();
  static Future<void> addRecord(
    TextRecord record, {
    void Function()? beforeCommit,
  }) => withRecordSaveLock(
    record.hash,
    () => _ops.addRecord(record, beforeCommit: beforeCommit),
  );

  /// Writes text under the content hash lock, then publishes its row under
  /// the manifest mutation lock.
  static Future<String> saveTextRecord(TextRecord record, String text) =>
      withSaveLock(record.hash, () async {
        final filePath = await writeText(record.storagePath, text);
        await addRecord(record);
        return filePath;
      });

  /// Writes edited text and updates its manifest record under the content
  /// locks, so deletion cannot race a change to the record's content hash.
  static Future<String> updateTextRecord(TextRecord record, String text) async {
    late String filePath;
    final updated = await withRecordSaveLocks(record.id, record.hash, () async {
      filePath = await writeText(record.storagePath, text);
      await _ops.updateRecord(record);
    });
    if (!updated) {
      throw StateError('The text record was deleted before saving.');
    }
    return filePath;
  }

  /// Deletes content only after rechecking persisted references under its hash
  /// lock, so saves publishing that hash cannot race the reference check.
  static Future<bool> deleteFileIfUnreferenced(String hash, String fileName) =>
      withSaveLock(hash, () async {
        final records = await loadRecordsUncached();
        if (records.any((record) => record.storagePath == fileName)) {
          return false;
        }
        return deleteFile(fileName);
      });

  static Future<void> deleteRecord(String id, {bool preserveFiles = false}) =>
      _deleteRecordsWithCurrentHashLocks(
        (_) => {id},
        () => _ops.deleteRecord(id, preserveFiles: preserveFiles),
      );

  /// Rollback already knows the record hash, so it can remove metadata without
  /// first reading the manifest again when that lookup is the failing step.
  static Future<void> deleteRecordWithKnownHash(
    String id,
    String hash, {
    bool preserveFiles = false,
  }) => withRecordSaveLock(
    hash,
    () => _ops.deleteRecord(id, preserveFiles: preserveFiles),
  );

  static Future<void> deleteRecords(List<String> ids) async {
    await _deleteRecordsWithCurrentHashLocks(
      (_) => ids.toSet(),
      () => _ops.deleteRecords(ids),
    );
  }

  static Future<void> updateRecord(TextRecord updated) async {
    await withRecordSaveLocks(
      updated.id,
      updated.hash,
      () => _ops.updateRecord(updated),
    );
  }

  static Future<void> renameRecord(String id, String newName) =>
      _withRecordMutationLock(() => _ops.renameRecord(id, newName));
  static Future<void> moveRecord(String id, String targetFolder) =>
      _withRecordMutationLock(() => _ops.moveRecord(id, targetFolder));

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) async {
    final bytes = await _ops.readFile(fileName);
    if (bytes != null ||
        (!fileName.endsWith('.srt') && !fileName.endsWith('.vtt'))) {
      return bytes;
    }

    final extensionIndex = fileName.lastIndexOf('.');
    final legacyFileName = '${fileName.substring(0, extensionIndex)}.txt';
    return _ops.readFile(legacyFileName);
  }

  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);
  static Future<bool> deleteFile(String fileName) => _ops.deleteFile(fileName);

  /// 写入文本内容到文件
  static Future<String> writeText(String fileName, String text,
      {void Function()? beforeCommit}) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = fileName.endsWith('.txt')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return withSaveLock(hash,
        () => _ops.writeFile(fileName, bytes, beforeCommit: beforeCommit));
  }

  /// 读取文本内容从文件
  static Future<String?> readText(String fileName) async {
    final bytes = await readFile(fileName);
    if (bytes == null) return null;
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes);
  }

  // Folder management
  static Future<Set<String>> getAllFolders({bool throwOnError = false}) =>
      _withRecordMutationLock(
        () => _ops.getAllFolders(throwOnError: throwOnError),
      );
  static Future<void> addFolder(String name) =>
      _withRecordMutationLock(() => _ops.addFolder(name));
  static Future<void> removeFolder(String name) async {
    if (name.isEmpty) {
      await _withRecordMutationLock(() => _ops.removeFolder(name));
      return;
    }
    // Folder removal selects records in the folder and descendants. Its
    // selection must be reconciled while row membership is serialized so an
    // add or move into the subtree cannot escape the hash locks.
    final folderPrefix = '$name/';
    await _deleteRecordsWithCurrentHashLocks(
      (records) => records
          .where(
            (record) =>
                record.folder == name || record.folder.startsWith(folderPrefix),
          )
          .map((record) => record.id)
          .toSet(),
      () => _ops.removeFolder(name),
      pauseBeforeLocksForTesting: true,
    );
  }

  static Future<void> removeFolderFromCache(String folderPath) =>
      _withRecordMutationLock(() => _ops.removeFolderFromCache(folderPath));
  static void invalidateCache() {
    unawaited(_withRecordMutationLock(() async {
      final beforeInvalidate = beforeCacheInvalidationForTesting;
      if (beforeInvalidate != null) await beforeInvalidate();
      _ops.invalidateCache();
    }));
  }

  // Path utilities — forward to shared utilities
  static String getFolderBaseName(String folderPath) =>
      FolderPathUtils.getFolderBaseName(folderPath);
  static String getParentFolderPath(String folderPath) =>
      FolderPathUtils.getParentFolderPath(folderPath);
  static List<String> getChildFolderPaths(String parentPath,
          [List<String>? allPaths]) =>
      FolderPathUtils.getChildFolderPaths(parentPath, allPaths?.toSet() ?? {});
  static String? validateFolderName(String name) =>
      FolderPathUtils.validateFolderName(name);

  /// Get descendant folder paths using the manifest's internal state.
  static Future<List<String>> getAllDescendantFolderPaths(
    String parentPath,
  ) async {
    final allPaths = await getAllFolders();
    return FolderPathUtils.getAllDescendantFolderPaths(parentPath, allPaths);
  }
}
