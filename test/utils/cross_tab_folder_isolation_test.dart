import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    // Invalidate all caches
    TextManifest.invalidateCache();
    FileManifest.invalidateCache();
    ImageManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  group('Cross-tab folder isolation', () {
    testWidgets('folder created in VideoManifest does NOT leak to TextManifest',
        (WidgetTester t) async {
      // Create a folder in VideoManifest
      await VideoManifest.addFolder('my_video_folder');

      // Verify it exists in VideoManifest
      final videoFolders = await VideoManifest.getAllFolders();
      expect(videoFolders, contains('my_video_folder'),
          reason: 'Folder should exist in VideoManifest');

      // Force a reload on all manifests
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      // ⚠️ BUG: TextManifest should NOT see this folder
      final textFolders = await TextManifest.getAllFolders();
      expect(textFolders, isNot(contains('my_video_folder')),
          reason:
              'BUG: TextManifest should NOT contain video folder. '
              'Folders must be isolated per tab type.');
    });

    testWidgets('folder created in VideoManifest does NOT leak to ImageManifest',
        (WidgetTester t) async {
      await VideoManifest.addFolder('video_only_folder');

      // Force a reload on all manifests
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final imageFolders = await ImageManifest.getAllFolders();
      expect(imageFolders, isNot(contains('video_only_folder')),
          reason:
              'BUG: ImageManifest should NOT contain video folder');
    });

    testWidgets('folder created in VideoManifest does NOT leak to AudioManifest',
        (WidgetTester t) async {
      await VideoManifest.addFolder('video_only_folder');

      // Force a reload
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final audioFolders = await FileManifest.getAllFolders();
      expect(audioFolders, isNot(contains('video_only_folder')),
          reason:
              'BUG: AudioManifest (FileManifest) should NOT contain video folder');
    });

    testWidgets('folder created in TextManifest does NOT leak to other tabs',
        (WidgetTester t) async {
      await TextManifest.addFolder('text_folder');

      // Force a reload
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final textFolders = await TextManifest.getAllFolders();
      final audioFolders = await FileManifest.getAllFolders();
      final imageFolders = await ImageManifest.getAllFolders();
      final videoFolders = await VideoManifest.getAllFolders();

      expect(textFolders, contains('text_folder'),
          reason: 'TextManifest should have text_folder');
      expect(audioFolders, isNot(contains('text_folder')),
          reason: 'BUG: AudioManifest should NOT contain text_folder');
      expect(imageFolders, isNot(contains('text_folder')),
          reason: 'BUG: ImageManifest should NOT contain text_folder');
      expect(videoFolders, isNot(contains('text_folder')),
          reason: 'BUG: VideoManifest should NOT contain text_folder');
    });

    testWidgets('folder created in ImageManifest does NOT leak to other tabs',
        (WidgetTester t) async {
      await ImageManifest.addFolder('image_folder');

      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final textFolders = await TextManifest.getAllFolders();
      final audioFolders = await FileManifest.getAllFolders();
      final imageFolders = await ImageManifest.getAllFolders();
      final videoFolders = await VideoManifest.getAllFolders();

      expect(imageFolders, contains('image_folder'),
          reason: 'ImageManifest should have image_folder');
      expect(textFolders, isNot(contains('image_folder')),
          reason: 'BUG: TextManifest should NOT contain image_folder');
      expect(audioFolders, isNot(contains('image_folder')),
          reason: 'BUG: AudioManifest should NOT contain image_folder');
      expect(videoFolders, isNot(contains('image_folder')),
          reason: 'BUG: VideoManifest should NOT contain image_folder');
    });

    testWidgets('folder created in AudioManifest does NOT leak to other tabs',
        (WidgetTester t) async {
      await FileManifest.addFolder('audio_folder');

      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final textFolders = await TextManifest.getAllFolders();
      final audioFolders = await FileManifest.getAllFolders();
      final imageFolders = await ImageManifest.getAllFolders();
      final videoFolders = await VideoManifest.getAllFolders();

      expect(audioFolders, contains('audio_folder'),
          reason: 'AudioManifest should have audio_folder');
      expect(textFolders, isNot(contains('audio_folder')),
          reason: 'BUG: TextManifest should NOT contain audio_folder');
      expect(imageFolders, isNot(contains('audio_folder')),
          reason: 'BUG: ImageManifest should NOT contain audio_folder');
      expect(videoFolders, isNot(contains('audio_folder')),
          reason: 'BUG: VideoManifest should NOT contain audio_folder');
    });

    testWidgets('deleting folder from VideoManifest does NOT affect TextManifest',
        (WidgetTester t) async {
      // Create separate folders in different manifests
      await VideoManifest.addFolder('video_folder');
      await TextManifest.addFolder('text_folder');

      // Verify both folders exist in their respective manifests
      var videoFolders = await VideoManifest.getAllFolders();
      var textFolders = await TextManifest.getAllFolders();
      expect(videoFolders, contains('video_folder'));
      expect(textFolders, contains('text_folder'));

      // Delete folder from VideoManifest only
      await VideoManifest.removeFolder('video_folder');

      // Force a reload
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      videoFolders = await VideoManifest.getAllFolders();
      textFolders = await TextManifest.getAllFolders();

      expect(videoFolders, isNot(contains('video_folder')),
          reason: 'VideoManifest should have video_folder removed');
      expect(textFolders, contains('text_folder'),
          reason:
              'BUG: TextManifest folder should NOT have been deleted when '
              'VideoManifest folder was deleted');
    });

    testWidgets('deleting folder from one tab does NOT delete same-name folder from other tabs',
        (WidgetTester t) async {
      // Create same-named folders in multiple manifests (they should be independent)
      await TextManifest.addFolder('shared_name');
      await ImageManifest.addFolder('shared_name');

      // Delete from TextManifest
      await TextManifest.removeFolder('shared_name');

      // Force a reload
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final textFolders = await TextManifest.getAllFolders();
      final imageFolders = await ImageManifest.getAllFolders();

      expect(textFolders, isNot(contains('shared_name')),
          reason: 'TextManifest should have the folder removed');
      expect(imageFolders, contains('shared_name'),
          reason:
              'BUG: ImageManifest should still have its own copy of '
              '"shared_name" folder');
    });

    testWidgets('each tab can have independent folders with the same name',
        (WidgetTester t) async {
      // Create same-named folders in all four manifests
      await TextManifest.addFolder('my_folder');
      await FileManifest.addFolder('my_folder');
      await ImageManifest.addFolder('my_folder');
      await VideoManifest.addFolder('my_folder');

      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      // All four should see the folder
      expect(await TextManifest.getAllFolders(), contains('my_folder'));
      expect(await FileManifest.getAllFolders(), contains('my_folder'));
      expect(await ImageManifest.getAllFolders(), contains('my_folder'));
      expect(await VideoManifest.getAllFolders(), contains('my_folder'));

      // Delete only from TextManifest
      await TextManifest.removeFolder('my_folder');

      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      // Only TextManifest should have lost it
      expect(await TextManifest.getAllFolders(), isNot(contains('my_folder')),
          reason: 'TextManifest folder was deleted');
      expect(await FileManifest.getAllFolders(), contains('my_folder'),
          reason: 'BUG: AudioManifest folder should still exist');
      expect(await ImageManifest.getAllFolders(), contains('my_folder'),
          reason: 'BUG: ImageManifest folder should still exist');
      expect(await VideoManifest.getAllFolders(), contains('my_folder'),
          reason: 'BUG: VideoManifest folder should still exist');
    });

    testWidgets(
        'create-empty-folder across all 4 manifests - each independent',
        (WidgetTester t) async {
      // Create one empty folder in each manifest
      await TextManifest.addFolder('text_empty');
      await FileManifest.addFolder('audio_empty');
      await ImageManifest.addFolder('image_empty');
      await VideoManifest.addFolder('video_empty');

      // Reload all
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      final textFolders = await TextManifest.getAllFolders();
      final audioFolders = await FileManifest.getAllFolders();
      final imageFolders = await ImageManifest.getAllFolders();
      final videoFolders = await VideoManifest.getAllFolders();

      // Each should only see its own folder
      expect(textFolders, contains('text_empty'));
      expect(textFolders, isNot(contains('audio_empty')),
          reason: 'BUG: Text should not see audio_empty');
      expect(textFolders, isNot(contains('image_empty')),
          reason: 'BUG: Text should not see image_empty');
      expect(textFolders, isNot(contains('video_empty')),
          reason: 'BUG: Text should not see video_empty');

      expect(audioFolders, contains('audio_empty'));
      expect(audioFolders, isNot(contains('text_empty')),
          reason: 'BUG: Audio should not see text_empty');
      expect(audioFolders, isNot(contains('image_empty')),
          reason: 'BUG: Audio should not see image_empty');
      expect(audioFolders, isNot(contains('video_empty')),
          reason: 'BUG: Audio should not see video_empty');

      expect(imageFolders, contains('image_empty'));
      expect(imageFolders, isNot(contains('text_empty')),
          reason: 'BUG: Image should not see text_empty');
      expect(imageFolders, isNot(contains('audio_empty')),
          reason: 'BUG: Image should not see audio_empty');
      expect(imageFolders, isNot(contains('video_empty')),
          reason: 'BUG: Image should not see video_empty');

      expect(videoFolders, contains('video_empty'));
      expect(videoFolders, isNot(contains('text_empty')),
          reason: 'BUG: Video should not see text_empty');
      expect(videoFolders, isNot(contains('audio_empty')),
          reason: 'BUG: Video should not see audio_empty');
      expect(videoFolders, isNot(contains('image_empty')),
          reason: 'BUG: Video should not see image_empty');
    });

    testWidgets('legacy folders from shared table still appear in all manifests',
        (WidgetTester t) async {
      // Simulate legacy data by manually inserting a folder into the shared
      // folders table (bypassing the manifest-specific addFolder)
      await ManifestDatabase.insertFolder('legacy_folder');

      // Reload all manifests
      TextManifest.invalidateCache();
      FileManifest.invalidateCache();
      ImageManifest.invalidateCache();
      VideoManifest.invalidateCache();

      await TextManifest.loadRecords();
      await FileManifest.loadRecords();
      await ImageManifest.loadRecords();
      await VideoManifest.loadRecords();

      // Legacy folders should still appear in all
      expect(await TextManifest.getAllFolders(), contains('legacy_folder'),
          reason: 'Legacy folder should appear in TextManifest');
      expect(await FileManifest.getAllFolders(), contains('legacy_folder'),
          reason: 'Legacy folder should appear in AudioManifest');
      expect(await ImageManifest.getAllFolders(), contains('legacy_folder'),
          reason: 'Legacy folder should appear in ImageManifest');
      expect(await VideoManifest.getAllFolders(), contains('legacy_folder'),
          reason: 'Legacy folder should appear in VideoManifest');
    });
  });
}
