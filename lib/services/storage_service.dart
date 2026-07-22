import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'app_log_service.dart';

/// Static utility that provides a cached, resilient path to the application
/// documents directory.
///
/// On platforms where [getApplicationDocumentsDirectory] is unavailable
/// (e.g. Windows desktop / test environments without a registered platform
/// channel), a fallback directory is used instead.
class AppStorage {
  AppStorage._();

  static String? _resolved;

  /// Returns the path to the application documents directory.
  ///
  /// Resolution order:
  /// 1. [getApplicationDocumentsDirectory] (native)
  /// 2. If [MissingPluginException] is thrown:
  ///    - `FLUTTER_TEST` environment is set → [Directory.systemTemp]
  ///    - [Platform.isWindows] → `<cwd>/stroom_data`
  ///    - otherwise → [Directory.systemTemp]
  ///
  /// The result is cached after the first successful resolution.
  static Future<String> get directory async {
    if (_resolved != null) return _resolved!;
    await AppLogService.info('AppStorage', '获取应用文档目录');

    try {
      final dir = await getApplicationDocumentsDirectory();
      _resolved = dir.path;
    } on MissingPluginException {
      _resolved = _fallbackPath();
    }

    return _resolved!;
  }

  /// Determines a fallback path when [getApplicationDocumentsDirectory] fails.
  ///
  /// Uses [kIsWeb] + try-catch to safely check platform conditions across
  /// all Flutter targets (web, desktop, mobile, test).
  static String _fallbackPath() {
    // Web: dart:io (Directory, Platform) is unavailable.
    // Return a placeholder — actual file operations won't work on web.
    if (kIsWeb) {
      return '/stroom_data';
    }

    // Check for test environment (dart:io Platform might be partially available)
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        return _safeTempPath();
      }
    } catch (e) {
      AppLogService.warning('AppStorage', '检查 FLUTTER_TEST 环境变量失败: $e');
    }

    // Check for Windows desktop
    try {
      if (Platform.isWindows) {
        return _safeCwdPath('stroom_data');
      }
    } catch (e) {
      AppLogService.warning('AppStorage', '检查 Platform.isWindows 失败: $e');
    }

    return _safeTempPath();
  }

  /// Returns [Directory.systemTemp.path] safely, or a fallback if unavailable.
  static String _safeTempPath() {
    try {
      return Directory.systemTemp.path;
    } catch (e) {
      AppLogService.warning('AppStorage', '获取系统临时目录失败，使用 /tmp 回退: $e');
      return '/tmp';
    }
  }

  /// Returns [Directory.current.path]/[subDir] safely, or a fallback.
  static String _safeCwdPath(String subDir) {
    try {
      return '${Directory.current.path}/$subDir';
    } catch (e) {
      AppLogService.warning('AppStorage', '获取当前工作目录失败，使用 /tmp 回退: $e');
      return '/tmp/$subDir';
    }
  }

  /// Resets the cached path, forcing re-resolution on the next call.
  /// Useful in tests.
  static void resetCache() {
    _resolved = null;
  }
}
