import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';

import '../models/task_flow_definition.dart';
import '../models/io_type.dart';
import 'persistable_notifier.dart';

// ============================================================================
// Provider
// ============================================================================

/// Provider for the list of task flow definitions.
///
/// Flows are ordered by [updatedAt] descending (newest first).
final taskFlowListProvider =
    StateNotifierProvider<TaskFlowNotifier, List<TaskFlowDefinition>>(
      (ref) => TaskFlowNotifier(),
    );

// ============================================================================
// Notifier
// ============================================================================

class TaskFlowNotifier extends StateNotifier<List<TaskFlowDefinition>>
    with PersistableNotifier<List<TaskFlowDefinition>> {
  TaskFlowNotifier() : super([]);

  // ========================================================================
  // PersistableNotifier contract
  // ========================================================================

  @override
  String get persistenceFileName => 'flows.json';

  @override
  List<TaskFlowDefinition> fromJsonList(List<dynamic> json) {
    final result = <TaskFlowDefinition>[];
    for (final item in json) {
      try {
        result.add(
          TaskFlowDefinition.fromMap(Map<String, dynamic>.from(item as Map)),
        );
      } catch (e) {
        debugPrint('WARNING: Skipping corrupt TaskFlowDefinition: $e');
      }
    }
    return result;
  }

  @override
  List<dynamic> toJsonList(List<TaskFlowDefinition> state) {
    return state.map((f) => f.toMap()).toList();
  }

  // ========================================================================
  // CRUD Operations
  // ========================================================================

  /// Add a new flow and return its id.
  String addFlow({
    String name = '',
    String description = '',
    IOType? inputType,
    List<TaskFlowBlock>? blocks,
  }) {
    final flow = TaskFlowDefinition(
      name: name,
      description: description,
      inputType: inputType ?? IOType.text,
      blocks: blocks ?? [],
    );
    state = [flow, ...state];
    persist();
    return flow.id;
  }

  /// Update an existing flow's metadata and/or blocks.
  /// Does nothing if [id] is not found.
  void updateFlow(
    String id, {
    String? name,
    String? description,
    IOType? inputType,
    List<TaskFlowBlock>? blocks,
  }) {
    final index = state.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final current = state[index];
    final updated = current.copyWith(
      name: name,
      description: description,
      inputType: inputType,
      blocks: blocks,
      updatedAt: DateTime.now(),
    );

    final newState = [...state];
    newState[index] = updated;
    // Re-sort: move updated item to front
    newState.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = newState;
    persist();
  }

  /// Remove a flow by id. Does nothing if not found.
  void removeFlow(String id) {
    state = state.where((f) => f.id != id).toList();
    persist();
  }

  /// Duplicate a flow (creates a copy with a new id).
  /// Returns the new id, or null if the original wasn't found.
  String? duplicateFlow(String id) {
    final index = state.indexWhere((f) => f.id == id);
    if (index == -1) return null;

    final original = state[index];
    final copy = original.copyWithNewId();
    final newCopy = copy.copyWith(
      name: '${original.name} (副本)',
      updatedAt: DateTime.now(),
    );
    state = [newCopy, ...state];
    persist();
    return newCopy.id;
  }

  /// Get a flow by id.
  TaskFlowDefinition? getFlow(String id) {
    try {
      return state.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  // ========================================================================
  // Persistence
  // ========================================================================

  /// Restore persisted flows on startup.
  Future<void> restoreFromPersistence() async {
    await restore();
    if (state.isNotEmpty) {
      state = [...state]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    await persist();
  }
}
