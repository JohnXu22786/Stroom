import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  // ==================================================================
  // BackupSelection 类行为（新字段）
  // ==================================================================

  group('BackupSelection class', () {
    test('BackupSelection.all.selectedLabels returns all 9 labels', () {
      final labels = BackupSelection.all.selectedLabels;
      expect(labels.length, equals(9));
      expect(labels, contains('聊天记录和附件'));
      expect(labels, contains('设置'));
      expect(labels, contains('图片'));
      expect(labels, contains('音频'));
      expect(labels, contains('视频'));
      expect(labels, contains('文本'));
      expect(labels, contains('任务'));
      expect(labels, contains('Anki闪卡数据'));
      expect(labels, contains('浏览器Cookies'));
    });

    test('BackupSelection with pictures-only returns correct labels', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('图片'));
    });

    test('all flags false returns empty selectedLabels', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final labels = sel.selectedLabels;
      expect(labels, isEmpty,
          reason:
              'With all flags false including ankiData, selectedLabels should be empty');
    });

    test('ankiData-only shows 1 label', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: true,
        browserCookies: false,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('Anki闪卡数据'));
    });

    test('chatRecordsAndAttachments-only shows 1 label', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('聊天记录和附件'));
    });

    test('settings-only shows 1 label', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('设置'));
    });

    test('browserCookies-only shows 1 label', () {
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: true,
      );
      final labels = sel.selectedLabels;
      expect(labels.length, equals(1));
      expect(labels.first, equals('浏览器Cookies'));
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
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
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

      // Should NOT contain chat_data.json or settings.json (both false)
      expect(fileNames, isNot(contains('chat_data.json')));
      expect(fileNames, isNot(contains('settings.json')));

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

    testWidgets(
        'backup with chatRecordsAndAttachments includes chat_data.json and no settings.json',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[]',
        'assistants': '[{"id":"a1","name":"测试助手"}]',
        'per_model_chat_settings': '{}',
        'selected_model_index': 0,
        'model_order': '[]',
        'provider_entries': '[]',
        'data_format_version': 2,
      });

      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(
        selection: sel,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('chat_data.json'));
      expect(fileNames, isNot(contains('settings.json')));

      // Verify settings keys are NOT in chat_data.json
      Uint8List? chatDataRaw;
      for (final f in archive) {
        if (f.isFile && f.name == 'chat_data.json') {
          chatDataRaw = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(chatDataRaw, isNotNull);
      final chatData =
          jsonDecode(utf8.decode(chatDataRaw!)) as Map<String, dynamic>;
      expect(chatData.containsKey('assistants'), isFalse,
          reason:
              'assistants should NOT be in chat_data.json; it belongs to settings');
      expect(chatData.containsKey('per_model_chat_settings'), isFalse,
          reason:
              'per_model_chat_settings should NOT be in chat_data.json; it belongs to settings');
      expect(chatData.containsKey('selected_model_index'), isFalse,
          reason:
              'selected_model_index should NOT be in chat_data.json; it belongs to settings');
      expect(chatData.containsKey('model_order'), isFalse,
          reason:
              'model_order should NOT be in chat_data.json; it belongs to settings');
    });

    testWidgets(
        'backup with settings-only includes settings.json and no chat_data.json',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[]',
        'assistants': '[{"id":"a1","name":"测试助手"}]',
        'per_model_chat_settings': '{}',
        'selected_model_index': 0,
        'model_order': '[]',
        'provider_entries': '[]',
        'data_format_version': 2,
      });

      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(
        selection: sel,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('settings.json'));
      expect(fileNames, isNot(contains('chat_data.json')));

      // Verify all settings keys ARE in settings.json
      Uint8List? settingsDataRaw;
      for (final f in archive) {
        if (f.isFile && f.name == 'settings.json') {
          settingsDataRaw = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(settingsDataRaw, isNotNull);
      final settingsData =
          jsonDecode(utf8.decode(settingsDataRaw!)) as Map<String, dynamic>;
      expect(settingsData.containsKey('assistants'), isTrue,
          reason:
              'assistants should be in settings.json when settings-only backup is selected');
      expect(settingsData.containsKey('per_model_chat_settings'), isTrue,
          reason:
              'per_model_chat_settings should be in settings.json when settings-only backup is selected');
      expect(settingsData.containsKey('selected_model_index'), isTrue,
          reason:
              'selected_model_index should be in settings.json when settings-only backup is selected');
      expect(settingsData.containsKey('model_order'), isTrue,
          reason:
              'model_order should be in settings.json when settings-only backup is selected');
    });
  });

  // ==================================================================
  // 助手设置分类：assistants 键应归为"设置"而非"聊天记录和附件"
  // ==================================================================

  group('Assistant settings classification', () {
    testWidgets(
        'full backup: assistants goes to settings.json, conversations goes to chat_data.json',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'active_conversation_id': 'conv1',
        'assistants': '[{"id":"a1","name":"测试助手","prompt":"你好"}]',
        'per_model_chat_settings': '{"gpt-4":{"reasoningEnabled":true}}',
        'selected_model_index': 0,
        'model_order': '["gpt-4","gpt-3.5"]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'data_format_version': 2,
      });

      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(
        selection: sel,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('chat_data.json'));
      expect(fileNames, contains('settings.json'));

      // Verify assistants is in settings.json (not chat_data.json)
      Uint8List? settingsDataRaw;
      Uint8List? chatDataRaw;
      for (final f in archive) {
        if (f.isFile && f.name == 'settings.json') {
          settingsDataRaw = Uint8List.fromList(f.content as List<int>);
        }
        if (f.isFile && f.name == 'chat_data.json') {
          chatDataRaw = Uint8List.fromList(f.content as List<int>);
        }
      }
      expect(settingsDataRaw, isNotNull);
      expect(chatDataRaw, isNotNull);

      final settingsData =
          jsonDecode(utf8.decode(settingsDataRaw!)) as Map<String, dynamic>;
      final chatData =
          jsonDecode(utf8.decode(chatDataRaw!)) as Map<String, dynamic>;

      // All settings keys should be in settings.json
      expect(settingsData.containsKey('assistants'), isTrue,
          reason: 'assistants must be in settings.json (settings, not chat)');
      expect(settingsData.containsKey('per_model_chat_settings'), isTrue,
          reason:
              'per_model_chat_settings must be in settings.json (settings, not chat)');
      expect(settingsData.containsKey('selected_model_index'), isTrue,
          reason:
              'selected_model_index must be in settings.json (settings, not chat)');
      expect(settingsData.containsKey('model_order'), isTrue,
          reason: 'model_order must be in settings.json (settings, not chat)');

      // All settings keys should NOT be in chat_data.json
      expect(chatData.containsKey('assistants'), isFalse,
          reason: 'assistants must NOT be in chat_data.json');
      expect(chatData.containsKey('per_model_chat_settings'), isFalse,
          reason: 'per_model_chat_settings must NOT be in chat_data.json');
      expect(chatData.containsKey('selected_model_index'), isFalse,
          reason: 'selected_model_index must NOT be in chat_data.json');
      expect(chatData.containsKey('model_order'), isFalse,
          reason: 'model_order must NOT be in chat_data.json');

      // conversations should still be in chat_data.json
      expect(chatData.containsKey('conversations'), isTrue,
          reason: 'conversations should still be in chat_data.json');
      expect(chatData.containsKey('active_conversation_id'), isTrue,
          reason: 'active_conversation_id should still be in chat_data.json');

      // provider_entries should still be in settings.json
      expect(settingsData.containsKey('provider_entries'), isTrue,
          reason: 'provider_entries should be in settings.json');
    });
  });

  // ==================================================================
  // 选择性恢复：仅恢复选中的类别
  // ==================================================================

  group('Selective restore only restores selected categories', () {
    testWidgets(
        'pictures-only restore: images replaced, unselected records PRESERVED',
        (WidgetTester t) async {
      // Add pre-existing data for multiple types
      await ManifestDatabase.insertImageRecord({
        'id': 'img_old',
        'name': 'old_img',
        'hash': 'old_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'width': 50,
        'height': 50,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_old',
        'name': 'old_aud',
        'hash': 'old_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_old',
        'name': 'old_vid',
        'hash': 'old_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      // Build backup with new data for ALL types
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_new',
                'name': 'new_img',
                'hash': 'new_hash',
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
                'id': 'aud_new',
                'name': 'new_aud',
                'hash': 'new_aud_hash',
                'format': 'wav',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 200,
                'folder': '',
                'duration': 2.0,
              },
            ],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with pictures-only selection
      final sel = BackupSelection(
        pictures: true,
        audio: false, // unselected → will be PRESERVED
        videos: false, // unselected → will be PRESERVED
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Selected: image records replaced from backup
      final imgRecords = await ManifestDatabase.getAllImageRecords();
      expect(imgRecords.length, equals(1));
      expect(imgRecords[0]['id'], equals('img_new'),
          reason: 'Selected image records should be restored from backup');

      // Unselected: audio records PRESERVED (not cleared)
      final audRecords = await ManifestDatabase.getAllAudioRecords();
      expect(audRecords.length, equals(1),
          reason:
              'Unselected audio records must be preserved (user did not select audio)');
      expect(audRecords[0]['id'], equals('aud_old'),
          reason: 'Pre-existing audio record should remain unchanged');

      // Unselected: video records PRESERVED
      final vidRecords = await ManifestDatabase.getAllVideoRecords();
      expect(vidRecords.length, equals(1),
          reason:
              'Unselected video records must be preserved (user did not select video)');
      expect(vidRecords[0]['id'], equals('vid_old'),
          reason: 'Pre-existing video record should remain unchanged');
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
            'version': 2,
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

    testWidgets(
        'restore old v1 backup with preferences.json maps keys correctly',
        (WidgetTester t) async {
      // Set up old format preferences with chat and settings keys
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'active_conversation_id': 'conv1',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'data_format_version': 1,
      });

      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }

      // Build an old-format (v1) backup with preferences.json
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      archive.addFile(ArchiveFile(
          'preferences.json', 0, utf8.encode(jsonEncode(prefData))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Clear state
      SharedPreferences.setMockInitialValues({});

      // Restore with chatRecordsAndAttachments + settings (full restore of prefs)
      await BackupService.restoreFromBytesForTest(backupBytes);

      final restoredPrefs = await SharedPreferences.getInstance();
      expect(restoredPrefs.getString('conversations'), isNotNull,
          reason: 'Chat key should be restored from v1 backup');
      expect(restoredPrefs.getString('provider_entries'), isNotNull,
          reason: 'Settings key should be restored from v1 backup');
    });

    testWidgets(
        'full v2 restore merges chat_data.json and settings.json correctly',
        (WidgetTester t) async {
      // Regression test: _restorePreferencesFromJson clears all keys on each call,
      // so separate calls for chat_data.json and settings.json would lose data.
      // The restore must merge both files before calling restore once.
      SharedPreferences.setMockInitialValues({});

      // Build a v2 backup with both chat_data.json and settings.json
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      // Chat data
      archive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"conv1"}]',
            'active_conversation_id': 'conv1',
          }))));
      // Settings data
      archive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'provider_entries': '[{"id":"p1"}]',
            'data_format_version': 1,
          }))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Full restore (default selection = chatRecordsAndAttachments + settings)
      await BackupService.restoreFromBytesForTest(backupBytes);

      // Verify BOTH chat and settings keys survived
      final restoredPrefs = await SharedPreferences.getInstance();
      expect(restoredPrefs.getString('conversations'), isNotNull,
          reason: 'Chat key must survive full v2 restore (regression)');
      expect(restoredPrefs.getString('active_conversation_id'), isNotNull,
          reason: 'Chat key must survive full v2 restore (regression)');
      expect(restoredPrefs.getString('provider_entries'), isNotNull,
          reason: 'Settings key must survive full v2 restore (regression)');
      // 恢复后 migrateDataFormatIfNeeded 按恢复的数据重建版本记录：
      // settings 类别恢复（含旧版 data_format_version=1）后展开迁移，
      // settings 部分必须是当前版本。
      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partSettings], equals(1),
          reason: 'Settings part version must be current after restore');
      expect(restoredPrefs.containsKey('data_format_versions'), isTrue,
          reason: 'Per-part version record must exist after restore');
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
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: true,
        videos: false,
        texts: false,
        tasks: true,
      );
      final bytes = await BackupService.buildBackupBytesForTest(selection: sel);
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));

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

    testWidgets(
        'video-only restore: videos replaced, unselected records PRESERVED',
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
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_existing',
        'name': 'existing_aud',
        'hash': 'existing_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      // Build backup with video records
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
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
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: true,
        texts: false,
        tasks: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Selected: video records restored from backup
      final videoRecords = await ManifestDatabase.getAllVideoRecords();
      expect(videoRecords.length, equals(1),
          reason: 'Video record should be restored');
      expect(videoRecords[0]['id'], equals('vid_restore_1'));

      // Unselected: image records PRESERVED
      final imageRecords = await ManifestDatabase.getAllImageRecords();
      expect(imageRecords.length, equals(1),
          reason:
              'Unselected image records must be preserved (user did not select pictures)');
      expect(imageRecords[0]['id'], equals('img_existing_vid'),
          reason: 'Pre-existing image record should remain unchanged');

      // Unselected: audio records PRESERVED
      final audioRecords = await ManifestDatabase.getAllAudioRecords();
      expect(audioRecords.length, equals(1),
          reason:
              'Unselected audio records must be preserved (user did not select audio)');
      expect(audioRecords[0]['id'], equals('aud_existing'),
          reason: 'Pre-existing audio record should remain unchanged');
    });
  });

  // ==================================================================
  // 已存在的全量备份/恢复测试不应受选择性变更影响
  // ==================================================================

  // ==================================================================
  // 选择性恢复 SharedPreferences：部分选择只替换选中的键，未选中的键保持原样
  // ==================================================================
  //
  // 新行为：选择 chat 时只替换 chat 键（清除现有 chat 键后写入备份值），
  // settings 键保持原样；选择 settings 时同理；两者都不选时保留所有偏好。

  group('Selective SharedPreferences restore preserves unselected keys', () {
    testWidgets('v2 restore: chat-only selection preserves settings',
        (WidgetTester t) async {
      // Set up existing preferences with both chat and settings data
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1","messages":[]}]',
        'active_conversation_id': 'conv1',
        'assistants': '[{"id":"a1","name":"测试助手","prompt":"你好"}]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'per_model_chat_settings': '{"gpt-4":{"reasoningEnabled":true}}',
        'selected_model_index': 0,
        'model_order': '["gpt-4"]',
        'data_format_version': 2,
      });

      // Build a v2 backup archive with DIFFERENT chat data and DIFFERENT settings
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      // New chat data from backup
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"conv_backup","messages":[]}]',
            'active_conversation_id': 'conv_backup',
          }))));
      // New settings data from backup (DIFFERENT from existing)
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"a_backup","name":"备份助手","prompt":"hi"}]',
            'provider_entries': '[{"id":"p_backup","type":"llm"}]',
            'data_format_version': 2,
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with chatRecordsAndAttachments ONLY (NOT settings)
      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false, // <-- settings NOT selected
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // Chat keys should be restored from backup
      expect(
        restoredPrefs.getString('conversations'),
        contains('conv_backup'),
        reason: 'Chat conversations should be restored from backup',
      );
      expect(
        restoredPrefs.getString('active_conversation_id'),
        equals('conv_backup'),
        reason: 'Active conversation ID should be restored from backup',
      );

      // Settings keys should be PRESERVED (not cleared)
      // (settings was NOT selected for restore, so existing values must stay)
      final assistants = restoredPrefs.getString('assistants');
      expect(assistants, contains('测试助手'),
          reason:
              'Settings (assistants) must be preserved when only chat is restored');

      final provEntries = restoredPrefs.getString('provider_entries');
      expect(provEntries, contains('p1'),
          reason:
              'Settings (provider_entries) must be preserved when only chat is restored');

      expect(
          restoredPrefs.getString('per_model_chat_settings'), contains('gpt-4'),
          reason: 'Settings (per_model_chat_settings) must be preserved');
      expect(restoredPrefs.getInt('selected_model_index'), equals(0),
          reason: 'Settings (selected_model_index) must be preserved');
    });

    testWidgets('v2 restore: settings-only selection preserves chat',
        (WidgetTester t) async {
      // Set up existing preferences with both chat and settings data
      SharedPreferences.setMockInitialValues({
        'conversations':
            '[{"id":"original_conv","messages":[{"role":"user","content":"hello"}]}]',
        'active_conversation_id': 'original_conv',
        'assistants': '[{"id":"a1","name":"原始助手","prompt":"你好"}]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'per_model_chat_settings': '{}',
        'selected_model_index': 0,
        'model_order': '["gpt-4"]',
        'data_format_version': 2,
      });

      // Build a v2 backup archive with DIFFERENT settings data
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"backup_conv","messages":[]}]',
            'active_conversation_id': 'backup_conv',
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"a_backup","name":"备份助手"}]',
            'provider_entries': '[{"id":"p_backup","type":"llm"}]',
            'per_model_chat_settings':
                '{"gpt-4-backup":{"reasoningEnabled":false}}',
            'selected_model_index': 1,
            'model_order': '["gpt-4-backup"]',
            'data_format_version': 2,
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with settings ONLY (NOT chatRecordsAndAttachments)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false, // <-- chat NOT selected
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // Settings keys should be restored from backup
      expect(
        restoredPrefs.getString('assistants'),
        contains('备份助手'),
        reason: 'Settings (assistants) should be restored from backup',
      );
      expect(
        restoredPrefs.getString('provider_entries'),
        contains('p_backup'),
        reason: 'Settings (provider_entries) should be restored from backup',
      );

      // Chat keys should be PRESERVED (not cleared)
      // (chat was NOT selected for restore, so existing values must stay)
      final conversations = restoredPrefs.getString('conversations');
      expect(conversations, contains('original_conv'),
          reason:
              'Chat (conversations) must be preserved when only settings is restored');

      expect(restoredPrefs.getString('active_conversation_id'),
          equals('original_conv'),
          reason: 'Chat (active_conversation_id) must be preserved');
    });

    testWidgets(
        'v2 restore: deselecting BOTH chat AND settings preserves all preferences',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'active_conversation_id': 'conv1',
        'assistants': '[{"id":"a1","name":"助手"}]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'data_format_version': 2,
      });

      // Build a v2 backup with different data
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"alt_conv"}]',
            'active_conversation_id': 'alt_conv',
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"alt_a"}]',
            'provider_entries': '[{"id":"alt_p"}]',
            'data_format_version': 2,
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with NEITHER chat nor settings
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // All original data must be preserved (nothing was selected for restore)
      expect(restoredPrefs.getString('conversations'), contains('conv1'),
          reason: 'Original chat must be preserved when nothing is restored');
      expect(restoredPrefs.getString('assistants'), contains('助手'),
          reason:
              'Original settings must be preserved when nothing is restored');
      expect(restoredPrefs.getString('provider_entries'), contains('p1'),
          reason:
              'Original provider_entries must be preserved when nothing is restored');
    });

    testWidgets(
        'v2 restore: chat selected but backup has no chat_data.json → existing chat keys cleared',
        (WidgetTester t) async {
      // Existing chat + settings data
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"existing_conv"}]',
        'active_conversation_id': 'existing_conv',
        'assistants': '[{"id":"existing_a"}]',
        'data_format_version': 2,
      });

      // Build a v2 backup WITHOUT chat_data.json (only settings.json)
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"backup_a"}]',
            'data_format_version': 2,
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ONLY chat selected (settings NOT selected)
      final sel = BackupSelection(
        chatRecordsAndAttachments: true, // <-- selected
        settings: false, // <-- must be preserved
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();
      // Selected category with no backup data → cleared
      expect(restoredPrefs.getString('conversations'), isNull,
          reason:
              'Selected chat category must be cleared even when the backup has no chat_data.json');
      expect(restoredPrefs.getString('active_conversation_id'), isNull,
          reason: 'Selected chat category must be cleared');
      // Unselected settings → preserved
      expect(restoredPrefs.getString('assistants'), contains('existing_a'),
          reason: 'Unselected settings must be preserved');
    });

    testWidgets(
        'v2 restore: full restore (both chat AND settings) still clears and replaces all',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"old_conv"}]',
        'active_conversation_id': 'old_conv',
        'assistants': '[{"id":"old_a"}]',
        'provider_entries': '[{"id":"old_p"}]',
        'old_legacy_key': 'should_be_removed',
        'data_format_version': 2,
      });

      // Build a v2 backup
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"new_conv"}]',
            'active_conversation_id': 'new_conv',
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"new_a"}]',
            'provider_entries': '[{"id":"new_p"}]',
            'data_format_version': 2,
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Full restore (BOTH chat and settings)
      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // New data should replace old
      expect(restoredPrefs.getString('conversations'), contains('new_conv'),
          reason: 'Full restore should replace chat data');
      expect(restoredPrefs.getString('assistants'), contains('new_a'),
          reason: 'Full restore should replace settings data');
      expect(restoredPrefs.getString('provider_entries'), contains('new_p'),
          reason: 'Full restore should replace provider_entries');

      // Old data should be gone
      expect(
          restoredPrefs.getString('conversations'), isNot(contains('old_conv')),
          reason: 'Full restore should remove old chat data');

      // Legacy key not in backup should be removed
      expect(restoredPrefs.getString('old_legacy_key'), isNull,
          reason: 'Full restore should remove keys not present in backup');
    });

    testWidgets(
        'v1 restore: chat-only selection preserves settings (preferences.json split by key)',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"v1_orig_conv"}]',
        'active_conversation_id': 'v1_orig_conv',
        'assistants': '[{"id":"v1_orig_a","name":"原始助手"}]',
        'provider_entries': '[{"id":"v1_orig_p","type":"llm"}]',
        'data_format_version': 1,
      });

      // Build a v1 backup
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      archive.addFile(ArchiveFile(
          'preferences.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"v1_backup_conv"}]',
            'active_conversation_id': 'v1_backup_conv',
            'assistants': '[{"id":"v1_backup_a","name":"备份助手"}]',
            'provider_entries': '[{"id":"v1_backup_p","type":"llm"}]',
            'data_format_version': 1,
          }))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore v1 with chat-only selection
      // v1 merges chat+settings in a single preferences.json, but the
      // restore splits it back by key classification: chat-only restores
      // only the chat keys and leaves settings keys untouched.
      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false, // <-- not selected, must be preserved
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // Chat should be restored from backup
      expect(
          restoredPrefs.getString('conversations'), contains('v1_backup_conv'),
          reason: 'v1 restore should restore chat from preferences.json');

      // Settings preserved: the merged preferences.json is split by key
      // classification, so settings keys keep their original values.
      expect(restoredPrefs.getString('assistants'), contains('v1_orig_a'),
          reason:
              'Settings must be preserved when only chat is restored (v1 split by key)');
      expect(restoredPrefs.getString('provider_entries'), contains('v1_orig_p'),
          reason: 'Settings must be preserved (v1 split by key)');
    });

    testWidgets(
        'v1 restore: settings-only selection preserves chat (preferences.json split by key)',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"v1_orig_conv2"}]',
        'active_conversation_id': 'v1_orig_conv2',
        'assistants': '[{"id":"v1_orig_a2","name":"原始助手2"}]',
        'provider_entries': '[{"id":"v1_orig_p2","type":"llm"}]',
        'data_format_version': 1,
      });

      // Build a v1 backup
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      archive.addFile(ArchiveFile(
          'preferences.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"v1_backup_conv2"}]',
            'active_conversation_id': 'v1_backup_conv2',
            'assistants': '[{"id":"v1_backup_a2","name":"备份助手2"}]',
            'provider_entries': '[{"id":"v1_backup_p2","type":"llm"}]',
            'data_format_version': 1,
          }))));

      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore v1 with settings-only selection
      final sel = BackupSelection(
        chatRecordsAndAttachments: false, // <-- not selected, must be preserved
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final restoredPrefs = await SharedPreferences.getInstance();

      // Settings should be restored from backup
      expect(restoredPrefs.getString('assistants'), contains('备份助手2'),
          reason: 'Settings should be restored from v1 preferences.json');
      expect(
          restoredPrefs.getString('provider_entries'), contains('v1_backup_p2'),
          reason: 'Settings should be restored from v1 preferences.json');

      // Chat preserved: only settings keys are restored from the merged file
      expect(
          restoredPrefs.getString('conversations'), contains('v1_orig_conv2'),
          reason:
              'Chat must be preserved when only settings is restored (v1 split by key)');
      expect(restoredPrefs.getString('active_conversation_id'),
          equals('v1_orig_conv2'),
          reason: 'Chat must be preserved (v1 split by key)');
    });
  });

  // ==================================================================
  // 全面检查：所有 9 个类别在选择性备份和恢复中的行为一致性
  // ==================================================================
  //
  // 新行为：选中的类别恢复（清空后还原），未选中的类别保持原样，
  // 什么都没选则全部保留。本 group 对所有 9 个类别逐一验证。

  group('Comprehensive selective backup/restore audit for all 9 categories',
      () {
    // ----------------------------------------------------------------
    // 选择性备份：验证未选中的类别排除在归档之外
    // ----------------------------------------------------------------

    testWidgets('selective backup: deselected categories excluded from archive',
        (WidgetTester t) async {
      // Insert test records for ALL 4 DB-based types
      await ManifestDatabase.insertImageRecord({
        'id': 'img_audit',
        'name': 'audit_img',
        'hash': 'audit_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_audit',
        'name': 'audit_aud',
        'hash': 'audit_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_audit',
        'name': 'audit_vid',
        'hash': 'audit_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_audit',
        'name': 'audit_txt',
        'hash': 'audit_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"audit_conv"}]',
        'assistants': '[{"id":"audit_a"}]',
        'provider_entries': '[{"id":"audit_p"}]',
        'data_format_version': 2,
      });

      // Backup with ONLY pictures selected (all other 8 categories deselected)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final bytes = await BackupService.buildBackupBytesForTest(selection: sel);
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // Always present
      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));

      // Deselected categories: files must NOT be in archive
      expect(fileNames, isNot(contains('chat_data.json')),
          reason: 'chat_data.json must not be in pictures-only backup');
      expect(fileNames, isNot(contains('settings.json')),
          reason: 'settings.json must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('tts_audio/')), isFalse,
          reason: 'Audio files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('videos/')), isFalse,
          reason: 'Video files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('texts/')), isFalse,
          reason: 'Text files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('attachments/')), isFalse,
          reason: 'Attachment files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('synthesis/')), isFalse,
          reason: 'Task files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('catcatch/')), isFalse,
          reason: 'Task files must not be in pictures-only backup');
      expect(fileNames.any((n) => n.startsWith('anki/')), isFalse,
          reason: 'Anki files must not be in pictures-only backup');
      expect(fileNames, isNot(contains('browser_cookies.json')),
          reason: 'browser_cookies.json must not be in pictures-only backup');

      // Verify stroom_manifest.json: deselected types have empty arrays
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
      expect((dbJson['image_records'] as List<dynamic>).length, greaterThan(0),
          reason: 'Image records must be included when pictures is selected');
      expect((dbJson['audio_records'] as List<dynamic>).length, equals(0),
          reason: 'Audio records must be empty when audio is deselected');
      expect((dbJson['video_records'] as List<dynamic>).length, equals(0),
          reason: 'Video records must be empty when videos is deselected');
      expect((dbJson['text_records'] as List<dynamic>).length, equals(0),
          reason: 'Text records must be empty when texts is deselected');
    });

    // ----------------------------------------------------------------
    // 选择性恢复：验证未选择任何 DB 类别时保留所有数据，部分选择时未选类别保持原样
    // ----------------------------------------------------------------

    testWidgets(
        'selective restore with NOTHING selected preserves ALL existing DB records',
        (WidgetTester t) async {
      // Insert records for all 4 types
      await ManifestDatabase.insertImageRecord({
        'id': 'img_preserve',
        'name': 'p_img',
        'hash': 'p_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_preserve',
        'name': 'p_aud',
        'hash': 'p_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_preserve',
        'name': 'p_vid',
        'hash': 'p_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_preserve',
        'name': 'p_txt',
        'hash': 'p_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });

      // Build a full backup with DIFFERENT data
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_backup',
                'name': 'b_img',
                'hash': 'b_img_hash',
                'format': 'jpg',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'width': 999,
                'height': 999,
              },
            ],
            'audio_records': [
              {
                'id': 'aud_backup',
                'name': 'b_aud',
                'hash': 'b_aud_hash',
                'format': 'wav',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'duration': 99.0,
              },
            ],
            'video_records': [
              {
                'id': 'vid_backup',
                'name': 'b_vid',
                'hash': 'b_vid_hash',
                'format': 'mp4',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'duration': 99.0,
              },
            ],
            'text_records': [
              {
                'id': 'txt_backup',
                'name': 'b_txt',
                'hash': 'b_txt_hash',
                'format': 'txt',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'textLength': 999,
              },
            ],
            'folders': <String>[],
          }))));
      // Also include chat and settings to test SharedPreferences preservation
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"backup_conv"}]',
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"backup_a"}]',
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"original_conv"}]',
        'assistants': '[{"id":"original_a"}]',
      });

      // Restore with ABSOLUTELY NOTHING selected
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // ALL existing DB records must be preserved
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1));
      expect(images[0]['id'], equals('img_preserve'),
          reason: 'Pre-existing image records must be preserved');

      final audios = await ManifestDatabase.getAllAudioRecords();
      expect(audios.length, equals(1));
      expect(audios[0]['id'], equals('aud_preserve'),
          reason: 'Pre-existing audio records must be preserved');

      final videos = await ManifestDatabase.getAllVideoRecords();
      expect(videos.length, equals(1));
      expect(videos[0]['id'], equals('vid_preserve'),
          reason: 'Pre-existing video records must be preserved');

      final texts = await ManifestDatabase.getAllTextRecords();
      expect(texts.length, equals(1));
      expect(texts[0]['id'], equals('txt_preserve'),
          reason: 'Pre-existing text records must be preserved');

      // SharedPreferences must also be preserved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), contains('original_conv'),
          reason: 'Chat must be preserved when chat is deselected');
      expect(prefs.getString('assistants'), contains('original_a'),
          reason: 'Settings must be preserved when settings is deselected');
    });

    // ----------------------------------------------------------------
    // 选择性恢复：每次只选一个类别，验证只有该类别被替换
    // ----------------------------------------------------------------

    testWidgets(
        'selective restore: only the selected category is restored, all others preserved',
        (WidgetTester t) async {
      // Insert pre-existing records for all 4 DB types
      await ManifestDatabase.insertImageRecord({
        'id': 'img_pre',
        'name': 'pre_img',
        'hash': 'pre_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'width': 50,
        'height': 50,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_pre',
        'name': 'pre_aud',
        'hash': 'pre_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'duration': 0.5,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_pre',
        'name': 'pre_vid',
        'hash': 'pre_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'duration': 0.5,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_pre',
        'name': 'pre_txt',
        'hash': 'pre_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'textLength': 50,
      });

      // Build backup with DIFFERENT data for ALL 4 types
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': [
              {
                'id': 'img_new',
                'name': 'new_img',
                'hash': 'new_img_hash',
                'format': 'jpg',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'width': 999,
                'height': 999,
              },
            ],
            'audio_records': [
              {
                'id': 'aud_new',
                'name': 'new_aud',
                'hash': 'new_aud_hash',
                'format': 'wav',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'duration': 99.0,
              },
            ],
            'video_records': [
              {
                'id': 'vid_new',
                'name': 'new_vid',
                'hash': 'new_vid_hash',
                'format': 'mp4',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'duration': 99.0,
              },
            ],
            'text_records': [
              {
                'id': 'txt_new',
                'name': 'new_txt',
                'hash': 'new_txt_hash',
                'format': 'txt',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'textLength': 999,
              },
            ],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ONLY videos selected (all other categories deselected)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: true,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Only videos should be replaced; all others PRESERVED
      final videos = await ManifestDatabase.getAllVideoRecords();
      expect(videos.length, equals(1));
      expect(videos[0]['id'], equals('vid_new'),
          reason: 'Videos must be replaced from backup');

      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Images must be preserved (not selected)');
      expect(images[0]['id'], equals('img_pre'),
          reason: 'Pre-existing image records must remain unchanged');

      final audios = await ManifestDatabase.getAllAudioRecords();
      expect(audios.length, equals(1),
          reason: 'Audio must be preserved (not selected)');
      expect(audios[0]['id'], equals('aud_pre'),
          reason: 'Pre-existing audio records must remain unchanged');

      final texts = await ManifestDatabase.getAllTextRecords();
      expect(texts.length, equals(1),
          reason: 'Texts must be preserved (not selected)');
      expect(texts[0]['id'], equals('txt_pre'),
          reason: 'Pre-existing text records must remain unchanged');
    });

    // ----------------------------------------------------------------
    // 选择性备份 + 全量恢复：验证从选择性备份全量恢复会清除未选类别的数据
    // （这是正确但可能令人意外的行为 —— 用户需要知道这个后果）
    // ----------------------------------------------------------------

    testWidgets(
        'FULL restore from SELECTIVE backup clears categories that were not in backup',
        (WidgetTester t) async {
      // Scenario: user does a selective backup WITHOUT videos, then a full restore
      // Result: video records are cleared (backup has empty video data, full restore clears all)

      // Insert pre-existing video records
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_will_be_lost',
        'name': 'lost_vid',
        'hash': 'lost_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 500,
        'folder': '',
        'duration': 10.0,
      });
      await ManifestDatabase.insertImageRecord({
        'id': 'img_will_be_replaced',
        'name': 'old_img',
        'hash': 'old_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });

      // Build a SELECTIVE backup (pictures only, no videos)
      final selBackup = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false, // <-- VIDEOS NOT INCLUDED
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      final backupBytes =
          await BackupService.buildBackupBytesForTest(selection: selBackup);

      // Now do a FULL restore from this selective backup
      await BackupService.restoreFromBytesForTest(backupBytes);
      // Default selection = BackupSelection.all (all true)

      // Image records should be replaced by backup data
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Image records should be restored from backup');
      expect(images[0]['id'], equals('img_will_be_replaced'),
          reason: 'Original image record should be restored from backup');

      // Video records: CLEARED because full restore clears all tables,
      // but backup has empty video_records (videos were not selected during backup)
      final videos = await ManifestDatabase.getAllVideoRecords();
      expect(videos.length, equals(0),
          reason:
              'Video records are cleared because full restore clears all tables, '
              'and the backup had empty video data (videos were not in the backup)');
    });

    // ----------------------------------------------------------------
    // 选择性恢复：每个类别单独验证正确行为
    // ----------------------------------------------------------------

    testWidgets('texts-only restore replaces text records, preserves others',
        (WidgetTester t) async {
      await ManifestDatabase.insertImageRecord({
        'id': 'img_keep',
        'name': 'keep_img',
        'hash': 'keep_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_old',
        'name': 'old_txt',
        'hash': 'old_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'textLength': 10,
      });

      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': [
              {
                'id': 'txt_new',
                'name': 'new_txt',
                'hash': 'new_txt_hash',
                'format': 'txt',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'textLength': 999,
              },
            ],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      final sel = BackupSelection(
        pictures: false,
        audio: false,
        videos: false,
        texts: true, // <-- only texts selected
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final texts = await ManifestDatabase.getAllTextRecords();
      expect(texts.length, equals(1));
      expect(texts[0]['id'], equals('txt_new'));

      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Images preserved when only texts selected');
      expect(images[0]['id'], equals('img_keep'),
          reason: 'Pre-existing image records must remain unchanged');
    });

    testWidgets('audio-only restore replaces audio records, preserves others',
        (WidgetTester t) async {
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_keep',
        'name': 'keep_vid',
        'hash': 'keep_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'duration': 0.1,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_old',
        'name': 'old_aud',
        'hash': 'old_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'duration': 0.1,
      });

      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': [
              {
                'id': 'aud_new',
                'name': 'new_aud',
                'hash': 'new_aud_hash',
                'format': 'wav',
                'createdAt': DateTime.now().toIso8601String(),
                'size': 999,
                'folder': '',
                'duration': 99.0,
              },
            ],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      final sel = BackupSelection(
        pictures: false,
        audio: true, // <-- only audio selected
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      final audios = await ManifestDatabase.getAllAudioRecords();
      expect(audios.length, equals(1));
      expect(audios[0]['id'], equals('aud_new'));

      final videos = await ManifestDatabase.getAllVideoRecords();
      expect(videos.length, equals(1),
          reason: 'Videos preserved when only audio selected');
      expect(videos[0]['id'], equals('vid_keep'),
          reason: 'Pre-existing video records must remain unchanged');
    });

    // ----------------------------------------------------------------
    // 浏览器 Cookies 和 Anki 数据的选择性处理
    // ----------------------------------------------------------------

    testWidgets(
        'browserCookies: true restores file with correct content, false preserves pre-existing data',
        (WidgetTester t) async {
      final cookiesContent = 'mock_cookies_data';
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(
          ArchiveFile('browser_cookies.json', 0, utf8.encode(cookiesContent)));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Test 1: browserCookies selected → file should be restored with correct content
      final selTrue = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: true,
      );
      await BackupService.restoreFromBytesForTest(backupBytes,
          selection: selTrue);
      var written = await WebFileStore.read('/browser_cookies.json');
      expect(written, isNotNull,
          reason:
              'browser_cookies.json should be restored when browserCookies is true');
      expect(String.fromCharCodes(written!), equals(cookiesContent),
          reason: 'Restored browser_cookies.json content should match backup');

      // Clean up and verify cleanup succeeded
      await WebFileStore.delete('/browser_cookies.json');
      var afterDelete = await WebFileStore.read('/browser_cookies.json');
      expect(afterDelete, isNull,
          reason: 'Cleanup should remove browser_cookies.json before test 2');

      // Test 2: browserCookies deselected → backup file NOT restored,
      // pre-existing data is preserved (not cleared)
      await WebFileStore.write('/browser_cookies.json',
          Uint8List.fromList(utf8.encode('pre_existing_cookies')));
      final selFalse = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes,
          selection: selFalse);
      written = await WebFileStore.read('/browser_cookies.json');
      expect(written, isNotNull,
          reason:
              'Pre-existing browser_cookies.json should be preserved when browserCookies is false');
      expect(String.fromCharCodes(written!), equals('pre_existing_cookies'),
          reason: 'Pre-existing cookies content should be unchanged');
    });

    testWidgets(
        'ankiData: true restores file to live path, false preserves pre-existing anki data',
        (WidgetTester t) async {
      // Seed pre-existing anki data at the LIVE path (app data dir root)
      await WebFileStore.write('/collection.anki2',
          Uint8List.fromList(utf8.encode('pre_existing_anki')));
      // Build backup with anki data
      final ankiContent = 'mock_anki_content_for_restore';
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(
          ArchiveFile('anki/collection.anki2', 0, utf8.encode(ankiContent)));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Test 1: ankiData false → file NOT restored, pre-existing data preserved
      final selFalse = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes,
          selection: selFalse);

      var written = await WebFileStore.read('/collection.anki2');
      expect(written, isNotNull,
          reason:
              'Pre-existing anki data must be preserved when ankiData is false');
      expect(String.fromCharCodes(written!), equals('pre_existing_anki'),
          reason:
              'Pre-existing anki content should be unchanged when ankiData is false');

      // Clean up for test 2
      await WebFileStore.delete('/collection.anki2');

      // Test 2: ankiData true → file restored to the LIVE path with correct content
      final selTrue = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: true,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes,
          selection: selTrue);

      written = await WebFileStore.read('/collection.anki2');
      expect(written, isNotNull,
          reason:
              'collection.anki2 should be restored to the live path when ankiData is true');
      expect(String.fromCharCodes(written!), equals(ankiContent),
          reason: 'Restored anki content should match backup');
    });

    // ----------------------------------------------------------------
    // 任务文件选择性恢复
    // ----------------------------------------------------------------

    testWidgets(
        'tasks-only restore restores task files, preserves all DB records and SharedPreferences',
        (WidgetTester t) async {
      // Seed pre-existing data in all DB tables and SharedPreferences
      await ManifestDatabase.insertImageRecord({
        'id': 'img_keep_task',
        'name': 'keep_img',
        'hash': 'keep_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_keep_task',
        'name': 'keep_aud',
        'hash': 'keep_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'duration': 0.1,
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_keep_task',
        'name': 'keep_vid',
        'hash': 'keep_vid_hash',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'duration': 0.1,
      });
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_keep_task',
        'name': 'keep_txt',
        'hash': 'keep_txt_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'textLength': 10,
      });
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"keep_conv"}]',
        'assistants': '[{"id":"keep_a"}]',
        'provider_entries': '[{"id":"keep_p"}]',
      });

      // Build backup with task data
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile(
          'synthesis/tasks.json', 0, utf8.encode('["task_from_backup"]')));
      backupArchive.addFile(ArchiveFile(
          'catcatch/tasks.json', 0, utf8.encode('["catcatch_from_backup"]')));
      // Also include chat/settings in backup (should not be restored)
      backupArchive.addFile(ArchiveFile(
          'chat_data.json',
          0,
          utf8.encode(jsonEncode({
            'conversations': '[{"id":"backup_conv"}]',
          }))));
      backupArchive.addFile(ArchiveFile(
          'settings.json',
          0,
          utf8.encode(jsonEncode({
            'assistants': '[{"id":"backup_a"}]',
          }))));

      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ONLY tasks selected
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: true, // <-- only tasks selected
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Task files should be restored
      final synthesisData = await WebFileStore.read('synthesis/tasks.json');
      expect(synthesisData, isNotNull,
          reason:
              'synthesis/tasks.json should be restored when tasks is selected');
      final synthesisContent = String.fromCharCodes(synthesisData!);
      expect(synthesisContent, contains('task_from_backup'),
          reason: 'Synthesis tasks should contain backup data');

      final catcatchData = await WebFileStore.read('catcatch/tasks.json');
      expect(catcatchData, isNotNull,
          reason:
              'catcatch/tasks.json should be restored when tasks is selected');

      // All DB records must be preserved (not selected for restore)
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1));
      expect(images[0]['id'], equals('img_keep_task'),
          reason: 'Images preserved during tasks-only restore');

      final audios = await ManifestDatabase.getAllAudioRecords();
      expect(audios.length, equals(1));
      expect(audios[0]['id'], equals('aud_keep_task'));

      final videos = await ManifestDatabase.getAllVideoRecords();
      expect(videos.length, equals(1));
      expect(videos[0]['id'], equals('vid_keep_task'));

      final texts = await ManifestDatabase.getAllTextRecords();
      expect(texts.length, equals(1));
      expect(texts[0]['id'], equals('txt_keep_task'));

      // SharedPreferences must be preserved (not selected)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), contains('keep_conv'),
          reason: 'Chat preserved during tasks-only restore');
      expect(prefs.getString('assistants'), contains('keep_a'),
          reason: 'Settings preserved during tasks-only restore');
    });

    // ----------------------------------------------------------------
    // 文件夹选择性恢复：验证文件夹表按类型正确处理
    // ----------------------------------------------------------------

    testWidgets(
        'folder tables are preserved or replaced according to selection',
        (WidgetTester t) async {
      // Set up pre-existing folders for multiple types
      await ManifestDatabase.insertFolder('Folder_A',
          recordTable: ManifestTables.imageRecords);
      await ManifestDatabase.insertFolder('Folder_B',
          recordTable: ManifestTables.videoRecords);

      // Build backup with folders for images only
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
            ManifestTables.imageFolders: ['Backup_Folder_X'],
            ManifestTables.videoFolders: <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ONLY images selected (videos deselected)
      final sel = BackupSelection(
        pictures: true,
        audio: false,
        videos: false, // <-- videos not selected
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Image folders: cleared and replaced from backup
      final imgFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.imageRecords);
      expect(imgFolders, contains('Backup_Folder_X'),
          reason: 'Image folder from backup should be restored');
      expect(imgFolders, isNot(contains('Folder_A')),
          reason: 'Pre-existing image folder should be replaced');

      // Video folders: preserved (videos not selected for restore)
      final vidFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords);
      expect(vidFolders, contains('Folder_B'),
          reason:
              'Pre-existing video folder must be preserved (videos not selected)');
    });
  });

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

      SharedPreferences.setMockInitialValues({
        'conversations': '[]',
        'provider_entries': '[]',
      });

      // Default selection (should be full)
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // All expected files should be present
      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));
      // New format: both chat_data.json and settings.json should be present
      expect(fileNames, contains('chat_data.json'));
      expect(fileNames, contains('settings.json'));

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

    testWidgets('restore with ankiData:false skips anki data',
        (WidgetTester t) async {
      // Build a backup archive that includes an anki/ file
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      // Add anki data
      backupArchive.addFile(ArchiveFile(
          'anki/collection.anki2', 0, utf8.encode('mock anki db content')));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ankiData: false
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Verify anki file was NOT written to WebFileStore
      final written = await WebFileStore.read('/collection.anki2');
      expect(written, isNull,
          reason:
              'collection.anki2 should NOT be restored when ankiData is false');
    });

    testWidgets('restore with ankiData:true restores anki/ to live root path',
        (WidgetTester t) async {
      // Build a backup archive that includes an anki/ file
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      // Add anki data
      final ankiContent = 'mock anki db content for restore test';
      backupArchive.addFile(
          ArchiveFile('anki/collection.anki2', 0, utf8.encode(ankiContent)));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ankiData: true (but all others false)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: true,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Verify anki file WAS written to the LIVE root path in WebFileStore
      final written = await WebFileStore.read('/collection.anki2');
      expect(written, isNotNull,
          reason:
              'collection.anki2 should be restored to the live path when ankiData is true');
      final content = String.fromCharCodes(written!);
      expect(content, equals(ankiContent),
          reason: 'collection.anki2 content should match');
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
            'version': 2,
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

  // ==================================================================
  // 恢复"勾选即清空"：选中的文件类类别在备份中缺失对应文件时，
  // 现有文件也会被清除（与 DB/偏好设置类别语义一致）
  // ==================================================================

  group('Restore clears selected file categories even when backup lacks them',
      () {
    testWidgets(
        'selected file categories are cleared when backup has no files for them',
        (WidgetTester t) async {
      // Seed existing files for every file-based category
      await WebFileStore.write('/collection.anki2',
          Uint8List.fromList(utf8.encode('existing_anki')));
      await WebFileStore.write('/browser_cookies.json',
          Uint8List.fromList(utf8.encode('existing_cookies')));
      await WebFileStore.write(
          'synthesis/tasks.json', Uint8List.fromList(utf8.encode('["t1"]')));
      await WebFileStore.write(
          'catcatch/tasks.json', Uint8List.fromList(utf8.encode('["t2"]')));
      // Attachment files (referenced + orphan) — all under attachments/
      await WebFileStore.write(
          'attachments/ref.jpg', Uint8List.fromList(utf8.encode('ref_bytes')));
      await WebFileStore.write('attachments/orphan.bin',
          Uint8List.fromList(utf8.encode('orphan_bytes')));
      // Media record + file
      await ManifestDatabase.insertImageRecord({
        'id': 'img_sel_clear',
        'name': 'sel_clear',
        'hash': 'img_sel_clear_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await WebFileStore.write('pictures/img_sel_clear_hash.jpg',
          Uint8List.fromList(utf8.encode('img_bytes')));
      await WebFileStore.write(
          'pictures/${imageThumbFileName('img_sel_clear_hash')}',
          Uint8List.fromList(utf8.encode('thumb_bytes')));

      // Build a backup WITHOUT any of those files (empty stroom_manifest,
      // no chat_data/settings/tasks/anki/cookies/attachments)
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with all file-based categories selected
      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: true,
        ankiData: true,
        browserCookies: true,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Selected categories: existing files cleared even though the backup
      // has no corresponding files
      expect(await WebFileStore.read('/collection.anki2'), isNull,
          reason:
              'Selected anki category must be cleared when backup has no anki file');
      expect(await WebFileStore.read('/browser_cookies.json'), isNull,
          reason:
              'Selected cookies category must be cleared when backup has no cookies file');
      expect(await WebFileStore.read('synthesis/tasks.json'), isNull,
          reason:
              'Selected tasks category must be cleared when backup has no tasks file');
      expect(await WebFileStore.read('catcatch/tasks.json'), isNull,
          reason: 'Selected tasks category must be cleared');
      expect(await WebFileStore.read('attachments/ref.jpg'), isNull,
          reason:
              'Selected chat category must clear existing attachment files');
      expect(await WebFileStore.read('attachments/orphan.bin'), isNull,
          reason:
              'Selected chat category must clear orphan attachment files too');
      expect(await WebFileStore.read('pictures/img_sel_clear_hash.jpg'), isNull,
          reason: 'Selected pictures category must clear existing media files');
      expect(
          await WebFileStore.read(
              'pictures/${imageThumbFileName('img_sel_clear_hash')}'),
          isNull,
          reason: 'Selected pictures category must clear thumbnails too');

      // DB records also cleared (backup has empty records)
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(0),
          reason: 'Selected pictures records must be cleared');
    });

    testWidgets(
        'unselected file categories keep their files when backup lacks them',
        (WidgetTester t) async {
      // Seed files for categories that will NOT be selected
      await WebFileStore.write('/browser_cookies.json',
          Uint8List.fromList(utf8.encode('existing_cookies')));
      await WebFileStore.write('/collection.anki2',
          Uint8List.fromList(utf8.encode('existing_anki')));
      await WebFileStore.write('attachments/keep.bin',
          Uint8List.fromList(utf8.encode('keep_bytes')));
      await WebFileStore.write(
          'synthesis/tasks.json', Uint8List.fromList(utf8.encode('["t1"]')));

      // Backup without any files
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with ONLY pictures selected (cookies/chat/tasks unselected)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      expect(await WebFileStore.read('/browser_cookies.json'), isNotNull,
          reason: 'Unselected cookies must keep their file');
      expect(await WebFileStore.read('/collection.anki2'), isNotNull,
          reason: 'Unselected anki data must keep its file');
      expect(await WebFileStore.read('attachments/keep.bin'), isNotNull,
          reason: 'Unselected chat attachments must keep their files');
      expect(await WebFileStore.read('synthesis/tasks.json'), isNotNull,
          reason: 'Unselected tasks must keep their files');
    });

    testWidgets('corrupt backup aborts BEFORE deleting any existing files',
        (WidgetTester t) async {
      // Seed existing media record + file
      await ManifestDatabase.insertImageRecord({
        'id': 'img_corrupt',
        'name': 'corrupt_img',
        'hash': 'img_corrupt_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await WebFileStore.write('pictures/img_corrupt_hash.jpg',
          Uint8List.fromList(utf8.encode('img_bytes')));

      // Backup with a NESTED-shape-corrupt stroom_manifest.json
      // (valid JSON, wrong inner shape: image_records is a string)
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': 'garbage', // ← wrong shape
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with pictures selected → must throw and NOT delete files
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await expectLater(
        BackupService.restoreFromBytesForTest(backupBytes, selection: sel),
        throwsA(isA<BackupValidationException>()),
        reason: 'Corrupt backup must abort the restore before deleting data',
      );

      // Existing files must survive (validation happens before deletion)
      expect(
          await WebFileStore.read('pictures/img_corrupt_hash.jpg'), isNotNull,
          reason:
              'Existing files must NOT be deleted when the backup is corrupt');
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Existing records must survive a corrupt backup');
    });

    testWidgets(
        'backup without database manifest still clears selected media records',
        (WidgetTester t) async {
      // Seed existing media record + file
      await ManifestDatabase.insertImageRecord({
        'id': 'img_no_manifest',
        'name': 'no_manifest_img',
        'hash': 'img_no_manifest_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await WebFileStore.write('pictures/img_no_manifest_hash.jpg',
          Uint8List.fromList(utf8.encode('img_bytes')));

      // Backup WITHOUT stroom_manifest.json / database/manifest_data.json
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with pictures selected
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Selected category: files deleted AND records cleared (no dangling
      // records pointing at deleted files)
      expect(
          await WebFileStore.read('pictures/img_no_manifest_hash.jpg'), isNull,
          reason: 'Selected media files must be deleted');
      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(0),
          reason:
              'Media records must be cleared even without a database manifest');
    });

    testWidgets(
        'corrupt prefs file of an UNSELECTED category does not block restore',
        (WidgetTester t) async {
      // Backup with corrupt chat_data.json (not valid object)
      final backupArchive = Archive();
      backupArchive.addFile(ArchiveFile(
          'manifest.json',
          0,
          utf8.encode(jsonEncode({
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'appVersion': 'test',
          }))));
      backupArchive.addFile(ArchiveFile(
          'stroom_manifest.json',
          0,
          utf8.encode(jsonEncode({
            'image_records': <Map<String, dynamic>>[],
            'audio_records': <Map<String, dynamic>>[],
            'video_records': <Map<String, dynamic>>[],
            'text_records': <Map<String, dynamic>>[],
            'folders': <String>[],
          }))));
      backupArchive.addFile(ArchiveFile('chat_data.json', 0,
          utf8.encode('{"conversations": '))); // ← malformed JSON
      final encoded = ZipEncoder().encode(backupArchive);
      final backupBytes = Uint8List.fromList(encoded);

      // Restore with pictures selected (chat NOT selected)
      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: true,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreFromBytesForTest(backupBytes, selection: sel);

      // Must not throw: unselected category's corrupt file is ignored
      expect(true, isTrue,
          reason: 'Restore must succeed despite corrupt unselected prefs file');
    });
  });

  // ==================================================================
  // clearSelectedData：只清除选中的类别，未选中的类别保持原样
  // ==================================================================

  group('clearSelectedData clears only selected categories', () {
    testWidgets('chat-only clear removes chat keys, preserves settings keys',
        (WidgetTester t) async {
      // Seed a conversation with an attachment file (subdirectory path) and
      // settings keys
      SharedPreferences.setMockInitialValues({
        'conversations':
            '[{"id":"conv1","messages":[{"attachments":[{"storagePath":"attachments/sub/1.jpg"}]}]}]',
        'active_conversation_id': 'conv1',
        'assistants': '[{"id":"a1","name":"助手"}]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'data_format_version': 2,
      });
      await WebFileStore.write('attachments/sub/1.jpg',
          Uint8List.fromList(utf8.encode('attachment_bytes')));
      // 孤儿附件：不再被任何对话引用，清除聊天时也必须被删除
      await WebFileStore.write('attachments/orphan.bin',
          Uint8List.fromList(utf8.encode('orphan_bytes')));

      final sel = BackupSelection(
        chatRecordsAndAttachments: true,
        settings: false, // <-- must be preserved
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.clearSelectedData(sel);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), isNull,
          reason: 'Chat conversations must be cleared');
      expect(prefs.getString('active_conversation_id'), isNull,
          reason: 'Active conversation ID must be cleared');
      expect(prefs.getString('assistants'), contains('助手'),
          reason: 'Settings keys must be preserved when only chat is cleared');
      expect(prefs.getString('provider_entries'), contains('p1'),
          reason: 'Settings keys must be preserved');

      // Attachment files referenced by the cleared conversations must be deleted
      final attachment = await WebFileStore.read('attachments/sub/1.jpg');
      expect(attachment, isNull,
          reason: 'Attachment file must be deleted when chat is cleared');
      // Orphan attachment files (not referenced by any conversation) too
      final orphan = await WebFileStore.read('attachments/orphan.bin');
      expect(orphan, isNull,
          reason:
              'Orphan attachment files must also be deleted when chat is cleared');
    });

    testWidgets(
        'settings-only clear removes settings keys, preserves chat keys',
        (WidgetTester t) async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'active_conversation_id': 'conv1',
        'assistants': '[{"id":"a1","name":"助手"}]',
        'provider_entries': '[{"id":"p1","type":"llm"}]',
        'data_format_version': 2,
      });

      final sel = BackupSelection(
        chatRecordsAndAttachments: false, // <-- must be preserved
        settings: true,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.clearSelectedData(sel);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('assistants'), isNull,
          reason: 'Settings keys must be cleared');
      expect(prefs.getString('provider_entries'), isNull,
          reason: 'Settings keys must be cleared');
      expect(prefs.getString('conversations'), contains('conv1'),
          reason: 'Chat keys must be preserved when only settings is cleared');
      expect(prefs.getString('active_conversation_id'), equals('conv1'),
          reason: 'Chat keys must be preserved');
    });

    testWidgets('media clear removes selected DB records, preserves unselected',
        (WidgetTester t) async {
      await ManifestDatabase.insertImageRecord({
        'id': 'img_keep_clear',
        'name': 'keep_img',
        'hash': 'keep_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_clear',
        'name': 'clear_aud',
        'hash': 'clear_aud_hash',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'duration': 0.1,
      });
      await ManifestDatabase.insertFolder('Clear_Folder',
          recordTable: ManifestTables.audioRecords);
      await ManifestDatabase.insertFolder('Keep_Video_Folder',
          recordTable: ManifestTables.videoRecords);
      // 媒体文件（按记录 hash 命名，Web/测试模式同样会被逐文件删除）
      await WebFileStore.write('tts_audio/clear_aud_hash.wav',
          Uint8List.fromList(utf8.encode('audio_bytes')));
      await WebFileStore.write('tts_audio/clear_aud_hash.txt',
          Uint8List.fromList(utf8.encode('audio_txt')));
      await WebFileStore.write('pictures/keep_img_hash.jpg',
          Uint8List.fromList(utf8.encode('img_bytes')));

      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: true, // <-- selected, must be cleared
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.clearSelectedData(sel);

      final audios = await ManifestDatabase.getAllAudioRecords();
      expect(audios.length, equals(0),
          reason: 'Selected audio records must be cleared');
      final audioFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.audioRecords);
      expect(audioFolders.length, equals(0),
          reason: 'Selected audio folders must be cleared');

      // Selected category files must be deleted
      expect(await WebFileStore.read('tts_audio/clear_aud_hash.wav'), isNull,
          reason: 'Selected audio file must be deleted');
      expect(await WebFileStore.read('tts_audio/clear_aud_hash.txt'), isNull,
          reason: 'Selected audio text file must be deleted');

      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Unselected image records must be preserved');
      expect(images[0]['id'], equals('img_keep_clear'));

      // Unselected category files must be preserved
      expect(await WebFileStore.read('pictures/keep_img_hash.jpg'), isNotNull,
          reason: 'Unselected image file must be preserved');

      // Unselected video folders must be preserved
      final videoFolders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords);
      expect(videoFolders, contains('Keep_Video_Folder'),
          reason: 'Unselected video folders must be preserved');
    });

    testWidgets('tasks/anki/cookies clear deletes the files',
        (WidgetTester t) async {
      await WebFileStore.write('synthesis/tasks.json',
          Uint8List.fromList(utf8.encode('["task_1"]')));
      await WebFileStore.write(
          'catcatch/tasks.json', Uint8List.fromList(utf8.encode('["task_2"]')));
      // 实际 Anki 数据库位于根目录（WebFileStore 根级文件带前导斜杠）；
      // 历史恢复残留位于 anki/ 子目录
      await WebFileStore.write(
          '/collection.anki2', Uint8List.fromList(utf8.encode('anki_db')));
      await WebFileStore.write('anki/collection.anki2',
          Uint8List.fromList(utf8.encode('anki_db_residue')));
      await WebFileStore.write(
          '/browser_cookies.json', Uint8List.fromList(utf8.encode('cookies')));

      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: true,
        ankiData: true,
        browserCookies: true,
      );
      await BackupService.clearSelectedData(sel);

      expect(await WebFileStore.read('synthesis/tasks.json'), isNull,
          reason: 'synthesis/tasks.json must be deleted when tasks is cleared');
      expect(await WebFileStore.read('catcatch/tasks.json'), isNull,
          reason: 'catcatch/tasks.json must be deleted when tasks is cleared');
      expect(await WebFileStore.read('/collection.anki2'), isNull,
          reason: 'collection.anki2 must be deleted when ankiData is cleared');
      expect(await WebFileStore.read('anki/collection.anki2'), isNull,
          reason:
              'anki/collection.anki2 residue must be deleted when ankiData is cleared');
      expect(await WebFileStore.read('/browser_cookies.json'), isNull,
          reason:
              'browser_cookies.json must be deleted when browserCookies is cleared');

      // 阶段 2：只清除 browserCookies，任务和 Anki 文件必须保留
      // （验证每个 flag 只删除自己对应的文件）
      await WebFileStore.write('synthesis/tasks.json',
          Uint8List.fromList(utf8.encode('["task_1"]')));
      await WebFileStore.write(
          '/collection.anki2', Uint8List.fromList(utf8.encode('anki_db')));
      await WebFileStore.write(
          '/browser_cookies.json', Uint8List.fromList(utf8.encode('cookies')));

      final cookiesOnly = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: true,
      );
      await BackupService.clearSelectedData(cookiesOnly);

      expect(await WebFileStore.read('/browser_cookies.json'), isNull,
          reason: 'browser_cookies.json must be deleted');
      expect(await WebFileStore.read('synthesis/tasks.json'), isNotNull,
          reason:
              'tasks.json must NOT be deleted when only cookies is cleared');
      expect(await WebFileStore.read('/collection.anki2'), isNotNull,
          reason:
              'collection.anki2 must NOT be deleted when only cookies is cleared');
    });

    testWidgets('clearing with NOTHING selected preserves all data',
        (WidgetTester t) async {
      await ManifestDatabase.insertImageRecord({
        'id': 'img_noop',
        'name': 'noop_img',
        'hash': 'noop_img_hash',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 10,
        'folder': '',
        'width': 10,
        'height': 10,
      });
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'assistants': '[{"id":"a1"}]',
      });
      await WebFileStore.write('synthesis/tasks.json',
          Uint8List.fromList(utf8.encode('["task_1"]')));
      await WebFileStore.write(
          '/collection.anki2', Uint8List.fromList(utf8.encode('anki_db')));
      await WebFileStore.write(
          '/browser_cookies.json', Uint8List.fromList(utf8.encode('cookies')));

      final sel = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: false,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.clearSelectedData(sel);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), contains('conv1'),
          reason: 'Nothing selected → chat must be preserved');
      expect(prefs.getString('assistants'), contains('a1'),
          reason: 'Nothing selected → settings must be preserved');

      final images = await ManifestDatabase.getAllImageRecords();
      expect(images.length, equals(1),
          reason: 'Nothing selected → image records must be preserved');

      expect(await WebFileStore.read('synthesis/tasks.json'), isNotNull,
          reason: 'Nothing selected → task files must be preserved');
      expect(await WebFileStore.read('/collection.anki2'), isNotNull,
          reason: 'Nothing selected → anki db must be preserved');
      expect(await WebFileStore.read('/browser_cookies.json'), isNotNull,
          reason: 'Nothing selected → cookies must be preserved');
    });
  });
}
