import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'file_record.dart';
import '../services/manifest_operations.dart';
import 'folder_path_utils.dart';

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
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）

  ImageRecord({
    String? id,
    required this.name,
    required this.hash,
    required this.format,
    required this.createdAt,
    required this.size,
    this.folder = '',
  }) : id = id ?? 'img_${const Uuid().v4()}';

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
      };

  factory ImageRecord.fromMap(Map<String, dynamic> map) => ImageRecord(
        id: map['id'] as String?,
        name: map['name'] as String? ?? '',
        hash: map['hash'] as String? ?? '',
        format: map['format'] as String? ?? 'jpg',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        size: (map['size'] as num?)?.toInt() ?? 0,
        folder: map['folder'] as String? ?? '',
      );

  @override
  ImageRecord copyWithName(String name) => ImageRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
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
        size: size,
        folder: folder,
      );

  ImageRecord copyWith({
    String? name,
    String? folder,
    int? size,
  }) =>
      ImageRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
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
  static final _ops = ManifestOperations<ImageRecord>(
    manifestKey: 'image_manifest',
    storageDirName: 'pictures',
    useAppSupportDir: false,
    fromMap: ImageRecord.fromMap,
    tableName: 'image_records',
    toMap: (r) => r.toMap(),
  );

  static Future<List<ImageRecord>> loadRecords() => _ops.loadRecords();
  static Future<void> addRecord(ImageRecord record) => _ops.addRecord(record);
  static Future<void> deleteRecord(String id) => _ops.deleteRecord(id);
  static Future<void> deleteRecords(List<String> ids) =>
      _ops.deleteRecords(ids);
  static Future<void> updateRecord(ImageRecord updated) =>
      _ops.updateRecord(updated);
  static Future<void> renameRecord(String id, String newName) =>
      _ops.renameRecord(id, newName);
  static Future<void> moveRecord(String id, String targetFolder) =>
      _ops.moveRecord(id, targetFolder);

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<bool> deleteFile(String fileName) =>
      _ops.deleteFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);

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
}
