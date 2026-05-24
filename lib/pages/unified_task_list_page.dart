import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catcatch/models/media_resource.dart';
import '../catcatch/models/catcatch_task.dart' as catcatch;
import '../services/storage_service.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../providers/task_provider.dart';
import 'catcatch_page.dart';
import 'tts_create_page.dart';

String _formatSize(int? bytes) {
  if (bytes == null) return '未知大小';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

void _openFile(String filePath) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $filePath');
      return;
    }
    if (Platform.isWindows) {
      Process.start('explorer', ['/select,', filePath],
          mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      Process.start('open', [filePath], mode: ProcessStartMode.detached);
    } else {
      Process.start('xdg-open', [filePath], mode: ProcessStartMode.detached);
    }
  } catch (e) {
    debugPrint('Failed to open file: $e');
  }
}

String _truncateUrl(String url, {int maxLen = 40}) {
  if (url.length <= maxLen) return url;
  return '${url.substring(0, maxLen ~/ 2)}...${url.substring(url.length - maxLen ~/ 2)}';
}

String _formatDurationSimple(String duration) {
  final sec = _parseDurationToSeconds(duration);
  if (sec == null) return duration;
  if (sec < 60) return '${sec.round()}秒';
  if (sec < 3600) return '${(sec ~/ 60)}分${(sec % 60).round()}秒';
  return '${(sec ~/ 3600)}时${((sec % 3600) ~/ 60)}分';
}

double? _parseDurationToSeconds(String duration) {
  final parts = duration.split(':');
  if (parts.length == 3) {
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  if (parts.length == 2) {
    final m = double.tryParse(parts[0]) ?? 0;
    final s = double.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
  return double.tryParse(duration);
}

Widget _stepIcon(catcatch.StepStatus step) {
  if (step.skipped) {
    return const Icon(Icons.skip_next, color: Colors.orange, size: 20);
  }
  if (step.completed) {
    return const Icon(Icons.check_circle, color: Colors.green, size: 20);
  }
  if (step.running) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (step.failed) {
    return const Icon(Icons.cancel, color: Colors.red, size: 20);
  }
  return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
}

Future<void> showMediaPreview(
  BuildContext context,
  MediaResource resource,
  String taskTitle,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MediaPreviewSheet(
      resource: resource,
      taskTitle: taskTitle,
    ),
  );
}

class _MediaPreviewSheet extends ConsumerStatefulWidget {
  final MediaResource resource;
  final String taskTitle;

  const _MediaPreviewSheet({
    required this.resource,
    required this.taskTitle,
  });

  @override
  ConsumerState<_MediaPreviewSheet> createState() =>
      _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends ConsumerState<_MediaPreviewSheet> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  Future<void> _initPreview() async {
    try {
      final ext = widget.resource.ext.toLowerCase();
      final isVideoFormat =
          ['mp4', 'webm', 'ogg', 'mov', 'mkv', 'ogv'].contains(ext);
      final isAudioFormat =
          ['mp3', 'wav', 'm4a', 'aac', 'wma', 'opus'].contains(ext);

      if (!isVideoFormat && !isAudioFormat) {
        setState(() {
          _loading = false;
          _error = '不支持此格式预览';
        });
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName =
          widget.resource.name.replaceAll(RegExp(r'[^\w\-.]'), '_');
      _tempFile = File(p.join(tempDir.path, 'preview_$safeName.$ext'));

      await _downloadToFile(widget.resource.url, _tempFile!);

      if (!mounted) return;

      if (isVideoFormat) {
        _videoController = VideoPlayerController.file(_tempFile!);
        await _videoController!.initialize();
        if (!mounted) return;
        final theme = Theme.of(context).colorScheme;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          placeholder: Container(color: Colors.black),
          materialProgressColors: ChewieProgressColors(
            playedColor: theme.primary,
            handleColor: theme.primary,
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade100,
          ),
        );
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _downloadToFile(String urlString, File file) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(urlString);
      final request = await client.getUrl(uri);
      if (widget.resource.initiator != null) {
        request.headers.set('Referer', widget.resource.initiator!);
      }
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      await response.pipe(file.openWrite());
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    try {
      if (_tempFile != null && _tempFile!.existsSync()) {
        _tempFile!.deleteSync();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight + bottomInset),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              widget.taskTitle,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _buildPreviewContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final ext = widget.resource.ext.toLowerCase();
    final isAudioFormat =
        ['mp3', 'wav', 'm4a', 'aac', 'wma', 'opus'].contains(ext);

    if (isAudioFormat) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.audio_file,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '音频文件',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.resource.name}.${widget.resource.ext}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (widget.resource.size != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatSize(widget.resource.size),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    if (_chewieController != null && _videoController != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return const Center(child: Text('无法加载预览'));
  }
}

/// 任务列表上次打开时间戳，用于判断未读任务
final taskListLastReadProvider = StateProvider<DateTime>((ref) => DateTime(2000));

Future<void> persistTaskListLastRead(DateTime dt) async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    await file.writeAsString(jsonEncode({'lastRead': dt.toIso8601String()}));
  } catch (e) {
    debugPrint('Failed to persist lastRead: $e');
  }
}

Future<DateTime> loadTaskListLastRead() async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map;
        if (data['lastRead'] != null) {
          return DateTime.parse(data['lastRead'] as String);
        }
      }
    }
  } catch (e) {
    debugPrint('Failed to load lastRead: $e');
  }
  return DateTime(2000);
}

