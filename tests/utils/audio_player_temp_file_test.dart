import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_player_temp_file.dart';

void main() {
  test('deletes a partial temp file when writing fails', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));

    await expectLater(
      writeAudioPlayerTempFile(
        getTempDirectory: () async => directory,
        bytes: [1, 2, 3],
        extension: 'wav',
        isDisposed: () => false,
        writeBytes: (file, _) async {
          await file.writeAsBytes([1]);
          throw StateError('simulated write failure');
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(directory.listSync(), isEmpty);
  });

  test(
    'preserves the temp-write error when partial-file cleanup fails',
    () async {
      final directory = await Directory.systemTemp.createTemp('audio_player_');
      addTearDown(() => directory.delete(recursive: true));
      final writeError = StateError('simulated write failure');
      Directory? partialArtifact;

      await expectLater(
        writeAudioPlayerTempFile(
          getTempDirectory: () async => directory,
          bytes: [1, 2, 3],
          extension: 'wav',
          isDisposed: () => false,
          writeBytes: (file, _) async {
            partialArtifact = await Directory(file.path).create();
            throw writeError;
          },
        ),
        throwsA(same(writeError)),
      );

      expect(await partialArtifact!.exists(), isTrue);
    },
  );

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

  test('waits for player disposal before deleting its temp file', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/playing.wav');
    await file.writeAsBytes([1, 2, 3]);
    final disposalStarted = Completer<void>();
    final finishDisposal = Completer<void>();

    final cleanup = disposeAudioPlayerTempFile(
      tempFilePath: file.path,
      disposePlayer: () async {
        disposalStarted.complete();
        await finishDisposal.future;
      },
    );

    await disposalStarted.future;
    expect(await file.exists(), isTrue);
    finishDisposal.complete();
    await cleanup;

    expect(await file.exists(), isFalse);
  });

  test('surfaces temp-file deletion failures', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));

    await expectLater(
      deleteAudioPlayerTempFile(File(directory.path)),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('ignores a temp file that was already removed', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/already_removed.wav');

    await deleteAudioPlayerTempFile(file);
  });

  test('does not delete the temp file when player disposal fails', () async {
    final directory = await Directory.systemTemp.createTemp('audio_player_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/playing.wav');
    await file.writeAsBytes([1, 2, 3]);
    final disposalError = StateError('player disposal failed');

    await expectLater(
      disposeAudioPlayerTempFile(
        tempFilePath: file.path,
        disposePlayer: () async => throw disposalError,
      ),
      throwsA(same(disposalError)),
    );
    expect(await file.exists(), isTrue);
  });
}
