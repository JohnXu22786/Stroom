import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeTag = query['locale'] ?? 'de';
  final locale = switch (localeTag) {
    'en' => const Locale('en'),
    'es' => const Locale('es'),
    _ => const Locale('de', 'DE'),
  };
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;

  runApp(
    ProviderScope(
      child: MaterialApp(
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
        home: const ModelConfigPage(
          entryId: 'qa-provider-model',
          configIndex: -1,
          modelIndex: -1,
        ),
      ),
    ),
  );
}
