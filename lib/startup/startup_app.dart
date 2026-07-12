import 'dart:io' show exit, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;

import 'app_restart.dart';
import 'backup_startup_check.dart';
import 'startup_check_service.dart';
import 'startup_page.dart';
import '../application.dart';
import '../providers/update_provider.dart';

// ====================================================================
// StartupApp — 应用启动入口
// ====================================================================
//
// 在应用启动时显示启动页面，同时执行数据格式检查、迁移和完整性
// 验证。所有工作完成后，切换到主应用界面。
//
// 流程：
// 1. 立即显示启动页面（至少 1 秒）
// 2. 清除"更新后重启"标记（如存在）
// 3. 依次执行：数据格式版本检查 → 格式验证 → 完整性检查
// 4. 检查完成后，如果进行了数据迁移，提示用户重启
// 5. 否则无缝过渡到主应用
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

class _StartupAppState extends State<StartupApp>
    with SingleTickerProviderStateMixin {
  bool _checkingComplete = false;
  bool _isWorking = true;
  String _statusMessage = '';
  String? _progressDetail;
  bool _migrationPerformed = false;

  /// Fade-out animation controller and opacity for smooth transition.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isFadingOut = false;

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
    _runStartupSequence();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Runs all startup checks, ensuring a minimum 1-second display.
  /// Each check is separated by an event-loop yield so the UI never freezes.
  Future<void> _runStartupSequence() async {
    final stopwatch = Stopwatch()..start();

    try {
      // ---------------------------------------------------------------
      // 清除"更新后重启"标记
      // ---------------------------------------------------------------
      try {
        if (await hasPendingUpdateRestart()) {
          debugPrint('[StartupApp] Detected pending update restart flag '
              '(cold restart after APK install) — clearing it');
          await clearPendingUpdateRestart();
        }
      } catch (_) {}

      // 让出事件循环，确保启动页的动画能先渲染一帧
      await Future<void>.delayed(Duration.zero);

      // Update status as we go — each call yields to the event loop
      await _updateStatus('正在检查数据格式版本...', '1/4');
      final migrationResult = await StartupCheckService.checkFormatVersion();
      // 让出事件循环，避免顿住
      await Future<void>.delayed(Duration.zero);
      final didMigration = migrationResult.needsMigration;

      await _updateStatus('正在验证数据格式...', '2/4');
      final formatIssues = await StartupCheckService.validateDataFormats();
      await Future<void>.delayed(Duration.zero);

      await _updateStatus('正在检查数据完整性...', '3/4');
      final integrityIssues = await StartupCheckService.checkDataIntegrity();
      await Future<void>.delayed(Duration.zero);

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

      // ---------------------------------------------------------------
      // 步骤 5: 备份存储位置与自动备份检查
      // ---------------------------------------------------------------
      // 此检查会引导用户完成 Android SAF 授权（如需），
      // 并在授权后自动执行一次启动备份。如果空间不足或备份
      // 失败，会循环提示用户直到问题解决。
      // ---------------------------------------------------------------
      await _updateStatus('正在检查备份存储...', '5/5');
      final backupResult = await BackupStartupCheck.runCheck(context);
      await Future<void>.delayed(Duration.zero);

      if (!mounted) return;

      setState(() {
        _isWorking = false;
        _migrationPerformed = didMigration;
        _statusMessage = didMigration
            ? '数据检查完成，准备启动应用'
            : '准备启动应用';
      });

      // Wait a moment so the user can see the completion state
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      // If migration was performed, show a restart prompt
      if (didMigration) {
        await _showRestartDialog();
      } else {
        // Before fading, ensure the main app is rendered underneath
        // by setting _isFadingOut = true (which triggers Stack layout).
        // The splash remains on top and fades via opacity.
        setState(() {
          _isFadingOut = true;
        });
        // Let the frame render so the main app appears underneath
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
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
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
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
    // 让出事件循环，让 UI 有时间渲染更新（无需额外延迟）
    await Future<void>.delayed(Duration.zero);
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
    // Phase 3: 启动完成 — 仅显示主应用
    if (_checkingComplete) {
      return const _AppErrorBoundary(
        key: ValueKey('app_error_boundary'),
        child: Application(key: ValueKey('app_ready')),
      );
    }

    // Phase 2: 渐出中 — 主应用渲染在底层，启动页在最上层通过透明度渐出
    if (_isFadingOut) {
      return Stack(
        children: [
          // 底层：主应用（已渲染完成，通过相同 key 保持状态）
          const _AppErrorBoundary(
            key: ValueKey('app_fade_boundary'),
            child: Application(key: ValueKey('app_ready')),
          ),
          // 顶层：启动页渐出
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
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
        ],
      );
    }

    // Phase 1: 渐出前 — 仅显示启动页
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

// ====================================================================
// Error Boundary — 启动后异常兜底
// ====================================================================
//
// 在启动检查完成后，如果 Provider 初始化过程中发生 Widget 构建异常
// （例如数据格式修复后仍有残留的不兼容数据），此 ErrorBoundary 会
// 捕获异常并显示恢复界面，而不是让应用直接闪退。
// ====================================================================

/// A simple error boundary that catches build-phase exceptions in [child]
/// and displays a recoverable error UI instead of a blank/crashing screen.
///
/// This is specifically for catching errors that happen AFTER the startup
/// check sequence completes but DURING the first render of the [Application]
/// widget and its providers.  Once the error is handled, the user can press
/// "重试" to rebuild the widget tree.
class _AppErrorBoundary extends StatefulWidget {
  final Widget child;

  const _AppErrorBoundary({super.key, required this.child});

  @override
  State<_AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<_AppErrorBoundary> {
  bool _hasError = false;
  String _errorMessage = '';

  void _onRetry() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // 兜底恢复界面，不会闪退
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Colors.orange.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '应用启动异常',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage.isNotEmpty
                        ? _errorMessage
                        : '启动过程中遇到数据格式问题，已自动修复，请重试。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _ErrorCatcher(
      onError: (Object error, StackTrace stack) {
        debugPrint('[_AppErrorBoundary] Caught build error: $error');
        debugPrint('[_AppErrorBoundary] Stack: $stack');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
          });
        }
        return _ErrorWidgetPlaceholder();
      },
      child: widget.child,
    );
  }
}

/// Wraps [child] and catches any FlutterError (build/layout/paint errors)
/// by installing a zone error handler and a custom [ErrorWidget.builder].
///
/// When an error is caught, [onError] is called and a placeholder widget
/// is displayed instead of the default red error box.
class _ErrorCatcher extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stack) onError;

  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  @override
  State<_ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  ErrorWidgetBuilder? _originalBuilder;

  @override
  void initState() {
    super.initState();
    // Replace the global ErrorWidget.builder so build errors are caught here
    _originalBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final result = widget.onError(
          details.exception, details.stack ?? StackTrace.current);
      return result;
    };
  }

  @override
  void dispose() {
    // Restore the original ErrorWidget.builder
    if (_originalBuilder != null) {
      ErrorWidget.builder = _originalBuilder!;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A minimal placeholder widget used by [_ErrorCatcher] when errors occur.
class _ErrorWidgetPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
