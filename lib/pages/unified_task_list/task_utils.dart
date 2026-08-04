import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../task_flow/models/task_flow_execution.dart';
import '../../task_flow/services/task_flow_execution_service.dart';
import '../../task_flow/services/task_flow_scheduler.dart';

// =============================================================================
// 工具函数
// =============================================================================

String formatSize(int? bytes) {
  if (bytes == null) return '未知大小';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String truncateUrl(String url, {int maxLen = 40}) {
  if (url.length <= maxLen) return url;
  return '${url.substring(0, maxLen ~/ 2)}...${url.substring(url.length - maxLen ~/ 2)}';
}

String formatDurationSimple(String duration) {
  final sec = parseDurationToSeconds(duration);
  if (sec == null) return duration;
  if (sec < 60) return '${sec.round()}秒';
  if (sec < 3600) return '${(sec ~/ 60)}分${(sec % 60).round()}秒';
  return '${(sec ~/ 3600)}时${((sec % 3600) ~/ 60)}分';
}

double? parseDurationToSeconds(String duration) {
  final parts = duration.split(':');
  if (parts.length == 3) {
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  if (parts.length == 2) {
    final m = double.tryParse(parts[0]) ?? 0;
    final s = double.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
  return double.tryParse(duration);
}

String formatRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String getStatusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.running:
      return '进行中';
    case TaskStatus.completed:
      return '已完成';
    case TaskStatus.failed:
      return '失败';
    case TaskStatus.paused:
      return '已暂停';
    case TaskStatus.waiting:
      return '等待中';
  }
}

Widget buildInfoRow(ColorScheme cs, IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Text(
        '$label: ',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(fontSize: 12, color: cs.onSurface),
        ),
      ),
    ],
  );
}

Widget buildStatusChip(TaskStatus status) {
  switch (status) {
    case TaskStatus.running:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '进行中',
          style: TextStyle(fontSize: 11, color: Colors.blue),
        ),
      );
    case TaskStatus.completed:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '已完成',
          style: TextStyle(fontSize: 11, color: Colors.green),
        ),
      );
    case TaskStatus.failed:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '失败',
          style: TextStyle(fontSize: 11, color: Colors.red),
        ),
      );
    case TaskStatus.paused:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '已暂停',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        ),
      );
    case TaskStatus.waiting:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '等待中',
          style: TextStyle(fontSize: 11, color: Colors.purple),
        ),
      );
  }
}

// =============================================================================
// 步骤图标
// =============================================================================

Widget stepIcon(catcatch.StepStatus step) {
  if (step.skipped) {
    return const Icon(Icons.skip_next, color: Colors.orange, size: 20);
  }
  if (step.completed) {
    return const Icon(Icons.check_circle, color: Colors.green, size: 20);
  }
  if (step.running) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (step.failed) {
    return const Icon(Icons.cancel, color: Colors.red, size: 20);
  }
  return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
}

// =============================================================================
// UnifiedTaskItem 数据模型
// =============================================================================

/// Whether deleting [execution] should cancel its in-flight request and
/// scheduler slot. Cancel tokens are keyed per execution now (concurrent
/// flows), so only deleting the RUNNING execution cancels anything — a
/// completed/failed flow's deletion must not touch other flows.
@visibleForTesting
bool shouldCancelActiveRequest(TaskFlowExecution execution) =>
    execution.status == FlowExecutionStatus.running;

/// Remove the real tasks behind a flow execution's sub-tasks from their
/// providers, so they don't resurface as orphaned standalone cards when
/// the execution record is removed (card delete and AppBar 清除 actions).
///
/// This genuinely cancels the underlying work where possible: catcatch and
/// TTS `removeTask` cancel their engine/HTTP tokens; chat streams are
/// cancelled by conversation id; the in-flight ASR/OCR request of the
/// currently executing block is cancelled via the execution service.
void removeFlowSubTaskTasks(WidgetRef ref, TaskFlowExecution execution) {
  removeFlowSubTaskTasksCore(
    execution,
    removeCatCatch: (id) =>
        ref.read(catcatchTasksProvider.notifier).removeTask(id),
    removeSynthesis: (id) => ref.read(taskListProvider.notifier).removeTask(id),
    removeBackground: (id) =>
        ref.read(backgroundTasksProvider.notifier).removeTask(id),
    cancelChat: (convId) => ref.read(chatStreamManagerProvider).cancel(convId),
    cancelActiveRequest: shouldCancelActiveRequest(execution)
        ? () {
            ref
                .read(taskFlowExecutionServiceProvider)
                .cancelActiveRequest(execution.id);
            // Also release/cancel the flow's scheduler slot so a queued
            // flow does not sit in the wait queue after deletion.
            ref.read(taskFlowSchedulerProvider).cancel(execution.id);
          }
        : null,
  );
}

/// Testable core of [removeFlowSubTaskTasks] — all provider access is
/// injected as callbacks.
@visibleForTesting
void removeFlowSubTaskTasksCore(
  TaskFlowExecution execution, {
  required void Function(String id) removeCatCatch,
  required void Function(String id) removeSynthesis,
  required void Function(String id) removeBackground,
  required void Function(String convId) cancelChat,
  void Function()? cancelActiveRequest,
}) {
  for (final st in execution.subTasks) {
    if (st.subTaskId.startsWith('pending_')) continue;
    switch (st.subTaskType) {
      case 'catcatch':
        removeCatCatch(st.subTaskId);
      case 'synthesis':
        removeSynthesis(st.subTaskId);
      default: // 'background' (including legacy 'chat' records)
        if (st.subTaskId.startsWith('chat_')) {
          // Cancel the live chat stream (convId is derived from the
          // FlowSubTask id, matching chat_executor).
          cancelChat('flow_${st.id}');
        }
        removeBackground(st.subTaskId);
    }
  }
  // Abort the in-flight ASR/OCR request of the currently executing block
  // so the flow's run lock frees promptly (idempotent when idle).
  cancelActiveRequest?.call();
}

class UnifiedTaskItem {
  final String id;
  final DateTime createdAt;
  final bool isCatCatch;
  final bool isBackground;
  final bool isTaskFlow;
  final catcatch.CatCatchTask? catCatchTask;
  final SynthesisTask? synthesisTask;
  final BackgroundTask? backgroundTask;
  final TaskFlowExecution? taskFlowExecution;

  const UnifiedTaskItem({
    required this.id,
    required this.createdAt,
    this.isCatCatch = false,
    this.isBackground = false,
    this.isTaskFlow = false,
    this.catCatchTask,
    this.synthesisTask,
    this.backgroundTask,
    this.taskFlowExecution,
  });
}
