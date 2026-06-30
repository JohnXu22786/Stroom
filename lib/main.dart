import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, FlutterError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'startup/startup_app.dart';
import 'providers/tts_config.dart';
import 'providers/provider_config.dart';
import 'catcatch/providers/catcatch_provider.dart';
import 'providers/task_provider.dart';
import 'providers/background_task_provider.dart';
import 'providers/notification_provider.dart';
import 'pages/unified_task_list_page.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';

/// 初始化 ProviderScope 的 overrides
final catcatchStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(catcatchTasksProvider.notifier).restoreUnfinishedTasks();
  await ref.read(taskListProvider.notifier).restoreFromPersistence();
  await ref.read(backgroundTasksProvider.notifier).restoreFromPersistence();
  final lastRead = await loadTaskListLastRead();
  ref.read(taskListLastReadProvider.notifier).state = lastRead;
  // 加载通知设置
  await ref.read(notificationSettingsProvider.notifier).load();
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
    if (kReleaseMode) {
      // 生产环境：显示友好提示，不暴露详细信息
      return const Material(
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
                  '界面渲染异常',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '请尝试重启应用。',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
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
                const Text(
                  '界面渲染异常（Debug 模式）',
                  style: TextStyle(
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

Future<void> main() async {
  // 初始化全局错误处理（必须在 runApp 之前）
  _initGlobalErrorHandling();

  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        MediaKit.ensureInitialized();
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          await initializeBackgroundService();
          // 初始化通知服务
          await NotificationService().initialize();
        }
        registerBuiltinProviders();
        registerBuiltinProviderTypes();

        // 使用 StartupApp 作为入口，它会在启动页面完成后切换到 Application
        runApp(const ProviderScope(child: StartupApp()));
      } catch (e, s) {
        // If initialization fails, show an error screen
        debugPrint('[GlobalError] App initialization failed: $e\n$s');
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '应用启动失败',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('错误: $e'),
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
