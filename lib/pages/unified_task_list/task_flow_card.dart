import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../../task_flow/models/task_flow_execution.dart';
import '../../task_flow/providers/task_flow_execution_provider.dart';
import 'background_task_card.dart';
import 'catcatch_task_card.dart';
import 'synthesis_task_card.dart';

/// Card for a task flow execution in the unified task list.
/// Two-level expand:
///   Level 1: Flow header → expands to show sub-tasks (one per block)
///   Level 2: Sub-task tile → expands to show the underlying task's card
///            (CatCatchTaskCard / BackgroundTaskCard / SynthesisTaskCard)
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
  final Set<String> _expandedSubTasks = {};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exec = widget.execution;

    // Sync sub-task statuses with underlying real tasks.
    // When the execution page is disposed mid-flow, the polling loop stops
    // but the CatCatch/Background tasks continue running. This keeps the
    // sub-task statuses in sync so auto-completion works.
    _syncSubTaskStatuses();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
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
            // === Level 1: Flow summary (always visible) ===
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Status icon
                    _statusIcon(exec.status, cs),
                    const SizedBox(width: 10),
                    // Flow name + count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exec.flowName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '任务流 · ${exec.subTasks.length} 个步骤',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expand icon
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    // Delete button
                    GestureDetector(
                      onLongPress: () => _confirmDelete(context, cs),
                      child: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: cs.error),
                        onPressed: () => _confirmDelete(context, cs),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: '删除',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === Level 2: Sub-tasks (when flow is expanded) ===
            if (_expanded)
              ...exec.subTasks
                  .map((subTask) => _buildSubTaskSection(subTask, cs)),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(FlowExecutionStatus status, ColorScheme cs) {
    switch (status) {
      case FlowExecutionStatus.running:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: cs.primary,
          ),
        );
      case FlowExecutionStatus.completed:
        return Icon(Icons.check_circle, size: 20, color: Colors.green);
      case FlowExecutionStatus.failed:
        return Icon(Icons.error, size: 20, color: cs.error);
    }
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

  /// Sync sub-task statuses with the underlying real tasks.
  ///
  /// When the execution page is disposed mid-flow (user navigated away),
  /// the CatCatch/Background/Synthesis tasks continue running in their
  /// respective providers. This method keeps the flow execution's sub-task
  /// statuses in sync, which triggers [updateSubTaskStatus] auto-completion.
  void _syncSubTaskStatuses() {
    final exec = widget.execution;
    if (exec.status != FlowExecutionStatus.running) return;

    final execNotifier = ref.read(taskFlowExecutionsProvider.notifier);
    final catcatchTasks = ref.read(catcatchTasksProvider);
    final bgTasks = ref.read(backgroundTasksProvider);
    final synthTasks = ref.read(taskListProvider);

    for (final st in exec.subTasks) {
      // Skip already-terminal sub-tasks (no need to update)
      if (st.status == TaskStatus.completed || st.status == TaskStatus.failed) {
        continue;
      }

      // Check CatCatch tasks (uses a different TaskStatus enum)
      final ccTask =
          catcatchTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (ccTask != null) {
        final newStatus = _convertCatCatchStatus(ccTask.status);
        if (newStatus != st.status) {
          execNotifier.updateSubTaskStatus(exec.id, st.id, newStatus);
        }
        continue;
      }

      // Check Background tasks
      final bgTask = bgTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (bgTask != null && bgTask.status != st.status) {
        execNotifier.updateSubTaskStatus(exec.id, st.id, bgTask.status);
        continue;
      }

      // Check Synthesis tasks
      final synthTask =
          synthTasks.where((t) => t.id == st.subTaskId).firstOrNull;
      if (synthTask != null && synthTask.status != st.status) {
        execNotifier.updateSubTaskStatus(exec.id, st.id, synthTask.status);
      }
    }
  }

  /// Convert CatCatch's [TaskStatus] enum to the shared [TaskStatus] enum.
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

  /// Build a sub-task row that can expand to show the underlying task card.
  Widget _buildSubTaskSection(FlowSubTask subTask, ColorScheme cs) {
    final isExpanded = _expandedSubTasks.contains(subTask.id);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.3),
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSubTasks.remove(subTask.id);
                } else {
                  _expandedSubTasks.add(subTask.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  // Sub-task status
                  _subTaskIcon(subTask.status, cs),
                  const SizedBox(width: 10),
                  // Sub-task label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subTask.blockLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          _statusText(subTask.status),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _subTaskColor(subTask.status, cs)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _shortStatusText(subTask.status),
                      style: TextStyle(
                        fontSize: 10,
                        color: _subTaskColor(subTask.status, cs),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Expand arrow
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        // === Level 3: Nested task detail card (when sub-task is expanded) ===
        if (isExpanded) _buildSubTaskDetail(subTask, cs),
      ],
    );
  }

  /// Build the underlying task's detail card inside an expanded sub-task.
  Widget _buildSubTaskDetail(FlowSubTask subTask, ColorScheme cs) {
    switch (subTask.subTaskType) {
      case 'catcatch':
        return _buildCatCatchDetail(subTask, cs);
      case 'background':
        return _buildBackgroundDetail(subTask, cs);
      case 'synthesis':
        return _buildSynthesisDetail(subTask, cs);
      default:
        return _buildGenericDetail(subTask, cs);
    }
  }

  /// Look up and render the real CatCatch task card.
  Widget _buildCatCatchDetail(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(catcatchTasksProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CatCatchTaskCard(
          key: ValueKey('catcatch_${task.id}'),
          task: task,
          isUnread: false,
        ),
      );
    }

    return _buildGenericDetail(subTask, cs);
  }

  /// Look up and render the real Background task card.
  Widget _buildBackgroundDetail(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(backgroundTasksProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BackgroundTaskCard(
          key: ValueKey('bg_${task.id}'),
          task: task,
          isUnread: false,
        ),
      );
    }

    return _buildGenericDetail(subTask, cs);
  }

  /// Look up and render the real Synthesis task card.
  Widget _buildSynthesisDetail(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(taskListProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SynthesisTaskCard(
          key: ValueKey('synth_${task.id}'),
          task: task,
          isUnread: false,
        ),
      );
    }

    return _buildGenericDetail(subTask, cs);
  }

  /// Fallback generic detail view when the real task is not found.
  Widget _buildGenericDetail(FlowSubTask subTask, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _subTaskIcon(subTask.status, cs),
                const SizedBox(width: 8),
                Text(
                  '${subTask.blockLabel} · ${_statusText(subTask.status)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '类型: ${subTask.subTaskType}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (subTask.subTaskId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '任务ID: ${subTask.subTaskId}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Sub-task status helpers
  // =========================================================================

  Widget _subTaskIcon(TaskStatus status, ColorScheme cs) {
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

  Color _subTaskColor(TaskStatus status, ColorScheme cs) {
    switch (status) {
      case TaskStatus.running:
        return cs.primary;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return cs.error;
      case TaskStatus.paused:
        return Colors.orange;
      case TaskStatus.waiting:
        return cs.onSurfaceVariant;
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

  String _shortStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return '运行中';
      case TaskStatus.completed:
        return '完成';
      case TaskStatus.failed:
        return '失败';
      case TaskStatus.paused:
        return '暂停';
      case TaskStatus.waiting:
        return '等待';
    }
  }
}
