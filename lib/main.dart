import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/app_log_service.dart';
import 'services/asr_retry_storage.dart';
import 'services/bundled_asset_licenses.dart';
import 'services/browser_profile_service.dart';
import 'services/video_player_init.dart';

import 'startup/startup_app.dart';
import 'providers/tts_config.dart';
import 'providers/provider_config.dart';
import 'catcatch/providers/catcatch_provider.dart';
import 'providers/task_provider.dart';
import 'providers/background_task_provider.dart';
import 'providers/notification_provider.dart';
import 'pages/unified_task_list/task_session_tracker.dart';
import 'task_flow/providers/task_flow_provider.dart';
import 'task_flow/providers/task_flow_execution_provider.dart';
import 'task_flow/services/task_flow_execution_service.dart';
import 'services/background_service.dart';
import 'services/desktop_app_service.dart';
import 'services/notification_service.dart';
import 'providers/locale_provider.dart';

final asrRetryAudioStoreProvider =
    Provider<AsrRetryAudioStore>((ref) => AsrRetryAudioStore());

/// Restore flow ownership independently so startup can leave child controls
/// locked if the execution file cannot be trusted.
final taskFlowExecutionRestorationProvider = FutureProvider<bool>((ref) async {
  var flowExecutionsRestored = false;
  try {
    flowExecutionsRestored = await ref
        .read(taskFlowExecutionsProvider.notifier)
        .restoreFromPersistence();
  } catch (error, stackTrace) {
    debugPrint('Failed to restore task flow executions: $error\n$stackTrace');
  }
  ref.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
      flowExecutionsRestored
          ? FlowExecutionRestoreStatus.ready
          : FlowExecutionRestoreStatus.failed;
  return flowExecutionsRestored;
});

/// 初始化 ProviderScope 的 overrides
final catcatchStartupProvider = FutureProvider<void>((ref) async {
  // Task providers can publish restored children before flow executions load.
  // Yield once so Riverpod permits updating another provider, then lock child
  // controls before starting any task restoration.
  await Future<void>.value();
  ref.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
      FlowExecutionRestoreStatus.restoring;
  await ref.read(catcatchTasksProvider.notifier).restoreUnfinishedTasks();
  await ref.read(taskListProvider.notifier).restoreFromPersistence();
  final backgroundNotifier = ref.read(backgroundTasksProvider.notifier);
  await backgroundNotifier.restoreFromPersistence();
  final retryAudioStore = ref.read(asrRetryAudioStoreProvider);
  Future<void> pruneRetryAudio() async {
    await retryAudioStore.prune(
      () => backgroundNotifier.retryAudioReferencedIds,
    );
  }

  if (backgroundNotifier.retryAudioCleanupSafe) {
    try {
      await pruneRetryAudio();
    } catch (error, stackTrace) {
      debugPrint(
        '[Startup] ASR retry audio cleanup failed: $error\n$stackTrace',
      );
    }
    for (final task in ref.read(backgroundTasksProvider)) {
      if (task.type == BackgroundTaskType.asr &&
          AsrRetryAudioStore.referencedIds(task.retryData).isNotEmpty) {
        backgroundNotifier.registerTaskCleanup(task.id, pruneRetryAudio);
      }
    }
  }
  await ref.read(taskFlowListProvider.notifier).restoreFromPersistence();
  final flowExecutionsRestored =
      await ref.read(taskFlowExecutionRestorationProvider.future);
  ref.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
      flowExecutionsRestored
          ? FlowExecutionRestoreStatus.ready
          : FlowExecutionRestoreStatus.failed;
  if (flowExecutionsRestored) {
    await ref.read(taskFlowExecutionServiceProvider).restorePendingExecutions();
  }
  final lastRead = await loadTaskListLastRead();
  ref.read(taskListLastReadProvider.notifier).state = lastRead;
  // 加载通知设置
  await ref.read(notificationSettingsProvider.notifier).load();
  // 记录冷启动（仅完全退出后重新启动算一次）
  final launchTimestamps = await recordAppLaunch();
  ref.read(appLaunchTimestampsProvider.notifier).state = launchTimestamps;
});

/// 全局错误处理器：捕获所有未处理的异常，打印日志但不闪退。
///
/// 在 release 模式下，使用 ErrorWidget.builder 显示友好提示；
/// 在 debug 模式下，保留完整错误信息以便开发调试。
void _initGlobalErrorHandling() {
  // 1. 捕获 Flutter 框架层的错误（build、layout、paint 等）
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[GlobalError] FlutterError: ${details.exception}');
    debugPrint('[GlobalError] Stack: ${details.stack}');
    if (details.context != null) {
      debugPrint('[GlobalError] Context: ${details.context}');
    }
  };

  // 2. 替换默认的红色错误页为安全降级组件
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final strings = appLocalizationsForLocale(null);
    if (kReleaseMode) {
      // 生产环境：显示友好提示，不暴露详细信息
      return Material(
        color: Color(0xFF1E1E2E),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                SizedBox(height: 16),
                Text(
                  strings.renderErrorTitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  strings.renderErrorRestartMessage,
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 开发环境：保留完整错误信息
    return Material(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.renderErrorDebugTitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '${details.exception}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // 3. 捕获平台层错误（原生代码崩溃等）
  if (!kIsWeb) {
    try {
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('[GlobalError] PlatformDispatcher error: $error');
        debugPrint('[GlobalError] Stack: $stack');
        return true; // 已处理，不崩溃
      };
    } catch (_) {
      // PlatformDispatcher 在某些平台上不可用，忽略
    }
  }
}

Widget _buildBootstrapLoadingScreen() {
  return const MaterialApp(
    home: Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF89B4FA),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  // 初始化全局错误处理（必须在 runApp 之前）
  _initGlobalErrorHandling();

  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        // 桌面端：窗口管理器必须在 Flutter 首帧前拦截关闭事件。
        // 在它完成后立即显示轻量加载页，再继续其余启动初始化。
        if (DesktopAppService.isDesktopPlatform) {
          await DesktopAppService.instance.initialize();
        }
        runApp(_buildBootstrapLoadingScreen());
        registerBundledAssetLicenses();
        await BrowserProfileService.applyPendingAction();
        await AppLogService.info('App', '应用启动: Stroom');
        registerVideoPlayer();
        // 桌面端同样初始化通知服务：窗口最小化/关闭后任务完成
        // 通知需要走系统通知（in-app 横幅不可见）。
        // initialize() 内部自带错误保护，失败不会阻塞启动。
        if (DesktopAppService.isDesktopPlatform) {
          await NotificationService().initialize();
        }
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          // 先初始化通知服务（创建通知渠道），再初始化后台服务
          await NotificationService().initialize();
          await initializeBackgroundService();
          // 冷启动时恢复之前运行的后台服务（进程被杀后自动恢复）
          await restoreBackgroundServiceOnColdStart();
        }
        registerBuiltinProviders();
        registerBuiltinProviderTypes();

        // 使用 StartupApp 作为入口，它会在启动页面完成后切换到 Application
        runApp(const ProviderScope(child: StartupApp()));
      } catch (e, s) {
        // If initialization fails, show an error screen
        debugPrint('[GlobalError] App initialization failed: $e\n$s');
        final strings = appLocalizationsForLocale(null);
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      strings.startupErrorTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(strings.startupErrorDetails('$e')),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    },
    (Object error, StackTrace stack) {
      // 4. 捕获 runZonedGuarded 内的所有未捕获异步异常
      debugPrint('[GlobalError] Unhandled async error: $error');
      debugPrint('[GlobalError] Stack: $stack');
    },
  );
}
