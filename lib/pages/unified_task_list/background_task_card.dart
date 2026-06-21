import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import 'task_utils.dart';

// =============================================================================
// 后台任务卡片（OCR / ASR / 音频分离）
// 设计参考 CatCatchTaskCard：可展开/折叠，圆形进度条，步骤信息
// =============================================================================

class BackgroundTaskCard extends ConsumerStatefulWidget {
  final BackgroundTask task;
  final bool isUnread;

  const BackgroundTaskCard({
    super.key,
    required this.task,
    this.isUnread = false,
  });

  @override
  ConsumerState<BackgroundTaskCard> createState() => _BackgroundTaskCardState();
}

class _BackgroundTaskCardState extends ConsumerState<BackgroundTaskCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.task.status == TaskStatus.running;
  }

  @override
  void didUpdateWidget(covariant BackgroundTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.status == TaskStatus.running &&
        oldWidget.task.status != TaskStatus.running) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final colorScheme = Theme.of(context).colorScheme;

    final statusColor = _statusColor(task.status);
    final statusIcon = _statusIcon(task.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (widget.isUnread)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  _buildStatusIcon(task.status, colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _taskTypeBadge(task.type, colorScheme),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStatusChip(task.status),
                            const SizedBox(width: 8),
                            Text(
                              '${formatRelativeTime(task.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Circular progress or completion icon
                  if (task.status == TaskStatus.running)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: task.progress / 100.0,
                            strokeWidth: 3,
                            color: Colors.blue,
                            backgroundColor: colorScheme.outlineVariant,
                          ),
                          Text(
                            '${task.progress}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(statusIcon, color: statusColor, size: 28),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildExpandedContent(task, colorScheme),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BackgroundTask task, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type and time info
        _buildInfoRow(cs, Icons.category_outlined, '任务类型', task.type.label),
        const SizedBox(height: 6),
        _buildInfoRow(
          cs,
          Icons.access_time,
          '创建时间',
          formatRelativeTime(task.createdAt),
        ),
        if (task.completedAt != null) ...[
          const SizedBox(height: 6),
          _buildInfoRow(
            cs,
            Icons.check_circle_outline,
            '完成时间',
            formatRelativeTime(task.completedAt!),
          ),
        ],

        // Progress bar for running tasks
        if (task.status == TaskStatus.running) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress / 100.0,
              minHeight: 6,
              backgroundColor: cs.outlineVariant,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '进度 ${task.progress}%',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],

        // Error message for failed tasks
        if (task.status == TaskStatus.failed && task.error != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '错误详情',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Action buttons
        const SizedBox(height: 12),
        _buildActionButtons(task, cs),
      ],
    );
  }

  Widget _buildInfoRow(
    ColorScheme cs,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
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
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BackgroundTask task, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () {
            ref.read(backgroundTasksProvider.notifier).removeTask(task.id);
          },
          icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
          label: Text('删除', style: TextStyle(fontSize: 13, color: cs.error)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Helper widgets
  // ===========================================================================

  Widget _taskTypeBadge(BackgroundTaskType type, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _taskTypeColor(type).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_taskTypeIcon(type), size: 12, color: _taskTypeColor(type)),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _taskTypeColor(type),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
      case TaskStatus.paused:
        return Colors.orange;
    }
  }

  static IconData _statusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return Icons.sync;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.error;
      case TaskStatus.paused:
        return Icons.pause_circle;
    }
  }

  /// Returns a spinning animation widget for running tasks,
  /// or a static icon for other states.
  Widget _buildStatusIcon(TaskStatus status, ColorScheme colorScheme) {
    if (status == TaskStatus.running) {
      return _SpinningIcon(
        icon: Icons.sync,
        color: _statusColor(status),
        size: 24,
      );
    }
    return Icon(_statusIcon(status), color: _statusColor(status), size: 24);
  }

  static Widget _buildStatusChip(TaskStatus status) {
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
    }
  }

  static IconData _taskTypeIcon(BackgroundTaskType type) {
    switch (type) {
      case BackgroundTaskType.ocr:
        return Icons.text_snippet;
      case BackgroundTaskType.asr:
        return Icons.multitrack_audio;
      case BackgroundTaskType.audioSeparation:
        return Icons.music_note;
    }
  }

  static Color _taskTypeColor(BackgroundTaskType type) {
    switch (type) {
      case BackgroundTaskType.ocr:
        return Colors.teal;
      case BackgroundTaskType.asr:
        return Colors.deepPurple;
      case BackgroundTaskType.audioSeparation:
        return Colors.indigo;
    }
  }
}

/// An icon that spins continuously, used to indicate a running task.
class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _SpinningIcon({
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.1415927,
          child: child,
        );
      },
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
