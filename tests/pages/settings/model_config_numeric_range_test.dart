import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _TestProviderEntriesNotifier extends ProviderEntriesNotifier {
  _TestProviderEntriesNotifier() : super() {
    state = ProviderEntriesState(
      entries: [ProviderEntry(id: 'audit', name: 'Test provider')],
    );
  }
}

void main() {
  Future<void> pumpConfigPage(
    WidgetTester tester, {
    void Function(ModelConfig?)? onSaved,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => _TestProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<ModelConfig>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModelConfigPage(
                          entryId: 'audit',
                          configIndex: -1,
                          modelIndex: -1,
                          initialModel: ModelConfig(
                            name: 'Test model',
                            modelId: 'test-model',
                            maxWordsPerRequest: 250,
                          ),
                        ),
                      ),
                    );
                    onSaved?.call(result);
                  },
                  child: const Text('Open config'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open config'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final context = tester.element(find.byType(ModelConfigPage));
    await tester
        .tap(find.text(AppLocalizations.of(context)!.mermaidSaveButton));
    await tester.pumpAndSettle();
  }

  testWidgets('malformed range is rejected without saving', (tester) async {
    await pumpConfigPage(tester);

    await tester.enterText(find.byType(TextField).at(2), 'invalid');
    await tester.enterText(find.byType(TextField).at(3), '1.5');
    await tapSave(tester);

    expect(find.byType(ModelConfigPage), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('reversed range is rejected without saving', (tester) async {
    await pumpConfigPage(tester);

    await tester.enterText(find.byType(TextField).at(2), '1.5');
    await tester.enterText(find.byType(TextField).at(3), '0.25');
    await tapSave(tester);

    expect(find.byType(ModelConfigPage), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('valid range saves parsed values', (tester) async {
    ModelConfig? saved;
    await pumpConfigPage(tester, onSaved: (value) => saved = value);
    await tester.enterText(find.byType(TextField).at(2), '0.25');
    await tester.enterText(find.byType(TextField).at(3), '1.75');
    await tapSave(tester);

    expect(find.byType(ModelConfigPage), findsNothing);
    expect(saved?.volumeMin, 0.25);
    expect(saved?.volumeMax, 1.75);
    expect(saved?.hasVolume, isTrue);
  });

  testWidgets('empty optional ranges retain defaults', (tester) async {
    ModelConfig? saved;
    await pumpConfigPage(tester, onSaved: (value) => saved = value);

    await tapSave(tester);

    expect(find.byType(ModelConfigPage), findsNothing);
    expect(saved?.volumeMin, 0.1);
    expect(saved?.volumeMax, 2.0);
    expect(saved?.speedMin, 0.5);
    expect(saved?.speedMax, 2.0);
    expect(saved?.hasVolume, isFalse);
    expect(saved?.hasSpeed, isFalse);
  });
}
