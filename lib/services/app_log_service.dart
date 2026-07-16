import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

import 'data_migration_service.dart';
import '../utils/web_file_store.dart';

// ====================================================================
// AppLogService — 应用日志服务
// ====================================================================
//
// 将应用运行日志写入自动备份目录下的 logs/ 子目录。
// 日志按天分割，格式为 app_YYYY-MM-DD.log。
// 每个日志条目包含时间戳、日志级别、来源和消息内容。
//
// 日志保留策略：保留最近 3 次使用的天的日志（按文件日期计）。
// 超过 3 天的日志文件会自动清理。
//
// 日志级别：
// - DEBUG: 调试信息（详细开发日志）
// - INFO:  一般运行信息
// - WARN:  警告（潜在问题）
// - ERROR: 错误（需要关注的问题）
// ====================================================================

/// 日志级别枚举。
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  final String label;
  const LogLevel(this.label);
}

/// 应用日志服务。
///
/// 提供静态方法供全局调用，无需实例化。
/// 日志写入备份目录下的 logs/ 子目录。
class AppLogService {
  AppLogService._();

  /// 是否已手动设置过（true=禁用, false=启用）。
  /// 未设置时保持 null，由 [_shouldSkipFileIo] 根据测试环境自动判断。
  static bool? _manualFileLogging;

  /// 启用文件日志写入。
  static void enableFileLogging() => _manualFileLogging = false;

  /// 禁用文件日志写入（仅控制台输出，用于测试）。
  static void disableFileLogging() => _manualFileLogging = true;

  /// 是否应该跳过文件 I/O。
  /// - Web 平台始终跳过。
  /// - 手动设置的值优先。
  /// - 测试模式（WebFileStore.isTestMode 或 FLUTTER_TEST 环境变量）下默认跳过。
  /// - 生产环境默认写入文件。
  static bool _cachedIsTestEnv = false;
  static bool _isTestEnvChecked = false;

