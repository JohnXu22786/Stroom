import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/gallery_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';

class Application extends ConsumerWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                : Theme.of(context).brightness == Brightness.light
                    ? lightColorScheme
                    : darkColorScheme;

        return MaterialApp(
          title: 'Stroom',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            pageTransitionsTheme: const PageTransitionsTheme(
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
            '/gallery': (context) => const GalleryPage(),
            '/settings': (context) => const SettingsPage(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
