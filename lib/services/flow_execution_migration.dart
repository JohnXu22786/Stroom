import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'storage_service.dart';

/// Normalize execution histories during the existing startup migration and
/// restart flow. Original configurations cannot be reconstructed from history.
class FlowExecutionMigration {
  static Future<void> migrate() async {
    if (kIsWeb || WebFileStore.isTestMode) return;
    final directory = await AppStorage.directory;
    final file = File('$directory/task_flows/executions.json');
    if (!await file.exists()) return;
    final encoded = await file.readAsString();
    if (encoded.isEmpty) return;
    final executions = jsonDecode(encoded) as List;
    for (final execution in executions.whereType<Map>()) {
      execution.putIfAbsent('batchIndex', () => 0);
      for (final step
          in (execution['subTasks'] as List? ?? []).whereType<Map>()) {
        if (step.containsKey('outcome')) continue;
        final pending =
            (step['subTaskId'] as String? ?? '').startsWith('pending_');
        if (pending && ['failed', 'completed'].contains(execution['status'])) {
          step['outcome'] = 'skipped';
          step['status'] = 'paused';
        } else {
          step['outcome'] = switch (step['status']) {
            'waiting' => 'pending',
            'completed' => 'succeeded',
            'failed' => 'failed',
            'paused' => 'paused',
            _ => 'running',
          };
        }
      }
    }
    final updated = jsonEncode(executions);
    if (updated == encoded) return;
    await AtomicFile.writeString(file, updated);
    if (await file.readAsString() != updated) throw StateError('任务流执行记录迁移校验失败');
  }
}
