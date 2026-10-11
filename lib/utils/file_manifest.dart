import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'web_file_store.dart';
import 'file_record.dart';
import '../services/manifest_database.dart';
import '../services/manifest_operations.dart';
import 'folder_path_utils.dart';

// ====================================================================
// AudioRecord
// ====================================================================

/// 音频文件记录（manifest 中的一条记录）
class AudioRecord
    with Hashable, Storable, Renamable<AudioRecord>, Movable<AudioRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name; // 用户设置的文件名
  @override
  final String hash; // 音频数据的 MD5 哈希值
  @override
  final String format; // 文件格式（wav, mp3 等）
  @override
  final DateTime createdAt;
  @override
  final DateTime modifiedAt; // 内容最后修改时间（未修改时等于 createdAt）
  @override
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）
  final String sourceText; // 源文本
  final int duration; // 时长（秒）

  AudioRecord({
    String? id,
    required this.name,
    required this.hash,
    required this.format,
    required this.createdAt,
    DateTime? modifiedAt,
    required this.size,
    this.folder = '',
    this.sourceText = '',
    this.duration = 0,
  })  : modifiedAt = modifiedAt ?? createdAt,
        id = id ?? 'rec_${const Uuid().v4()}';

  /// 音频文件的存储文件名（基于哈希）
  String get storageFileName => '$hash.$format';

  /// 音频文件的实际存储路径（相对于 tts_audio 目录）
  @override
  String get storagePath => '$hash.$format';

  /// 文本文件的存储路径
  String get textStoragePath => '$hash.txt';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hash': hash,
        'format': format,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'size': size,
        'folder': folder,
        'sourceText': sourceText,
        'duration': duration,
      };

  factory AudioRecord.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now();
    return AudioRecord(
      id: (map['id'] as String?) ?? 'rec_${const Uuid().v4()}',
      name: map['name'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      format: map['format'] as String? ?? 'wav',
      createdAt: createdAt,
      // 旧记录没有 modifiedAt：回退为 createdAt（向后兼容）
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : createdAt,
      size: (map['size'] as num?)?.toInt() ?? 0,
      folder: map['folder'] as String? ?? '',
      sourceText: map['sourceText'] as String? ?? '',
      duration: (map['duration'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  AudioRecord copyWithName(String name) => AudioRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
        sourceText: sourceText,
        duration: duration,
      );

  @override
  AudioRecord copyWithFolder(String folder) => AudioRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
        sourceText: sourceText,
        duration: duration,
      );

  AudioRecord copyWith({
    String? name,
    String? folder,
    String? sourceText,
    int? size,
    int? duration,
    DateTime? modifiedAt,
  }) =>
      AudioRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        size: size ?? this.size,
        duration: duration ?? this.duration,
        folder: folder ?? this.folder,
        sourceText: sourceText ?? this.sourceText,
      );
}

/// 计算音频数据的 MD5 哈希值
String computeAudioHash(Uint8List data) {
  final digest = md5.convert(data);
  return digest.toString();
}

class _StorageFileSaveContext {
  _StorageFileSaveContext(this.storageName);

  final String storageName;
  bool active = true;
}

class _AudioHashFileSaveContext {
  _AudioHashFileSaveContext(this.hashes);

  final Set<String> hashes;
  bool active = true;
}

// ====================================================================
// FileManifest — thin wrapper around ManifestOperations
// ====================================================================

/// Audio file manifest — delegates to [ManifestOperations].
class FileManifest {
  static final Map<String, Future<void>> _storageFileSaveTails = {};
  static final Object _storageFileSaveZoneKey = Object();
  static final Map<String, Future<void>> _audioHashFileSaveTails = {};
  static final Object _audioHashFileSaveZoneKey = Object();
  static void Function(String hash)? onWaitingForAudioHashFileSaveForTesting;
  @visibleForTesting
  static set beforeAudioPrimaryDeleteForTesting(
    Future<void> Function(String name)? callback,
  ) {
    _ops.beforeAudioPrimaryDeleteForTesting = callback;
  }

  static Future<void> _folderRemovalTail = Future<void>.value();
  static Completer<void> _folderRemovalsFinished = Completer<void>()
    ..complete();
  static int _pendingFolderRemovals = 0;

  static String _audioHashForStorageName(String storageName) {
    final name = path.basename(storageName);
    final extensionSeparator = name.lastIndexOf('.');
    return extensionSeparator == -1
        ? name
        : name.substring(0, extensionSeparator);
  }

