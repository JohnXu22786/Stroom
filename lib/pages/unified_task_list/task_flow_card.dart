import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../catcatch/providers/catcatch_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/task_provider_shared.dart';
import '../../task_flow/models/task_flow_execution.dart';
import '../../task_flow/providers/task_flow_execution_provider.dart';
import '../../task_flow/services/task_flow_execution_service.dart';
import '../../task_flow/services/task_flow_validator.dart';
import '../../task_flow/pages/task_flow_builder_page.dart';
import '../../task_flow/pages/task_flow_run_page.dart';
import '../../task_flow/providers/task_flow_provider.dart';
import 'background_task_card.dart';
import 'catcatch_task_card.dart';
import 'synthesis_task_card.dart';
import 'task_utils.dart';

/// Card for a task flow execution in the unified task list.
///
/// Watches the execution provider DIRECTLY (not via parent prop) so
/// subTaskId updates from the execution service are always reflected.
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
  void initState() {
    super.initState();
    // A restored failed run has no status transition for ref.listen to catch.
    final initialStatus = ref
            .read(taskFlowExecutionsProvider)
            .where((execution) => execution.id == widget.execution.id)
            .firstOrNull
            ?.status ??
        widget.execution.status;
    _expanded = [FlowExecutionStatus.failed, FlowExecutionStatus.interrupted]
        .contains(initialStatus);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Watch execution directly for real-time subTaskId/subTask status.
    // Use .select() so the card only rebuilds when ITS execution changes,
    // not when any unrelated execution is added/updated/removed.
    final execution = ref.watch(
      taskFlowExecutionsProvider.select(
        (list) => list.where((e) => e.id == widget.execution.id).firstOrNull,
      ),
    );

    // Keep failure details visible; successful runs may collapse.
    ref.listen(
      taskFlowExecutionsProvider.select(
        (list) => list.where((e) => e.id == widget.execution.id).firstOrNull,
      ),
      (prev, next) {
        final wasRunning =
            prev != null && prev.status == FlowExecutionStatus.running;
        if ([FlowExecutionStatus.failed, FlowExecutionStatus.interrupted]
                .contains(next?.status) &&
            next?.status != prev?.status) {
          setState(() => _expanded = true);
        } else if (wasRunning &&
            next?.status == FlowExecutionStatus.completed &&
            _expanded) {
          setState(() => _expanded = false);
        }
      },
    );

    if (execution == null) return const SizedBox.shrink();

    final subTasks = execution.subTasks;

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
                  _flowStatusIcon(execution, cs),
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
                                execution.flowName,
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
                          '${_executionLabel(execution.status)} · ${_progressText(subTasks)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        // Queued badge: the flow is alive but its current
                        // block is waiting for scheduler resources.
                        if (execution.queued) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '排队中（等待资源）',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

          // ── Expanded: nested real task cards ──
          if (_expanded) ...[
            _ExpandedContent(
              subTasks: subTasks,
              executionId: execution.id,
              executionStatus: execution.status,
            ),
            if (execution.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  execution.error!,
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Flow status icon
  // ===========================================================================

  Widget _flowStatusIcon(TaskFlowExecution execution, ColorScheme cs) {
    return switch (execution.status) {
      FlowExecutionStatus.running => SizedBox(
          width: 20,
          height: 20,
          child:
              CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
      FlowExecutionStatus.completed =>
        const Icon(Icons.check_circle, size: 20, color: Colors.green),
      FlowExecutionStatus.failed =>
        Icon(Icons.error, size: 20, color: cs.error),
      FlowExecutionStatus.paused =>
        const Icon(Icons.pause_circle, size: 20, color: Colors.orange),
      FlowExecutionStatus.cancelled =>
        Icon(Icons.cancel_outlined, size: 20, color: cs.onSurfaceVariant),
      FlowExecutionStatus.interrupted =>
        const Icon(Icons.warning_amber, size: 20, color: Colors.orange),
      FlowExecutionStatus.waiting =>
        Icon(Icons.hourglass_empty, size: 20, color: cs.onSurfaceVariant),
    };
  }

  String _progressText(List<FlowSubTask> subTasks) {
    final done = subTasks
        .where((step) => step.outcome == FlowStepOutcome.succeeded)
        .length;
    final details = <String>['$done/${subTasks.length} 已完成'];
    for (final (outcome, label) in [
      (FlowStepOutcome.failed, '失败'),
      (FlowStepOutcome.skipped, '跳过'),
      (FlowStepOutcome.cancelled, '取消'),
      (FlowStepOutcome.interrupted, '中断'),
    ]) {
      final count = subTasks.where((step) => step.outcome == outcome).length;
      if (count > 0) details.add('$count 个$label');
    }
    return details.join(' · ');
  }
}

// ===========================================================================
// Expanded content — only built when _expanded is true
// ===========================================================================

class _ExpandedContent extends ConsumerWidget {
  final List<FlowSubTask> subTasks;
  final String executionId;
  final FlowExecutionStatus executionStatus;

  const _ExpandedContent({
    required this.subTasks,
    required this.executionId,
    required this.executionStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final backgroundTasks = ref.watch(backgroundTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);

    return Column(
      children: [
        for (int i = 0; i < subTasks.length; i++)
          _buildSubTaskCard(
              subTasks[i], catcatchTasks, backgroundTasks, synthesisTasks, cs),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (executionStatus == FlowExecutionStatus.running ||
                    executionStatus == FlowExecutionStatus.waiting)
                  TextButton.icon(
                      onPressed: () => _control(
                          context,
                          () => ref
                              .read(taskFlowExecutionServiceProvider)
                              .pauseExecution(executionId)),
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('暂停流程')),
                if (ref
                        .watch(taskFlowExecutionsProvider)
                        .where((e) => e.id == executionId)
                        .firstOrNull
                        ?.canResume ??
                    false)
                  TextButton.icon(
                      onPressed: () => _control(
                          context,
                          () => ref
                              .read(taskFlowExecutionServiceProvider)
                              .resumeExecution(executionId)),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(executionStatus == FlowExecutionStatus.paused
                          ? '继续流程'
                          : '从中断步骤继续')),
                if ([
                  FlowExecutionStatus.running,
                  FlowExecutionStatus.waiting,
                  FlowExecutionStatus.paused
                ].contains(executionStatus))
                  TextButton.icon(
                      onPressed: () => _control(
                          context,
                          () => ref
                              .read(taskFlowExecutionServiceProvider)
                              .cancelExecution(executionId)),
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('取消流程')),
                if ([
                  FlowExecutionStatus.failed,
                  FlowExecutionStatus.interrupted,
                  FlowExecutionStatus.cancelled
                ].contains(executionStatus))
                  TextButton.icon(
                    onPressed: () => _confirmRetry(context, ref),
                    icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                    label: Text('重试',
                        style: TextStyle(fontSize: 13, color: cs.primary)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, executionId),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  label: const Text('删除',
                      style: TextStyle(fontSize: 13, color: Colors.red)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _control(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _confirmRetry(BuildContext context, WidgetRef ref) {
    final execution = ref
        .read(taskFlowExecutionsProvider)
        .where((e) => e.id == executionId)
        .firstOrNull;
    if (execution == null) return;
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('重试任务流'),
              content: Text(execution.snapshot == null
                  ? '此历史记录没有运行快照，将使用当前流程配置从头运行。'
                  : '从头运行会重新下载并调用模型。可按启动时的原配置重试，或明确选择当前最新配置。要复用已完成步骤，请选择“从中断步骤继续”。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                if (execution.snapshot != null)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _retry(context, ref, execution, useLatest: true);
                      },
                      child: const Text('按最新配置运行')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _retry(context, ref, execution,
                          useLatest: execution.snapshot == null);
                    },
                    child: Text(execution.snapshot == null ? '重试' : '按原配置重试')),
              ],
            ));
  }

  Future<void> _retry(
      BuildContext context, WidgetRef ref, TaskFlowExecution execution,
      {required bool useLatest}) async {
    final input = FlowRunInput(
        text: execution.inputText, durationSec: execution.inputDurationSec);
    try {
      final ids = await ref
          .read(taskFlowExecutionServiceProvider)
          .retryExecution(execution.id, useLatestConfiguration: useLatest);
      if (context.mounted)
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TaskFlowRunPage(executionIds: ids)));
    } on TaskFlowValidationException catch (error) {
      if (!context.mounted) return;
      if (!useLatest ||
          !ref
              .read(taskFlowListProvider)
              .any((f) => f.id == execution.flowId)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaskFlowBuilderPage(
              flowId: execution.flowId,
              startInRunMode: true,
              initialInput: input,
              validationError: error)));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String execId) {
    final execution = ref
        .read(taskFlowExecutionsProvider)
        .where((e) => e.id == execId)
        .firstOrNull;
    final isRunning = execution != null && !execution.isTerminal;
    // Deleting a running flow cancels its sub-task tasks first — since the
    // executors' removeTask paths genuinely cancel the engine/HTTP work,
    // no orphaned background work is left behind.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务流记录'),
        content: Text(
          isRunning
              ? execution.batchId != null
                  ? '删除将取消整个批次中尚未完成的运行，并清除本条记录。确定删除？'
                  : '删除将取消此任务流。确定删除？'
              : execution != null && execution.subTasks.isNotEmpty
                  ? '确定删除此任务流记录？其子任务记录也会一并删除。'
                  : '确定删除此任务流记录？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // Re-read the execution at confirm time: the dialog may have
              // been open while later blocks started, so the snapshot from
              // dialog-open misses their sub-tasks.
              final current = ref
                  .read(taskFlowExecutionsProvider)
                  .where((e) => e.id == execId)
                  .firstOrNull;
              if (current != null && !current.isTerminal) {
                try {
                  final service = ref.read(taskFlowExecutionServiceProvider);
                  if (current.batchId != null) {
                    await service.cancelBatch(current.batchId!);
                  } else {
                    await service.cancelExecution(execId);
                  }
                } catch (error) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())));
                  return;
                }
              }
              if (!ctx.mounted) return;
              _removeSubTaskTasks(ref, current);
              ref
                  .read(taskFlowExecutionsProvider.notifier)
                  .removeExecution(execId);
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Remove the execution's real sub-task tasks from their providers so
  /// they don't resurface as orphaned standalone cards after the flow
  /// record is deleted (matches the AppBar 清除 actions, which remove
  /// execution and sub-tasks together).
  void _removeSubTaskTasks(WidgetRef ref, TaskFlowExecution? execution) {
    if (execution == null) return;
    removeFlowSubTaskTasks(ref, execution);
  }

  Widget _buildSubTaskCard(
    FlowSubTask subTask,
    List<catcatch.CatCatchTask> catcatchTasks,
    List<BackgroundTask> backgroundTasks,
    List<SynthesisTask> synthesisTasks,
    ColorScheme cs,
  ) {
    if ([
      FlowStepOutcome.skipped,
      FlowStepOutcome.cancelled,
      FlowStepOutcome.interrupted
    ].contains(subTask.outcome)) {
      return _buildFallbackCard(subTask, cs);
    }
    switch (subTask.subTaskType) {
      case 'catcatch':
        return _buildCatCatchCard(subTask, catcatchTasks, cs);
      case 'background':
        return _buildBackgroundCard(subTask, backgroundTasks, cs);
      case 'synthesis':
        return _buildSynthesisCard(subTask, synthesisTasks, cs);
      default:
        return _buildFallbackCard(subTask, cs);
    }
  }

  Widget _buildCatCatchCard(
      FlowSubTask subTask, List<catcatch.CatCatchTask> tasks, ColorScheme cs) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return CatCatchTaskCard(
        key: ValueKey('catcatch_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildBackgroundCard(
      FlowSubTask subTask, List<BackgroundTask> tasks, ColorScheme cs) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return BackgroundTaskCard(
        key: ValueKey('bg_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildSynthesisCard(
      FlowSubTask subTask, List<SynthesisTask> tasks, ColorScheme cs) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return SynthesisTaskCard(
        key: ValueKey('synth_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
      );
    }
    return _buildFallbackCard(subTask, cs);
  }

  Widget _buildFallbackCard(FlowSubTask subTask, ColorScheme cs) {
    final isInitializing = subTask.outcome == FlowStepOutcome.pending;
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
            _statusIcon(subTask.outcome, cs),
            const SizedBox(width: 8),
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
                  if (isInitializing)
                    Text(
                      '等待中',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (!isInitializing)
              Text(
                _stepLabel(subTask.outcome),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(FlowStepOutcome outcome, ColorScheme cs) =>
      switch (outcome) {
        FlowStepOutcome.running => SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
        FlowStepOutcome.succeeded =>
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
        FlowStepOutcome.failed => Icon(Icons.error, size: 16, color: cs.error),
        FlowStepOutcome.paused =>
          const Icon(Icons.pause_circle, size: 16, color: Colors.orange),
        FlowStepOutcome.skipped =>
          Icon(Icons.skip_next, size: 16, color: cs.onSurfaceVariant),
        FlowStepOutcome.cancelled =>
          Icon(Icons.cancel_outlined, size: 16, color: cs.onSurfaceVariant),
        FlowStepOutcome.interrupted =>
          const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
        FlowStepOutcome.pending =>
          Icon(Icons.hourglass_empty, size: 16, color: cs.onSurfaceVariant),
      };
}

String _executionLabel(FlowExecutionStatus status) => switch (status) {
      FlowExecutionStatus.waiting => '等待中',
      FlowExecutionStatus.running => '进行中',
      FlowExecutionStatus.paused => '已暂停',
      FlowExecutionStatus.completed => '已完成',
      FlowExecutionStatus.failed => '失败',
      FlowExecutionStatus.cancelled => '已取消',
      FlowExecutionStatus.interrupted => '已中断',
    };

String _stepLabel(FlowStepOutcome outcome) => switch (outcome) {
      FlowStepOutcome.pending => '等待中',
      FlowStepOutcome.running => '进行中',
      FlowStepOutcome.paused => '已暂停',
      FlowStepOutcome.succeeded => '已完成',
      FlowStepOutcome.failed => '失败',
      FlowStepOutcome.skipped => '已跳过',
      FlowStepOutcome.cancelled => '已取消',
      FlowStepOutcome.interrupted => '已中断',
    };
