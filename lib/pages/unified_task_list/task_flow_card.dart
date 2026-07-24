import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../../task_flow/models/task_flow_execution.dart';
import '../../task_flow/providers/task_flow_execution_provider.dart';

/// Card for a task flow execution in the unified task list.
///
/// Layout:
///   Level 0: Flow header — "任务流" tag, flow name, progress, status icon
///   Level 1 (expanded): Unified sub-task rows showing status + block label
class TaskFlowCard extends ConsumerStatefulWidget {
  final TaskFlowExecution execution;
  final bool isUnread;

  const TaskFlowCard({
    super.key,
    required this.execution,
    this.isUnread = false,
  });

  @override
  ConsumerState<TaskFlowCard> createState() => _TaskFlowCardState();
}

class _TaskFlowCardState extends ConsumerState<TaskFlowCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exec = widget.execution;

    // Sync sub-task statuses with underlying real tasks
    _syncSubTaskStatuses();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isUnread ? cs.primary : cs.outlineVariant,
          width: widget.isUnread ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // === Level 0: Flow summary (always visible) ===
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Status icon (based on sub-task states, not exec.status)
                  _computedStatusIcon(cs),
                  const SizedBox(width: 10),
                  // Flow name + tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // "任务流" tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '任务流',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Flow name
                            Flexible(
                              child: Text(
                                exec.flowName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Progress line
                        Text(
                          _progressText(exec),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand arrow
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // === Level 1: Direct sub-task cards (when flow is expanded) ===
          if (_expanded) ...[
            for (int i = 0; i < exec.subTasks.length; i++)
              _buildSubTaskCard(exec.subTasks[i], cs),
            // Delete button at the bottom of expanded view
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context, cs),
                  icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                  label: Text('删除',
                      style: TextStyle(fontSize: 13, color: cs.error)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the status icon based on sub-task states.
  Widget _computedStatusIcon(ColorScheme cs) {
    final exec = widget.execution;
    final anyActive = exec.subTasks.any((st) =>
        st.status == TaskStatus.running ||
        st.status == TaskStatus.waiting ||
        st.status == TaskStatus.paused);
    final anyFailed = exec.subTasks.any((st) => st.status == TaskStatus.failed);
    final allCompleted =
        exec.subTasks.every((st) => st.status == TaskStatus.completed);

    if (exec.subTasks.isEmpty || anyActive) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: cs.primary,
        ),
      );
    }
    if (allCompleted) {
      return Icon(Icons.check_circle, size: 20, color: Colors.green);
    }
    if (anyFailed) {
      return Icon(Icons.error, size: 20, color: cs.error);
    }
    return Icon(Icons.hourglass_empty, size: 20, color: cs.onSurfaceVariant);
  }

  /// Progress text: "2/3 已完成" or "2 个步骤"
  String _progressText(TaskFlowExecution exec) {
    final total = exec.subTasks.length;
    if (total == 0) return '0 个步骤';
    final done =
        exec.subTasks.where((st) => st.status == TaskStatus.completed).length;
    final failed =
        exec.subTasks.where((st) => st.status == TaskStatus.failed).length;
    if (failed > 0) {
      return '$done/$total 已完成 · $failed 个失败';
    }
    return '$done/$total 已完成';
  }

  void _confirmDelete(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务流记录'),
        content: Text('确定删除「${widget.execution.flowName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(taskFlowExecutionsProvider.notifier)
                  .removeExecution(widget.execution.id);
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Sub-task → unified row (consistent width for all block types)
  // =========================================================================

  /// Build a unified row for a single sub-task.
  ///
  /// Uses a consistent layout for all block types — no nested real task
  /// cards (which have incompatible built-in margins).  The row shows
  /// status icon, block label, and status text.
  Widget _buildSubTaskCard(FlowSubTask subTask, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            _statusIcon(subTask.status, cs),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subTask.blockLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _statusText(subTask.status),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Status sync between flow sub-tasks and real provider tasks
  // =========================================================================

  /// Sync sub-task statuses with the underlying real tasks.
  ///
  /// ALWAYS syncs, even when the execution is not "running". This allows
  /// the flow to reflect the current state of its sub-tasks (e.g., if a
  /// CatCatch task was retried and succeeded after the flow failed).
  void _syncSubTaskStatuses() {
    final exec = widget.execution;

    final execNotifier = ref.read(taskFlowExecutionsProvider.notifier);
    final catcatchTasks = ref.read(catcatchTasksProvider);
    final bgTasks = ref.read(backgroundTasksProvider);
    final synthTasks = ref.read(taskListProvider);

    for (final st in exec.subTasks) {
      final ccTask =
          catcatchTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (ccTask != null) {
        final newStatus = _convertCatCatchStatus(ccTask.status);
        if (newStatus != st.status) {
          execNotifier.updateSubTaskStatus(exec.id, st.id, newStatus);
        }
        continue;
      }

      final bgTask = bgTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (bgTask != null && bgTask.status != st.status) {
        execNotifier.updateSubTaskStatus(exec.id, st.id, bgTask.status);
        continue;
      }

      final synthTask =
          synthTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (synthTask != null && synthTask.status != st.status) {
        execNotifier.updateSubTaskStatus(exec.id, st.id, synthTask.status);
      }
    }
  }

  TaskStatus _convertCatCatchStatus(catcatch.TaskStatus status) {
    switch (status) {
      case catcatch.TaskStatus.waiting:
        return TaskStatus.waiting;
      case catcatch.TaskStatus.running:
        return TaskStatus.running;
      case catcatch.TaskStatus.completed:
        return TaskStatus.completed;
      case catcatch.TaskStatus.failed:
        return TaskStatus.failed;
      case catcatch.TaskStatus.paused:
        return TaskStatus.paused;
    }
  }

  // =========================================================================
  // Status helpers
  // =========================================================================

  Widget _statusIcon(TaskStatus status, ColorScheme cs) {
    switch (status) {
      case TaskStatus.running:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.primary,
          ),
        );
      case TaskStatus.completed:
        return Icon(Icons.check_circle, size: 16, color: Colors.green);
      case TaskStatus.failed:
        return Icon(Icons.error, size: 16, color: cs.error);
      case TaskStatus.paused:
        return Icon(Icons.pause_circle, size: 16, color: Colors.orange);
      case TaskStatus.waiting:
        return Icon(Icons.hourglass_empty,
            size: 16, color: cs.onSurfaceVariant);
    }
  }

  String _statusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return '执行中...';
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
}
