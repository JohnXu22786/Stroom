import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'web_file_store.dart';

/// 跨平台文件存储服务
/// - Web: 使用 WebFileStore（IndexedDB）持久化的内存 Map
/// - Native: 使用 dart:io + path_provider
class StorageService {
  // =========================================================================
  // Web: In-memory store backed by IndexedDB
  // =========================================================================
  static Map<String, Uint8List>? _webStore;

  static Future<Map<String, Uint8List>> _ensureWebStore() async {
    if (_webStore != null) return _webStore!;
    _webStore = {};
    // 从 WebFileStore (IndexedDB) 加载数据
    try {
      // WebFileStore 使用 'storage_service' 前缀存储所有文件
      // 我们无法高效地列出所有 key，所以这里只初始化空 map
      // 实际文件在 writeFile 时存储，在 readFile 时按需读取
    } catch (_) {}
    return _webStore!;
  }

  // =========================================================================
  // Native
  // =========================================================================
  static String? _nativeBasePath;

  static Future<String> get _nativeTtsDir async {
    if (_nativeBasePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _nativeBasePath = dir.path;
    }
    final ttsDir = path.join(_nativeBasePath!, 'tts_audio');
    final d = Directory(ttsDir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return ttsDir;
  }

  // =========================================================================
  // 公共 API
  // =========================================================================

  static Future<bool> ttsDirExists() async {
    if (kIsWeb) {
      try {
        final store = await _ensureWebStore();
        return store.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    final dir = Directory(await _nativeTtsDir);
    return await dir.exists();
  }

  static Future<List<StorageFileInfo>> listFiles() async {
    if (kIsWeb) {
      // WebFileStore 不支持列出所有 key，返回空列表
      // 文件列表由 Manifest 管理，此处不影响功能
      return [];
    }

    final ttsDir = await _nativeTtsDir;
    final dir = Directory(ttsDir);
    if (!await dir.exists()) return [];

    final files = <StorageFileInfo>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        files.add(StorageFileInfo(
          name: path.basename(entity.path),
          path: entity.path,
          size: await entity.length(),
          modifiedAt: stat.modified,
        ));
      }
    }
    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  static Future<String> writeFile(String fileName, Uint8List data) async {
    if (kIsWeb) {
      await WebFileStore.write('storage_service/$fileName', data);
      return fileName;
    }

    final ttsDir = await _nativeTtsDir;
    final filePath = path.join(ttsDir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  static Future<Uint8List?> readFile(String filePath) async {
    if (kIsWeb) {
      return WebFileStore.read('storage_service/$filePath');
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteFile(String filePath) async {
    if (kIsWeb) {
      await WebFileStore.delete('storage_service/$filePath');
      return true;
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> copyFile(
      String sourcePath, String destFileName) async {
    if (kIsWeb) {
      try {
        final data = await WebFileStore.read('storage_service/$sourcePath');
        if (data == null) return null;
        await WebFileStore.write('storage_service/$destFileName', data);
        return destFileName;
      } catch (_) {
        return null;
      }
    }

    try {
      final source = File(sourcePath);
      if (!await source.exists()) return null;
      final ttsDir = await _nativeTtsDir;
      final destPath = path.join(ttsDir, destFileName);
      await source.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> fileExists(String filePath) async {
    if (kIsWeb) {
      return WebFileStore.exists('storage_service/$filePath');
    }

    try {
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> createDir(String dirPath) async {
    if (kIsWeb) return;
    await Directory(dirPath).create(recursive: true);
  }

  static Future<int> fileSize(String filePath) async {
    if (kIsWeb) {
      final data = await WebFileStore.read('storage_service/$filePath');
      return data?.lengthInBytes ?? 0;
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static bool get isWeb => kIsWeb;

  static Future<void> clearWebStorage() async {
    if (!kIsWeb) return;
    // WebFileStore 没有列出所有 key 的 API，简单置空内存状态
    _webStore?.clear();
  }
}

class StorageFileInfo {
  final String name;
  final String path;
  final Uint8List? data;
  final int size;
  final DateTime modifiedAt;

  StorageFileInfo({
    required this.name,
    required this.path,
    this.data,
    required this.size,
    DateTime? modifiedAt,
  }) : modifiedAt = modifiedAt ?? DateTime.now();

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }
}
