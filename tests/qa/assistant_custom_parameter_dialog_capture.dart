import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/assistant_selection_page.dart';

void main() => runApp(const _CaptureApp());

class _CaptureApp extends StatefulWidget {
  const _CaptureApp();

  @override
  State<_CaptureApp> createState() => _CaptureAppState();
}

class _CaptureAppState extends State<_CaptureApp> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Builder(
        builder: (context) {
          if (!_opened) {
            _opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              showAddCustomParameterDialog(context, (_, _, _) {});
            });
          }
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
  }
}
