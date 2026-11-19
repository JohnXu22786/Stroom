import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/video_thumbnail_temp_file.dart';

void main() {
  test(
    'concurrent byte fallbacks use distinct files with their own bytes',
    () async {
      final firstBytes = Uint8List.fromList([1, 2, 3]);
      final secondBytes = Uint8List.fromList([4, 5, 6]);
      final paths = <String>[];
      final bothGeneratorsStarted = Completer<void>();
      final continueGenerators = Completer<void>();

      Future<Uint8List?> generate(Uint8List bytes) {
        return withVideoThumbnailTempFile(bytes, (path) async {
          paths.add(path);
          final writtenBytes = await File(path).readAsBytes();
          if (paths.length == 2 && !bothGeneratorsStarted.isCompleted) {
            bothGeneratorsStarted.complete();
          }
          await continueGenerators.future;
          return writtenBytes;
        });
      }

      final first = generate(firstBytes);
      final second = generate(secondBytes);
      await bothGeneratorsStarted.future;

      expect(paths.toSet(), hasLength(2));
      continueGenerators.complete();
      expect(await first, firstBytes);
      expect(await second, secondBytes);
      for (final path in paths) {
        expect(await File(path).exists(), isFalse);
      }
    },
  );
}
