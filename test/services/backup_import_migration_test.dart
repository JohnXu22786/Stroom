import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppStorage.resetCache();
  });

  group('Backup import triggers data format migration', () {
    test('old-format backup (chat_configs) auto-migrated after import',
        () async {
      // ===============================================================
      // Setup: OLD format SharedPreferences (pre-migration era)
      // ===============================================================
      final oldChatConfigs = [
        {
          'providerName': 'OpenAI',
          'host': 'https://api.openai.com/v1',
          'key': 'sk-test',
          'models': [
            {
              'modelId': 'gpt-4',
              'maxTokens': 8192,
              'temperature': 0.7,
              'supportStream': true,
            },
          ],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode(oldChatConfigs),
        // NO 'provider_entries' — old format
        // NO 'data_format_version' — defaults to 0
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('provider_entries'), isFalse,
          reason: 'Pre-condition: old backup has no provider_entries');
      expect(prefs.getString('chat_configs'), isNotNull,
          reason: 'Pre-condition: old backup has chat_configs');

      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }

      // ===============================================================
      // Build an old-format backup archive (v1 with preferences.json)
      // ===============================================================
      final archive = Archive();

      final manifest = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
      };
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest))));

      final dbData = {
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
      };
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8.encode(jsonEncode(dbData)).length,
          utf8.encode(jsonEncode(dbData))));

      // Old format: preferences.json (with chat_configs)
      archive.addFile(ArchiveFile(
          'preferences.json',
          utf8.encode(jsonEncode(prefData)).length,
          utf8.encode(jsonEncode(prefData))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // ===============================================================
      // Clear state and restore (this triggers migration automatically)
      // ===============================================================
      await ManifestDatabase.clearAllData();
      SharedPreferences.setMockInitialValues({});

      // Restore — migration happens INSIDE restoreFromBytesForTest
      await BackupService.restoreFromBytesForTest(backupBytes);

      // ===============================================================
      // Verify data is already migrated (without explicit migrate call)
      // ===============================================================
      final migratedPrefs = await SharedPreferences.getInstance();

      // provider_entries should exist (from migration of chat_configs)
      expect(migratedPrefs.containsKey('provider_entries'), isTrue,
          reason: 'After import+migration, provider_entries should exist');

      // chat_configs should be removed (migration deletes old keys)
      expect(migratedPrefs.containsKey('chat_configs'), isFalse,
          reason: 'After import+migration, chat_configs should be removed');

      // data_format_version should be updated
      expect(migratedPrefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion),
          reason:
              'data_format_version should be updated after import+migration');

      // provider_entries should have valid content
      final providerEntriesJson = migratedPrefs.getString('provider_entries');
      expect(providerEntriesJson, isNotNull);

      final providerEntries = jsonDecode(providerEntriesJson!) as List<dynamic>;
      expect(providerEntries, isNotEmpty,
          reason: 'provider_entries should not be empty');

      // Verify migrated LLM entry structure
      final llmEntry = providerEntries.firstWhere(
        (e) => (e as Map)['type'] == 'llm',
        orElse: () => null,
      );
      expect(llmEntry, isNotNull,
          reason: 'LLM entry should exist after migration');
      final llmMap = llmEntry as Map<String, dynamic>;
      expect(llmMap['id'], isNotNull,
          reason: 'LLM entry should have non-null id');
      expect(llmMap['id'], isNotEmpty,
          reason: 'LLM entry should have non-empty id');
      expect(llmMap['type'], equals('llm'));
    });

    test('null IDs in provider_entries auto-fixed after import', () async {
      // ===============================================================
      // Setup: old format with null IDs and null types
      // ===============================================================
      final oldProviderEntries = [
        {
          'id': null, // null ID bug
          'type': 'tts',
          'name': 'TTS供应商',
          'configs': [],
        },
        {
          'id': 'some_id',
          'type': null, // null type bug
          'name': 'BrokenProvider',
          'configs': [],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode(oldProviderEntries),
        'data_format_version': 0,
      });

      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }

      // ===============================================================
      // Build backup (v1 format with preferences.json)
      // ===============================================================
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode({'version': 1})).length,
          utf8.encode(jsonEncode({'version': 1}))));

      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8
              .encode(jsonEncode({
                'image_records': [],
                'audio_records': [],
                'video_records': [],
                'text_records': [],
                'folders': []
              }))
              .length,
          utf8.encode(jsonEncode({
            'image_records': [],
            'audio_records': [],
            'video_records': [],
            'text_records': [],
            'folders': []
          }))));

      archive.addFile(ArchiveFile(
          'preferences.json',
          utf8.encode(jsonEncode(prefData)).length,
          utf8.encode(jsonEncode(prefData))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // ===============================================================
      // Restore (triggers migration automatically)
      // ===============================================================
      await ManifestDatabase.clearAllData();
      SharedPreferences.setMockInitialValues({});
      await BackupService.restoreFromBytesForTest(backupBytes);

      // ===============================================================
      // Verify data auto-migrated
      // ===============================================================
      final migratedPrefs = await SharedPreferences.getInstance();
      final migratedJson = migratedPrefs.getString('provider_entries');
      expect(migratedJson, isNotNull);

      final migratedList = jsonDecode(migratedJson!) as List<dynamic>;
      expect(migratedList.length, equals(2),
          reason: 'Both entries should survive migration');

      // Entry 0: null ID fixed
      final entry0 = migratedList[0] as Map<String, dynamic>;
      expect(entry0['id'], isNotNull,
          reason: 'Null ID should be auto-fixed after import');
      expect((entry0['id'] as String).isNotEmpty, isTrue);

      // Entry 1: null type fixed
      final entry1 = migratedList[1] as Map<String, dynamic>;
      expect(entry1['type'], isNotNull,
          reason: 'Null type should be auto-fixed after import');
      expect((entry1['type'] as String).isNotEmpty, isTrue);

      // Version should be updated
      expect(migratedPrefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
    });

    test('modern-format backup skips migration after import', () async {
      // ===============================================================
      // Setup: Modern format at currentFormatVersion
      // ===============================================================
      final modernProviderEntries = [
        {
          'id': 'builtin_tts',
          'type': 'tts',
          'name': 'TTS供应商',
          'configs': [],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode(modernProviderEntries),
        'data_format_version': DataMigrationService.currentFormatVersion,
      });

      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }

      // Build backup (v2 format with chat_data.json and settings.json)
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode({'version': 2})).length,
          utf8.encode(jsonEncode({'version': 2}))));

      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8
              .encode(jsonEncode({
                'image_records': [],
                'audio_records': [],
                'video_records': [],
                'text_records': [],
                'text_folders': [],
                'audio_folders': [],
                'image_folders': [],
                'video_folders': []
              }))
              .length,
          utf8.encode(jsonEncode({
            'image_records': [],
            'audio_records': [],
            'video_records': [],
            'text_records': [],
            'text_folders': [],
            'audio_folders': [],
            'image_folders': [],
            'video_folders': []
          }))));

      // New format settings.json
      archive.addFile(ArchiveFile(
          'settings.json',
          utf8.encode(jsonEncode(prefData)).length,
          utf8.encode(jsonEncode(prefData))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore
      await ManifestDatabase.clearAllData();
      SharedPreferences.setMockInitialValues({});
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Verify data still in modern format (migration didn't change anything)
      final postPrefs = await SharedPreferences.getInstance();
      expect(postPrefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
      expect(postPrefs.getString('provider_entries'), isNotNull);
    });

    test('restore without preferences skips migration gracefully', () async {
      // Build a backup WITHOUT any preference files
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode({'version': 2})).length,
          utf8.encode(jsonEncode({'version': 2}))));

      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8
              .encode(jsonEncode({
                'image_records': [],
                'audio_records': [],
                'video_records': [],
                'text_records': [],
                'folders': []
              }))
              .length,
          utf8.encode(jsonEncode({
            'image_records': [],
            'audio_records': [],
            'video_records': [],
            'text_records': [],
            'folders': []
          }))));

      // NO preference files

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      await ManifestDatabase.clearAllData();
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
      });
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Should not throw and version should remain current
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
    });

    test('v1 backup with preferences.json still imports correctly', () async {
      // ===============================================================
      // Build an old-format (v1) backup with preferences.json
      // ===============================================================
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {'id': 'test_llm', 'type': 'llm', 'name': 'Test LLM', 'configs': []}
        ]),
        'data_format_version': DataMigrationService.currentFormatVersion,
      });

      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }

      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode({'version': 1})).length,
          utf8.encode(jsonEncode({'version': 1}))));

      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8
              .encode(jsonEncode({
                'image_records': [],
                'audio_records': [],
                'video_records': [],
                'text_records': [],
                'folders': []
              }))
              .length,
          utf8.encode(jsonEncode({
            'image_records': [],
            'audio_records': [],
            'video_records': [],
            'text_records': [],
            'folders': []
          }))));

      archive.addFile(ArchiveFile(
          'preferences.json',
          utf8.encode(jsonEncode(prefData)).length,
          utf8.encode(jsonEncode(prefData))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore
      await ManifestDatabase.clearAllData();
      SharedPreferences.setMockInitialValues({});
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Verify data was restored
      final restoredPrefs = await SharedPreferences.getInstance();
      expect(restoredPrefs.getString('provider_entries'), isNotNull);
      final entries = jsonDecode(restoredPrefs.getString('provider_entries')!) as List;
      expect(entries.length, equals(1));
      expect(entries[0]['id'], equals('test_llm'));
    });
  });
}
