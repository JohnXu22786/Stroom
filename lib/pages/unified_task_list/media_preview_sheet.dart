import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../catcatch/config/default_rules.dart';
import '../../catcatch/models/media_resource.dart';
import '../../l10n/app_localizations.dart';

const _audioPreviewExtensions = {
  'oga',
  'mp3',
  'wav',
  'm4a',
  'aac',
  'wma',
  'opus',
  'weba',
};

const _videoPreviewExtensions = {'mp4', 'webm', 'ogg', 'mov', 'mkv', 'ogv'};

/// Whether the preview flow treats this resource as audio.
bool isAudioPreviewResource(MediaResource resource) =>
    _audioPreviewExtensions.contains(previewExtensionForResource(resource));

String previewExtensionForResource(MediaResource resource) {
  final ext = resource.ext.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
  final mime = (resource.mimeType ?? '').split(';').first.trim().toLowerCase();
  if (mime == 'audio/ogg') return 'oga';
  if (mime == 'video/ogg') return 'ogg';
  if (mime == 'video/x-theora+ogg') return 'ogv';

  const supported = {..._videoPreviewExtensions, ..._audioPreviewExtensions};
  if (supported.contains(ext)) return ext;
  const mimeExtensions = {
    'video/mp4': 'mp4',
    'video/webm': 'webm',
    'video/ogg': 'ogg',
    'video/x-theora+ogg': 'ogv',
    'video/quicktime': 'mov',
    'video/x-matroska': 'mkv',
    'audio/mpeg': 'mp3',
    'audio/ogg': 'oga',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/x-ms-wma': 'wma',
    'audio/opus': 'opus',
    'audio/webm': 'weba',
  };
  return mimeExtensions[mime] ?? ext;
}

/// 显示媒体预览弹窗
Future<void> showMediaPreview(
  BuildContext context,
  MediaResource resource,
  String taskTitle,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        MediaPreviewSheet(resource: resource, taskTitle: taskTitle),
  );
}

class MediaPreviewSheet extends ConsumerStatefulWidget {
  final MediaResource resource;
  final String taskTitle;
  @visibleForTesting
  final AudioPlayer Function()? audioPlayerFactory;

  const MediaPreviewSheet({
    super.key,
    required this.resource,
    required this.taskTitle,
    this.audioPlayerFactory,
  });

