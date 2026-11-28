import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/simple_model_config_page.dart';

void main() {
  final isDark = Uri.base.queryParameters['theme'] == 'dark';
  final fitting = Uri.base.queryParameters['case'] == 'fitting';
  final brightness = isDark ? Brightness.dark : Brightness.light;
  final locale = fitting ? const Locale('en', 'US') : const Locale('de', 'DE');
  final textScale = fitting ? 1.0 : 1.8;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
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
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SimpleModelConfigPage(
        model: fitting
            ? null
            : ModelConfig(
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
