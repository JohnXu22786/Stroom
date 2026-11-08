import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../l10n/app_localizations.dart';
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
  final double? taskListViewportHeight;

  const TaskFlowCard({
    super.key,
    required this.execution,
    this.isUnread = false,
    this.taskListViewportHeight,
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
    _expanded = [
      FlowExecutionStatus.failed,
      FlowExecutionStatus.interrupted,
    ].contains(initialStatus);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

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
        if ([
              FlowExecutionStatus.failed,
              FlowExecutionStatus.interrupted,
            ].contains(next?.status) &&
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isUnread ? cs.primary : cs.outlineVariant,
          width: widget.isUnread ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header (always visible) ──
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: Radius.circular(0),
            ),
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
                                horizontal: 4,
                                vertical: 1,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                strings.taskFlowCardTag,
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
                          '${_executionLabel(execution.status, strings)} · ${_progressText(subTasks, strings)}',
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
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              strings.taskFlowCardQueued,
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
              taskListViewportHeight: widget.taskListViewportHeight,
            ),
            if (execution.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  execution.error!,
                  style: TextStyle(color: cs.error, fontSize: 12),
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
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
        ),
      FlowExecutionStatus.completed => const Icon(
          Icons.check_circle,
          size: 20,
          color: Colors.green,
        ),
      FlowExecutionStatus.failed => Icon(
          Icons.error,
          size: 20,
          color: cs.error,
        ),
      FlowExecutionStatus.paused => const Icon(
          Icons.pause_circle,
          size: 20,
          color: Colors.orange,
        ),
      FlowExecutionStatus.cancelled => Icon(
          Icons.cancel_outlined,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
      FlowExecutionStatus.interrupted => const Icon(
          Icons.warning_amber,
          size: 20,
          color: Colors.orange,
        ),
      FlowExecutionStatus.waiting => Icon(
          Icons.hourglass_empty,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
    };
  }

  String _progressText(List<FlowSubTask> subTasks, AppLocalizations strings) {
    final done = subTasks
        .where((step) => step.outcome == FlowStepOutcome.succeeded)
        .length;
    final details = <String>[
      strings.taskFlowCardCompletedProgress(done, subTasks.length),
    ];
    for (final (outcome, label) in [
      (FlowStepOutcome.failed, strings.taskFlowCardFailedLabel),
      (FlowStepOutcome.skipped, strings.taskFlowCardSkippedLabel),
      (FlowStepOutcome.cancelled, strings.taskFlowCardCancelledLabel),
      (FlowStepOutcome.interrupted, strings.taskFlowCardInterruptedLabel),
    ]) {
      final count = subTasks.where((step) => step.outcome == outcome).length;
      if (count > 0) details.add(strings.taskFlowCardCountLabel(count, label));
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
  final double? taskListViewportHeight;

  const _ExpandedContent({
    required this.subTasks,
    required this.executionId,
    required this.executionStatus,
    required this.taskListViewportHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;
    final restoreReady = ref.watch(taskFlowExecutionRestoreStatusProvider) ==
        FlowExecutionRestoreStatus.ready;
    final executions = ref.watch(taskFlowExecutionsProvider);
    final execution = executions.where((e) => e.id == executionId).firstOrNull;
    final hasBatchWork = execution != null &&
        hasUnfinishedFlowBatchMember(execution, executions);

    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final backgroundTasks = ref.watch(backgroundTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);

    return Column(
      children: [
        for (int i = 0; i < subTasks.length; i++)
          _buildSubTaskCard(
            subTasks[i],
            catcatchTasks,
            backgroundTasks,
            synthesisTasks,
            cs,
            strings,
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (restoreReady &&
                    (executionStatus == FlowExecutionStatus.running ||
                        executionStatus == FlowExecutionStatus.waiting))
                  TextButton.icon(
                    onPressed: () => _control(
                      context,
                      () => ref
                          .read(taskFlowExecutionServiceProvider)
                          .pauseExecution(executionId),
                    ),
                    icon: const Icon(Icons.pause, size: 18),
                    label: Text(strings.taskFlowCardPause),
                  ),
                if (restoreReady && (execution?.canResume ?? false))
                  TextButton.icon(
                    onPressed: () => _control(
                      context,
                      () => ref
                          .read(taskFlowExecutionServiceProvider)
                          .resumeExecution(executionId),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      executionStatus == FlowExecutionStatus.paused
                          ? strings.taskFlowCardResume
                          : strings.taskFlowCardResumeInterrupted,
                    ),
                  ),
                if (restoreReady &&
                    [
                      FlowExecutionStatus.running,
                      FlowExecutionStatus.waiting,
                      FlowExecutionStatus.paused,
                    ].contains(executionStatus))
                  TextButton.icon(
                    onPressed: () => _control(
                      context,
                      () => ref
                          .read(taskFlowExecutionServiceProvider)
                          .cancelExecution(executionId),
                    ),
                    icon: const Icon(Icons.stop, size: 18),
                    label: Text(strings.taskFlowCardCancelFlow),
                  ),
                if (restoreReady &&
                    [
                      FlowExecutionStatus.failed,
                      FlowExecutionStatus.interrupted,
                      FlowExecutionStatus.cancelled,
                    ].contains(executionStatus))
                  TextButton.icon(
                    onPressed: () => _confirmRetry(context, ref),
                    icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                    label: Text(
                      strings.taskFlowCardRetry,
                      style: TextStyle(fontSize: 13, color: cs.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                if (restoreReady && hasBatchWork)
                  TextButton.icon(
                    onPressed: () => _control(
                      context,
                      () => ref
                          .read(taskFlowExecutionServiceProvider)
                          .cancelBatch(execution.batchId!),
                    ),
                    icon: const Icon(Icons.stop, size: 18),
                    label: Text(strings.taskFlowCardCancelBatch),
                  ),
                TextButton.icon(
                  onPressed: restoreReady
                      ? () => _confirmDelete(context, ref, executionId)
                      : null,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: Text(
                    strings.taskFlowCardDelete,
                    style: TextStyle(fontSize: 13, color: Colors.red),
                  ),
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
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _confirmRetry(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final execution = ref
        .read(taskFlowExecutionsProvider)
        .where((e) => e.id == executionId)
        .firstOrNull;
    if (execution == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.taskFlowCardRetryFlow),
        content: Text(
          execution.snapshot == null
              ? strings.taskFlowCardNoSnapshot
              : strings.taskFlowCardRetryInfo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.taskFlowCardCancel),
          ),
          if (execution.snapshot != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _retry(context, ref, execution, useLatest: true);
              },
              child: Text(strings.taskFlowCardRunLatest),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _retry(
                context,
                ref,
                execution,
                useLatest: execution.snapshot == null,
              );
            },
            child: Text(
              execution.snapshot == null
                  ? strings.taskFlowCardRetry
                  : strings.taskFlowCardRetryOriginal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(
    BuildContext context,
    WidgetRef ref,
    TaskFlowExecution execution, {
    required bool useLatest,
  }) async {
    final input = FlowRunInput(
      text: execution.inputText,
      durationSec: execution.inputDurationSec,
    );
    try {
      final ids = await ref
          .read(taskFlowExecutionServiceProvider)
          .retryExecution(execution.id, useLatestConfiguration: useLatest);
      if (context.mounted)
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskFlowRunPage(executionIds: ids),
          ),
        );
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TaskFlowBuilderPage(
            flowId: execution.flowId,
            startInRunMode: true,
            initialInput: input,
            validationError: error,
          ),
        ),
      );
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String execId) {
    final strings = AppLocalizations.of(context)!;
    final execution = ref
        .read(taskFlowExecutionsProvider)
        .where((e) => e.id == execId)
        .firstOrNull;
    final isRunning = execution != null && !execution.isTerminal;
    final cancelsBatch = execution != null &&
        hasUnfinishedFlowBatchMember(
          execution,
          ref.read(taskFlowExecutionsProvider),
        );
    // Clearing a card with unfinished batch members cancels their work;
    // deleting the selected card also removes its own child tasks.
    // Save the cancellation and child removals before removing the record.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.taskFlowCardDeleteRecord),
        content: Text(
          cancelsBatch
              ? strings.taskFlowCardDeleteBatchConfirm
              : isRunning
                  ? strings.taskFlowCardDeleteRunningConfirm
                  : execution != null && execution.subTasks.isNotEmpty
                      ? strings.taskFlowCardDeleteRecordConfirm
                      : strings.taskFlowCardDeleteConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.taskFlowCardCancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Re-read after awaits: the dialog may have been open while
                // later blocks started or a terminal cancellation failed to
                // persist on an earlier delete attempt.
                while (ctx.mounted) {
                  final current = ref
                      .read(taskFlowExecutionsProvider)
                      .where((e) => e.id == execId)
                      .firstOrNull;
                  if (current == null) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    return;
                  }
                  final service = ref.read(taskFlowExecutionServiceProvider);
                  if (hasUnfinishedFlowBatchMember(
                    current,
                    ref.read(taskFlowExecutionsProvider),
                  )) {
                    await service.cancelBatch(current.batchId!);
                    if (!ctx.mounted) return;
                  } else if (!current.isTerminal) {
                    await service.cancelExecution(execId);
                    if (!ctx.mounted) return;
                  }
                  final snapshot = ref.read(taskFlowExecutionsProvider);
                  if (!await ref
                      .read(taskFlowExecutionsProvider.notifier)
                      .persist()) {
                    throw TaskFlowPersistenceException(
                      strings.taskFlowCardSaveCancelStateError,
                    );
                  }
                  if (!ctx.mounted) return;
                  if (!identical(
                    snapshot,
                    ref.read(taskFlowExecutionsProvider),
                  )) {
                    continue;
                  }
                  final latest =
                      snapshot.where((e) => e.id == execId).firstOrNull;
                  if (latest != null && !latest.isTerminal) {
                    throw StateError(strings.taskFlowCardStillRunning);
                  }
                  final executionsNotifier = ref.read(
                    taskFlowExecutionsProvider.notifier,
                  );
                  if (latest != null) {
                    await removeFlowChildTasksPersisted(ref, [latest]);
                  }
                  if (!await executionsNotifier.removeExecutionsPersisted([
                    execId,
                  ])) {
                    throw TaskFlowPersistenceException(
                      strings.taskFlowCardSaveDeleteStateError,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  return;
                }
              } catch (error) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  final message = switch (error.toString()) {
                    '猫抓子任务删除状态无法保存，请重试' =>
                      strings.taskFlowCardCatCatchDeletePersistError,
                    '合成子任务删除状态无法保存，请重试' =>
                      strings.taskFlowCardSynthesisDeletePersistError,
                    '后台子任务删除状态无法保存，请重试' =>
                      strings.taskFlowCardBackgroundDeletePersistError,
                    _ => error.toString(),
                  };
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                }
              }
            },
            child: Text(
              strings.taskFlowCardConfirm,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTaskCard(
    FlowSubTask subTask,
    List<catcatch.CatCatchTask> catcatchTasks,
    List<BackgroundTask> backgroundTasks,
    List<SynthesisTask> synthesisTasks,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
    if ([
      FlowStepOutcome.skipped,
      FlowStepOutcome.cancelled,
      FlowStepOutcome.interrupted,
    ].contains(subTask.outcome)) {
      return _buildFallbackCard(subTask, cs, strings);
    }
    switch (subTask.subTaskType) {
      case 'catcatch':
        return _buildCatCatchCard(subTask, catcatchTasks, cs, strings);
      case 'background':
        return _buildBackgroundCard(subTask, backgroundTasks, cs, strings);
      case 'synthesis':
        return _buildSynthesisCard(subTask, synthesisTasks, cs, strings);
      default:
        return _buildFallbackCard(subTask, cs, strings);
    }
  }

  Widget _buildCatCatchCard(
    FlowSubTask subTask,
    List<catcatch.CatCatchTask> tasks,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return CatCatchTaskCard(
        key: ValueKey('catcatch_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
        taskListViewportHeight: taskListViewportHeight,
      );
    }
    return _buildFallbackCard(subTask, cs, strings);
  }

  Widget _buildBackgroundCard(
    FlowSubTask subTask,
    List<BackgroundTask> tasks,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return BackgroundTaskCard(
        key: ValueKey('bg_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
        flowBlockTypeKey: subTask.blockTypeKey,
      );
    }
    return _buildFallbackCard(subTask, cs, strings);
  }

  Widget _buildSynthesisCard(
    FlowSubTask subTask,
    List<SynthesisTask> tasks,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
    final task = tasks.where((t) => t.id == subTask.subTaskId).firstOrNull;
    if (task != null) {
      return SynthesisTaskCard(
        key: ValueKey('synth_${task.id}'),
        task: task,
        isUnread: false,
        isFlowManaged: true,
      );
    }
    return _buildFallbackCard(subTask, cs, strings);
  }

  Widget _buildFallbackCard(
    FlowSubTask subTask,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
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
                      strings.taskFlowCardWaiting,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!isInitializing)
              Text(
                _stepLabel(subTask.outcome, strings),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
        FlowStepOutcome.succeeded => const Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green,
          ),
        FlowStepOutcome.failed => Icon(Icons.error, size: 16, color: cs.error),
        FlowStepOutcome.paused => const Icon(
            Icons.pause_circle,
            size: 16,
            color: Colors.orange,
          ),
        FlowStepOutcome.skipped => Icon(
            Icons.skip_next,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        FlowStepOutcome.cancelled => Icon(
            Icons.cancel_outlined,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        FlowStepOutcome.interrupted => const Icon(
            Icons.warning_amber,
            size: 16,
            color: Colors.orange,
          ),
        FlowStepOutcome.pending => Icon(
            Icons.hourglass_empty,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
      };
}

String _executionLabel(FlowExecutionStatus status, AppLocalizations strings) =>
    switch (status) {
      FlowExecutionStatus.waiting => strings.taskFlowCardWaiting,
      FlowExecutionStatus.running => strings.taskFlowCardRunning,
      FlowExecutionStatus.paused => strings.taskFlowCardPaused,
      FlowExecutionStatus.completed => strings.taskFlowCardCompleted,
      FlowExecutionStatus.failed => strings.taskFlowCardFailed,
      FlowExecutionStatus.cancelled => strings.taskFlowCardCanceled,
      FlowExecutionStatus.interrupted => strings.taskFlowCardInterrupted,
    };

String _stepLabel(FlowStepOutcome outcome, AppLocalizations strings) =>
    switch (outcome) {
      FlowStepOutcome.pending => strings.taskFlowCardWaiting,
      FlowStepOutcome.running => strings.taskFlowCardRunning,
      FlowStepOutcome.paused => strings.taskFlowCardPaused,
      FlowStepOutcome.succeeded => strings.taskFlowCardCompleted,
      FlowStepOutcome.failed => strings.taskFlowCardFailed,
      FlowStepOutcome.skipped => strings.taskFlowCardSucceeded,
      FlowStepOutcome.cancelled => strings.taskFlowCardCanceled,
      FlowStepOutcome.interrupted => strings.taskFlowCardInterrupted,
    };
