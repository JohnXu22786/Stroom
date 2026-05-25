import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catcatch/models/media_resource.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../utils/duration_parser.dart';
import 'browser_page.dart';
import 'unified_task_list_page.dart';

// =============================================================================
// 工具函数
// =============================================================================

String _formatSize(int? bytes) {
  if (bytes == null) return '未知大小';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

// =============================================================================
// 预览弹出框
// =============================================================================

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

// =============================================================================
// 主页面
// =============================================================================

class CatCatchPage extends ConsumerStatefulWidget {
  final String? initialUrl;
  final int? initialDurationSec;

  const CatCatchPage({super.key, this.initialUrl, this.initialDurationSec});

  @override
  ConsumerState<CatCatchPage> createState() => _CatCatchPageState();
}

class _CatCatchPageState extends ConsumerState<CatCatchPage> {
  final _urlController = TextEditingController();
  final _durationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _durationDisplay = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
    }
    if (widget.initialDurationSec != null && widget.initialDurationSec! > 0) {
      final totalSec = widget.initialDurationSec!;
      final h = totalSec ~/ 3600;
      final m = (totalSec % 3600) ~/ 60;
      final s = totalSec % 60;
      final parts = <String>[];
      if (h > 0) parts.add(h.toString());
      parts.add(m.toString());
      parts.add(s.toString());
      _durationController.text = parts.join(' ');
      _updateDurationDisplay();
    }
    _durationController.addListener(_updateDurationDisplay);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _updateDurationDisplay() {
    final parsed = parseSmartDuration(_durationController.text);
    if (parsed == null) {
      setState(() => _durationDisplay = '');
      return;
    }
    setState(() => _durationDisplay = formatDurationDisplay(parsed));
  }

  _DurationResult? _parseDurationInput(String text) {
    final result = parseSmartDuration(text);
    if (result == null) return null;
    return _DurationResult(
      hours: result.hours,
      minutes: result.minutes,
      seconds: result.seconds,
    );
  }

  void _startTask() {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final parsed = _parseDurationInput(_durationController.text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的时长（时 分 秒 用空格分隔）'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final totalSec = parsed.hours * 3600 + parsed.minutes * 60 + parsed.seconds;

    if (totalSec <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入视频时长'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      ref.read(catcatchTasksProvider.notifier).addTask(url, totalSec);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分析失败: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('任务已添加'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '查看任务列表',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UnifiedTaskListPage(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('获取网页视频'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.language, size: 20),
            tooltip: '内置浏览器',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BrowserPage(initialUrl: 'https://www.google.com'),
              ),
            ),
          ),
        ],
      ),
      body: _buildInputSection(colorScheme),
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

            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: '时长（时 分 秒 用空格分隔，如 "2 30" 或 "90" 或 "1 0 30"）',
                labelText: '视频时长',
                prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixText: _durationDisplay.isNotEmpty ? _durationDisplay : null,
                suffixStyle: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _startTask(),
            ),

            const SizedBox(height: 12),

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
      ),
    );
  }
}

class _DurationResult {
  final int hours;
  final int minutes;
  final int seconds;
  const _DurationResult({required this.hours, required this.minutes, required this.seconds});
}
