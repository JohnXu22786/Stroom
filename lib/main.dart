import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
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
