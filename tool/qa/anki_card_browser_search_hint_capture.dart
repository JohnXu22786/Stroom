import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/pages/card_browser.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

class _EmptyCardDao implements CardDao {
  @override
  Future<List<anki.Card>> all() async => [];

  @override
  Future<List<anki.Card>> listByDeck(int deckId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final parameters = Uri.base.queryParameters;
  final localeCode = parameters['locale'] ?? 'fr';
  final locale = Locale(localeCode, localeCode == 'en' ? 'US' : 'FR');
  final textScale = double.tryParse(parameters['scale'] ?? '') ?? 1.8;
  final dark = parameters['theme'] == 'dark';

  runApp(
    ProviderScope(
      overrides: [
        ankiCardDaoProvider.overrideWithValue(AsyncData(_EmptyCardDao())),
      ],
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AnkiCardBrowser(),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    html.window.dispatchEvent(html.Event('anki-card-browser-rendered'));
  });
}
