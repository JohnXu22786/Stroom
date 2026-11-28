import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/llm_model_config_shared.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';
import '../../qa/round11_hint_measurement.dart';

void main() {
  testWidgets(
    'custom parameter header fits its dialog at wide viewport and large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(
            dialogTheme: const DialogThemeData(
              constraints: BoxConstraints(maxWidth: 340),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProviderSettingsPanel(
                  context: context,
                  providerType: 'llm',
                  config: ProviderConfigItem(
                    providerName: 'Provider',
                    host: 'https://example.test',
                    customParams: [
                      CustomParam(
                        paramName: 'response_mode',
                        type: 'string',
                        options: ['concise', 'detailed'],
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
      await tester.pumpAndSettle();
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      await tester.tap(find.byWidget(tabs.tabs[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final strings = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
      final heading = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == strings.chatCustomParameters,
      );
      final addButton =
          find.widgetWithText(TextButton, strings.providerAddCustomParam);
      final headingRect = tester.getRect(heading);
      final buttonRect = tester.getRect(addButton);
      final dialogRect = tester.getRect(find.byType(Dialog));
      expect(headingRect.left, greaterThanOrEqualTo(dialogRect.left));
      expect(headingRect.right, lessThanOrEqualTo(dialogRect.right));
      expect(buttonRect.left, greaterThanOrEqualTo(dialogRect.left));
      expect(buttonRect.right, lessThanOrEqualTo(dialogRect.right));
      expect(
        buttonRect.top >= headingRect.bottom ||
            buttonRect.left >= headingRect.right,
        isTrue,
        reason: 'The title and add action must reflow or fit without overlap.',
      );
      final optionHint = strings.providerOptionExampleHint(
        'low, enabled, true, max',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedInputHint && widget.data == optionHint,
        ),
        findsWidgets,
      );
      expectHintMeasurement(tester, hint: optionHint, clipped: true);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('LLM numeric examples use measured native-field hints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final maxTokensController = TextEditingController();
    final seedController = TextEditingController();
    final maxTokensHintStates = MaterialStatesController();
    final seedHintStates = MaterialStatesController();
    addTearDown(maxTokensController.dispose);
    addTearDown(seedController.dispose);
    addTearDown(maxTokensHintStates.dispose);
    addTearDown(seedHintStates.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            final strings = AppLocalizations.of(context)!;
            return Scaffold(
              body: ListView(
                children: [
                  LlmToggleTextField(
                    label: 'Max tokens',
                    controller: maxTokensController,
                    enabled: true,
                    onToggle: (_) {},
                    hintText: strings.providerOptionalExample('4096'),
                    constrainedHint: true,
                    hintStatesController: maxTokensHintStates,
                  ),
                  LlmToggleTextField(
                    label: 'Seed',
                    controller: seedController,
                    enabled: true,
                    onToggle: (_) {},
                    hintText: strings.providerOptionalExample('42'),
                    constrainedHint: true,
                    hintStatesController: seedHintStates,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    final strings = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expectHintMeasurement(
      tester,
      hint: strings.providerOptionalExample('4096'),
      clipped: true,
    );
    await tester.ensureVisible(find.byType(LlmToggleTextField).last);
    await tester.pump();
    expectHintMeasurement(
      tester,
      hint: strings.providerOptionalExample('42'),
      clipped: true,
    );
    expect(tester.takeException(), isNull);
  });
}