  @override
  ConsumerState<MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewError {
  const _MediaPreviewError.unsupportedFormat()
      : kind = _MediaPreviewErrorKind.unsupportedFormat,
        detail = null;

  const _MediaPreviewError.loadFailed(String error)
      : kind = _MediaPreviewErrorKind.loadFailed,
        detail = error;

  const _MediaPreviewError.playbackFailed(String error)
      : kind = _MediaPreviewErrorKind.playbackFailed,
        detail = error;

  final _MediaPreviewErrorKind kind;
  final String? detail;

  String localizedMessage(AppLocalizations strings) => switch (kind) {
        _MediaPreviewErrorKind.unsupportedFormat =>
          strings.unifiedTaskFormatUnsupported,
        _MediaPreviewErrorKind.loadFailed =>
          strings.unifiedTaskLoadFailed(detail!),
        _MediaPreviewErrorKind.playbackFailed =>
          strings.unifiedTaskPlaybackFailed(detail!),
      };
}

enum _MediaPreviewErrorKind { unsupportedFormat, loadFailed, playbackFailed }

class _MediaPreviewSheetState extends ConsumerState<MediaPreviewSheet> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _loading = true;
  _MediaPreviewError? _previewError;
  File? _tempFile;
  bool _isAudioFormat = false;
  AudioPlayer? _audioPlayer;
  final List<StreamSubscription<dynamic>> _audioSubscriptions = [];
  bool _isAudioPlaying = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initPreview());
    });
  }

  Future<void> _initPreview() async {
    try {
      final resource = widget.resource;
      if (resource.isPlaylist && resource.isM3U8) {
        final headers = <String, String>{
          'User-Agent': DefaultRules.defaultHeaders['User-Agent']!,
          if (resource.initiator != null) 'Referer': resource.initiator!,
        };
        await _initializeVideoPreview(
          VideoPlayerController.networkUrl(
            Uri.parse(resource.url),
            httpHeaders: headers,
          ),
        );
        return;
      }

      final ext = previewExtensionForResource(resource);
      final isVideoFormat = _videoPreviewExtensions.contains(ext);
      final isAudioFormat = _audioPreviewExtensions.contains(ext);

      if (!isVideoFormat && !isAudioFormat) {
        setState(() {
          _loading = false;
          _previewError = const _MediaPreviewError.unsupportedFormat();
        });
        return;
      }

      _isAudioFormat = isAudioFormat;

      if (isAudioFormat) {
        await _initializeAudioPreview(resource);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = widget.resource.name.replaceAll(
        RegExp(r'[^\w\-.]'),
        '_',
      );
      _tempFile = File(p.join(tempDir.path, 'preview_$safeName.$ext'));

      await _downloadToFile(widget.resource.url, _tempFile!);

      if (!mounted) return;

      if (isVideoFormat) {
        final controller = VideoPlayerController.file(_tempFile!);
        _videoPlayerController = controller;
        await controller.initialize();

        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.red,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white24,
          ),
        );

        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (e) {
      // Dispose controller to prevent resource leak on init failure
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _disposeAudioPlayer();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _previewError = _MediaPreviewError.loadFailed(e.toString());
      });
    }
  }

  Future<void> _initializeAudioPreview(MediaResource resource) async {
    final player = widget.audioPlayerFactory?.call() ?? AudioPlayer();
    _audioPlayer = player;

    _audioSubscriptions.add(
      player.positionStream.listen((position) {
        if (mounted) setState(() => _audioPosition = position);
      }, onError: _handleAudioError),
    );
    _audioSubscriptions.add(
      player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _audioDuration = duration);
        }
      }, onError: _handleAudioError),
    );
    _audioSubscriptions.add(
      player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isAudioPlaying = state.playing);
      }, onError: _handleAudioError),
    );
    _audioSubscriptions.add(
      player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && mounted) {
          unawaited(_rewindAudio(player));
        }
      }, onError: _handleAudioError),
    );
    _audioSubscriptions.add(
      player.errorStream.listen((error) => _handleAudioError(error)),
    );

    final headers = <String, String>{
      'User-Agent': DefaultRules.defaultHeaders['User-Agent']!,
      if (resource.initiator != null) 'Referer': resource.initiator!,
    };
    final duration = await player.setAudioSource(
      AudioSource.uri(Uri.parse(resource.url), headers: headers),
    );
    if (!mounted) return;
    setState(() {
      _audioDuration = duration ?? player.duration ?? Duration.zero;
      _loading = false;
    });
  }

  void _handleAudioError(Object error, [StackTrace? stackTrace]) {
    if (!mounted) return;
    _disposeAudioPlayer();
    setState(() {
      _loading = false;
      _previewError = _MediaPreviewError.playbackFailed(error.toString());
    });
  }

  Future<void> _rewindAudio(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
    } catch (e) {
      _handleAudioError(e);
    }
  }

  Future<void> _seekAudio(Duration position) async {
    try {
      await _audioPlayer?.seek(position);
    } catch (e) {
      _handleAudioError(e);
    }
  }

  Future<void> _toggleAudioPlayback() async {
    final player = _audioPlayer;
    if (player == null) return;
    try {
      if (_isAudioPlaying) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (e) {
      _handleAudioError(e);
    }
  }

  void _disposeAudioPlayer() {
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    _audioSubscriptions.clear();
    final player = _audioPlayer;
    _audioPlayer = null;
    if (player != null) unawaited(player.dispose());
  }

  Future<void> _initializeVideoPreview(VideoPlayerController controller) async {
    _videoPlayerController = controller;
    await controller.initialize();
    if (!mounted) return;
    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.red,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white24,
      ),
    );
    setState(() => _loading = false);
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
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      await response.pipe(file.openWrite());
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _disposeAudioPlayer();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
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
          Flexible(child: _buildPreviewContent(context)),
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

    final strings = AppLocalizations.of(context)!;
    final previewError = _previewError;
    if (previewError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                previewError.localizedMessage(strings),
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
              AppLocalizations.of(context)!.unifiedTaskAudioFile,
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
            const SizedBox(height: 20),
            Slider(
              value: _audioDuration.inMilliseconds > 0
                  ? (_audioPosition.inMilliseconds /
                          _audioDuration.inMilliseconds)
                      .clamp(0.0, 1.0)
                      .toDouble()
                  : 0.0,
              onChanged: _audioDuration > Duration.zero
                  ? (value) {
                      final position = Duration(
                        milliseconds:
                            (value * _audioDuration.inMilliseconds).round(),
                      );
                      _seekAudio(position);
                    }
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_audioPosition)),
                Text(_formatDuration(_audioDuration)),
              ],
            ),
            IconButton(
              tooltip: _isAudioPlaying
                  ? AppLocalizations.of(context)!.unifiedTaskPauseAudio
                  : AppLocalizations.of(context)!.unifiedTaskPlayAudio,
              iconSize: 48,
              onPressed: _toggleAudioPlayback,
              icon: Icon(
                _isAudioPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Chewie(controller: _chewieController!),
      );
    }

    return Center(
      child: Text(AppLocalizations.of(context)!.unifiedTaskPreviewLoadFailed),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null)
      return AppLocalizations.of(context)!.unifiedTaskUnknownSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
