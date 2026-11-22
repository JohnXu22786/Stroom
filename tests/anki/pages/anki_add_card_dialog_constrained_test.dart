import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/card.dart' as model;
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/model.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/anki_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

class _StubAnkiActions extends AnkiActions {
  _StubAnkiActions(super.ref, this.calls);

  final _CallCapture calls;

  @override
  Future<model.Card?> getNextCard(int did) async => null;

  @override
  Future<int> addCard(
    int did,
    String front,
    String back, {
    int? modelId,
    String tags = '',
  }) async {
    calls.modelId = modelId;
    calls.front = front;
    calls.back = back;
    calls.tags = tags;
    return 1;
  }
}

class _CallCapture {
  int? modelId;
  String? front;
  String? back;
  String? tags;
}

void main() {
  Future<_CallCapture> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final calls = _CallCapture();
    final container = ProviderContainer(
      overrides: [
        ankiDeckListProvider.overrideWith(
          (ref) async => [Deck(id: 1, name: 'Deck')],
        ),
        ankiDeckStatsProvider.overrideWith(
          (ref, deckId) async => DeckStats(deckName: 'Deck'),
        ),
        ankiModelListProvider.overrideWith(
          (ref) async => [
            Notetype(id: 1, name: 'Basic'),
            Notetype(id: 2, name: 'Cloze'),
          ],
        ),
        ankiActionsProvider.overrideWith((ref) => _StubAnkiActions(ref, calls)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ankiModelListProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('de'),
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
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karte hinzufügen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return calls;
  }

  testWidgets('bounded add dialog keeps controls usable at narrow width', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Vorderseite (Frage)'), findsOneWidget);
    expect(find.text('Rückseite / Zusatz'), findsOneWidget);
    expect(
      find.text('Schlagwörter (durch Leerzeichen getrennt)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard inset allows editing and still submitting fields', (
    tester,
  ) async {
    final calls = await openDialog(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cloze').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Text (Löschungen mit {{c1::答案}} markieren)'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        ConstrainedText,
        'Text (Löschungen mit {{c1::答案}} markieren)',
      ),
      findsOneWidget,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Question');
    await tester.enterText(fields.at(1), 'Answer');
    await tester.enterText(fields.at(2), 'math physics');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(calls.front, 'Question');
    expect(calls.back, 'Answer');
    expect(calls.tags, 'math physics');
    expect(calls.modelId, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
