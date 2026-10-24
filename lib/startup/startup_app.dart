import 'dart:async';
import 'dart:io' show exit, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import 'app_restart.dart';
import 'startup_sequence_controller.dart';
import 'startup_page.dart';
import '../application.dart';
import '../providers/update_provider.dart';
import '../services/backup_service.dart';
import '../widgets/update_dialog.dart';

// ====================================================================
// StartupApp — 应用启动入口
// ====================================================================
//
// 在应用启动时显示启动页面，并通过 StartupSequenceController 独立执行
// 数据格式检查、迁移和完整性验证。UI 只接收进度与结果事件。
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
/// Renders startup progress from [StartupSequenceController] and owns only
/// UI actions such as the migration dialog and transition to the main app.
class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp>
    with SingleTickerProviderStateMixin {
  bool _checkingComplete = false;
  bool _applicationReady = false;
  bool _isWorking = true;
  String _statusMessage = '';
  String? _progressDetail;
  late final StartupSequenceController _startupController;
  StreamSubscription<StartupCheckProgress>? _startupProgressSubscription;

  /// 数据安全防线阻断原因（版本哨兵 / 检查不可用 / 冻结）。
  /// 非 null 时启动页显示阻断页（拒绝进入主应用），不再渐出。
  String? _dataSafetyBlocked;

  /// Fade-out animation controller and opacity for smooth transition.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isFadingOut = false;

  /// Navigator key for the overlay [MaterialApp] that hosts [StartupPage].
  /// Used by [_showRestartDialog] to find a valid [Navigator] ancestor.
  final GlobalKey<NavigatorState> _overlayNavigatorKey =
      GlobalKey<NavigatorState>();

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
    _startupController = StartupSequenceController();
    _startupProgressSubscription = _startupController.progress.listen((event) {
      if (!mounted) return;
      setState(() {
        _isWorking = event.isWorking;
        _statusMessage = event.message;
        _progressDetail = event.detail;
        _dataSafetyBlocked = event.blockedMessage;
      });
    });
    _runStartupSequence();
  }

  @override
  void dispose() {
    _startupProgressSubscription?.cancel();
    _startupController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Waits for the independent backend controller, then performs UI actions.
  Future<void> _runStartupSequence() async {
    final outcome = await _startupController.run();
    if (!mounted || outcome.blockedMessage != null) return;
    if (outcome.failure != null) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await _prepareApplicationAndFadeOut();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (outcome.didMigrate) await _showRestartDialog();
    if (!mounted) return;
    await _prepareApplicationAndFadeOut();
  }

  /// Starts the fade-out transition to the main app.
  ///
  /// Uses [addPostFrameCallback] to ensure the [Stack] layout renders the
  /// main app underneath the splash before the animation begins, producing
  /// a buttery-smooth fade.
  void _startFadeOut() {
    if (!mounted || _isFadingOut) return;
    // 通知 Application：启动页即将渐出，启动后任务（更新/备份检查）
    // 的对话框现在可以显示了（不会被不透明的启动页遮住）。
    startupReadyNotifier.value = true;
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

  /// Build the main application only after startup checks have finished.
  /// Its providers and first screen can do substantial synchronous setup, so
  /// keeping it out of the tree while checks are running lets the startup UI
  /// render independently. Wait for its first frame before starting the fade.
  Future<void> _prepareApplicationAndFadeOut() async {
    if (!mounted) return;
    setState(() => _applicationReady = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _startFadeOut();
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
      builder: (dialogContext) => PopScope(
        // 阻止 Android 系统返回键关闭对话框：迁移后必须重启/退出，
        // 被返回键关掉会导致用户永远停留在启动页。
        canPop: false,
        child: AlertDialog(
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
                Navigator.of(dialogContext).pop();
                _exitApp();
              },
              child: const Text('退出应用'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                restartApp();
              },
              child: const Text('立即重启'),
            ),
          ],
        ),
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
    // The startup screen owns rendering while checks run. The main app is
    // inserted only once those checks finish, then revealed by the fade.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        if (_applicationReady)
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
              home: _dataSafetyBlocked != null
                  ? _DataSafetyBlockPage(
                      message: _dataSafetyBlocked!,
                      onExit: _exitApp,
                    )
                  : StartupPage(
                      isWorking: _isWorking,
                      statusMessage: _statusMessage,
                      progressDetail: _progressDetail,
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
  int _retryGeneration = 0;

  void _onRetry() {
    // 增加 generation：给 child 换一个新 Key，强制重建失败子树。
    // （ErrorWidget 占位符替换了失败的小部件后，同一个 const
    // Application 实例会被 updateChild 短路复用，不换 Key 重试无效。）
    // 同时复位启动后任务标记：首次启动构建失败时任务已在坏实例上
    // 消耗过标记，重试后的健康实例必须重新执行更新/备份检查。
    resetPostStartupTasksFlag();
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _retryGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 主应用（child）始终保留在 Widget 树中：错误恢复界面以覆盖层
    // 形式显示在其上方，用户始终能看到恢复入口。
    // 重试时通过 KeyedSubtree 换 Key 强制重新挂载 Application；
    // 启动后任务（更新检查/备份检查）有进程级去重保护（见
    // application.dart 的 _postStartupTasksStarted），不会重复执行。
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        _ErrorCatcher(
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
          child: KeyedSubtree(
            key: ValueKey('app_retry_$_retryGeneration'),
            child: widget.child,
          ),
        ),
        if (_hasError)
          Positioned.fill(
            // 兜底恢复界面，不会闪退
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
              home: Builder(
                builder: (overlayContext) => Scaffold(
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
                            style: Theme.of(overlayContext)
                                .textTheme
                                .headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage.isNotEmpty
                                ? _errorMessage
                                : '启动过程中遇到数据格式问题，已自动修复，请重试。',
                            textAlign: TextAlign.center,
                            style: Theme.of(overlayContext)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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
              ),
            ),
          ),
      ],
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

/// 数据安全阻断页：版本哨兵（数据由更新版本创建）或冻结
/// （迁移失败 / 无法自动修复）时全屏展示，拒绝进入主应用。
///
/// 只读页面：提供「导出数据」（全量导出到用户选择的位置，只读操作）
/// 与「退出应用」，绝不提供任何写入入口，防止破坏被保护的数据。
class _DataSafetyBlockPage extends ConsumerStatefulWidget {
  final String message;
  final VoidCallback? onExit;

  const _DataSafetyBlockPage({required this.message, this.onExit});

  @override
  ConsumerState<_DataSafetyBlockPage> createState() =>
      _DataSafetyBlockPageState();
}

class _DataSafetyBlockPageState extends ConsumerState<_DataSafetyBlockPage> {
  bool _exporting = false;

  Future<void> _checkForUpdate() async {
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('正在检查更新...'),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    await ref.read(updateProvider.notifier).checkForUpdate();
    if (!mounted) return;
    final state = ref.read(updateProvider);
    snackBar.close();

    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (state.updateAvailable) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => const UpdateDialog(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已是最新版本'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // 双平台统一路径：原生走 FilePicker 保存；Web 走内存构建 +
      // 浏览器下载（exportBackup 内部处理）。
      final exported = await BackupService.exportBackup(
        context,
        selection: BackupSelection.all,
      );
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据导出完成')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 阻断页不允许返回键关闭（数据保护）
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    size: 72, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  '数据安全保护',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (!kIsWeb) ...[
                      _buildUpdateButton(),
                    ],
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportData,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt),
                      label: const Text('导出数据'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onExit ?? () => SystemNavigator.pop(),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('退出应用'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    final isChecking = ref.watch(updateProvider).isChecking;
    return OutlinedButton.icon(
      onPressed: isChecking ? null : _checkForUpdate,
      icon: isChecking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.update),
      label: const Text('更新应用'),
    );
  }
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  ErrorWidgetBuilder? _originalBuilder;

  @override
  void initState() {
    super.initState();
    // Replace the global ErrorWidget.builder so build errors are caught here
    _originalBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // 注意：ErrorWidget.builder 在 build 阶段被同步调用，此时不能直接
      // setState（会触发 "setState() or markNeedsBuild() called during
      // build" 断言）。先把错误状态调度到帧后，再返回占位组件。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onError(details.exception, details.stack ?? StackTrace.current);
      });
      return _ErrorWidgetPlaceholder();
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
