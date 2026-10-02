import 'dart:async';
import 'dart:isolate';
import 'batch_rename_config.dart';
import 'batch_rename_regex.dart';

/// One cancellable preview owns this worker. Each rule has a bounded runtime.
class BatchRenameRegexWorker {
  final Duration timeout;
  bool _disposed = false;
  void Function()? _cancelPending;
  BatchRenameRegexWorker({this.timeout = const Duration(seconds: 2)});

  Future<List<BatchRenameRegexResult>> replace(
      List<String> names, BatchReplaceOp op) async {
    if (_disposed) throw BatchRenameRegexCancelled();
    if (_cancelPending != null) throw StateError('正则计算尚未完成');
    final done = Completer<List<BatchRenameRegexResult>>();
    final port = ReceivePort();
    Isolate? isolate;
    void fail(Object error) {
      if (!done.isCompleted) done.completeError(error);
    }

    _cancelPending = () => fail(BatchRenameRegexCancelled());
    final timer =
        Timer(timeout, () => fail(TimeoutException('正则计算超时，请简化表达式或缩小参与范围')));
    final subscription = port.listen((message) {
      if (done.isCompleted) return;
      if (message is List<BatchRenameRegexResult>) {
        done.complete(message);
      } else {
        fail(StateError('正则预览计算失败，请调整规则'));
      }
    });
    // Cancellation can win before spawn returns; kill the late isolate too.
    unawaited(Isolate.spawn(_replaceInIsolate, (port.sendPort, names, op),
            onError: port.sendPort, onExit: port.sendPort)
        .then((value) {
      isolate = value;
      if (done.isCompleted) value.kill(priority: Isolate.immediate);
    }, onError: (Object error) => fail(error)));
    try {
      return await done.future;
    } finally {
      timer.cancel();
      isolate?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      port.close();
      _cancelPending = null;
    }
  }

  void dispose() {
    _disposed = true;
    _cancelPending?.call();
  }
}

void _replaceInIsolate((SendPort, List<String>, BatchReplaceOp) request) {
  final results = <BatchRenameRegexResult>[];
  for (final name in request.$2) {
    try {
      results.add(BatchRenameRegexResult(
          name: replaceBatchRenameText(name, request.$3)));
    } on FormatException catch (e) {
      results.add(BatchRenameRegexResult(error: e.message));
    }
  }
  request.$1.send(results);
}
