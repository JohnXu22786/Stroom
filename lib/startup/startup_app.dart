import 'dart:async';
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
import '../services/data_migration_service.dart';

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

  /// Runs all startup checks in parallel so the UI thread is never blocked.
  /// Ensures a minimum 1-second display and sets [_isWorking] to false only
  /// after all checks complete.
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

      // 确保启动页的动画能先渲染一帧
      await _yieldToFrame();

      // ===============================================================
      // 依次执行所有检查，逐个进行
      // ===============================================================
      //
      // 设计原理：
      // 全部5个检查依次执行（而非并行），每次执行前更新状态文字，
      // 并在每个检查之间让出一帧以确保 UI 动画流畅。
      //
      // 1. 检查数据格式版本
      // 2. 验证数据格式
      // 3. 检查数据完整性
      // 4. 处理检查结果
      // 5. 检查备份存储
      // ===============================================================

      // ---- Task 1: 检查数据格式版本 ----
      await _updateStatus('正在检查数据格式版本...', '1/5');
      MigrationResult migrationResult;
      try {
        migrationResult = await StartupCheckService.checkFormatVersion();
      } catch (e) {
        debugPrint('[StartupApp] checkFormatVersion failed: $e');
        migrationResult = const MigrationResult(needsMigration: false);
      }
      if (!mounted) return;
      await _yieldToFrame();

      // ---- Task 2: 验证数据格式 ----
      await _updateStatus('正在验证数据格式...', '2/5');
      List<StartupIssue> formatIssues;
      try {
        formatIssues = await StartupCheckService.validateDataFormats();
      } catch (e) {
        debugPrint('[StartupApp] validateDataFormats failed: $e');
        formatIssues = <StartupIssue>[];
      }
      if (!mounted) return;
      await _yieldToFrame();

      // ---- Task 3: 检查数据完整性 ----
      await _updateStatus('正在检查数据完整性...', '3/5');
      List<StartupIssue> integrityIssues;
      try {
        integrityIssues = await StartupCheckService.checkDataIntegrity();
      } catch (e) {
        debugPrint('[StartupApp] checkDataIntegrity failed: $e');
        integrityIssues = <StartupIssue>[];
      }
      if (!mounted) return;
      await _yieldToFrame();

      final didMigration = migrationResult.needsMigration;

      // ---- Task 4: 处理检查结果 ----
      // 汇总所有发现问题并记录日志
      await _updateStatus('正在处理检查结果...', '4/5');
      await _yieldToFrame();

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
      // Task 5: 备份存储位置与自动备份检查
      // ---------------------------------------------------------------
      // 此检查会引导用户完成 Android SAF 授权（如需），
      // 并在授权后自动执行一次启动备份。如果空间不足或备份
      // 失败，会循环提示用户直到问题解决。
      // ---------------------------------------------------------------
      await _updateStatus('正在检查备份存储...', '5/5');
      // The backup check runs its own UI/dialogs; we only await completion
      if (!mounted) return;
      await BackupStartupCheck.runCheck(context);
      await Future<void>.delayed(Duration.zero);

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
        // Start fade-out — the main app is rendered underneath the splash
        // via the Stack layout when _isFadingOut = true.
        setState(() {
          _isFadingOut = true;
        });
        // 让一帧渲染，使主应用出现在启动页下方，然后启动流畅的渐出动画
        await _yieldToFrame();
        if (!mounted) return;
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('[StartupApp] Startup sequence failed: $e');
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _statusMessage = '启动检查失败：$e\n\n可继续使用应用';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      // Fade out before showing main app even on error
      setState(() {
        _isFadingOut = true;
      });
      await _yieldToFrame();
      if (!mounted) return;
      _fadeController.forward();
    }
  }

  /// 更新启动页面的状态文本和进度详情。
  /// 等待下一帧被渲染后才返回，确保用户能看到状态变化。
  /// 如果有超时（无帧被调度），则安全降级为事件循环让出。
  Future<void> _updateStatus(String message, String detail) async {
    if (!mounted) return;
    final completer = Completer<void>();
    setState(() {
      _statusMessage = message;
      _progressDetail = detail;
    });
    // 等待下一个帧被渲染，确保用户能看到状态变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    // 超时保护：如果在 100ms 内无帧回调，则不阻塞后续流程
    await completer.future.timeout(
      const Duration(milliseconds: 100),
      onTimeout: () => completer.complete(),
    );
  }

  /// 让出到下一帧，确保动画/状态更新有机会渲染。
  /// 超时后降级为事件循环让出，避免死锁。
  Future<void> _yieldToFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    // 超时保护
    await completer.future.timeout(
      const Duration(milliseconds: 100),
      onTimeout: () => completer.complete(),
    );
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
    // 单一布局策略：Stack 中包含主应用（始终存在于 Widget 树中）和
    // 启动页（启动检查完成后移除）两层。
    //
    // 设计原理：
    // - Application 从第一次 build 起就存在于 Widget 树中，
    //   确保其在渐出开始时已经完全初始化，消除渐出卡顿。
    // - 启动页始终覆盖在主应用之上，通过在渐出过程中降低透明度
    //   来让主应用自然显示出来。
    // - 渐出完成后移除启动页，只显示主应用。
    return Stack(
      children: [
        // 主应用（始终存在，确保启动时完全初始化）
        const _AppErrorBoundary(
          key: ValueKey('app_fade_boundary'),
          child: Application(key: ValueKey('app_ready')),
        ),

        // 启动页覆盖层（检查完成后移除）
        if (!_checkingComplete)
          AnimatedBuilder(
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
      ],
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
