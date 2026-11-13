import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';
import 'package:stroom/utils/storage_file_publication.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  final content = Uint8List.fromList([1, 2, 3]);
  final thumbnail = Uint8List.fromList([4, 5]);

  ImageRecord imageRecord() => ImageRecord(
        name: 'image',
        hash: 'image-hash',
        format: 'png',
        createdAt: DateTime(2025),
        size: content.length,
      );

  VideoRecord videoRecord() => VideoRecord(
        name: 'video',
        hash: 'video-hash',
        format: 'mp4',
        createdAt: DateTime(2025),
        size: content.length,
      );

  test('failed image publication removes new content and thumbnail', () async {
    final record = imageRecord();
    final files = <String, Uint8List>{};
    final failure = StateError('record insert failed');

    await expectLater(
      publishStorageFiles<void, ImageRecord>(
        publish: (write) async {
          await write(record.storageFileName, content);
          await write(imageThumbFileName(record.hash), thumbnail);
          throw failure;
        },
        loadRecords: () async => [],
        isReferenced: (candidate, fileName) =>
            candidate.hash == record.hash &&
            (fileName == candidate.storageFileName ||
                fileName == imageThumbFileName(candidate.hash)),
        writeFile: (name, bytes) async {
          files[name] = bytes;
          return null;
        },
        readFile: (name) async => files[name],
        fileExists: (name) async => files.containsKey(name),
        deleteFile: (name) async {
          files.remove(name);
        },
      ),
      throwsA(same(failure)),
    );

    expect(files, isEmpty);
  });

  test('failed video publication removes new content and thumbnail', () async {
    final record = videoRecord();
    final thumbName = VideoManifest.thumbnailFileName(record.hash);
    final files = <String, Uint8List>{};

    await expectLater(
      publishStorageFiles<void, VideoRecord>(
        publish: (write) async {
          await write(record.storageFileName, content);
          await write(thumbName, thumbnail);
          throw StateError('record insert failed');
        },
        loadRecords: () async => [],
        isReferenced: (candidate, fileName) =>
            candidate.hash == record.hash &&
            (fileName == candidate.storageFileName ||
                fileName == VideoManifest.thumbnailFileName(candidate.hash)),
        writeFile: (name, bytes) async {
          files[name] = bytes;
          return null;
        },
        readFile: (name) async => files[name],
        fileExists: (name) async => files.containsKey(name),
        deleteFile: (name) async {
          files.remove(name);
        },
      ),
      throwsStateError,
    );

    expect(files, isEmpty);
  });

  test(
    'failed video publication preserves pre-existing shared files',
    () async {
      final record = videoRecord();
      final existing = videoRecord();
      final thumbName = '${record.hash}_thumb.jpg';
      final files = <String, Uint8List>{
        record.storageFileName: Uint8List.fromList([9]),
        thumbName: Uint8List.fromList([8]),
      };
      final originalContent = files[record.storageFileName];
      final originalThumbnail = files[thumbName];

      await expectLater(
        publishStorageFiles<void, VideoRecord>(
          publish: (write) async {
            await write(record.storageFileName, content);
            await write(thumbName, thumbnail);
            throw StateError('record insert failed');
          },
          loadRecords: () async => [existing],
          isReferenced: (candidate, fileName) =>
              candidate.hash == record.hash &&
              (fileName == candidate.storageFileName || fileName == thumbName),
          writeFile: (name, bytes) async {
            files[name] = bytes;
            return null;
          },
          readFile: (name) async => files[name],
          fileExists: (name) async => files.containsKey(name),
          deleteFile: (name) async {
            files.remove(name);
          },
        ),
        throwsStateError,
      );

      expect(files[record.storageFileName], originalContent);
      expect(files[thumbName], originalThumbnail);
    },
  );

  test(
    'uncertain image manifest read restores old bytes and keeps new files',
    () async {
      final record = imageRecord();
      final oldThumbnail = Uint8List.fromList([7]);
      final thumbName = imageThumbFileName(record.hash);
      final files = <String, Uint8List>{thumbName: oldThumbnail};

      await expectLater(
        publishStorageFiles<void, ImageRecord>(
          publish: (write) async {
            await write(record.storageFileName, content);
            await write(thumbName, thumbnail);
            throw StateError('publication outcome unknown');
          },
          loadRecords: () async => throw StateError('manifest unavailable'),
          isReferenced: (_, _) => false,
          writeFile: (name, bytes) async {
            files[name] = bytes;
            return null;
          },
          readFile: (name) async => files[name],
          fileExists: (name) async => files.containsKey(name),
          deleteFile: (name) async {
            files.remove(name);
          },
        ),
        throwsStateError,
      );

      expect(files[record.storageFileName], content);
      expect(files[thumbName], oldThumbnail);
    },
  );
}
