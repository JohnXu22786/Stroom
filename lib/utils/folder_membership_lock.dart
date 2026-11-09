import 'dart:async';

import 'content_hash_save_lock.dart';

/// Coordinates folder copies and deletion across one provider's folders.
/// Each copy owns the provider membership lock; additions and deletions wait
/// until its source snapshot and destination publication are complete.
class FolderMembershipLock {
  static final _locks = ContentHashSaveLock();
  static final Object _copyZoneKey = Object();

  static Future<void> Function()? afterCopySnapshotForTesting;

  static Future<T> withCopyLock<T>(
    String provider,
    String folderPath,
    Future<T> Function() action,
  ) {
    final held = Zone.current[_copyZoneKey] as Set<String>? ?? const {};
    return _locks.withFolderWriteLock(
      '$provider:membership',
      () => runZoned(
        action,
        zoneValues: {
          _copyZoneKey: {...held, provider},
        },
      ),
    );
  }

  static Future<T> withAddLock<T>(
    String provider,
    String folderPath,
    Future<T> Function() action,
  ) {
    final held = Zone.current[_copyZoneKey] as Set<String>? ?? const {};
    if (held.contains(provider)) return action();
    return _locks.withFolderWriteLock('$provider:membership', action);
  }

  static Future<T> withDeleteLock<T>(
    String provider,
    String folderPath,
    Future<T> Function() action,
  ) =>
      _locks.withFolderWriteLock('$provider:membership', action);
}
