import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('provider custom parameter field labels use measured slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProviderSettingsPanel(
                context: context,
                providerType: 'llm',
                config: ProviderConfigItem(
                  providerName: 'Provider',
                  host: 'https://example.test',
                  customParams: [
                    CustomParam(
                      paramName: 'reasoning_effort',
                      type: 'json',
                      defaultValue: '{"x": 1}',
                    ),
                  ],
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    final settingsTab = tabs.tabs[1];
    await tester.tap(find.byWidget(settingsTab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
    final labels = tester.widgetList<ConstrainedText>(
      find.byType(ConstrainedText),
    );
    expect(
      labels.map((label) => label.data),
      contains(strings.providerParamNameLabel),
    );
    expect(
      labels.map((label) => label.data),
      contains(strings.providerParamDefaultValueLabel),
    );
    expect(find.byType(TextFormField), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });
}
