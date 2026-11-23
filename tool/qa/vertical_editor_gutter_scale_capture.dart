import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/code_editor_field.dart';

void main() {
  final localeParts =
      (Uri.base.queryParameters['locale'] ?? 'de-DE').split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;
  final dark = Uri.base.queryParameters['theme'] == 'dark';

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
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showJsonValueEditorDialog(
                context,
                initialValue: '''{
  "name": "local example",
  "enabled": true,
  "count": 3,
  "options": {
    "first": "alpha",
    "second": "beta"
  }
}''',
                hintText: '',
                type: 'json',
                onSave: (_) {},
              ),
              child: const Text('Open JSON editor'),
            ),
          ),
        ),
      ),
    ),
  );
}
