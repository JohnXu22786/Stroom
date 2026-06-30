import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  // ==================================================================
  // Backup creation: onProgress callback
  // ==================================================================

  group('Backup creation with onProgress callback', () {
    testWidgets('buildBackupBytesForTest calls onProgress with 0.0 and 1.0',
        (WidgetTester t) async {
      final progressValues = <double>[];
      await BackupService.buildBackupBytesForTest(
        onProgress: (p) => progressValues.add(p),
      );

      // First call should be 0.0
      expect(progressValues.first, equals(0.0));
      // Last call should be 1.0
      expect(progressValues.last, equals(1.0));
      // Should have multiple progress updates
      expect(progressValues.length, greaterThanOrEqualTo(2));
    });

    testWidgets('buildBackupBytesForTest reports intermediate progress values',
        (WidgetTester t) async {
      final progressValues = <double>[];
      await BackupService.buildBackupBytesForTest(
        onProgress: (p) => progressValues.add(p),
      );

      // Should have reported progress at multiple stages
      expect(progressValues, contains(0.0));
      expect(progressValues, contains(1.0));
      // Check for intermediate values
      expect(progressValues.any((p) => p > 0.0 && p < 1.0), isTrue,
          reason: 'Should report intermediate progress values between 0 and 1');
    });
  });

  // ==================================================================
  // Backup creation: verify text records and text files are included
  // ==================================================================

  group('Backup creation includes text records', () {
    testWidgets('stroom_manifest.json contains text_records key',
        (WidgetTester t) async {
      // Insert a text record into the database
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_backup_1',
        'name': 'backup_test',
        'hash': 'hash123',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });

      // Build backup bytes
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find stroom_manifest.json in the archive
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull,
          reason: 'stroom_manifest.json must exist in the backup archive');

      final manifestJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;

      // Verify text_records key exists
      expect(manifestJson.containsKey('text_records'), isTrue,
          reason:
              'stroom_manifest.json must contain text_records key (bug: was missing)');

      // Verify our inserted record is in the list
      final textRecords =
          (manifestJson['text_records'] as List<dynamic>?) ?? [];
      expect(textRecords.length, equals(1),
          reason: 'text_records must contain 1 record');
      expect((textRecords[0] as Map)['id'], equals('txt_backup_1'));
    });

    testWidgets('text files are included in the backup archive',
        (WidgetTester t) async {
      const testContent = 'Hello, this is text file content for backup test!';
      // Create a text file and its database record
      final storageFileName = 'my_test_hash.txt';
      await TextManifest.writeText(storageFileName, testContent);
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_backup_2',
        'name': 'file_backup_test',
        'hash': 'my_test_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': testContent.length,
        'folder': '',
        'textLength': testContent.length,
      });

      // Build backup bytes
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Look for the text file in the texts/ directory
      String? foundFileKey;
      for (final f in archive) {
        if (f.isFile && f.name == 'texts/$storageFileName') {
          foundFileKey = f.name;
          break;
        }
      }
      expect(foundFileKey, isNotNull,
          reason:
              'Backup archive must contain texts/$storageFileName (bug: text files were excluded)');
    });
  });

  // ==================================================================
  // Backup restore: verify text records and files are restored
  // ==================================================================

  group('Backup restore includes text records', () {
    testWidgets('_restoreDatabaseFromJson inserts text records',
        (WidgetTester t) async {
      // Build a JSON string as it would appear in a backup
      final testJson = jsonEncode({
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': [
          {
            'id': 'txt_restore_1',
            'name': 'restored_text',
            'hash': 'restored_hash',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': 200,
            'folder': 'subfolder',
            'textLength': 200,
          },
          {
            'id': 'txt_restore_2',
            'name': 'restored_text_2',
            'hash': 'restored_hash_2',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': 300,
            'folder': '',
            'textLength': 300,
          },
        ],
        'folders': <String>['subfolder'],
      });

      // First clear the database (simulates restore starting fresh)
      await ManifestDatabase.clearAllData();

      // Restore from JSON
      await BackupService.restoreDatabaseFromJsonForTest(testJson);

      // Verify text records were inserted
      final textRecords = await ManifestDatabase.getAllTextRecords();
      expect(textRecords.length, equals(2),
          reason:
              'After restore from JSON, there should be 2 text records (bug: text records were not inserted)');
      expect(textRecords[0]['id'], equals('txt_restore_1'));
      expect(textRecords[0]['folder'], equals('subfolder'));
    });

    testWidgets('text files are restored from texts/ directory',
        (WidgetTester t) async {
      // Build a minimal backup archive that includes a text file
      const testContent = 'Restored text content! 你好世界';
      final archive = Archive();

      // Add manifest.json
      final manifest = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
      };
      archive.addFile(ArchiveFile(
          'manifest.json', utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest))));

      // Add stroom_manifest.json with a text record
      final dbData = {
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': [
          {
            'id': 'txt_restore_file',
            'name': 'restored_file',
            'hash': 'restored_hash_file',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': utf8.encode(testContent).length,
            'folder': '',
            'textLength': testContent.length,
          },
        ],
        'folders': <String>[],
      };
      archive.addFile(ArchiveFile(
          'stroom_manifest.json', utf8.encode(jsonEncode(dbData)).length,
          utf8.encode(jsonEncode(dbData))));

      // Add the text file in texts/ directory
      final textFileContent = utf8.encode(testContent);
      archive.addFile(ArchiveFile(
          'texts/restored_hash_file.txt', textFileContent.length,
          textFileContent));

      // Encode to bytes
      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);
      final backupBytes = Uint8List.fromList(encoded!);

      // Clear database and file store
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();

      // Restore from bytes
      await BackupService.restoreFromBytesForTest(backupBytes);
      TextManifest.invalidateCache();

      // Verify text record exists in DB
      final textRecords = await ManifestDatabase.getAllTextRecords();
      expect(textRecords.length, equals(1),
          reason:
              'After full restore, there should be 1 text record in the database');

      // Verify the text file content can be read
      final restoredContent =
          await TextManifest.readText('restored_hash_file.txt');
      expect(restoredContent, isNotNull,
          reason:
              'Text file should be readable after restore (bug: texts/ was missing from knownDirs)');
      expect(restoredContent, equals(testContent));
    });
  });

  // ==================================================================
  // Full roundtrip: backup → clear → restore → verify
  // ==================================================================

  group('Full backup/restore roundtrip preserves text records', () {
    testWidgets('text records survive backup and restore cycle',
        (WidgetTester t) async {
      // 1. Create test data: insert a text record and write a text file
      const testContent = 'Full roundtrip test content with 中文 Unicode!';
      final storageFileName = 'roundtrip_hash.txt';
      await TextManifest.writeText(storageFileName, testContent);
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_roundtrip_1',
        'name': 'roundtrip_test',
        'hash': 'roundtrip_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': utf8.encode(testContent).length,
        'folder': '',
        'textLength': testContent.length,
      });

      // 2. Create backup
      final backupBytes = await BackupService.buildBackupBytesForTest();

      // 3. Clear everything
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();
      expect(await ManifestDatabase.getAllTextRecords(), isEmpty,
          reason: 'After clearAllData, text records must be empty');

      // 4. Restore from backup
      await BackupService.restoreFromBytesForTest(backupBytes);
      TextManifest.invalidateCache();

      // 5. Verify text records are restored
      final restoredRecords = await ManifestDatabase.getAllTextRecords();
      expect(restoredRecords.length, equals(1),
          reason:
              'After full restore cycle, there must be 1 text record (bug: text records were lost during restore)');
      expect(restoredRecords[0]['name'], equals('roundtrip_test'));
      expect(restoredRecords[0]['hash'], equals('roundtrip_hash'));

      // 6. Verify text file content is restored
      final restoredContent = await TextManifest.readText(storageFileName);
      expect(restoredContent, isNotNull,
          reason:
              'Text file content must be restorable after full backup/restore cycle');
      expect(restoredContent, equals(testContent),
          reason:
              'Text file content must be identical after backup/restore roundtrip');
    });

    testWidgets('multiple text records with Chinese content survive roundtrip',
        (WidgetTester t) async {
      // Create several text records with Chinese content
      const contents = [
        '第一篇中文文档内容',
        '第二篇文档 - 含有English混合',
        '第三篇: 数字12345和符号!@#\$%',
      ];

      for (var i = 0; i < contents.length; i++) {
        final hash = 'chinese_hash_$i';
        final fileName = '$hash.txt';
        await TextManifest.writeText(fileName, contents[i]);
        await ManifestDatabase.insertTextRecord({
          'id': 'txt_chinese_$i',
          'name': 'chinese_doc_$i',
          'hash': hash,
          'format': 'txt',
          'createdAt': DateTime.now().toIso8601String(),
          'size': utf8.encode(contents[i]).length,
          'folder': '',
          'textLength': contents[i].length,
        });
      }

      // Create backup
      final backupBytes = await BackupService.buildBackupBytesForTest();

      // Clear everything
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();

      // Restore
      await BackupService.restoreFromBytesForTest(backupBytes);
      TextManifest.invalidateCache();

      // Verify all 3 records exist
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(3),
          reason: 'All 3 Chinese text records must survive backup/restore');

      // Verify content for each
      for (var i = 0; i < contents.length; i++) {
        final hash = 'chinese_hash_$i';
        final fileName = '$hash.txt';
        final content = await TextManifest.readText(fileName);
        expect(content, isNotNull,
            reason: 'Text file $fileName must be restorable');
        expect(content, equals(contents[i]),
            reason: 'Content of $fileName must match original');
      }
    });
  });

  // ==================================================================
  // Error handling: backup/restore with no data
  // ==================================================================

  group('Backup/restore handles empty data gracefully', () {
    testWidgets('backup with no records does not crash',
        (WidgetTester t) async {
      // No records inserted - just empty data
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify stroom_manifest.json has all keys (even if empty)
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);

      final manifestJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;
      expect(manifestJson.containsKey('text_records'), isTrue);
      expect((manifestJson['text_records'] as List<dynamic>?)?.length ?? 0,
          equals(0));
    });

    testWidgets('restore with no text records in backup does not crash',
        (WidgetTester t) async {
      // Build a minimal backup with empty text_records
      final testJson = jsonEncode({
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
      });

      await ManifestDatabase.clearAllData();
      await BackupService.restoreDatabaseFromJsonForTest(testJson);

      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty,
          reason: 'Restoring empty text_records must not crash');
    });
  });
}
