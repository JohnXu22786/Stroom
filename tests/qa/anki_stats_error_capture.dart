import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        ankiDatabaseProvider.overrideWith(
          (_) async => throw StateError(
            'Anki database failure: ${'detail with context ' * 75}END OF DIAGNOSTIC',
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const AnkiStatsPage(),
      ),
    ),
  );
}
