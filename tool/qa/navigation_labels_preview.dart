import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_page.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeTag = query['locale'] ?? 'de';
  final localeParts = localeTag.split('-');
  final locale = Locale.fromSubtags(
    languageCode: localeParts.first,
    countryCode: localeParts.length > 1 ? localeParts[1].toUpperCase() : null,
  );
  final scale = double.tryParse(query['scale'] ?? '1') ?? 1;
  final dark = query['theme'] == 'dark';
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: dark ? Brightness.dark : Brightness.light,
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: query['motion'] == 'false',
          ),
          child: child!,
        ),
        home: const HomePage(),
      ),
    ),
  );
}
