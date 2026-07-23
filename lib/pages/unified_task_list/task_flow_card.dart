import 'package:flutter/material.dart';
import '../../task_flow/models/task_flow_execution.dart';
import '../../providers/task_provider_shared.dart';

/// Card for a task flow execution in the unified task list.
/// Two-level expand:
///   Level 1: Flow → shows sub-tasks (one per block)
///   Level 2: Sub-task → shows original task progress (delegated)
class TaskFlowCard extends StatefulWidget {
  final TaskFlowExecution execution;
  final bool isUnread;

  const TaskFlowCard({
    super.key,
    required this.execution,
    this.isUnread = false,
  });

  @override
  State<TaskFlowCard> createState() => _TaskFlowCardState();
}

class _TaskFlowCardState extends State<TaskFlowCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exec = widget.execution;

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
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // === Level 2: Sub-tasks (when expanded) ===
            if (_expanded)
              ...exec.subTasks.map((subTask) =>
                  _buildSubTaskTile(subTask, cs)),
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

  Widget _buildSubTaskTile(FlowSubTask subTask, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.3),
        ),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _subTaskColor(subTask.status, cs).withValues(alpha: 0.12),
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
        ],
      ),
    );
  }

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
        return Icon(Icons.hourglass_empty, size: 16, color: cs.onSurfaceVariant);
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
