import 'dart:io' show exit, Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/chat_page.dart';
import 'pages/files_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/notification_provider.dart';
import 'services/data_migration_service.dart';
import 'services/notification_service.dart';
import 'widgets/migration_dialog.dart';
import 'widgets/update_dialog.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<Application> {
  /// Global key for the MaterialApp's Navigator, used to show the
  /// update dialog from a context that is INSIDE the navigator.
  ///
  /// This is necessary because [_checkForUpdatesOnStartup] runs from
  /// [initState], whose BuildContext lives ABOVE the MaterialApp's
  /// Navigator. Using [navigatorKey.currentContext] ensures
  /// [showDialog] can find [MaterialLocalizations] and the
  /// [NavigatorState] it needs.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Web端不提供更新功能和数据迁移
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performStartupChecks();
      });
    }
    // Set up in-app notification handler
    NotificationService().onInAppNotification = (payload) {
      if (mounted) {
        ref.read(inAppNotificationProvider.notifier).state = payload;
      }
    };
  }

  /// 执行启动时的检查流程（按顺序）：
  /// 1. 数据格式版本检查与迁移
  /// 2. 应用版本更新检查
  Future<void> _performStartupChecks() async {
    // 第一步：数据格式迁移
    final migrationCompleted = await _performDataMigration();
    if (!migrationCompleted) return;

    // 第二步：检查应用更新
    await _checkForUpdatesOnStartup();
  }

  /// 执行数据格式迁移。
  ///
  /// 如果存储的数据格式版本低于当前版本，弹出不可关闭的迁移对话框，
  /// 执行备份和迁移。迁移完成后自动关闭对话框并退出应用，
  /// 确保所有 provider 和服务以新的数据格式重新初始化。
  ///
  /// 返回 `true` 表示迁移已处理完毕（或无迁移需求），可继续下一步；
  /// 返回 `false` 表示应用需要退出，不应继续。
  Future<bool> _performDataMigration() async {
    try {
      // 先快速检查是否需要迁移（不执行备份和迁移）
      final storedVersion = await DataMigrationService.getStoredFormatVersion();
      if (storedVersion >= DataMigrationService.currentFormatVersion) {
        // 数据格式已是最新，不需要迁移
        return true;
      }

      // 需要迁移：弹出对话框并执行迁移
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) {
        // 没有有效的 context，直接执行静默迁移后退出应用
        await DataMigrationService.checkAndMigrate();
        _exitApp();
        return false;
      }

      // 在对话框内执行迁移
      final shouldExit = await showDialog<bool>(
        context: navigatorContext,
        barrierDismissible: false, // 不可通过点击背景关闭
        builder: (_) => MigrationDialog(
          future: DataMigrationService.checkAndMigrate(),
        ),
      );

      // 如果返回 true，表示需要重启应用
      if (shouldExit == true) {
        _exitApp();
        return false;
      }

      // 迁移出错或无退出信号时，继续启动流程
      return true;
    } catch (e) {
      debugPrint('[Application] Data migration failed: $e');
      // 迁移失败不应阻塞启动，记录日志后继续
      return true;
    }
  }

  /// 安全退出应用。
  void _exitApp() {
    // 移动端使用 SystemNavigator.pop() 退出
    // 桌面端使用 dart:io exit()
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows ||
          Platform.isMacOS ||
          Platform.isLinux) {
        exit(0);
      }
    } catch (e) {
      debugPrint('[Application] Failed to exit app: $e');
    }
  }

  Future<void> _checkForUpdatesOnStartup() async {
    final notifier = ref.read(updateProvider.notifier);

    // 在 HTTP 请求之前捕获 Navigator context，
    // 确保异步等待后 context 仍然有效。
    final navigatorContext = _navigatorKey.currentContext;

    // 直接请求 GitHub API 检查最新版本
    // silent=true 表示启动时不把网络错误暴露给用户
    await notifier.checkForUpdate(silent: true);

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

        return Stack(
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
                '/camera': (context) => const CameraPage(),
                '/chat': (context) => const ChatPage(),
                '/files': (context) => const FilesPage(),
                '/settings': (context) => const SettingsPage(),
              },
              debugShowCheckedModeBanner: false,
            ),
            // In-app notification banner overlay
            _InAppBannerOverlay(),
          ],
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
