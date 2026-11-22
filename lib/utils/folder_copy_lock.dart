import 'dart:async';

/// Serializes folder copies that publish to the same provider destination.
class FolderCopyLock {
  FolderCopyLock._();

  static final Map<String, Future<void>> _pendingByDestination = {};

  static Future<T> withLock<T>(
    String provider,
    String destination,
    Future<T> Function() action,
  ) async {
    final key = '$provider:$destination';
    final previous = _pendingByDestination[key] ?? Future<void>.value();
    final release = Completer<void>();
    final pending = previous.then((_) => release.future);
    _pendingByDestination[key] = pending;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_pendingByDestination[key], pending)) {
        _pendingByDestination.remove(key);
      }
    }
  }
}
