import 'dart:io' show exit, Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;

import 'app_restart.dart';
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
// 2. 依次执行：数据格式版本检查 → 格式验证 → 完整性检查
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

class _StartupAppState extends State<StartupApp> with TickerProviderStateMixin {
  bool _checkingComplete = false;
  bool _isWorking = true;
  String _statusMessage = '';
  String? _progressDetail;
  bool _migrationPerformed = false;

  /// Fade-out animation controller and opacity for smooth transition.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isFadingOut = false;

  /// Gradient animation controller for the background during fade-out.
  late final AnimationController _gradientController;

  static const int _minimumDisplayMs = 1000;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _checkingComplete = true;
          _isFadingOut = false;
        });
      }
    });

    // Animated gradient background
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _runStartupSequence();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  /// Runs all startup checks, ensuring a minimum 1-second display.
  Future<void> _runStartupSequence() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Update status as we go
      await _updateStatus('正在检查数据格式版本...', '1/5');
      final migrationResult = await StartupCheckService.checkFormatVersion();
      final didMigration = migrationResult.needsMigration;

      await _updateStatus('正在验证数据格式...', '2/5');
      final formatIssues = await StartupCheckService.validateDataFormats();

      await _updateStatus('正在修复数据格式...', '3/5');
      await StartupCheckService.repairDataFormats();

      await _updateStatus('正在检查数据完整性...', '4/5');
      final integrityIssues = await StartupCheckService.checkDataIntegrity();

      await _updateStatus('正在准备应用...', '5/5');

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
        // Start fade-out animation before transitioning to main app
        setState(() {
          _isFadingOut = true;
        });
        _fadeController.forward();
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
      // Fade out before showing main app even on error
      setState(() {
        _isFadingOut = true;
      });
      _fadeController.forward();
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
              restartApp();
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
    if (_checkingComplete) {
      // Use a key to force rebuild the Application widget fresh
      return const Application(key: ValueKey('app_ready'));
    }

    // While startup checks are running OR during fade-out, show the startup
    // page on top of a gradient background.  During fade, the startup page
    // becomes transparent (opacity 1→0), revealing the same gradient behind
    // it.  This avoids flashing a black screen between startup and main app.
    //
    // Once the fade animation completes, [_checkingComplete] becomes true
    // and this entire widget tree is replaced with [Application].
    return Stack(
      children: [
        // Gradient background matching the startup page's theme colors.
        // Visible behind the startup page as it fades out, preventing a
        // black screen flash.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: _buildBackgroundGradient(),
                ),
                child: child,
              );
            },
            child: const SizedBox.shrink(),
          ),
        ),
        // The startup page sits on top. During fade, it becomes transparent
        // (opacity 1→0) to reveal the gradient background.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _isFadingOut ? _fadeAnimation.value : 1.0,
                child: child,
              );
            },
            child: MaterialApp(
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
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a gradient that matches the StartupPage's default gradient,
  /// so the transition isn't a sudden color pop.
  LinearGradient _buildBackgroundGradient() {
    final colors = _migrationPerformed
        ? [
            const Color(0xFF1A237E),
            const Color(0xFF4A148C),
            const Color(0xFF880E4F),
          ]
        : [
            const Color(0xFF0D47A1),
            const Color(0xFF1565C0),
            const Color(0xFF00897B),
          ];

    final angle = _gradientController.value * 2 * math.pi;
    return LinearGradient(
      begin: Alignment(math.cos(angle), math.sin(angle)),
      end: Alignment(-math.cos(angle), -math.sin(angle)),
      colors: colors,
    );
  }
}
