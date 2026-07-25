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
///
/// Layout:
///   Header: "任务流" tag, flow name, progress, status icon
///   Expanded: Direct nested real task cards (CatCatch / Background / Synthesis)
///
/// No more _syncSubTaskStatuses — the execution service updates sub-task
/// statuses directly via the provider. This card just watches and renders.
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
          // ── Header (always visible) ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _flowStatusIcon(exec.subTasks, cs),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                        Text(
                          _progressText(exec.subTasks, cs),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: nested sub-task cards ──
          if (_expanded) ...[
            for (int i = 0; i < exec.subTasks.length; i++)
              _buildSubTaskCard(exec.subTasks[i], cs),
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

  // ===========================================================================
  // Flow status icon — computed from sub-task statuses
  // ===========================================================================

  Widget _flowStatusIcon(List<FlowSubTask> subTasks, ColorScheme cs) {
    if (subTasks.isEmpty) {
      return Icon(Icons.hourglass_empty, size: 20, color: cs.onSurfaceVariant);
    }

    final anyFailed = subTasks.any((s) => s.status == TaskStatus.failed);
    final anyActive = subTasks.any(
        (s) => s.status == TaskStatus.running || s.status == TaskStatus.paused);
    final allWaiting = subTasks.every((s) => s.status == TaskStatus.waiting);
    final allCompleted =
        subTasks.every((s) => s.status == TaskStatus.completed);

    if (anyFailed) return Icon(Icons.error, size: 20, color: cs.error);
    if (anyActive) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: cs.primary,
        ),
      );
    }
    if (allWaiting) {
      return Icon(Icons.hourglass_empty, size: 20, color: cs.onSurfaceVariant);
    }
    if (allCompleted) {
      return Icon(Icons.check_circle, size: 20, color: Colors.green);
    }
    return Icon(Icons.hourglass_empty, size: 20, color: cs.onSurfaceVariant);
  }

  // ===========================================================================
  // Progress text
  // ===========================================================================

  String _progressText(List<FlowSubTask> subTasks, ColorScheme cs) {
    if (subTasks.isEmpty) return '0 个步骤';
    final total = subTasks.length;
    final done =
        subTasks.where((st) => st.status == TaskStatus.completed).length;
    final failed =
        subTasks.where((st) => st.status == TaskStatus.failed).length;
    if (failed > 0) return '$done/$total 已完成 · $failed 个失败';
    return '$done/$total 已完成';
  }

  // ===========================================================================
  // Delete
  // ===========================================================================

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

  // ===========================================================================
  // Sub-task → real task card mapping
  // ===========================================================================

  Widget _buildSubTaskCard(FlowSubTask subTask, ColorScheme cs) {
    switch (subTask.subTaskType) {
      case 'catcatch':
        return _buildCatCatchCard(subTask, cs);
      case 'background':
        return _buildBackgroundCard(subTask, cs);
      case 'synthesis':
        return _buildSynthesisCard(subTask, cs);
      default:
        return _buildFallbackCard(subTask, cs);
    }
  }

  Widget _buildCatCatchCard(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(catcatchTasksProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return CatCatchTaskCard(
        key: ValueKey('catcatch_${task.id}'),
        task: task,
        isUnread: false,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildBackgroundCard(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(backgroundTasksProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return BackgroundTaskCard(
        key: ValueKey('bg_${task.id}'),
        task: task,
        isUnread: false,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildSynthesisCard(FlowSubTask subTask, ColorScheme cs) {
    final tasks = ref.watch(taskListProvider);
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;

    if (task != null) {
      return SynthesisTaskCard(
        key: ValueKey('synth_${task.id}'),
        task: task,
        isUnread: false,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildFallbackCard(FlowSubTask subTask, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            _statusIcon(subTask.status, cs),
            const SizedBox(width: 8),
            Text(
              subTask.blockLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              _statusText(subTask.status),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Status helpers (for fallback card)
  // ===========================================================================

  Widget _statusIcon(TaskStatus status, ColorScheme cs) {
    switch (status) {
      case TaskStatus.running:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
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
