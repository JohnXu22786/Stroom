import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'video_gallery_web_source.dart';

/// Full-screen video player page using Chewie + video_player (backed by fvp).
class VideoPlayerPage extends StatefulWidget {
  final String filePath;
  final String displayName;

  const VideoPlayerPage({
    super.key,
    required this.filePath,
    required this.displayName,
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
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      } else {
        controller = VideoPlayerController.file(File(widget.filePath));
      }
      _videoPlayerController = controller;
      await controller.initialize();

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
        title: Text(
          widget.displayName,
          style: const TextStyle(color: Colors.white),
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
    _ => 'application/octet-stream',
  };
}