  static String? _audioHashForSidecar(String fileName) {
    final name = path.basename(fileName);
    if (!name.toLowerCase().endsWith('.txt')) return null;
    return name.substring(0, name.length - '.txt'.length);
  }

  static Future<T> _withAudioHashFileSaveLock<T>(
    String hash,
    Future<T> Function() operation, {
    Future<void> Function(Future<void> previous)? waitForPrevious,
    void Function()? onQueued,
  }) async {
    final currentHashContext = Zone.current[_audioHashFileSaveZoneKey];
    final currentStorageContext = Zone.current[_storageFileSaveZoneKey];
    final activeHashContext = currentHashContext is _AudioHashFileSaveContext &&
            currentHashContext.active
        ? currentHashContext
        : null;
    if (activeHashContext != null && activeHashContext.hashes.contains(hash)) {
      return operation();
    }

    final isNestedSave = activeHashContext != null ||
        (currentStorageContext is _StorageFileSaveContext &&
            currentStorageContext.active);
    while (_pendingFolderRemovals > 0 && !isNestedSave) {
      final folderRemovalFinished = _folderRemovalsFinished.future;
      await folderRemovalFinished;
    }

    final previous = _audioHashFileSaveTails[hash];
    final release = Completer<void>();
    final tail = previous == null
        ? release.future
        : previous.then((_) => release.future);
    _audioHashFileSaveTails[hash] = tail;
    var previousFinished = previous == null;

    void releaseLock() {
      if (release.isCompleted) return;
      release.complete();
      if (!identical(_audioHashFileSaveTails[hash], tail)) return;
      if (previousFinished) {
        _audioHashFileSaveTails.remove(hash);
      } else {
        unawaited(tail.then((_) {
          if (identical(_audioHashFileSaveTails[hash], tail)) {
            _audioHashFileSaveTails.remove(hash);
          }
        }));
      }
    }

    if (previous != null) {
      try {
        onWaitingForAudioHashFileSaveForTesting?.call(hash);
        onQueued?.call();
        final previousReleased = previous.then((_) {
          previousFinished = true;
        });
        await (waitForPrevious?.call(previousReleased) ?? previousReleased);
      } catch (_) {
        releaseLock();
        rethrow;
      }
    }

    final saveContext = _AudioHashFileSaveContext({
      ...?activeHashContext?.hashes,
      hash,
    });
    try {
      return await runZoned<Future<T>>(
        operation,
        zoneValues: {_audioHashFileSaveZoneKey: saveContext},
      );
    } finally {
      saveContext.active = false;
      releaseLock();
    }
  }

  static final _ops = ManifestOperations<AudioRecord>(
    manifestKey: 'audio_manifest',
    storageDirName: 'tts_audio',
    fromMap: AudioRecord.fromMap,
    tableName: 'audio_records',
    toMap: (r) => r.toMap(),
    onExtraDelete: (r) async {
      // Also delete the .txt sidecar file (same prefix convention)
      if (kIsWeb || WebFileStore.isTestMode) {
        await WebFileStore.delete('tts_audio/${r.textStoragePath}');
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final txtFile =
            File(path.join(appDocDir.path, 'tts_audio', r.textStoragePath));
        if (await txtFile.exists()) await txtFile.delete();
      }
    },
  );

  /// Runs a content-addressed audio save under a per-file lock.
  ///
  /// Callers should include both writing the bytes and adding the record in
  /// [operation], so cancellation cleanup cannot race another manifest save
  /// for the same storage name.
  static Future<T> withStorageFileSaveLock<T>(
    String storageName,
    Future<T> Function() operation, {
    Future<void> Function(Future<void> previous)? waitForPrevious,
    void Function()? onQueued,
  }) =>
      _withStorageFileSaveLock(
        storageName,
        operation,
        acquireAudioHashLock: true,
        waitForPrevious: waitForPrevious,
        onQueued: onQueued,
      );

