import 'dart:io' show exit, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;

import 'startup_check_service.dart';
import 'startup_page.dart';
import '../application.dart';

// ====================================================================
// StartupApp — 应用启动入口
// ====================================================================
//
// 在应用启动时显示启动页面，同时执行数据格式检查、迁移和完整性
// 验证。所有工作完成后，切换到主应用界面。
//
// 流程：
// 1. 立即显示启动页面（至少 1 秒）
// 2. 依次执行：崩溃恢复 → 数据格式版本检查 → 格式验证 → 完整性检查
// 3. 检查完成后，如果进行了数据迁移，提示用户重启
// 4. 否则无缝过渡到主应用
// ====================================================================

/// The root widget shown at app launch.
///
/// Manages the startup flow:
/// 1. Shows a beautiful splash screen immediately
/// 2. Runs all startup checks (format version, migration, validation, integrity)
/// 3. After checks complete + minimum 1s, transitions to the main app
class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  bool _checkingComplete = false;
  bool _isWorking = true;
  String _statusMessage = '';
  String? _progressDetail;
  bool _migrationPerformed = false;

  static const int _minimumDisplayMs = 1000;

  @override
  void initState() {
    super.initState();
    _runStartupSequence();
  }

  /// Runs all startup checks, ensuring a minimum 1-second display.
  Future<void> _runStartupSequence() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Step 0: Crash recovery — recover from interrupted writes/migrations
      await _updateStatus('正在恢复崩溃数据...', '恢复中');
      final crashRecovered = await StartupCheckService.recoverCrashData();
      if (crashRecovered) {
        debugPrint('[StartupApp] Crash data recovered successfully');
      }

      // Update status as we go
      await _updateStatus('正在检查数据格式版本...', '1/4');
      final migrationResult = await StartupCheckService.checkFormatVersion();
      final didMigration = migrationResult.needsMigration;

      await _updateStatus('正在验证数据格式...', '2/4');
      final formatIssues = await StartupCheckService.validateDataFormats();

      await _updateStatus('正在检查数据完整性...', '3/4');
      final integrityIssues = await StartupCheckService.checkDataIntegrity();

      await _updateStatus('正在准备应用...', '4/4');

      final allIssues = <StartupIssue>[
        ...formatIssues,
        ...integrityIssues,
      ];

      // Log all issues found
      for (final issue in allIssues) {
        debugPrint('[StartupApp] ${issue.severity.name}: ${issue.message}');
      }

      // Ensure minimum display time
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < _minimumDisplayMs) {
        await Future.delayed(
            Duration(milliseconds: _minimumDisplayMs - elapsed));
      }

      if (!mounted) return;

      setState(() {
        _isWorking = false;
        _migrationPerformed = didMigration;
        _statusMessage = didMigration ? '数据检查完成，准备启动应用' : '准备启动应用';
      });

      // Wait a moment so the user can see the completion state
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      // If migration was performed, show a restart prompt
      if (didMigration) {
        await _showRestartDialog();
      } else {
        setState(() {
          _checkingComplete = true;
        });
      }
    } catch (e) {
      debugPrint('[StartupApp] Startup sequence failed: $e');
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _statusMessage = '启动检查失败，可继续使用应用';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() {
        _checkingComplete = true;
      });
    }
  }

  /// Updates the status message and progress detail on the startup page.
  Future<void> _updateStatus(String message, String detail) async {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _progressDetail = detail;
    });
    // Small delay so the user can see each status update
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Shows a dialog indicating that migration was performed and the
  /// app needs to restart to use the new data format.
  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('数据格式升级完成'),
          ],
        ),
        content: const Text(
          '数据已迁移到新版格式。'
          '请重启应用以使用新版本。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exitApp();
            },
            child: const Text('退出应用'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exitApp();
            },
            child: const Text('立即重启'),
          ),
        ],
      ),
    );
  }

  /// Exits the application (migration requires restart).
  void _exitApp() {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        exit(0);
      }
    } catch (e) {
      debugPrint('[StartupApp] Failed to exit app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // When startup checks are complete and no migration was needed,
    // show the main application
    if (_checkingComplete) {
      // Use a key to force rebuild the Application widget fresh
      return const Application(key: ValueKey('app_ready'));
    }

    // Show the startup page
    return MaterialApp(
      title: 'Stroom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: StartupPage(
        isWorking: _isWorking,
        statusMessage: _statusMessage,
        progressDetail: _progressDetail,
        migrationPerformed: _migrationPerformed,
      ),
    );
  }
}
