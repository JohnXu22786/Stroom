import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/provider_settings_panel.dart';

void main() {
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final brightness = Uri.base.queryParameters['theme'] == 'dark'
      ? Brightness.dark
      : Brightness.light;
  runApp(
    MaterialApp(
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showProviderSettingsPanel(
                context: context,
                providerType: 'llm',
                config: ProviderConfigItem(
                  providerName: 'Test provider',
                  host: 'https://example.test/v1',
                  customParams: [
                    CustomParam(
                      paramName: 'reasoning_effort',
                      type: 'json',
                      defaultValue: '{\n  "effort": "high"\n}',
                    ),
                  ],
                ),
              ),
              child: const Text('Provider-Einstellungen öffnen'),
            ),
          ),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}
