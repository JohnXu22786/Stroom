import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/text_storage_page.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ManifestDatabase.enableTestMode();

  final query = Uri.base.queryParameters;
  final localeParts = (query['locale'] ?? 'fr-FR').split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const TextStoragePage(),
      ),
    ),
  );
}
