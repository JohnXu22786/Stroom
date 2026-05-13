import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catcatch/models/media_resource.dart';
import '../catcatch/models/catcatch_task.dart';
import '../catcatch/providers/catcatch_provider.dart';

// =============================================================================
// 工具函数
// =============================================================================

/// 格式化字节数为可读字符串
String _formatSize(int? bytes) {
  if (bytes == null) return '未知大小';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// 使用系统默认应用打开文件
void _openFile(String filePath) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $filePath');
      return;
    }
    // Windows: explorer /select,  macOS: open,  Linux: xdg-open
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

/// 截断 URL 显示
String _truncateUrl(String url, {int maxLen = 40}) {
  if (url.length <= maxLen) return url;
  return '${url.substring(0, maxLen ~/ 2)}...${url.substring(url.length - maxLen ~/ 2)}';
}

// =============================================================================
// 步骤图标映射
// =============================================================================

Widget _stepIcon(StepStatus step) {
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
  // pending
  return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
}

// =============================================================================
// 预览弹出框
// =============================================================================

/// 显示媒体预览底部弹出框
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
  ConsumerState<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
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

      // 下载到临时文件
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
      // 设置 referer
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
    // 清理预览临时文件
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
          // 拖拽指示条
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
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
          // 内容
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

    // 视频预览
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

// =============================================================================
// 主页面
// =============================================================================

class CatCatchPage extends ConsumerStatefulWidget {
  const CatCatchPage({super.key});

  @override
  ConsumerState<CatCatchPage> createState() => _CatCatchPageState();
}

class _CatCatchPageState extends ConsumerState<CatCatchPage> {
  final _urlController = TextEditingController();
  final _durationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 添加任务
  // ===========================================================================

