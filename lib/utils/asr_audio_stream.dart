import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

void throwIfAsrAudioCanceled(CancelToken? cancelToken) {
  if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
}

/// Reads one audio stream and cancels its subscription when its task is
/// canceled before the stream completes.
Future<Uint8List> readAsrAudioStream(
  Stream<List<int>> stream, {
  CancelToken? cancelToken,
}) async {
  throwIfAsrAudioCanceled(cancelToken);
  final output = BytesBuilder(copy: false);
  final completed = Completer<void>();
  final subscription = stream.listen(
    output.add,
    onError: (Object error, StackTrace stackTrace) {
      if (!completed.isCompleted) completed.completeError(error, stackTrace);
    },
    onDone: () {
      if (!completed.isCompleted) completed.complete();
    },
  );

  try {
    if (cancelToken == null) {
      await completed.future;
    } else {
      await Future.any<void>([
        completed.future,
        cancelToken.whenCancel.then<void>((cancelError) => throw cancelError),
      ]);
      throwIfAsrAudioCanceled(cancelToken);
    }
    return output.takeBytes();
  } finally {
    await subscription.cancel();
  }
}
