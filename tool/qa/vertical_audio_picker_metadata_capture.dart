import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_player_page.dart'
    show buildAudioTextPickerSubtitle;
import 'package:stroom/widgets/app_media_picker_dialog.dart';

class _TextRecord {
  final String id;
  final String folder;

  const _TextRecord({required this.id, this.folder = ''});
}

void main() {
  final localeCode = Uri.base.queryParameters['locale'] ?? 'de-DE';
  final localeParts = localeCode.split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );

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
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showMediaPickerDialog<_TextRecord>(
                context,
                MediaPickerConfig<_TextRecord>(
                  title:
                      AppLocalizations.of(context)!.audioPlayerSelectInAppText,
                  emptyIcon: Icons.description_outlined,
                  emptyText:
                      AppLocalizations.of(context)!.audioPlayerNoTextFiles,
                  fileIcon: Icons.description,
                  fileIconColor: Colors.orange,
                  loadRecords: () async => const [
                    _TextRecord(id: 'text-fixture'),
                  ],
                  loadFolders: () async => <String>{},
                  readFile: (_) async => Uint8List.fromList([1]),
                  displayName: (_) => 'meeting-notes.txt',
                  subtitleBuilder: (_) => buildAudioTextPickerSubtitle(
                    context,
                    characterCount: AppLocalizations.of(context)!
                        .audioPlayerCharacterCount(1234567),
                    fileSize: '12,34 MB im lokalen Speicher',
                  ),
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
