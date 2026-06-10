import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'file_record.dart';
import 'manifest_operations.dart';
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
  final String format; // 文件格式（txt）
  @override
  final DateTime createdAt;
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
    required this.size,
    this.folder = '',
    this.textLength = 0,
  }) : id = id ?? 'txt_${const Uuid().v4()}';

  /// 实体文件存储名
  String get storageFileName => '$hash.txt';
  @override
  String get storagePath => '$hash.txt';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hash': hash,
        'format': format,
        'createdAt': createdAt.toIso8601String(),
        'size': size,
        'folder': folder,
        'textLength': textLength,
      };

  factory TextRecord.fromMap(Map<String, dynamic> map) => TextRecord(
        id: map['id'] as String?,
        name: map['name'] as String? ?? '',
        hash: map['hash'] as String? ?? '',
        format: map['format'] as String? ?? 'txt',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        size: (map['size'] as num?)?.toInt() ?? 0,
        folder: map['folder'] as String? ?? '',
        textLength: (map['textLength'] as num?)?.toInt() ?? 0,
      );

  @override
  TextRecord copyWithName(String name) => TextRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
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
        size: size,
        folder: folder,
        textLength: textLength,
      );

  TextRecord copyWith({
    String? name,
    String? folder,
    int? size,
    int? textLength,
  }) =>
      TextRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
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
  static final _ops = ManifestOperations<TextRecord>(
    manifestKey: 'text_manifest',
    storageDirName: 'texts',
    useAppSupportDir: false,
    fromMap: TextRecord.fromMap,
    tableName: 'text_records',
    toMap: (r) => r.toMap(),
  );

  static Future<List<TextRecord>> loadRecords() => _ops.loadRecords();
  static Future<void> addRecord(TextRecord record) => _ops.addRecord(record);
  static Future<void> deleteRecord(String id) => _ops.deleteRecord(id);
  static Future<void> deleteRecords(List<String> ids) =>
      _ops.deleteRecords(ids);
  static Future<void> updateRecord(TextRecord updated) =>
      _ops.updateRecord(updated);
  static Future<void> renameRecord(String id, String newName) =>
      _ops.renameRecord(id, newName);
  static Future<void> moveRecord(String id, String targetFolder) =>
      _ops.moveRecord(id, targetFolder);

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<bool> fileExists(String fileName) => _ops.fileExists(fileName);
  static Future<bool> deleteFile(String fileName) => _ops.deleteFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);

  /// 写入文本内容到文件
  static Future<String> writeText(String fileName, String text) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    return writeFile(fileName, bytes);
  }

  /// 读取文本内容从文件
  static Future<String?> readText(String fileName) async {
    final bytes = await readFile(fileName);
    if (bytes == null || bytes.isEmpty) return null;
    return utf8.decode(bytes);
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
}
