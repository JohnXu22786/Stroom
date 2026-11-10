// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Uint8List _backupWithRecord(String table, Map<String, Object?> record) {
  final archive = Archive();
  final manifest = utf8.encode(jsonEncode({'version': 1}));
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  final db = utf8.encode(
    jsonEncode({
      'image_records': table == 'image_records' ? [record] : [],
      'audio_records': table == 'audio_records' ? [record] : [],
      'video_records': table == 'video_records' ? [record] : [],
      'text_records': table == 'text_records' ? [record] : [],
      'folders': <String>[],
    }),
  );
  archive.addFile(ArchiveFile('stroom_manifest.json', db.length, db));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets('restore rejects media storage names with path separators', (
    _,
  ) async {
    const date = '2026-01-01T00:00:00.000';
    const tables = [
      'image_records',
      'video_records',
      'text_records',
      'audio_records',
    ];
    for (final table in tables) {
      for (final field in ['hash', 'format']) {
        final record = <String, Object?>{
          'id': 'record',
          'name': 'record',
          'hash': 'safehash',
          'format': 'txt',
          'createdAt': date,
          'size': 1,
          'folder': '',
          if (table == 'video_records') 'duration': 0,
          if (table == 'text_records') 'textLength': 1,
          if (table == 'audio_records') ...{'sourceText': '', 'duration': 0},
          field: '../outside',
        };
        final selection = BackupSelection(
          chatRecordsAndAttachments: false,
          settings: false,
          pictures: table == 'image_records',
          audio: table == 'audio_records',
          videos: table == 'video_records',
          texts: table == 'text_records',
          tasks: false,
          ankiData: false,
          browserCookies: false,
        );

        await expectLater(
          BackupService.restoreFromBytesForTest(
            _backupWithRecord(table, record),
            selection: selection,
            skipMissingCategories: true,
          ),
          throwsA(isA<BackupValidationException>()),
          reason: '$table.$field must not be accepted as a storage name',
        );
      }
    }

    final oversizedRecord = <String, Object?>{
      'id': 'oversized',
      'name': 'oversized',
      'hash': List.filled(240, 'h').join(),
      'format': List.filled(20, 'f').join(),
      'createdAt': date,
      'size': 1,
      'folder': '',
    };
    await expectLater(
      BackupService.restoreFromBytesForTest(
        _backupWithRecord('image_records', oversizedRecord),
        selection: const BackupSelection(
          chatRecordsAndAttachments: false,
          settings: false,
          pictures: true,
          audio: false,
          videos: false,
          texts: false,
          tasks: false,
          ankiData: false,
          browserCookies: false,
        ),
        skipMissingCategories: true,
      ),
      throwsA(isA<BackupValidationException>()),
      reason: 'the combined storage filename must fit one filesystem component',
    );

    final oversizedAudioRecord = <String, Object?>{
      'id': 'oversized-audio',
      'name': 'oversized-audio',
      'hash': List.filled(170, 'h').join(),
      'format': List.filled(90, 'f').join(),
      'createdAt': date,
      'size': 1,
      'folder': '',
      'sourceText': '',
      'duration': 0,
    };
    await expectLater(
      BackupService.restoreFromBytesForTest(
        _backupWithRecord('audio_records', oversizedAudioRecord),
        selection: const BackupSelection(
          chatRecordsAndAttachments: false,
          settings: false,
          pictures: false,
          audio: true,
          videos: false,
          texts: false,
          tasks: false,
          ankiData: false,
          browserCookies: false,
        ),
        skipMissingCategories: true,
      ),
      throwsA(isA<BackupValidationException>()),
      reason: 'the raw audio backup filename must fit one filesystem component',
    );
  });
}
