import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/note_dao.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/models/note.dart';
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

class _StaticCardDao implements CardDao {
  final List<anki.Card> cards;
  _StaticCardDao(this.cards);

  @override
  Future<List<anki.Card>> all() async => cards;

  @override
  Future<List<anki.Card>> listByDeck(int deckId) async => cards;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingCardDao implements CardDao {
  @override
  Future<List<anki.Card>> all() async => throw StateError('query failed');

  @override
  Future<List<anki.Card>> listByDeck(int deckId) async =>
      throw StateError('query failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticNoteDao implements NoteDao {
  final Note note;
  _StaticNoteDao(this.note);

  @override
  Future<Note?> get(int id) async => note.id == id ? note : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingNoteDao implements NoteDao {
  @override
  Future<Note?> get(int id) async => throw StateError('note query failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'localizes browser title, search hint, and empty state in English and Chinese',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('zh')]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ankiCardDaoProvider.overrideWithValue(AsyncData(_EmptyCardDao())),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AnkiCardBrowser(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expected = locale.languageCode == 'en'
            ? ['Browse cards', 'Search cards...', 'No cards']
            : ['浏览卡片', '搜索卡片...', '无卡片'];
        for (final label in expected) {
          expect(find.text(label), findsOneWidget);
        }
      }
    },
  );

  testWidgets('uses compact radius for the search field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWith((_) async {
            throw StateError('Card loading is not needed to inspect the field');
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('waits for a delayed card DAO before loading cards', (
    tester,
  ) async {
    final daoCompleter = Completer<CardDao>();
    final matchingCard = anki.Card(id: 1234, note_id: 1, deck_id: 1);
    final otherCard = anki.Card(id: 5678, note_id: 2, deck_id: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWith((_) => daoCompleter.future),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');

    daoCompleter.complete(_StaticCardDao([matchingCard, otherCard]));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('waits for the note DAO before rendering card content', (
    tester,
  ) async {
    final noteDaoCompleter = Completer<NoteDao>();
    final card = anki.Card(id: 1234, note_id: 1, deck_id: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(
            AsyncData(_StaticCardDao([card])),
          ),
          ankiNoteDaoProvider.overrideWith((_) => noteDaoCompleter.future),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    noteDaoCompleter.complete(
      _StaticNoteDao(Note(id: 1, notetype_id: 1, fields: ['Card front'])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card front'), findsOneWidget);
  });

  testWidgets('shows a localized error when loading a card note fails', (
    tester,
  ) async {
    final card = anki.Card(id: 1234, note_id: 1, deck_id: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(
            AsyncData(_StaticCardDao([card])),
          ),
          ankiNoteDaoProvider.overrideWithValue(AsyncData(_FailingNoteDao())),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to load cards: Bad state: note query failed'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a visible error when loading the card query fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(AsyncData(_FailingCardDao())),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to load cards: Bad state: query failed'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
