import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'file_record.dart';
import 'manifest_operations.dart';
import 'folder_path_utils.dart';

// ====================================================================
// VideoRecord
// ====================================================================

/// 视频文件记录（manifest 中的一条记录）
class VideoRecord
    with Hashable, Storable, Renamable<VideoRecord>, Movable<VideoRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name; // 用户设置的文件名（不含扩展名）
  @override
  final String hash; // 视频数据的 MD5 哈希值
  @override
  final String format; // 文件格式（mp4, mov 等）
  @override
  final DateTime createdAt;
  @override
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）
  final int duration; // 视频时长（毫秒）

  VideoRecord({
    String? id,
    required this.name,
    required this.hash,
    required this.format,
    required this.createdAt,
    required this.size,
    this.folder = '',
    this.duration = 0,
  }) : id = id ?? 'vid_${const Uuid().v4()}';

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
        'size': size,
        'folder': folder,
        'duration': duration,
      };

  factory VideoRecord.fromMap(Map<String, dynamic> map) => VideoRecord(
        id: map['id'] as String?,
        name: map['name'] as String? ?? '',
        hash: map['hash'] as String? ?? '',
        format: map['format'] as String? ?? 'mp4',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        size: (map['size'] as num?)?.toInt() ?? 0,
        folder: map['folder'] as String? ?? '',
        duration: (map['duration'] as num?)?.toInt() ?? 0,
      );

  @override
  VideoRecord copyWithName(String name) => VideoRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
        duration: duration,
      );

  @override
  VideoRecord copyWithFolder(String folder) => VideoRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
        duration: duration,
      );

  VideoRecord copyWith({
    String? name,
    String? folder,
    int? size,
    int? duration,
  }) =>
      VideoRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size ?? this.size,
        folder: folder ?? this.folder,
        duration: duration ?? this.duration,
      );
}

/// 计算视频数据的 MD5 哈希值
String computeVideoHash(Uint8List data) {
  final digest = md5.convert(data);
  return digest.toString();
}

// ====================================================================
// VideoManifest — thin wrapper around ManifestOperations
// ====================================================================

/// Video file manifest — delegates to [ManifestOperations].
class VideoManifest {
  static final _ops = ManifestOperations<VideoRecord>(
    manifestKey: 'video_manifest',
    storageDirName: 'videos',
    useAppSupportDir: false,
    fromMap: VideoRecord.fromMap,
    tableName: 'video_records',
    toMap: (r) => r.toMap(),
    thumbnailExtension: '.jpg',
  );

  static Future<List<VideoRecord>> loadRecords() => _ops.loadRecords();
  static Future<void> addRecord(VideoRecord record) => _ops.addRecord(record);
  static Future<void> deleteRecord(String id) => _ops.deleteRecord(id);
  static Future<void> deleteRecords(List<String> ids) =>
      _ops.deleteRecords(ids);
  static Future<void> updateRecord(VideoRecord updated) =>
      _ops.updateRecord(updated);
  static Future<void> renameRecord(String id, String newName) =>
      _ops.renameRecord(id, newName);
  static Future<void> moveRecord(String id, String targetFolder) =>
      _ops.moveRecord(id, targetFolder);

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);

  /// Derived from the configured [thumbnailExtension] in [_ops].
  static String get _thumbExtension => _ops.thumbnailExtension;

  static Future<bool> hasThumbnail(String hash) async {
    final thumbPath = '${hash}_thumb$_thumbExtension';
    return (await readFile(thumbPath)) != null;
  }

  static Future<Uint8List?> readThumbnail(String hash) async {
    final thumbPath = '${hash}_thumb$_thumbExtension';
    return readFile(thumbPath);
  }

  static Future<void> writeThumbnail(String hash, Uint8List bytes) async {
    final thumbPath = '${hash}_thumb$_thumbExtension';
    await writeFile(thumbPath, bytes);
  }

  // Folder management
  static Future<Set<String>> getAllFolders() => _ops.getAllFolders();
  static Future<void> addFolder(String name) => _ops.addFolder(name);
  static Future<void> removeFolder(String name) => _ops.removeFolder(name);
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

  /// Storage directory path for videos.
  static Future<String> get videoDir => _ops.storageDirPath;

  /// Find a record by its hash.
  static Future<VideoRecord?> getRecordByHash(String hash) async {
    final records = await loadRecords();
    for (final r in records) {
      if (r.hash == hash) return r;
    }
    return null;
  }
}
