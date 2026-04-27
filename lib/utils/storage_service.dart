import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart' as idb_browser;

/// 跨平台文件存储服务
/// - Web: 使用 IndexedDB
/// - Native: 使用 dart:io + path_provider
class StorageService {
  // =========================================================================
  // Web: IndexedDB
  // =========================================================================
  static idb.Database? _webDb;

  static Future<idb.Database> _getWebDb() async {
    if (_webDb != null) return _webDb!;
    _webDb = await idb_browser.idbFactory.openDatabase(
      'stroom_audio',
      version: 1,
      onUpgradeNeeded: (event) {
        event.database.createObjectStore('audio_files', keyPath: 'name');
      },
    );
    return _webDb!;
  }

  static const String _storeName = 'audio_files';

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
        final db = await _getWebDb();
        final count = await db.getObjectStore(_storeName).count();
        return count > 0;
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
        final db = await _getWebDb();
        final all = await db.getObjectStore(_storeName).getAll();
        return all.map<StorageFileInfo>((record) {
          final r = record as Map;
          final name = r['name'] as String;
          final data = r['data'] as Uint8List;
          return StorageFileInfo(
            name: name,
            path: name,
            data: data,
            size: data.lengthInBytes,
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
      final db = await _getWebDb();
      final tx = db.transactionStore(_storeName, 'readwrite');
      await tx.put({'name': fileName, 'data': data}, fileName);
      await tx.completed;
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
        final db = await _getWebDb();
        final record = await db.getObjectStore(_storeName).getObject(filePath);
        if (record == null) return null;
        return (record as Map)['data'] as Uint8List?;
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
        final db = await _getWebDb();
        final tx = db.transactionStore(_storeName, 'readwrite');
        await tx.delete(filePath);
        await tx.completed;
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
        final db = await _getWebDb();
        final store = db.getObjectStore(_storeName);
        final record = await store.getObject(sourcePath);
        if (record == null) return null;
        final r = record as Map;
        final data = r['data'] as Uint8List;
        final tx = db.transactionStore(_storeName, 'readwrite');
        await tx.put({'name': destFileName, 'data': Uint8List.fromList(data)}, destFileName);
        await tx.completed;
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
        final db = await _getWebDb();
        final record = await db.getObjectStore(_storeName).getObject(filePath);
        return record != null;
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
        final db = await _getWebDb();
        final record = await db.getObjectStore(_storeName).getObject(filePath);
        if (record == null) return 0;
        final data = (record as Map)['data'] as Uint8List?;
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
      final db = await _getWebDb();
      final tx = db.transactionStore(_storeName, 'readwrite');
      await tx.clear();
      await tx.completed;
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
