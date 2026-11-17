import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_player_temp_file.dart';

void main() {
  test(
    'deletes the temp file when disposal happens during the write',
    () async {
      final directory = await Directory.systemTemp.createTemp('audio_player_');
      addTearDown(() => directory.delete(recursive: true));
      final writeStarted = Completer<void>();
      final finishWrite = Completer<void>();
      var disposed = false;

      final write = writeAudioPlayerTempFile(
        getTempDirectory: () async => directory,
        bytes: [1, 2, 3],
        extension: 'wav',
        isDisposed: () => disposed,
        writeBytes: (file, bytes) async {
          writeStarted.complete();
          await finishWrite.future;
          await file.writeAsBytes(bytes);
        },
      );

      await writeStarted.future;
      disposed = true;
      finishWrite.complete();

      expect(await write, isNull);
      expect(directory.listSync(), isEmpty);
    },
  );
}
