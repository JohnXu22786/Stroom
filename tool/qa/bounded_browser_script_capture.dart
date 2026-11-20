import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_page.dart';

void main() {
  const source = '''
// ==UserScript==
// @name Preview test
// ==/UserScript==
console.log("preview");
''';
  final query = Uri.base.queryParameters;
  final localeName = query['locale'] ?? 'de';
  final locale = localeName == 'pt-br'
      ? const Locale('pt', 'BR')
      : Locale(localeName);
  final textScale = double.tryParse(query['textScale'] ?? '1') ?? 1;
  final mode = query['mode'] ?? 'manual';
  var didAutoOpen = false;

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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          if (!didAutoOpen) {
            didAutoOpen = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mode == 'import' || mode == 'preview') {
                showBrowserUserScriptImportDialog(
                  context,
                  fetchSource: (_) async => source,
                );
              } else {
                showBrowserUserScriptEditDialog(
                  context,
                  UserScript(name: 'Example', code: 'console.log("hello");'),
                );
              }
            });
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const Key('open-manual-script-editor'),
                    onPressed: () => showBrowserUserScriptEditDialog(
                      context,
                      UserScript(
                        name: 'Example',
                        code: 'console.log("hello");',
                      ),
                    ),
                    child: const Text('Open manual editor'),
                  ),
                  FilledButton(
                    key: const Key('open-import-script-dialog'),
                    onPressed: () => showBrowserUserScriptImportDialog(
                      context,
                      fetchSource: (_) async => source,
                    ),
                    child: const Text('Open import dialog'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
