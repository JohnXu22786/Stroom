import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 跨平台文件存储服务
/// - Native (Android/iOS/Windows/macOS/Linux): 使用 dart:io 的 File/Directory
/// - Web: 使用内存 Map 模拟文件系统
class StorageService {
  // 内存存储（Web 使用）
  static final Map<String, Uint8List> _memoryStorage = {};
  static const String _memoryPrefix = 'memory://';

  /// TTS 音频目录路径
  static String get _ttsDirKey => '$_memoryPrefix/tts_audio';

  /// 生成内存中的存储 key
  static String _memoryKey(String fileName) =>
      '$_ttsDirKey/$fileName';

  /// 从 path 中提取文件名
  static String _fileNameFromPath(String filePath) {
    if (filePath.startsWith(_memoryPrefix)) {
      return filePath.split('/').last;
    }
    // 兼容 native 路径
    return filePath.split(RegExp(r'[/\\]')).last;
  }

  /// TTS 音频目录是否存在
  static Future<bool> ttsDirExists() async {
    if (kIsWeb) {
      return _memoryStorage.keys.any((k) => k.startsWith(_ttsDirKey));
    }
    // 在 native 上通过调用方处理，避免引入 dart:io
    return false;
  }

  /// 列出 TTS 音频目录下所有文件
  static Future<List<StorageFileInfo>> listFiles() async {
    if (kIsWeb) {
      final entries = _memoryStorage.entries
          .where((e) => e.key.startsWith(_ttsDirKey))
          .toList();
      return entries.map((e) {
        final name = e.key.split('/').last;
        return StorageFileInfo(
          name: name,
          path: e.key,
          data: e.value,
          size: e.value.lengthInBytes,
          modifiedAt: DateTime.now(),
        );
      }).toList();
    }
    return [];
  }

  /// 写入文件
  static Future<String> writeFile(String fileName, Uint8List data) async {
    if (kIsWeb) {
      final key = _memoryKey(fileName);
      _memoryStorage[key] = data;
      return key;
    }
    // native 上返回空，由调用方使用 path_provider + dart:io
    return '';
  }

  /// 读取文件
  static Future<Uint8List?> readFile(String filePath) async {
    if (kIsWeb) {
      return _memoryStorage[filePath];
    }
    return null;
  }

  /// 删除文件
  static Future<bool> deleteFile(String filePath) async {
    if (kIsWeb) {
      return _memoryStorage.remove(filePath) != null;
    }
    return false;
  }

  /// 复制文件
  static Future<String?> copyFile(String sourcePath, String destFileName) async {
    final data = await readFile(sourcePath);
    if (data == null) return null;

    if (kIsWeb) {
      final destKey = _memoryKey(destFileName);
      _memoryStorage[destKey] = Uint8List.fromList(data);
      return destKey;
    }
    return null;
  }

  /// 文件是否存在
  static Future<bool> fileExists(String filePath) async {
    if (kIsWeb) {
      return _memoryStorage.containsKey(filePath);
    }
    return false;
  }

  /// 创建目录
  static Future<void> createDir(String dirPath) async {
    if (kIsWeb) {
      // 内存存储不需要显式创建目录，写入时自动存在
      return;
    }
  }

  /// 获取文件大小
  static Future<int> fileSize(String filePath) async {
    if (kIsWeb) {
      final data = _memoryStorage[filePath];
      return data?.lengthInBytes ?? 0;
    }
    return 0;
  }

  /// 判断是否 Web 平台（静态访问器）
  static bool get isWeb => kIsWeb;
}

/// 文件信息
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
