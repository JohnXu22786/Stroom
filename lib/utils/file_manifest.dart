import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'web_file_store.dart';
import 'file_record.dart';

/// 音频文件记录（manifest 中的一条记录）
class AudioRecord implements FileRecord {
  @override
  final String id;
  @override
  final String name; // 用户设置的文件名
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

/// 文件清单管理服务
/// 元数据统一存储在 SharedPreferences 中（全平台一致，同供应商配置），
/// 实际文件以 <hash>.<format> 命名存储在 tts_audio 目录中。
class FileManifest {
  static List<AudioRecord>? _cache;
  static bool _dirty = false;
  static List<String> _folderCache = [];

  /// SharedPreferences 存储键名
  static const String _manifestKey = 'audio_manifest';

  /// 加载所有记录（全平台统一用 SharedPreferences）
  static Future<List<AudioRecord>> loadRecords() async {
    if (_cache != null && !_dirty) return _cache!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_manifestKey);
      if (json != null && json.isNotEmpty) {
        final decoded = jsonDecode(json);
        if (decoded is List) {
          // 旧格式：纯数组
          final list = decoded.cast<Map<String, dynamic>>();
          _cache = list.map((m) => AudioRecord.fromMap(m)).toList();
        } else {
          // 新格式：{ records: [...], folders: [...] }
          final map = decoded as Map<String, dynamic>;
          final list =
              (map['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _cache = list.map((m) => AudioRecord.fromMap(m)).toList();
          _folderCache = (map['folders'] as List?)?.cast<String>() ?? [];
        }
      } else {
        _cache = [];
      }
    } catch (e) {
      debugPrint('Failed to load manifest: $e');
      _cache = [];
    }
    _dirty = false;
    return _cache!;
  }

  /// 持久化 manifest（全平台统一用 SharedPreferences）
  static Future<void> _persist() async {
    if (_cache == null) {
      debugPrint('WARNING: _persist called with null cache, reloading first');
      await loadRecords();
    }
    try {
      final data = {
        'records': (_cache ?? []).map((r) => r.toMap()).toList(),
        'folders': _folderCache,
      };
      final json = jsonEncode(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manifestKey, json);
    } catch (e) {
      debugPrint('Failed to persist manifest: $e');
    }
  }

  /// 添加记录
  static Future<void> addRecord(AudioRecord record) async {
    await loadRecords();
    _cache!.add(record);
    await _persist();
  }

  /// 删除单条记录的实体文件（引用计数≤1 时才删）
  static Future<void> _deleteRecordEntityFiles(AudioRecord record) async {
    final refCount = _cache!.where((r) => r.hash == record.hash).length;
    if (refCount <= 1) {
      if (kIsWeb) {
        await WebFileStore.delete(record.storagePath);
        await WebFileStore.delete(record.textStoragePath);
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final ttsDir = path.join(appDocDir.path, 'tts_audio');
        final audioFile = File(path.join(ttsDir, record.storagePath));
        if (await audioFile.exists()) await audioFile.delete();
        final textFile = File(path.join(ttsDir, record.textStoragePath));
        if (await textFile.exists()) await textFile.delete();
      }
    }
  }

  /// 删除记录（仅在无其他记录引用同一哈希时才删除实体文件）
  static Future<void> deleteRecord(String id) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final record = _cache![index];
    await _deleteRecordEntityFiles(record);

    _cache!.removeAt(index);
    await _persist();
  }

  /// 批量删除记录（优化：一次性处理所有记录，只 persist 一次）
  static Future<void> deleteRecords(List<String> ids) async {
    await loadRecords();
    for (final id in ids) {
      final index = _cache!.indexWhere((r) => r.id == id);
      if (index == -1) continue;
      final record = _cache![index];
      await _deleteRecordEntityFiles(record);
      _cache!.removeAt(index);
    }
    await _persist();
  }

