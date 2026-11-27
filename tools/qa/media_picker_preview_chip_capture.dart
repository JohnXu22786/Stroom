import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/app_media_picker_dialog.dart';

void main() {
  final parameters = Uri.base.queryParameters;
  final fixture = parameters['fixture'] ?? 'fit';
  final scale = fixture == 'fit' ? 1.0 : 2.0;
  final isStatic = parameters['static'] == '1';
  final name = switch (fixture) {
    'three' => 'one two three',
    'overflow' => 'media picker selected filename 123456789 extra.txt',
    _ => 'a.b',
  };

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: isStatic,
        ),
        child: child!,
      ),
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: isStatic,
          ),
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open-media-picker'),
                  onPressed: () => showMediaPickerDialog<_CaptureRecord>(
                    context,
                    MediaPickerConfig<_CaptureRecord>(
                      title: 'Local media',
                      emptyIcon: Icons.folder_outlined,
                      emptyText: 'No media available',
                      fileIcon: Icons.insert_drive_file,
                      multiSelect: true,
                      loadRecords: () async => [
                        _CaptureRecord(id: 'fixture', name: name, folder: ''),
                      ],
                      loadFolders: () async => <String>{},
                      readFile: (_) async => Uint8List.fromList([1, 2, 3]),
                      displayName: (record) => record.name,
                      subtitleBuilder: (_) => const Text('Local fixture'),
                    ),
                  ),
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CaptureRecord {
  final String id;
  final String name;
  final String folder;

  const _CaptureRecord({
    required this.id,
    required this.name,
    this.folder = '',
  });
}
