import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/providers/provider_config.dart';

class _ProviderEntriesCapture extends ProviderEntriesNotifier {
  _ProviderEntriesCapture(List<ModelConfig> models) : super() {
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'provider-model-tile-capture',
          type: 'llm',
          name: 'Capture provider',
          configs: [
            ProviderConfigItem(
              providerName: 'Capture provider',
              host: 'https://example.test',
              key: 'local-capture-only',
              models: models,
            ),
          ],
        ),
      ],
    );
  }
}

final _models = [
  ModelConfig(
    name: 'A very long provider model name that exceeds this narrow tile',
    modelId: 'provider-model-identifier-with-a-long-unbroken-value-123456789',
  ),
];

void main() {
  final query = Uri.base.queryParameters;
  final fitting = query['state'] == 'fitting';
  final reducedMotion = query['reducedMotion'] == 'true';
  final locale = switch (query['locale']) {
    'en' => const Locale('en'),
    _ => const Locale('de', 'DE'),
  };
  final scale = double.tryParse(query['scale'] ?? '') ?? 1.8;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final models = fitting
      ? [ModelConfig(name: 'Model name', modelId: 'model-id')]
      : _models;

  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => _ProviderEntriesCapture(models),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: ProviderConfigDetailPage(
          entryId: 'provider-model-tile-capture',
          configIndex: 0,
        ),
      ),
    ),
  );
}
