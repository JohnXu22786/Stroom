import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

void main() {
  final deckName = 'Long safe fixture deck name ' * 4;
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 2;
  runApp(
    ProviderScope(
      overrides: [
        ankiDeckListProvider.overrideWith(
          (ref) async => [Deck(id: 1, name: deckName)],
        ),
        ankiDeckStatsProvider.overrideWith(
          (ref, deckId) async => DeckStats(deckName: deckName),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AnkiDroidPage(),
      ),
    ),
  );
}
