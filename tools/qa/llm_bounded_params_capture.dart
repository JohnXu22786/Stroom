import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';

void main() {
  runApp(
    MaterialApp(
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: LlmModelConfigPage(
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          customParams: [
            CustomParam(
              paramName: 'reasoning_effort',
              defaultValue: '{\n  "mode": "deep"\n}',
              type: 'json',
            ),
          ],
        ),
      ),
    ),
  );
}
