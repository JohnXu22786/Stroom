import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:web/web.dart' as web;
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/search_panel.dart';

void main() {
  final parameters = Uri.base.queryParameters;
  final languageCode = parameters['locale'] ?? 'de';
  final locale = Locale(languageCode, languageCode == 'en' ? 'US' : 'DE');
  final textScale = double.tryParse(parameters['scale'] ?? '') ?? 2;
  final dark = parameters['theme'] == 'dark';
  final reducedMotion = parameters['reducedMotion'] == 'true';

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => SearchPanel(
                  conversations: const [],
                  onConversationSelected: (_) {},
                ),
              ),
              child: const Text('Open search'),
            ),
          ),
        ),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    web.window.dispatchEvent(web.Event('search-panel-ready'));
  });
}
