import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/code_editor_field.dart';

void main() {
  final localeName = Uri.base.queryParameters['locale'] ?? 'de';
  final locale = localeName == 'en' ? const Locale('en') : const Locale('de');

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
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showJsonValueEditorDialog(
                context,
                initialValue: '{"name":"example","count":1}',
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
