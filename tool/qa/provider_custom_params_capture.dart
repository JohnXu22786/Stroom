import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_settings_panel.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  final localeParts =
      (Uri.base.queryParameters['locale'] ?? 'fr-FR').split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showProviderSettingsPanel(
                context: context,
                providerType: 'llm',
                config: ProviderConfigItem(
                  providerName: 'Demo provider',
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
              child: const Text('Open provider settings'),
            ),
          ),
        ),
      ),
    ),
  );
}
