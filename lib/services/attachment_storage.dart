import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';

class AttachmentStorage {
  static const _storageDirName = 'attachments';

  static String _extractExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return 'bin';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String computeHash(Uint8List data) {
    final digest = md5.convert(data);
    return digest.toString();
  }

  static String _webKey(String storagePath) => storagePath;

  static Future<String> get _storageDir async {
    if (kIsWeb) return '';
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = p.join(appDir.path, _storageDirName);
      final d = Directory(dir);
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
      return dir;
    } catch (e) {
      await AppLogService.error('AttachmentStorage', '获取存储目录失败', e);
      rethrow;
    }
  }

  static Future<String> saveFile(String fileName, Uint8List bytes) async {
    await AppLogService.info(
        'AttachmentStorage', '保存文件: $fileName, 大小: ${bytes.length} 字节');
    try {
      final ext = _extractExtension(fileName);
      final hash = computeHash(bytes);
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final storageName = '${hash}_$uniqueId.$ext';
      final storagePath = '$_storageDirName/$storageName';

      if (kIsWeb) {
        await WebFileStore.write(_webKey(storagePath), bytes);
      } else {
        final dir = await _storageDir;
        final filePath = p.join(dir, storageName);
        await File(filePath).writeAsBytes(bytes);
      }

      return storagePath;
    } catch (e) {
      await AppLogService.error('AttachmentStorage', '保存文件失败: $fileName', e);
      rethrow;
    }
  }

  static Future<Uint8List?> readFile(String storagePath) async {
    await AppLogService.info('AttachmentStorage', '读取文件: $storagePath');
    try {
      if (kIsWeb) {
        return WebFileStore.read(_webKey(storagePath));
      }
      final dir = await _storageDir;
      final name = p.basename(storagePath);
      final filePath = p.join(dir, name);
      final file = File(filePath);
      if (await file.exists()) return await file.readAsBytes();
      return null;
    } catch (e) {
      await AppLogService.error('AttachmentStorage', '读取文件失败: $storagePath', e);
      rethrow;
    }
  }

  static Future<bool> deleteFile(String storagePath) async {
    await AppLogService.info('AttachmentStorage', '删除文件: $storagePath');
    try {
      if (kIsWeb) {
        await WebFileStore.delete(_webKey(storagePath));
        return true;
      }
      final dir = await _storageDir;
      final name = p.basename(storagePath);
      final filePath = p.join(dir, name);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      await AppLogService.error('AttachmentStorage', '删除文件失败: $storagePath', e);
      rethrow;
    }
  }

  static Future<String> getStorageDirPath() async {
    if (kIsWeb) return '';
    return _storageDir;
  }
}
