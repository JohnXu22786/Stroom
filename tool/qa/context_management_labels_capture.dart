import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

void main() {
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1.0;
  final entry = ProviderEntry(
    id: 'qa_context_labels',
    type: 'llm',
    name: 'Local QA provider',
    configs: [
      ProviderConfigItem(
        providerName: 'ProviderA',
        host: 'https://example.invalid/v1',
        key: 'local-only',
        models: [
          ModelConfig(
            id: 'model-a',
            name: 'Model A',
            modelId: 'model-a',
            typeConfig: const {'context': 128000},
          ),
          ModelConfig(
            id: 'model-b',
            name: 'Model B',
            modelId: 'model-b',
            typeConfig: const {'context': 64000},
          ),
        ],
      ),
    ],
  );
  final entries = ProviderEntriesNotifier()
    ..state = ProviderEntriesState(entries: [entry]);

  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith((ref) => ThemeNotifier()..setLight()),
        providerEntriesProvider.overrideWith((ref) => entries),
        updateProvider.overrideWith((ref) => UpdateNotifier()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SettingsPage(),
      ),
    ),
  );
}
