import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';
import 'task_list_shared.dart';

/// 任务列表页面 - 显示所有合成任务（进行中/已完成/失败）
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        centerTitle: true,
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无任务',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(task: task);
              },
            ),
    );
  }
}
