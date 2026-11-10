import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'file_record.dart';
import '../services/manifest_operations.dart';
import 'folder_path_utils.dart';
import 'content_hash_save_lock.dart';

// ====================================================================
// ImageRecord
// ====================================================================

/// 图片文件记录（manifest 中的一条记录）
class ImageRecord
    with Hashable, Storable, Renamable<ImageRecord>, Movable<ImageRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name; // 用户设置的文件名（不含扩展名）
  @override
  final String hash; // 图片数据的 MD5 哈希值
  @override
  final String format; // 文件格式（jpg, png 等）
  @override
  final DateTime createdAt;
  @override
  final DateTime modifiedAt; // 内容最后修改时间（未修改时等于 createdAt）
  @override
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）

  ImageRecord({
    String? id,
    required this.name,
    required this.hash,
    required this.format,
    required this.createdAt,
    DateTime? modifiedAt,
    required this.size,
    this.folder = '',
  })  : modifiedAt = modifiedAt ?? createdAt,
        id = id ?? 'img_${const Uuid().v4()}';

  /// 实体文件存储名
  String get storageFileName => '$hash.$format';
  @override
  String get storagePath => '$hash.$format';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hash': hash,
        'format': format,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'size': size,
        'folder': folder,
      };

  factory ImageRecord.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now();
    return ImageRecord(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      format: map['format'] as String? ?? 'jpg',
      createdAt: createdAt,
      // 旧记录没有 modifiedAt：回退为 createdAt（向后兼容）
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : createdAt,
      size: (map['size'] as num?)?.toInt() ?? 0,
      folder: map['folder'] as String? ?? '',
    );
  }

  @override
  ImageRecord copyWithName(String name) => ImageRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
      );

  @override
  ImageRecord copyWithFolder(String folder) => ImageRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        size: size,
        folder: folder,
      );

  ImageRecord copyWith({
    String? name,
    String? folder,
    int? size,
    DateTime? modifiedAt,
  }) =>
      ImageRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        size: size ?? this.size,
        folder: folder ?? this.folder,
      );
}

/// 计算图片数据的 MD5 哈希值
String computeImageHash(Uint8List data) {
  final digest = md5.convert(data);
  return digest.toString();
}

// ====================================================================
// ImageManifest — thin wrapper around ManifestOperations
// ====================================================================

/// Image file manifest — delegates to [ManifestOperations].
class ImageManifest {
  static final _saveLocks = ContentHashSaveLock();
  static final _ops = ManifestOperations<ImageRecord>(
    manifestKey: 'image_manifest',
    storageDirName: 'pictures',
    useAppSupportDir: false,
    fromMap: ImageRecord.fromMap,
    tableName: 'image_records',
    toMap: (r) => r.toMap(),
  );

  static Future<List<ImageRecord>> loadRecords() => _ops.loadRecords();

  /// Loads records while preserving read failures for callers that display them.
  static Future<List<ImageRecord>> loadRecordsStrict() =>
      _ops.loadRecords(forceRefresh: true, throwOnError: true);

  /// Include file writing, thumbnail generation, and record insertion in the
  /// action so deletion cannot remove bytes before their new record is saved.
  static Future<T> withSaveLock<T>(
    String hash,
    Future<T> Function() action,
  ) =>
      _saveLocks.withLock(_hashLockKey(hash), action);

  static Future<T> withSaveLocks<T>(
    Iterable<String> hashes,
    Future<T> Function() action,
  ) =>
      _saveLocks.withLocks(hashes.map(_hashLockKey), action);

  static String _hashLockKey(String hash) => 'hash:$hash';

  static List<String> _folderLockKeys(Iterable<String> folders) {
    final keys = <String>{};
    for (final folder in folders) {
      var current = '';
      for (final part in folder.split('/').where((part) => part.isNotEmpty)) {
        current = current.isEmpty ? part : '$current/$part';
        keys.add('folder:$current');
      }
    }
    return keys.toList()..sort();
  }

  static Future<T> _withFolderPathLocks<T>(
    Iterable<String> folders,
    Future<T> Function() action,
  ) =>
      _saveLocks.withFolderReadLocks(_folderLockKeys(folders), action);

  /// Excludes changes to this folder and descendants while sharing ancestors.
  static Future<T> withFolderMutationLock<T>(
    String folder,
    Future<T> Function() action,
  ) {
    final keys = _folderLockKeys([folder]);
    if (keys.isEmpty) return action();
    final ancestors = keys.take(keys.length - 1);
    final leaf = keys.last;
    return _saveLocks.withFolderReadLocks(
      ancestors,
      () => _saveLocks.withFolderWriteLock(leaf, action),
    );
  }

  /// Lets publication and membership updates share the folder path hierarchy.
  static Future<T> withFolderReadLock<T>(
    String folder,
    Future<T> Function() action,
  ) =>
      _withFolderPathLocks([folder], action);

  static Future<T> withFilePublicationLock<T>(
    String hash,
    String folder,
    Future<T> Function() action,
  ) =>
      withFolderReadLock(folder, () => withSaveLock(hash, action));

  static Future<void> addRecord(ImageRecord record) => withFilePublicationLock(
        record.hash,
        record.folder,
        () => _ops.addRecord(record),
      );

