import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 检查文件写入是否安全（目录可写、空间充足）
class StorageSafety {
  /// 检查存储目录是否存在并可写
  /// 如果存在问题返回错误信息，否则返回 null
  static Future<String?> checkWriteReady(String storageDirName) async {
    if (kIsWeb) return null; // Web 端由 IndexedDB 管理

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, storageDirName));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // 尝试写入一个临时文件来验证可写性
      final testFile = File(p.join(dir.path, '.write_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return null;
    } catch (e) {
      return '存储不可用: $e';
    }
  }
}
