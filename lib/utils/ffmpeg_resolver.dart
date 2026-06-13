import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart' show Dio;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// FFmpeg 路径解析器
///
/// 负责在不同平台上查找或提取 FFmpeg 可执行文件：
/// - Android/iOS/macOS：使用 ffmpeg_kit_flutter 内置 FFmpeg（无需此解析器）
/// - Windows/Linux：自动从 CDN 下载 FFmpeg 二进制文件
/// - Web 端：使用 ffmpeg.wasm（无需此解析器）
class FFmpegResolver {
  FFmpegResolver._();

  /// 捆绑的 FFmpeg 在 asset 中的路径
  static const _bundledAssetBase = 'assets/ffmpeg/ffmpeg';

  /// FFmpeg 下载 URL（平台相关）
  static String? get _downloadUrl {
    if (Platform.isWindows) {
      return 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
    } else if (Platform.isLinux) {
      return 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz';
    }
    return null;
  }

  /// 检查系统是否安装了 FFmpeg（通过 PATH 查找）
  static Future<bool> isFFmpegAvailable() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return false;
    return await _findSystemFFmpeg() != null;
  }

  /// 确保 FFmpeg 就绪，返回可执行文件的路径
  ///
  /// 查找优先级：
  /// 1. 从 assets 中提取的捆绑二进制
  /// 2. 已下载到缓存目录的二进制
  /// 3. 自动从 CDN 下载
  /// 4. 系统 PATH 中的 FFmpeg
  ///
  /// 全都找不到则返回 null。
  static Future<String?> ensureFFmpegReady() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return null;

    // 1. 从 assets 提取
    try {
      final extracted = await _extractFromAssets();
      if (extracted != null) return extracted;
    } catch (e) {
      debugPrint('[FFmpegResolver] Asset extraction failed: $e');
    }

    // 2. 检查已下载的缓存
    final cached = await _getCachedPath();
    if (cached != null) {
      final file = File(cached);
      if (await file.exists()) {
        debugPrint('[FFmpegResolver] Using cached FFmpeg: $cached');
        return cached;
      }
    }

    // 3. 自动下载
    try {
      final downloaded = await _downloadFFmpeg();
      if (downloaded != null) return downloaded;
    } catch (e) {
      debugPrint('[FFmpegResolver] Download failed: $e');
    }

    // 4. 系统 PATH
    return await _findSystemFFmpeg();
  }

  /// 从 assets 中提取捆绑的 FFmpeg 二进制
  static Future<String?> _extractFromAssets() async {
    final assetPath = _getAssetPath();
    if (assetPath == null) return null;

    try {
      final byteData = await rootBundle.load(assetPath);
      return await _saveBinary(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// 获取已缓存到可写目录的 FFmpeg 路径
  static Future<String?> _getCachedPath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      return p.join(appDir.path, 'ffmpeg', binaryName);
    } catch (_) {
      return null;
    }
  }

  /// 自动从 CDN 下载 FFmpeg
  static Future<String?> _downloadFFmpeg() async {
    final url = _downloadUrl;
    if (url == null) return null;

    debugPrint('[FFmpegResolver] Downloading FFmpeg from $url ...');

    try {
      final tempDir = await getTemporaryDirectory();
      final downloadPath = p.join(tempDir.path, 'ffmpeg_download');

      // 使用 Dio 下载
      final dio = Dio();
      await dio.download(url, downloadPath);

      // 读取下载的文件
      final bytes = await File(downloadPath).readAsBytes();

      // 解压并提取 ffmpeg 二进制
      Uint8List? binaryBytes;

      if (Platform.isWindows) {
        binaryBytes = _extractFromZip(bytes, 'ffmpeg.exe');
      } else if (Platform.isLinux) {
        binaryBytes = _extractFromTarXz(bytes, 'ffmpeg');
      }

      if (binaryBytes == null || binaryBytes.isEmpty) {
        throw Exception('解压后未找到 ffmpeg 二进制文件');
      }

      // 保存二进制到缓存目录
      final savedPath = await _saveBinary(binaryBytes);
      if (savedPath != null) {
        debugPrint('[FFmpegResolver] FFmpeg downloaded to: $savedPath');
      }

      // 清理临时文件
      try {
        await File(downloadPath).delete();
      } catch (_) {}

      return savedPath;
    } catch (e) {
      debugPrint('[FFmpegResolver] Download failed: $e');
      return null;
    }
  }

  /// 从 ZIP 中提取指定文件
  static Uint8List? _extractFromZip(Uint8List bytes, String targetName) {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile && file.name.endsWith(targetName)) {
        return file.content as Uint8List;
      }
    }
    return null;
  }

  /// 从 tar.xz 中提取指定文件
  static Uint8List? _extractFromTarXz(Uint8List bytes, String targetName) {
    // 先解压 xz → tar
    final tarBytes = XZDecoder().decodeBytes(bytes);
    // 再解压 tar → 文件
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      if (file.isFile && p.basename(file.name) == targetName) {
        return file.content as Uint8List;
      }
    }
    return null;
  }

  /// 将 FFmpeg 二进制保存到应用缓存目录
  static Future<String?> _saveBinary(Uint8List bytes) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(p.join(appDir.path, 'ffmpeg'));
      if (!await ffmpegDir.exists()) {
        await ffmpegDir.create(recursive: true);
      }

      final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final outputPath = p.join(ffmpegDir.path, binaryName);
      await File(outputPath).writeAsBytes(bytes);

      // Linux/macOS 需要可执行权限
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', outputPath]);
      }

      return outputPath;
    } catch (e) {
      debugPrint('[FFmpegResolver] Save binary failed: $e');
      return null;
    }
  }

  /// 获取当前平台对应的 asset 路径
  static String? _getAssetPath() {
    if (Platform.isWindows) {
      return '${_bundledAssetBase}_windows.exe';
    } else if (Platform.isLinux) {
      return '${_bundledAssetBase}_linux';
    }
    return null;
  }

  /// 在系统 PATH 中查找 FFmpeg
  static Future<String?> _findSystemFFmpeg() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['ffmpeg']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.isNotEmpty && lines[0].trim().isNotEmpty) {
            return lines[0].trim();
          }
        }
      } else {
        final result = await Process.run('which', ['ffmpeg']);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty) return path;
        }
      }
    } catch (e) {
      debugPrint('[FFmpegResolver] System PATH lookup failed: $e');
    }
    return null;
  }
}
