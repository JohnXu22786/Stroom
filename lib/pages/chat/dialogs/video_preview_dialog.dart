import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:stroom/utils/attachment_preview_lifecycle.dart';

import '../../../widgets/constrained_text.dart';

/// Video preview dialog — plays a video file using Chewie + video_player
/// (backed by fvp).
class VideoPreviewDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  const VideoPreviewDialog({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  late final AttachmentPreviewFileLifecycle _previewLifecycle;
  Future<void>? _videoPlayerInitialization;

  @override
  void initState() {
    super.initState();
    _previewLifecycle = AttachmentPreviewFileLifecycle(widget.filePath);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.file(File(widget.filePath));
      _videoPlayerController = controller;
      final initialization = controller.initialize();
      _videoPlayerInitialization = initialization;
      await initialization;
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

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[VideoPreview] init failed: $e');
      final controller = _videoPlayerController;
      _videoPlayerController = null;
      if (mounted) setState(() => _hasError = true);
      _chewieController?.dispose();
      _chewieController = null;
      if (controller != null) {
        await _releasePlayerAndDeletePreview(controller);
      } else if (mounted) {
        await _releasePlayerAndDeletePreview(null);
      }
    }
  }

  Future<void> _releasePlayerAndDeletePreview(
    VideoPlayerController? controller,
  ) {
    return _previewLifecycle.disposePlayerAndDelete(
      () async => controller?.dispose(),
      // A pre-player creation failure leaves the plugin's creation completer
      // unresolved, so dispose would never finish. A reported event error
      // means creation settled and disposing cancels its event subscription.
      shouldDisposePlayer: () =>
          controller != null &&
          (_videoPlayerWasCreated(controller) ||
              controller.value.errorDescription != null),
      initialization: _videoPlayerInitialization,
    );
  }

  bool _videoPlayerWasCreated(VideoPlayerController controller) {
    // video_player exposes this testing-visible sentinel as its only
    // indication that platform player creation has not succeeded.
    // ignore: invalid_use_of_visible_for_testing_member
    return controller.playerId != VideoPlayerController.kUninitializedPlayerId;
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    final controller = _videoPlayerController;
    _videoPlayerController = null;
    unawaited(_releasePlayerAndDeletePreview(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (_chewieController != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Chewie(controller: _chewieController!),
              ),
            )
          else if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.white38, size: 48),
                  SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.chatVideoLoadFailed,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ConstrainedText(
              widget.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
