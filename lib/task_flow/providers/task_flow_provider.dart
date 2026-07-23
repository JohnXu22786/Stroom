import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../models/task_flow_definition.dart';
import '../models/io_type.dart';
import '../../services/storage_service.dart';

// ============================================================================
// Provider
// ============================================================================

/// Provider for the list of task flow definitions.
///
/// Flows are ordered by [updatedAt] descending (newest first).
final taskFlowListProvider =
    StateNotifierProvider<TaskFlowNotifier, List<TaskFlowDefinition>>(
        (ref) => TaskFlowNotifier());

// ============================================================================
// Notifier
// ============================================================================

class TaskFlowNotifier extends StateNotifier<List<TaskFlowDefinition>> {
  TaskFlowNotifier() : super([]);

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
    _persist();
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
    _persist();
  }

  /// Remove a flow by id. Does nothing if not found.
  void removeFlow(String id) {
    state = state.where((f) => f.id != id).toList();
    _persist();
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
    _persist();
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

  Future<void> _persist() async {
    try {
      final file = await _flowsFile();
      final data = state.map((f) => f.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[TaskFlowNotifier] Failed to persist flows: $e');
    }
  }

  Future<List<TaskFlowDefinition>> _loadPersistedFlows() async {
    try {
      final file = await _flowsFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map((m) =>
              TaskFlowDefinition.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('[TaskFlowNotifier] Failed to load persisted flows: $e');
      return [];
    }
  }

  Future<File> _flowsFile() async {
    final dirPath = await AppStorage.directory;
    final taskFlowDir = Directory(p.join(dirPath, 'task_flows'));
    try {
      if (!await taskFlowDir.exists()) {
        await taskFlowDir.create(recursive: true);
      }
    } catch (_) {}
    return File(p.join(taskFlowDir.path, 'flows.json'));
  }

  /// Restore persisted flows on startup.
  Future<void> restoreFromPersistence() async {
    final flows = await _loadPersistedFlows();
    if (flows.isEmpty) return;
    // Merge with existing state (in case flows were added before restore)
    state = [
      for (final f in flows)
        if (!state.any((s) => s.id == f.id)) f,
      ...state,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    debugPrint(
        '[TaskFlowNotifier] Restored ${flows.length} flows from persistence');
  }

  /// Persist current state to storage (public for manual save).
  Future<void> persist() => _persist();
}
