import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/chat_page.dart';
import 'pages/files_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'utils/app_version.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => _ApplicationState();
}

class _ApplicationState extends ConsumerState<Application> {
  @override
  void initState() {
    super.initState();
    // Web端不提供更新功能
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdatesOnStartup();
      });
    }
  }

  Future<void> _checkForUpdatesOnStartup() async {
    final notifier = ref.read(updateProvider.notifier);
    final pendingUpdate = await notifier.getPendingUpdate();
    if (pendingUpdate != null) {
      if (mounted) {
        _showUpdateDialog(
          latestVersion: pendingUpdate['latest_version'] as String? ?? '',
          mandatory: pendingUpdate['mandatory'] as bool? ?? false,
          releaseNotes: pendingUpdate['release_notes'] as String? ?? '',
          downloadUrl: pendingUpdate['download_url'] as String? ?? '',
        );
      }
    }
    await notifier.checkForUpdate(silent: true);
  }

  void _showUpdateDialog({
    required String latestVersion,
    required bool mandatory,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                mandatory ? Icons.warning_amber_rounded : Icons.system_update,
                color: mandatory ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(mandatory ? '强制更新' : '发现新版本'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('最新版本: $latestVersion'),
                Text('当前版本: $appVersion'),
                if (mandatory) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '此版本为强制更新，请立即升级以继续使用。',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('更新内容:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(releaseNotes),
                ],
              ],
            ),
          ),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () {
                  ref.read(updateProvider.notifier).skipVersion(latestVersion);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('跳过此版本'),
              ),
            if (!mandatory)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('稍后提醒'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openUrl(downloadUrl);
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

        return MaterialApp(
          title: 'Stroom',
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
        );
      },
    );
  }
}
