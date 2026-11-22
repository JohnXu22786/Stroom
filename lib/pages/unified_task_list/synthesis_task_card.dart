import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/task_provider.dart';
import '../../l10n/app_localizations.dart';
import '../tts_create_page.dart';
import 'task_utils.dart';
import 'file_opener.dart';
import '../../widgets/running_elapsed_label.dart';
import '../../widgets/constrained_text.dart';

// =============================================================================
// 合成任务卡片
// =============================================================================

/// Expansion state retained by the task list while a lazy card is evicted.
class SynthesisTaskCardViewState {
  bool expanded = false;
  bool initialized = false;
}

class SynthesisTaskCard extends ConsumerStatefulWidget {
  final SynthesisTask task;
  final bool isUnread;
  final bool isFlowManaged;
  final SynthesisTaskCardViewState? viewState;

  const SynthesisTaskCard({
    super.key,
    required this.task,
    this.isUnread = false,
    this.isFlowManaged = false,
    this.viewState,
  });

  @override
  ConsumerState<SynthesisTaskCard> createState() => _SynthesisTaskCardState();
}

class _SynthesisTaskCardState extends ConsumerState<SynthesisTaskCard> {
  late SynthesisTaskCardViewState _viewState;
  bool get _expanded => _viewState.expanded;
  set _expanded(bool value) => _viewState.expanded = value;

