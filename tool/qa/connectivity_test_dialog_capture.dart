import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/connectivity_test_dialog.dart';
import 'package:stroom/services/connectivity_test_service.dart';

void main() {
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              builder: (dialogContext) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted) {
                    FocusScope.of(dialogContext).nextFocus();
                  }
                });
                return ConnectivityTestDialog(
                  title: 'Proxy',
                  initialContent:
                      '{\n  "endpoint": "https://example.invalid"\n}',
                  note:
                      'Lokaler Vorschaudialog. Es wird keine Verbindung gestartet.',
                  onSave: (_) async {},
                  onRun: (_) async => const ConnectivityTestResult(
                    succeeded: true,
                    summary: 'Lokale Vorschau',
                    details: '',
                    elapsed: Duration.zero,
                  ),
                );
              },
            );
          });
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
}
