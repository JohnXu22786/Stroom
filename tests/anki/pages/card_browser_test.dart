import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/note_dao.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/pages/card_browser.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';

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

class _MutableCardDao implements CardDao {
  List<anki.Card> cards;
  int queries = 0;
  _MutableCardDao(this.cards);

  @override
  Future<List<anki.Card>> all() async {
    queries++;
    return cards;
  }

  @override
  Future<List<anki.Card>> listByDeck(int deckId) async {
    queries++;
    return cards;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedRemoveNoteActions extends AnkiActions {
  final Completer<void> deletion = Completer<void>();
  final VoidCallback onDeleted;

  _DelayedRemoveNoteActions(super.ref, this.onDeleted);

  @override
  Future<void> removeNote(int nid) async {
    await deletion.future;
    onDeleted();
  }
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

class _ThrowingNoteDao implements NoteDao {
  final String message;
  _ThrowingNoteDao(this.message);

  @override
  Future<Note?> get(int id) async => throw StateError(message);

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

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

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

  testWidgets('reloads cards only after note deletion completes', (
    tester,
  ) async {
    final card = anki.Card(id: 1234, note_id: 1, deck_id: 1);
    final cardDao = _MutableCardDao([card]);
    late _DelayedRemoveNoteActions actions;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(AsyncData(cardDao)),
          ankiNoteDaoProvider.overrideWithValue(
            AsyncData(
              _StaticNoteDao(Note(id: 1, notetype_id: 1, fields: ['Front'])),
            ),
          ),
          ankiActionsProvider.overrideWith((ref) {
            actions = _DelayedRemoveNoteActions(ref, () => cardDao.cards = []);
            return actions;
          }),
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
    expect(find.byType(ListTile), findsOneWidget);
    expect(cardDao.queries, 1);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(cardDao.queries, 1);
    expect(find.byType(ListTile), findsOneWidget);

    actions.deletion.complete();
    await tester.pumpAndSettle();

    expect(cardDao.queries, 2);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('No cards'), findsOneWidget);
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

  // Unit owner: vertical_anki_card_error.
  // Functional suite mapping: component-integrations; the CI test owner is component-integrations.
  testWidgets(
    'keeps a long note-load diagnostic fully reachable in a narrow row',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final diagnostic = List.filled(
        24,
        'SQLiteException: note query failed near the stored field value',
      ).join(' — ');
      final card = anki.Card(id: 1234, note_id: 1, deck_id: 1);

      for (final (locale, textScale, isDark) in [
        (const Locale('fr', 'FR'), 1.0, false),
        (const Locale('zh', 'CN'), 2.0, false),
        (const Locale('en', 'US'), 1.5, true),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ankiCardDaoProvider.overrideWithValue(
                AsyncData(_StaticCardDao([card])),
              ),
              ankiNoteDaoProvider
                  .overrideWith((_) async => _ThrowingNoteDao(diagnostic)),
            ],
            child: MaterialApp(
              locale: locale,
              theme: isDark
                  ? ThemeData.dark(useMaterial3: true)
                  : ThemeData.light(useMaterial3: true),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
              home: const AnkiCardBrowser(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final diagnosticFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data?.contains(diagnostic) == true,
        );
        final errorText = tester.widget<Text>(diagnosticFinder);
        expect(errorText.maxLines, isNull);
        expect(errorText.overflow, isNull);
        expect(errorText.data, contains(diagnostic));
        final queueRect = tester.getRect(find.byIcon(Icons.fiber_new));
        final deleteRect = tester.getRect(find.byIcon(Icons.delete_outline));
        expect(queueRect.top, greaterThanOrEqualTo(0));
        expect(queueRect.bottom, lessThanOrEqualTo(640));
        expect(deleteRect.top, greaterThanOrEqualTo(0));
        expect(deleteRect.bottom, lessThanOrEqualTo(640));

        if (locale == const Locale('fr', 'FR')) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              '../../../docs/ui-constrained-text-qa/vertical-anki-card-error/card-error-fr-320x640-scale1-light.png',
            ),
          );
        }

        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable).last);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await scrollable.position.ensureVisible(
          tester.renderObject(diagnosticFinder),
          alignment: 1,
        );
        await tester.pumpAndSettle();
        expect(diagnosticFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
        scrollable.position.jumpTo(0);
        await tester.pumpAndSettle();
      }
    },
  );

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

  testWidgets('reveals the full French search hint at narrow expanded scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const hint = 'Rechercher des cartes…';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(AsyncData(_EmptyCardDao())),
        ],
        child: MaterialApp(
          locale: const Locale('fr', 'FR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
            ),
            child: child!,
          ),
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pump();

    final hintFinder = find.text(hint);
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(ConstrainedText),
      ),
      findsOneWidget,
    );
    expect(hintFinder, findsOneWidget);
    final initialLeft = tester.getTopLeft(hintFinder).dx;
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(hintFinder).dx, lessThan(initialLeft - 10));
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '123');
    await tester.pump();
    final editor = tester.widget<EditableText>(find.byType(EditableText));
    expect(editor.controller.text, '123');
    expect(editor.controller.selection.extentOffset, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the fitting English search hint stationary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const hint = 'Search cards...';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWithValue(AsyncData(_EmptyCardDao())),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );
    await tester.pump();

    final hintFinder = find.text(hint);
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(ConstrainedText),
      ),
      findsOneWidget,
    );
    expect(hintFinder, findsOneWidget);
    final initialLeft = tester.getTopLeft(hintFinder).dx;
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getTopLeft(hintFinder).dx, initialLeft);
    expect(tester.takeException(), isNull);
  });
}
