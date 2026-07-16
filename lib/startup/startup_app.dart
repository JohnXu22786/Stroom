import 'dart:async';
import 'dart:io' show exit, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;

import 'app_restart.dart';
import 'startup_check_service.dart';
import 'startup_page.dart';
import '../application.dart';
import '../providers/update_provider.dart';
import '../services/app_log_service.dart';
import '../services/data_migration_service.dart';

// ====================================================================
// StartupApp — 应用启动入口
// ====================================================================
//
// 在应用启动时显示启动页面，同时执行数据格式检查、迁移和完整性
// 验证。所有工作完成后，切换到主应用界面。
//
// 流程：
// 1. 立即显示启动页面（至少 1.5 秒）
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

  /// Collector for startup errors that should be displayed to the user.
  /// When non-null after startup completes, the error is shown in the UI
  /// instead of silently continuing.
  String? _startupError;

  /// Navigator key for the overlay [MaterialApp] that hosts [StartupPage].
  /// Used by [_showRestartDialog] to find a valid [Navigator] ancestor.
  final GlobalKey<NavigatorState> _overlayNavigatorKey =
      GlobalKey<NavigatorState>();

  static const int _minimumDisplayMs = 1500;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

  /// Runs the 5 startup checks sequentially, one by one.
  ///
  /// Design principle:
  /// - Each task updates the status via [setState] immediately (synchronous)
  ///   so the widget shows the new status on the next frame.
  /// - Between tasks we yield briefly to let the UI render the new status.
  /// - The 5 tasks are:
  ///     1. Check data format version (migration if needed)
  ///     2. Validate data formats
  ///     3. Check data integrity
  ///     4. Process & log results
  ///     5. Finalize — prepare to transition to main app
  /// - Backup storage check and auto-backup are moved to post-startup
  ///   (they run after the main app is shown) to avoid blocking the UI.
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

      // Ensure the splash screen animations have rendered the first frame
      if (!mounted) return;
      setState(() {}); // ensure initial layout
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      // ===============================================================
      // 依次执行所有检查，逐个进行
      // ===============================================================
      //
      // 全部5个检查依次执行（而非并行）。
      // 每步先通过 setState 更新状态文字（同步），
      // 然后短暂等待让 UI 有机会渲染新文字，
      // 最后执行对应的后端任务。
      //
      // 1. 检查数据格式版本（迁移）
      // 2. 验证数据格式（Isolate 后台执行）
      // 3. 检查数据完整性（Isolate 后台执行）
      // 4. 记录检查结果日志
      // 5. 完成启动准备 → 过渡到主应用
      // ===============================================================

      // ---- Task 1: 检查数据格式版本 ----
      _setStatus('正在检查数据格式版本...', '1/5');
      // 短暂让出，让 UI 渲染新状态
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      await AppLogService.info('StartupApp', '开始检查数据格式版本');
      MigrationResult migrationResult;
      try {
        migrationResult = await StartupCheckService.checkFormatVersion();
        await AppLogService.info('StartupApp',
            '数据格式版本检查完成: needsMigration=${migrationResult.needsMigration}');
      } catch (e) {
        debugPrint('[StartupApp] checkFormatVersion failed: $e');
        await AppLogService.error('StartupApp', '检查数据格式版本失败', e);
        migrationResult = const MigrationResult(needsMigration: false);
      }
      if (!mounted) return;

      // ---- Task 2: 验证数据格式 ----
      _setStatus('正在验证数据格式...', '2/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      await AppLogService.info('StartupApp', '开始验证数据格式');
      List<StartupIssue> formatIssues;
      try {
        formatIssues = await StartupCheckService.validateDataFormats();
        await AppLogService.info(
            'StartupApp', '数据格式验证完成: 发现 ${formatIssues.length} 个问题');
      } catch (e) {
        debugPrint('[StartupApp] validateDataFormats failed: $e');
        await AppLogService.error('StartupApp', '验证数据格式失败', e);
        formatIssues = <StartupIssue>[];
      }
      if (!mounted) return;

      // ---- Task 3: 检查数据完整性 ----
      _setStatus('正在检查数据完整性...', '3/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      await AppLogService.info('StartupApp', '开始检查数据完整性');
      List<StartupIssue> integrityIssues;
      try {
        integrityIssues = await StartupCheckService.checkDataIntegrity();
        await AppLogService.info(
            'StartupApp', '数据完整性检查完成: 发现 ${integrityIssues.length} 个问题');
      } catch (e) {
        debugPrint('[StartupApp] checkDataIntegrity failed: $e');
        await AppLogService.error('StartupApp', '检查数据完整性失败', e);
        integrityIssues = <StartupIssue>[];
      }
      if (!mounted) return;

      final didMigration = migrationResult.needsMigration;

      // ---- Task 4: 处理检查结果 ----
      _setStatus('正在处理检查结果...', '4/5');
      // Step 4 is instant (just logging), so give more time for the UI
      // to display this status before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final allIssues = <StartupIssue>[
        ...formatIssues,
        ...integrityIssues,
      ];

      // Log all issues found
      for (final issue in allIssues) {
        debugPrint('[StartupApp] ${issue.severity.name}: ${issue.message}');
      }

      // 收集检查过程中发现的问题，显示给用户
      if (allIssues.isNotEmpty) {
        final errorMessages = allIssues
            .where((i) => i.severity == StartupIssueSeverity.error)
            .map((i) => i.message)
            .toList();
        final warningMessages = allIssues
            .where((i) => i.severity == StartupIssueSeverity.warning)
            .map((i) => i.message)
            .toList();
        if (errorMessages.isNotEmpty || warningMessages.isNotEmpty) {
          final sb = StringBuffer();
          if (errorMessages.isNotEmpty) {
            sb.writeln('发现 ${errorMessages.length} 个数据问题:');
            for (final msg in errorMessages) {
              sb.writeln('  • $msg');
            }
          }
          if (warningMessages.isNotEmpty) {
            if (sb.isNotEmpty) sb.writeln();
            sb.writeln('${warningMessages.length} 个警告:');
            for (final msg in warningMessages) {
              sb.writeln('  • $msg');
            }
          }
          _startupError = sb.toString().trim();
        }
      }

      // Ensure minimum display time for pre-check tasks
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < _minimumDisplayMs) {
        await Future<void>.delayed(
            Duration(milliseconds: _minimumDisplayMs - elapsed));
      }

      if (!mounted) return;

      // ---- Task 5: 完成启动准备 ----
      _setStatus('准备启动应用', '5/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      // 所有预检查完成，显示完成状态
      setState(() {
        _isWorking = false;
        _migrationPerformed = didMigration;
        _progressDetail = null;
        if (_startupError != null) {
          _statusMessage = '启动完成（注意: $_startupError）';
        } else {
          _statusMessage = didMigration ? '数据检查完成，准备启动应用' : '准备启动应用';
        }
      });

      // Wait a moment so the user can see the completion state
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      // If migration was performed, show a restart prompt
      if (didMigration) {
        await _showRestartDialog();
      } else {
        _startFadeOut();
      }
    } catch (e, stack) {
      debugPrint('[StartupApp] Startup sequence failed: $e');
      debugPrint('[StartupApp] Stack: $stack');
      if (!mounted) return;

      // Show the actual error to the user, don't hide it
      setState(() {
        _isWorking = false;
        _startupError = e.toString();
        _statusMessage = '启动检查失败: ${e.toString()}';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      _startFadeOut();
    }
  }

  /// Starts the fade-out transition to the main app.
  ///
  /// Uses [addPostFrameCallback] to ensure the [Stack] layout renders the
  /// main app underneath the splash before the animation begins, producing
  /// a buttery-smooth fade.
  void _startFadeOut() {
    if (!mounted || _isFadingOut) return;
    setState(() {
      _isFadingOut = true;
    });
    // Start the fade animation on the very next frame, ensuring the
    // Application widget has rendered underneath before opacity changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  /// 同步更新启动页面的状态文本和进度详情。
  /// 调用后立即通过 setState 更新 UI，不等待帧渲染。
  /// 调用方应在调用此方法后主动让出事件循环以让 UI 渲染。
  void _setStatus(String message, String detail) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _progressDetail = detail;
    });
  }

  /// Shows a dialog indicating that migration was performed and the
  /// app needs to restart to use the new data format.
  ///
  /// Uses [_overlayNavigatorKey] to find a valid [Navigator] ancestor,
  /// because this widget (StartupApp) lives above the Navigator in the
  /// widget tree.
  Future<void> _showRestartDialog() async {
    final navContext = _overlayNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    await showDialog<void>(
      context: navContext,
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
      textDirection: TextDirection.ltr,
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
              navigatorKey: _overlayNavigatorKey,
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
