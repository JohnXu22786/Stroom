import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/assistant_selection_page.dart';

void main() {
  final localeName = Uri.base.queryParameters['locale'] ?? 'de';
  final locale = localeName == 'en' ? const Locale('en') : const Locale('de');
  final dark = Uri.base.queryParameters['theme'] == 'dark';

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const AssistantSelectionPage(),
      ),
    ),
  );
}
