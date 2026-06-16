import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catcatch/models/media_resource.dart';

// =============================================================================
// 工具函数
// =============================================================================

String formatFileSize(int? bytes) {
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
    builder: (ctx) => MediaPreviewSheet(
      resource: resource,
      taskTitle: taskTitle,
    ),
  );
}

class MediaPreviewSheet extends ConsumerStatefulWidget {
  final MediaResource resource;
  final String taskTitle;

  const MediaPreviewSheet({
    required this.resource,
    required this.taskTitle,
  });

  @override
  ConsumerState<MediaPreviewSheet> createState() => MediaPreviewSheetState();
}

class MediaPreviewSheetState extends ConsumerState<MediaPreviewSheet> {
  Player? _player;
  VideoController? _controller;
  bool _loading = true;
  String? _error;
  File? _tempFile;
  bool _isAudioFormat = false;

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

      _isAudioFormat = isAudioFormat;

      final tempDir = await getTemporaryDirectory();
      final safeName =
          widget.resource.name.replaceAll(RegExp(r'[^\w\-.]'), '_');
      _tempFile = File(p.join(tempDir.path, 'preview_$safeName.$ext'));

      await _downloadToFile(widget.resource.url, _tempFile!);

      if (!mounted) return;

      if (isVideoFormat) {
        _player = Player();
        _controller = VideoController(_player!);
        await _player!.open(Media(Uri.file(_tempFile!.path).toString()));
        if (!mounted) return;
        setState(() => _loading = false);
      } else {
        setState(() => _loading = false);
      }
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
    _player?.dispose();
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

    if (_isAudioFormat) {
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
                formatFileSize(widget.resource.size),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    if (_controller != null && _player != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Video(
          controller: _controller!,
          controls: MaterialVideoControls,
        ),
      );
    }

    return const Center(child: Text('无法加载预览'));
  }
}
