import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _providerSettingsHarness(Locale locale, String providerType) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        dialogTheme: const DialogThemeData(
          constraints: BoxConstraints(maxWidth: 1200),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showProviderSettingsPanel(
                context: context,
                config: ProviderConfigItem(
                  providerName: 'Provider',
                  host: 'https://example.test',
                  key: 'test-key',
                ),
                providerType: providerType,
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'provider field labels and endpoint options are measured in every locale',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;

      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(_providerSettingsHarness(locale, 'llm'));
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final localizations = AppLocalizations.of(
          tester.element(find.byType(Dialog)),
        )!;
        await tester.ensureVisible(find.text(localizations.providerNameLabel));
        await tester.pump();
        final boundedLabels = tester
            .widgetList<ConstrainedText>(find.byType(ConstrainedText))
            .map((widget) => widget.data)
            .toSet();
        for (final label in [
          localizations.providerNameLabel,
          localizations.providerApiUrlLabel,
          localizations.mcpApiKey,
          localizations.providerEndpointTypeLabel,
        ]) {
          expect(
            boundedLabels,
            contains(label),
            reason: 'Expected a measured, bounded label for $locale: $label',
          );
        }

        if (locale == AppLocalizations.supportedLocales.first) {
          final providerNameField = find.byType(TextField).first;
          await tester.tap(providerNameField);
          await tester.enterText(providerNameField, 'Updated provider');
          expect(
            tester.widget<TextField>(providerNameField).controller!.text,
            'Updated provider',
          );
        }

        await tester.ensureVisible(
          find.text(localizations.providerEndpointTypeLabel),
        );
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final boundedOptions = tester
            .widgetList<ConstrainedText>(find.byType(ConstrainedText))
            .map((widget) => widget.data)
            .toSet();
        for (final option in [
          localizations.providerEndpointOpenAi,
          localizations.providerEndpointAnthropic,
          localizations.endpointResponsesApi,
        ]) {
          expect(
            boundedOptions,
            contains(option),
            reason: 'Expected a measured dropdown option for $locale: $option',
          );
        }

        expect(tester.takeException(), isNull, reason: 'Locale: $locale');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await tester.pumpWidget(_providerSettingsHarness(locale, 'ocr'));
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final tabController = DefaultTabController.of(
          tester.element(find.byType(TabBar)),
        );
        tabController.animateTo(1, duration: Duration.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final ocrLocalizations = AppLocalizations.of(
          tester.element(find.byType(Dialog)),
        )!;
        await tester.ensureVisible(
          find.text(ocrLocalizations.providerRequestJsonDefault),
        );
        await tester.pump();
        expect(
          tester
              .widgetList<ConstrainedText>(find.byType(ConstrainedText))
              .map((widget) => widget.data),
          contains(ocrLocalizations.providerRequestJsonDefault),
          reason: 'Expected measured OCR budget label for $locale',
        );
        expect(tester.takeException(), isNull, reason: 'OCR locale: $locale');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
