import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/asr_audio_stream.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  test(
    'observes request and transaction failures after IndexedDB abort',
    () async {
      final uncaughtErrors = <Object>[];
      final finished = Completer<void>();

      runZonedGuarded(
        () async {
          try {
            final request = Completer<Object?>();
            final transactionCompleted = Completer<void>();
            final read =
                WebFileStore.waitForRequestAndTransactionCompletionForTesting(
              request.future,
              transactionCompleted.future,
            );
            request.completeError(StateError('request aborted'));
            transactionCompleted.completeError(
              StateError('transaction aborted'),
            );

            await expectLater(read, throwsStateError);
            await Future<void>.delayed(Duration.zero);
          } finally {
            finished.complete();
          }
        },
        (error, stackTrace) {
          uncaughtErrors.add(error);
        },
      );

      await finished.future;
      expect(uncaughtErrors, isEmpty);
    },
  );

  test('canceling a file-backed stream stops reading before EOF', () async {
    final directory = await Directory.systemTemp.createTemp('asr-stream-');
    final file = File('${directory.path}/long-audio.raw');
    await file.writeAsBytes(Uint8List(16 * 1024 * 1024));
    final source = StreamController<List<int>>();
    final cancelToken = CancelToken();
    var sourceChunks = 0;
    late StreamSubscription<List<int>> fileSubscription;
    source.onCancel = () => fileSubscription.cancel();

    final read = readAsrAudioStream(source.stream, cancelToken: cancelToken);
    fileSubscription = file.openRead().listen(
      (chunk) {
        sourceChunks++;
        source.add(chunk);
        if (sourceChunks == 1) cancelToken.cancel('stop reading');
      },
      onError: source.addError,
      onDone: source.close,
    );

    await expectLater(read, throwsA(isA<DioException>()));
    expect(sourceChunks, lessThan(100));

    await directory.delete(recursive: true);
  });
}
