import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';
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
  final component = Uri.base.queryParameters['component'] ?? 'editor';
  final editorFixture = '[\n${List.generate(
    1234,
    (index) => '  "Eintrag ${index + 1}"',
  ).join(',\n')}\n]';
  final codeBlockFixture = List<String>.generate(1234, (index) => 'entry');

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
      home: component == 'block'
          ? Scaffold(
              body: CodeBlockSourceView(
                code: codeBlockFixture.join('\n'),
                language: 'dart',
              ),
            )
          : Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showJsonValueEditorDialog(
                      context,
                      initialValue: editorFixture,
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
