import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/providers/text_provider.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/providers/video_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/folder_membership_lock.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

Future<void> _waitForSignalOrOperationFailure(
  Completer<void> signal,
  Future<void> operation,
  String description,
) {
  final operationFinished = operation.then<void>((_) {
    if (!signal.isCompleted) {
      throw StateError('$description completed before reaching its barrier');
    }
  });
  return Future.any([signal.future, operationFinished]);
}

Future<void> _drainOperations(
  Iterable<Future<void>> operations, {
  Future<void>? second,
}) async {
  final pending = operations.toList();
  if (second != null) pending.add(second);
  try {
    await Future.wait(pending);
  } catch (_) {
    // The originating assertion or barrier wait reports the test failure.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeFolderInsertForTesting = null;
    FolderMembershipLock.afterCopySnapshotForTesting = null;
    FileManifest.invalidateCache();
    ImageManifest.invalidateCache();
    TextManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  testWidgets(
    'folder copies protect source content from concurrent deletion for all providers',
    (WidgetTester t) async {
      final now = DateTime.now();
      final operations = <({
        String provider,
        Future<void> Function() save,
        Future<void> Function() copy,
        Future<void> Function() delete,
        Future<List<dynamic>> Function() load,
        Future<Uint8List?> Function(String) read,
        String fileName,
        String destination,
      })>[
        (
          provider: 'text',
          fileName: 'race_text.txt',
          destination: 'target/race_text',
          save: () async {
            await TextManifest.writeFile(
              'race_text.txt',
              Uint8List.fromList([1]),
            );
            await TextManifest.addRecord(
              TextRecord(
                id: 'race_text',
                name: 'text',
                hash: 'race_text',
                createdAt: now,
                size: 1,
                folder: 'race_text',
              ),
            );
          },
          copy: () => TextRecordsNotifier().copyFolder('race_text', 'target'),
          delete: () => TextManifest.removeFolder('race_text'),
          load: TextManifest.loadRecords,
          read: TextManifest.readFile,
        ),
        (
          provider: 'image',
          fileName: 'race_image.png',
          destination: 'target/race_image',
          save: () async {
            await ImageManifest.writeFile(
              'race_image.png',
              Uint8List.fromList([1]),
            );
            await ImageManifest.addRecord(
              ImageRecord(
                id: 'race_image',
                name: 'image',
                hash: 'race_image',
                format: 'png',
                createdAt: now,
                size: 1,
                folder: 'race_image',
              ),
            );
          },
          copy: () => ImageRecordsNotifier().copyFolder('race_image', 'target'),
          delete: () => ImageManifest.removeFolder('race_image'),
          load: ImageManifest.loadRecords,
          read: ImageManifest.readFile,
        ),
        (
          provider: 'video',
          fileName: 'race_video.mp4',
          destination: 'target/race_video/child',
          save: () async {
            await VideoManifest.writeFile(
              'race_video.mp4',
              Uint8List.fromList([1]),
            );
            await VideoManifest.addRecord(
              VideoRecord(
                id: 'race_video',
                name: 'video',
                hash: 'race_video',
                format: 'mp4',
                createdAt: now,
                size: 1,
                folder: 'race_video/child',
              ),
            );
          },
          copy: () => VideoRecordsNotifier().copyFolder('race_video', 'target'),
          delete: () => VideoManifest.removeFolder('race_video/child'),
          load: VideoManifest.loadRecords,
          read: VideoManifest.readFile,
        ),
        (
          provider: 'audio',
          fileName: 'race_audio.wav',
          destination: 'target/race_audio',
          save: () async {
            await FileManifest.writeFile(
              'race_audio.wav',
              Uint8List.fromList([1]),
            );
            await FileManifest.addRecord(
              AudioRecord(
                id: 'race_audio',
                name: 'audio',
                hash: 'race_audio',
                format: 'wav',
                createdAt: now,
                size: 1,
                folder: 'race_audio',
              ),
            );
          },
          copy: () => AudioRecordsNotifier().copyFolder('race_audio', 'target'),
          delete: () => FileManifest.removeFolder('race_audio'),
          load: FileManifest.loadRecords,
          read: FileManifest.readFile,
        ),
      ];
      for (final item in operations) {
        await item.save();
        final snapshotted = Completer<void>();
        final resume = Completer<void>();
        FolderMembershipLock.afterCopySnapshotForTesting = () async {
          FolderMembershipLock.afterCopySnapshotForTesting = null;
          snapshotted.complete();
          await resume.future;
        };
        final copy = item.copy();
        Future<void>? deletion;
        try {
          await _waitForSignalOrOperationFailure(
            snapshotted,
            copy,
            '${item.provider} copy',
          );
          var deleted = false;
          deletion = item.delete().then((_) => deleted = true);
          await t.pump();
          expect(
            deleted,
            isFalse,
            reason: '${item.provider} delete should wait for copy',
          );
          resume.complete();
          await Future.wait([copy, deletion]);
          expect(
            (await item.load()).where(
              (record) => record.folder == item.destination,
            ),
            hasLength(1),
          );
          expect(
            await item.read(item.fileName),
            isNotNull,
            reason: item.provider,
          );
        } finally {
          if (!resume.isCompleted) resume.complete();
          await _drainOperations([
            copy,
          ], second: deletion);
        }
      }
    },
  );

  testWidgets(
      'direct record deletion waits for a copy holding its content reference',
      (WidgetTester t) async {
    await ImageManifest.writeFile(
        'hash_delete_race.png', Uint8List.fromList([1]));
    await ImageManifest.addRecord(ImageRecord(
      id: 'delete_race',
      name: 'image',
      hash: 'hash_delete_race',
      format: 'png',
      createdAt: DateTime.now(),
      size: 1,
      folder: 'delete_race',
    ));

    final snapshotted = Completer<void>();
    final resume = Completer<void>();
    FolderMembershipLock.afterCopySnapshotForTesting = () async {
      FolderMembershipLock.afterCopySnapshotForTesting = null;
      snapshotted.complete();
      await resume.future;
    };
    final copy = ImageRecordsNotifier().copyFolder('delete_race', 'target');
    Future<void>? deletion;
    try {
      await _waitForSignalOrOperationFailure(
        snapshotted,
        copy,
        'image copy',
      );
      var deleted = false;
      deletion = ImageManifest.deleteRecord('delete_race').then((_) {
        deleted = true;
      });
      await t.pump();
      expect(deleted, isFalse);
      resume.complete();
      await Future.wait([copy, deletion]);
      expect(
        (await ImageManifest.loadRecords())
            .where((record) => record.folder == 'target/delete_race'),
        hasLength(1),
      );
      expect(await ImageManifest.readFile('hash_delete_race.png'), isNotNull);
    } finally {
      if (!resume.isCompleted) resume.complete();
      await _drainOperations([copy], second: deletion);
    }
  });

  testWidgets('adding an empty descendant waits for a stable folder copy', (
    WidgetTester t,
  ) async {
    await ImageManifest.addFolder('copy_empty_source/known');
    final snapshotted = Completer<void>();
    final resume = Completer<void>();
    FolderMembershipLock.afterCopySnapshotForTesting = () async {
      FolderMembershipLock.afterCopySnapshotForTesting = null;
      snapshotted.complete();
      await resume.future;
    };

    final copy = ImageRecordsNotifier().copyFolder(
      'copy_empty_source',
      'target',
    );
    Future<void>? add;
    try {
      await _waitForSignalOrOperationFailure(
        snapshotted,
        copy,
        'image copy',
      );
      var added = false;
      add = ImageManifest.addFolder('copy_empty_source/late').then((_) {
        added = true;
      });
      await t.pump();
      expect(added, isFalse);

      resume.complete();
      await Future.wait([copy, add]);
      final folders = await ImageManifest.getAllFolders();
      expect(folders, contains('target/copy_empty_source/known'));
      expect(folders, contains('copy_empty_source/late'));
      expect(folders, isNot(contains('target/copy_empty_source/late')));
    } finally {
      if (!resume.isCompleted) resume.complete();
      await _drainOperations([copy], second: add);
    }
  });

  testWidgets('new source records wait while each provider publishes a copy', (
    WidgetTester t,
  ) async {
    final now = DateTime.now();
    final cases = <({
      String provider,
      Future<void> Function() saveInitial,
      Future<void> Function() copy,
      Future<void> Function() addSecond,
      Future<List<dynamic>> Function() load,
      Future<Uint8List?> Function(String) read,
      String destination,
      String initialFile,
      String secondFile,
      String initialId,
      String secondId,
    })>[
      (
        provider: 'text',
        destination: 'target/copy_add_text',
        initialFile: 'copy_add_text.txt',
        secondFile: 'copy_add_text_second.txt',
        initialId: 'copy_add_text',
        secondId: 'copy_add_text_second',
        saveInitial: () async {
          await TextManifest.writeFile(
            'copy_add_text.txt',
            Uint8List.fromList([1]),
          );
          await TextManifest.addRecord(
            TextRecord(
              id: 'copy_add_text',
              name: 'text',
              hash: 'copy_add_text',
              createdAt: now,
              size: 1,
              folder: 'copy_add_text',
            ),
          );
        },
        copy: () => TextRecordsNotifier().copyFolder('copy_add_text', 'target'),
        addSecond: () async {
          await TextManifest.writeFile(
            'copy_add_text_second.txt',
            Uint8List.fromList([2]),
          );
          await TextManifest.addRecord(
            TextRecord(
              id: 'copy_add_text_second',
              name: 'second',
              hash: 'copy_add_text_second',
              createdAt: now,
              size: 1,
              folder: 'copy_add_text',
            ),
          );
        },
        load: TextManifest.loadRecords,
        read: TextManifest.readFile,
      ),
      (
        provider: 'image',
        destination: 'target/copy_add_image',
        initialFile: 'copy_add_image.png',
        secondFile: 'copy_add_image_second.png',
        initialId: 'copy_add_image',
        secondId: 'copy_add_image_second',
        saveInitial: () async {
          await ImageManifest.writeFile(
            'copy_add_image.png',
            Uint8List.fromList([1]),
          );
          await ImageManifest.addRecord(
            ImageRecord(
              id: 'copy_add_image',
              name: 'image',
              hash: 'copy_add_image',
              format: 'png',
              createdAt: now,
              size: 1,
              folder: 'copy_add_image',
            ),
          );
        },
        copy: () =>
            ImageRecordsNotifier().copyFolder('copy_add_image', 'target'),
        addSecond: () async {
          await ImageManifest.writeFile(
            'copy_add_image_second.png',
            Uint8List.fromList([2]),
          );
          await ImageManifest.addRecord(
            ImageRecord(
              id: 'copy_add_image_second',
              name: 'second',
              hash: 'copy_add_image_second',
              format: 'png',
              createdAt: now,
              size: 1,
              folder: 'copy_add_image',
            ),
          );
        },
        load: ImageManifest.loadRecords,
        read: ImageManifest.readFile,
      ),
      (
        provider: 'video',
        destination: 'target/copy_add_video',
        initialFile: 'copy_add_video.mp4',
        secondFile: 'copy_add_video_second.mp4',
        initialId: 'copy_add_video',
        secondId: 'copy_add_video_second',
        saveInitial: () async {
          await VideoManifest.writeFile(
            'copy_add_video.mp4',
            Uint8List.fromList([1]),
          );
          await VideoManifest.addRecord(
            VideoRecord(
              id: 'copy_add_video',
              name: 'video',
              hash: 'copy_add_video',
              format: 'mp4',
              createdAt: now,
              size: 1,
              folder: 'copy_add_video',
            ),
          );
        },
        copy: () =>
            VideoRecordsNotifier().copyFolder('copy_add_video', 'target'),
        addSecond: () async {
          await VideoManifest.writeFile(
            'copy_add_video_second.mp4',
            Uint8List.fromList([2]),
          );
          await VideoManifest.addRecord(
            VideoRecord(
              id: 'copy_add_video_second',
              name: 'second',
              hash: 'copy_add_video_second',
              format: 'mp4',
              createdAt: now,
              size: 1,
              folder: 'copy_add_video',
            ),
          );
        },
        load: VideoManifest.loadRecords,
        read: VideoManifest.readFile,
      ),
      (
        provider: 'audio',
        destination: 'target/copy_add_audio',
        initialFile: 'copy_add_audio.wav',
        secondFile: 'copy_add_audio_second.wav',
        initialId: 'copy_add_audio',
        secondId: 'copy_add_audio_second',
        saveInitial: () async {
          await FileManifest.writeFile(
            'copy_add_audio.wav',
            Uint8List.fromList([1]),
          );
          await FileManifest.addRecord(
            AudioRecord(
              id: 'copy_add_audio',
              name: 'audio',
              hash: 'copy_add_audio',
              format: 'wav',
              createdAt: now,
              size: 1,
              folder: 'copy_add_audio',
            ),
          );
        },
        copy: () =>
            AudioRecordsNotifier().copyFolder('copy_add_audio', 'target'),
        addSecond: () async {
          await FileManifest.writeFile(
            'copy_add_audio_second.wav',
            Uint8List.fromList([2]),
          );
          await FileManifest.addRecord(
            AudioRecord(
              id: 'copy_add_audio_second',
              name: 'second',
              hash: 'copy_add_audio_second',
              format: 'wav',
              createdAt: now,
              size: 1,
              folder: 'copy_add_audio',
            ),
          );
        },
        load: FileManifest.loadRecords,
        read: FileManifest.readFile,
      ),
    ];
    for (final item in cases) {
      await item.saveInitial();
      final snapshotted = Completer<void>();
      final resume = Completer<void>();
      FolderMembershipLock.afterCopySnapshotForTesting = () async {
        FolderMembershipLock.afterCopySnapshotForTesting = null;
        snapshotted.complete();
        await resume.future;
      };
      final copy = item.copy();
      Future<void>? add;
      try {
        await _waitForSignalOrOperationFailure(
          snapshotted,
          copy,
          '${item.provider} copy',
        );
        var added = false;
        add = item.addSecond().then((_) => added = true);
        await t.pump();
        expect(added, isFalse, reason: item.provider);
        resume.complete();
        await Future.wait([copy, add]);
        final records = await item.load();
        final copied = records.where(
          (record) => record.folder == item.destination,
        );
        expect(copied.map((record) => record.id), [item.initialId]);
        expect(records.any((record) => record.id == item.secondId), isTrue);
        expect(await item.read(item.initialFile), isNotNull);
        expect(await item.read(item.secondFile), isNotNull);
      } finally {
        if (!resume.isCompleted) resume.complete();
        await _drainOperations([copy], second: add);
      }
    }
  });

  testWidgets('one copy cannot add a descendant during another copy snapshot', (
    WidgetTester t,
  ) async {
    await ImageManifest.addFolder('copy_donor/empty');
    await ImageManifest.addFolder('copy_parent/known');
    final snapshotted = Completer<void>();
    final resume = Completer<void>();
    FolderMembershipLock.afterCopySnapshotForTesting = () async {
      FolderMembershipLock.afterCopySnapshotForTesting = null;
      snapshotted.complete();
      await resume.future;
    };

    final parentCopy = ImageRecordsNotifier().copyFolder(
      'copy_parent',
      'target',
    );
    Future<void>? donorCopy;
    try {
      await _waitForSignalOrOperationFailure(
        snapshotted,
        parentCopy,
        'parent image copy',
      );
      var donorCopyFinished = false;
      donorCopy = ImageRecordsNotifier()
          .copyFolder('copy_donor', 'copy_parent')
          .then((_) => donorCopyFinished = true);
      await t.pump();
      expect(donorCopyFinished, isFalse);

      resume.complete();
      await Future.wait([parentCopy, donorCopy]);
      final folders = await ImageManifest.getAllFolders();
      expect(folders, contains('copy_parent/copy_donor'));
      expect(folders, contains('target/copy_parent/known'));
      expect(folders, isNot(contains('target/copy_parent/copy_donor')));
    } finally {
      if (!resume.isCompleted) resume.complete();
      await _drainOperations([parentCopy], second: donorCopy);
    }
  });

  testWidgets(
    'concurrent folder copies to the same destination publish one copy for all types',
    (WidgetTester t) async {
      final now = DateTime.now();
      await TextManifest.addRecord(TextRecord(
          id: 'copy_race_text',
          name: 'doc',
          hash: 'copy_race_text_hash',
          createdAt: now,
          size: 1,
          folder: 'copy_race_text'));
      await TextManifest.addRecord(TextRecord(
          id: 'copy_race_text_child',
          name: 'child',
          hash: 'copy_race_text_child_hash',
          createdAt: now,
          size: 1,
          folder: 'copy_race_text/sub'));
      await ImageManifest.addRecord(ImageRecord(
          id: 'copy_race_image',
          name: 'img',
          hash: 'copy_race_image_hash',
          format: 'png',
          createdAt: now,
          size: 1,
          folder: 'copy_race_image'));
      await ImageManifest.addRecord(ImageRecord(
          id: 'copy_race_image_child',
          name: 'child',
          hash: 'copy_race_image_child_hash',
          format: 'png',
          createdAt: now,
          size: 1,
          folder: 'copy_race_image/sub'));
      await VideoManifest.addRecord(VideoRecord(
          id: 'copy_race_video',
          name: 'vid',
          hash: 'copy_race_video_hash',
          format: 'mp4',
          createdAt: now,
          size: 1,
          folder: 'copy_race_video'));
      await VideoManifest.addRecord(VideoRecord(
          id: 'copy_race_video_child',
          name: 'child',
          hash: 'copy_race_video_child_hash',
          format: 'mp4',
          createdAt: now,
          size: 1,
          folder: 'copy_race_video/sub'));
      await FileManifest.addRecord(AudioRecord(
          id: 'copy_race_audio',
          name: 'aud',
          hash: 'copy_race_audio_hash',
          format: 'wav',
          createdAt: now,
          size: 1,
          folder: 'copy_race_audio'));
      await FileManifest.addRecord(AudioRecord(
          id: 'copy_race_audio_child',
          name: 'child',
          hash: 'copy_race_audio_child_hash',
          format: 'wav',
          createdAt: now,
          size: 1,
          folder: 'copy_race_audio/sub'));

      final operations = <Future<void> Function()>[
        () => TextRecordsNotifier().copyFolder('copy_race_text', 'target'),
        () => ImageRecordsNotifier().copyFolder('copy_race_image', 'target'),
        () => VideoRecordsNotifier().copyFolder('copy_race_video', 'target'),
        () => AudioRecordsNotifier().copyFolder('copy_race_audio', 'target'),
      ];
      final records = <Future<List<dynamic>> Function()>[
        TextManifest.loadRecords,
        ImageManifest.loadRecords,
        VideoManifest.loadRecords,
        FileManifest.loadRecords,
      ];
      final folders = <Future<Set<String>> Function()>[
        TextManifest.getAllFolders,
        ImageManifest.getAllFolders,
        VideoManifest.getAllFolders,
        FileManifest.getAllFolders,
      ];
      final names = [
        'copy_race_text',
        'copy_race_image',
        'copy_race_video',
        'copy_race_audio',
      ];

      for (var i = 0; i < operations.length; i++) {
        await Future.wait([operations[i](), operations[i]()]);

        final copiedRecords = (await records[i]())
            .where((record) => record.folder.startsWith('target/${names[i]}'));
        expect(copiedRecords, hasLength(2),
            reason: 'concurrent copies must publish records only once');
        final copiedFolders = (await folders[i]())
            .where((path) => path.startsWith('target/${names[i]}'))
            .toSet();
        expect(copiedFolders, {'target/${names[i]}', 'target/${names[i]}/sub'});
      }
    },
  );

  testWidgets(
      'folder rename rolls back partial manifest failures for all types',
      (WidgetTester t) async {
    final now = DateTime.now();
    await TextManifest.addRecord(TextRecord(
        id: 'rollback_text',
        name: 'doc',
        hash: 'rollback_text_hash',
        createdAt: now,
        size: 1,
        folder: 'old_text'));
    await TextManifest.addRecord(TextRecord(
        id: 'rollback_text_child',
        name: 'child',
        hash: 'rollback_text_child_hash',
        createdAt: now,
        size: 1,
        folder: 'old_text/sub'));
    await ImageManifest.addRecord(ImageRecord(
        id: 'rollback_image',
        name: 'img',
        hash: 'rollback_image_hash',
        format: 'png',
        createdAt: now,
        size: 1,
        folder: 'old_image'));
    await ImageManifest.addRecord(ImageRecord(
        id: 'rollback_image_child',
        name: 'child',
        hash: 'rollback_image_child_hash',
        format: 'png',
        createdAt: now,
        size: 1,
        folder: 'old_image/sub'));
    await VideoManifest.addRecord(VideoRecord(
        id: 'rollback_video',
        name: 'vid',
        hash: 'rollback_video_hash',
        format: 'mp4',
        createdAt: now,
        size: 1,
        folder: 'old_video'));
    await VideoManifest.addRecord(VideoRecord(
        id: 'rollback_video_child',
        name: 'child',
        hash: 'rollback_video_child_hash',
        format: 'mp4',
        createdAt: now,
        size: 1,
        folder: 'old_video/sub'));
    await FileManifest.addRecord(AudioRecord(
        id: 'rollback_audio',
        name: 'aud',
        hash: 'rollback_audio_hash',
        format: 'wav',
        createdAt: now,
        size: 1,
        folder: 'old_audio'));
    await FileManifest.addRecord(AudioRecord(
        id: 'rollback_audio_child',
        name: 'child',
        hash: 'rollback_audio_child_hash',
        format: 'wav',
        createdAt: now,
        size: 1,
        folder: 'old_audio/sub'));

    final operations = <Future<void> Function()>[
      () => TextRecordsNotifier().renameFolder('old_text', 'new_text'),
      () => ImageRecordsNotifier().renameFolder('old_image', 'new_image'),
      () => VideoRecordsNotifier().renameFolder('old_video', 'new_video'),
      () => AudioRecordsNotifier().renameFolder('old_audio', 'new_audio'),
    ];
    final records = <Future<List<String>> Function()>[
      () async =>
          (await TextManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await ImageManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await VideoManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await FileManifest.loadRecords()).map((r) => r.folder).toList(),
    ];
    final folderSets = <Future<Set<String>> Function()>[
      TextManifest.getAllFolders,
      ImageManifest.getAllFolders,
      VideoManifest.getAllFolders,
      FileManifest.getAllFolders,
    ];

    for (var i = 0; i < operations.length; i++) {
      var injected = false;
      ManifestDatabase.beforeFolderInsertForTesting = (path) {
        if (!injected && path.startsWith('new_') && path.endsWith('/sub')) {
          injected = true;
          throw StateError('injected folder persistence failure');
        }
      };
      await expectLater(operations[i](), throwsStateError);
      ManifestDatabase.beforeFolderInsertForTesting = null;
      expect(injected, isTrue);
      expect(
          (await records[i]()).toSet(),
          containsAll([
            'old_${['text', 'image', 'video', 'audio'][i]}',
            'old_${['text', 'image', 'video', 'audio'][i]}/sub'
          ]));
      expect((await folderSets[i]()).any((folder) => folder.startsWith('new_')),
          isFalse);
    }
  });

  testWidgets('folder move rolls back partial manifest failures for all types',
      (WidgetTester t) async {
    final now = DateTime.now();
    await TextManifest.addRecord(TextRecord(
        id: 'move_rollback_text',
        name: 'doc',
        hash: 'move_rollback_text_hash',
        createdAt: now,
        size: 1,
        folder: 'old_text'));
    await TextManifest.addRecord(TextRecord(
        id: 'move_rollback_text_child',
        name: 'child',
        hash: 'move_rollback_text_child_hash',
        createdAt: now,
        size: 1,
        folder: 'old_text/sub'));
    await ImageManifest.addRecord(ImageRecord(
        id: 'move_rollback_image',
        name: 'img',
        hash: 'move_rollback_image_hash',
        format: 'png',
        createdAt: now,
        size: 1,
        folder: 'old_image'));
    await ImageManifest.addRecord(ImageRecord(
        id: 'move_rollback_image_child',
        name: 'child',
        hash: 'move_rollback_image_child_hash',
        format: 'png',
        createdAt: now,
        size: 1,
        folder: 'old_image/sub'));
    await VideoManifest.addRecord(VideoRecord(
        id: 'move_rollback_video',
        name: 'vid',
        hash: 'move_rollback_video_hash',
        format: 'mp4',
        createdAt: now,
        size: 1,
        folder: 'old_video'));
    await VideoManifest.addRecord(VideoRecord(
        id: 'move_rollback_video_child',
        name: 'child',
        hash: 'move_rollback_video_child_hash',
        format: 'mp4',
        createdAt: now,
        size: 1,
        folder: 'old_video/sub'));
    await FileManifest.addRecord(AudioRecord(
        id: 'move_rollback_audio',
        name: 'aud',
        hash: 'move_rollback_audio_hash',
        format: 'wav',
        createdAt: now,
        size: 1,
        folder: 'old_audio'));
    await FileManifest.addRecord(AudioRecord(
        id: 'move_rollback_audio_child',
        name: 'child',
        hash: 'move_rollback_audio_child_hash',
        format: 'wav',
        createdAt: now,
        size: 1,
        folder: 'old_audio/sub'));

    final operations = <Future<void> Function()>[
      () => TextRecordsNotifier().moveFolder('old_text', 'new_text_parent'),
      () => ImageRecordsNotifier().moveFolder('old_image', 'new_image_parent'),
      () => VideoRecordsNotifier().moveFolder('old_video', 'new_video_parent'),
      () => AudioRecordsNotifier().moveFolder('old_audio', 'new_audio_parent'),
    ];
    final records = <Future<List<String>> Function()>[
      () async =>
          (await TextManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await ImageManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await VideoManifest.loadRecords()).map((r) => r.folder).toList(),
      () async =>
          (await FileManifest.loadRecords()).map((r) => r.folder).toList(),
    ];
    final folderSets = <Future<Set<String>> Function()>[
      TextManifest.getAllFolders,
      ImageManifest.getAllFolders,
      VideoManifest.getAllFolders,
      FileManifest.getAllFolders,
    ];

    for (var i = 0; i < operations.length; i++) {
      final source = ['text', 'image', 'video', 'audio'][i];
      var injected = false;
      ManifestDatabase.beforeFolderInsertForTesting = (path) {
        if (!injected && path.startsWith('new_') && path.endsWith('/sub')) {
          injected = true;
          throw StateError('injected folder persistence failure');
        }
      };
      await expectLater(operations[i](), throwsStateError);
      ManifestDatabase.beforeFolderInsertForTesting = null;
      expect(injected, isTrue);
      expect((await records[i]()).toSet(),
          containsAll(['old_$source', 'old_$source/sub']));
      expect((await folderSets[i]()).any((folder) => folder.startsWith('new_')),
          isFalse);
    }
  });

  testWidgets(
    'folder copy rolls back partial writes and can be retried for all types',
    (WidgetTester t) async {
      final now = DateTime.now();
      await TextManifest.addRecord(
        TextRecord(
          id: 'copy_rollback_text',
          name: 'doc',
          hash: 'copy_text',
          createdAt: now,
          size: 1,
          folder: 'copy_text',
        ),
      );
      await TextManifest.addRecord(
        TextRecord(
          id: 'copy_rollback_text_child',
          name: 'child',
          hash: 'copy_text_child',
          createdAt: now,
          size: 1,
          folder: 'copy_text/sub',
        ),
      );
      await ImageManifest.addRecord(
        ImageRecord(
          id: 'copy_rollback_image',
          name: 'img',
          hash: 'copy_image',
          format: 'png',
          createdAt: now,
          size: 1,
          folder: 'copy_image',
        ),
      );
      await ImageManifest.addRecord(
        ImageRecord(
          id: 'copy_rollback_image_child',
          name: 'child',
          hash: 'copy_image_child',
          format: 'png',
          createdAt: now,
          size: 1,
          folder: 'copy_image/sub',
        ),
      );
      await VideoManifest.addRecord(
        VideoRecord(
          id: 'copy_rollback_video',
          name: 'vid',
          hash: 'copy_video',
          format: 'mp4',
          createdAt: now,
          size: 1,
          folder: 'copy_video',
        ),
      );
      await VideoManifest.addRecord(
        VideoRecord(
          id: 'copy_rollback_video_child',
          name: 'child',
          hash: 'copy_video_child',
          format: 'mp4',
          createdAt: now,
          size: 1,
          folder: 'copy_video/sub',
        ),
      );
      await FileManifest.addRecord(
        AudioRecord(
          id: 'copy_rollback_audio',
          name: 'aud',
          hash: 'copy_audio',
          format: 'wav',
          createdAt: now,
          size: 1,
          folder: 'copy_audio',
        ),
      );
      await FileManifest.addRecord(
        AudioRecord(
          id: 'copy_rollback_audio_child',
          name: 'child',
          hash: 'copy_audio_child',
          format: 'wav',
          createdAt: now,
          size: 1,
          folder: 'copy_audio/sub',
        ),
      );

      final operations = <Future<void> Function()>[
        () => TextRecordsNotifier().copyFolder('copy_text', 'target'),
        () => ImageRecordsNotifier().copyFolder('copy_image', 'target'),
        () => VideoRecordsNotifier().copyFolder('copy_video', 'target'),
        () => AudioRecordsNotifier().copyFolder('copy_audio', 'target'),
      ];
      final records = <Future<List<dynamic>> Function()>[
        TextManifest.loadRecords,
        ImageManifest.loadRecords,
        VideoManifest.loadRecords,
        FileManifest.loadRecords,
      ];
      final folders = <Future<Set<String>> Function()>[
        TextManifest.getAllFolders,
        ImageManifest.getAllFolders,
        VideoManifest.getAllFolders,
        FileManifest.getAllFolders,
      ];
      final sourceNames = [
        'copy_text',
        'copy_image',
        'copy_video',
        'copy_audio',
      ];

      for (var i = 0; i < operations.length; i++) {
        var injected = false;
        ManifestDatabase.beforeFolderInsertForTesting = (path) {
          if (!injected && path == 'target/${sourceNames[i]}/sub') {
            injected = true;
            throw StateError('injected copy persistence failure');
          }
        };
        await expectLater(operations[i](), throwsStateError);
        ManifestDatabase.beforeFolderInsertForTesting = null;
        expect(injected, isTrue);
        expect(
          (await records[i]()).every(
            (record) => !record.folder.startsWith('target/${sourceNames[i]}'),
          ),
          isTrue,
        );
        expect(
          (await folders[i]()).any(
            (path) => path.startsWith('target/${sourceNames[i]}'),
          ),
          isFalse,
        );

        await operations[i]();
        expect(
          (await records[i]())
              .where(
                (record) =>
                    record.folder.startsWith('target/${sourceNames[i]}'),
              )
              .length,
          2,
        );
        expect(
          (await folders[i]()).contains('target/${sourceNames[i]}/sub'),
          isTrue,
        );
      }
    },
  );

  test('metadata-only folder cleanup preserves concurrent record paths',
      () async {
    final now = DateTime.now();
    await TextManifest.addRecord(TextRecord(
      id: 'metadata_cleanup_text',
      name: 'doc',
      hash: 'metadata_cleanup_text_hash',
      createdAt: now,
      size: 1,
      folder: 'shared/text',
    ));
    await ImageManifest.addRecord(ImageRecord(
      id: 'metadata_cleanup_image',
      name: 'img',
      hash: 'metadata_cleanup_image_hash',
      format: 'png',
      createdAt: now,
      size: 1,
      folder: 'shared/image',
    ));
    await VideoManifest.addRecord(VideoRecord(
      id: 'metadata_cleanup_video',
      name: 'vid',
      hash: 'metadata_cleanup_video_hash',
      format: 'mp4',
      createdAt: now,
      size: 1,
      folder: 'shared/video',
    ));
    await FileManifest.addRecord(AudioRecord(
      id: 'metadata_cleanup_audio',
      name: 'aud',
      hash: 'metadata_cleanup_audio_hash',
      format: 'wav',
      createdAt: now,
      size: 1,
      folder: 'shared/audio',
    ));
    await TextManifest.addFolder('shared/concurrent_empty');
    await ImageManifest.addFolder('shared/concurrent_empty');
    await VideoManifest.addFolder('shared/concurrent_empty');
    await FileManifest.addFolder('shared/concurrent_empty');

    await TextManifest.removeFolderMetadataFromCache('shared');
    await ImageManifest.removeFolderMetadataFromCache('shared');
    await VideoManifest.removeFolderMetadataFromCache('shared');
    await FileManifest.removeFolderMetadataFromCache('shared');

    expect((await TextManifest.loadRecords()).single.folder, 'shared/text');
    expect((await ImageManifest.loadRecords()).single.folder, 'shared/image');
    expect((await VideoManifest.loadRecords()).single.folder, 'shared/video');
    expect((await FileManifest.loadRecords()).single.folder, 'shared/audio');
    expect(await TextManifest.getAllFolders(),
        contains('shared/concurrent_empty'));
    expect(await ImageManifest.getAllFolders(),
        contains('shared/concurrent_empty'));
    expect(await VideoManifest.getAllFolders(),
        contains('shared/concurrent_empty'));
    expect(await FileManifest.getAllFolders(),
        contains('shared/concurrent_empty'));
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

    testWidgets('copied descendant records preserve duration',
        (WidgetTester t) async {
      final notifier = AudioRecordsNotifier();
      await notifier.loadRecords();
      await FileManifest.addRecord(AudioRecord(
        id: 'audio_cp_desc_dur_1',
        name: 'tts',
        hash: 'hash_audio_cp_desc_dur_1',
        format: 'wav',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a/sub',
        duration: 3700,
      ));

      await notifier.copyFolder('a', 'x');

      await notifier.loadRecords();
      final copies = notifier.state.where((r) => r.folder == 'x/a/sub');
      expect(copies, hasLength(1));
      expect(copies.first.duration, equals(3700),
          reason: 'copied descendant audio records must keep their duration');
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
    testWidgets('copyFolder snapshots records before adding copied records',
        (WidgetTester t) async {
      final notifier = ImageRecordsNotifier();
      await notifier.loadRecords();
      await ImageManifest.addRecord(ImageRecord(
        id: 'img_cp_snapshot_1',
        name: 'pic',
        hash: 'hash_img_cp_snapshot_1',
        format: 'jpg',
        createdAt: DateTime.now(),
        size: 4,
        folder: 'a',
      ));

      await expectLater(notifier.copyFolder('a', 'x'), completes);

      final records = await ImageManifest.loadRecords();
      expect(records.where((record) => record.folder == 'a'), hasLength(1));
      expect(records.where((record) => record.folder == 'x/a'), hasLength(1));
    });

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

  // ====================================================================
  // TextRecordsNotifier.renameRecord with format
  // （重命名时切换文件格式，如 txt → md）
  // ====================================================================

  group('TextRecordsNotifier rename record with format', () {
    testWidgets('renameRecord with a new format updates name and format',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_fmt_1',
        name: 'doc',
        hash: 'hash_fmt_1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
      ));

      await notifier.renameRecord('txt_fmt_1', 'doc', format: 'md');

      final record = notifier.state.firstWhere((r) => r.id == 'txt_fmt_1');
      expect(record.name, equals('doc'));
      expect(record.format, equals('md'));

      // 必须持久化到 manifest
      final fromDb = await TextManifest.loadRecords();
      final dbRecord = fromDb.firstWhere((r) => r.id == 'txt_fmt_1');
      expect(dbRecord.name, equals('doc'));
      expect(dbRecord.format, equals('md'));
    });

    testWidgets(
      'format rename moves subtitle content to the new storage path',
      (WidgetTester t) async {
        final notifier = TextRecordsNotifier();
        await notifier.loadRecords();
        final original = TextRecord(
          id: 'txt_fmt_subtitle',
          name: 'transcript',
          hash: 'hash_fmt_subtitle',
          format: 'srt',
          createdAt: DateTime.now(),
          size: 20,
        );
        const subtitle = '1\n00:00:00,000 --> 00:00:01,000\nHello';
        await TextManifest.writeText(original.storageFileName, subtitle);
        await TextManifest.addRecord(original);

        await notifier.renameRecord(
          'txt_fmt_subtitle',
          'transcript',
          format: 'vtt',
        );

        final renamed = (await TextManifest.loadRecords()).firstWhere(
          (record) => record.id == 'txt_fmt_subtitle',
        );
        expect(await TextManifest.readText(renamed.storageFileName), subtitle);
        expect(await TextManifest.readText(original.storageFileName), isNull);
      },
    );

    testWidgets(
      'format rename retries when content changes after its source read',
      (WidgetTester t) async {
        final notifier = TextRecordsNotifier();
        await notifier.loadRecords();
        final original = TextRecord(
          id: 'txt_fmt_concurrent_edit',
          name: 'diagram',
          hash: 'hash_fmt_concurrent_edit',
          format: 'srt',
          createdAt: DateTime.now(),
          size: 11,
        );
        const staleContent = 'old content';
        const latestContent = 'latest edit';
        await TextManifest.writeText(original.storageFileName, staleContent);
        await TextManifest.addRecord(original);

        var firstRead = true;
        TextManifest.readFileOverrideForTesting = (_) async {
          if (!firstRead) return null;
          firstRead = false;
          TextManifest.readFileOverrideForTesting = null;
          await TextManifest.updateTextRecord(
            TextRecord(
              id: original.id,
              name: original.name,
              hash: 'hash_fmt_concurrent_edit_latest',
              format: original.format,
              createdAt: original.createdAt,
              size: latestContent.length,
            ),
            latestContent,
          );
          await TextManifest.deleteFileIfUnreferenced(
            original.hash,
            original.storageFileName,
          );
          return Uint8List.fromList(utf8.encode(staleContent));
        };

        await notifier.renameRecord(original.id, 'diagram', format: 'mmd');

        final converted = (await TextManifest.loadRecords())
            .singleWhere((record) => record.id == original.id);
        expect(converted.format, 'mmd');
        expect(converted.hash, 'hash_fmt_concurrent_edit_latest');
        expect(
          await TextManifest.readText(converted.storageFileName),
          latestContent,
        );
        expect(await TextManifest.readText(original.storageFileName), isNull);
      },
    );

    testWidgets(
      'format rename retries when initial source read misses a concurrent save',
      (WidgetTester t) async {
        final notifier = TextRecordsNotifier();
        await notifier.loadRecords();
        final original = TextRecord(
          id: 'txt_fmt_initial_read_miss',
          name: 'diagram',
          hash: 'hash_fmt_initial_read_miss',
          format: 'srt',
          createdAt: DateTime.now(),
          size: 11,
        );
        const latestContent = 'latest edit';
        await TextManifest.writeText(original.storageFileName, 'old content');
        await TextManifest.addRecord(original);

        TextManifest.readFileOverrideForTesting = (_) async {
          TextManifest.readFileOverrideForTesting = null;
          await TextManifest.updateTextRecord(
            TextRecord(
              id: original.id,
              name: original.name,
              hash: 'hash_fmt_initial_read_miss_latest',
              format: original.format,
              createdAt: original.createdAt,
              size: latestContent.length,
            ),
            latestContent,
          );
          await TextManifest.deleteFileIfUnreferenced(
            original.hash,
            original.storageFileName,
          );
          return null;
        };

        await notifier.renameRecord(original.id, 'diagram', format: 'mmd');

        final converted = (await TextManifest.loadRecords())
            .singleWhere((record) => record.id == original.id);
        expect(converted.format, 'mmd');
        expect(converted.hash, 'hash_fmt_initial_read_miss_latest');
        expect(
          await TextManifest.readText(converted.storageFileName),
          latestContent,
        );
        expect(await TextManifest.readText(original.storageFileName), isNull);
      },
    );

    testWidgets(
      'format rename keeps the original record when reading content fails',
      (WidgetTester t) async {
        final notifier = TextRecordsNotifier();
        await notifier.loadRecords();
        final original = TextRecord(
          id: 'txt_fmt_read_error',
          name: 'diagram',
          hash: 'hash_fmt_read_error',
          format: 'srt',
          createdAt: DateTime.now(),
          size: 20,
        );
        const content = 'graph TD\n  A-->B';
        await TextManifest.writeText(original.storageFileName, content);
        await TextManifest.addRecord(original);

        TextManifest.readFileOverrideForTesting = (_) async => null;
        try {
          await expectLater(
            notifier.renameRecord(
              original.id,
              'diagram',
              format: 'mmd',
            ),
            throwsA(isA<Exception>()),
          );
        } finally {
          TextManifest.readFileOverrideForTesting = null;
        }

        final fromDb = (await TextManifest.loadRecords())
            .firstWhere((record) => record.id == original.id);
        expect(fromDb.format, 'srt');
        expect(fromDb.storageFileName, original.storageFileName);
        expect(await TextManifest.readText(original.storageFileName), content);
        expect(await TextManifest.readText('hash_fmt_read_error.txt'), isNull);
      },
    );

    testWidgets(
      'format rename keeps the original format when source is missing',
      (WidgetTester t) async {
        final notifier = TextRecordsNotifier();
        await notifier.loadRecords();
        final original = TextRecord(
          id: 'txt_fmt_missing_source',
          name: 'diagram',
          hash: 'hash_fmt_missing_source',
          format: 'srt',
          createdAt: DateTime.now(),
          size: 0,
        );
        await TextManifest.addRecord(original);

        await expectLater(
          notifier.renameRecord(original.id, 'diagram', format: 'mmd'),
          throwsA(isA<Exception>()),
        );

        final fromDb = (await TextManifest.loadRecords())
            .firstWhere((record) => record.id == original.id);
        expect(fromDb.format, 'srt');
        expect(fromDb.storageFileName, original.storageFileName);
        expect(
            await TextManifest.readText('hash_fmt_missing_source.txt'), isNull);
      },
    );

    testWidgets('renameRecord with a new name and format updates both',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_fmt_2',
        name: 'doc',
        hash: 'hash_fmt_2',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
      ));

      await notifier.renameRecord('txt_fmt_2', 'renamed', format: 'mmd');

      final record = notifier.state.firstWhere((r) => r.id == 'txt_fmt_2');
      expect(record.name, equals('renamed'));
      expect(record.format, equals('mmd'));
    });

    testWidgets('renameRecord without a format keeps the original format',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();
      await TextManifest.addRecord(TextRecord(
        id: 'txt_fmt_3',
        name: 'doc',
        hash: 'hash_fmt_3',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 4,
      ));

      await notifier.renameRecord('txt_fmt_3', 'renamed');

      final record = notifier.state.firstWhere((r) => r.id == 'txt_fmt_3');
      expect(record.name, equals('renamed'));
      expect(record.format, equals('txt'));
    });

    testWidgets('renameRecord with an unknown id is a safe no-op',
        (WidgetTester t) async {
      final notifier = TextRecordsNotifier();
      await notifier.loadRecords();

      // 不应抛异常，也不应新增记录
      await notifier.renameRecord('missing', 'x', format: 'md');

      expect(notifier.state, isEmpty);
      expect(await TextManifest.loadRecords(), isEmpty);
    });
  });
}
