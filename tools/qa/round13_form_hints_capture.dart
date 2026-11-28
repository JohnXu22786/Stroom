import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/simple_model_config_page.dart';

void main() {
  final isDark = Uri.base.queryParameters['theme'] == 'dark';
  final brightness = isDark ? Brightness.dark : Brightness.light;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.8)),
        child: child!,
      ),
      home: SimpleModelConfigPage(
        model: ModelConfig(
          name: 'Example',
          modelId: 'gpt-4o',
          customParams: [
            CustomParam(paramName: 'response', type: 'json'),
          ],
        ),
      ),
    ),
  );
}
