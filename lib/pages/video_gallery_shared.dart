import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.open(Media(Uri.file(widget.filePath).toString()));
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('VideoPlayerPage init error: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.displayName,
            style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _initialized
            ? Video(
                controller: _controller,
                controls: MaterialVideoControls,
              )
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