  void _startTask() {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final durationSec = int.tryParse(_durationController.text.trim()) ?? 0;

    ref.read(catcatchTasksProvider.notifier).addTask(url, durationSec);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('任务已开始，执行过程中请勿退出应用'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 清空输入，保留 URL 便于后续操作
    _durationController.clear();
  }

  // ===========================================================================
  // 构建
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(catcatchTasksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('获取网页视频'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // ---------- 输入区域 ----------
          _buildInputSection(colorScheme),
          const Divider(height: 1),

          // ---------- 任务列表 ----------
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: tasks.length,
                    itemBuilder: (_, index) => _TaskCard(task: tasks[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL 输入
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: '请输入视频/音频网页URL',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入URL';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return '请输入有效的URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 时长输入 + 按钮
            Row(
              children: [
                // 时长输入
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      hintText: '期望时长（秒）',
                      prefixIcon: const Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _startTask(),
                  ),
                ),
                const SizedBox(width: 12),

                // 开始分析按钮
                FilledButton.icon(
                  onPressed: _startTask,
                  icon: const Icon(Icons.search),
                  label: const Text('开始分析'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无任务',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在上方输入URL开始分析网页中的媒体资源',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 任务卡片
// =============================================================================

class _TaskCard extends ConsumerStatefulWidget {
  final CatCatchTask task;

  const _TaskCard({required this.task});

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _expanded = false;
  // 本地状态：每个任务当前选中的 media（仅 UI 选中，确认下载时才触发 provider）
  final Map<String, MediaResource?> _selectedMedia = {};

  @override
  void initState() {
    super.initState();
    // 运行中的任务默认展开
    _expanded = widget.task.status == TaskStatus.running;
  }

  @override
  void didUpdateWidget(covariant _TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果任务变为运行中且当前折叠，自动展开
    if (widget.task.status == TaskStatus.running &&
        oldWidget.task.status != TaskStatus.running) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final colorScheme = Theme.of(context).colorScheme;

    // 状态颜色
    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case TaskStatus.running:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TaskStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case TaskStatus.paused:
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
          // ---------- 标题栏（可点击展开/折叠） ----------
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 状态图标
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),

                  // URL + 标题
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${task.status.label} · ${task.progress}%',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 进度百分比（圆形）
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

                  // 展开箭头
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

          // ---------- 展开内容 ----------
          if (_expanded) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),

            // 步骤列表（Timeline 风格）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildStepTimeline(task, colorScheme),
            ),

            // 检测到的媒体资源（userSelecting 步骤时显示）
            if (task.status == TaskStatus.running &&
                task.steps.any(
                    (s) => s.type == StepType.userSelecting && s.running) &&
                task.detectedMedia.isNotEmpty) ...[
              _buildMediaSelection(task, colorScheme),
            ],

            // 底部操作按钮
            const Divider(height: 1, indent: 12, endIndent: 12),
            _buildActionButtons(task, colorScheme),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 步骤时间线
  // ===========================================================================

  Widget _buildStepTimeline(CatCatchTask task, ColorScheme colorScheme) {
    final steps = task.steps;

    // 如果步骤列表为空，显示初始状态
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
              // 左侧：图标 + 竖线
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    _stepIcon(step),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: step.completed
                              ? Colors.green.shade300
                              : colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 右侧：步骤内容
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.type.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: step.completed
                                  ? Colors.green.shade700
                                  : step.running
                                      ? colorScheme.primary
                                      : step.failed
                                          ? Colors.red.shade700
                                          : colorScheme.onSurface,
                            ),
                      ),

                      // 进度条（进行中）
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

                      // 错误信息（失败）
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
                        // 重试此步骤按钮
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

  // ===========================================================================
  // 媒体资源选择区域
  // ===========================================================================

  Widget _buildMediaSelection(CatCatchTask task, ColorScheme colorScheme) {
    final mediaList = task.detectedMedia;
    if (mediaList.isEmpty) return const SizedBox.shrink();

    // 如果只有一个资源，自动选择
    final autoSelected = mediaList.length == 1;
    // 使用本地状态存储 UI 选中，仅在"确认下载"时通知 provider
    // 仅在 provider 有值时同步到本地，避免覆盖用户正在做的选择
    if (task.selectedMedia != null) {
      _selectedMedia[task.id] = task.selectedMedia;
    }
    final selectedMedia = _selectedMedia[task.id];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '检测到 ${mediaList.length} 个媒体资源',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),

          // 媒体列表
          ...mediaList.map((media) {
            final isSelected = selectedMedia?.url == media.url;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (!autoSelected) {
                    setState(() {
                      _selectedMedia[task.id] = media;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // 单选按钮（仅多资源时显示）
                      if (!autoSelected)
                        Icon(
                          selectedMedia?.url == media.url
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedMedia?.url == media.url
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          size: 20,
                        ),

                      // 文件信息
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
                            Text(
                              '${_formatSize(media.size)} · ${media.mimeType ?? media.ext.toUpperCase()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      // 预览按钮
                      if (media.isPlayable)
                        IconButton(
                          icon: Icon(
                            Icons.play_circle_filled,
                            color: colorScheme.primary,
                          ),
                          tooltip: '预览',
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 确认下载按钮（多资源时显示）
          if (!autoSelected) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedMedia != null
                    ? () => ref
                        .read(catcatchTasksProvider.notifier)
                        .selectMedia(task.id, selectedMedia)
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('确认下载'),
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

  // ===========================================================================
  // 底部操作按钮
  // ===========================================================================

  Widget _buildActionButtons(CatCatchTask task, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ----- 运行中 -----
          if (task.status == TaskStatus.running) ...[
            _actionButton(
              icon: Icons.pause,
              label: '暂停',
              color: Colors.orange,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).pauseTask(task.id),
            ),
            _actionButton(
              icon: Icons.delete_outline,
              label: '删除',
              color: Colors.red,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).removeTask(task.id),
            ),
          ],

          // ----- 已暂停 -----
          if (task.status == TaskStatus.paused) ...[
            _actionButton(
              icon: Icons.play_arrow,
              label: '继续',
              color: Colors.blue,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).resumeTask(task.id),
            ),
            _actionButton(
              icon: Icons.delete_outline,
              label: '删除',
              color: Colors.red,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).removeTask(task.id),
            ),
          ],

          // ----- 已完成 -----
          if (task.status == TaskStatus.completed) ...[
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
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).removeTask(task.id),
            ),
          ],

          // ----- 已失败 -----
          if (task.status == TaskStatus.failed) ...[
            _actionButton(
              icon: Icons.refresh,
              label: '重试',
              color: Colors.blue,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).retryTask(task.id),
            ),
            _actionButton(
              icon: Icons.delete_outline,
              label: '删除',
              color: Colors.red,
              onPressed: () =>
                  ref.read(catcatchTasksProvider.notifier).removeTask(task.id),
            ),
          ],
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
