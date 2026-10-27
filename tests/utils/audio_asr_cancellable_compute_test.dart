import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/cancellable_compute.dart';

int _slowWorker(Object? request) {
  final events = request as SendPort;
  events.send('started');
  final stopwatch = Stopwatch()..start();
  var checksum = 0;
  while (stopwatch.elapsedMilliseconds < 300) {
    checksum++;
  }
  events.send('finished');
  return checksum;
}

Uint8List _materializeTransferredBytes(IsolateTransferableBytes bytes) =>
    bytes.materialize();

void main() {
  test('worker receives transferable audio bytes intact', () async {
    final source = Uint8List.fromList(List<int>.generate(4096, (i) => i % 256));
    final transferred = IsolateTransferableBytes(source);

    final result =
        await computeCancellable<IsolateTransferableBytes, Uint8List>(
      _materializeTransferredBytes,
      transferred,
      debugLabel: 'asr-transferable-bytes-test',
    );

    expect(result, orderedEquals(source));
  });

  test(
    'precompleted cancellation skips lazy request creation and worker spawn',
    () async {
      final cancellation = Completer<Object?>()
        ..complete(StateError('cancelled before request creation'));
      var requestCreated = false;

      await expectLater(
        computeCancellableWithRequestFactory<int, int>(
          (request) => request,
          () {
            requestCreated = true;
            return 7;
          },
          debugLabel: 'asr-cancel-before-request-test',
          cancellationSignal: cancellation.future,
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('cancelled before request creation'),
          ),
        ),
      );

      expect(requestCreated, isFalse);
    },
  );

  test('cancellation terminates a running native worker isolate', () async {
    final events = ReceivePort();
    final started = Completer<void>();
    var finished = false;
    events.listen((message) {
      if (message == 'started' && !started.isCompleted) started.complete();
      if (message == 'finished') finished = true;
    });
    final cancellation = Completer<Object?>();

    final work = computeCancellable<SendPort, int>(
      _slowWorker,
      events.sendPort,
      debugLabel: 'asr-cancellation-test',
      cancellationSignal: cancellation.future,
    );

    await started.future.timeout(const Duration(seconds: 5));
    cancellation.complete(StateError('cancelled'));
    await expectLater(work, throwsA(isA<StateError>()));
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(finished, isFalse);
    events.close();
  });
}
