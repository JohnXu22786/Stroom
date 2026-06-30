import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'pages/home_page.dart';
import 'pages/chat_page.dart';
import 'pages/files_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
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
    // Web端不提供更新功能
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdatesOnStartup();
      });
    }
    // Set up in-app notification handler
    NotificationService().onInAppNotification = (payload) {
      if (mounted) {
        ref.read(inAppNotificationProvider.notifier).state = payload;
      }
    };
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
