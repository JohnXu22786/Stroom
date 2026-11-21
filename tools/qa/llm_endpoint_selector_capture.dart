import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';

void main() {
  final query = Uri.base.queryParameters;
  final locale = query['locale'] == 'en'
      ? const Locale('en')
      : const Locale('fr', 'FR');
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: LlmModelConfigPage(
        model: ModelConfig(
          name: 'Capture model',
          modelId: 'capture-model',
          typeConfig: const {'context': 4096},
          endpointType: 'openai',
        ),
      ),
    ),
  );
}
