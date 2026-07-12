import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    VideoManifest.invalidateCache();
  });

  // ====== ManifestDatabase CRUD (in-memory, no file I/O) ======

  group('ManifestDatabase video records', () {
    testWidgets('empty initially', (WidgetTester t) async {
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records, isEmpty);
    });

    testWidgets('insert and retrieve', (WidgetTester t) async {
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_1',
        'name': 'test_video',
        'hash': 'abc123',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 1024,
        'folder': '',
        'duration': 5000,
      });
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('vid_1'));
    });

    testWidgets('update existing record', (WidgetTester t) async {
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_2',
        'name': 'original',
        'hash': 'def456',
        'format': 'mov',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 2048,
        'folder': '',
        'duration': 3000,
      });
      await ManifestDatabase.updateVideoRecord(
          'vid_2', {'name': 'renamed', 'size': 4096});
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records[0]['name'], equals('renamed'));
      expect(records[0]['size'], equals(4096));
    });

    testWidgets('delete record', (WidgetTester t) async {
      await ManifestDatabase.insertVideoRecord({
        'id': 'vid_3',
        'name': 'to_delete',
        'hash': 'ghi789',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 512,
        'folder': '',
        'duration': 2000,
      });
      await ManifestDatabase.deleteVideoRecord('vid_3');
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records, isEmpty);
    });

    testWidgets('batch delete', (WidgetTester t) async {
      for (var i = 0; i < 3; i++) {
        await ManifestDatabase.insertVideoRecord({
          'id': 'batch_$i',
          'name': 'batch_$i',
          'hash': 'hash_$i',
          'format': 'mp4',
          'createdAt': DateTime.now().toIso8601String(),
          'size': 100,
          'folder': '',
          'duration': 1000,
        });
      }
      await ManifestDatabase.deleteVideoRecords(['batch_0', 'batch_2']);
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('batch_1'));
    });
  });

  group('ManifestDatabase folders', () {
    testWidgets('insert and list', (WidgetTester t) async {
      await ManifestDatabase.insertFolder('folder_a',
          recordTable: ManifestTables.videoRecords);
      await ManifestDatabase.insertFolder('folder_b/sub',
          recordTable: ManifestTables.videoRecords);
      final folders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords);
      expect(folders.length, equals(2));
      expect(folders, contains('folder_a'));
      expect(folders, contains('folder_b/sub'));
    });

    testWidgets('delete folder', (WidgetTester t) async {
      await ManifestDatabase.insertFolder('to_remove',
          recordTable: ManifestTables.videoRecords);
      await ManifestDatabase.deleteFolder('to_remove',
          recordTable: ManifestTables.videoRecords);
      final folders = await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords);
      expect(folders, isNot(contains('to_remove')));
    });
  });

  // ====== VideoManifest record CRUD (DB-only methods, no file I/O) ======

  group('VideoManifest DB operations', () {
    testWidgets('add and load records', (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        name: 'test_video',
        hash: 'hash1',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 1024,
        duration: 5000,
      ));
      final records = await VideoManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_video'));
    });

    testWidgets('rename record (DB only)', (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        id: 'rename_me',
        name: 'old_name',
        hash: 'hren',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 100,
        duration: 1000,
      ));
      await VideoManifest.renameRecord('rename_me', 'new_name');
      final records = await VideoManifest.loadRecords();
      expect(records[0].name, equals('new_name'));
    });

    testWidgets('move record to folder (DB only)', (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        id: 'move_me',
        name: 'movable',
        hash: 'hmov',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 100,
        folder: '',
        duration: 1000,
      ));
      await VideoManifest.moveRecord('move_me', 'my_folder');
      final records = await VideoManifest.loadRecords();
      expect(records[0].folder, equals('my_folder'));
    });

    testWidgets('update record (DB only)', (WidgetTester t) async {
      final record = VideoRecord(
        id: 'upd',
        name: 'before',
        hash: 'hupd',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 100,
        duration: 1000,
      );
      await VideoManifest.addRecord(record);
      await VideoManifest.updateRecord(
          record.copyWith(name: 'after', size: 999));
      final records = await VideoManifest.loadRecords();
      expect(records[0].name, equals('after'));
      expect(records[0].size, equals(999));
    });
  });
}
