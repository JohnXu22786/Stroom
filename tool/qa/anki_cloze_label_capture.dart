import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/card.dart' as model;
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/model.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

void main() => runApp(
  ProviderScope(
    overrides: [
      ankiDeckListProvider.overrideWith(
        (ref) async => [Deck(id: 1, name: 'Fixture deck')],
      ),
      ankiDeckStatsProvider.overrideWith(
        (ref, deckId) async => DeckStats(deckName: 'Fixture deck'),
      ),
      ankiModelListProvider.overrideWith(
        (ref) async => [
          Notetype(id: 1, name: 'Basic'),
          Notetype(id: 2, name: 'Cloze'),
        ],
      ),
      ankiActionsProvider.overrideWith(_FixtureAnkiActions.new),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
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
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(ankiModelListProvider);
          return const AnkiDroidPage();
        },
      ),
      builder: (context, child) {
        final scale =
            double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
    ),
  ),
);

class _FixtureAnkiActions extends AnkiActions {
  _FixtureAnkiActions(super.ref);

  @override
  Future<model.Card?> getNextCard(int did) async => null;
}
