import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ManifestDatabase.enableTestMode();
  await FileManifest.addRecord(
    AudioRecord(
      id: 'qa-asr-metadata-local-fixture',
      name: 'ASR sample audio',
      hash: 'qa_fixture_asr_metadata_sample',
      format: 'wav',
      createdAt: DateTime.utc(2026, 1, 1),
      size: 48 * 1024 * 1024,
      duration: 123456,
    ),
  );

  final query = Uri.base.queryParameters;
  final localeParts = (query['locale'] ?? 'en-US').split('-');
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
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AsrPage(),
      ),
    ),
  );
}
