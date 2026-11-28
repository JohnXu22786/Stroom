import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;

/// Resolves an FVP conversion when it completes, fails, or is cancelled.
class FvpConversionWaiter {
  FvpConversionWaiter({
    required CancelToken? cancelToken,
    required void Function() stopPlayer,
  }) {
    cancelToken?.whenCancel.then((_) {
      if (_completer.isCompleted) return;
      try {
        stopPlayer();
      } catch (_) {}
      completeError(Exception('Task was cancelled'));
    });
  }

  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