  @override
  void initState() {
    super.initState();
    _viewState = widget.viewState ?? SynthesisTaskCardViewState();
    // Failed tasks used to show their error box in the header unconditionally;
    // expand by default so the error stays visible in the collapsible design.
    if (!_viewState.initialized) {
      _expanded = widget.task.status == TaskStatus.running ||
          widget.task.status == TaskStatus.failed;
      _viewState.initialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant SynthesisTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewState != widget.viewState && widget.viewState != null) {
      _viewState = widget.viewState!;
      if (!_viewState.initialized) {
        _expanded = widget.task.status == TaskStatus.running ||
            widget.task.status == TaskStatus.failed;
        _viewState.initialized = true;
      }
    }
    if (widget.task.status != oldWidget.task.status &&
        (widget.task.status == TaskStatus.running ||
            widget.task.status == TaskStatus.failed)) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 320;
                  final taskTitle = widget.task.title.isNotEmpty
                      ? widget.task.title
                      : AppLocalizations.of(context)!
                          .unifiedTaskUnnamedRecording;
                  final titleAndMetadata = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedText(
                        taskTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          buildStatusChip(
                            widget.task.status,
                            AppLocalizations.of(context)!,
                          ),
                          Text(
                            formatRelativeTime(
                              widget.task.createdAt,
                              AppLocalizations.of(context)!,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (widget.task.status == TaskStatus.running) ...[
                            // Live elapsed time — lets the user see a
                            // slow-but-working synthesis is still alive.
                            RunningElapsedLabel(
                              startedAt: widget.task.createdAt,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                  final leading = Row(
                    mainAxisSize: MainAxisSize.min,
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
                      _buildStatusIcon(),
                      const SizedBox(width: 12),
                    ],
                  );
                  final trailing = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderActions(context),
                      const SizedBox(width: 4),
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
                  );

                  if (isVeryNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            leading,
                            Expanded(child: titleAndMetadata),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      leading,
                      Expanded(child: titleAndMetadata),
                      const SizedBox(width: 8),
                      trailing,
                    ],
                  );
                },
              ),
            ),
          ),
          // Expanded detail section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedDetail(context),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final cs = Theme.of(context).colorScheme;
    switch (widget.task.status) {
      case TaskStatus.running:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
        );
      case TaskStatus.completed:
        return Icon(Icons.check_circle, color: cs.primary, size: 24);
      case TaskStatus.failed:
        return Icon(Icons.error, color: cs.error, size: 24);
      case TaskStatus.paused:
        return Icon(Icons.pause_circle, color: cs.tertiary, size: 24);
      case TaskStatus.waiting:
        return Icon(Icons.hourglass_empty, color: cs.tertiary, size: 24);
    }
  }

  // ===========================================================================
  // Header action buttons (extracted from old inline code)
  // ===========================================================================

  Widget _buildHeaderActions(BuildContext context) {
    if (widget.isFlowManaged) {
      return widget.task.status == TaskStatus.completed &&
              widget.task.downloadedFilePath != null
          ? IconButton(
              tooltip: AppLocalizations.of(context)!.unifiedTaskOpenFile,
              icon: const Icon(Icons.folder_open),
              onPressed: () =>
                  openFile(widget.task.downloadedFilePath!, context),
            )
          : const SizedBox.shrink();
    }
    switch (widget.task.status) {
      case TaskStatus.running:
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            if (value == 'pause') {
              ref.read(taskListProvider.notifier).pauseTask(widget.task.id);
            } else if (value == 'remove') {
              ref.read(taskListProvider.notifier).removeTask(widget.task.id);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pause',
              child: ListTile(
                leading: Icon(Icons.pause, size: 20),
                title: Text(AppLocalizations.of(context)!.unifiedTaskPause),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'remove',
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context)!.unifiedTaskClearTask,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      case TaskStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ref.read(taskListProvider.notifier).resumeTask(widget.task.id);
              },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(
                AppLocalizations.of(context)!.unifiedTaskContinue,
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'remove') {
                  ref
                      .read(taskListProvider.notifier)
                      .removeTask(widget.task.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.unifiedTaskClearTask,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        );
      case TaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TTSCreatePage(retryTask: widget.task),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                AppLocalizations.of(context)!.unifiedTaskRetry,
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'remove') {
                  ref
                      .read(taskListProvider.notifier)
                      .removeTask(widget.task.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.unifiedTaskClearTask,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        );
      case TaskStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.task.downloadedFilePath != null)
              TextButton.icon(
                onPressed: () =>
                    openFile(widget.task.downloadedFilePath!, context),
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text(
                  AppLocalizations.of(context)!.unifiedTaskOpenFile,
                  style: TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'remove') {
                  ref
                      .read(taskListProvider.notifier)
                      .removeTask(widget.task.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.unifiedTaskRemoveFromList,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        );
      case TaskStatus.waiting:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // Expanded detail section
  // ===========================================================================

  Widget _buildExpandedDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const Divider(height: 1, indent: 12, endIndent: 12),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text content being synthesized
              if (widget.task.text.isNotEmpty) ...[
                Text(
                  AppLocalizations.of(context)!.unifiedTaskSynthesisText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.task.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          tooltip: AppLocalizations.of(context)!
                              .unifiedTaskViewFullSynthesisText,
                          icon: const Icon(Icons.open_in_full),
                          onPressed: () => _showSynthesisTextDialog(
                            context,
                            widget.task.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Status info
              buildInfoRow(
                cs,
                Icons.info_outline,
                AppLocalizations.of(context)!.unifiedTaskStatus,
                getStatusLabel(
                  widget.task.status,
                  AppLocalizations.of(context)!,
                ),
              ),
              const SizedBox(height: 4),
              buildInfoRow(
                cs,
                Icons.access_time,
                AppLocalizations.of(context)!.unifiedTaskCreatedAt,
                formatRelativeTime(
                  widget.task.createdAt,
                  AppLocalizations.of(context)!,
                ),
              ),
              if (widget.task.completedAt != null) ...[
                const SizedBox(height: 4),
                buildInfoRow(
                  cs,
                  Icons.check_circle_outline,
                  AppLocalizations.of(context)!.unifiedTaskCompletedAt,
                  formatRelativeTime(
                    widget.task.completedAt!,
                    AppLocalizations.of(context)!,
                  ),
                ),
              ],
              // Error message for failed tasks
              if (widget.task.status == TaskStatus.failed &&
                  widget.task.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final errorColor = Theme.of(context).colorScheme.error;
                      final errorText = GestureDetector(
                        onTap: () =>
                            _showErrorDetailDialog(context, widget.task.error!),
                        child: Text(
                          widget.task.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: errorColor,
                            height: 1.4,
                          ),
                        ),
                      );
                      final hasDetails = widget.task.originalRequest != null ||
                          widget.task.originalResponse != null;
                      final details = hasDetails
                          ? GestureDetector(
                              onTap: () => _showOriginalDetailDialog(
                                context,
                                widget.task,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!
                                    .unifiedTaskDetails,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: errorColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null;

                      final icon = Icon(
                        Icons.error_outline,
                        size: 14,
                        color: errorColor,
                      );
                      if (constraints.maxWidth < 480) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                icon,
                                const SizedBox(width: 6),
                                Expanded(child: errorText),
                              ],
                            ),
                            if (details != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: details,
                                ),
                              ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 6),
                          Expanded(child: errorText),
                          if (details != null) ...[
                            const SizedBox(width: 4),
                            details,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showSynthesisTextDialog(BuildContext context, String text) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.unifiedTaskSynthesisText),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.unifiedTaskClose),
          ),
        ],
      ),
    );
  }

  void _showErrorDetailDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: ConstrainedText(
                AppLocalizations.of(context)!.unifiedTaskSynthesisError,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
            child: ConstrainedText(
              AppLocalizations.of(context)!.unifiedTaskClose,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showOriginalDetailDialog(BuildContext context, SynthesisTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.code, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.unifiedTaskRawRequestResponse,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.originalRequest != null) ...[
                  Text(
                    AppLocalizations.of(context)!.unifiedTaskRawRequestBody,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      task.originalRequest!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (task.originalResponse != null) ...[
                  Text(
                    AppLocalizations.of(context)!.unifiedTaskRawResponseBody,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      task.originalResponse!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.unifiedTaskClose),
          ),
        ],
      ),
    );
  }
}