  static Future<T> _withStorageFileSaveLock<T>(
    String storageName,
    Future<T> Function() operation, {
    required bool acquireAudioHashLock,
    Future<void> Function(Future<void> previous)? waitForPrevious,
    void Function()? onQueued,
  }) async {
    final currentContext = Zone.current[_storageFileSaveZoneKey];
    final isNestedSave =
        currentContext is _StorageFileSaveContext && currentContext.active;
    if (currentContext is _StorageFileSaveContext &&
        currentContext.active &&
        currentContext.storageName == storageName) {
      return operation();
    }

    var queuedNotified = false;
    void notifyQueued() {
      if (queuedNotified) return;
      queuedNotified = true;
      onQueued?.call();
    }

    while (_pendingFolderRemovals > 0 && !isNestedSave) {
      notifyQueued();
      final folderRemovalFinished = _folderRemovalsFinished.future;
      await (waitForPrevious?.call(folderRemovalFinished) ??
          folderRemovalFinished);
    }

    final previous = _storageFileSaveTails[storageName];
    final release = Completer<void>();
    final tail = previous == null
        ? release.future
        : previous.then((_) => release.future);
    _storageFileSaveTails[storageName] = tail;
    var previousFinished = previous == null;

    void releaseLock() {
      if (release.isCompleted) return;
      release.complete();
      if (!identical(_storageFileSaveTails[storageName], tail)) return;
      if (previousFinished) {
        _storageFileSaveTails.remove(storageName);
      } else {
        unawaited(tail.then((_) {
          if (identical(_storageFileSaveTails[storageName], tail)) {
            _storageFileSaveTails.remove(storageName);
          }
        }));
      }
    }

    if (previous != null) {
      try {
        notifyQueued();
        final previousReleased = previous.then((_) {
          previousFinished = true;
        });
        await (waitForPrevious?.call(previousReleased) ?? previousReleased);
      } catch (_) {
        releaseLock();
        rethrow;
      }
    }

    final saveContext = _StorageFileSaveContext(storageName);
    try {
      return await runZoned<Future<T>>(
        () => acquireAudioHashLock
            ? _withAudioHashFileSaveLock(
                _audioHashForStorageName(storageName),
                operation,
                waitForPrevious: waitForPrevious,
                onQueued: notifyQueued,
              )
            : operation(),
        zoneValues: {_storageFileSaveZoneKey: saveContext},
      );
    } finally {
      saveContext.active = false;
      releaseLock();
    }
  }

  static Future<T> _withFolderRemovalLock<T>(
    Future<T> Function() operation, {
    void Function()? onWaitingForSaves,
  }) async {
    final previousRemoval = _folderRemovalTail;
    final releaseRemoval = Completer<void>();
    final removalTail = previousRemoval.then((_) => releaseRemoval.future);
    _folderRemovalTail = removalTail;
    if (_pendingFolderRemovals++ == 0) {
      _folderRemovalsFinished = Completer<void>();
    }

    try {
      await previousRemoval;
      final activeSaves = [
        ..._storageFileSaveTails.values,
        ..._audioHashFileSaveTails.values,
      ];
      if (activeSaves.isNotEmpty) {
        onWaitingForSaves?.call();
        await Future.wait(activeSaves);
      }
      return await operation();
    } finally {
      releaseRemoval.complete();
      _pendingFolderRemovals--;
      if (_pendingFolderRemovals == 0) {
        _folderRemovalsFinished.complete();
      }
      if (identical(_folderRemovalTail, removalTail)) {
        unawaited(removalTail.then((_) {
          if (identical(_folderRemovalTail, removalTail)) {
            _folderRemovalTail = Future<void>.value();
          }
        }));
      }
    }
  }

  static Future<List<AudioRecord>> loadRecords() => _ops.loadRecords();

  /// Loads authoritative records and propagates database errors to callers
  /// that must not interpret a failed read as an empty manifest.
  static Future<List<AudioRecord>> loadRecordsStrict() =>
      _ops.loadRecords(forceRefresh: true, throwOnError: true);
  static Future<void> addRecord(AudioRecord record) {
    final currentContext = Zone.current[_storageFileSaveZoneKey];
    if (currentContext is _StorageFileSaveContext &&
        currentContext.active &&
        currentContext.storageName == record.storageFileName) {
      return _ops.addRecord(record);
    }
    return withStorageFileSaveLock(
      record.storageFileName,
      () => _ops.addRecord(record),
    );
  }

  static Future<void> deleteRecord(String id,
      {bool preserveFiles = false}) async {
    final records = await _ops.loadRecords();
    AudioRecord? record;
    for (final candidate in records) {
      if (candidate.id == id) {
        record = candidate;
        break;
      }
    }
    if (record == null) {
      await ManifestDatabase.withAudioRecordMutationLock(
        () => _ops.deleteRecord(id, preserveFiles: preserveFiles),
      );
      return;
    }
    await withStorageFileSaveLock(
      record.storageFileName,
      () => ManifestDatabase.withAudioRecordMutationLock(
        () => _ops.deleteRecord(id, preserveFiles: preserveFiles),
      ),
    );
  }

