import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/web_file_store.dart';

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
    final appDir = await getApplicationDocumentsDirectory();
    final dir = p.join(appDir.path, _storageDirName);
    final d = Directory(dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return dir;
  }

  static Future<String> saveFile(String fileName, Uint8List bytes) async {
    final ext = _extractExtension(fileName);
    final hash = computeHash(bytes);
    final storageName = '$hash.$ext';
    final storagePath = '$_storageDirName/$storageName';

    if (kIsWeb) {
      await WebFileStore.write(_webKey(storagePath), bytes);
    } else {
      final dir = await _storageDir;
      final filePath = p.join(dir, storageName);
      await File(filePath).writeAsBytes(bytes);
    }

    return storagePath;
  }

  static Future<Uint8List?> readFile(String storagePath) async {
    if (kIsWeb) {
      return WebFileStore.read(_webKey(storagePath));
    }
    final dir = await _storageDir;
    final name = p.basename(storagePath);
    final filePath = p.join(dir, name);
    final file = File(filePath);
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  static Future<bool> deleteFile(String storagePath) async {
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
  }

  static Future<String> getStorageDirPath() async {
    if (kIsWeb) return '';
    return _storageDir;
  }
}
