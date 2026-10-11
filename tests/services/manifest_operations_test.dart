import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/manifest_operations.dart';
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
    ManifestDatabase.beforeFolderInsertForTesting = null;
    ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
    ManifestDatabase.beforeWebDataSaveForTesting = null;
    FileManifest.onWaitingForAudioHashFileSaveForTesting = null;
    FileManifest.beforeAudioPrimaryDeleteForTesting = null;
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
      expect(await WebFileStore.exists('pictures/hash_thumb_only_thumb.png'),
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
      expect(await WebFileStore.exists('pictures/hash_thumb_shared_thumb.png'),
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

    testWidgets(
      'single audio deletion keeps the sidecar while another format shares its hash',
      (WidgetTester t) async {
        const hash = 'hash_sidecar_shared_formats_single';
        final audioBytes = Uint8List.fromList([1, 2]);
        final sidecarBytes = Uint8List.fromList([97, 98]);
        final wav = AudioRecord(
          id: 'audio_sidecar_shared_formats_single_wav',
          name: 'wav',
          hash: hash,
          format: 'wav',
          createdAt: DateTime.now(),
          size: 2,
          sourceText: 'shared text',
        );
        final mp3 = AudioRecord(
          id: 'audio_sidecar_shared_formats_single_mp3',
          name: 'mp3',
          hash: hash,
          format: 'mp3',
          createdAt: DateTime.now(),
          size: 2,
          sourceText: 'shared text',
        );
        await FileManifest.writeFile(wav.storagePath, audioBytes);
        await FileManifest.writeFile(mp3.storagePath, audioBytes);
        await FileManifest.writeFile(wav.textStoragePath, sidecarBytes);
        await FileManifest.addRecord(wav);
        await FileManifest.addRecord(mp3);

        await FileManifest.deleteRecord(wav.id);

        expect(
            await WebFileStore.exists('tts_audio/${wav.storagePath}'), isFalse);
        expect(
            await WebFileStore.exists('tts_audio/${mp3.storagePath}'), isTrue);
        expect(
          await WebFileStore.exists('tts_audio/${wav.textStoragePath}'),
          isTrue,
          reason: 'the remaining format still references the hash sidecar',
        );

        await FileManifest.deleteRecord(mp3.id);

        expect(
            await WebFileStore.exists('tts_audio/${mp3.storagePath}'), isFalse);
        expect(
          await WebFileStore.exists('tts_audio/${mp3.textStoragePath}'),
          isFalse,
          reason: 'the sidecar is removed after its last hash reference',
        );
      },
    );

    testWidgets(
      'batch audio deletion keeps the sidecar while another format shares its hash',
      (WidgetTester t) async {
        const hash = 'hash_sidecar_shared_formats_batch';
        final audioBytes = Uint8List.fromList([1, 2]);
        final sidecarBytes = Uint8List.fromList([97, 98]);
        final wav = AudioRecord(
          id: 'audio_sidecar_shared_formats_batch_wav',
          name: 'wav',
          hash: hash,
          format: 'wav',
          createdAt: DateTime.now(),
          size: 2,
          sourceText: 'shared text',
        );
        final mp3 = AudioRecord(
          id: 'audio_sidecar_shared_formats_batch_mp3',
          name: 'mp3',
          hash: hash,
          format: 'mp3',
          createdAt: DateTime.now(),
          size: 2,
          sourceText: 'shared text',
        );
        await FileManifest.writeFile(wav.storagePath, audioBytes);
        await FileManifest.writeFile(mp3.storagePath, audioBytes);
        await FileManifest.writeFile(wav.textStoragePath, sidecarBytes);
        await FileManifest.addRecord(wav);
        await FileManifest.addRecord(mp3);

        await FileManifest.deleteRecords([wav.id]);

        expect(
            await WebFileStore.exists('tts_audio/${wav.storagePath}'), isFalse);
        expect(
            await WebFileStore.exists('tts_audio/${mp3.storagePath}'), isTrue);
        expect(
          await WebFileStore.exists('tts_audio/${wav.textStoragePath}'),
          isTrue,
          reason: 'the remaining format still references the hash sidecar',
        );

        await FileManifest.deleteRecords([mp3.id]);

        expect(
            await WebFileStore.exists('tts_audio/${mp3.storagePath}'), isFalse);
        expect(
          await WebFileStore.exists('tts_audio/${mp3.textStoragePath}'),
          isFalse,
          reason: 'the sidecar is removed after its last hash reference',
        );
      },
    );

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

  group('audio deletion persistence failures', () {
    final audioBytes = Uint8List.fromList([1, 2, 3]);
    final sidecarBytes = Uint8List.fromList([97, 98]);

    AudioRecord audioRecord(String id, String hash) => AudioRecord(
          id: id,
          name: id,
          hash: hash,
          format: 'wav',
          createdAt: DateTime.utc(2024),
          size: audioBytes.length,
          sourceText: 'ab',
        );

    Future<void> addRecordWithFiles(AudioRecord record) async {
      await FileManifest.writeFile(record.storagePath, audioBytes);
      await FileManifest.writeFile(record.textStoragePath, sidecarBytes);
      await FileManifest.addRecord(record);
    }

    Future<List<String>> persistedAudioIds() async {
      final raw = await WebFileStore.read('manifest_database_data');
      expect(raw, isNotNull);
      final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
      final records =
          data[ManifestTables.audioRecords] as List<dynamic>? ?? const [];
      return records.map((row) => (row as Map)['id'] as String).toList();
    }

    Future<List<String>> persistedImageIds() async {
      final raw = await WebFileStore.read('manifest_database_data');
      expect(raw, isNotNull);
      final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
      final records =
          data[ManifestTables.imageRecords] as List<dynamic>? ?? const [];
      return records.map((row) => (row as Map)['id'] as String).toList();
    }

    Future<Map<String, dynamic>> persistedAudioRecord(String id) async {
      final raw = await WebFileStore.read('manifest_database_data');
      expect(raw, isNotNull);
      final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
      final records =
          data[ManifestTables.audioRecords] as List<dynamic>? ?? const [];
      return Map<String, dynamic>.from(
        records.singleWhere((row) => (row as Map)['id'] == id) as Map,
      );
    }

    Future<void> expectDeleteFailurePreservesStateAndCanRetry({
      required List<AudioRecord> records,
      required List<String> deletedIds,
      required Future<void> Function() delete,
    }) async {
      final originalIds = records.map((record) => record.id).toList();
      expect(
        (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
        unorderedEquals(originalIds),
      );
      expect(
        (await FileManifest.loadRecords()).map((record) => record.id),
        unorderedEquals(originalIds),
      );

      final failure = StateError('injected audio deletion persistence failure');
      var failureInjected = false;
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        failureInjected = true;
        ManifestDatabase.beforeWebDataSaveForTesting = null;
        throw failure;
      };

      await expectLater(delete(), throwsA(same(failure)));
      expect(failureInjected, isTrue);
      expect(
        (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
        unorderedEquals(originalIds),
        reason: 'failed JSON persistence must restore the database record list',
      );
      expect(
        (await FileManifest.loadRecords()).map((record) => record.id),
        unorderedEquals(originalIds),
        reason: 'failed metadata deletion must leave the manifest cache intact',
      );
      for (final record in records) {
        expect(
          await WebFileStore.read('tts_audio/${record.storagePath}'),
          equals(audioBytes),
          reason: 'the audio bytes must remain usable after a failed deletion',
        );
        expect(
          await WebFileStore.read('tts_audio/${record.textStoragePath}'),
          equals(sidecarBytes),
          reason: 'the source-text sidecar must remain usable after a failure',
        );
      }

      await delete();

      final remainingRecords =
          records.where((record) => !deletedIds.contains(record.id)).toList();
      final remainingIds = remainingRecords.map((record) => record.id).toList();
      expect(
        (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
        unorderedEquals(remainingIds),
        reason: 'retry must remove the requested durable metadata',
      );
      expect(
        (await FileManifest.loadRecords()).map((record) => record.id),
        unorderedEquals(remainingIds),
        reason: 'retry must update the manifest cache',
      );
      for (final record in records) {
        final shouldRemain = !deletedIds.contains(record.id);
        expect(
          await WebFileStore.exists('tts_audio/${record.storagePath}'),
          shouldRemain,
          reason: 'audio files must match the successful retry result',
        );
        expect(
          await WebFileStore.exists('tts_audio/${record.textStoragePath}'),
          shouldRemain,
          reason: 'sidecars must match the successful retry result',
        );
      }
    }

    Future<void> expectConcurrentRegistrationSurvivesFailedDelete({
      required WidgetTester tester,
      required List<AudioRecord> recordsToDelete,
      required Future<void> Function() delete,
      required Future<void> Function() retry,
      required String concurrentId,
      required Future<void> Function(AudioRecord record)
          registerConcurrentRecord,
      bool concurrentRegistrationInFileManifest = true,
    }) async {
      for (final record in recordsToDelete) {
        await addRecordWithFiles(record);
      }
      final concurrentRecord = audioRecord(
        concurrentId,
        'hash_$concurrentId',
      );
      await FileManifest.writeFile(concurrentRecord.storagePath, audioBytes);
      await FileManifest.writeFile(
        concurrentRecord.textStoragePath,
        sidecarBytes,
      );

      final deletedIds = recordsToDelete.map((record) => record.id).toList();
      final originalIds = [...deletedIds, concurrentRecord.id];
      // Warm both data layers before installing the one-shot persistence hook.
      await ManifestDatabase.getAllAudioRecords();
      await FileManifest.loadRecords();
      expect(await persistedAudioIds(), unorderedEquals(deletedIds));

      final deleteWriteStarted = Completer<void>();
      final registrationAttempted = Completer<void>();
      final registrationWriteStarted = Completer<void>();
      final releaseDeleteWrite = Completer<void>();
      final failure = StateError('injected audio deletion persistence failure');
      var saveCount = 0;
      ManifestDatabase.beforeJsonRecordRegistrationForTesting = () {
        if (!registrationAttempted.isCompleted) {
          registrationAttempted.complete();
        }
      };
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        saveCount++;
        if (saveCount == 1) {
          deleteWriteStarted.complete();
          await releaseDeleteWrite.future;
          throw failure;
        }
        if (saveCount == 2) registrationWriteStarted.complete();
      };

      final deleteFuture = delete();
      await deleteWriteStarted.future;
      final registrationFuture = registerConcurrentRecord(concurrentRecord);
      await registrationAttempted.future;
      await tester.pump();
      final registrationWroteBeforeDeleteFailed =
          registrationWriteStarted.isCompleted;
      releaseDeleteWrite.complete();

      await expectLater(deleteFuture, throwsA(same(failure)));
      await registrationFuture;
      ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
      ManifestDatabase.beforeWebDataSaveForTesting = null;

      expect(
        registrationWroteBeforeDeleteFailed,
        isFalse,
        reason:
            'registration persistence must wait for the failed delete rollback',
      );
      expect(
        (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
        unorderedEquals(originalIds),
      );
      final cachedIdsAfterRegistration =
          concurrentRegistrationInFileManifest ? originalIds : deletedIds;
      expect(
        (await FileManifest.loadRecords()).map((record) => record.id),
        unorderedEquals(cachedIdsAfterRegistration),
      );
      expect(await persistedAudioIds(), unorderedEquals(originalIds));
      for (final record in [...recordsToDelete, concurrentRecord]) {
        expect(
          await WebFileStore.read('tts_audio/${record.storagePath}'),
          equals(audioBytes),
        );
        expect(
          await WebFileStore.read('tts_audio/${record.textStoragePath}'),
          equals(sidecarBytes),
        );
      }

      await retry();

      expect(
        (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
        equals([concurrentRecord.id]),
      );
      expect(
        (await FileManifest.loadRecords()).map((record) => record.id),
        equals(concurrentRegistrationInFileManifest
            ? [concurrentRecord.id]
            : <String>[]),
      );
      expect(await persistedAudioIds(), equals([concurrentRecord.id]));
      for (final record in recordsToDelete) {
        expect(
          await WebFileStore.exists('tts_audio/${record.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${record.textStoragePath}'),
          isFalse,
        );
      }
      expect(
        await WebFileStore.exists('tts_audio/${concurrentRecord.storagePath}'),
        isTrue,
      );
      expect(
        await WebFileStore.exists(
          'tts_audio/${concurrentRecord.textStoragePath}',
        ),
        isTrue,
      );
    }

    testWidgets(
      'single delete preserves metadata, cache, audio and sidecar after JSON save failure',
      (WidgetTester t) async {
        final record = audioRecord(
          'audio_single_delete_retry',
          'hash_single_retry',
        );
        await addRecordWithFiles(record);

        await expectDeleteFailurePreservesStateAndCanRetry(
          records: [record],
          deletedIds: [record.id],
          delete: () => FileManifest.deleteRecord(record.id),
        );
      },
    );

    testWidgets(
      'batch delete preserves metadata, cache, audio and sidecars after JSON save failure',
      (WidgetTester t) async {
        final first = audioRecord(
          'audio_batch_delete_retry_1',
          'hash_batch_retry_1',
        );
        final second = audioRecord(
          'audio_batch_delete_retry_2',
          'hash_batch_retry_2',
        );
        final survivor = audioRecord(
          'audio_batch_delete_survivor',
          'hash_batch_survivor',
        );
        await addRecordWithFiles(first);
        await addRecordWithFiles(second);
        await addRecordWithFiles(survivor);
        final deletedIds = [first.id, second.id];

        await expectDeleteFailurePreservesStateAndCanRetry(
          records: [first, second, survivor],
          deletedIds: deletedIds,
          delete: () => FileManifest.deleteRecords(deletedIds),
        );
      },
    );

    testWidgets(
      'single delete restores metadata and audio when sidecar cleanup fails',
      (WidgetTester t) async {
        final record = audioRecord(
          'audio_single_cleanup_retry',
          'hash_single_cleanup_retry',
        );
        final failure = StateError('injected sidecar cleanup failure');
        var shouldFail = true;
        final operations = ManifestOperations<AudioRecord>(
          manifestKey: 'audio_cleanup_failure_test',
          storageDirName: 'tts_audio',
          fromMap: AudioRecord.fromMap,
          tableName: ManifestTables.audioRecords,
          toMap: (value) => value.toMap(),
          onExtraDelete: (value) async {
            if (shouldFail) {
              shouldFail = false;
              await WebFileStore.delete('tts_audio/${value.textStoragePath}');
              throw failure;
            }
            await WebFileStore.delete('tts_audio/${value.textStoragePath}');
          },
        );

        await FileManifest.writeFile(record.storagePath, audioBytes);
        await FileManifest.writeFile(record.textStoragePath, sidecarBytes);
        await operations.addRecord(record);

        await expectLater(
          operations.deleteRecord(record.id),
          throwsA(same(failure)),
        );
        expect(
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          contains(record.id),
          reason: 'failed file cleanup must restore durable audio metadata',
        );
        expect(await persistedAudioIds(), contains(record.id));
        expect(
          (await operations.loadRecords()).map((row) => row.id),
          contains(record.id),
          reason: 'failed file cleanup must retain the cached audio row',
        );
        expect(
          await WebFileStore.read('tts_audio/${record.storagePath}'),
          equals(audioBytes),
        );
        expect(
          await WebFileStore.read('tts_audio/${record.textStoragePath}'),
          equals(sidecarBytes),
        );

        await operations.deleteRecord(record.id);

        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(await operations.loadRecords(), isEmpty);
        expect(
          await WebFileStore.exists('tts_audio/${record.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${record.textStoragePath}'),
          isFalse,
        );
      },
    );

    testWidgets(
      'batch delete restores metadata and audio when sidecar cleanup fails',
      (WidgetTester t) async {
        final first = audioRecord(
          'audio_batch_cleanup_retry_1',
          'hash_batch_cleanup_retry_1',
        );
        final second = audioRecord(
          'audio_batch_cleanup_retry_2',
          'hash_batch_cleanup_retry_2',
        );
        final failure = StateError('injected sidecar cleanup failure');
        var cleanupCount = 0;
        final operations = ManifestOperations<AudioRecord>(
          manifestKey: 'audio_cleanup_failure_test',
          storageDirName: 'tts_audio',
          fromMap: AudioRecord.fromMap,
          tableName: ManifestTables.audioRecords,
          toMap: (value) => value.toMap(),
          onExtraDelete: (value) async {
            cleanupCount++;
            if (cleanupCount == 2) {
              throw failure;
            }
            await WebFileStore.delete('tts_audio/${value.textStoragePath}');
          },
        );
        for (final record in [first, second]) {
          await FileManifest.writeFile(record.storagePath, audioBytes);
          await FileManifest.writeFile(record.textStoragePath, sidecarBytes);
          await operations.addRecord(record);
        }

        await expectLater(
          operations.deleteRecords([first.id, second.id]),
          throwsA(same(failure)),
        );
        expect(
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          unorderedEquals([first.id, second.id]),
          reason: 'failed batch cleanup must restore all durable audio rows',
        );
        expect(
          await persistedAudioIds(),
          unorderedEquals([first.id, second.id]),
        );
        expect(
          (await operations.loadRecords()).map((row) => row.id),
          unorderedEquals([first.id, second.id]),
          reason: 'failed batch cleanup must retain all cached audio rows',
        );
        for (final record in [first, second]) {
          expect(
            await WebFileStore.read('tts_audio/${record.storagePath}'),
            equals(audioBytes),
          );
          expect(
            await WebFileStore.read('tts_audio/${record.textStoragePath}'),
            equals(sidecarBytes),
          );
        }

        await operations.deleteRecords([first.id, second.id]);

        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(await operations.loadRecords(), isEmpty);
        for (final record in [first, second]) {
          expect(
            await WebFileStore.exists('tts_audio/${record.storagePath}'),
            isFalse,
          );
          expect(
            await WebFileStore.exists('tts_audio/${record.textStoragePath}'),
            isFalse,
          );
        }
      },
    );

    testWidgets(
      'batch cleanup keeps metadata only for primary files still present',
      (WidgetTester t) async {
        final first = audioRecord(
          'audio_batch_primary_cleanup_failure_1',
          'hash_batch_primary_cleanup_failure_1',
        );
        final second = audioRecord(
          'audio_batch_primary_cleanup_failure_2',
          'hash_batch_primary_cleanup_failure_2',
        );
        final failure = StateError('injected second primary file failure');
        var primaryDeleteCount = 0;
        final operations = ManifestOperations<AudioRecord>(
          manifestKey: 'audio_primary_cleanup_failure_test',
          storageDirName: 'tts_audio',
          fromMap: AudioRecord.fromMap,
          tableName: ManifestTables.audioRecords,
          toMap: (value) => value.toMap(),
          onExtraDelete: (value) =>
              WebFileStore.delete('tts_audio/${value.textStoragePath}'),
        )..beforeAudioPrimaryDeleteForTesting = (name) async {
            primaryDeleteCount++;
            if (primaryDeleteCount == 2) throw failure;
          };

        for (final record in [first, second]) {
          await FileManifest.writeFile(record.storagePath, audioBytes);
          await FileManifest.writeFile(record.textStoragePath, sidecarBytes);
          await operations.addRecord(record);
        }

        await expectLater(
          operations.deleteRecords([first.id, second.id]),
          throwsA(same(failure)),
        );

        for (final checkRows in [
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          await persistedAudioIds(),
          (await operations.loadRecords()).map((record) => record.id),
        ]) {
          expect(checkRows, equals([second.id]));
        }
        expect(
          await WebFileStore.exists('tts_audio/${first.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${first.textStoragePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${second.storagePath}'),
          isTrue,
        );
        expect(
          await WebFileStore.read('tts_audio/${second.textStoragePath}'),
          equals(sidecarBytes),
        );

        await operations.deleteRecords([second.id]);

        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(await operations.loadRecords(), isEmpty);
        expect(
          await WebFileStore.exists('tts_audio/${second.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${second.textStoragePath}'),
          isFalse,
        );
      },
    );

    testWidgets(
      'single delete rollback preserves a concurrent audio registration',
      (WidgetTester t) async {
        final record = audioRecord(
          'audio_single_concurrent_delete_retry',
          'hash_single_concurrent_delete_retry',
        );
        await expectConcurrentRegistrationSurvivesFailedDelete(
          tester: t,
          recordsToDelete: [record],
          delete: () => FileManifest.deleteRecord(record.id),
          retry: () => FileManifest.deleteRecord(record.id),
          concurrentId: 'audio_single_concurrent_registration',
          registerConcurrentRecord: FileManifest.addRecord,
        );
      },
    );

    testWidgets(
      'batch delete rollback preserves a concurrent audio registration',
      (WidgetTester t) async {
        final first = audioRecord(
          'audio_batch_concurrent_delete_retry_1',
          'hash_batch_concurrent_delete_retry_1',
        );
        final second = audioRecord(
          'audio_batch_concurrent_delete_retry_2',
          'hash_batch_concurrent_delete_retry_2',
        );
        await expectConcurrentRegistrationSurvivesFailedDelete(
          tester: t,
          recordsToDelete: [first, second],
          delete: () => FileManifest.deleteRecords([first.id, second.id]),
          retry: () => FileManifest.deleteRecords([first.id, second.id]),
          concurrentId: 'audio_batch_concurrent_registration',
          registerConcurrentRecord: FileManifest.addRecord,
        );
      },
    );

    testWidgets(
      'same-hash registration waits for audio sidecar deletion across formats',
      (WidgetTester t) async {
        const hash = 'hash_concurrent_shared_sidecar_delete';
        final target = audioRecord(
          'audio_concurrent_shared_sidecar_delete_target',
          hash,
        );
        final concurrent = AudioRecord(
          id: 'audio_concurrent_shared_sidecar_delete_survivor',
          name: 'survivor',
          hash: hash,
          format: 'mp3',
          createdAt: DateTime.utc(2024),
          size: audioBytes.length,
          sourceText: 'ab',
        );
        await addRecordWithFiles(target);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();

        final deleteWriteStarted = Completer<void>();
        final releaseDeleteWrite = Completer<void>();
        var hookInvoked = false;
        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          if (hookInvoked) return;
          hookInvoked = true;
          ManifestDatabase.beforeWebDataSaveForTesting = null;
          deleteWriteStarted.complete();
          await releaseDeleteWrite.future;
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await deleteWriteStarted.future;

        final registrationAttempted = Completer<void>()..complete();
        final registrationStarted = Completer<void>();
        final registrationFuture = FileManifest.withStorageFileSaveLock(
          concurrent.storageFileName,
          () async {
            registrationStarted.complete();
            await FileManifest.writeFile(concurrent.storagePath, audioBytes);
            await FileManifest.writeFile(
              concurrent.textStoragePath,
              sidecarBytes,
            );
            await FileManifest.addRecord(concurrent);
          },
        );
        await registrationAttempted.future;
        await t.pump();
        expect(
          registrationStarted.isCompleted,
          isFalse,
          reason: 'the different-format save must wait on the shared hash',
        );

        releaseDeleteWrite.complete();
        await deleteFuture;
        await registrationFuture;

        expect(hookInvoked, isTrue);
        expect(
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          equals([concurrent.id]),
        );
        expect(await persistedAudioIds(), equals([concurrent.id]));
        expect(
          (await FileManifest.loadRecords()).map((record) => record.id),
          equals([concurrent.id]),
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${concurrent.storagePath}'),
          isTrue,
        );
        expect(
          await WebFileStore.read('tts_audio/${concurrent.textStoragePath}'),
          equals(sidecarBytes),
          reason: 'the surviving format must have its hash sidecar',
        );
      },
    );

    testWidgets(
      'batch delete acquires storage locks before shared hash locks',
      (WidgetTester t) async {
        const hash = 'hash_batch_shared_lock_order';
        final first = AudioRecord(
          id: 'audio_batch_shared_lock_order_mp3',
          name: 'first',
          hash: hash,
          format: 'mp3',
          createdAt: DateTime.utc(2024),
          size: audioBytes.length,
          sourceText: 'ab',
        );
        final second = AudioRecord(
          id: 'audio_batch_shared_lock_order_wav',
          name: 'second',
          hash: hash,
          format: 'wav',
          createdAt: DateTime.utc(2024),
          size: audioBytes.length,
          sourceText: 'ab',
        );
        final concurrent = AudioRecord(
          id: 'audio_batch_shared_lock_order_registration',
          name: 'concurrent',
          hash: hash,
          format: second.format,
          createdAt: DateTime.utc(2024),
          size: audioBytes.length,
          sourceText: 'ab',
        );
        await addRecordWithFiles(first);
        await addRecordWithFiles(second);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();

        final externalLockAcquired = Completer<void>();
        final releaseExternalLock = Completer<void>();
        final externalHashLock = FileManifest.withStorageFileSaveLock(
          '$hash.ogg',
          () async {
            externalLockAcquired.complete();
            await releaseExternalLock.future;
          },
        );
        await externalLockAcquired.future;

        final batchQueuedForHash = Completer<void>();
        FileManifest.onWaitingForAudioHashFileSaveForTesting = (queuedHash) {
          if (queuedHash == hash && !batchQueuedForHash.isCompleted) {
            batchQueuedForHash.complete();
          }
        };
        final deleteFuture = FileManifest.deleteRecords([first.id, second.id]);
        await batchQueuedForHash.future;

        final registrationQueued = Completer<void>();
        final cancelRegistration = Completer<void>();
        final registrationFuture = FileManifest.withStorageFileSaveLock(
          second.storageFileName,
          () async {
            await FileManifest.writeFile(concurrent.storagePath, audioBytes);
            await FileManifest.writeFile(
              concurrent.textStoragePath,
              sidecarBytes,
            );
            await FileManifest.addRecord(concurrent);
          },
          waitForPrevious: (previous) async {
            await Future.any<void>([
              previous,
              cancelRegistration.future.then<void>(
                (_) => throw StateError('cancelled lock-order regression'),
              ),
            ]);
          },
          onQueued: () {
            if (!registrationQueued.isCompleted) {
              registrationQueued.complete();
            }
          },
        );
        await registrationQueued.future;
        releaseExternalLock.complete();

        try {
          await Future.wait<void>([deleteFuture, registrationFuture])
              .timeout(const Duration(seconds: 5));
        } on TimeoutException {
          cancelRegistration.complete();
          await expectLater(
            registrationFuture,
            throwsA(isA<StateError>()),
          );
          await deleteFuture;
          fail('batch deletion deadlocked with a concurrent same-hash save');
        } finally {
          FileManifest.onWaitingForAudioHashFileSaveForTesting = null;
          if (!releaseExternalLock.isCompleted) {
            releaseExternalLock.complete();
          }
        }
        await externalHashLock;

        expect(
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          equals([concurrent.id]),
        );
        expect(await persistedAudioIds(), equals([concurrent.id]));
        expect(
          (await FileManifest.loadRecords()).map((record) => record.id),
          equals([concurrent.id]),
        );
        expect(
          await WebFileStore.read('tts_audio/${concurrent.storagePath}'),
          equals(audioBytes),
        );
        expect(
          await WebFileStore.read('tts_audio/${concurrent.textStoragePath}'),
          equals(sidecarBytes),
        );
      },
    );

    testWidgets(
      'single delete rollback preserves a concurrent direct audio insert',
      (WidgetTester t) async {
        final record = audioRecord(
          'audio_direct_insert_concurrent_delete_retry',
          'hash_direct_insert_concurrent_delete_retry',
        );
        await expectConcurrentRegistrationSurvivesFailedDelete(
          tester: t,
          recordsToDelete: [record],
          delete: () => FileManifest.deleteRecord(record.id),
          retry: () => FileManifest.deleteRecord(record.id),
          concurrentId: 'audio_direct_insert_concurrent_registration',
          registerConcurrentRecord: (record) =>
              ManifestDatabase.insertAudioRecord(record.toMap()),
          concurrentRegistrationInFileManifest: false,
        );
      },
    );

    testWidgets(
      'single delete rollback preserves a concurrent audio record update',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_concurrent_update_delete_target',
          'hash_concurrent_update_delete_target',
        );
        final survivor = audioRecord(
          'audio_concurrent_update_delete_survivor',
          'hash_concurrent_update_delete_survivor',
        );
        await addRecordWithFiles(target);
        await addRecordWithFiles(survivor);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();
        expect(
          await persistedAudioIds(),
          unorderedEquals([target.id, survivor.id]),
        );

        final deleteWriteStarted = Completer<void>();
        final updateWriteStarted = Completer<void>();
        final releaseDeleteWrite = Completer<void>();
        final failure =
            StateError('injected audio deletion persistence failure');
        var saveCount = 0;
        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          saveCount++;
          if (saveCount == 1) {
            deleteWriteStarted.complete();
            await releaseDeleteWrite.future;
            throw failure;
          }
          if (saveCount == 2) updateWriteStarted.complete();
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await deleteWriteStarted.future;
        final updateFuture = ManifestDatabase.updateAudioRecord(
          survivor.id,
          {'name': 'updated survivor'},
        );
        await t.pump();
        final updateWroteBeforeDeleteFailed = updateWriteStarted.isCompleted;
        releaseDeleteWrite.complete();

        await expectLater(deleteFuture, throwsA(same(failure)));
        await updateFuture;
        ManifestDatabase.beforeWebDataSaveForTesting = null;

        expect(
          updateWroteBeforeDeleteFailed,
          isFalse,
          reason: 'audio updates must wait for delete rollback to finish',
        );
        expect(
          await persistedAudioIds(),
          unorderedEquals([target.id, survivor.id]),
        );
        final databaseRecords = await ManifestDatabase.getAllAudioRecords();
        expect(
          databaseRecords.map((row) => row['id']),
          unorderedEquals([target.id, survivor.id]),
        );
        expect(
          databaseRecords
              .singleWhere((row) => row['id'] == survivor.id)['name'],
          'updated survivor',
        );
        expect(
          (await persistedAudioRecord(survivor.id))['name'],
          'updated survivor',
        );
        expect(
          (await FileManifest.loadRecords()).map((record) => record.id),
          unorderedEquals([target.id, survivor.id]),
        );

        await FileManifest.deleteRecord(target.id);

        expect(await persistedAudioIds(), equals([survivor.id]));
        expect(
          (await ManifestDatabase.getAllAudioRecords()).single['name'],
          'updated survivor',
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.textStoragePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${survivor.storagePath}'),
          isTrue,
        );
        expect(
          await WebFileStore.exists('tts_audio/${survivor.textStoragePath}'),
          isTrue,
        );
      },
    );

    testWidgets(
      'audio table clear waits for a failed delete rollback',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_concurrent_clear_delete_target',
          'hash_concurrent_clear_delete_target',
        );
        final survivor = audioRecord(
          'audio_concurrent_clear_delete_survivor',
          'hash_concurrent_clear_delete_survivor',
        );
        await addRecordWithFiles(target);
        await addRecordWithFiles(survivor);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();
        expect(
          await persistedAudioIds(),
          unorderedEquals([target.id, survivor.id]),
        );

        final deleteWriteStarted = Completer<void>();
        final clearWriteStarted = Completer<void>();
        final releaseDeleteWrite = Completer<void>();
        final failure =
            StateError('injected audio deletion persistence failure');
        var saveCount = 0;
        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          saveCount++;
          if (saveCount == 1) {
            deleteWriteStarted.complete();
            await releaseDeleteWrite.future;
            throw failure;
          }
          if (saveCount == 2) clearWriteStarted.complete();
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await deleteWriteStarted.future;
        final clearFuture =
            ManifestDatabase.clearRecords(ManifestTables.audioRecords);
        await t.pump();
        final clearWroteBeforeDeleteFailed = clearWriteStarted.isCompleted;
        releaseDeleteWrite.complete();

        await expectLater(deleteFuture, throwsA(same(failure)));
        await clearFuture;
        ManifestDatabase.beforeWebDataSaveForTesting = null;

        expect(
          clearWroteBeforeDeleteFailed,
          isFalse,
          reason: 'audio table clear must wait for delete rollback to finish',
        );
        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(await persistedAudioIds(), isEmpty);
      },
    );

    testWidgets(
      'audio table clear waits for file cleanup failure rollback',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_clear_after_cleanup_failure_target',
          'hash_clear_after_cleanup_failure_target',
        );
        await addRecordWithFiles(target);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();
        expect(await persistedAudioIds(), equals([target.id]));

        final cleanupStarted = Completer<void>();
        final releaseCleanupFailure = Completer<void>();
        final clearCompleted = Completer<void>();
        final failure = StateError('injected audio file cleanup failure');
        FileManifest.beforeAudioPrimaryDeleteForTesting = (_) async {
          cleanupStarted.complete();
          await releaseCleanupFailure.future;
          throw failure;
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await cleanupStarted.future;
        final clearFuture = () async {
          await ManifestDatabase.clearRecords(ManifestTables.audioRecords);
          clearCompleted.complete();
        }();
        await t.pump();
        final clearCompletedBeforeCleanup = clearCompleted.isCompleted;
        releaseCleanupFailure.complete();

        try {
          await expectLater(deleteFuture, throwsA(same(failure)));
          await clearFuture;
        } finally {
          FileManifest.beforeAudioPrimaryDeleteForTesting = null;
          ManifestDatabase.beforeWebDataSaveForTesting = null;
        }

        expect(
          clearCompletedBeforeCleanup,
          isFalse,
          reason: 'clear must wait until file cleanup rollback finishes',
        );
        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(await persistedAudioIds(), isEmpty);
        expect(
          await WebFileStore.read('tts_audio/${target.storagePath}'),
          equals(audioBytes),
          reason: 'failed cleanup leaves the audio file available',
        );
        expect(
          await WebFileStore.read('tts_audio/${target.textStoragePath}'),
          equals(sidecarBytes),
          reason: 'failed cleanup restores the sidecar',
        );
      },
    );

    testWidgets(
      'failed audio cleanup preserves a concurrent record update',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_update_after_cleanup_failure_target',
          'hash_update_after_cleanup_failure_target',
        );
        await addRecordWithFiles(target);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();

        final cleanupStarted = Completer<void>();
        final releaseCleanupFailure = Completer<void>();
        final updateCompleted = Completer<void>();
        final failure = StateError('injected audio file cleanup failure');
        FileManifest.beforeAudioPrimaryDeleteForTesting = (_) async {
          cleanupStarted.complete();
          await releaseCleanupFailure.future;
          throw failure;
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await cleanupStarted.future;
        final updateFuture = () async {
          await FileManifest.updateRecord(target.copyWith(name: 'updated'));
          updateCompleted.complete();
        }();
        await t.pump();
        final updateCompletedBeforeCleanup = updateCompleted.isCompleted;
        releaseCleanupFailure.complete();

        try {
          await expectLater(deleteFuture, throwsA(same(failure)));
          await updateFuture;
        } finally {
          FileManifest.beforeAudioPrimaryDeleteForTesting = null;
        }

        expect(
          updateCompletedBeforeCleanup,
          isFalse,
          reason: 'record updates must wait for failed deletion rollback',
        );
        expect(
          (await ManifestDatabase.getAllAudioRecords()).single['name'],
          'updated',
        );
        expect(
          (await FileManifest.loadRecords()).single.name,
          'updated',
        );
        expect(
          (await persistedAudioRecord(target.id))['name'],
          'updated',
        );
        expect(
          await WebFileStore.read('tts_audio/${target.storagePath}'),
          equals(audioBytes),
        );
        expect(
          await WebFileStore.read('tts_audio/${target.textStoragePath}'),
          equals(sidecarBytes),
        );

        await FileManifest.deleteRecord(target.id);
        expect(await persistedAudioIds(), isEmpty);
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.textStoragePath}'),
          isFalse,
        );
      },
    );

    testWidgets(
      'batch audio deletion preserves an update to a surviving record',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_batch_update_survivor_delete_target',
          'hash_batch_update_survivor_delete_target',
        );
        final survivor = audioRecord(
          'audio_batch_update_survivor_record',
          'hash_batch_update_survivor_record',
        );
        await addRecordWithFiles(target);
        await addRecordWithFiles(survivor);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();

        final cleanupStarted = Completer<void>();
        final releaseCleanup = Completer<void>();
        FileManifest.beforeAudioPrimaryDeleteForTesting = (_) async {
          cleanupStarted.complete();
          await releaseCleanup.future;
        };

        final deleteFuture = FileManifest.deleteRecords([target.id]);
        await cleanupStarted.future;
        var updateCompleted = false;
        final updateFuture = FileManifest.updateRecord(
          survivor.copyWith(name: 'updated survivor'),
        ).whenComplete(() => updateCompleted = true);
        await t.pump();
        final updateCompletedBeforeCleanup = updateCompleted;
        final cacheNameWhileDeletePaused = (await FileManifest.loadRecords())
            .singleWhere((record) => record.id == survivor.id)
            .name;

        releaseCleanup.complete();
        try {
          await deleteFuture;
          await updateFuture;
        } finally {
          FileManifest.beforeAudioPrimaryDeleteForTesting = null;
        }

        expect(updateCompletedBeforeCleanup, isFalse);
        expect(cacheNameWhileDeletePaused, 'updated survivor');
        expect(await persistedAudioIds(), equals([survivor.id]));
        expect(
          (await ManifestDatabase.getAllAudioRecords()).single['name'],
          'updated survivor',
        );
        expect(
          (await FileManifest.loadRecords()).single.name,
          'updated survivor',
        );
        expect(
          (await persistedAudioRecord(survivor.id))['name'],
          'updated survivor',
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.textStoragePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${survivor.storagePath}'),
          isTrue,
        );
        expect(
          await WebFileStore.exists('tts_audio/${survivor.textStoragePath}'),
          isTrue,
        );
      },
    );

    testWidgets(
      'failed audio delete rollback survives a concurrent image save',
      (WidgetTester t) async {
        final target = audioRecord(
          'audio_concurrent_image_save_delete_target',
          'hash_concurrent_image_save_delete_target',
        );
        final image = ImageRecord(
          id: 'image_concurrent_audio_delete_save',
          name: 'concurrent image',
          hash: 'hash_concurrent_audio_delete_image',
          format: 'png',
          createdAt: DateTime.utc(2024),
          size: 1,
        );
        await addRecordWithFiles(target);
        await ManifestDatabase.getAllAudioRecords();
        await FileManifest.loadRecords();
        await ManifestDatabase.getAllImageRecords();
        expect(await persistedAudioIds(), equals([target.id]));
        expect(await persistedImageIds(), isEmpty);

        final deleteWriteStarted = Completer<void>();
        final imageWriteStarted = Completer<void>();
        final releaseDeleteWrite = Completer<void>();
        final failure =
            StateError('injected audio deletion persistence failure');
        var saveCount = 0;
        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          saveCount++;
          if (saveCount == 1) {
            deleteWriteStarted.complete();
            await releaseDeleteWrite.future;
            throw failure;
          }
          if (saveCount == 2) imageWriteStarted.complete();
        };

        final deleteFuture = FileManifest.deleteRecord(target.id);
        await deleteWriteStarted.future;
        final imageFuture = ManifestDatabase.insertImageRecord(image.toMap());
        await t.pump();
        final imageWroteBeforeDeleteFailed = imageWriteStarted.isCompleted;
        releaseDeleteWrite.complete();

        await expectLater(deleteFuture, throwsA(same(failure)));
        await imageFuture;
        ManifestDatabase.beforeWebDataSaveForTesting = null;

        expect(
          imageWroteBeforeDeleteFailed,
          isFalse,
          reason: 'a JSON save must wait for the audio rollback to finish',
        );
        expect(await persistedAudioIds(), equals([target.id]));
        expect(await persistedImageIds(), equals([image.id]));
        expect(
          (await ManifestDatabase.getAllAudioRecords()).single['id'],
          target.id,
        );
        expect(
          (await ManifestDatabase.getAllImageRecords()).single['id'],
          image.id,
        );
        expect(
          (await FileManifest.loadRecords()).map((record) => record.id),
          equals([target.id]),
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isTrue,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.textStoragePath}'),
          isTrue,
        );

        await FileManifest.deleteRecord(target.id);

        expect(await persistedAudioIds(), isEmpty);
        expect(await persistedImageIds(), equals([image.id]));
        expect(await ManifestDatabase.getAllAudioRecords(), isEmpty);
        expect(
          (await ManifestDatabase.getAllImageRecords()).single['id'],
          image.id,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.storagePath}'),
          isFalse,
        );
        expect(
          await WebFileStore.exists('tts_audio/${target.textStoragePath}'),
          isFalse,
        );
      },
    );
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
    Future<void> expectWebFolderSaveFailureCanRetry(
      String path,
      Future<void> Function(String) addFolder,
    ) async {
      await FileManifest.loadRecords();
      await FileManifest.getAllFolders();
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          isNot(contains(path)));

      final failure = StateError('injected Web manifest save failure');
      var failureInjected = false;
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        failureInjected = true;
        ManifestDatabase.beforeWebDataSaveForTesting = null;
        throw failure;
      };

      await expectLater(addFolder(path), throwsA(same(failure)));
      expect(failureInjected, isTrue);
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          isNot(contains(path)),
          reason: 'a failed Web save must roll back the in-memory folder path');

      await addFolder(path);

      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          contains(path),
          reason: 'retry must persist the folder after the Web save fails');
    }

    Future<void> expectFailedFolderInsertCanRetry(
      String path,
      Future<void> Function(String) addFolder,
    ) async {
      final failure = StateError('injected folder persistence failure');
      var shouldFail = true;
      ManifestDatabase.beforeFolderInsertForTesting = (insertedPath) {
        if (shouldFail && insertedPath == path) {
          shouldFail = false;
          throw failure;
        }
      };

      await expectLater(addFolder(path), throwsA(same(failure)));
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          isNot(contains(path)),
          reason: 'the injected failure must leave the folder unpersisted');

      await addFolder(path);

      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          contains(path),
          reason: 'retry must persist the folder after the first insert fails');
    }

    testWidgets('addFolder retries after folder persistence failure',
        (WidgetTester t) async {
      await expectFailedFolderInsertCanRetry(
        'audio-folder-retry',
        FileManifest.addFolder,
      );
    });

    testWidgets('addFolderPath retries after folder persistence failure',
        (WidgetTester t) async {
      await expectFailedFolderInsertCanRetry(
        'audio-path-retry',
        FileManifest.addFolderPath,
      );
    });

    testWidgets('addFolder retries after Web manifest save failure',
        (WidgetTester t) async {
      await expectWebFolderSaveFailureCanRetry(
        'audio-web-folder-save-retry',
        FileManifest.addFolder,
      );
    });

    testWidgets('addFolderPath retries after Web manifest save failure',
        (WidgetTester t) async {
      await expectWebFolderSaveFailureCanRetry(
        'audio-web-path-save-retry',
        FileManifest.addFolderPath,
      );
    });

    testWidgets(
        'forced refresh keeps a record registered after its record snapshot',
        (WidgetTester t) async {
      final operations = ManifestOperations<AudioRecord>(
        manifestKey: 'test_audio_manifest',
        storageDirName: 'tts_audio',
        fromMap: AudioRecord.fromMap,
        tableName: ManifestTables.audioRecords,
        toMap: (record) => record.toMap(),
      );
      await operations.loadRecords();

      final recordSnapshotReady = Completer<void>();
      final releaseFolderRead = Completer<void>();
      operations.beforeFolderLoadForTesting = () async {
        recordSnapshotReady.complete();
        await releaseFolderRead.future;
      };

      final refresh = operations.loadRecords(forceRefresh: true);
      await recordSnapshotReady.future;

      final record = AudioRecord(
        id: 'audio_registered_during_refresh',
        name: 'registered',
        hash: 'hash_registered_during_refresh',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'refresh/child',
      );
      await operations.addRecord(record);
      releaseFolderRead.complete();

      expect((await refresh).map((item) => item.id), contains(record.id),
          reason:
              'a refresh based on an older record snapshot must not overwrite a successful registration');
      expect((await operations.loadRecords()).map((item) => item.id),
          contains(record.id));
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          containsAll(['refresh', 'refresh/child']));
    });

    testWidgets(
        'failed JSON registration preserves folders used by a concurrent registration',
        (WidgetTester t) async {
      final firstWriteStarted = Completer<void>();
      final secondRegistrationStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      final failure = StateError('injected first registration failure');
      var registrationCount = 0;
      var writeCount = 0;
      ManifestDatabase.beforeJsonRecordRegistrationForTesting = () {
        registrationCount++;
        if (registrationCount == 2) secondRegistrationStarted.complete();
      };
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        writeCount++;
        if (writeCount == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
          throw failure;
        }
      };

      final firstRecord = AudioRecord(
        id: 'audio_concurrent_failed_registration',
        name: 'first',
        hash: 'hash_concurrent_failed_registration',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'concurrent/shared/child',
      );
      final secondRecord = AudioRecord(
        id: 'audio_concurrent_successful_registration',
        name: 'second',
        hash: 'hash_concurrent_successful_registration',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'concurrent/shared/child',
      );
      const folderPaths = [
        'concurrent',
        'concurrent/shared',
        'concurrent/shared/child',
      ];
      Future<void> insertRecord(AudioRecord record) =>
          ManifestDatabase.insertRecordWithFolders(
            recordTable: ManifestTables.audioRecords,
            record: record.toMap(),
            folderPaths: folderPaths,
          );

      final firstInsert = insertRecord(firstRecord);
      await firstWriteStarted.future;
      final secondInsert = insertRecord(secondRecord);
      await secondRegistrationStarted.future;
      await t.pump();
      releaseFirstWrite.complete();

      await expectLater(firstInsert, throwsA(same(failure)));
      await secondInsert;

      expect(
          (await ManifestDatabase.getAllAudioRecords()).map((row) => row['id']),
          equals([secondRecord.id]));
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          containsAll(folderPaths),
          reason:
              'rollback must not remove paths required by a concurrent successful registration');
    });

    testWidgets(
        'failed JSON registration is not cached by a concurrent forced refresh',
        (WidgetTester t) async {
      final firstWriteStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      final failure = StateError('injected registration failure');
      var writeCount = 0;
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        writeCount++;
        if (writeCount == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
          throw failure;
        }
      };
      final record = AudioRecord(
        id: 'audio_uncommitted_refresh',
        name: 'pending',
        hash: 'hash_uncommitted_refresh',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'pending/child',
      );

      final registration = FileManifest.addRecord(record);
      await firstWriteStarted.future;
      final refreshed = FileManifest.loadRecordsStrict();
      await t.pump();
      releaseFirstWrite.complete();

      await expectLater(registration, throwsA(same(failure)));
      expect(await refreshed, isEmpty,
          reason: 'a forced refresh must not expose an uncommitted row');
      expect(await FileManifest.loadRecords(), isEmpty,
          reason: 'rollback must not leave the failed row in the record cache');
    });

    testWidgets(
        'failed JSON registration preserves a concurrent folder registration',
        (WidgetTester t) async {
      final firstWriteStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      final failure = StateError('injected registration failure');
      var writeCount = 0;
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        writeCount++;
        if (writeCount == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
          throw failure;
        }
      };
      final record = AudioRecord(
        id: 'audio_concurrent_folder_registration',
        name: 'pending',
        hash: 'hash_concurrent_folder_registration',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'concurrent-folder/shared',
      );

      final registration = FileManifest.addRecord(record);
      await firstWriteStarted.future;
      final folderRegistration = FileManifest.addFolder(record.folder);
      await t.pump();
      releaseFirstWrite.complete();

      await expectLater(registration, throwsA(same(failure)));
      await folderRegistration;
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          equals([record.folder]),
          reason:
              'rollback must not remove a folder registered by a concurrent successful operation');
    });

    testWidgets(
        'text addRecord rolls back record and folders when canceled during persistence',
        (WidgetTester t) async {
      var cancelled = false;
      final cancellation = StateError('cancelled during manifest persistence');
      ManifestDatabase.beforeWebDataSaveForTesting = () async {
        cancelled = true;
      };

      await expectLater(
        TextManifest.addRecord(
          TextRecord(
            id: 'text_cancel_folder_save',
            name: 'cancelled',
            hash: 'hash_cancel_folder_save',
            createdAt: DateTime(2024),
            size: 4,
            folder: 'cancelled/child',
          ),
          beforeCommit: () {
            if (cancelled) throw cancellation;
          },
        ),
        throwsA(same(cancellation)),
      );

      expect(await ManifestDatabase.getAllTextRecords(), isEmpty);
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.textRecords),
          isEmpty);
      expect(await TextManifest.loadRecords(), isEmpty);
    });

    testWidgets(
        'addRecord rolls back folder persistence failure and retry completes it',
        (WidgetTester t) async {
      final existingRecord = AudioRecord(
        id: 'audio_existing_folder_retry',
        name: 'existing',
        hash: 'hash_existing_folder_retry',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
      );
      await FileManifest.addRecord(existingRecord);
      await FileManifest.addFolder('existing');
      final record = AudioRecord(
        id: 'audio_folder_retry',
        name: 'tts',
        hash: 'hash_folder_retry',
        format: 'wav',
        createdAt: DateTime(2024),
        size: 4,
        folder: 'existing/child/grandchild',
      );
      final failure = StateError('injected folder persistence failure');
      var shouldFail = true;
      ManifestDatabase.beforeFolderInsertForTesting = (path) {
        if (shouldFail && path == 'existing/child') {
          shouldFail = false;
          throw failure;
        }
      };

      await expectLater(FileManifest.addRecord(record), throwsA(same(failure)));

      expect((await FileManifest.loadRecords()).map((row) => row.id),
          equals([existingRecord.id]),
          reason:
              'a failed add must not remain visible through the record cache');
      final failedRows = await ManifestDatabase.getAllAudioRecords();
      expect(failedRows.any((row) => row['id'] == record.id), isFalse,
          reason: 'a failed add must not remain persisted as a record');
      expect(failedRows.map((row) => row['id']), equals([existingRecord.id]),
          reason: 'a failed add must preserve pre-existing records');
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          equals(['existing']),
          reason: 'a failed add must retain pre-existing folders only');

      await FileManifest.addRecord(record);

      expect(
          (await ManifestDatabase.getAllAudioRecords())
              .any((row) => row['id'] == record.id),
          isTrue,
          reason: 'retry must persist the audio record');
      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          containsAll([
            'existing',
            'existing/child',
            'existing/child/grandchild',
          ]),
          reason: 'retry must persist the complete folder path');
    });

    testWidgets('ordinary audio folder registration persists the folder',
        (WidgetTester t) async {
      await FileManifest.addFolder('ordinary/audio');

      expect(
          await ManifestDatabase.getAllFolders(
              recordTable: ManifestTables.audioRecords),
          contains('ordinary/audio'));
    });

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
