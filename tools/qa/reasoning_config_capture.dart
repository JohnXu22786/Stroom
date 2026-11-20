import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';

void main() {
  runApp(
    MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: LlmModelConfigPage(
        model: ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'thinking.type',
              isReasoningToggle: true,
              onValue: 'enabled',
              offValue: 'disabled',
            ),
            ReasoningParam(
              paramName: 'reasoning_effort',
              isEffortParam: true,
              options: ['low', 'high'],
            ),
            ReasoningParam(paramName: 'budget_tokens', options: ['4096']),
          ],
        ),
      ),
    ),
  );
}
