import 'dart:async';

/// Serializes publication and deletion of files that share a content hash.
///
/// A save lock must cover the complete publication sequence, including any
/// asynchronous work between writing the bytes and registering their record.
class ContentHashSaveLock {
  final Map<String, Future<void>> _tails = {};
  final Object _zoneKey = Object();

  Future<T> withLock<T>(String hash, Future<T> Function() action) async {
    final held = Zone.current[_zoneKey] as Set<String>? ?? const {};
    if (held.contains(hash)) return action();

    final previous = _tails[hash] ?? Future<void>.value();
    final release = Completer<void>();
    final pending = previous.then((_) => release.future);
    _tails[hash] = pending;
    await previous;
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: {
          _zoneKey: {...held, hash},
        },
      );
    } finally {
      release.complete();
      if (identical(_tails[hash], pending)) _tails.remove(hash);
    }
  }

  Future<T> withLocks<T>(Iterable<String> hashes, Future<T> Function() action) {
    final ordered = hashes.toSet().toList()..sort();

    Future<T> acquire(int index) {
      if (index == ordered.length) return action();
      return withLock(ordered[index], () => acquire(index + 1));
    }

    return acquire(0);
  }
}
