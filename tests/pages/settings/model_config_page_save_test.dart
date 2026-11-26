import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _ModelSaveNotifier extends ProviderEntriesNotifier {
  _ModelSaveNotifier({required this.failUpdate}) {
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'provider',
          type: 'tts',
          name: 'Provider',
          configs: [
            ProviderConfigItem(
              id: 'config',
              providerName: 'Provider',
              models: [
                ModelConfig(
                  id: 'model',
                  name: 'Model',
                  modelId: 'model-id',
                  maxWordsPerRequest: 100,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final bool failUpdate;

  @override
  Future<void> update(
    String id,
    ProviderEntry updated, {
    bool requirePersistence = true,
  }) async {
    if (failUpdate) throw StateError('storage unavailable');
    state = ProviderEntriesState(entries: [updated]);
  }
}

Future<void> _openModelEditor(
  WidgetTester tester, {
  required bool failUpdate,
  bool changeModelId = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => _ModelSaveNotifier(failUpdate: failUpdate),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<dynamic>(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => const ModelConfigPage(
                      entryId: 'provider',
                      configIndex: 0,
                      modelIndex: 0,
                    ),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
  if (changeModelId) {
    await tester.enterText(find.byType(TextField).at(1), 'changed-model-id');
  }
  await tester.pump();
}

void main() {
  testWidgets(
    'provider update failure keeps the editor usable and reports failure',
    (tester) async {
      await _openModelEditor(
        tester,
        failUpdate: true,
        changeModelId: true,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(ModelConfigPage), findsOneWidget);
      expect(
        find.text('Could not save. Your changes are still here. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Saving…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful provider update shows success feedback', (
    tester,
  ) async {
    await _openModelEditor(tester, failUpdate: false);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Model saved'), findsOneWidget);
    expect(
      find.text('Could not save. Your changes are still here. Try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
