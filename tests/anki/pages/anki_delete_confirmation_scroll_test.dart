import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';

class _RecordingAnkiActions extends AnkiActions {
  _RecordingAnkiActions(super.ref);

  int removeCalls = 0;

  @override
  Future<void> removeDeck(int did) async {
    removeCalls++;
  }
}

void main() {
  Future<void> openConfirmation(
    WidgetTester tester, {
    required String deckName,
    Locale locale = const Locale('en', 'US'),
    double textScale = 1,
    void Function(_RecordingAnkiActions actions)? onActionsCreated,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late _RecordingAnkiActions actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckListProvider.overrideWith(
            (ref) async => [Deck(id: 1, name: deckName)],
          ),
          ankiDeckStatsProvider.overrideWith(
            (ref, deckId) async => DeckStats(deckName: deckName),
          ),
          ankiActionsProvider.overrideWith((ref) {
            actions = _RecordingAnkiActions(ref);
            onActionsCreated?.call(actions);
            return actions;
          }),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiDroidPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AnkiDroidPage)),
    )!;
    await tester.tap(find.text(l10n.ankiDeleteAction));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'long delete confirmation stays reachable at narrow width and large text',
    (tester) async {
      final deckName = 'Deck name with a long user supplied value ' * 4;
      await openConfirmation(tester, deckName: deckName, textScale: 2);

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(deckName),
        ),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AnkiDroidPage)),
      )!;
      expect(find.text(l10n.actionCancel), findsOneWidget);
      expect(find.text(l10n.actionDelete), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'confirming a long name invokes delete only for the selected deck',
    (tester) async {
      final deckName = 'Long safe fixture deck name ' * 4;
      late _RecordingAnkiActions actions;
      await openConfirmation(
        tester,
        deckName: deckName,
        textScale: 2,
        onActionsCreated: (value) => actions = value,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AnkiDroidPage)),
      )!;
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();
      expect(actions.removeCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('localized short confirmation keeps its content and actions', (
    tester,
  ) async {
    const deckName = 'Kurzes Deck';
    await openConfirmation(
      tester,
      deckName: deckName,
      locale: const Locale('de'),
    );

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(deckName),
      ),
      findsOneWidget,
    );
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
