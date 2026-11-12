import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  testWidgets('ASR preprocessing defaults to none and preserves saved choice', (
    tester,
  ) async {
    for (final testCase in [
      (saved: <String, dynamic>{}, expected: 'none'),
      (
        saved: <String, dynamic>{'preprocessing': 'resampleMono'},
        expected: 'resampleMono',
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showProviderSettingsPanel(
                    context: context,
                    config: ProviderConfigItem(
                      providerName: 'ASR provider',
                      host: 'https://api.example.com',
                      key: 'test-key',
                      typeConfig: testCase.saved,
                    ),
                    providerType: 'asr',
                  ),
                  child: const Text('Open provider settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open provider settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parameter settings'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButton<String> &&
              widget.value == testCase.expected,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  test(
    'resampling label is not marked recommended in any supported locale',
    () async {
      final recommendationMarker = RegExp(
        r'recommended|recommand|recomend|empfohlen|推奨|推荐|권장|موصى',
        caseSensitive: false,
      );

      for (final locale in AppLocalizations.supportedLocales) {
        final localizations = await AppLocalizations.delegate.load(locale);
        expect(
          localizations.providerPreprocessResample,
          isNot(contains(recommendationMarker)),
          reason: 'The resampling option should not be recommended in $locale.',
        );
      }
    },
  );
}
