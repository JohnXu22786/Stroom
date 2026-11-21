import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/provider_settings_panel.dart';

void main() {
  runApp(
    MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showProviderSettingsPanel(
                context: context,
                providerType: 'llm',
                config: ProviderConfigItem(
                  providerName: 'Provider QA',
                  host: 'https://example.test/v1',
                  reasoningParams: [
                    ReasoningParam(
                      paramName: 'reasoning.enabled',
                      isReasoningToggle: true,
                      onValue: 'yes',
                      offValue: 'false',
                    ),
                    ReasoningParam(
                      paramName: 'reasoning_effort',
                      isEffortParam: true,
                      options: ['low', 'high'],
                    ),
                    ReasoningParam(
                      paramName: 'thinking.budget',
                      options: ['1024', '4096'],
                    ),
                  ],
                ),
              ),
              child: const Text('Open provider settings'),
            ),
          ),
        ),
      ),
    ),
  );
}
