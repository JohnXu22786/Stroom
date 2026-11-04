import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/unified_task_list/task_flow_card.dart';
import '../providers/task_flow_execution_provider.dart';
import '../services/task_flow_execution_service.dart';
import '../../l10n/app_localizations.dart';

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
    final finished = executions
        .where((execution) => execution.isTerminal)
        .length;
    final batchId = executions
        .map((execution) => execution.batchId)
        .whereType<String>()
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.taskFlowUiRunTitle),
        actions: [
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(AppLocalizations.of(context)!.taskFlowUiCancelBatch),
            ),
        ],
      ),
      body: restoreStatus != FlowExecutionRestoreStatus.ready
          ? Center(
              child: Text(
                restoreStatus == FlowExecutionRestoreStatus.restoring
                    ? AppLocalizations.of(context)!.taskFlowUiRestoringRecords
                    : AppLocalizations.of(context)!.taskFlowUiRecordsPaused,
              ),
            )
          : executions.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.taskFlowUiRecordsCleared,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppLocalizations.of(context)!.taskFlowUiRunSummary(
                            finished,
                            executionIds.length,
                          ) +
                          (executions.length < executionIds.length
                              ? AppLocalizations.of(context)!
                                    .taskFlowUiClearedRecordCount(
                                      executionIds.length - executions.length,
                                    )
                              : ''),
                    ),
                  ),
                  for (final execution in executions)
                    TaskFlowCard(
                      key: ValueKey(execution.id),
                      execution: execution,
                      taskListViewportHeight: constraints.maxHeight,
                    ),
                ],
              ),
            ),
    );
  }
}
