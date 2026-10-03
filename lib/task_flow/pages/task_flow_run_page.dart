import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/unified_task_list/task_flow_card.dart';
import '../providers/task_flow_execution_provider.dart';
import '../services/task_flow_execution_service.dart';

/// A direct entry to the records created by one launch.
class TaskFlowRunPage extends ConsumerWidget {
  final List<String> executionIds;

  const TaskFlowRunPage({super.key, required this.executionIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restoreStatus = ref.watch(taskFlowExecutionRestoreStatusProvider);
    final executions = ref
        .watch(taskFlowExecutionsProvider)
        .where((execution) => executionIds.contains(execution.id))
        .toList();
    final finished =
        executions.where((execution) => execution.isTerminal).length;
    final batchId = executions
        .map((execution) => execution.batchId)
        .whereType<String>()
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('本次运行'), actions: [
        if (restoreStatus == FlowExecutionRestoreStatus.ready &&
            batchId != null &&
            finished < executions.length)
          TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(taskFlowExecutionServiceProvider)
                      .cancelBatch(batchId);
                } catch (error) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('取消整个批次')),
      ]),
      body: restoreStatus != FlowExecutionRestoreStatus.ready
          ? Center(
              child: Text(restoreStatus == FlowExecutionRestoreStatus.restoring
                  ? '正在恢复任务流记录…'
                  : '任务流记录读取失败，任务操作已暂停'))
          : executions.isEmpty
              ? const Center(child: Text('本次运行记录已清除'))
              : ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('$finished/${executionIds.length} 个运行已结束'
                          '${executions.length < executionIds.length ? ' · ${executionIds.length - executions.length} 个记录已清除' : ''}')),
                  for (final execution in executions)
                    TaskFlowCard(key: ValueKey(execution.id), execution: execution),
                ]),
    );
  }
}
