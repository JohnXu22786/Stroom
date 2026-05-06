import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 跨平台文件存储服务
/// - Web: 使用 SharedPreferences 持久化的内存 Map
/// - Native: 使用 dart:io + path_provider
class StorageService {
  // =========================================================================
  // Web: In-memory store backed by SharedPreferences
  // =========================================================================
  static Map<String, Uint8List>? _webStore;

  static Future<Map<String, Uint8List>> _ensureWebStore() async {
    if (_webStore != null) return _webStore!;
    _webStore = {};
    // Try to restore from SharedPreferences (metadata only)
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList('web_audio_keys');
      if (keys != null) {
        for (final key in keys) {
          final base64 = prefs.getString('web_audio_$key');
          if (base64 != null) {
            _webStore![key] = base64Decode(base64);
          }
        }
      }
    } catch (_) {}
    return _webStore!;
  }

  static Future<void> _persistWebStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = _webStore?.keys.toList() ?? [];
      await prefs.setStringList('web_audio_keys', keys);
      for (final key in keys) {
        final data = _webStore![key];
        if (data != null) {
          await prefs.setString('web_audio_$key', base64Encode(data));
        }
      }
    } catch (_) {}
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
      try {
        final store = await _ensureWebStore();
        return store.entries.map<StorageFileInfo>((e) {
          return StorageFileInfo(
            name: e.key,
            path: e.key,
            data: e.value,
            size: e.value.lengthInBytes,
            modifiedAt: DateTime.now(),
          );
        }).toList();
      } catch (_) {
        return [];
      }
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
      final store = await _ensureWebStore();
      store[fileName] = data;
      await _persistWebStore();
      return fileName;
    }

    final ttsDir = await _nativeTtsDir;
    final filePath = path.join(ttsDir, fileName);
    await File(filePath).writeAsBytes(data);
    return filePath;
  }

  static Future<Uint8List?> readFile(String filePath) async {
    if (kIsWeb) {
      try {
        final store = await _ensureWebStore();
        return store[filePath];
      } catch (_) {
        return null;
      }
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
      try {
        final store = await _ensureWebStore();
        store.remove(filePath);
        await _persistWebStore();
        return true;
      } catch (_) {
        return false;
      }
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

  static Future<String?> copyFile(String sourcePath, String destFileName) async {
    if (kIsWeb) {
      try {
        final store = await _ensureWebStore();
        final data = store[sourcePath];
        if (data == null) return null;
        store[destFileName] = Uint8List.fromList(data);
        await _persistWebStore();
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
      try {
        final store = await _ensureWebStore();
        return store.containsKey(filePath);
      } catch (_) {
        return false;
      }
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
      try {
        final store = await _ensureWebStore();
        final data = store[filePath];
        return data?.lengthInBytes ?? 0;
      } catch (_) {
        return 0;
      }
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
    try {
      final store = await _ensureWebStore();
      store.clear();
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList('web_audio_keys');
      if (keys != null) {
        for (final key in keys) {
          await prefs.remove('web_audio_$key');
        }
      }
      await prefs.remove('web_audio_keys');
    } catch (_) {}
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
