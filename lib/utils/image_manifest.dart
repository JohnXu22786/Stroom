import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'web_file_store.dart';
import 'file_record.dart';

/// 图片文件记录（manifest 中的一条记录）
class ImageRecord implements FileRecord {
  @override
  final String id;
  @override
  final String name;          // 用户设置的文件名（不含扩展名）
  final String hash;          // 图片数据的 MD5 哈希值
  @override
  final String format;        // 文件格式（jpg, png 等）
  @override
  final DateTime createdAt;
  @override
  final int size;             // 文件大小（字节）
  @override
  final String folder;        // 文件夹路径（空字符串表示根目录）

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

  ImageRecord copyWith({
    String? name,
    String? folder,
    int? size,
  }) => ImageRecord(
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

/// 图片文件清单管理服务
/// 元数据：SharedPreferences（key: image_manifest）
/// 实体文件：pictures/<hash>.<format>
class ImageManifest {
  static List<ImageRecord>? _cache;
  static bool _dirty = false;
  static List<String> _folderCache = [];

  static const String _manifestKey = 'image_manifest';

  // ====================================================================
  // 加载 / 持久化
  // ====================================================================

  static Future<List<ImageRecord>> loadRecords() async {
    if (_cache != null && !_dirty) return _cache!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_manifestKey);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json);
        if (data is List) {
          _cache = data.cast<Map<String, dynamic>>()
              .map((m) => ImageRecord.fromMap(m))
              .toList();
          _folderCache = [];
        } else if (data is Map) {
          final list = (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _cache = list.map((m) => ImageRecord.fromMap(m)).toList();
          _folderCache = (data['folders'] as List?)?.cast<String>() ?? [];
        }
      } else {
        _cache = [];
      }
    } catch (e) {
      debugPrint('ImageManifest.loadRecords error: $e');
      _cache = [];
    }
    _dirty = false;
    return _cache!;
  }

  static Future<void> _persist() async {
    if (_cache == null) {
      await loadRecords();
    }
    try {
      final data = {
        'records': (_cache ?? []).map((r) => r.toMap()).toList(),
        'folders': _folderCache,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manifestKey, jsonEncode(data));
    } catch (e) {
      debugPrint('ImageManifest._persist error: $e');
    }
  }

  // ====================================================================
  // CRUD
  // ====================================================================

  static Future<void> addRecord(ImageRecord record) async {
    await loadRecords();
    _cache!.add(record);
    await _persist();
  }

  static Future<void> _deleteEntityFiles(ImageRecord record) async {
    final refCount = _cache!.where((r) => r.hash == record.hash).length;
    if (refCount <= 1) {
      if (kIsWeb) {
        await WebFileStore.delete(record.storagePath);
      } else {
        final appDir = await getApplicationSupportDirectory();
        final picDir = p.join(appDir.path, 'pictures');
        final file = File(p.join(picDir, record.storagePath));
        if (await file.exists()) await file.delete();
      }
    }
  }

  static Future<void> deleteRecord(String id) async {
    await loadRecords();
    final idx = _cache!.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    await _deleteEntityFiles(_cache![idx]);
    _cache!.removeAt(idx);
    await _persist();
  }

  static Future<void> deleteRecords(List<String> ids) async {
    await loadRecords();
    for (final id in ids) {
      final idx = _cache!.indexWhere((r) => r.id == id);
      if (idx == -1) continue;
      await _deleteEntityFiles(_cache![idx]);
      _cache!.removeAt(idx);
    }
    await _persist();
  }

  static Future<void> updateRecord(ImageRecord updated) async {
    await loadRecords();
    final idx = _cache!.indexWhere((r) => r.id == updated.id);
    if (idx != -1) {
      _cache![idx] = updated;
      await _persist();
    }
  }

  static Future<void> renameRecord(String id, String newName) async {
    await loadRecords();
    final idx = _cache!.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _cache![idx] = _cache![idx].copyWith(name: newName);
      await _persist();
    }
  }

  static Future<void> moveRecord(String id, String targetFolder) async {
    await loadRecords();
    final idx = _cache!.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _cache![idx] = _cache![idx].copyWith(folder: targetFolder);
      await _persist();
    }
  }

  // ====================================================================
  // 文件 I/O
  // ====================================================================

  static Future<String> writeFile(String fileName, Uint8List data) async {
    if (kIsWeb) {
      await WebFileStore.write(fileName, data);
      return fileName;
    }
    final appDir = await getApplicationSupportDirectory();
    final picDir = p.join(appDir.path, 'pictures');
    final dir = Directory(picDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final filePath = p.join(picDir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  static Future<Uint8List?> readFile(String fileName) async {
    if (kIsWeb) {
      return WebFileStore.read(fileName);
    }
    final appDir = await getApplicationSupportDirectory();
    final picDir = p.join(appDir.path, 'pictures');
    final file = File(p.join(picDir, fileName));
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  static Future<String?> readFilePath(String fileName) async {
    if (kIsWeb) {
      final exists = await WebFileStore.exists(fileName);
      return exists ? fileName : null;
    }
    final appDir = await getApplicationSupportDirectory();
    final picDir = p.join(appDir.path, 'pictures');
    final filePath = p.join(picDir, fileName);
    if (await File(filePath).exists()) return filePath;
    return null;
  }

  // ====================================================================
  // 文件夹管理
  // ====================================================================

  static Future<Set<String>> getAllFolders() async {
    await loadRecords();
    final folders = <String>{};
    folders.addAll(_folderCache);
    for (final r in _cache ?? []) {
      if (r.folder.isNotEmpty) folders.add(r.folder);
    }
    return folders;
  }

  static Future<void> addFolder(String folderName) async {
    await loadRecords();
    final name = folderName.trim();
    if (name.isEmpty || name.contains('/')) return;
    if (!_folderCache.contains(name)) {
      _folderCache.add(name);
      await _persist();
    }
  }

  static Future<void> removeFolder(String folderName) async {
    await loadRecords();

    // 递归删除所有后代文件夹
    await _removeFolderRecursive(folderName);

    // 删除当前文件夹下的记录
    final toRemove = _cache!.where((r) => r.folder == folderName).toList();
    for (final r in toRemove) {
      await _deleteEntityFiles(r);
      _cache!.remove(r);
    }
    _folderCache.remove(folderName);
    await _persist();
  }

  /// 递归删除 folderPath 的所有子文件夹及其记录
  static Future<void> _removeFolderRecursive(String folderPath) async {
    final prefix = folderPath.isEmpty ? '' : '$folderPath/';
    // 找出所有直接子文件夹路径
    final children = _folderCache.where((f) {
      if (f == folderPath || !f.startsWith(prefix)) return false;
      final suffix = f.substring(prefix.length);
      return !suffix.contains('/'); // 直接子级
    }).toList();

    for (final child in children) {
      await removeFolder(child); // 递归
    }

    // 也从记录中找出遗漏的子文件夹路径
    final recordFolders = _cache!
        .map((r) => r.folder)
        .where((f) => f.isNotEmpty && f.startsWith(prefix))
        .toSet();
    for (final childFolder in recordFolders) {
      if (!_folderCache.contains(childFolder)) {
        final toRemove = _cache!.where((r) => r.folder == childFolder).toList();
        for (final r in toRemove) {
          await _deleteEntityFiles(r);
          _cache!.remove(r);
        }
      }
    }
  }

  static String? validateFolderName(String name) {
    final t = name.trim();
    if (t.isEmpty) return '文件夹名不能为空';
    if (t.length > 100) return '文件夹名不能超过100个字符';
    if (t.contains('/')) return '文件夹名不能包含斜杠 /';
    return null;
  }

  // ====================================================================
  // 路径工具
  // ====================================================================

  static String getFolderBaseName(String folderPath) {
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? folderPath : folderPath.substring(idx + 1);
  }

  static String getParentFolderPath(String folderPath) {
    if (folderPath.isEmpty) return '';
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? '' : folderPath.substring(0, idx);
  }

  static List<String> getChildFolderPaths(String parentPath, [List<String>? allPaths]) {
    final paths = allPaths ?? _folderCache;
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    final result = <String>[];
    for (final p in paths) {
      if (p == parentPath) continue;
      if (parentPath.isEmpty) {
        if (!p.contains('/')) result.add(p);
      } else {
        if (p.startsWith(prefix)) {
          final suffix = p.substring(prefix.length);
          if (!suffix.contains('/')) result.add(p);
        }
      }
    }
    return result;
  }

  static void invalidateCache() {
    _dirty = true;
    _cache = null;
  }
}
