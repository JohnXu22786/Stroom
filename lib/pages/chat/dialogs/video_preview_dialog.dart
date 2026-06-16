import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Video preview dialog — plays a video file using [media_kit].
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
  Player? _player;
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final player = Player();
      _player = player;
      _controller = VideoController(player);
      await player.open(Media(widget.filePath));
    } catch (e) {
      debugPrint('[VideoPreview] init failed: $e');
      _player?.dispose();
      _player = null;
      _controller = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (_controller != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Video(
                  controller: _controller!,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                _player?.stop();
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
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
