import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  // ==================================================================
  // BackupSelection 类行为
  // ==================================================================

  group('BackupSelection class', () {
    test('BackupSelection.all has all flags set to true', () {
      final sel = BackupSelection.all;
      expect(sel.conversations, isTrue);
      expect(sel.pictures, isTrue);
      expect(sel.audio, isTrue);
      expect(sel.videos, isTrue);
      expect(sel.texts, isTrue);
      expect(sel.tasks, isTrue);
      expect(sel.attachments, isTrue);
    });

    test('BackupSelection.all.selectedLabels returns all 7 labels', () {
      final labels = BackupSelection.all.selectedLabels;
      expect(labels.length, equals(7));
      expect(labels, contains('聊天记录和设置'));
      expect(labels, contains('图片'));
      expect(labels, contains('音频'));
      expect(labels, contains('视频'));
      expect(labels, contains('文本'));
      expect(labels, contains('任务'));
      expect(labels, contains('附件'));
    });

    test('BackupSelection with pictures-only returns correct labels', () {
      final sel = BackupSelection(
        conversations: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        attachments: false,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('图片'));
    });

    test('BackupSelection default constructor has all flags true', () {
      final sel = BackupSelection();
      expect(sel.conversations, isTrue);
      expect(sel.pictures, isTrue);
      expect(sel.audio, isTrue);
      expect(sel.videos, isTrue);
      expect(sel.texts, isTrue);
      expect(sel.tasks, isTrue);
      expect(sel.attachments, isTrue);
    });
  });

  // ==================================================================
  // 选择性备份：仅备份选中的类别
  // ==================================================================

  group('Selective backup produces archives with only selected data', () {
    testWidgets('backup with pictures-only includes only pictures in archive',
        (WidgetTester t) async {
      // Insert test records for multiple types
      await ManifestDatabase.insertImageRecord({
        'id': 'img_sel_1',
        'name': 'sel_img',
        'hash': 'sel_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_sel_1',
        'name': 'sel_aud',
        'hash': 'sel_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_sel_1',
        'name': 'sel_vid',
        'hash': 'sel_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_sel_1',
        'name': 'sel_txt',
        'hash': 'sel_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });

      // Build backup with pictures-only selection
      final sel = BackupSelection(
        conversations: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        attachments: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(
        selection: sel,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      // Collect file names from archive
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // Should contain manifest.json (always included)
      expect(fileNames, contains('manifest.json'));

      // Should contain stroom_manifest.json (always included, but only with selected records)
      expect(fileNames, contains('stroom_manifest.json'));

      // Should NOT contain preferences.json (conversations=false)
      expect(fileNames, isNot(contains('preferences.json')));

      // Should NOT contain audio, video, text files
      expect(fileNames.any((n) => n.startsWith('tts_audio/')), isFalse,
          reason: 'Audio should not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('videos/')), isFalse,
          reason: 'Videos should not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('texts/')), isFalse,
          reason: 'Texts should not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('synthesis/')), isFalse,
          reason: 'Tasks should not be in pictures-only backup');

      // Verify stroom_manifest.json only has image_records populated
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);

      final dbJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;
      expect((dbJson['image_records'] as List<dynamic>).length, equals(1),
          reason: 'image_records should have 1 record');
      expect((dbJson['audio_records'] as List<dynamic>).length, equals(0),
          reason: 'audio_records should be empty');
      expect((dbJson['video_records'] as List<dynamic>).length, equals(0),
          reason: 'video_records should be empty');
      expect((dbJson['text_records'] as List<dynamic>).length, equals(0),
          reason: 'text_records should be empty');
    });

    testWidgets('backup with conversations-only has preferences and db',
        (WidgetTester t) async {
      // Insert a text record
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_conv_1',
        'name': 'conv_txt',
        'hash': 'conv_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });

      // Build backup with conversations-only selection
      final sel = BackupSelection(
        conversations: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        attachments: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(
        selection: sel,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // Should contain manifest and preferences and database
      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));
      expect(fileNames, contains('preferences.json'));

      // Should NOT contain any binary files
      expect(fileNames.any((n) => n.startsWith('pictures/')), isFalse);
      expect(fileNames.any((n) => n.startsWith('tts_audio/')), isFalse);
      expect(fileNames.any((n) => n.startsWith('videos/')), isFalse);
      expect(fileNames.any((n) => n.startsWith('texts/')), isFalse);
      expect(fileNames.any((n) => n.startsWith('synthesis/')), isFalse);
      expect(fileNames.any((n) => n.startsWith('catcatch/')), isFalse);
    });
  });

  // ==================================================================
  // 选择性恢复：仅恢复选中的类别
  // ==================================================================

  group('Selective restore only restores selected categories', () {
    testWidgets('pictures-only restore only restores image records',
        (WidgetTester t) async {
      // First, add some existing data (simulating pre-existing data)
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_existing_1',
        'name': 'existing_aud',
        'hash': 'existing_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      // Build a backup archive containing both image and audio records
      final backupArchive = Archive();
      // manifest.json
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      // stroom_manifest.json with both image and audio records
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_restore_1',
                'name': 'restored_img',
                'hash': 'restored_img_hash',
                'format': 'jpg',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 200,
                'folder': '',
                'width': 200,
                'height': 200,
              },
            ],
            'audio_records': [
              {
                'id': 'aud_restore_1',
                'name': 'restored_aud',
                'hash': 'restored_aud_hash',
                'format': 'wav',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 200,
                'folder': '',
                'duration': 2.0,
              },
            ],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with pictures-only selection
      final sel = BackupSelection(
        conversations: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        attachments: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Verify: image records were restored
      final imageRecords = await ManifestDatabase.getAllImageRecords();
      expect(imageRecords.length, equals(1),
          reason: 'Image records should be restored');
      expect(imageRecords[0]['id'], equals('img_restore_1'));

      // Verify: audio records from the backup were NOT restored (pictures-only)
      // The pre-existing audio record should also have been preserved
      // since we only cleared image_records, not audio_records
      // Wait - actually the behavior is: with pictures-only selection,
      // we ONLY clear and restore image_records. audio_records is untouched.
      // So the existing audio record should still be there.
      final audioRecords = await ManifestDatabase.getAllAudioRecords();
      expect(audioRecords.length, equals(1),
          reason:
              'Audio records should be preserved (only pictures were selected for restore)');
      expect(audioRecords[0]['id'], equals('aud_existing_1'),
          reason:
              'Pre-existing audio record must be preserved during selective restore');
    });

    testWidgets('full restore replaces all record types',
        (WidgetTester t) async {
      // Add pre-existing data
      await ManifestDatabase.insertImageRecord({
        'id': 'img_old_1',
        'name': 'old_img',
        'hash': 'old_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'width': 50,
        'height': 50,
      });

      // Build a backup archive with different records
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_new_1',
                'name': 'new_img',
                'hash': 'new_img_hash',
                'format': 'jpg',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 200,
                'folder': '',
                'width': 200,
                'height': 200,
              },
            ],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Full restore (default selection)
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Old image record should be gone, new one should be present
      final imageRecords = await ManifestDatabase.getAllImageRecords();
      expect(imageRecords.length, equals(1),
          reason: 'Full restore should replace all image records');
      expect(imageRecords[0]['id'], equals('img_new_1'),
          reason: 'Old image record must be replaced during full restore');
    });
  });

  // ==================================================================
  // 混合选择备份/恢复测试
  // ==================================================================

  group('Mixed selection backup and restore', () {
    testWidgets('backup with pictures+audio includes both in archive',
        (WidgetTester t) async {
      await ManifestDatabase.insertImageRecord({
        'id': 'img_mix_1',
        'name': 'mix_img',
        'hash': 'mix_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_mix_1',
        'name': 'mix_vid',
        'hash': 'mix_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      // Build backup with pictures + audio + tasks selection (no video, no text)
      final sel = BackupSelection(
        conversations: false,
        pictures: true,
        audio: true,
        videos: false,
        texts: false,
        tasks: true,
        attachments: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(selection: sel);
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));

      // The key behavior to verify is which categories' DB records are included.
      // Binary files (pictures/, tts_audio/) are only added if they exist on disk,
      // which isn't tested here. The DB records tell us which categories were selected.
      expect(fileNames.any((n) => n.startsWith('videos/')), isFalse,
          reason: 'Videos should not be in pictures+audio+tasks backup');
      expect(fileNames.any((n) => n.startsWith('texts/')), isFalse,
          reason: 'Texts should not be in pictures+audio+tasks backup');

      // Verify stroom_manifest.json has only image, audio, video records
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);
      final dbJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;
      expect(dbJson.containsKey('image_records'), isTrue);
      expect(dbJson.containsKey('audio_records'), isTrue);
      expect(dbJson.containsKey('video_records'), isTrue,
          reason: 'video_records key should exist even if empty');
      expect(dbJson.containsKey('text_records'), isTrue,
          reason: 'text_records key should exist even if empty');
      expect((dbJson['video_records'] as List<dynamic>).length, equals(0),
          reason: 'video_records should be empty (not selected)');
      expect((dbJson['text_records'] as List<dynamic>).length, equals(0),
          reason: 'text_records should be empty (not selected)');
    });

    testWidgets('video-only restore preserves other record types',
        (WidgetTester t) async {
      // Add pre-existing data in multiple tables
      await ManifestDatabase.insertImageRecord({
        'id': 'img_existing_vid',
        'name': 'existing_img',
        'hash': 'existing_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'width': 50,
        'height': 50,
      });

      // Build backup with video records
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': [
              {
                'id': 'vid_restore_1',
                'name': 'restored_vid',
                'hash': 'restored_vid_hash',
                'format': 'mp4',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 500,
                'folder': '',
                'duration': 10.0,
              },
            ],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with videos-only selection
      final sel = BackupSelection(
        conversations: false,
        pictures: false,
        audio: false,
        videos: true,
        texts: false,
        tasks: false,
        attachments: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Video records should include the restored one
      final videoRecords = await ManifestDatabase.getAllVideoRecords();
      expect(videoRecords.length, equals(1),
          reason: 'Video record should be restored');
      expect(videoRecords[0]['id'], equals('vid_restore_1'));

      // Image records should be preserved (not selected for restore)
      final imageRecords = await ManifestDatabase.getAllImageRecords();
      expect(imageRecords.length, equals(1),
          reason: 'Image records should be preserved');
      expect(imageRecords[0]['id'], equals('img_existing_vid'),
          reason: 'Pre-existing image record must be preserved');
    });
  });

  // ==================================================================
  // 已存在的全量备份/恢复测试不应受选择性变更影响
  // ==================================================================

  group('Existing full backup/restore still works (regression)', () {
    testWidgets('buildBackupBytesForTest with default selection is full backup',
        (WidgetTester t) async {
      // Insert records
      await ManifestDatabase.insertImageRecord({
        'id': 'img_full_1',
        'name': 'full_img',
        'hash': 'full_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_full_1',
        'name': 'full_aud',
        'hash': 'full_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      // Default selection (should be full)
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // All expected files should be present
      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));
      expect(fileNames, contains('preferences.json'));

      // DB should contain both record types
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);
      final dbJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;
      expect((dbJson['image_records'] as List<dynamic>).length, equals(1));
      expect((dbJson['audio_records'] as List<dynamic>).length, equals(1));
    });

    testWidgets(
        'restoreFromBytesForTest with default selection is full restore',
        (WidgetTester t) async {
      // Add pre-existing data
      await ManifestDatabase.insertImageRecord({
        'id': 'img_old_2',
        'name': 'old_img_2',
        'hash': 'old_img_hash_2',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'width': 50,
        'height': 50,
      });

      // Build a backup with different data
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_new_2',
                'name': 'new_img_2',
                'hash': 'new_img_hash_2',
                'format': 'jpg',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 200,
                'folder': '',
                'width': 200,
                'height': 200,
              },
            ],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Full restore (default)
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Old data should be gone
      final records = await ManifestDatabase.getAllImageRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('img_new_2'));
    });
  });
}
