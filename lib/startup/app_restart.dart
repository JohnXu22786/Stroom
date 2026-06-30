import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;

// ====================================================================
// AppRestart — 应用重启工具
// ====================================================================
//
// 提供跨平台的应用重启能力：
// - Desktop (Windows/Mac/Linux): 启动新进程后退出当前进程
// - Mobile (Android/iOS): 退出应用（移动平台无法自动重启）
// - Web: 当前忽略（需要手动刷新页面）
// ====================================================================

/// 跨平台应用重启。
///
/// 在桌面平台会尝试启动一个新的应用进程；在移动平台仅退出应用。
void restartApp() {
  _restartApp();
}

void _restartApp() {
  // Web 平台：dart:io 不可用，直接返回
  if (kIsWeb) {
    debugPrint('[AppRestart] Auto-restart not supported on web');
    return;
  }

  // 移动平台：退出应用（无法自动重启）
  try {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      SystemNavigator.pop();
      return;
    }
  } catch (e) {
    debugPrint('[AppRestart] SystemNavigator.pop failed: $e');
  }

  // 桌面平台：尝试启动新进程再退出
  bool started = false;
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final executable = Platform.resolvedExecutable;
      Process.start(executable, []);
      started = true;
    }
  } catch (e) {
    debugPrint('[AppRestart] Process.start failed: $e');
  }

  // 退出当前进程
  try {
    exit(0);
  } catch (e) {
    debugPrint('[AppRestart] exit failed: $e');
  }

  if (!started) {
    debugPrint('[AppRestart] Could not restart app automatically');
  }
}
