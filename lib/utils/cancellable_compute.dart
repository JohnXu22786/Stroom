import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

/// A byte buffer prepared for ownership transfer to a native isolate.
///
/// Materializing this value consumes its transferable payload. The isolate
/// port can then move the backing store without cloning the mutable byte list
/// as part of `Isolate.spawn` message delivery.
class IsolateTransferableBytes {
  final TransferableTypedData _payload;

  IsolateTransferableBytes(Uint8List bytes)
      : _payload = TransferableTypedData.fromList([bytes]);

  Uint8List materialize() => _payload.materialize().asUint8List();
}

class _ComputeRequest<Q, R> {
  final SendPort responsePort;
  final R Function(Q request) callback;
  final Q request;

  const _ComputeRequest(this.responsePort, this.callback, this.request);
}

class _ComputeSuccess<R> {
  final R value;

  const _ComputeSuccess(this.value);
}

class _ComputeFailure {
  final String type;
  final String message;
  final String stackTrace;

  const _ComputeFailure(this.type, this.message, this.stackTrace);
}

class _ComputeCancelled {
  final Object? reason;

  const _ComputeCancelled(this.reason);
}

class _CancellationPreflightComplete {
  const _CancellationPreflightComplete();
}

class CancellableComputeException implements Exception {
  final String remoteType;
  final String message;
  final String remoteStackTrace;

  const CancellableComputeException(
    this.remoteType,
    this.message,
    this.remoteStackTrace,
  );

  @override
  String toString() => '$remoteType: $message';
}

String _computeErrorMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message.toString();
  if (error is ArgumentError) return error.message.toString();
  if (error is Exception) {
    final prefix = '${error.runtimeType}: ';
    final text = error.toString();
    if (text.startsWith(prefix)) return text.substring(prefix.length);
  }
  return error.toString();
}

Future<Object?>? _observeCancellation(Future<Object?>? cancellationSignal) {
  return cancellationSignal?.then<Object?>(
    _ComputeCancelled.new,
    onError: (Object error, StackTrace stackTrace) => _ComputeCancelled(error),
  );
}

void _throwIfCancelled(Object? outcome) {
  if (outcome is! _ComputeCancelled) return;
  final reason = outcome.reason;
  if (reason != null) throw reason;
  throw StateError('Audio processing was cancelled.');
}

Future<void> _preflightCancellation(
  Future<Object?>? cancellationOutcome,
) async {
  if (cancellationOutcome == null) return;
  final outcome = await Future.any<Object?>([
    cancellationOutcome,
    Future<_CancellationPreflightComplete>.microtask(
      () => const _CancellationPreflightComplete(),
    ),
  ]);
  _throwIfCancelled(outcome);
}

void _computeEntry<Q, R>(_ComputeRequest<Q, R> request) {
  try {
    Isolate.exit(
      request.responsePort,
      _ComputeSuccess(request.callback(request.request)),
    );
  } on Object catch (error, stackTrace) {
    Isolate.exit(
      request.responsePort,
      _ComputeFailure(
        error.runtimeType.toString(),
        _computeErrorMessage(error),
        stackTrace.toString(),
      ),
    );
  }
}

/// Runs synchronous CPU work in a native isolate that can be killed when its
/// owning task is cancelled. [callback] must be a top-level or static function
/// so its isolate message does not retain unrelated objects.
Future<R> computeCancellable<Q, R>(
  R Function(Q request) callback,
  Q request, {
  required String debugLabel,
  Future<Object?>? cancellationSignal,
}) async {
  final cancellationOutcome = _observeCancellation(cancellationSignal);
  await _preflightCancellation(cancellationOutcome);
  return _runCancellable(
    callback,
    request,
    debugLabel: debugLabel,
    cancellationOutcome: cancellationOutcome,
  );
}

/// Runs work after creating its request only if cancellation has not already
/// completed. Use this when constructing [requestFactory] transfers a large
/// buffer or otherwise performs expensive synchronous work.
Future<R> computeCancellableWithRequestFactory<Q, R>(
  R Function(Q request) callback,
  Q Function() requestFactory, {
  required String debugLabel,
  Future<Object?>? cancellationSignal,
}) async {
  final cancellationOutcome = _observeCancellation(cancellationSignal);
  await _preflightCancellation(cancellationOutcome);
  final request = requestFactory();
  return _runCancellable(
    callback,
    request,
    debugLabel: debugLabel,
    cancellationOutcome: cancellationOutcome,
  );
}

Future<R> _runCancellable<Q, R>(
  R Function(Q request) callback,
  Q request, {
  required String debugLabel,
  required Future<Object?>? cancellationOutcome,
}) async {
  final responsePort = ReceivePort();
  Isolate? worker;
  try {
    worker = await Isolate.spawn<_ComputeRequest<Q, R>>(
      _computeEntry<Q, R>,
      _ComputeRequest<Q, R>(responsePort.sendPort, callback, request),
      debugName: debugLabel,
    );
    final responseFuture = responsePort.first.then<Object?>(
      (response) => response,
    );
    final outcome = cancellationOutcome == null
        ? await responseFuture
        : await Future.any<Object?>([responseFuture, cancellationOutcome]);

    if (outcome is _ComputeCancelled) {
      worker.kill(priority: Isolate.immediate);
      _throwIfCancelled(outcome);
    }
    if (outcome is _ComputeFailure) {
      switch (outcome.type) {
        case 'FormatException':
          throw FormatException(outcome.message);
        case 'StateError':
          throw StateError(outcome.message);
        case 'ArgumentError':
          throw ArgumentError(outcome.message);
        case 'Exception':
          throw Exception(outcome.message);
        default:
          throw CancellableComputeException(
            outcome.type,
            outcome.message,
            outcome.stackTrace,
          );
      }
    }
    if (outcome is! _ComputeSuccess<R>) {
      throw StateError('Audio worker returned an invalid response.');
    }
    return outcome.value;
  } finally {
    worker?.kill(priority: Isolate.immediate);
    responsePort.close();
  }
}
