import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// 主题提供器，管理应用主题模式
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  /// 切换到浅色模式
  void setLight() {
    state = ThemeMode.light;
  }

  /// 切换到深色模式
  void setDark() {
    state = ThemeMode.dark;
  }

  /// 切换到跟随系统模式
  void setSystem() {
    state = ThemeMode.system;
  }

  /// 切换主题模式（循环切换：light -> dark -> system -> light）
  void toggle() {
    switch (state) {
      case ThemeMode.light:
        state = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        state = ThemeMode.system;
        break;
      case ThemeMode.system:
        state = ThemeMode.light;
        break;
    }
  }
}
