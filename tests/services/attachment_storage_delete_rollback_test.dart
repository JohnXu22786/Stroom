// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/attachment_storage.dart';

void main() {
  tearDown(AttachmentStorage.resetOverridesForTesting);

  test(
    'failed attachment deletion restores earlier files before rethrowing',
    () async {
      final files = <String, Uint8List>{
        'attachments/first.png': Uint8List.fromList([1, 2, 3]),
        'attachments/second.png': Uint8List.fromList([4, 5, 6]),
      };
      AttachmentStorage.readFileOverrideForTesting = (path) async {
        final bytes = files[path];
        return bytes == null ? null : Uint8List.fromList(bytes);
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        if (path == 'attachments/second.png') {
          files.remove(path);
          throw StateError('delete failed');
        }
        files.remove(path);
        return true;
      };
      AttachmentStorage.restoreFileOverrideForTesting = (path, bytes) async {
        files[path] = Uint8List.fromList(bytes);
      };

      await expectLater(
        AttachmentStorage.deleteFilesWithRollback(files.keys.toList()),
        throwsA(isA<StateError>()),
      );

      expect(
        files.keys,
        containsAll(['attachments/first.png', 'attachments/second.png']),
      );
      expect(files['attachments/first.png'], [1, 2, 3]);
      expect(files['attachments/second.png'], [4, 5, 6]);
    },
  );
}
