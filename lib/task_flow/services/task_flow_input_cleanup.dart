import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/attachment_storage.dart';

/// Durable cleanup for file copies that have not been handed to a flow run.
class TaskFlowInputCleanup {
  TaskFlowInputCleanup._();

  static const _pendingKey = 'task_flow_pending_input_cleanup';
  static Future<void> _pendingWrites = Future<void>.value();

  static Future<void> enqueueAll(Iterable<String> references) async {
    final additions = references.toSet();
    if (additions.isEmpty) return;
    await _updatePending((pending) => pending..addAll(additions));
  }

  static Future<void> retryPending() async {
    late final List<String> pending;
    try {
      pending = await pendingReferencesForTesting();
    } catch (error) {
      debugPrint('Failed to load unsubmitted flow input cleanup: $error');
      return;
    }
    for (final reference in pending) {
      try {
        await AttachmentStorage.deleteFile(reference);
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
