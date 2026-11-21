import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_page.dart';

void main() {
  runApp(const _RecoveryGuidanceCaptureApp());
}

class _RecoveryGuidanceCaptureApp extends StatelessWidget {
  const _RecoveryGuidanceCaptureApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const BrowserPage(
          initialUrl:
              'data:text/html,<html><body style="font:16px sans-serif"><h2>Local recovery fixture</h2><p>This page is embedded in the capture and makes no network requests.</p></body></html>',
          recoveryMode: true,
        ),
      );
}
