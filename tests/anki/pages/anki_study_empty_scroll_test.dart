import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart' as model;
import 'package:stroom/anki/models/deck.dart';
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
}