  /// Lazily determine whether we are running in a test environment.
  static bool get _isTestEnv {
    if (_isTestEnvChecked) return _cachedIsTestEnv;
    _isTestEnvChecked = true;
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        _cachedIsTestEnv = true;
      }
    } catch (_) {}
    return _cachedIsTestEnv;
  }

  static bool get _shouldSkipFileIo {
    if (kIsWeb) return true;
    if (_manualFileLogging != null) return _manualFileLogging!;
    // 测试模式下默认只输出到控制台
    if (WebFileStore.isTestMode || _isTestEnv) return true;
    return false;
  }

  /// 日志文件保留天数。
  static const int _retentionDays = 3;

  /// 日志子目录名。
  static const String _logDirName = 'logs';

  // ================================================================
  // 日志写入方法
  // ================================================================

  /// 写入 DEBUG 级别日志。
  static Future<void> debug(String source, String message) async {
    await _writeLog(LogLevel.debug, source, message);
  }

  /// 写入 INFO 级别日志。
  static Future<void> info(String source, String message) async {
    await _writeLog(LogLevel.info, source, message);
  }

  /// 写入 WARNING 级别日志。
  static Future<void> warning(String source, String message) async {
    await _writeLog(LogLevel.warning, source, message);
  }

  /// 写入 ERROR 级别日志，可包含异常和堆栈信息。
  static Future<void> error(
    String source,
    String message, [
    Object? exception,
    StackTrace? stackTrace,
  ]) async {
    String fullMessage = message;
    if (exception != null) {
      fullMessage += ' | 异常: $exception';
    }
    if (stackTrace != null) {
      // 只取前 5 行堆栈，避免日志文件过大
      final lines = stackTrace.toString().split('\n');
      final truncated = lines.take(5).join('\n  ');
      fullMessage += '\n  堆栈:\n  $truncated';
    }
    await _writeLog(LogLevel.error, source, fullMessage);
  }

  /// 核心日志写入方法。
  static Future<void> _writeLog(
      LogLevel level, String source, String message) async {
    // 先输出到控制台（所有场景）
    debugPrint('[AppLog] [${level.label}] [$source] $message');

    // 手动禁用或 Web 平台时跳过文件写入
    if (_shouldSkipFileIo) return;

    // 文件写入以 fire-and-forget 方式执行，绝不阻塞主流程。
    // 在 testWidgets 的 FakeAsync zone 中，即使 _shouldSkipFileIo=false，
    // 文件 I/O 也会永远挂起，所以必须不等待。
    _writeLogToFile(level, source, message);
  }

  /// 用于测试同步的 Completer，完成时表示所有待写入日志已刷新。
  static Completer<void>? _flushCompleter;

  /// 等待所有待写入日志完成（仅用于测试）。
  static Future<void> flush() async {
    await _flushCompleter?.future;
  }

  /// 将日志写入文件（fire-and-forget，不阻塞调用方）。
  /// 在 _shouldSkipFileIo 为 true 时完全跳过（不创建 Future/timer），
  /// 避免在 testWidgets 的 FakeAsync zone 中产生未决计时器。
  static void _writeLogToFile(LogLevel level, String source, String message) {
    if (_shouldSkipFileIo) return;

    // 使用 Future 构造避免 async/await，确保即使在没有微任务调度的
    // FakeAsync zone 中也不会挂起调用方。
    final completer = Completer<void>();
    _flushCompleter = completer;
    Future(() async {
      try {
        final logDir = await getLogDir();
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final now = DateTime.now();
        final dateStr = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
        final logFile = File(p.join(logDir.path, 'app_$dateStr.log'));
        final timestamp = '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
            '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
        final logLine = '[$timestamp] [${level.label}] [$source] $message\n';
        await logFile.writeAsString(logLine, mode: FileMode.append);
      } catch (_) {
        // 文件写入失败不影响主流程（包括 FakeAsync zone 中不可用的情况）
      } finally {
        completer.complete();
      }
    });
  }
  // ================================================================
  // 日志文件管理
  // ================================================================

  /// 获取日志目录。
  ///
  /// 日志目录位于自动备份目录下的 logs/ 子目录。
  static Future<Directory> getLogDir() async {
    if (kIsWeb) {
      return Directory('/tmp/stroom_logs');
    }
    final backupRoot = await DataMigrationService.getExternalBackupRootPath();
    return Directory(p.join(backupRoot, _logDirName));
  }

  /// 列出所有日志文件。
  ///
  /// 返回按文件名（即日期）排序的日志文件名列表。
  static Future<List<String>> listLogFiles() async {
    try {
      final logDir = await getLogDir();
      if (!await logDir.exists()) return [];

      final entries = await logDir.list().toList();
      final logFiles = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.log') && f.path.contains('app_'))
          .map((f) => p.basename(f.path))
          .toList();
      logFiles.sort(); // 按日期排序
      return logFiles;
    } catch (e) {
      debugPrint('[AppLogService] 列出日志文件失败: $e');
      return [];
    }
  }

  /// 读取指定日志文件的内容。
  ///
  /// [fileName] 是文件名（如 `app_2024-01-01.log`）。
  /// 如果文件不存在返回 `null`。
  static Future<String?> readLogFile(String fileName) async {
    try {
      final logDir = await getLogDir();
      final file = File(p.join(logDir.path, fileName));
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('[AppLogService] 读取日志文件失败: $e');
      return null;
    }
  }

  /// 读取今天的日志内容。
  static Future<String?> readTodayLog() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
    return readLogFile('app_$dateStr.log');
  }

  /// 清理超过保留天数的旧日志文件。
  ///
  /// 保留最近 _retentionDays 天的日志文件。
  /// 此方法应在启动时或每日首次写入日志时调用。
  static Future<void> cleanupOldLogs() async {
    if (kIsWeb) return;

    try {
      final logDir = await getLogDir();
      if (!await logDir.exists()) return;

      final entries = await logDir.list().toList();
      final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));

      for (final entry in entries) {
        if (entry is! File) continue;
        if (!entry.path.endsWith('.log')) continue;

        // 从文件名提取日期: app_YYYY-MM-DD.log
        final fileName = p.basename(entry.path);
        final dateMatch =
            RegExp(r'app_(\d{4}-\d{2}-\d{2})\.log').firstMatch(fileName);
        if (dateMatch == null) continue;

        try {
          final fileDate = DateTime.parse(dateMatch.group(1)!);
          if (fileDate.isBefore(cutoff)) {
            await entry.delete();
            debugPrint('[AppLogService] 清理旧日志: $fileName');
          }
        } catch (_) {
          // 日期解析失败，跳过
        }
      }
    } catch (e) {
      debugPrint('[AppLogService] 清理旧日志失败: $e');
    }
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');
