import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  ManifestDatabase.enableTestMode();
  TextManifest.invalidateCache();
  await TextManifest.writeText('picker-chrome-note.txt', 'safe fixture');
  await TextManifest.addRecord(
    TextRecord(
      name: 'picker-chrome-note',
      hash: 'picker-chrome-note',
      size: 12,
      createdAt: DateTime(2026, 11, 27),
    ),
  );
  runApp(const _CaptureApp());
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp();

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final localeParts = (query['locale'] ?? 'de-DE').split('-');
    final scale = double.tryParse(query['scale'] ?? '3') ?? 3;
    final language = Locale.fromSubtags(
      languageCode: localeParts.first,
      countryCode: localeParts.length > 1 ? localeParts[1] : null,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: language,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData.light(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const _CaptureHome(),
    );
  }
}

class _CaptureHome extends StatefulWidget {
  const _CaptureHome();

  @override
  State<_CaptureHome> createState() => _CaptureHomeState();
}

class _CaptureHomeState extends State<_CaptureHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showAppFilePickerDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
