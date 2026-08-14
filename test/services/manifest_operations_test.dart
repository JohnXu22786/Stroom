import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

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
  // File lifecycle in test mode (WebFileStore in-memory store).
  // Regression: delete paths used `kIsWeb` instead of `_useWebFileStore`,
  // so in test mode they hit native path_provider → MissingPluginException
  // and the record/file were never deleted.
  // ====================================================================

  group('entity file lifecycle (test mode)', () {
    testWidgets('write/read/exists/delete roundtrip', (WidgetTester t) async {
      final data = Uint8List.fromList([1, 2, 3, 4]);

      final written = await ImageManifest.writeFile('abc.jpg', data);
      expect(written, isNotEmpty);

      expect(await ImageManifest.readFile('abc.jpg'), equals(data));
      expect(await WebFileStore.exists('pictures/abc.jpg'), isTrue);

      await ImageManifest.deleteFile('abc.jpg');
      expect(await WebFileStore.exists('pictures/abc.jpg'), isFalse);
      expect(await ImageManifest.readFile('abc.jpg'), isNull);
    });

    testWidgets(
        'deleteRecord deletes entity file when it is the last reference',
        (WidgetTester t) async {
      final record = ImageRecord(
        id: 'img_del_1',
        name: 'pic',
        hash: 'hash_unique_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          record.storagePath, Uint8List.fromList([1]));
      await ImageManifest.addRecord(record);

      expect(
          await WebFileStore.exists('pictures/${record.storagePath}'), isTrue);

      await ImageManifest.deleteRecord(record.id);

      expect(await ImageManifest.loadRecords(), isEmpty,
          reason: 'record must be removed from cache and DB');
      expect(
          await WebFileStore.exists('pictures/${record.storagePath}'), isFalse,
          reason: 'entity file must be deleted when refcount reaches 0');
    });

    testWidgets(
        'deleteRecord keeps entity file when storage name is shared by another record',
        (WidgetTester t) async {
      final shared = ImageRecord(
        id: 'img_shared_a',
        name: 'pic_a',
        hash: 'hash_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      final other = ImageRecord(
        id: 'img_shared_b',
        name: 'pic_b',
        hash: 'hash_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          shared.storagePath, Uint8List.fromList([1]));
      await ImageManifest.addRecord(shared);
      await ImageManifest.addRecord(other);

      await ImageManifest.deleteRecord(shared.id);

      final remaining = await ImageManifest.loadRecords();
      expect(remaining.length, equals(1));
      expect(
          await WebFileStore.exists('pictures/${shared.storagePath}'), isTrue,
          reason: 'file shared with a remaining record must not be deleted');
    });

    testWidgets('deleteRecord deletes thumbnail only when hash is unique',
        (WidgetTester t) async {
      final record = ImageRecord(
        id: 'img_thumb_1',
        name: 'pic',
        hash: 'hash_thumb_only',
        format: 'png',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          record.storagePath, Uint8List.fromList([1]));
      await ImageManifest.writeFile(
          imageThumbFileName('hash_thumb_only'), Uint8List.fromList([2]));
      // 旧版（变形）命名残留文件：删除记录时必须一并清理
      await ImageManifest.writeFile(
          'hash_thumb_only_thumb.png', Uint8List.fromList([5]));
      await ImageManifest.addRecord(record);

      await ImageManifest.deleteRecord(record.id);

      expect(
          await WebFileStore.exists(
              'pictures/${imageThumbFileName('hash_thumb_only')}'),
          isFalse,
          reason: 'thumbnail must be deleted when its hash is no longer used');
      expect(
          await WebFileStore.exists('pictures/hash_thumb_only_thumb.png'),
          isFalse,
          reason:
              'legacy distorted thumbnail must also be cleaned up on delete');
    });

    testWidgets(
        'deleteRecord keeps thumbnail while another record shares the hash',
        (WidgetTester t) async {
      final record = ImageRecord(
        id: 'img_thumb_2',
        name: 'pic',
        hash: 'hash_thumb_shared',
        format: 'png',
        createdAt: DateTime.now(),
        size: 4,
      );
      final twin = ImageRecord(
        id: 'img_thumb_3',
        name: 'pic2',
        hash: 'hash_thumb_shared',
        format: 'jpg', // different storage name, same hash → shared thumbnail
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          imageThumbFileName('hash_thumb_shared'), Uint8List.fromList([2]));
      // 旧版命名残留：hash 仍有记录引用时不得清理
      await ImageManifest.writeFile(
          'hash_thumb_shared_thumb.png', Uint8List.fromList([5]));
      await ImageManifest.addRecord(record);
      await ImageManifest.addRecord(twin);

      await ImageManifest.deleteRecord(record.id);

      expect(
          await WebFileStore.exists(
              'pictures/${imageThumbFileName('hash_thumb_shared')}'),
          isTrue,
          reason: 'thumbnail must stay while the twin record still uses it');
      expect(
          await WebFileStore.exists('pictures/hash_thumb_shared_thumb.png'),
          isTrue,
          reason:
              'legacy thumbnail must stay while the twin record still uses it');
    });

    testWidgets(
        'deleteRecords removes entity file only after the last reference is deleted',
        (WidgetTester t) async {
      final shared1 = ImageRecord(
        id: 'img_batch_1',
        name: 'a',
        hash: 'hash_batch_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      final shared2 = ImageRecord(
        id: 'img_batch_2',
        name: 'b',
        hash: 'hash_batch_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      final unique = ImageRecord(
        id: 'img_batch_3',
        name: 'c',
        hash: 'hash_batch_unique',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          shared1.storagePath, Uint8List.fromList([1]));
      await ImageManifest.writeFile(
          unique.storagePath, Uint8List.fromList([2]));
      await ImageManifest.writeFile(
          imageThumbFileName('hash_batch_shared'), Uint8List.fromList([3]));
      await ImageManifest.writeFile(
          imageThumbFileName('hash_batch_unique'), Uint8List.fromList([4]));
      await ImageManifest.addRecord(shared1);
      await ImageManifest.addRecord(shared2);
      await ImageManifest.addRecord(unique);

      // Delete shared1 + unique: shared file must survive (shared2 remains),
      // unique file must be removed.
      await ImageManifest.deleteRecords([shared1.id, unique.id]);

      final remaining = await ImageManifest.loadRecords();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(shared2.id));
      expect(
          await WebFileStore.exists('pictures/${shared1.storagePath}'), isTrue,
          reason: 'shared entity file must survive while one record remains');
      expect(
          await WebFileStore.exists('pictures/${unique.storagePath}'), isFalse,
          reason: 'unique entity file must be deleted');
      expect(
          await WebFileStore.exists(
              'pictures/${imageThumbFileName('hash_batch_shared')}'),
          isTrue,
          reason: 'shared thumbnail must survive while one record remains');
      expect(
          await WebFileStore.exists(
              'pictures/${imageThumbFileName('hash_batch_unique')}'),
          isFalse,
          reason: 'unique thumbnail must be deleted');
    });

    testWidgets('audio deleteRecord removes the .txt sidecar via onExtraDelete',
        (WidgetTester t) async {
      final hash = 'hash_sidecar';
      await FileManifest.writeFile('$hash.wav', Uint8List.fromList([1, 2]));
      await FileManifest.writeFile('$hash.txt', Uint8List.fromList([97]));

      final record = AudioRecord(
        id: 'audio_sidecar_1',
        name: 'tts',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 2,
        sourceText: 'a',
      );
      await FileManifest.addRecord(record);

      await FileManifest.deleteRecord(record.id);

      expect(await WebFileStore.exists('tts_audio/$hash.wav'), isFalse,
          reason: 'audio entity file must be deleted');
      expect(await WebFileStore.exists('tts_audio/$hash.txt'), isFalse,
          reason: 'audio .txt sidecar must be deleted via onExtraDelete');
    });

    testWidgets('deleteRecord with unknown id is a no-op',
        (WidgetTester t) async {
      final record = ImageRecord(
        id: 'img_keep_1',
        name: 'keep',
        hash: 'hash_keep',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      // The file exists on disk — deleting an unknown id must not touch it.
      await ImageManifest.writeFile(
          record.storagePath, Uint8List.fromList([1]));
      await ImageManifest.addRecord(record);

      await ImageManifest.deleteRecord('does_not_exist');

      expect(await ImageManifest.loadRecords(), hasLength(1));
      expect(await WebFileStore.exists('pictures/hash_keep.jpg'), isTrue,
          reason: 'unknown-id delete must not remove the physical file');
    });

    testWidgets('deleteRecords with empty id list is a no-op',
        (WidgetTester t) async {
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_keep_2',
        name: 'keep',
        hash: 'hash_keep_2',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      ));

      await ImageManifest.deleteRecords(const []);

      expect(await ImageManifest.loadRecords(), hasLength(1));
    });

    testWidgets('video deleteRecord removes .jpg thumbnail when hash is unique',
        (WidgetTester t) async {
      final record = VideoRecord(
        id: 'vid_thumb_1',
        name: 'clip',
        hash: 'hash_vid_thumb',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
      );
      await VideoManifest.writeFile(
          record.storagePath, Uint8List.fromList([1]));
      await VideoManifest.writeFile(
          'hash_vid_thumb_thumb.jpg', Uint8List.fromList([2]));
      await VideoManifest.addRecord(record);

      await VideoManifest.deleteRecord(record.id);

      expect(
          await WebFileStore.exists('videos/hash_vid_thumb_thumb.jpg'), isFalse,
          reason: 'video thumbnail (.jpg) must be deleted with its record');
    });

    testWidgets('video deleteRecords keeps .jpg thumbnail while hash is shared',
        (WidgetTester t) async {
      final a = VideoRecord(
        id: 'vid_thumb_2',
        name: 'a',
        hash: 'hash_vid_thumb_shared',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
      );
      final b = VideoRecord(
        id: 'vid_thumb_3',
        name: 'b',
        hash: 'hash_vid_thumb_shared',
        format: 'mov',
        createdAt: DateTime.now(),
        size: 4,
      );
      await VideoManifest.writeFile(
          'hash_vid_thumb_shared_thumb.jpg', Uint8List.fromList([2]));
      await VideoManifest.addRecord(a);
      await VideoManifest.addRecord(b);

      await VideoManifest.deleteRecords([a.id]);

      expect(
          await WebFileStore.exists('videos/hash_vid_thumb_shared_thumb.jpg'),
          isTrue,
          reason: 'thumbnail must stay while one record still uses it');
    });

    testWidgets(
        'audio deleteRecords removes the .txt sidecar via onExtraDelete',
        (WidgetTester t) async {
      final hash = 'hash_sidecar_batch';
      await FileManifest.writeFile('$hash.wav', Uint8List.fromList([1, 2]));
      await FileManifest.writeFile('$hash.txt', Uint8List.fromList([97]));
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_sidecar_b1',
        name: 'a',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 2,
        sourceText: 'a',
      ));
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_sidecar_b2',
        name: 'b',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 2,
        sourceText: 'b',
      ));

      // Delete one of the two sharing records — sidecar must survive.
      await FileManifest.deleteRecords(['audio_sidecar_b1']);
      expect(await WebFileStore.exists('tts_audio/$hash.txt'), isTrue,
          reason: 'sidecar must survive while one record remains');

      // Delete the last reference — sidecar must be removed.
      await FileManifest.deleteRecords(['audio_sidecar_b2']);
      expect(await WebFileStore.exists('tts_audio/$hash.txt'), isFalse,
          reason: 'sidecar must be deleted when the last record is removed');
      expect(await WebFileStore.exists('tts_audio/$hash.wav'), isFalse);
    });

    testWidgets('moveRecord to root clears the folder', (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_root_1',
        name: 'v',
        hash: 'hash_root_move',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await VideoManifest.moveRecord('vid_root_1', '');

      final records = await VideoManifest.loadRecords();
      expect(records.first.folder, isEmpty);
    });

    testWidgets('readFile/fileExists return null/false after deletion',
        (WidgetTester t) async {
      final record = ImageRecord(
        id: 'img_after_1',
        name: 'pic',
        hash: 'hash_after',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.writeFile(
          record.storagePath, Uint8List.fromList([9]));
      await ImageManifest.addRecord(record);
      await ImageManifest.deleteRecord(record.id);

      expect(await ImageManifest.readFile(record.storagePath), isNull);
      expect(
          await WebFileStore.exists('pictures/${record.storagePath}'), isFalse);
    });
  });

  // ====================================================================
  // removeFolder — records, folder entries and ref-counted files
  // ====================================================================

  group('removeFolder', () {
    testWidgets(
        'deletes records in folder + nested descendants, folder entries and files',
        (WidgetTester t) async {
      final inFolder = ImageRecord(
        id: 'img_folder_1',
        name: 'in_folder',
        hash: 'hash_in_folder',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'f',
      );
      final inSub = ImageRecord(
        id: 'img_folder_2',
        name: 'in_sub',
        hash: 'hash_in_sub',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'f/sub',
      );
      final root = ImageRecord(
        id: 'img_folder_3',
        name: 'root',
        hash: 'hash_root',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.addFolder('f/sub');
      for (final r in [inFolder, inSub, root]) {
        await ImageManifest.writeFile(r.storagePath, Uint8List.fromList([1]));
        await ImageManifest.addRecord(r);
      }

      await ImageManifest.removeFolder('f');

      final remaining = await ImageManifest.loadRecords();
      expect(remaining.map((r) => r.id), equals(['img_folder_3']));
      final folders = await ImageManifest.getAllFolders();
      expect(folders, isNot(contains('f')));
      expect(folders, isNot(contains('f/sub')));
      expect(await WebFileStore.exists('pictures/hash_in_folder.jpg'), isFalse);
      expect(await WebFileStore.exists('pictures/hash_in_sub.jpg'), isFalse);
      expect(await WebFileStore.exists('pictures/hash_root.jpg'), isTrue,
          reason: 'root record file must survive');
    });

    testWidgets('keeps files referenced from records outside the folder',
        (WidgetTester t) async {
      final inside = ImageRecord(
        id: 'img_ref_1',
        name: 'inside',
        hash: 'hash_ref_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'f',
      );
      final outside = ImageRecord(
        id: 'img_ref_2',
        name: 'outside',
        hash: 'hash_ref_shared',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
      );
      await ImageManifest.addFolder('f');
      await ImageManifest.writeFile(
          inside.storagePath, Uint8List.fromList([1]));
      await ImageManifest.addRecord(inside);
      await ImageManifest.addRecord(outside);

      await ImageManifest.removeFolder('f');

      expect(await WebFileStore.exists('pictures/hash_ref_shared.jpg'), isTrue,
          reason: 'file referenced by the surviving record must stay');
      expect(await ImageManifest.loadRecords(), hasLength(1));
    });

    testWidgets('on an empty folder removes only the folder entry',
        (WidgetTester t) async {
      await TextManifest.addFolder('empty_folder');
      await TextManifest.addRecord(TextRecord(
        id: 'txt_keep',
        name: 'keep',
        hash: 'hash_keep_txt',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'other',
      ));

      await TextManifest.removeFolder('empty_folder');

      final folders = await TextManifest.getAllFolders();
      expect(folders, isNot(contains('empty_folder')));
      expect(folders, contains('other'));
      expect(await TextManifest.loadRecords(), hasLength(1));
    });

    testWidgets('removeFolder with an empty name is a no-op (no data loss)',
        (WidgetTester t) async {
      final root = ImageRecord(
        id: 'img_rf_empty_1',
        name: 'root_pic',
        hash: 'hash_rf_empty_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: '',
      );
      final nested = ImageRecord(
        id: 'img_rf_empty_2',
        name: 'nested_pic',
        hash: 'hash_rf_empty_2',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'f',
      );
      await ImageManifest.writeFile(root.storagePath, Uint8List.fromList([1]));
      await ImageManifest.writeFile(
          nested.storagePath, Uint8List.fromList([2]));
      await ImageManifest.addRecord(root);
      await ImageManifest.addRecord(nested);

      await ImageManifest.removeFolder('');

      expect(await ImageManifest.loadRecords(), hasLength(2),
          reason: 'BUG: removeFolder("") must not wipe all records');
      expect(await WebFileStore.exists('pictures/hash_rf_empty_1.jpg'), isTrue,
          reason: 'BUG: removeFolder("") must not delete physical files');
      expect(await ImageManifest.getAllFolders(), contains('f'));
    });

    testWidgets('removes video .jpg thumbnail when folder records are deleted',
        (WidgetTester t) async {
      final record = VideoRecord(
        id: 'vid_rf_1',
        name: 'clip',
        hash: 'hash_vid_rf',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'videos_folder',
      );
      await VideoManifest.addFolder('videos_folder');
      await VideoManifest.writeFile(
          record.storagePath, Uint8List.fromList([1]));
      await VideoManifest.writeFile(
          'hash_vid_rf_thumb.jpg', Uint8List.fromList([2]));
      await VideoManifest.addRecord(record);

      await VideoManifest.removeFolder('videos_folder');

      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(await WebFileStore.exists('videos/hash_vid_rf_thumb.jpg'), isFalse,
          reason: 'video .jpg thumbnail must be deleted with its folder');
    });

    testWidgets('removes audio .txt sidecar when folder records are deleted',
        (WidgetTester t) async {
      final hash = 'hash_sidecar_folder';
      await FileManifest.writeFile('$hash.wav', Uint8List.fromList([1, 2]));
      await FileManifest.writeFile('$hash.txt', Uint8List.fromList([97]));
      await FileManifest.addFolder('audio_folder');
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_rf_1',
        name: 'tts',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 2,
        folder: 'audio_folder',
        sourceText: 'a',
      ));

      await FileManifest.removeFolder('audio_folder');

      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await WebFileStore.exists('tts_audio/$hash.txt'), isFalse,
          reason: 'audio .txt sidecar must be deleted with its folder');
      expect(await WebFileStore.exists('tts_audio/$hash.wav'), isFalse);
    });
  });

  // ====================================================================
  // Folder tracking behaviors
  // ====================================================================

  group('folder tracking', () {
    testWidgets('addRecord tracks folder and all ancestors',
        (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_track_1',
        name: 'v',
        hash: 'hash_track_v',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a/b/c',
      ));

      final folders = await VideoManifest.getAllFolders();
      expect(folders, containsAll(['a', 'a/b', 'a/b/c']));
    });

    testWidgets('moveRecord to nested folder tracks all ancestors',
        (WidgetTester t) async {
      await VideoManifest.addRecord(VideoRecord(
        id: 'vid_track_2',
        name: 'v',
        hash: 'hash_track_v2',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 4,
        folder: '',
      ));

      await VideoManifest.moveRecord('vid_track_2', 'x/y/z');

      final folders = await VideoManifest.getAllFolders();
      expect(folders, containsAll(['x', 'x/y', 'x/y/z']));
      final records = await VideoManifest.loadRecords();
      expect(records.first.folder, equals('x/y/z'));
    });

    testWidgets('addFolder ignores empty and whitespace names',
        (WidgetTester t) async {
      await TextManifest.addFolder('');
      await TextManifest.addFolder('   ');

      expect(await TextManifest.getAllFolders(), isEmpty);
    });

    testWidgets(
        'removeFolderFromCache moves records to root and clears entries',
        (WidgetTester t) async {
      final top = ImageRecord(
        id: 'img_rfc_1',
        name: 'top',
        hash: 'hash_rfc_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      );
      final sub = ImageRecord(
        id: 'img_rfc_2',
        name: 'sub',
        hash: 'hash_rfc_2',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a/sub',
      );
      await ImageManifest.addFolder('a/sub');
      await ImageManifest.addRecord(top);
      await ImageManifest.addRecord(sub);

      await ImageManifest.removeFolderFromCache('a');

      // Reload from the store to prove the DB rows were updated too.
      ImageManifest.invalidateCache();
      final records = await ImageManifest.loadRecords();
      for (final r in records) {
        expect(r.folder, isEmpty,
            reason: 'records under a removed folder path must move to root');
      }
      final folders = await ImageManifest.getAllFolders();
      expect(folders, isNot(contains('a')));
      expect(folders, isNot(contains('a/sub')));
    });
  });
}
