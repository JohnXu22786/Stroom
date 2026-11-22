import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_sync_page.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        ankiSyncSecureStorageProvider.overrideWith(
          (_) => const _SafeLocalSecureStorage(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
          cardTheme: const CardThemeData(elevation: 0),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
          cardTheme: const CardThemeData(elevation: 0),
        ),
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const AnkiSyncSettingsPage(),
      ),
    ),
  );
}

class _SafeLocalSecureStorage extends FlutterSecureStorage {
  const _SafeLocalSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;
}
