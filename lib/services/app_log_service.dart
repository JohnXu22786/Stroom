import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/web_file_store.dart';

// ====================================================================
// AppLogService — 应用日志服务
// ====================================================================
//
// 日志数据先存入内存缓冲区，每 10 秒自动写入一次存储。
// 写入成功后从内存中抹除。日志按天分割，格式为 app_YYYY-MM-DD.log。
// 每个日志条目包含时间戳、日志级别、来源和消息内容。
//
// 日志目录位置（与备份共享 Documents/Stroom 总目录）：
// - Windows: %USERPROFILE%\Documents\Stroom\Logs\
// - macOS:   ~/Documents/Stroom/Logs/
// - Linux:   ~/Documents/Stroom/Logs/
// - Android: <app_documents>/Stroom/Logs/
// - iOS:     <app_documents>/Stroom/Logs/
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

/// 内存中的日志条目。
class _LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  _LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

/// 应用日志服务。
///
/// 提供静态方法供全局调用，无需实例化。
/// 日志先存入内存缓冲区，每 10 秒自动写入 Documents/Stroom/Logs。
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

  /// 缓存日志目录。
  static Directory? _cachedLogDir;

  // ================================================================
  // 内存缓冲区与定时刷入
  // ================================================================

  /// 内存日志缓冲区。
  static final List<_LogEntry> _buffer = [];

  /// 定时刷入计时器（每 10 秒）。
  static Timer? _flushTimer;

  /// 刷入间隔。
  static const Duration _flushInterval = Duration(seconds: 10);

  /// 是否正在刷入中（防重入）。
  static bool _isFlushing = false;

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
  ///
  /// 日志先存入内存缓冲区，随后由定时器每 10 秒刷入文件。
  static Future<void> _writeLog(
      LogLevel level, String source, String message) async {
    // 先输出到控制台（所有场景）
    debugPrint('[AppLog] [${level.label}] [$source] $message');

    // 手动禁用或 Web 平台时跳过缓冲区写入
    if (_shouldSkipFileIo) return;

    _buffer.add(_LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    ));

    // 启动定时刷入（仅一次，非测试环境）
    if (_flushTimer == null) _startFlushTimer();
  }

  /// 启动定时刷入（仅在非测试环境下运行一次）。
  static void _startFlushTimer() {
    if (_flushTimer != null) return;
    // 测试环境不启动定时器，依赖显式 flush() 调用
    if (WebFileStore.isTestMode || _isTestEnv) return;
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      _flushBuffer();
    });
  }

  /// 将内存缓冲区中的所有日志刷入文件。
  ///
  /// 按日期分组写入对应的每日日志文件。写入成功后从缓冲区移除。
  /// 写入失败时回退（重新加入缓冲区前端）。
  static Future<void> _flushBuffer() async {
    if (_buffer.isEmpty || _isFlushing) return;
    _isFlushing = true;

    // 原子性取出所有待写入条目
    final entries = List<_LogEntry>.from(_buffer);
    _buffer.clear();

    try {
      final logDir = await getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // 按日期分组
      final byDate = <String, List<_LogEntry>>{};
      for (final entry in entries) {
        final dateStr =
            '${entry.timestamp.year}-${_pad(entry.timestamp.month)}-${_pad(entry.timestamp.day)}';
        byDate.putIfAbsent(dateStr, () => []).add(entry);
      }

      // 逐日期写入
      for (final group in byDate.entries) {
        final dateStr = group.key;
        final dateEntries = group.value;
        final logFile = File(p.join(logDir.path, 'app_$dateStr.log'));

        final sb = StringBuffer();
        for (final e in dateEntries) {
          final ts = e.timestamp;
          final timestamp = '${ts.year}-${_pad(ts.month)}-${_pad(ts.day)} '
              '${_pad(ts.hour)}:${_pad(ts.minute)}:${_pad(ts.second)}';
          sb.writeln(
              '[$timestamp] [${e.level.label}] [${e.source}] ${e.message}');
        }

        await logFile.writeAsString(sb.toString(), mode: FileMode.append);
      }
      // 写入成功：entries 已从 _buffer 清除，无需额外操作
    } catch (e) {
      // 写入失败：将条目放回缓冲区前端，避免丢失
      debugPrint('[AppLogService] 写入日志文件失败: $e');
      _buffer.insertAll(0, entries);
    } finally {
      _isFlushing = false;
    }
  }

  /// 等待所有待写入日志刷入文件。
  ///
  /// 在测试中调用此方法确保日志已写入后再断言。
  /// 在生产中也可手动调用以确保关键时刻（如应用退出前）日志已落盘。
  static Future<void> flush() async {
    await _flushBuffer();
  }

  /// 重置所有内部状态（仅用于测试）。
  static void reset() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _cachedLogDir = null;
    _manualFileLogging = null;
    _cachedIsTestEnv = false;
    _isTestEnvChecked = false;
    _isFlushing = false;
  }
  // ================================================================
  // 日志文件管理
  // ================================================================

  /// 获取日志目录。
  ///
  /// 日志目录位于 Documents/Stroom/Logs（与备份共享 Stroom 总目录）。
  /// 结果会被缓存，避免重复解析路径。
  static Future<Directory> getLogDir() async {
    if (_cachedLogDir != null) return _cachedLogDir!;
    if (kIsWeb) {
      _cachedLogDir = Directory('/tmp/stroom_logs');
      return _cachedLogDir!;
    }
    final logsPath = await _getLogsRootPath();
    _cachedLogDir = Directory(logsPath);
    return _cachedLogDir!;
  }

  /// 计算日志根目录路径（平台相关）。
  ///
  /// 路径策略（与 BackupLocationManager 的备份路径共享 Documents/Stroom）：
  /// - Windows: %USERPROFILE%\Documents\Stroom\Logs
  /// - macOS:   ~/Documents/Stroom/Logs
  /// - Linux:   ~/Documents/Stroom/Logs
  /// - Android: <app_documents>/Stroom/Logs
  /// - iOS:     <app_documents>/Stroom/Logs
  static Future<String> _getLogsRootPath() async {
    // 测试环境
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        return '${Directory.systemTemp.path}/stroom_log_test';
      }
    } catch (_) {}

    // Windows: %USERPROFILE%\Documents\Stroom\Logs
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return p.join(userProfile, 'Documents', 'Stroom', 'Logs');
        }
      }
    } catch (_) {}

    // macOS / Linux: ~/Documents/Stroom/Logs
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, 'Documents', 'Stroom', 'Logs');
        }
      }
    } catch (_) {}

    // 移动平台：应用 Documents 目录
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        return p.join(docsDir.path, 'Stroom', 'Logs');
      }
    } catch (_) {}

    // 兜底
    try {
      return p.join(Directory.systemTemp.path, 'Stroom', 'Logs');
    } catch (_) {
      return '/tmp/Stroom/Logs';
    }
  }

  /// 清空日志目录缓存（仅用于测试）。
  static void clearLogDirCache() {
    _cachedLogDir = null;
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
  /// 如果文件不存在返回 `null`。文件存在但因 I/O 错误无法读取也返回 `null`，
  /// 但会记录更详细的错误信息到控制台。
  static Future<String?> readLogFile(String fileName) async {
    try {
      final logDir = await getLogDir();
      final filePath = p.join(logDir.path, fileName);
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[AppLogService] 日志文件不存在: $filePath');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      debugPrint('[AppLogService] 读取日志文件失败 ($fileName): $e');
      // 如果是因为文件损坏或其他 I/O 错误，记录更详细的信息
      try {
        final logDir = await getLogDir();
        final filePath = p.join(logDir.path, fileName);
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('[AppLogService] 文件存在，大小: $fileSize 字节, 路径: $filePath');
        }
      } catch (_) {
        // 静默处理诊断失败的情况
      }
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
