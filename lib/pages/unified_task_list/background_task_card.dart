import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ocr_batch_execution.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/background_task_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/text_provider.dart';
import '../../services/ocr_result_saver.dart';
import '../chat/dialogs/error_detail_dialog.dart';
import '../asr_page.dart';
import '../ocr_page.dart';
import '../audio_separation_page.dart';
import 'task_utils.dart';
import 'file_opener.dart';
import '../../widgets/running_elapsed_label.dart';

String _localizedBackgroundStepLabel(String label, AppLocalizations strings) =>
    switch (label) {
      '连接服务器' => strings.bgStepConnectServer,
      '上传图片' => strings.bgStepUploadImage,
      '等待识别结果' => strings.bgStepWaitRecognition,
      '解析结果' => strings.bgStepParseResult,
      '保存文件' => strings.bgStepSaveFile,
      '上传音频' => strings.bgStepUploadAudio,
      '转写中' => strings.bgStepTranscribing,
      '接收结果' => strings.bgStepReceiveResult,
      '分离音频' => strings.bgStepSeparateAudio,
      '保存到文件' => strings.bgStepSaveToFile,
      '发送请求' => strings.bgStepSendRequest,
      '等待回复' => strings.bgStepWaitReply,
      _ => label,
    };

// =============================================================================
// 后台任务卡片（OCR / ASR / 音频分离）
// 默认折叠，只显示标题栏和类型等基本信息。
// 点击卡片可展开查看步骤详情、错误信息、操作按钮。
// =============================================================================

class BackgroundTaskCard extends ConsumerStatefulWidget {
  final BackgroundTask task;
  final bool isUnread;
  final bool isFlowManaged;