  /// 更新记录
  static Future<void> updateRecord(AudioRecord updated) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _cache![index] = updated;
      await _persist();
    }
  }

  /// 重命名
  static Future<void> renameRecord(String id, String newName) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cache![index] = _cache![index].copyWith(name: newName);
      await _persist();
    }
  }

  /// 移动文件到文件夹
  static Future<void> moveRecord(String id, String targetFolder) async {
    await loadRecords();
    final index = _cache!.indexWhere((r) => r.id == id);
    if (index != -1) {
      _cache![index] = _cache![index].copyWith(folder: targetFolder);
      await _persist();
    }
  }

  /// 根据 ID 获取记录
  static Future<AudioRecord?> getRecord(String id) async {
    await loadRecords();
    try {
      return _cache!.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据哈希值查找记录
  static Future<AudioRecord?> getRecordByHash(String hash) async {
    await loadRecords();
    try {
      return _cache!.firstWhere((r) => r.hash == hash);
    } catch (_) {
      return null;
    }
  }

  /// 写入文件（写入 tts_audio 目录）
  static Future<String> writeFile(String fileName, Uint8List data) async {
    if (kIsWeb) {
      await WebFileStore.write(fileName, data);
      return fileName;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final ttsDir = path.join(appDocDir.path, 'tts_audio');
    final dir = Directory(ttsDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final filePath = path.join(ttsDir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  /// 读取文件
  static Future<Uint8List?> readFile(String fileName) async {
    if (kIsWeb) {
      final result = await WebFileStore.read(fileName);
      if (result == null) {
        debugPrint('FileManifest.readFile: $fileName → null');
      } else if (result.isEmpty) {
        debugPrint('FileManifest.readFile: $fileName → 空数据 (0 字节)');
      }
      return result;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final ttsDir = path.join(appDocDir.path, 'tts_audio');
    final filePath = path.join(ttsDir, fileName);
    final file = File(filePath);
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String fileName) async {
    if (kIsWeb) {
      return await WebFileStore.exists(fileName);
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final ttsDir = path.join(appDocDir.path, 'tts_audio');
    return await File(path.join(ttsDir, fileName)).exists();
  }

  /// 删除文件
  static Future<bool> deleteFile(String fileName) async {
    if (kIsWeb) {
      await WebFileStore.delete(fileName);
      return true;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final ttsDir = path.join(appDocDir.path, 'tts_audio');
    final file = File(path.join(ttsDir, fileName));
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// 获取 tts_audio 目录路径（仅 Native）
  static Future<String> get ttsAudioDir async {
    if (kIsWeb) return '';
    final appDocDir = await getApplicationDocumentsDirectory();
    return path.join(appDocDir.path, 'tts_audio');
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  /// 加载所有文件夹
  static Future<List<String>> loadFolders() async {
    await loadRecords(); // 确保 manifest 已加载
    return List.unmodifiable(_folderCache);
  }

  /// 添加文件夹（支持层级路径如 "parent/sub"）
  static Future<void> addFolder(String folderName) async {
    await loadRecords();
    final name = folderName.trim();
    if (name.isEmpty) return;
    // 只校验末级名称，不校验完整层级路径（允许斜杠表示嵌套）
    final baseName = getFolderBaseName(name);
    final validationError = validateFolderName(baseName);
    if (validationError != null) return;
    if (!_folderCache.contains(name)) {
      _folderCache.add(name);
      await _persist();
    }
  }

  /// Add a folder path to cache without name validation (for internal use with computed paths)
  static Future<void> addFolderPath(String folderPath) async {
    await loadRecords();
    if (!_folderCache.contains(folderPath)) {
      _folderCache.add(folderPath);
      await _persist();
    }
  }

  /// 删除文件夹（同时删除内部所有记录，实体文件仅在无其他引用时删除）
  /// 会递归删除所有子文件夹。
  static Future<void> removeFolder(String folderName) async {
    await loadRecords();

    // 递归删除所有子文件夹
    final childPaths = getAllDescendantFolderPaths(folderName);
    for (final child in childPaths) {
      _folderCache.remove(child);
      final childRecords = _cache!.where((r) => r.folder == child).toList();
      for (final record in childRecords) {
        await _deleteRecordEntityFiles(record);
        _cache!.remove(record);
      }
    }

    _folderCache.remove(folderName);

    // 删除文件夹下的所有文件记录
    final toRemove = _cache!.where((r) => r.folder == folderName).toList();
    for (final record in toRemove) {
      await _deleteRecordEntityFiles(record);
      _cache!.remove(record);
    }

    await _persist();
  }

  /// 获取所有有效文件夹（存储的空文件夹 + 记录中存在的文件夹）
  static Future<Set<String>> getAllFolders() async {
    await loadRecords();
    final folders = <String>{};
    folders.addAll(_folderCache);
    for (final r in _cache ?? []) {
      if (r.folder.isNotEmpty) folders.add(r.folder);
    }
    return folders;
  }

  /// 校验文件夹名是否合法
  static String? validateFolderName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '文件夹名不能为空';
    if (trimmed.length > 100) return '文件夹名不能超过100个字符';
    if (trimmed.contains('/')) return '文件夹名不能包含斜杠 /';
    return null;
  }

  // ====================================================================
  // 层级文件夹路径工具
  // ====================================================================

  /// 获取路径中的末级文件夹名
  static String getFolderBaseName(String folderPath) {
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? folderPath : folderPath.substring(idx + 1);
  }

  /// 获取父级路径（空字符串表示根目录）
  static String getParentFolderPath(String folderPath) {
    if (folderPath.isEmpty) return '';
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? '' : folderPath.substring(0, idx);
  }

  /// 获取指定父路径下的直接子文件夹路径列表
  static List<String> getChildFolderPaths(String parentPath,
      [List<String>? allPaths]) {
    final paths = allPaths ?? _folderCache;
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    final result = <String>[];
    for (final p in paths) {
      if (p == parentPath) continue;
      if (parentPath.isEmpty) {
        // 根目录下的顶级文件夹：不含 /
        if (!p.contains('/')) result.add(p);
      } else {
        if (p.startsWith(prefix)) {
          final suffix = p.substring(prefix.length);
          // 直接子级：不含额外的 /
          if (!suffix.contains('/')) result.add(p);
        }
      }
    }
    return result;
  }

  /// 递归获取某路径下的所有子文件夹路径（含深层）
  static List<String> getAllDescendantFolderPaths(String parentPath) {
    final result = <String>{};
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    // Check _folderCache
    for (final p in _folderCache) {
      if (p == parentPath) continue;
      if (parentPath.isEmpty) {
        if (!p.contains('/')) continue;
        result.add(p);
      } else {
        if (p.startsWith(prefix)) result.add(p);
      }
    }
    // Also scan records for folder paths not in _folderCache
    if (_cache != null) {
      for (final r in _cache!) {
        if (r.folder.isEmpty || r.folder == parentPath) continue;
        if (parentPath.isEmpty) {
          if (r.folder.contains('/')) result.add(r.folder);
        } else {
          if (r.folder.startsWith(prefix)) result.add(r.folder);
        }
      }
    }
    return result.toList();
  }

  /// 从文件夹缓存中移除一个路径及其所有子路径，但不删除记录。
  /// 在 moveFolder 后调用，避免空文件夹残留在缓存中。
  static Future<void> removeFolderFromCache(String folderPath) async {
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
    }
    await _persist();
  }

  /// 清除缓存（用于刷新）
  static void invalidateCache() {
    _dirty = true;
    _cache = null;
  }
}
