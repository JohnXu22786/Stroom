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

  group('VideoManifest empty folder persistence', () {
    testWidgets('manually created empty folder stays after loadRecords', (
      WidgetTester t,
    ) async {
      // Create a folder with no records
      await VideoManifest.addFolder('my_empty_folder');

      // Verify the folder exists before loadRecords
      var folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('my_empty_folder'),
        reason: 'Empty folder should exist right after creation',
      );

      // Force a reload by invalidating cache and calling loadRecords
      VideoManifest.invalidateCache();
      await VideoManifest.loadRecords();

      // Verify the folder still exists — THIS IS THE BUG REPRODUCTION
      folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('my_empty_folder'),
        reason: 'BUG: Empty folder disappeared after loadRecords. '
            'Empty folders should remain visible even without records.',
      );
    });

    testWidgets('folder whose only record is deleted stays after loadRecords', (
      WidgetTester t,
    ) async {
      // Add a record in a folder
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'test_video',
          hash: 'hash1',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          folder: 'my_folder',
          duration: 5000,
        ),
      );

      // Verify the folder exists
      var folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('my_folder'),
        reason: 'Folder should exist when it has a record',
      );

      // Delete the record directly from DB (avoiding file I/O in tests)
      final records = await VideoManifest.loadRecords();
      await ManifestDatabase.deleteVideoRecord(records.first.id);
      VideoManifest.invalidateCache();

      // Force a reload
      await VideoManifest.loadRecords();

      // Verify the empty folder still exists — THIS IS THE BUG REPRODUCTION
      folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('my_folder'),
        reason: 'BUG: Folder disappeared after its last record was deleted. '
            'Empty folders should remain visible.',
      );
    });

    testWidgets('folder created by moveRecord persists after record deleted', (
      WidgetTester t,
    ) async {
      // Add a record at root
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'movable_video',
          hash: 'hash_move',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          folder: '',
          duration: 5000,
        ),
      );

      // Move it to a target folder — this should trigger _ensureFolderPathTracked
      final records = await VideoManifest.loadRecords();
      await VideoManifest.moveRecord(records.first.id, 'moved_folder');

      // Delete the record to make the folder empty
      await ManifestDatabase.deleteVideoRecord(records.first.id);
      VideoManifest.invalidateCache();

      // Force a reload
      await VideoManifest.loadRecords();

      // The folder should persist even though the record is gone
      // (because moveRecord called _ensureFolderPathTracked)
      final folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('moved_folder'),
        reason:
            'BUG: Folder created via moveRecord disappeared after record was deleted.',
      );
    });

    testWidgets('ancestor folders tracked for nested paths', (
      WidgetTester t,
    ) async {
      // Add a record in a deeply nested folder
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'nested_video',
          hash: 'hash_nest',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          folder: 'level1/level2/level3',
          duration: 5000,
        ),
      );

      // Delete the record to make the folder empty
      final records = await VideoManifest.loadRecords();
      await ManifestDatabase.deleteVideoRecord(records.first.id);
      VideoManifest.invalidateCache();

      // Force a reload
      await VideoManifest.loadRecords();

      // All ancestor folders should persist
      final folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('level1'),
        reason:
            'Ancestor folder level1 should persist (via _ensureFolderPathTracked)',
      );
      expect(
        folders,
        contains('level1/level2'),
        reason:
            'Ancestor folder level1/level2 should persist (via _ensureFolderPathTracked)',
      );
      expect(
        folders,
        contains('level1/level2/level3'),
        reason:
            'Leaf folder level1/level2/level3 should persist (via _ensureFolderPathTracked)',
      );
    });

    testWidgets('folder with records still appear (no regression)', (
      WidgetTester t,
    ) async {
      // Add records in multiple folders
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'video_a',
          hash: 'hash_a',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          folder: 'folder_a',
          duration: 5000,
        ),
      );
      await VideoManifest.addRecord(
        VideoRecord(
          name: 'video_b',
          hash: 'hash_b',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 2048,
          folder: 'folder_b',
          duration: 3000,
        ),
      );

      // Force a reload
      VideoManifest.invalidateCache();
      await VideoManifest.loadRecords();

      // Both folders should still appear
      final folders = await VideoManifest.getAllFolders();
      expect(
        folders,
        contains('folder_a'),
        reason: 'folder_a should still appear (has a record)',
      );
      expect(
        folders,
        contains('folder_b'),
        reason: 'folder_b should still appear (has a record)',
      );
    });
  });
}
