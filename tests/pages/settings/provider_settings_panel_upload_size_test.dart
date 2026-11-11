import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';

Future<ProviderConfigItem?> _openAndSave(
  WidgetTester tester, {
  String? editedValue,
  double initialSize = 25.0,
  bool switchToUrl = false,
}) async {
  ProviderConfigItem? saved;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                saved = await showProviderSettingsPanel(
                  context: context,
                  config: ProviderConfigItem(
                    providerName: 'ASR provider',
                    host: 'https://api.example.com',
                    key: 'test-key',
                    typeConfig: {'maxFileSizeMb': initialSize},
                  ),
                  providerType: 'asr',
                );
              },
              child: const Text('Open provider settings'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open provider settings'));
  await tester.pumpAndSettle();

  final sizeField = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.suffixText == 'MB',
  );
  if (editedValue != null) {
    await tester.enterText(sizeField, editedValue);
  }
  if (switchToUrl) {
    await tester.tap(find.text('Multipart (general)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('URL').last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('invalid maximum upload sizes are shown and cannot be saved', (
    tester,
  ) async {
    for (final invalidValue in ['', 'invalid', 'NaN', 'Infinity', '0', '-1']) {
      final saved = await _openAndSave(tester, editedValue: invalidValue);

      expect(saved, isNull, reason: 'Should reject "$invalidValue".');
      expect(
        find.text('Maximum upload size must be a positive number.'),
        findsOneWidget,
        reason: 'Should show validation for "$invalidValue".',
      );
    }
  });

  testWidgets('valid maximum upload size is saved from the edited value', (
    tester,
  ) async {
    final saved = await _openAndSave(tester, editedValue: '12.5');

    expect(saved, isNotNull);
    expect(saved!.typeConfig['maxFileSizeMb'], 12.5);
  });

  testWidgets('saving an untouched value preserves its configured precision', (
    tester,
  ) async {
    final saved = await _openAndSave(tester, initialSize: 12.55);

    expect(saved, isNotNull);
    expect(saved!.typeConfig['maxFileSizeMb'], 12.55);
  });

  testWidgets('URL upload mode does not block on hidden size validation', (
    tester,
  ) async {
    final saved = await _openAndSave(
      tester,
      editedValue: 'invalid',
      switchToUrl: true,
    );

    expect(saved, isNotNull);
    expect(saved!.typeConfig['maxFileSizeMb'], 25.0);
  });
}
