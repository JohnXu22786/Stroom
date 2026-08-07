import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/image_send_compressor.dart' show CompressedImage;
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

  /// 保存"编辑后"的附件文件。
  ///
  /// 与 [saveFile] 的物理位置完全一致（桌面端落在附件存储目录、Web 端
  /// 使用相同存储键规则），但返回的 storagePath 带 `temp_edited/` 前缀
  /// 标记，供清理逻辑识别"编辑产物"。
  ///
  /// 修复背景：编辑后的图片之前被直接写入系统临时目录，而 readFile 按
  /// basename 解析到附件目录 → 发送后消息气泡加载文件失败
  /// （“无法加载文件”）。现在编辑产物与普通附件同目录存储，
  /// readFile/deleteFile 通过 basename 即可正确解析（Web 端则因键名
  /// 本身就是 storagePath 而天然一致），标记仍保留用于移除/删除语义。
  static Future<String> saveEditedFile(String fileName, Uint8List bytes) async {
    final ext = _extractExtension(fileName);
    final hash = computeHash(bytes);
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final storageName = '${hash}_$uniqueId.$ext';
    final storagePath = 'temp_edited/$storageName';

    if (kIsWeb) {
      await WebFileStore.write(storagePath, bytes);
    } else {
      final dir = await _storageDir;
      await File(p.join(dir, storageName)).writeAsBytes(bytes);
    }
    return storagePath;
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

  // ─────────────────────────────────────────────────────────────────────
  // 图片发送压缩缓存（`temp_compressed/<conversationId>/<hash>.<ext>`）
  // ─────────────────────────────────────────────────────────────────────
  //
  // 压缩产物按（对话, 原字节哈希）隔离存储：
  // - 对话：图片压缩缓存"属于"选中它的那个对话，删除对话时整目录清理；
  // - 哈希：原字节 md5，图片被编辑（字节变化）后自动失效换新。
  // 这是派生的发送缓存，绝不覆盖/删除原附件文件（storagePath）；
  // 删除缓存永远是安全的（最坏情况是下次发送时重新压缩）。
  static const _compressedCacheDirName = 'temp_compressed';

  /// 图片压缩缓存目录：`<附件目录>/temp_compressed/<conversationId>/`
  static Future<Directory> _compressedCacheDir(String conversationId) async {
    final base = await _storageDir;
    final dir = Directory(p.join(base, _compressedCacheDirName, conversationId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存图片发送压缩缓存（不覆盖原附件文件）。
  ///
  /// [conversationId]/[hash] 缺失时 no-op（返回 null，如"选中时对话
  /// 尚未创建"的待发送附件）。返回存储路径。
  static Future<String?> saveCompressedImage({
    required String? conversationId,
    required String hash,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (conversationId == null ||
        conversationId.isEmpty ||
        hash.isEmpty ||
        bytes.isEmpty) {
      return null;
    }
    final ext = mimeType == 'image/png' ? 'png' : 'jpg';
    final storageName = '$hash.$ext';
    final storagePath = '$_compressedCacheDirName/$conversationId/$storageName';
    await AppLogService.info(
        'AttachmentStorage', '保存图片压缩缓存: $storagePath, ${bytes.length} 字节');
    if (kIsWeb) {
      await WebFileStore.write(storagePath, bytes);
    } else {
      final dir = await _compressedCacheDir(conversationId);
      await File(p.join(dir.path, storageName)).writeAsBytes(bytes);
    }
    return storagePath;
  }

  /// 读取图片发送压缩缓存；不存在/损坏返回 null。
  ///
  /// 压缩产物可能是 JPEG 或 PNG（由输入格式决定），两种扩展名都尝试，
  /// 并以魔数校验内容与扩展名一致（不一致视为损坏）。
  static Future<CompressedImage?> readCompressedImage({
    required String? conversationId,
    required String hash,
  }) async {
    if (conversationId == null || conversationId.isEmpty || hash.isEmpty) {
      return null;
    }
    for (final (ext, mimeType) in [
      ('jpg', 'image/jpeg'),
      ('png', 'image/png'),
    ]) {
      Uint8List? bytes;
      final storagePath = '$_compressedCacheDirName/$conversationId/$hash.$ext';
      if (kIsWeb) {
        bytes = await WebFileStore.read(storagePath);
      } else {
        // 只读路径不创建目录：避免"删除后又被读操作重建空目录"
        final base = await _storageDir;
        final file = File(p.join(
            base, _compressedCacheDirName, conversationId, '$hash.$ext'));
        bytes = await file.exists() ? await file.readAsBytes() : null;
      }
      if (bytes == null || bytes.isEmpty) continue;
      if (ext == 'jpg' &&
          !(bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8)) {
        continue; // 扩展名 .jpg 但内容不是 JPEG 魔数 → 损坏
      }
      if (ext == 'png' &&
          !(bytes.length >= 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47 &&
              bytes[4] == 0x0D &&
              bytes[5] == 0x0A &&
              bytes[6] == 0x1A &&
              bytes[7] == 0x0A)) {
        continue; // 扩展名 .png 但内容不是 PNG 魔数（完整 8 字节）→ 损坏
      }
      return CompressedImage(bytes: bytes, mimeType: mimeType);
    }
    return null;
  }

  /// 删除指定附件的图片压缩缓存（JPEG/PNG 两种扩展名都尝试）。
  static Future<bool> deleteCompressedImage({
    required String? conversationId,
    required String hash,
  }) async {
    if (conversationId == null || conversationId.isEmpty || hash.isEmpty) {
      return false;
    }
    var deleted = false;
    for (final ext in ['jpg', 'png']) {
      final storagePath = '$_compressedCacheDirName/$conversationId/$hash.$ext';
      if (kIsWeb) {
        // 与原生端语义一致：仅当文件真实存在才算删除
        if (await WebFileStore.exists(storagePath)) {
          await WebFileStore.delete(storagePath);
          deleted = true;
        }
      } else {
        final base = await _storageDir;
        final file = File(p.join(
            base, _compressedCacheDirName, conversationId, '$hash.$ext'));
        if (await file.exists()) {
          await file.delete();
          deleted = true;
        }
      }
    }
    return deleted;
  }

  /// 删除整个对话的图片压缩缓存目录（删除对话时调用）。
  static Future<void> deleteConversationCompressedImages(
      String conversationId) async {
    if (conversationId.isEmpty) return;
    await AppLogService.info(
        'AttachmentStorage', '删除对话图片压缩缓存: $conversationId');
    if (kIsWeb) {
      await WebFileStore.deleteByPrefix('$_compressedCacheDirName/$conversationId/');
      return;
    }
    final base = await _storageDir;
    final dir = Directory(p.join(base, _compressedCacheDirName, conversationId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
