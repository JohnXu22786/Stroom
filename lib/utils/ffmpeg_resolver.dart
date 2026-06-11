import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// FFmpeg 路径解析器
///
/// 负责在不同平台上查找 FFmpeg 可执行文件：
/// - 桌面端 (Win/Mac/Linux)：检查系统 PATH、常见安装路径、捆绑资源
/// - 移动端 (Android/iOS)：检查捆绑资源
/// - Web 端：不可用
class FFmpegResolver {
  FFmpegResolver._();

  /// 检查系统是否安装了 FFmpeg
  ///
  /// 在桌面端执行 `ffmpeg -version` 验证。
  /// 在 Web 端始终返回 false。
  static Future<bool> isFFmpegAvailable() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['ffmpeg']);
        return result.exitCode == 0;
      } else {
        // macOS / Linux / Android / iOS
        final result = await Process.run('which', ['ffmpeg']);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('[FFmpegResolver] FFmpeg not found: $e');
      return false;
    }
  }

  /// 解析 FFmpeg 可执行文件的完整路径
  ///
  /// 按优先级查找：
  /// 1. 捆绑的 FFmpeg 资源
  /// 2. 系统 PATH
  /// 3. 常见安装路径
  ///
  /// 返回 null 表示未找到。
  static Future<String?> resolveFFmpegPath() async {
    // 1. 检查捆绑资源
    final bundled = await getBundledFFmpegPath();
    if (bundled != null) return bundled;

    // 2. 检查系统 PATH
    if (!kIsWeb) {
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
        debugPrint('[FFmpegResolver] PATH lookup failed: $e');
      }

      // 3. 检查常见安装路径
      final commonPaths = getCommonInstallPaths();
      for (final path in commonPaths) {
        final file = File(path);
        if (await file.exists()) return path;
      }
    }

    return null;
  }

  /// 获取捆绑的 FFmpeg 路径
  ///
  /// 检查应用资源目录中是否包含 FFmpeg 可执行文件。
  /// 移动端和桌面端均可通过此方式内置 FFmpeg。
  static Future<String?> getBundledFFmpegPath() async {
    if (kIsWeb) return null;

    // 检查常见捆绑位置
    final suffix = getPlatformSuffix();
    final searchPaths = [
      // 应用内资源目录
      'assets/ffmpeg/ffmpeg$suffix',
      'assets/bin/ffmpeg$suffix',

      // 可执行文件同目录
      'ffmpeg$suffix',
      './ffmpeg$suffix',

      // 上级目录
      '../ffmpeg$suffix',

      // 数据目录（Android）
      '/data/data/com.stroom.app/files/ffmpeg$suffix',
    ];

    for (final relativePath in searchPaths) {
      // 跳过那些需要平台特定权限的路径
      try {
        final file = File(relativePath);
        if (await file.exists()) {
          debugPrint('[FFmpegResolver] Found bundled FFmpeg at: $relativePath');
          return file.absolute.path;
        }
      } catch (_) {
        // 某些路径可能无权限访问（如 /data/data/）
        continue;
      }
    }

    return null;
  }

  /// 获取当前平台的 FFmpeg 可执行文件后缀
  static String getPlatformSuffix() {
    if (kIsWeb) return '';

    if (Platform.isWindows) {
      return '.exe';
    } else if (Platform.isMacOS) {
      return '_macos';
    } else if (Platform.isLinux) {
      return '_linux';
    } else if (Platform.isAndroid) {
      return '_android';
    } else if (Platform.isIOS) {
      return '_ios';
    }
    return '';
  }

  /// 获取常见安装路径列表（平台相关）
  static List<String> getCommonInstallPaths() {
    if (kIsWeb) return [];

    if (Platform.isWindows) {
      return [
        r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
        r'C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe',
        r'C:\tools\ffmpeg\bin\ffmpeg.exe',
        r'C:\ffmpeg\bin\ffmpeg.exe',
        // Chocolatey 安装路径
        r'C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/usr/local/bin/ffmpeg',
        '/opt/homebrew/bin/ffmpeg',
        '/usr/bin/ffmpeg',
        '/opt/local/bin/ffmpeg', // MacPorts
      ];
    } else if (Platform.isLinux) {
      return [
        '/usr/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
        '/snap/bin/ffmpeg',
      ];
    } else if (Platform.isAndroid) {
      return [
        '/data/data/com.termux/files/usr/bin/ffmpeg',
        '/system/bin/ffmpeg',
      ];
    } else if (Platform.isIOS) {
      return [
        '/usr/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
      ];
    }

    return [];
  }

  /// 获取适合当前平台的 FFmpeg 下载 URL（预留接口）
  static String? getDownloadUrl() {
    if (kIsWeb) return null;

    if (Platform.isWindows) {
      return 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
    } else if (Platform.isMacOS) {
      return 'https://evermeet.cx/ffmpeg/ffmpeg.zip';
    } else if (Platform.isLinux) {
      return 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz';
    }
    return null;
  }
}
