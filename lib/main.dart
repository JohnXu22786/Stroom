import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'providers/tts_config.dart';
import 'providers/tts_state_provider.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    registerBuiltinProviders();

    // 加载用户自定义供应商
    final container = ProviderContainer();
    await container.read(customProvidersProvider.notifier).loadCustomProviders();
    container.dispose();

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
