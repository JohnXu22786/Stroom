
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用主题模式枚举
enum AppThemeMode {
  light,   // 浅色模式
  dark,    // 深色模式
  system,  // 跟随系统
}

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

/// 辅助函数：将AppThemeMode转换为ThemeMode
ThemeMode appThemeModeToThemeMode(AppThemeMode appThemeMode) {
  switch (appThemeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

/// 辅助函数：将ThemeMode转换为AppThemeMode
AppThemeMode themeModeToAppThemeMode(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.light:
      return AppThemeMode.light;
    case ThemeMode.dark:
      return AppThemeMode.dark;
    case ThemeMode.system:
      return AppThemeMode.system;
  }
}