class UnifiedTaskListPage extends ConsumerStatefulWidget {
  const UnifiedTaskListPage({super.key});

  @override
  ConsumerState<UnifiedTaskListPage> createState() =>
      _UnifiedTaskListPageState();
}

class _UnifiedTaskListPageState extends ConsumerState<UnifiedTaskListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 打开列表即标记已读
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final now = DateTime.now();
        ref.read(taskListLastReadProvider.notifier).state = now;
        persistTaskListLastRead(now);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);

    final allTasks = <_UnifiedTaskItem>[
      for (final t in catcatchTasks)
        _UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isCatCatch: true,
          catCatchTask: t,
        ),
      for (final t in synthesisTasks)
        _UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isCatCatch: false,
          synthesisTask: t,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_completed') {
                for (final t in catcatchTasks) {
                  if (t.status.name == 'completed') {
                    ref.read(catcatchTasksProvider.notifier).removeTask(t.id);
                  }
                }
                for (final t in synthesisTasks) {
                  if (t.status.name == 'completed') {
                    ref.read(taskListProvider.notifier).removeTask(t.id);
                  }
                }
              } else if (value == 'clear_failed') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('确定要清除所有失败任务吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          for (final t in catcatchTasks) {
                            if (t.status.name == 'failed') {
                              ref
                                  .read(catcatchTasksProvider.notifier)
                                  .removeTask(t.id);
                            }
                          }
                          for (final t in synthesisTasks) {
                            if (t.status.name == 'failed') {
                              ref
                                  .read(taskListProvider.notifier)
                                  .removeTask(t.id);
                            }
                          }
                        },
                        child: const Text('确定',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else if (value == 'clear_all') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('确定要清除所有任务吗？此操作不可撤销。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          for (final t in catcatchTasks) {
                            ref
                                .read(catcatchTasksProvider.notifier)
                                .removeTask(t.id);
                          }
                          for (final t in synthesisTasks) {
                            ref
                                .read(taskListProvider.notifier)
                                .removeTask(t.id);
                          }
                        },
                        child: const Text('确定',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services, size: 20),
                  title: Text('清除已完成'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_failed',
                child: ListTile(
                  leading:
                      Icon(Icons.error_outline, size: 20, color: Colors.red),
                  title: Text('清除失败任务',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  title: Text('清除所有',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '下载'),
            Tab(text: '合成'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(allTasks, '全部'),
          _buildTabContent(
            allTasks.where((t) => t.isCatCatch).toList(),
            '下载',
          ),
          _buildTabContent(
            allTasks.where((t) => !t.isCatCatch).toList(),
            '合成',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<_UnifiedTaskItem> tasks, String tabLabel) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabLabel == '下载'
                  ? Icons.cloud_download_outlined
                  : tabLabel == '合成'
                      ? Icons.graphic_eq
                      : Icons.pending_actions,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无任务',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final item = tasks[i];
        final lastRead = ref.watch(taskListLastReadProvider);
        if (item.isCatCatch) {
          final t = item.catCatchTask!;
          final isUnread = (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
          return _CatCatchTaskCard(task: t, isUnread: isUnread);
        }
        final t = item.synthesisTask!;
        final isUnread = (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
        return _SynthesisTaskCard(task: t, isUnread: isUnread);
      },
    );
  }
}

class _UnifiedTaskItem {
  final String id;
  final DateTime createdAt;
  final bool isCatCatch;
  final catcatch.CatCatchTask? catCatchTask;
  final SynthesisTask? synthesisTask;

  const _UnifiedTaskItem({
    required this.id,
    required this.createdAt,
    required this.isCatCatch,
    this.catCatchTask,
    this.synthesisTask,
  });
}

// =============================================================================
// CatCatch 任务卡片
// =============================================================================

class _CatCatchTaskCard extends ConsumerStatefulWidget {
  final catcatch.CatCatchTask task;
  final bool isUnread;

  const _CatCatchTaskCard({required this.task, this.isUnread = false});

  @override
  ConsumerState<_CatCatchTaskCard> createState() => _CatCatchTaskCardState();
}

class _CatCatchTaskCardState extends ConsumerState<_CatCatchTaskCard> {
  bool _expanded = false;
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
  void didUpdateWidget(covariant _CatCatchTaskCard oldWidget) {
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
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isNotEmpty
                              ? task.title
                              : _truncateUrl(task.url),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: statusColor),
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
                task.steps.any((s) =>
                    s.type == catcatch.StepType.userSelecting && s.running) &&
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
      catcatch.CatCatchTask task, ColorScheme colorScheme) {
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

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    _stepIcon(step),
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
                      Text(
                        step.type.label,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      if (step.skipped) ...[
                        const SizedBox(height: 4),
                        Text(
                          '已跳过（无需处理）',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade400),
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
                          label: const Text('重试此步骤',
                              style: TextStyle(fontSize: 12)),
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
        );
      },
    );
  }

  Widget _buildMediaSelection(
      catcatch.CatCatchTask task, ColorScheme colorScheme) {
    final mediaList = task.detectedMedia;
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final autoSelected = mediaList.length == 1;

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
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (splitGroups.isNotEmpty) ...[
            for (final entry in splitGroups.entries)
              _buildSplitTrackGroup(
                context,
                task,
                entry.value,
                colorScheme,
              ),
            const SizedBox(height: 12),
          ],
          ..._buildGroupedMediaList(task, mediaList, colorScheme),
          if (!autoSelected) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedUrls.isNotEmpty
                    ? () {
                        final selectedMediaList = mediaList
                            .where((m) => selectedUrls.contains(m.url))
                            .toList();
                        final notifier =
                            ref.read(catcatchTasksProvider.notifier);
                        final mergeAudio = _mergeAudioUrls[task.id];
                        notifier.batchSelectMedia(
                          task.id,
                          selectedMediaList,
                          mergeAudioUrl: mergeAudio,
                        );
                      }
                    : null,
                icon: const Icon(Icons.download),
                label: Text(selectedUrls.isNotEmpty
                    ? '下载选中的 ${selectedUrls.length} 个资源'
                    : '请选择要下载的资源'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
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
            Text('🎵 音频流',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...audioResources.map((audio) => _buildSplitTrackItem(
                  context,
                  task,
                  audio,
                  colorScheme,
                  isAudio: true,
                )),
          ],
          const SizedBox(height: 8),
          if (videoResources.isNotEmpty) ...[
            Text('🎬 视频流',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...videoResources.map((video) => _buildSplitTrackItem(
                  context,
                  task,
                  video,
                  colorScheme,
                  isAudio: false,
                )),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                isSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
                _formatSize(media.size),
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                              : _truncateUrl(task.url),
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
      final aSec = _parseDurationToSeconds(a.duration!);
      final bSec = _parseDurationToSeconds(b.duration!);
      if (aSec == null && bSec == null) return 0;
      if (aSec == null) return 1;
      if (bSec == null) return -1;
      return aSec.compareTo(bSec);
    });

    final widgets = <Widget>[];

    double? lastDurationSec;
    for (final media in withDuration) {
      final currSec = media.duration != null
          ? _parseDurationToSeconds(media.duration!)
          : null;
      final showLabel = currSec != null &&
          (lastDurationSec == null || (currSec - lastDurationSec).abs() > 5);
      if (showLabel) {
        lastDurationSec = currSec;
        final durationLabel = _formatDurationSimple(media.duration!);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: colorScheme.onSurfaceVariant),
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
          (currSec - lastDurationSec).abs() <= 5) {
      }
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
    final isAudioType =
        ['mp3', 'wav', 'm4a', 'aac', 'opus', 'weba'].contains(ext);

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
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_formatSize(media.size)} · ${media.mimeType ?? media.ext.toUpperCase()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (media.isLikelySplitTrack) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.call_split,
                              size: 12, color: Colors.amber.shade600),
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
                          : _truncateUrl(task.url),
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
      catcatch.CatCatchTask task, ColorScheme colorScheme) {
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
                Icon(Icons.settings_suggest,
                    size: 20, color: Colors.blue.shade700),
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
                  height: 1.4),
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
                    label:
                        const Text('自动处理', style: TextStyle(fontSize: 13)),
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
                    label: const Text(
                      '保留原始格式',
                      style: TextStyle(fontSize: 13),
                    ),
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
      catcatch.CatCatchTask task, ColorScheme colorScheme) {
    final isDownloadingStep = task.steps.any(
      (s) =>
          s.type == catcatch.StepType.downloading &&
          (s.running || s.completed),
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
                    resumeSupported
                        ? Icons.cloud_download
                        : Icons.cloud_off,
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
                    onPressed: () => _openFile(task.downloadedFilePath!),
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
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// =============================================================================
// 合成任务卡片
// =============================================================================

class _SynthesisTaskCard extends ConsumerWidget {
  final SynthesisTask task;
  final bool isUnread;

  const _SynthesisTaskCard({required this.task, this.isUnread = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isUnread)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
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
                  if (task.status == TaskStatus.failed &&
                      task.error != null)
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
                            if (task.originalRequest != null ||
                                task.originalResponse != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _showOriginalDetailDialog(
                                    context, task),
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
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (task.status == TaskStatus.running)
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
                      leading:
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      title: Text('清除任务',
                          style: TextStyle(color: Colors.red)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            if (task.status == TaskStatus.paused)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(taskListProvider.notifier)
                            .resumeTask(task.id);
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label:
                          const Text('继续', style: TextStyle(fontSize: 13)),
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
                          leading: Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          title: Text('清除任务',
                              style: TextStyle(color: Colors.red)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (task.status == TaskStatus.failed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TTSCreatePage(
                              retryTask: task,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label:
                          const Text('重试', style: TextStyle(fontSize: 13)),
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
                          leading: Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          title: Text('清除任务',
                              style: TextStyle(color: Colors.red)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (task.status == TaskStatus.completed)
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
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case TaskStatus.running:
        return const SizedBox(
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
