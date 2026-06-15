import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import 'task_utils.dart';

// =============================================================================
// 后台任务卡片（OCR / ASR / 音频分离）
// =============================================================================

class BackgroundTaskCard extends ConsumerWidget {
  final BackgroundTask task;
  final bool isUnread;

  const BackgroundTaskCard({super.key, required this.task, this.isUnread = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isUnread)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            _buildStatusIcon(task.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _taskTypeIcon(task.type),
                        size: 14,
                        color: _taskTypeColor(task.type),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _taskTypeLabel(task.type),
                        style: TextStyle(
                          fontSize: 11,
                          color: _taskTypeColor(task.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusChip(task.status),
                      const SizedBox(width: 8),
                      Text(
                        formatRelativeTime(task.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (task.status == TaskStatus.failed &&
                      task.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          task.error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'remove') {
                  ref.read(backgroundTasksProvider.notifier).removeTask(task.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        size: 20, color: Colors.grey),
                    title: Text('从列表移除'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.blue,
          ),
        );
      case TaskStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case TaskStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
      case TaskStatus.paused:
        return const Icon(Icons.pause_circle, color: Colors.orange, size: 24);
    }
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

  static String _taskTypeLabel(BackgroundTaskType type) {
    return type.label;
  }
}
