import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';

/// 任务列表页面 - 显示所有合成任务（进行中/已完成/失败）
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    final hasCompleted = tasks.any((t) => t.status == TaskStatus.completed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        centerTitle: true,
        actions: [
          if (hasCompleted)
            GestureDetector(
              onTap: () => _confirmClearCompleted(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '清空已完成',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无任务', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskCard(task: task);
              },
            ),
    );
  }

  void _confirmClearCompleted(BuildContext context, WidgetRef ref) {
    // 直接清除已完成，无需二次确认；保留进行中/失败/暂停
    final notifier = ref.read(taskListProvider.notifier);
    final tasks = ref.read(taskListProvider);
    for (final t in tasks) {
      if (t.status == TaskStatus.completed) {
        notifier.removeTask(t.id);
      }
    }
  }
}

class _TaskCard extends ConsumerWidget {
  final SynthesisTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 状态图标
            _buildStatusIcon(),
            const SizedBox(width: 12),
            // 标题+时间
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isNotEmpty ? task.title : '未命名录音',
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
                      _buildStatusChip(),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(task.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  // 失败的显示完整错误信息（直到手动关闭）
                  if (task.status == TaskStatus.failed && task.error != null)
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showErrorDetailDialog(
                                    context, task.error!),
                                child: Text(
                                  task.error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => ref
                                  .read(taskListProvider.notifier)
                                  .dismissError(task.id),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red[300],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // === 操作区域 ===
            if (task.status == TaskStatus.running)
              // 进行中：三点菜单（暂停 + 清除）
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'pause') {
                    ref.read(taskListProvider.notifier).pauseTask(task.id);
                  } else if (value == 'remove') {
                    ref.read(taskListProvider.notifier).removeTask(task.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pause',
                    child: ListTile(
                      leading: Icon(Icons.pause, size: 20),
                      title: Text('暂停'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      title: Text('清除任务', style: TextStyle(color: Colors.red)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            if (task.status == TaskStatus.paused)
              // 已暂停：继续按钮 + 三点菜单（仅清除）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(taskListProvider.notifier).resumeTask(task.id);
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('继续', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'remove') {
                        ref.read(taskListProvider.notifier).removeTask(task.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          title: Text('清除任务', style: TextStyle(color: Colors.red)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (task.status == TaskStatus.failed)
              // 失败：重试按钮 + 三点菜单（关闭错误 + 清除）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(taskListProvider.notifier).retryTask(task.id);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重试', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'dismiss_error') {
                        ref.read(taskListProvider.notifier).dismissError(task.id);
                      } else if (value == 'remove') {
                        ref.read(taskListProvider.notifier).removeTask(task.id);
                      }
                    },
                    itemBuilder: (_) => [
                      if (task.error != null)
                        const PopupMenuItem(
                          value: 'dismiss_error',
                          child: ListTile(
                            leading: Icon(Icons.close, size: 20, color: Colors.grey),
                            title: Text('关闭错误信息'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          title: Text('清除任务', style: TextStyle(color: Colors.red)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (task.status == TaskStatus.completed)
              // 已完成：三点菜单（仅从列表移除）
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'remove') {
                    ref.read(taskListProvider.notifier).removeTask(task.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, size: 20, color: Colors.grey),
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

  Widget _buildStatusIcon() {
    switch (task.status) {
      case TaskStatus.running:
        return SizedBox(
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

  Widget _buildStatusChip() {
    switch (task.status) {
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 弹窗显示完整错误详情
  void _showErrorDetailDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            const Text('合成错误详情'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            error,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
