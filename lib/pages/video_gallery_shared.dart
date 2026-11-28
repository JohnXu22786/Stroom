import '../widgets/constrained_text.dart';

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'video_gallery_web_source.dart';

/// Full-screen video player page using Chewie + video_player (backed by fvp).
class VideoPlayerPage extends StatefulWidget {
  final String filePath;
  final String displayName;
  @visibleForTesting
  final VideoPlayerController Function(String source)? controllerFactory;

  const VideoPlayerPage({
    super.key,
    required this.filePath,
    required this.displayName,
    this.controllerFactory,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _initialized = false;
  bool _hasError = false;
  String? _webVideoSource;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      late final VideoPlayerController controller;
      if (kIsWeb) {
        final source = await createVideoGalleryWebSource(
          widget.filePath,
          videoMimeTypeForPath(widget.filePath),
        );
        if (source == null) throw StateError('Stored video is unavailable');
        if (!mounted) {
          revokeVideoGalleryWebSource(source);
          return;
        }
        _webVideoSource = source;
        controller = widget.controllerFactory?.call(source) ??
            VideoPlayerController.networkUrl(Uri.parse(source));
      } else {
        controller = widget.controllerFactory?.call(widget.filePath) ??
            VideoPlayerController.file(File(widget.filePath));
      }
      _videoPlayerController = controller;
      await controller.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('VideoPlayerPage init error: $e');
      // Dispose controller to prevent resource leak on init failure
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      revokeVideoGalleryWebSource(_webVideoSource);
      _webVideoSource = null;
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    revokeVideoGalleryWebSource(_webVideoSource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: ConstrainedText(
          widget.displayName,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.galleryVideoLoadFailed,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            : _initialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String videoMimeTypeForPath(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();
  return switch (extension) {
    'mp4' => 'video/mp4',
    'm4v' => 'video/x-m4v',
    'mov' => 'video/quicktime',
    '3gp' || '3gpp' => 'video/3gpp',
    'webm' => 'video/webm',
    'ogv' => 'video/ogg',
    'flv' => 'video/x-flv',
    'avi' => 'video/x-msvideo',
    'mpeg' || 'mpg' => 'video/mpeg',
    _ => 'application/octet-stream',
  };
}
