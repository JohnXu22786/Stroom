import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'application.dart';
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

Future<void> main() async {
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

    runApp(
      const ProviderScope(
        child: Application(),
      ),
    );
  } catch (e, s) {
    // If initialization fails, show an error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '应用启动失败',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('错误: $e'),
                const SizedBox(height: 10),
                Text('堆栈: $s'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
