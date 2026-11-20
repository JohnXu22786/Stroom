import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/card.dart' as model;
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

class _StubAnkiActions extends AnkiActions {
  _StubAnkiActions(super.ref);

  @override
  Future<model.Card?> getNextCard(int did) async => null;
}

void main() {
  testWidgets('keeps long deck statistics within a narrow card at 1.8x scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    const deckName = 'A very long deck name for a narrow screen';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckListProvider.overrideWith(
            (ref) async => [Deck(id: 1, name: deckName)],
          ),
          ankiDeckStatsProvider.overrideWith(
            (ref, deckId) async => DeckStats(
              deckName: deckName,
              newCount: 123456,
              learningCount: 987654,
              reviewCount: 456789,
            ),
          ),
          ankiDeckByIdProvider.overrideWith(
            (ref, deckId) async => Deck(id: deckId, name: deckName),
          ),
          ankiActionsProvider.overrideWith(_StubAnkiActions.new),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiDroidPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('123456'), findsOneWidget);
    expect(find.text('987654'), findsOneWidget);
    expect(find.text('456789'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Aprendiendo'), findsOneWidget);
    expect(find.text('Revisar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deck tap opens a bounded study title and keeps toolbar action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    const deckName = 'A very long deck name for a narrow screen';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckListProvider.overrideWith(
            (ref) async => [Deck(id: 1, name: deckName)],
          ),
          ankiDeckStatsProvider.overrideWith(
            (ref, deckId) async => DeckStats(deckName: deckName),
          ),
          ankiDeckByIdProvider.overrideWith(
            (ref, deckId) async => Deck(id: deckId, name: deckName),
          ),
          ankiActionsProvider.overrideWith(_StubAnkiActions.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiDroidPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(deckName).first);
    await tester.pumpAndSettle();

    expect(find.text(deckName), findsOneWidget);
    expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short statistics remain compact in a wide layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckListProvider.overrideWith(
            (ref) async => [Deck(id: 1, name: 'Deck')],
          ),
          ankiDeckStatsProvider.overrideWith(
            (ref, deckId) async => DeckStats(
              deckName: 'Deck',
              newCount: 1,
              learningCount: 2,
              reviewCount: 3,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiDroidPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final counts = ['1', '2', '3'];
    final chipContainers = counts.map((count) {
      final countText = find.text(count);
      expect(countText, findsOneWidget);
      final ancestors = find.ancestor(
        of: countText,
        matching: find.byType(Container),
      );
      return ancestors.first;
    }).toList();
    final chipWidths = chipContainers
        .map((chip) => tester.getSize(chip).width)
        .toList();
    final countLefts = counts
        .map((count) => tester.getTopLeft(find.text(count)).dx)
        .toList();

    expect(chipWidths, everyElement(lessThan(150)));
    expect(countLefts, orderedEquals([...countLefts]..sort()));
    expect(tester.takeException(), isNull);
  });
}
