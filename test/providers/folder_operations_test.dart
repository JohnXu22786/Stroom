import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/providers/text_provider.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/providers/video_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    ImageManifest.invalidateCache();
    TextManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  // ====================================================================
  // No-op guards — degenerate inputs must not corrupt data.
  // Regression: moveFolder('a','a') previously flattened/erased records.
  // ====================================================================

  group('no-op guards', () {
    testWidgets('renameFolder to the same name is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_1',
        name: 'doc',
        hash: 'hash_guard_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_1').folder,
          equals('a'),
          reason: 'records must not be flattened to root');
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('renameFolder to an empty name is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_2',
        name: 'doc',
        hash: 'hash_guard_2',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', '');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_2').folder,
          equals('a'));
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('renameFolder of a nested folder to an empty name is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_6',
        name: 'doc',
        hash: 'hash_guard_6',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a/sub',
      ));

      await notifier.renameFolder('a/sub', '');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_6').folder,
          equals('a/sub'),
          reason: 'BUG: records must stay in their folder, not move to a/');
      expect(await TextManifest.getAllFolders(), contains('a/sub'));
      expect(await TextManifest.getAllFolders(), isNot(contains('a/')),
          reason: 'BUG: trailing-slash folder entry must not be created');
    });

    testWidgets('renameFolder to a whitespace name is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_7',
        name: 'doc',
        hash: 'hash_guard_7',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', '   ');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_7').folder,
          equals('a'));
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('renameFolder into its own descendant is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_8',
        name: 'doc',
        hash: 'hash_guard_8',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', 'a/b');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_8').folder,
          equals('a'),
          reason: 'BUG: records must stay in the source folder');
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('moveFolder into itself is a no-op and keeps records in place',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_3',
        name: 'doc',
        hash: 'hash_guard_3',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('a/empty_sub');

      await notifier.moveFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_3').folder,
          equals('a'),
          reason: 'records must stay in the source folder');
      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('a'));
      expect(folders, contains('a/empty_sub'),
          reason: 'folder tree must be untouched');
    });

    testWidgets('moveFolder into its own descendant is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_4',
        name: 'doc',
        hash: 'hash_guard_4',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', 'a/sub');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_4').folder,
          equals('a'),
          reason: 'records must stay in the source folder');
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('audio moveFolder into itself is a no-op (no data loss)',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_guard_1',
        name: 'tts',
        hash: 'hash_audio_guard_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'audio_guard_1').folder,
          equals('a'),
          reason: 'BUG: audio records must not be deleted by a self-move');
      expect(await FileManifest.getAllFolders(), contains('a'));
    });

    testWidgets('moveFolder to the same location at root is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_5',
        name: 'doc',
        hash: 'hash_guard_5',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', '');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_5').folder,
          equals('a'));
      expect(await TextManifest.getAllFolders(), contains('a'));
    });

    testWidgets('copyFolder into the source parent does not duplicate records',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_9',
        name: 'doc',
        hash: 'hash_guard_9',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'x/a',
      ));

      // Copying 'x/a' into 'x' would produce newPath == sourceName.
      await notifier.copyFolder('x/a', 'x');

      await notifier.loadRecords();
      expect(notifier.state.where((r) => r.folder == 'x/a'), hasLength(1),
          reason: 'BUG: copying a folder into its own parent duplicates it');
    });

    testWidgets('folder ops with an empty source folder name are no-ops',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_10',
        name: 'doc',
        hash: 'hash_guard_10',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: '',
      ));
      await TextManifest.addFolder('other');

      await notifier.renameFolder('', 'x');
      await notifier.moveFolder('', 'y');
      await notifier.copyFolder('', 'z');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_10').folder,
          isEmpty,
          reason: 'BUG: empty-source ops must not re-prefix root records');
      final folders = await TextManifest.getAllFolders();
      expect(folders, isNot(contains('x')));
      expect(folders, isNot(contains('y')));
      expect(folders, isNot(contains('z')));
      expect(folders, contains('other'));
    });

    testWidgets(
        'moveFolder and copyFolder with a whitespace-only target are no-ops',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_11',
        name: 'doc',
        hash: 'hash_guard_11',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', '   ');
      await notifier.copyFolder('a', '  ');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_11').folder,
          equals('a'),
          reason: 'BUG: whitespace target must not create a " /a" folder');
      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('a'));
      expect(folders, isNot(contains(' /a')));
      expect(folders, isNot(contains('  /a')));
    });

    testWidgets('copyFolder with multiple records copies all without error',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_cp_multi_1',
        name: 'one',
        hash: 'hash_cp_multi_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
        textLength: 11,
      ));
      await TextManifest.addRecord(TextRecord(
        id: 'txt_cp_multi_2',
        name: 'two',
        hash: 'hash_cp_multi_2',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
        textLength: 22,
      ));

      await notifier.copyFolder('a', 'x');

      await notifier.loadRecords();
      expect(notifier.state, hasLength(4),
          reason: 'BUG: copying must not throw ConcurrentModificationError '
              'or drop records when the source folder has multiple records');
      final copies = notifier.state.where((r) => r.folder == 'x/a');
      expect(copies, hasLength(2));
      expect(copies.every((r) => r.textLength > 0), isTrue,
          reason: 'copied records must preserve type-specific fields');
    });

    testWidgets('renameFolder onto an existing sibling folder is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_12',
        name: 'doc',
        hash: 'hash_guard_12',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_13',
        name: 'doc2',
        hash: 'hash_guard_13',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'b',
      ));
      await TextManifest.addFolder('b');

      await notifier.renameFolder('a', 'b');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_12').folder,
          equals('a'),
          reason:
              'BUG: renaming onto an existing folder must not merge records');
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_13').folder,
          equals('b'));
      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('a'));
      expect(folders, contains('b'));
    });

    testWidgets('moving an empty folder registers ancestor folders',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addFolder('emptyA');

      await notifier.moveFolder('emptyA', 'x/y');

      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('x/y/emptyA'));
      expect(folders, contains('x/y'),
          reason: 'BUG: ancestor x/y must be registered');
      expect(folders, contains('x'),
          reason: 'BUG: ancestor x must be registered');
      expect(folders, isNot(contains('emptyA')));
    });

    testWidgets('copying an empty folder registers ancestor folders',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addFolder('emptyB');

      await notifier.copyFolder('emptyB', 'x/y');

      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('x/y/emptyB'));
      expect(folders, contains('x/y'));
      expect(folders, contains('x'));
      expect(folders, contains('emptyB'));
    });

    testWidgets('moveFolder onto an existing destination is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_14',
        name: 'doc',
        hash: 'hash_guard_14',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('x/a');

      await notifier.moveFolder('a', 'x');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_14').folder,
          equals('a'),
          reason: 'BUG: moving onto an existing destination must not merge');
      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('a'));
      expect(folders, contains('x/a'));
    });

    testWidgets('copyFolder onto an existing destination is a no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_15',
        name: 'doc',
        hash: 'hash_guard_15',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('x/a');

      await notifier.copyFolder('a', 'x');

      await notifier.loadRecords();
      expect(notifier.state.where((r) => r.folder == 'a'), hasLength(1),
          reason:
              'BUG: copying onto an existing destination must not duplicate');
      expect(notifier.state.where((r) => r.folder == 'x/a'), hasLength(0));
    });

    testWidgets('moveFolder of a nested folder to root moves it by base name',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_16',
        name: 'doc',
        hash: 'hash_guard_16',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'x/a',
      ));

      await notifier.moveFolder('x/a', '');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_guard_16').folder,
          equals('a'),
          reason: 'BUG: nested folder must move to root under its base name');
      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('a'));
      expect(folders, isNot(contains('x/a')));
    });

    testWidgets('copyFolder of a nested folder to root copies it by base name',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_guard_17',
        name: 'doc',
        hash: 'hash_guard_17',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'x/a',
      ));

      await notifier.copyFolder('x/a', '');
      await notifier.loadRecords();
      expect(notifier.state.where((r) => r.folder == 'a'), hasLength(1),
          reason:
              'BUG: nested folder must be copied to root under its base name');
      expect(notifier.state.where((r) => r.folder == 'x/a'), hasLength(1));
    });
  });

  // ====================================================================
  // Image provider — guard coverage (mirrors text provider)
  // ====================================================================

  group('ImageRecordsNotifier guard coverage', () {
    testWidgets('renameFolder to the same name is a no-op',
        (WidgetTester t) async {
      final notifier = ImageRecordsNotifier();
      await notifier.loadRecords();
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_guard_1',
        name: 'pic',
        hash: 'hash_img_guard_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'img_guard_1').folder,
          equals('a'));
      expect(await ImageManifest.getAllFolders(), contains('a'));
    });

    testWidgets('moveFolder into itself is a no-op', (WidgetTester t) async {
      final notifier = ImageRecordsNotifier();
      await notifier.loadRecords();
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_guard_2',
        name: 'pic',
        hash: 'hash_img_guard_2',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'img_guard_2').folder,
          equals('a'));
      expect(await ImageManifest.getAllFolders(), contains('a'));
    });
  });

  // ====================================================================
  // Video provider — guard coverage (mirrors text provider)
  // ====================================================================

  group('VideoRecordsNotifier guard coverage', () {
    testWidgets('renameFolder to the same name is a no-op',
        (WidgetTester t) async {
      final notifier = VideoRecordsNotifier();
      await notifier.loadRecords();
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_guard_1',
        name: 'clip',
        hash: 'hash_vid_guard_1',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.renameFolder('a', 'a');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'vid_guard_1').folder,
          equals('a'));
      expect(await VideoManifest.getAllFolders(), contains('a'));
    });

    testWidgets('moveFolder into its own descendant is a no-op',
        (WidgetTester t) async {
      final notifier = VideoRecordsNotifier();
      await notifier.loadRecords();
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_guard_2',
        name: 'clip',
        hash: 'hash_vid_guard_2',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.moveFolder('a', 'a/sub');

      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'vid_guard_2').folder,
          equals('a'));
      expect(await VideoManifest.getAllFolders(), contains('a'));
    });
  });

  // ====================================================================
  // Audio provider — copyFolder preserves duration
  // ====================================================================

  group('AudioRecordsNotifier copyFolder fields', () {
    testWidgets('copied records preserve duration', (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_cp_dur_1',
        name: 'tts',
        hash: 'hash_audio_cp_dur_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
        duration: 3700,
      ));

      await notifier.copyFolder('a', 'x');

      await notifier.loadRecords();
      final copies = notifier.state.where((r) => r.folder == 'x/a');
      expect(copies, hasLength(1));
      expect(copies.first.duration, equals(3700),
          reason: 'BUG: copied audio records must keep their duration');
    });

    testWidgets('copyFolder normalizes a trailing-slash target parent',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_cp_ts_1',
        name: 'tts',
        hash: 'hash_audio_cp_ts_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await notifier.copyFolder('a', 'parent/');

      await notifier.loadRecords();
      expect(notifier.state.where((r) => r.folder == 'parent/a'), hasLength(1));
      final folders = await FileManifest.getAllFolders();
      expect(folders, contains('parent'),
          reason: 'BUG: normalized target parent must be registered');
      expect(folders, isNot(contains('parent/')));
    });
  });

  // ====================================================================
  // Text provider folder operations.
  // Regression: empty descendant folder entries were dropped when a
  // folder was renamed/moved/copied because only the folder itself was
  // re-added at its new path.
  // ====================================================================

  group('TextRecordsNotifier folder ops', () {
    testWidgets('renameFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_rn_1',
        name: 'doc',
        hash: 'hash_rn_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('a/empty_sub');

      await notifier.renameFolder('a', 'b');

      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('b'),
          reason: 'renamed folder must exist at its new path');
      expect(folders, contains('b/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during rename');
      expect(folders, isNot(contains('a')));
      expect(folders, isNot(contains('a/empty_sub')));
      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'txt_rn_1').folder,
          equals('b'));
    });

    testWidgets('renameFolder moves records in nested descendants',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_rn_2',
        name: 'top',
        hash: 'hash_rn_2',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addRecord(TextRecord(
        id: 'txt_rn_3',
        name: 'sub',
        hash: 'hash_rn_3',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a/deep/sub',
      ));

      await notifier.renameFolder('a', 'b');

      final top = notifier.state.firstWhere((r) => r.id == 'txt_rn_2');
      final sub = notifier.state.firstWhere((r) => r.id == 'txt_rn_3');
      expect(top.folder, equals('b'));
      expect(sub.folder, equals('b/deep/sub'),
          reason: 'nested records must keep their relative structure');
    });

    testWidgets('moveFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_mv_1',
        name: 'doc',
        hash: 'hash_mv_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('a/empty_sub');

      await notifier.moveFolder('a', 'parent');

      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('parent/a'));
      expect(folders, contains('parent/a/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during move');
      expect(folders, isNot(contains('a')));
      expect(folders, isNot(contains('a/empty_sub')));
    });

    testWidgets('copyFolder replicates empty descendant folders',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_cp_1',
        name: 'doc',
        hash: 'hash_cp_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('a/empty_sub');

      await notifier.copyFolder('a', 'x');

      final folders = await TextManifest.getAllFolders();
      expect(folders, contains('x/a'));
      expect(folders, contains('x/a/empty_sub'),
          reason: 'BUG: copied folder is missing its empty descendant');
      expect(folders, contains('a/empty_sub'),
          reason: 'source folder structure must be untouched');
    });

    testWidgets('deleteFolder removes records and folder entries',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_df_1',
        name: 'doc',
        hash: 'hash_df_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await TextManifest.addFolder('a/empty_sub');

      await notifier.deleteFolder('a');

      expect(await TextManifest.getAllFolders(), isNot(contains('a')));
      expect(
          await TextManifest.getAllFolders(), isNot(contains('a/empty_sub')));
      expect(await TextManifest.loadRecords(), isEmpty);
    });
  });

  // ====================================================================
  // Image provider — moveFolder keeps empty descendants
  // ====================================================================

  group('ImageRecordsNotifier folder ops', () {
    testWidgets('moveFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = ImageRecordsNotifier();
      await notifier.loadRecords();
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_mv_1',
        name: 'pic',
        hash: 'hash_img_mv_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await ImageManifest.addFolder('a/empty_sub');

      await notifier.moveFolder('a', 'parent');

      final folders = await ImageManifest.getAllFolders();
      expect(folders, contains('parent/a'));
      expect(folders, contains('parent/a/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during move');
    });

    testWidgets('renameFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = ImageRecordsNotifier();
      await notifier.loadRecords();
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_rn_1',
        name: 'pic',
        hash: 'hash_img_rn_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await ImageManifest.addFolder('a/empty_sub');

      await notifier.renameFolder('a', 'b');

      final folders = await ImageManifest.getAllFolders();
      expect(folders, contains('b/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during rename');
    });
  });

  // ====================================================================
  // Video provider — copyFolder replicates empty descendants
  // ====================================================================

  group('VideoRecordsNotifier folder ops', () {
    testWidgets('copyFolder replicates empty descendant folders',
        (WidgetTester t) async {
      final notifier = VideoRecordsNotifier();
      await notifier.loadRecords();
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_cp_1',
        name: 'clip',
        hash: 'hash_vid_cp_1',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await VideoManifest.addFolder('a/empty_sub');

      await notifier.copyFolder('a', 'x');

      final folders = await VideoManifest.getAllFolders();
      expect(folders, contains('x/a'));
      expect(folders, contains('x/a/empty_sub'),
          reason: 'BUG: copied folder is missing its empty descendant');
    });

    testWidgets('moveFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = VideoRecordsNotifier();
      await notifier.loadRecords();
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_mv_1',
        name: 'clip',
        hash: 'hash_vid_mv_1',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await VideoManifest.addFolder('a/empty_sub');

      await notifier.moveFolder('a', 'parent');

      final folders = await VideoManifest.getAllFolders();
      expect(folders, contains('parent/a/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during move');
    });
  });

  // ====================================================================
  // Audio provider (TTS) — same empty-descendant guarantees
  // ====================================================================

  group('AudioRecordsNotifier folder ops', () {
    testWidgets('renameFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_rn_1',
        name: 'tts',
        hash: 'hash_audio_rn_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await FileManifest.addFolder('a/empty_sub');

      await notifier.renameFolder('a', 'b');

      final folders = await FileManifest.getAllFolders();
      expect(folders, contains('b'));
      expect(folders, contains('b/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during rename');
      expect(folders, isNot(contains('a')));
      await notifier.loadRecords();
      expect(notifier.state.firstWhere((r) => r.id == 'audio_rn_1').folder,
          equals('b'));
    });

    testWidgets('moveFolder keeps empty descendant folders',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_mv_1',
        name: 'tts',
        hash: 'hash_audio_mv_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await FileManifest.addFolder('a/empty_sub');

      await notifier.moveFolder('a', 'parent');

      final folders = await FileManifest.getAllFolders();
      expect(folders, contains('parent/a/empty_sub'),
          reason: 'BUG: empty descendant folder was lost during move');
    });

    testWidgets('copyFolder replicates empty descendant folders',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_cp_1',
        name: 'tts',
        hash: 'hash_audio_cp_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));
      await FileManifest.addFolder('a/empty_sub');

      await notifier.copyFolder('a', 'x');

      final folders = await FileManifest.getAllFolders();
      expect(folders, contains('x/a/empty_sub'),
          reason: 'BUG: copied folder is missing its empty descendant');
      expect(folders, contains('a/empty_sub'));
    });
  });
}
