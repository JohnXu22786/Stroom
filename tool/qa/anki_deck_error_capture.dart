import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

void main() {
  const summary = '''
The Anki collection could not be opened because its local database is unavailable.
Collection path: /safe/fixture/Anki2/User 1/collection.anki2
Database operation: open collection and read deck metadata
SQLite result: SQLITE_CANTOPEN (14)
The file may be locked by another process or the selected profile may not be mounted.
No collection data was changed. Close other Anki sessions, check that the profile is
available, and retry. If the problem continues, preserve this full diagnostic for support.
''';
  final diagnostic = [
    summary,
    ...List.filled(
      18,
      'Diagnostic detail: checked the configured profile path, filesystem permissions, '
      'lock file, database header, journal state, and collection schema.',
    ),
  ].join('\n');

  runApp(
    ProviderScope(
      overrides: [
        ankiDeckListProvider.overrideWith(
          (ref) async => throw StateError(diagnostic),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          cardTheme: const CardThemeData(elevation: 0),
        ),
        home: const AnkiDroidPage(),
      ),
    ),
  );
}
