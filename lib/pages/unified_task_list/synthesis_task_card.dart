import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/task_provider.dart';
import '../tts_create_page.dart';
import 'task_utils.dart';
import 'file_opener.dart';

// =============================================================================
// 合成任务卡片
// =============================================================================

class SynthesisTaskCard extends ConsumerStatefulWidget {
  final SynthesisTask task;
  final bool isUnread;

  const SynthesisTaskCard(
      {super.key, required this.task, this.isUnread = false});

  @override
  ConsumerState<SynthesisTaskCard> createState() => _SynthesisTaskCardState();
}

class _SynthesisTaskCardState extends ConsumerState<SynthesisTaskCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.task.status == TaskStatus.running;
  }

  @override
  void didUpdateWidget(covariant SynthesisTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.status == TaskStatus.running &&
        oldWidget.task.status != TaskStatus.running) {
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
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  _buildStatusIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title.isNotEmpty
                              ? widget.task.title
                              : '未命名录音',
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
                            buildStatusChip(widget.task.status),
                            const SizedBox(width: 8),
                            Text(
                              formatRelativeTime(widget.task.createdAt),
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
                  // ── Action buttons for running/paused/failed/completed ──
                  _buildHeaderActions(),
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
              ),
            ),
          ),
          // Expanded detail section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedDetail(),
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
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: cs.primary,
          ),
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

  Widget _buildHeaderActions() {
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
                leading:
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                title: Text('清除任务', style: TextStyle(color: Colors.red)),
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
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(taskListProvider.notifier)
                      .resumeTask(widget.task.id);
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
                  ref
                      .read(taskListProvider.notifier)
                      .removeTask(widget.task.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading:
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    title: Text('清除任务', style: TextStyle(color: Colors.red)),
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
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TTSCreatePage(retryTask: widget.task),
                    ),
                  );
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
                if (value == 'remove') {
                  ref
                      .read(taskListProvider.notifier)
                      .removeTask(widget.task.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading:
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    title: Text('清除任务', style: TextStyle(color: Colors.red)),
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
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: () =>
                      openFile(widget.task.downloadedFilePath!, context),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('打开文件', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
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
        );
      case TaskStatus.waiting:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // Expanded detail section
  // ===========================================================================

  Widget _buildExpandedDetail() {
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
                  '合成文本',
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.task.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Status info
              buildInfoRow(cs, Icons.info_outline, '状态',
                  getStatusLabel(widget.task.status)),
              const SizedBox(height: 4),
              buildInfoRow(cs, Icons.access_time, '创建时间',
                  formatRelativeTime(widget.task.createdAt)),
              if (widget.task.completedAt != null) ...[
                const SizedBox(height: 4),
                buildInfoRow(cs, Icons.check_circle_outline, '完成时间',
                    formatRelativeTime(widget.task.completedAt!)),
              ],
              // Error message for failed tasks
              if (widget.task.status == TaskStatus.failed &&
                  widget.task.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                              context, widget.task.error!),
                          child: Text(
                            widget.task.error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (widget.task.originalRequest != null ||
                          widget.task.originalResponse != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              _showOriginalDetailDialog(context, widget.task),
                          child: const Text(
                            '详情',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showErrorDetailDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('合成错误详情'),
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

  void _showOriginalDetailDialog(BuildContext context, SynthesisTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('原始请求与响应'),
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
                  const Text(
                    '原始请求体:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
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
                  const Text(
                    '原始响应体:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
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
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
