import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_cookies_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  BrowserCookieService.enableTestMode();
  await BrowserCookieService.persistCookiesRawForTest([
    {
      'domain': 'example.com',
      'name': 'session',
      'value': 'synthetic-private-session-value',
      'path': '/account/preferences/security/session-settings/long-cookie-path',
    },
  ]);

  runApp(
    MaterialApp(
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
      home: const BrowserCookiesPage(),
    ),
  );
}
