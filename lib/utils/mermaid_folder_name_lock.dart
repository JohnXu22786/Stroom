import 'dart:async';

/// Serializes visible-name allocation and publication for Mermaid saves by
/// destination folder.
class MermaidFolderNameLock {
  MermaidFolderNameLock._();

  static final Map<String, Future<void>> _pendingByFolder = {};

  static Future<T> withLock<T>(
    String folder,
    Future<T> Function() action,
  ) async {
    final previous = _pendingByFolder[folder] ?? Future<void>.value();
    final release = Completer<void>();
    final pending = previous.then((_) => release.future);
    _pendingByFolder[folder] = pending;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_pendingByFolder[folder], pending)) {
        _pendingByFolder.remove(folder);
      }
    }
  }
}