  static Future<void> deleteRecords(List<String> ids) async {
    final idSet = ids.toSet();
    final records = await _ops.loadRecords();
    final storageNames = records
        .where((record) => idSet.contains(record.id))
        .map((record) => record.storageFileName)
        .toSet()
        .toList()
      ..sort();

    Future<void> deleteWithLocks(int index) async {
      if (index == storageNames.length) {
        await _withAudioHashFileSaveLocks(
          storageNames.map(_audioHashForStorageName),
          () => ManifestDatabase.withAudioRecordMutationLock(
            () => _ops.deleteRecords(ids),
          ),
        );
        return;
      }
      await _withStorageFileSaveLock(
        storageNames[index],
        () => deleteWithLocks(index + 1),
        acquireAudioHashLock: false,
      );
    }

    await deleteWithLocks(0);
  }

  static Future<T> _withAudioHashFileSaveLocks<T>(
    Iterable<String> hashes,
    Future<T> Function() operation,
  ) {
    final sortedHashes = hashes.toSet().toList()..sort();

    Future<T> acquire(int index) {
      if (index == sortedHashes.length) return operation();
      return _withAudioHashFileSaveLock(
        sortedHashes[index],
        () => acquire(index + 1),
      );
    }

    return acquire(0);
  }

  static Future<void> updateRecord(AudioRecord updated) =>
      _withRecordStorageFileSaveLock(
        updated.id,
        () => _ops.updateRecord(updated),
      );

  static Future<void> renameRecord(String id, String newName) =>
      _withRecordStorageFileSaveLock(
        id,
        () => _ops.renameRecord(id, newName),
      );

  static Future<void> moveRecord(String id, String targetFolder) =>
      _withRecordStorageFileSaveLock(
        id,
        () => _ops.moveRecord(id, targetFolder),
      );

  static Future<void> _withRecordStorageFileSaveLock(
    String id,
    Future<void> Function() operation,
  ) async {
    final records = await _ops.loadRecords();
    AudioRecord? record;
    for (final candidate in records) {
      if (candidate.id == id) {
        record = candidate;
        break;
      }
    }
    if (record == null) {
      await operation();
      return;
    }
    await withStorageFileSaveLock(record.storageFileName, operation);
  }

  static Future<AudioRecord?> getRecordByHash(String hash) async {
    final records = await _ops.loadRecords();
    try {
      return records.firstWhere((r) => r.hash == hash);
    } catch (_) {
      return null;
    }
  }

  static Future<String> writeFile(String fileName, Uint8List data) {
    final hash = _audioHashForSidecar(fileName);
    if (hash == null) return _ops.writeFile(fileName, data);
    return _withAudioHashFileSaveLock(
      hash,
      () => _ops.writeFile(fileName, data),
    );
  }

  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);
  static Future<bool> deleteFile(String fileName) {
    final hash = _audioHashForSidecar(fileName);
    if (hash == null) return _ops.deleteFile(fileName);
    return _withAudioHashFileSaveLock(
      hash,
      () => _ops.deleteFile(fileName),
    );
  }

  // Folder management
  static Future<void> addFolder(String name) => _ops.addFolder(name);
  static Future<void> addFolderPath(String pathName) =>
      _ops.addFolderPath(pathName);
  static Future<void> removeFolder(
    String name, {
    void Function()? onWaitingForSaves,
  }) =>
      _withFolderRemovalLock(
        () async {
          await loadRecordsStrict();
          await _ops.removeFolder(name);
        },
        onWaitingForSaves: onWaitingForSaves,
      );
  static Future<Set<String>> getAllFolders() => _ops.getAllFolders();
  static Future<void> removeFolderFromCache(String folderPath) =>
      _ops.removeFolderFromCache(folderPath);
  static void invalidateCache() => _ops.invalidateCache();

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
      String parentPath) async {
    final allPaths = await _ops.getAllFolders();
    return FolderPathUtils.getAllDescendantFolderPaths(parentPath, allPaths);
  }

  /// Storage directory path for audio files (Native only) — used to copy
  /// large downloaded files into hash-addressed storage without
  /// buffering them in memory.
  static Future<String> get ttsAudioDir => _ops.storageDirPath;
}
