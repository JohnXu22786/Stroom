import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/attachment_storage.dart';

/// Durable cleanup for file copies that have not been handed to a flow run.
class TaskFlowInputCleanup {
  TaskFlowInputCleanup._();

  static const _pendingKey = 'task_flow_pending_input_cleanup';
  // Keep ownership if preferences reject the durable write, for a later builder.
  static final _inMemoryPendingReferences = <String>{};
  static final _activeOperations = <Future<void>>{};
  static Future<void> _pendingWrites = Future<void>.value();

  static Future<void> enqueueAll(Iterable<String> references) {
    final additions = references.toSet();
    if (additions.isEmpty) return Future<void>.value();
    return _track(_enqueueAll(additions));
  }

  static Future<void> _enqueueAll(Set<String> additions) async {
    _inMemoryPendingReferences.addAll(additions);
    await _updatePending((pending) => pending..addAll(additions));
    _inMemoryPendingReferences.removeAll(additions);
  }

  static Future<void> enqueueAndRetry(
    Iterable<String> references, {
    VoidCallback? onQueued,
  }) {
    final additions = references.toSet();
    if (additions.isEmpty) return Future<void>.value();
    return _track(_enqueueAndRetry(additions, onQueued));
  }

  static Future<void> _enqueueAndRetry(
    Set<String> references,
    VoidCallback? onQueued,
  ) async {
    await enqueueAll(references);
    onQueued?.call();
    await retryPending();
  }

  static Future<void> retryPending() => _track(_retryPending());

  static Future<void> _retryPending() async {
    final pending = Set<String>.of(_inMemoryPendingReferences);
    try {
      pending.addAll(await pendingReferencesForTesting());
    } catch (error) {
      debugPrint('Failed to load unsubmitted flow input cleanup: $error');
    }
    for (final reference in pending) {
      try {
        await AttachmentStorage.deleteFile(reference);
        _inMemoryPendingReferences.remove(reference);
        await _updatePending((references) => references..remove(reference));
      } catch (error) {
        debugPrint('Failed to discard unsubmitted flow input: $error');
      }
    }
  }

  @visibleForTesting
  static Future<List<String>> pendingReferencesForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pendingKey) ?? const [];
  }

  @visibleForTesting
  static Future<void> waitForIdleForTesting() async {
    while (_activeOperations.isNotEmpty) {
      try {
        await Future.wait(_activeOperations.toList(), eagerError: false);
      } catch (_) {}
    }
    await _pendingWrites;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await waitForIdleForTesting();
    _inMemoryPendingReferences.clear();
  }

  static Future<void> _track(Future<void> operation) {
    _activeOperations.add(operation);
    operation.then(
      (_) => _activeOperations.remove(operation),
      onError: (Object _, StackTrace _) => _activeOperations.remove(operation),
    );
    return operation;
  }

  static Future<void> _updatePending(Set<String> Function(Set<String>) update) {
    final result = _pendingWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final pending = update(prefs.getStringList(_pendingKey)?.toSet() ?? {});
      if (pending.isEmpty) {
        await prefs.remove(_pendingKey);
      } else {
        final stored = await prefs.setStringList(_pendingKey, pending.toList());
        if (!stored) {
          throw StateError('Failed to persist unsubmitted flow input cleanup.');
        }
      }
    });
    _pendingWrites = result.catchError((Object error) {
      debugPrint('Failed to persist unsubmitted flow input cleanup: $error');
    });
    return result;
  }
}
