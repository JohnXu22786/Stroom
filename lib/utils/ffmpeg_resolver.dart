import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// FFmpeg 路径解析器
///
/// 负责在不同平台上查找或提取 FFmpeg 可执行文件：
/// - Android/iOS/macOS：使用 ffmpeg_kit_flutter 内置 FFmpeg（无需此解析器）
/// - Windows/Linux：从 APP 资产中提取捆绑的 FFmpeg 二进制文件
/// - Web 端：不可用
class FFmpegResolver {
  FFmpegResolver._();

  /// 捆绑的 FFmpeg 在 asset 中的路径（不含平台后缀）
  static const _bundledAssetBase = 'assets/ffmpeg/ffmpeg';

  /// 检查系统是否安装了 FFmpeg（通过 PATH 查找）
  ///
  /// 仅在桌面端有效，移动端和 macOS 使用 ffmpeg_kit_flutter。
  /// Web 端始终返回 false。
  static Future<bool> isFFmpegAvailable() async {
    if (kIsWeb) return false;
    // 移动端和 macOS 使用 ffmpeg_kit_flutter，不需要系统 FFmpeg
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return false;

    return await _findSystemFFmpeg() != null;
  }

  /// 确保 FFmpeg 就绪，返回可执行文件的路径
  ///
  /// 桌面端（Windows/Linux）：
  /// 1. 先检查是否已提取到可写目录
  /// 2. 若未提取，从 assets 中提取
  /// 3. 若 assets 中也没有，检查系统 PATH
  /// 4. 若都没有返回 null
  ///
  /// 移动端和 macOS（使用 ffmpeg_kit_flutter）直接返回 null
  /// Web 端直接返回 null
  static Future<String?> ensureFFmpegReady() async {
    if (kIsWeb) return null;

    // 移动端和 macOS 使用 ffmpeg_kit_flutter，不需要此解析器
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return null;

    // 1. 检查是否已提取到可写目录
    final extracted = await _getExtractedPath();
    if (extracted != null) {
      final file = File(extracted);
      if (await file.exists()) {
        debugPrint('[FFmpegResolver] Found extracted FFmpeg at: $extracted');
        return extracted;
      }
    }

    // 2. 从 assets 中提取捆绑的二进制文件
    try {
      final extractedPath = await _extractFromAssets();
      if (extractedPath != null) {
        debugPrint('[FFmpegResolver] Extracted bundled FFmpeg to: $extractedPath');
        return extractedPath;
      }
    } catch (e) {
      debugPrint('[FFmpegResolver] Failed to extract bundled FFmpeg: $e');
    }

    // 3. 检查系统 PATH
    final systemPath = await _findSystemFFmpeg();
    if (systemPath != null) return systemPath;

    return null;
  }

  /// 获取已提取的 FFmpeg 路径
  static Future<String?> _getExtractedPath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      return p.join(appDir.path, 'ffmpeg', binaryName);
    } catch (_) {
      return null;
    }
  }

  /// 从 assets 中提取捆绑的 FFmpeg 二进制文件
  static Future<String?> _extractFromAssets() async {
    final assetPath = _getAssetPath();
    if (assetPath == null) return null;

    try {
      // 从 asset bundle 读取二进制数据
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();

      // 写入可写目录
      final appDir = await getApplicationSupportDirectory();
      final ffmpegDir = Directory(p.join(appDir.path, 'ffmpeg'));
      if (!await ffmpegDir.exists()) {
        await ffmpegDir.create(recursive: true);
      }

      final binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final outputPath = p.join(ffmpegDir.path, binaryName);
      await File(outputPath).writeAsBytes(bytes);

      // Linux/macOS 需要设置可执行权限
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', outputPath]);
      }

      return outputPath;
    } catch (e) {
      debugPrint('[FFmpegResolver] Asset extraction failed: $e');
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
    // macOS 使用 ffmpeg_kit_flutter，不需要 asset 中的二进制
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

    // 检查常见安装路径
    final commonPaths = _getCommonInstallPaths();
    for (final path in commonPaths) {
      final file = File(path);
      if (await file.exists()) return path;
    }

    return null;
  }

  /// 获取常见安装路径列表（用于桌面端回退）
  static List<String> _getCommonInstallPaths() {
    if (kIsWeb) return [];

    if (Platform.isWindows) {
      return [
        r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
        r'C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe',
        r'C:\tools\ffmpeg\bin\ffmpeg.exe',
        r'C:\ffmpeg\bin\ffmpeg.exe',
        r'C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/usr/local/bin/ffmpeg',
        '/opt/homebrew/bin/ffmpeg',
        '/usr/bin/ffmpeg',
        '/opt/local/bin/ffmpeg',
      ];
    } else if (Platform.isLinux) {
      return [
        '/usr/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
        '/snap/bin/ffmpeg',
      ];
    }

    return [];
  }
}