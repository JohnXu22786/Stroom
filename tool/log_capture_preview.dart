import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/log_viewer_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LogCaptureApp());
}

class _LogCaptureApp extends StatelessWidget {
  const _LogCaptureApp();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    return MaterialApp(
      title: 'Stroom log settings capture',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1),
        ),
        child: child!,
      ),
      home: const LogViewerPage(),
    );
  }
}
