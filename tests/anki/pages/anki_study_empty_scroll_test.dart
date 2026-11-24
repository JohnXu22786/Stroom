import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/note_dao.dart';
import 'package:stroom/anki/models/card.dart' as model;
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

class _StubAnkiActions extends AnkiActions {
  _StubAnkiActions(super.ref, this.cards);

  final List<model.Card?> cards;

  @override
  Future<model.Card?> getNextCard(int did) async =>
      cards.isEmpty ? null : cards.removeAt(0);

  @override
  Future<void> answerCard(int cardId, int rating, {int duration = 0}) async {}
}

class _DelayedAnswerAnkiActions extends AnkiActions {
  _DelayedAnswerAnkiActions(super.ref, this.cards);

  final List<model.Card?> cards;
  int failNextCardLoads = 0;
  final answerCompletions = <Completer<void>>[];
  final ratings = <int>[];
  final savedRatings = <(int cardId, int rating)>[];
  int getNextCardCalls = 0;

  @override
  Future<model.Card?> getNextCard(int did) async {
    getNextCardCalls++;
    if (failNextCardLoads > 0) {
      failNextCardLoads--;
      throw StateError('next card unavailable');
    }
    return cards.removeAt(0);
  }

  @override
  Future<void> answerCard(int cardId, int rating, {int duration = 0}) {
    ratings.add(rating);
    final completion = Completer<void>();
    answerCompletions.add(completion);
    return completion.future;
  }

  void persistFirstAnswerThenFail() {
    savedRatings.add((10, ratings.first));
    answerCompletions.first.completeError(StateError('answer response lost'));
  }
}

class _StubNoteDao implements NoteDao {
  _StubNoteDao(this.notes);

  final Map<int, Note> notes;

  @override
  Future<Note?> get(int id) async => notes[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> showStudyPage(
    WidgetTester tester, {
    required double textScale,
    List<model.Card?> cards = const [],
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckByIdProvider.overrideWith(
            (ref, deckId) async => Deck(id: deckId, name: 'Español'),
          ),
          ankiActionsProvider.overrideWith(
            (ref) => _StubAnkiActions(ref, [...cards]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiStudyPage(deckId: 1),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty study fits at 320x640 with normal text scale', (
    tester,
  ) async {
    await showStudyPage(tester, textScale: 1);

    final backButton = find.widgetWithText(FilledButton, 'Atrás');
    expect(backButton, findsOneWidget);
    expect(tester.getRect(backButton).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty study scrolls to its back action at 1.8x text scale', (
    tester,
  ) async {
    await showStudyPage(tester, textScale: 1.8);

    final backButton = find.widgetWithText(FilledButton, 'Atrás');
    expect(backButton, findsOneWidget);
    await tester.ensureVisible(backButton);
    await tester.pumpAndSettle();
    expect(tester.getRect(backButton).bottom, lessThanOrEqualTo(640));
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated study still reveals the answer at 1.8x scale', (
    tester,
  ) async {
    await showStudyPage(
      tester,
      textScale: 1.8,
      cards: [model.Card(note_id: 1, deck_id: 1)],
    );

    expect(find.text('Mostrar respuesta'), findsOneWidget);
    await tester.tap(find.text('Mostrar respuesta'));
    await tester.pumpAndSettle();
    expect(find.text('De nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only one rating is saved while an answer is pending', (
    tester,
  ) async {
    final firstCard = model.Card(id: 10, note_id: 1, deck_id: 1);
    final nextCard = model.Card(id: 11, note_id: 2, deck_id: 1);
    final finalCard = model.Card(id: 12, note_id: 3, deck_id: 1);
    late _DelayedAnswerAnkiActions actions;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckByIdProvider.overrideWith(
            (ref, deckId) async => Deck(id: deckId, name: 'Español'),
          ),
          ankiActionsProvider.overrideWith((ref) {
            actions = _DelayedAnswerAnkiActions(ref, [
              firstCard,
              nextCard,
              finalCard,
            ]);
            return actions;
          }),
          ankiNoteDaoProvider.overrideWith(
            (ref) async => _StubNoteDao({
              1: Note(id: 1, notetype_id: 1, fields: ['Primera', 'Uno']),
              2: Note(id: 2, notetype_id: 1, fields: ['Siguiente', 'Dos']),
              3: Note(id: 3, notetype_id: 1, fields: ['Última', 'Tres']),
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiStudyPage(deckId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar respuesta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('De nuevo'));
    await tester.pump();
    await tester.tap(find.text('Duro'), warnIfMissed: false);
    await tester.pump();

    expect(actions.ratings, [1]);
    expect(actions.getNextCardCalls, 1);

    actions.persistFirstAnswerThenFail();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(actions.ratings, [1]);
    expect(actions.savedRatings, [(10, 1)]);
    expect(actions.getNextCardCalls, 2);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Mostrar respuesta'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    actions.failNextCardLoads = 1;
    await tester.tap(find.text('Mostrar respuesta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bien'));
    actions.answerCompletions.last.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Siguiente'), findsOneWidget);
    expect(actions.ratings, [1, 3]);
    final retryLabel = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    )!
        .actionRetry;
    await tester.tap(find.text(retryLabel));
    await tester.pumpAndSettle();

    expect(find.text('Última'), findsOneWidget);
    expect(actions.getNextCardCalls, 4);
    expect(tester.takeException(), isNull);
  });
}
