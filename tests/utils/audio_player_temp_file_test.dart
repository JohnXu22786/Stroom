import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_player_temp_file.dart';

void main() {
  test('keeps overlapping same-extension temp writes independent', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));
    final finishWrites = Completer<void>();
    final paths = <String>[];
    final firstBytes = [1, 2, 3];
    final secondBytes = [4, 5, 6];
    final sameTick = DateTime(2025, 1, 1);

    Future<File?> write(List<int> bytes) => writeAudioPlayerTempFile(
          getTempDirectory: () async => directory,
          now: () => sameTick,
          bytes: bytes,
          extension: 'wav',
          isDisposed: () => false,
          writeBytes: (file, fileBytes) async {
            paths.add(file.path);
            await finishWrites.future;
            await file.writeAsBytes(fileBytes);
          },
        );

    final firstWrite = write(firstBytes);
    final secondWrite = write(secondBytes);
    while (paths.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    finishWrites.complete();

    final files = await Future.wait([firstWrite, secondWrite]);
    expect(paths.toSet(), hasLength(2));
    expect(files.map((file) => file!.path).toSet(), hasLength(2));
    expect(await files[0]!.readAsBytes(), firstBytes);
    expect(await files[1]!.readAsBytes(), secondBytes);
  });

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
