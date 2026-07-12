import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import '../chat/dialogs/error_detail_dialog.dart';
import '../asr_page.dart';
import '../ocr_page.dart';
import '../audio_separation_page.dart';
import 'task_utils.dart';

// =============================================================================
// 后台任务卡片（OCR / ASR / 音频分离）
// 默认折叠，只显示标题栏和类型等基本信息。
// 点击卡片可展开查看步骤详情、错误信息、操作按钮。
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRawData =
        widget.task.rawRequest != null || widget.task.rawResponse != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible) ──
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
              bottom: Radius.circular(0),
            ),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
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
                  _buildStatusIcon(widget.task.status, colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _taskTypeBadge(widget.task.type, colorScheme),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.task.title,
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
                            _buildStatusChip(widget.task.status),
                            const SizedBox(width: 8),
                            Text(
                              '${formatRelativeTime(widget.task.createdAt)}',
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
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail section ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, indent: 12, endIndent: 12),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildDetailContent(
                      widget.task, colorScheme, ref, hasRawData),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(
    BackgroundTask task,
    ColorScheme cs,
    WidgetRef ref,
    bool hasRawData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type and time info
        _buildInfoRow(cs, Icons.category_outlined, '任务类型', task.type.label),
        const SizedBox(height: 4),
        _buildInfoRow(
          cs,
          Icons.access_time,
          '创建时间',
          formatRelativeTime(task.createdAt),
        ),
        if (task.completedAt != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(
            cs,
            Icons.check_circle_outline,
            '完成时间',
            formatRelativeTime(task.completedAt!),
          ),
        ],

        // Step chain timeline — always visible in expanded mode
        const SizedBox(height: 10),
        _buildStepTimeline(task, cs),

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
                    const Spacer(),
                    if (hasRawData)
                      TextButton.icon(
                        onPressed: () => _showErrorDetailDialog(context, task),
                        icon: const Icon(Icons.preview, size: 14),
                        label: const Text(
                          '查看错误详情',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        _buildActionButtons(task, cs, ref),
      ],
    );
  }

  void _showErrorDetailDialog(BuildContext context, BackgroundTask task) {
    showDataDetailDialog(
      context: context,
      rawRequest: task.rawRequest,
      rawResponse: task.rawResponse,
    );
  }

  Widget _buildStepTimeline(BackgroundTask task, ColorScheme colorScheme) {
    final steps = task.steps;

    if (steps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '等待开始...',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '执行步骤',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final isLast = i == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      _stepIconWidget(step, colorScheme),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: _stepLineColor(step, colorScheme),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: step.completed
                                ? Colors.green.shade700
                                : step.skipped
                                    ? Colors.orange.shade700
                                    : step.running
                                        ? colorScheme.primary
                                        : step.failed
                                            ? Colors.red.shade700
                                            : colorScheme.onSurface,
                          ),
                        ),
                        // Show step error detail directly (no folding)
                        if (step.failed && step.error != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            step.error!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _stepIconWidget(BgTaskStep step, ColorScheme colorScheme) {
    if (step.skipped) {
      return const Icon(Icons.skip_next, color: Colors.orange, size: 16);
    }
    if (step.completed) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    }
    if (step.running) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    }
    if (step.failed) {
      return const Icon(Icons.cancel, color: Colors.red, size: 16);
    }
    return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 16);
  }

  Color _stepLineColor(BgTaskStep step, ColorScheme colorScheme) {
    if (step.completed) return Colors.green.shade300;
    if (step.skipped) return Colors.orange.shade300;
    if (step.running || step.failed) return colorScheme.primary;
    return colorScheme.outlineVariant;
  }

  Widget _buildInfoRow(
    ColorScheme cs,
    IconData icon,
    String label,
    String value,
  ) {
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

  Widget _buildActionButtons(
      BackgroundTask task, ColorScheme cs, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Open file button for completed tasks
        if (task.status == TaskStatus.completed &&
            task.downloadedFilePath != null)
          _actionButton(
            icon: Icons.folder_open,
            label: '打开文件',
            color: Colors.green,
            onPressed: () => openFile(task.downloadedFilePath!, context),
          ),
        // Retry button for failed tasks
        if (task.status == TaskStatus.failed)
          _actionButton(
            icon: Icons.refresh,
            label: '重试',
            color: Colors.blue,
            onPressed: () => _navigateToTaskPage(context, task),
          ),
        // Delete button
        TextButton.icon(
          onPressed: () {
            ref.read(backgroundTasksProvider.notifier).removeTask(task.id);
          },
          icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
          label: Text('删除', style: TextStyle(fontSize: 13, color: cs.error)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  void _navigateToTaskPage(BuildContext context, BackgroundTask task) {
    switch (task.type) {
      case BackgroundTaskType.ocr:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OcrPage(retryData: task.retryData),
          ),
        );
        break;
      case BackgroundTaskType.asr:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AsrPage(retryData: task.retryData),
          ),
        );
        break;
      case BackgroundTaskType.audioSeparation:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioSeparationPage(retryData: task.retryData),
          ),
        );
        break;
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
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

  // ===========================================================================
  // Stateless helpers
  // ===========================================================================

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
