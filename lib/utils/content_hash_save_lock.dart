import 'dart:async';

/// Serializes publication and deletion of files that share a content hash.
///
/// A save lock must cover the complete publication sequence, including any
/// asynchronous work between writing the bytes and registering their record.
class ContentHashSaveLock {
  final Map<String, Future<void>> _tails = {};
  final Map<String, _FolderReadWriteLock> _folderLocks = {};
  final Object _zoneKey = Object();
  final Object _folderReadZoneKey = Object();
  final Object _folderWriteZoneKey = Object();

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

  /// Allows independent saves in the same folder tree to proceed together.
  /// Folder deletion uses [withFolderWriteLock] for its target path.
  Future<T> withFolderReadLocks<T>(
    Iterable<String> folders,
    Future<T> Function() action,
  ) async {
    final ordered = folders.toSet().toList()..sort();
    final heldReads =
        Zone.current[_folderReadZoneKey] as Set<String>? ?? const {};
    final heldWrites =
        Zone.current[_folderWriteZoneKey] as Set<String>? ?? const {};
    final acquired = <String>[];
    for (final folder in ordered) {
      if (heldReads.contains(folder) || heldWrites.contains(folder)) continue;
      final lock = _folderLocks.putIfAbsent(folder, _FolderReadWriteLock.new);
      await lock.acquireRead();
      acquired.add(folder);
    }
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: {
          _folderReadZoneKey: {...heldReads, ...acquired},
          _folderWriteZoneKey: heldWrites,
        },
      );
    } finally {
      for (final folder in acquired.reversed) {
        _folderLocks[folder]!.releaseRead();
      }
    }
  }

  /// Excludes saves, moves, and updates that target this folder or a descendant.
  Future<T> withFolderWriteLock<T>(
    String folder,
    Future<T> Function() action,
  ) async {
    final heldReads =
        Zone.current[_folderReadZoneKey] as Set<String>? ?? const {};
    final heldWrites =
        Zone.current[_folderWriteZoneKey] as Set<String>? ?? const {};
    if (heldWrites.contains(folder)) return action();
    if (heldReads.contains(folder)) {
      throw StateError('Cannot upgrade a folder read lock to a write lock.');
    }

    final lock = _folderLocks.putIfAbsent(folder, _FolderReadWriteLock.new);
    await lock.acquireWrite();
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: {
          _folderReadZoneKey: heldReads,
          _folderWriteZoneKey: {...heldWrites, folder},
        },
      );
    } finally {
      lock.releaseWrite();
    }
  }
}

class _FolderReadWriteLock {
  int _readers = 0;
  bool _writer = false;
  final List<_FolderLockWaiter> _waiters = [];

  Future<void> acquireRead() {
    if (!_writer && _waiters.isEmpty) {
      _readers++;
      return Future<void>.value();
    }
    final waiter = _FolderLockWaiter(write: false);
    _waiters.add(waiter);
    return waiter.ready.future;
  }

  Future<void> acquireWrite() {
    if (!_writer && _readers == 0 && _waiters.isEmpty) {
      _writer = true;
      return Future<void>.value();
    }
    final waiter = _FolderLockWaiter(write: true);
    _waiters.add(waiter);
    return waiter.ready.future;
  }

  void releaseRead() {
    _readers--;
    _drainWaiters();
  }

  void releaseWrite() {
    _writer = false;
    _drainWaiters();
  }

  void _drainWaiters() {
    if (_writer || _waiters.isEmpty) return;
    if (_waiters.first.write) {
      if (_readers != 0) return;
      _writer = true;
      _waiters.removeAt(0).ready.complete();
      return;
    }
    while (_waiters.isNotEmpty && !_waiters.first.write) {
      _readers++;
      _waiters.removeAt(0).ready.complete();
    }
  }
}

class _FolderLockWaiter {
  _FolderLockWaiter({required this.write});

  final bool write;
  final Completer<void> ready = Completer<void>();
}
