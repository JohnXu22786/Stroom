// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeWebDataReadForTesting = null;
    ManifestDatabase.beforeWebDataSaveForTesting = null;
  });

  tearDown(() {
    ManifestDatabase.beforeWebDataReadForTesting = null;
    ManifestDatabase.beforeWebDataSaveForTesting = null;
  });

  test(
      'concurrent cold JSON updates preserve independent image, video, and text changes',
      () async {
    await ManifestDatabase.insertImageRecord({'id': 'image-race'});
    await ManifestDatabase.insertVideoRecord({'id': 'video-race'});
    await ManifestDatabase.insertTextRecord({'id': 'text-race'});
    ManifestDatabase.invalidateWebDataCacheForTesting();

    var readCount = 0;
    final releaseFirstRead = Completer<void>();
    ManifestDatabase.beforeWebDataReadForTesting = () {
      readCount++;
      if (readCount == 1) scheduleMicrotask(releaseFirstRead.complete);
      return releaseFirstRead.future;
    };

    await Future.wait([
      ManifestDatabase.updateImageRecord('image-race', {'updated': true}),
      ManifestDatabase.updateVideoRecord('video-race', {'updated': true}),
      ManifestDatabase.updateTextRecord('text-race', {'updated': true}),
    ]);

    expect(
      readCount,
      1,
      reason: 'cold JSON updates must share one locked read',
    );
    expect(
      (await ManifestDatabase.getAllImageRecords()).single['updated'],
      isTrue,
    );
    expect(
      (await ManifestDatabase.getAllVideoRecords()).single['updated'],
      isTrue,
    );
    expect(
      (await ManifestDatabase.getAllTextRecords()).single['updated'],
      isTrue,
    );
  });

  test(
    'concurrent cold JSON inserts preserve image, video, and text records',
    () async {
      var readCount = 0;
      ManifestDatabase.beforeWebDataReadForTesting = () async {
        readCount++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      };

      await Future.wait([
        ManifestDatabase.insertImageRecord({'id': 'image-race'}),
        ManifestDatabase.insertVideoRecord({'id': 'video-race'}),
        ManifestDatabase.insertTextRecord({'id': 'text-race'}),
      ]);

      expect(
        (await ManifestDatabase.getAllImageRecords()).map((row) => row['id']),
        ['image-race'],
      );
      expect(
        (await ManifestDatabase.getAllVideoRecords()).map((row) => row['id']),
        ['video-race'],
      );
      expect(
        (await ManifestDatabase.getAllTextRecords()).map((row) => row['id']),
        ['text-race'],
      );
      expect(
        readCount,
        1,
        reason: 'the cold manifest should be loaded once while mutations queue',
      );
    },
  );

  test(
    'concurrent cold JSON deletes serialize image, video, and text changes',
    () async {
      await ManifestDatabase.insertImageRecord({'id': 'image-delete'});
      await ManifestDatabase.insertImageRecord({'id': 'image-batch-delete'});
      await ManifestDatabase.insertVideoRecord({'id': 'video-delete'});
      await ManifestDatabase.insertVideoRecord({'id': 'video-batch-delete'});
      await ManifestDatabase.insertTextRecord({'id': 'text-delete'});
      await ManifestDatabase.insertTextRecord({'id': 'text-batch-delete'});
      ManifestDatabase.invalidateWebDataCacheForTesting();

      var readCount = 0;
      ManifestDatabase.beforeWebDataReadForTesting = () {
        readCount++;
        return Future<void>.value();
      };

      await Future.wait([
        ManifestDatabase.deleteImageRecord('image-delete'),
        ManifestDatabase.deleteImageRecords(['image-batch-delete']),
        ManifestDatabase.deleteVideoRecord('video-delete'),
        ManifestDatabase.deleteVideoRecords(['video-batch-delete']),
        ManifestDatabase.deleteTextRecord('text-delete'),
        ManifestDatabase.deleteTextRecords(['text-batch-delete']),
      ]);

      expect(readCount, 1, reason: 'JSON deletes must share the cold read');
      expect(await ManifestDatabase.getAllImageRecords(), isEmpty);
      expect(await ManifestDatabase.getAllVideoRecords(), isEmpty);
      expect(await ManifestDatabase.getAllTextRecords(), isEmpty);
    },
  );

  test(
    'concurrent cold JSON clears serialize image, video, and text changes',
    () async {
      await ManifestDatabase.insertImageRecord({'id': 'image-clear'});
      await ManifestDatabase.insertVideoRecord({'id': 'video-clear'});
      await ManifestDatabase.insertTextRecord({'id': 'text-clear'});
      ManifestDatabase.invalidateWebDataCacheForTesting();

      var readCount = 0;
      ManifestDatabase.beforeWebDataReadForTesting = () {
        readCount++;
        return Future<void>.value();
      };

      await Future.wait([
        ManifestDatabase.clearRecords(ManifestTables.imageRecords),
        ManifestDatabase.clearRecords(ManifestTables.videoRecords),
        ManifestDatabase.clearRecords(ManifestTables.textRecords),
      ]);

      expect(readCount, 1, reason: 'JSON clears must share the cold read');
      expect(await ManifestDatabase.getAllImageRecords(), isEmpty);
      expect(await ManifestDatabase.getAllVideoRecords(), isEmpty);
      expect(await ManifestDatabase.getAllTextRecords(), isEmpty);
    },
  );

  test(
    'concurrent cold JSON folder mutations serialize per-type changes',
    () async {
      await ManifestDatabase.insertFolder(
        'image-delete',
        recordTable: ManifestTables.imageRecords,
      );
      await ManifestDatabase.insertFolder(
        'video-clear',
        recordTable: ManifestTables.videoRecords,
      );
      await ManifestDatabase.insertFolder(
        'text-keep',
        recordTable: ManifestTables.textRecords,
      );
      ManifestDatabase.invalidateWebDataCacheForTesting();

      var readCount = 0;
      ManifestDatabase.beforeWebDataReadForTesting = () {
        readCount++;
        return Future<void>.value();
      };

      await Future.wait([
        ManifestDatabase.deleteFolder(
          'image-delete',
          recordTable: ManifestTables.imageRecords,
        ),
        ManifestDatabase.clearFolders(recordTable: ManifestTables.videoRecords),
        ManifestDatabase.insertFolder(
          'audio-keep',
          recordTable: ManifestTables.audioRecords,
        ),
      ]);

      expect(
        readCount,
        1,
        reason: 'JSON folder mutations must share the cold read',
      );
      expect(
        await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.imageRecords,
        ),
        isEmpty,
      );
      expect(
        await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.videoRecords,
        ),
        isEmpty,
      );
      expect(
        await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.textRecords,
        ),
        ['text-keep'],
      );
      expect(
        await ManifestDatabase.getAllFolders(
          recordTable: ManifestTables.audioRecords,
        ),
        ['audio-keep'],
      );
    },
  );
}