  const BackgroundTaskCard({
    super.key,
    required this.task,
    this.isUnread = false,
    this.isFlowManaged = false,
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
    // Auto-expand when the task transitions into running so the step
    // timeline is visible while the task executes.  Keeps behaviour
    // consistent with CatCatchTaskCard and SynthesisTaskCard which
    // also auto-expand on the waiting→running transition.
    if (widget.task.status == TaskStatus.running &&
        oldWidget.task.status != TaskStatus.running) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;
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
                            _taskTypeBadge(
                              widget.task.type,
                              colorScheme,
                              strings,
                            ),
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
                            buildStatusChip(widget.task.status, strings),
                            const SizedBox(width: 8),
                            Text(
                              formatRelativeTime(
                                widget.task.createdAt,
                                strings,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            if (widget.task.status == TaskStatus.running) ...[
                              const SizedBox(width: 8),
                              // Live elapsed time — lets the user see a
                              // slow-but-working task is still alive.
                              RunningElapsedLabel(
                                startedAt: widget.task.createdAt,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
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
                    context,
                    widget.task,
                    colorScheme,
                    ref,
                    hasRawData,
                  ),
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
    BuildContext context,
    BackgroundTask task,
    ColorScheme cs,
    WidgetRef ref,
    bool hasRawData,
  ) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type and time info
        buildInfoRow(
          cs,
          Icons.category_outlined,
          strings.unifiedTaskType,
          _taskTypeLabel(task.type, strings),
        ),
        const SizedBox(height: 4),
        buildInfoRow(
          cs,
          Icons.access_time,
          strings.unifiedTaskCreatedAt,
          formatRelativeTime(task.createdAt, strings),
        ),
        if (task.completedAt != null) ...[
          const SizedBox(height: 4),
          buildInfoRow(
            cs,
            Icons.check_circle_outline,
            strings.unifiedTaskCompletedAt,
            formatRelativeTime(task.completedAt!, strings),
          ),
        ],
        if (task.resultSavedAsPartial) ...[
          const SizedBox(height: 4),
          buildInfoRow(
            cs,
            Icons.warning_amber_outlined,
            strings.unifiedTaskResultStatus,
            strings.unifiedTaskPartialResult,
          ),
        ],

        // Step chain timeline — always visible in expanded mode
        const SizedBox(height: 10),
        _buildStepTimeline(task, cs, AppLocalizations.of(context)!),
        if (task.ocrPageOutcomes.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildOcrPageOutcomes(task, cs, AppLocalizations.of(context)!),
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
                      strings.unifiedTaskErrorDetails,
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
                        label: Text(
                          strings.unifiedTaskViewErrorDetails,
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
        _buildActionButtons(task, cs, ref, AppLocalizations.of(context)!),
      ],
    );
  }

  void _showErrorDetailDialog(BuildContext context, BackgroundTask task) {
    showDataDetailDialog(
      context: context,
      rawRequest: task.rawRequest,
      rawResponse: task.rawResponse,
      isOcrDiagnostics: task.type == BackgroundTaskType.ocr,
    );
  }

  Widget _buildOcrPageOutcomes(
    BackgroundTask task,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.unifiedTaskOcrPerImage,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        for (final outcome in task.ocrPageOutcomes) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                _ocrPageOutcomeIcon(outcome.status, cs),
                const SizedBox(width: 8),
                Text(
                  strings.unifiedTaskOcrPageIndex(outcome.imageIndex + 1),
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                ),
                const SizedBox(width: 8),
                Text(
                  _ocrPageOutcomeLabel(outcome.status, strings),
                  style: TextStyle(
                    fontSize: 12,
                    color: outcome.status == OcrPageOutcomeStatus.failed ||
                            outcome.status == OcrPageOutcomeStatus.incomplete
                        ? Colors.red
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (outcome.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 3),
              child: Text(
                outcome.error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _ocrPageOutcomeIcon(OcrPageOutcomeStatus status, ColorScheme cs) {
    switch (status) {
      case OcrPageOutcomeStatus.pending:
        return Icon(Icons.circle_outlined, size: 15, color: cs.outline);
      case OcrPageOutcomeStatus.running:
        return SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        );
      case OcrPageOutcomeStatus.succeeded:
        return const Icon(
          Icons.check_circle_outline,
          size: 15,
          color: Colors.green,
        );
      case OcrPageOutcomeStatus.incomplete:
      case OcrPageOutcomeStatus.failed:
        return const Icon(Icons.error_outline, size: 15, color: Colors.red);
      case OcrPageOutcomeStatus.cancelled:
        return Icon(Icons.cancel_outlined, size: 15, color: cs.outline);
    }
  }

  String _ocrPageOutcomeLabel(
    OcrPageOutcomeStatus status,
    AppLocalizations strings,
  ) {
    switch (status) {
      case OcrPageOutcomeStatus.pending:
        return strings.unifiedTaskOcrPending;
      case OcrPageOutcomeStatus.running:
        return strings.unifiedTaskOcrRunning;
      case OcrPageOutcomeStatus.succeeded:
        return strings.unifiedTaskCompleted;
      case OcrPageOutcomeStatus.incomplete:
        return strings.unifiedTaskIncomplete;
      case OcrPageOutcomeStatus.failed:
        return strings.unifiedTaskOcrFailed;
      case OcrPageOutcomeStatus.cancelled:
        return strings.unifiedTaskCancelled;
    }
  }

  Widget _buildStepTimeline(
    BackgroundTask task,
    ColorScheme colorScheme,
    AppLocalizations strings,
  ) {
    final steps = task.steps;

    if (steps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          strings.unifiedTaskWaitingStart,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.unifiedTaskSteps,
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
                          _localizedBackgroundStepLabel(step.label, strings),
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

  Widget _buildActionButtons(
    BackgroundTask task,
    ColorScheme cs,
    WidgetRef ref,
    AppLocalizations strings,
  ) {
    // Chat tasks have no standalone page (they run inside a flow) — the
    // 立即开始/重试 buttons would be dead taps, so hide them.
    final hasRetryPage =
        !widget.isFlowManaged && task.type != BackgroundTaskType.chat;
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        // "立即开始" button for waiting tasks
        if (hasRetryPage && task.status == TaskStatus.waiting)
          _actionButton(
            icon: Icons.play_arrow,
            label: strings.unifiedTaskStartNow,
            color: Colors.purple,
            onPressed: () => _navigateToTaskPage(context, task),
          ),
        // Open file button for completed tasks
        if (task.status == TaskStatus.completed &&
            task.downloadedFilePath != null)
          _actionButton(
            icon: Icons.folder_open,
            label: strings.unifiedTaskOpenFile,
            color: Colors.green,
            onPressed: () => openFile(task.downloadedFilePath!, context),
          ),
        // A retained OCR result can be saved without repeating its API call.
        if (hasRetryPage &&
            task.type == BackgroundTaskType.ocr &&
            task.status == TaskStatus.failed &&
            task.result != null)
          _actionButton(
            icon: Icons.save_outlined,
            label: task.resultIsComplete
                ? strings.unifiedTaskRetrySave
                : task.partialSaveRequested
                    ? strings.unifiedTaskRetryPartialSave
                    : strings.unifiedTaskSavePartialResult,
            color: Colors.blue,
            onPressed: () => _retryOcrSave(task, ref),
          ),
        // OCR can still be rerun when the user prefers a fresh recognition.
        if (hasRetryPage && task.status == TaskStatus.failed)
          _actionButton(
            icon: Icons.refresh,
            label: strings.unifiedTaskRetry,
            color: Colors.blue,
            onPressed: () => _navigateToTaskPage(context, task),
          ),
        if (!widget.isFlowManaged &&
            task.type == BackgroundTaskType.ocr &&
            task.status == TaskStatus.running)
          _actionButton(
            icon: Icons.stop_circle_outlined,
            label: strings.unifiedTaskCancel,
            color: Colors.red,
            onPressed: () =>
                ref.read(backgroundTasksProvider.notifier).cancelTask(task.id),
          ),
        // Delete button
        if (!widget.isFlowManaged)
          TextButton.icon(
            onPressed: () {
              ref.read(backgroundTasksProvider.notifier).removeTask(task.id);
            },
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: Text(
              strings.unifiedTaskDelete,
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  void _retryOcrSave(BackgroundTask task, WidgetRef ref) {
    final textNotifier = ref.read(textRecordsProvider.notifier);
    final saver = OcrResultSaver(
      taskId: task.id,
      notifier: ref.read(backgroundTasksProvider.notifier),
      title: task.title,
      folder: task.resultFolder,
      onSaved: () => unawaited(textNotifier.loadRecords().catchError((_) {})),
    );
    unawaited(
      saver
          .retryTaskResult(allowPartial: !task.resultIsComplete)
          .catchError((_) {}),
    );
  }

  void _navigateToTaskPage(BuildContext context, BackgroundTask task) {
    switch (task.type) {
      case BackgroundTaskType.ocr:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OcrPage(
              retryData: task.retryData,
              retryTaskId: task.id,
              retryPageOutcomes: task.ocrPageOutcomes,
            ),
          ),
        );
        break;
      case BackgroundTaskType.asr:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AsrPage(retryData: task.retryData, retryTaskId: task.id),
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
      case BackgroundTaskType.chat:
        // Chat block: no standalone page — handled within flow execution.
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

  String _taskTypeLabel(BackgroundTaskType type, AppLocalizations strings) =>
      switch (type) {
        BackgroundTaskType.ocr => strings.taskFlowBlockOcr,
        BackgroundTaskType.asr => strings.taskFlowBlockAsr,
        BackgroundTaskType.audioSeparation =>
          strings.taskFlowBlockAudioSeparation,
        BackgroundTaskType.chat => strings.taskFlowBlockChat,
      };

  Widget _taskTypeBadge(
    BackgroundTaskType type,
    ColorScheme cs,
    AppLocalizations strings,
  ) {
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
            _taskTypeLabel(type, strings),
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
      case TaskStatus.waiting:
        return Colors.purple;
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
      case TaskStatus.waiting:
        return Icons.hourglass_empty;
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
    // Waiting uses a static icon (no spinning), handled by the fallback below.
    return Icon(_statusIcon(status), color: _statusColor(status), size: 24);
  }

  static IconData _taskTypeIcon(BackgroundTaskType type) {
    switch (type) {
      case BackgroundTaskType.ocr:
        return Icons.text_snippet;
      case BackgroundTaskType.asr:
        return Icons.multitrack_audio;
      case BackgroundTaskType.audioSeparation:
        return Icons.music_note;
      case BackgroundTaskType.chat:
        return Icons.chat_bubble_outline;
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
      case BackgroundTaskType.chat:
        return Colors.blue;
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
