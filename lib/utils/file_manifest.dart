import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'web_file_store.dart';
import 'file_record.dart';
import 'manifest_operations.dart';
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
  final int size; // 文件大小（字节）
  @override
  final String folder; // 文件夹路径（空字符串表示根目录）
  final String sourceText; // 源文本

  AudioRecord({
    String? id,
    required this.name,
    required this.hash,
    required this.format,
    required this.createdAt,
    required this.size,
    this.folder = '',
    this.sourceText = '',
  }) : id = id ?? 'rec_${const Uuid().v4()}';

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
        'size': size,
        'folder': folder,
        'sourceText': sourceText,
      };

  factory AudioRecord.fromMap(Map<String, dynamic> map) => AudioRecord(
        id: (map['id'] as String?) ?? 'rec_${const Uuid().v4()}',
        name: map['name'] as String? ?? '',
        hash: map['hash'] as String? ?? '',
        format: map['format'] as String? ?? 'wav',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        size: (map['size'] as num?)?.toInt() ?? 0,
        folder: map['folder'] as String? ?? '',
        sourceText: map['sourceText'] as String? ?? '',
      );

  @override
  AudioRecord copyWithName(String name) => AudioRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
        sourceText: sourceText,
      );

  @override
  AudioRecord copyWithFolder(String folder) => AudioRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
        sourceText: sourceText,
      );

  AudioRecord copyWith({
    String? name,
    String? folder,
    String? sourceText,
    int? size,
  }) =>
      AudioRecord(
        id: id,
        name: name ?? this.name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size ?? this.size,
        folder: folder ?? this.folder,
        sourceText: sourceText ?? this.sourceText,
      );
}

/// 计算音频数据的 MD5 哈希值
String computeAudioHash(Uint8List data) {
  final digest = md5.convert(data);
  return digest.toString();
}

// ====================================================================
// FileManifest — thin wrapper around ManifestOperations
// ====================================================================

/// Audio file manifest — delegates to [ManifestOperations].
class FileManifest {
  static final _ops = ManifestOperations<AudioRecord>(
    manifestKey: 'audio_manifest',
    storageDirName: 'tts_audio',
    fromMap: AudioRecord.fromMap,
    tableName: 'audio_records',
    toMap: (r) => r.toMap(),
    onExtraDelete: (r) async {
      // Also delete the .txt sidecar file (same prefix convention)
      if (kIsWeb) {
        await WebFileStore.delete('tts_audio/${r.textStoragePath}');
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final txtFile =
            File(path.join(appDocDir.path, 'tts_audio', r.textStoragePath));
        if (await txtFile.exists()) await txtFile.delete();
      }
    },
  );

  static Future<List<AudioRecord>> loadRecords() => _ops.loadRecords();
  static Future<void> addRecord(AudioRecord record) => _ops.addRecord(record);
  static Future<void> deleteRecord(String id) => _ops.deleteRecord(id);
  static Future<void> deleteRecords(List<String> ids) =>
      _ops.deleteRecords(ids);
  static Future<void> updateRecord(AudioRecord updated) =>
      _ops.updateRecord(updated);
  static Future<void> renameRecord(String id, String newName) =>
      _ops.renameRecord(id, newName);
  static Future<void> moveRecord(String id, String targetFolder) =>
      _ops.moveRecord(id, targetFolder);
  static Future<AudioRecord?> getRecord(String id) => _ops.getRecord(id);

  static Future<AudioRecord?> getRecordByHash(String hash) async {
    final records = await _ops.loadRecords();
    try {
      return records.firstWhere((r) => r.hash == hash);
    } catch (_) {
      return null;
    }
  }

  static Future<String> writeFile(String fileName, Uint8List data) =>
      _ops.writeFile(fileName, data);
  static Future<Uint8List?> readFile(String fileName) =>
      _ops.readFile(fileName);
  static Future<String?> readFilePath(String fileName) =>
      _ops.readFilePath(fileName);
  static Future<bool> fileExists(String fileName) => _ops.fileExists(fileName);
  static Future<bool> deleteFile(String fileName) => _ops.deleteFile(fileName);
  static Future<String> get ttsAudioDir => _ops.storageDirPath;

  // Folder management
  static Future<List<String>> loadFolders() => _ops.loadFolders();
  static Future<void> addFolder(String name) => _ops.addFolder(name);
  static Future<void> addFolderPath(String pathName) =>
      _ops.addFolderPath(pathName);
  static Future<void> removeFolder(String name) => _ops.removeFolder(name);
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
}