  static Future<void> deleteRecord(String id) async {
    while (true) {
      final records = await _ops.loadRecords();
      ImageRecord? record;
      for (final candidate in records) {
        if (candidate.id == id) {
          record = candidate;
          break;
        }
      }
      if (record == null) return;
      final snapshot = record;

      var retry = false;
      await _withFolderPathLocks([snapshot.folder], () async {
        await withSaveLock(snapshot.hash, () async {
          final current = await _ops.loadRecords();
          ImageRecord? latest;
          for (final candidate in current) {
            if (candidate.id == id) {
              latest = candidate;
              break;
            }
          }
          if (latest == null) return;
          if (latest.hash != snapshot.hash ||
              latest.folder != snapshot.folder) {
            retry = true;
            return;
          }
          await _ops.deleteRecord(id);
        });
      });
      if (!retry) return;
    }
  }

  static Future<void> deleteRecords(List<String> ids) async {
    final idSet = ids.toSet();
    while (true) {
      final records = await _ops.loadRecords();
      final selected =
          records.where((record) => idSet.contains(record.id)).toList();
      if (selected.isEmpty) return;
      final selectedById = {for (final record in selected) record.id: record};
      var retry = false;
      await _withFolderPathLocks(
        selected.map((record) => record.folder),
        () => withSaveLocks(selected.map((record) => record.hash), () async {
          final current = await _ops.loadRecords();
          final latest =
              current.where((record) => idSet.contains(record.id)).toList();
          if (latest.length != selected.length ||
              latest.any((record) {
                final previous = selectedById[record.id];
                return previous == null ||
                    previous.hash != record.hash ||
                    previous.folder != record.folder;
              })) {
            retry = true;
            return;
          }
          await _ops.deleteRecords(ids);
        }),
      );
      if (!retry) return;
    }
  }

  static Future<void> updateRecord(ImageRecord updated) async {
    while (true) {
      final records = await _ops.loadRecords();
      ImageRecord? current;
      for (final record in records) {
        if (record.id == updated.id) {
          current = record;
          break;
        }
      }
      if (current == null) return;
      final snapshot = current;
      var retry = false;
      await _withFolderPathLocks(
        [updated.folder, snapshot.folder],
        () => withSaveLocks(
          [updated.hash, snapshot.hash],
          () async {
            final latestRecords = await _ops.loadRecords();
            ImageRecord? latest;
            for (final record in latestRecords) {
              if (record.id == updated.id) {
                latest = record;
                break;
              }
            }
            if (latest == null) return;
            if (latest.hash != snapshot.hash ||
                latest.folder != snapshot.folder) {
              retry = true;
              return;
            }
            await _ops.updateRecord(updated);
          },
        ),
      );
      if (!retry) return;
    }
  }

  static Future<void> renameRecord(String id, String newName) =>
      _ops.renameRecord(id, newName);
  static Future<void> moveRecord(String id, String targetFolder) async {
    while (true) {
      final records = await _ops.loadRecords();
      ImageRecord? current;
      for (final record in records) {
        if (record.id == id) {
          current = record;
          break;
        }
      }
      if (current == null) return;
      final snapshot = current;
      var retry = false;
      await _withFolderPathLocks(
        [targetFolder, snapshot.folder],
        () => withSaveLock(snapshot.hash, () async {
          final latestRecords = await _ops.loadRecords();
          ImageRecord? latest;
          for (final record in latestRecords) {
            if (record.id == id) {
              latest = record;
              break;
            }
          }
          if (latest == null) return;
          if (latest.hash != snapshot.hash ||
              latest.folder != snapshot.folder) {
            retry = true;
            return;
          }
          await _ops.moveRecord(id, targetFolder);
        }),
      );
      if (!retry) return;
    }
  }

  static Future<bool> moveRecordIfFolder(
    String id,
    String expectedFolder,
    String targetFolder, {
    void Function()? onMoved,
  }) async {
    while (true) {
      final records = await _ops.loadRecords();
      ImageRecord? current;
      for (final record in records) {
        if (record.id == id) {
          current = record;
          break;
        }
      }
      if (current == null || current.folder != expectedFolder) return false;
      final snapshot = current;
      var retry = false;
      var moved = false;
      await _withFolderPathLocks(
        [targetFolder, snapshot.folder],
        () => withSaveLock(snapshot.hash, () async {
          final latestRecords = await _ops.loadRecords();
          ImageRecord? latest;
          for (final record in latestRecords) {
            if (record.id == id) {
              latest = record;
              break;
            }
          }
          if (latest == null) return;
          if (latest.hash != snapshot.hash ||
              latest.folder != snapshot.folder) {
            retry = true;
            return;
          }
          moved = await _ops.moveRecordIfFolder(
            id,
            expectedFolder,
            targetFolder,
            onMoved: onMoved,
          );
        }),
      );
      if (!retry) return moved;
    }
  }

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<bool> deleteFile(String fileName) => _ops.deleteFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);

  // Folder management
  static Future<Set<String>> getAllFolders() => _ops.getAllFolders();
  static Future<void> addFolder(String name) =>
      _withFolderPathLocks([name], () => _ops.addFolder(name));
  static Future<void> removeFolder(String name) async {
    await withFolderMutationLock(name, () async {
      final records = await _ops.loadRecords();
      final allFolders = await _ops.getAllFolders();
      final deletedFolders = {
        name,
        ...FolderPathUtils.getAllDescendantFolderPaths(name, allFolders),
      };
      final hashes = records
          .where((record) => deletedFolders.contains(record.folder))
          .map((record) => record.hash);
      await withSaveLocks(hashes, () => _ops.removeFolder(name));
    });
  }

  static Future<void> removeFolderFromCache(String folderPath) =>
      _ops.removeFolderFromCache(folderPath);
  static Future<void> removeFolderMetadataFromCache(String folderPath) =>
      _ops.removeFolderMetadataFromCache(folderPath);
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
}
