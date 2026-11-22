import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/app_media_picker_dialog.dart';

void main() {
  final locale = Uri.base.queryParameters['locale'] == 'fr'
      ? const Locale('fr', 'FR')
      : const Locale('en', 'US');
  const error = '''
MediaStore query failed: platform returned an invalid response.
Diagnostic context from a safe local fixture; no account data or network calls.
''';
  final fullError = List.generate(
    32,
    (index) => '  at media_store_reader.dart:${180 + index}:7 '
        '(query segment ${index + 1}/32)',
  ).join('\n');

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('media-picker-open'),
              onPressed: () => showMediaPickerDialog<void>(
                context,
                MediaPickerConfig<void>(
                  title: 'Local media',
                  emptyIcon: Icons.folder_outlined,
                  emptyText: 'No media available',
                  fileIcon: Icons.insert_drive_file,
                  loadRecords: () async => throw StateError(
                    '$error$fullError',
                  ),
                  loadFolders: () async => <String>{},
                  displayName: (_) => '',
                  subtitleBuilder: (_) => const SizedBox.shrink(),
                ),
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    ),
  );
}
