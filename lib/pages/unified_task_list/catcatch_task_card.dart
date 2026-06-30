import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catcatch/models/media_resource.dart';
import '../../catcatch/providers/catcatch_provider.dart';
import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../catcatch_page.dart' hide showMediaPreview;
import 'task_utils.dart';
import 'media_preview_sheet.dart';

// =============================================================================
// CatCatch 任务卡片
// =============================================================================

class CatCatchTaskCard extends ConsumerStatefulWidget {
  final catcatch.CatCatchTask task;
  final bool isUnread;

  const CatCatchTaskCard({
    super.key,
    required this.task,
    this.isUnread = false,
  });

  @override
  ConsumerState<CatCatchTaskCard> createState() => _CatCatchTaskCardState();
}

class _CatCatchTaskCardState extends ConsumerState<CatCatchTaskCard> {
  bool _expanded = false;
  final Set<int> _expandedSteps = {};
  final Map<String, Set<String>> _selectedMediaUrls = {};
  final Map<String, String?> _mergeAudioUrls = {};

  Set<String> _getSelectedUrls(String taskId) =>
      _selectedMediaUrls.putIfAbsent(taskId, () => {});

  bool _isSelected(String taskId, String url) =>
      _getSelectedUrls(taskId).contains(url);

  void _toggleSelection(String taskId, String url) {
    setState(() {
      final urls = _getSelectedUrls(taskId);
      if (urls.contains(url)) {
        urls.remove(url);
      } else {
        urls.add(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _expanded = widget.task.status == catcatch.TaskStatus.running;
  }

  @override
  void didUpdateWidget(covariant CatCatchTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.status == catcatch.TaskStatus.running &&
        oldWidget.task.status != catcatch.TaskStatus.running) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case catcatch.TaskStatus.running:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case catcatch.TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case catcatch.TaskStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case catcatch.TaskStatus.paused:
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
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
                  if (task.status == catcatch.TaskStatus.running)
                    _SpinningIcon(
                      icon: statusIcon,
                      color: statusColor,
                      size: 24,
                    )
                  else
                    Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isNotEmpty
                              ? task.title
                              : truncateUrl(task.url),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${task.status.label} · ${task.progress}%',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: task.progress / 100.0,
                          strokeWidth: 3,
                          color: statusColor,
                          backgroundColor: colorScheme.outlineVariant,
                        ),
                        Text(
                          '${task.progress}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildStepTimeline(task, colorScheme),
            ),
            if (task.metadata['pendingConfirm'] == 'special_format')
              _buildSpecialFormatConfirm(task, colorScheme),
            if (task.status == catcatch.TaskStatus.running &&
                task.steps.any(
                  (s) => s.type == catcatch.StepType.userSelecting && s.running,
                ) &&
                task.detectedMedia.isNotEmpty) ...[
              _buildMediaSelection(task, colorScheme),
            ],
            const Divider(height: 1, indent: 12, endIndent: 12),
            _buildActionButtons(task, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildStepTimeline(
    catcatch.CatCatchTask task,
    ColorScheme colorScheme,
  ) {
    final steps = task.steps;

    if (steps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '等待开始...',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: steps.length,
      itemBuilder: (_, i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        final isDetailExpanded = _expandedSteps.contains(i);
        final hasDetail = step.detail != null && step.detail!.isNotEmpty;

        return InkWell(
          onTap: hasDetail
              ? () {
                  setState(() {
                    if (isDetailExpanded) {
                      _expandedSteps.remove(i);
                    } else {
                      _expandedSteps.add(i);
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      stepIcon(step),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: step.skipped
                                ? Colors.orange.shade300
                                : step.completed
                                    ? Colors.green.shade300
                                    : colorScheme.outlineVariant,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.type.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
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
                            ),
                            if (hasDetail)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  isDetailExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (hasDetail && isDetailExpanded) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              step.detail!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ] else if (hasDetail && !isDetailExpanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            step.detail!,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (step.skipped && step.detail == null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '已跳过（无需处理）',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ],
                        if (step.running && step.progress > 0) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: step.progress / 100.0,
                              minHeight: 4,
                              backgroundColor: colorScheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${step.progress}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (step.failed && step.error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            step.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(catcatchTasksProvider.notifier)
                                  .retryStep(task.id, step.type);
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              '重试此步骤',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaSelection(
    catcatch.CatCatchTask task,
    ColorScheme colorScheme,
  ) {
    final mediaList = task.detectedMedia;
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final splitGroups = <String, List<MediaResource>>{};
    for (final m in mediaList) {
      if (m.groupId != null && m.isLikelySplitTrack) {
        splitGroups.putIfAbsent(m.groupId!, () => []).add(m);
      }
    }

    final selectedUrls = _getSelectedUrls(task.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedUrls.isNotEmpty
                ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
                : '检测到 ${mediaList.length} 个媒体资源（点击选择，可多选）',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (splitGroups.isNotEmpty) ...[
            for (final entry in splitGroups.entries)
              _buildSplitTrackGroup(context, task, entry.value, colorScheme),
            const SizedBox(height: 12),
          ],
          ..._buildGroupedMediaList(task, mediaList, colorScheme),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selectedUrls.isNotEmpty
                  ? () {
                      final selectedMediaList = mediaList
                          .where((m) => selectedUrls.contains(m.url))
                          .toList();
                      final notifier = ref.read(catcatchTasksProvider.notifier);
                      final mergeAudio = _mergeAudioUrls[task.id];
                      notifier.batchSelectMedia(
                        task.id,
                        selectedMediaList,
                        mergeAudioUrl: mergeAudio,
                      );
                    }
                  : null,
              icon: const Icon(Icons.download),
              label: Text(
                selectedUrls.isNotEmpty
                    ? '下载选中的 ${selectedUrls.length} 个资源'
                    : '请选择要下载的资源',
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTrackGroup(
    BuildContext context,
    catcatch.CatCatchTask task,
    List<MediaResource> group,
    ColorScheme colorScheme,
  ) {
    final audioResources = group.where((m) => m.isAudio).toList();
    final videoResources = group.where((m) => m.isVideo).toList();

    if (audioResources.isEmpty || videoResources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠ 疑似音视频分离',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '检测到此组资源可能是同一个视频的音频和视频分离的流，'
            '您可以选择合并音视频，或仅下载其中一种。',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
          ),
          const SizedBox(height: 12),
          if (audioResources.isNotEmpty) ...[
            Text(
              '🎵 音频流',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ...audioResources.map(
              (audio) => _buildSplitTrackItem(
                context,
                task,
                audio,
                colorScheme,
                isAudio: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (videoResources.isNotEmpty) ...[
            Text(
              '🎬 视频流',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ...videoResources.map(
              (video) => _buildSplitTrackItem(
                context,
                task,
                video,
                colorScheme,
                isAudio: false,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  final primaryVideo = videoResources.first;
                  setState(() {
                    final urls = _getSelectedUrls(task.id);
                    urls.add(primaryVideo.url);
                    urls.add(audioResources.first.url);
                    _mergeAudioUrls[task.id] = audioResources.first.url;
                  });
                },
                icon: const Icon(Icons.merge, size: 18),
                label: const Text('合并音视频', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    final urls = _getSelectedUrls(task.id);
                    for (final v in videoResources) {
                      urls.add(v.url);
                    }
                    _mergeAudioUrls[task.id] = null;
                  });
                },
                icon: const Icon(Icons.videocam, size: 18),
                label: const Text('仅视频', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    final urls = _getSelectedUrls(task.id);
                    for (final a in audioResources) {
                      urls.add(a.url);
                    }
                    _mergeAudioUrls[task.id] = null;
                  });
                },
                icon: const Icon(Icons.audiotrack, size: 18),
                label: const Text('仅音频', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTrackItem(
    BuildContext context,
    catcatch.CatCatchTask task,
    MediaResource media,
    ColorScheme colorScheme, {
    required bool isAudio,
  }) {
    final isSelected = _isSelected(task.id, media.url);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleSelection(task.id, media.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${media.name}.${media.ext}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                formatSize(media.size),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.play_circle_filled,
                  size: 20,
                  color: media.isPlayable
                      ? colorScheme.primary
                      : Colors.grey.shade300,
                ),
                tooltip: isAudio ? '预览音频' : '预览视频',
                onPressed: media.isPlayable
                    ? () => showMediaPreview(
                          context,
                          media,
                          task.title.isNotEmpty
                              ? task.title
                              : truncateUrl(task.url),
                        )
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedMediaList(
    catcatch.CatCatchTask task,
    List<MediaResource> mediaList,
    ColorScheme colorScheme,
  ) {
    if (mediaList.isEmpty) return [];

    final splitIds = <String>{};
    for (final m in mediaList) {
      if (m.groupId != null && m.isLikelySplitTrack) {
        splitIds.add(m.url);
      }
    }
    final remaining =
        mediaList.where((m) => !splitIds.contains(m.url)).toList();
    if (remaining.isEmpty) return [];

    final withDuration = <MediaResource>[];
    final withoutDuration = <MediaResource>[];
    for (final m in remaining) {
      if (m.duration != null) {
        withDuration.add(m);
      } else {
        withoutDuration.add(m);
      }
    }

    withDuration.sort((a, b) {
      final aSec = parseDurationToSeconds(a.duration!);
      final bSec = parseDurationToSeconds(b.duration!);
      if (aSec == null && bSec == null) return 0;
      if (aSec == null) return 1;
      if (bSec == null) return -1;
      return aSec.compareTo(bSec);
    });

    final widgets = <Widget>[];

    double? lastDurationSec;
    for (final media in withDuration) {
      final currSec = media.duration != null
          ? parseDurationToSeconds(media.duration!)
          : null;
      final showLabel = currSec != null &&
          (lastDurationSec == null || (currSec - lastDurationSec).abs() > 5);
      if (showLabel) {
        lastDurationSec = currSec;
        final durationLabel = formatDurationSimple(media.duration!);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '时长: $durationLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (currSec != null &&
          lastDurationSec != null &&
          (currSec - lastDurationSec).abs() <= 5) {}
      widgets.add(_buildMediaItem(media, task, colorScheme));
    }

    if (withoutDuration.isNotEmpty) {
      if (withDuration.isNotEmpty) {
        widgets.add(const SizedBox(height: 4));
      }
      for (final media in withoutDuration) {
        widgets.add(_buildMediaItem(media, task, colorScheme));
      }
    }

    return widgets;
  }

  Widget _buildMediaItem(
    MediaResource media,
    catcatch.CatCatchTask task,
    ColorScheme colorScheme,
  ) {
    final isSelected = _isSelected(task.id, media.url);
    final ext = media.ext.toLowerCase();
    final isAudioType = [
      'mp3',
      'wav',
      'm4a',
      'aac',
      'opus',
      'weba',
    ].contains(ext);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleSelection(task.id, media.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(
                isAudioType ? Icons.audiotrack : Icons.videocam,
                size: 18,
                color: isAudioType ? Colors.purple : Colors.blue,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? colorScheme.primary : Colors.grey,
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${media.name}.${media.ext}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${formatSize(media.size)} · ${media.mimeType ?? media.ext.toUpperCase()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (media.isLikelySplitTrack) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.call_split,
                            size: 12,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '分轨',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (media.isPlayable)
                IconButton(
                  icon: Icon(
                    Icons.play_circle_filled,
                    color: colorScheme.primary,
                  ),
                  tooltip: isAudioType ? '预览音频' : '预览视频',
                  onPressed: () {
                    showMediaPreview(
                      context,
                      media,
                      task.title.isNotEmpty
                          ? task.title
                          : truncateUrl(task.url),
                    );
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '不支持预览',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialFormatConfirm(
    catcatch.CatCatchTask task,
    ColorScheme colorScheme,
  ) {
    final format = task.metadata['pendingConfirmFormat'] ?? '未知格式';
    final isPlaylist = task.selectedMedia?.isPlaylist ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_suggest,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPlaylist ? '需要处理播放列表' : '检测到特殊格式',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPlaylist
                  ? '该资源是一个播放列表（$format），需要自动解析并下载所有分段后合并为可播放的视频文件。'
                  : '下载的文件格式为 $format，并不是标准的 MP4 格式。需要使用 FFmpeg 自动转换为 MP4。',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(catcatchTasksProvider.notifier)
                          .confirmAndContinue(task.id);
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('自动处理', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(catcatchTasksProvider.notifier)
                          .skipConversion(task.id);
                    },
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('保留原始格式', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    catcatch.CatCatchTask task,
    ColorScheme colorScheme,
  ) {
    final isDownloadingStep = task.steps.any(
      (s) =>
          s.type == catcatch.StepType.downloading && (s.running || s.completed),
    );
    final resumeSupported = task.metadata['resumeSupported'] == 'true';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isDownloadingStep &&
              task.metadata['resumeSupported'] != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    resumeSupported ? Icons.cloud_download : Icons.cloud_off,
                    size: 14,
                    color: resumeSupported ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    resumeSupported ? '支持断点续传' : '该站点不支持断点续传',
                    style: TextStyle(
                      fontSize: 11,
                      color: resumeSupported ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.status == catcatch.TaskStatus.running) ...[
                _actionButton(
                  icon: Icons.pause,
                  label: '暂停下载',
                  color: Colors.orange,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .pauseTask(task.id),
                ),
                _actionButton(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: Colors.red,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .removeTask(task.id),
                ),
              ],
              if (task.status == catcatch.TaskStatus.paused) ...[
                _actionButton(
                  icon: Icons.play_arrow,
                  label: resumeSupported ? '继续下载' : '重新下载',
                  color: Colors.blue,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .resumeTask(task.id),
                ),
                _actionButton(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: Colors.red,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .removeTask(task.id),
                ),
              ],
              if (task.status == catcatch.TaskStatus.completed) ...[
                if (task.downloadedFilePath != null)
                  _actionButton(
                    icon: Icons.folder_open,
                    label: '打开文件',
                    color: Colors.green,
                    onPressed: () => openFile(task.downloadedFilePath!),
                  ),
                _actionButton(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: Colors.red,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .removeTask(task.id),
                ),
              ],
              if (task.status == catcatch.TaskStatus.failed) ...[
                _actionButton(
                  icon: Icons.refresh,
                  label: '重试',
                  color: Colors.blue,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CatCatchPage(
                        initialUrl: task.url,
                        initialDurationSec: task.expectedDurationSec,
                      ),
                    ),
                  ),
                ),
                _actionButton(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: Colors.red,
                  onPressed: () => ref
                      .read(catcatchTasksProvider.notifier)
                      .removeTask(task.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
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
