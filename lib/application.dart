import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:async';
import 'dart:io' show exit, Platform;

import 'pages/home_page.dart';
import 'pages/chat_page.dart';
import 'pages/files_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/notification_provider.dart';
import 'services/app_log_service.dart';
import 'services/auto_backup_service.dart';
import 'services/notification_service.dart';
import 'startup/backup_startup_check.dart';
import 'widgets/update_dialog.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<Application>
    with WidgetsBindingObserver {
  /// Global key for the MaterialApp's Navigator, used to show the
  /// update dialog from a context that is INSIDE the navigator.
  ///
  /// This is necessary because [_checkForUpdatesOnStartup] runs from
  /// [initState], whose BuildContext lives ABOVE the MaterialApp's
  /// Navigator. Using [navigatorKey.currentContext] ensures
  /// [showDialog] can find [MaterialLocalizations] and the
  /// [NavigatorState] it needs.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  bool _postStartupTasksStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 在进入主界面后执行启动后流程（非 Web 端）：
    // 1. 检查更新（必须弹窗而非静默）
    // 2. 检查备份存储授权 + 自动备份（与检查更新并行）
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runPostStartupTasks();
      });
    }

    // Set up in-app notification handler
    NotificationService().onInAppNotification = (payload) {
      if (mounted) {
        ref.read(inAppNotificationProvider.notifier).state = payload;
      }
    };
  }

  /// 执行启动后流程：
  /// - 检查更新（有更新必须弹窗）
  /// - 检查备份存储授权 + 自动备份（并行运行）
  Future<void> _runPostStartupTasks() async {
    if (_postStartupTasksStarted) return;
    _postStartupTasksStarted = true;

    await AppLogService.info('Application', '开始执行启动后任务');
    // 启动时清理过期日志
    unawaited(AppLogService.cleanupOldLogs().catchError((_) {}));

    // 并行执行两个启动后任务：
    // 1. 检查更新
    // 2. 检查备份存储授权并自动备份
    await Future.wait([
      _checkForUpdatesOnStartup(),
      _checkBackupOnStartup(),
    ]);
    await AppLogService.info('Application', '启动后任务执行完成');
  }

  /// 启动后检查备份存储：
  /// - 如果未授权目录，立即弹窗要求授权
  /// - 授权后自动执行备份
  /// - 未授权不允许继续使用应用
  Future<void> _checkBackupOnStartup() async {
    try {
      // 获取 Navigator context 用于显示对话框
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;

      final result = await BackupStartupCheck.runCheck(navigatorContext);

      // 长时间异步后检查 mounted 状态
      if (!mounted) return;

      if (!result.storageReady) {
        // 用户点击了"退出应用"或授权失败 — 真正退出应用
        debugPrint('[Application] 备份存储未就绪，退出应用');
        _exitApp();
        return;
      }

      if (result.autoBackupPerformed) {
        debugPrint('[Application] 启动后备份检查完成: 已就绪');
      }
    } catch (e, stack) {
      debugPrint('[Application] 启动后备份检查失败: $e');
      debugPrint('[Application] Backup check stack: $stack');
    }
  }

  // ---------------------------------------------------------------
  // 生命周期检测：更新后热恢复处理
  // ---------------------------------------------------------------
  //
  // 设计原理：
  //
  // 当用户在 app 内触发 APK 安装后，有两种可能的后续路径：
  //
  // 路径 A — Kotlin onNewIntent 处理（首选）
  //   用户从安装器点击"打开" → 系统发送 Intent → Kotlin onNewIntent()
  //   检测到 SharedPreferences 标记 → 清标记 → 调度 AlarmManager →
  //   finishAffinity() + killProcess() → 干净的冷启动
  //   这是首选路径，对用户无感。
  //
  // 路径 B — Dart 热恢复处理（备选）
  //   如果 Kotlin 处理失败（例如异常、权限不足），
  //   didChangeAppLifecycleState(resumed) 被调用。
  //   此处理程序检查 SharedPreferences 标记，
  //   如果存在则提示用户手动重启。
  //
  // 用户取消安装的场景：
  //   用户按返回键取消安装器 → app 恢复 → resumed 被调用。
  //   此时 isPendingRestartInMemory 为 false（已在 paused 时清除），
  //   但 SharedPreferences 标记仍在。然而 dialog 只会在
  //   isPendingRestartInMemory 为 true 时触发，因为 SharedPreferences
  //   标记无法区分"安装完成"和"安装取消"。
  //   所以正确的行为是：仅当 in-memory 标记为 true 时才显示 dialog。
  //   但 in-memory 标记在 paused 时已清除... 这又回到了原点。
  //
  // 最终方案：
  //   paused 时不清除 in-memory 标记。
  //   而是利用 Kotlin onNewIntent() 作为主要处理方式。
  //   Dart 侧仅作为备选：当 Kotlin 处理失败时，
  //   检查 SharedPreferences 标记，如果存在则提示用户。
  //   Kotlin 处理成功后进程被杀死，Dart 备选不会执行。
  //
  //   用户取消安装的场景：
  //   - Kotlin onNewIntent 不触发（没有新的 Intent）
  //   - Dart resumed 被调用，isPendingRestartInMemory 为 true
  //   - 检查 SharedPreferences 标记 → 仍存在
  //   - 但我们无法区分"安装完成"和"取消"
  //   - 用 hasPendingUpdateRestart 验证标记确实存在
  //   - 如果存在：显示对话框让用户选择是否重启（无害）
  //   - 如果用户选择"稍后"：清除标记，继续使用
  // ---------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 如果应用进入后台/暂停状态，且后台备份正在运行，则取消备份
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (AutoBackupService.isRunning) {
        debugPrint('[Application] 应用进入后台，取消正在运行的自动备份');
        AutoBackupService.cancel();
      }
      return;
    }

    if (state != AppLifecycleState.resumed) return;
    if (!isPendingRestartInMemory) return;

    // Check SharedPreferences flag to confirm it's a real update scenario
    // (not a stale in-memory flag from a previous failed install).
    hasPendingUpdateRestart().then((bool hasPrefsFlag) {
      if (!hasPrefsFlag) return; // SharedPreferences flag cleared externally
      if (!mounted) return;

      debugPrint('[Application] Warm resume after APK install detected — '
          'showing restart dialog (Kotlin handler may have failed)');

      // Clear both flags immediately to prevent re-entry
      setPendingRestartInMemory(false);
      clearPendingUpdateRestart();

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.system_update,
                  color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('更新检测'),
            ],
          ),
          content: const Text(
            '检测到应用已更新，建议重启应用以确保稳定性。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // User chose to continue — hope for the best
              },
              child: const Text('稍后重启'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _exitApp();
              },
              child: const Text('立即重启'),
            ),
          ],
        ),
      );
    });
  }

  /// Exits the application (triggers clean cold start on next launch).
  void _exitApp() {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        exit(0);
      }
    } catch (e) {
      debugPrint('[Application] Failed to exit app: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForUpdatesOnStartup() async {
    final notifier = ref.read(updateProvider.notifier);

    // Load persisted pre-release preference before checking
    await notifier.loadAcceptPreRelease();

    // 在 HTTP 请求之前捕获 Navigator context，
    // 确保异步等待后 context 仍然有效。
    final navigatorContext = _navigatorKey.currentContext;

    // 直接请求 GitHub API 检查最新版本
    // silent=false 表示有更新时必须弹窗通知用户
    await notifier.checkForUpdate(silent: false);

    // 如果发现有新版本，弹出更新面板
    if (mounted && navigatorContext != null && navigatorContext.mounted) {
      final state = ref.read(updateProvider);
      if (state.updateAvailable) {
        showDialog(
          context: navigatorContext,
          barrierDismissible: true,
          builder: (context) => const UpdateDialog(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic;
          darkColorScheme = darkDynamic;
        } else {
          // Fallback color schemes if dynamic color is not available
          lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          );
        }

        final colorScheme = themeMode == ThemeMode.light
            ? lightColorScheme
            : themeMode == ThemeMode.dark
                ? darkColorScheme
                : MediaQuery.platformBrightnessOf(context) == Brightness.light
                    ? lightColorScheme
                    : darkColorScheme;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              MaterialApp(
                title: 'Stroom',
                navigatorKey: _navigatorKey,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: colorScheme,
                  pageTransitionsTheme: PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  colorScheme: darkColorScheme,
                  pageTransitionsTheme: PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                ),
                themeMode: themeMode,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('zh', 'CN'),
                  Locale('en', 'US'),
                ],
                locale: const Locale('zh', 'CN'),
                home: const HomePage(),
                routes: {
                  '/home': (context) => const HomePage(),
                  '/chat': (context) => const ChatPage(),
                  '/files': (context) => const FilesPage(),
                  '/settings': (context) => const SettingsPage(),
                },
                debugShowCheckedModeBanner: false,
              ),
              // In-app notification banner overlay
              _InAppBannerOverlay(),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// In-App Notification Banner Overlay
// ============================================================================

/// Overlay widget that displays on top of the MaterialApp when a
/// notification payload is set. Listens to [inAppNotificationProvider].
class _InAppBannerOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(inAppNotificationProvider);
    if (payload == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: InAppNotificationBanner(
        key: ValueKey(payload.taskId),
        payload: payload,
        onDismiss: () {
          ref.read(inAppNotificationProvider.notifier).state = null;
        },
      ),
    );
  }
}
