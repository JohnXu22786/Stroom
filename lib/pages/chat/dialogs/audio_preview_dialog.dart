import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Audio preview dialog — plays an audio file using [just_audio].
/// Shows the file name with play/pause controls.
class AudioPreviewDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AudioPreviewDialog({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<AudioPreviewDialog> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final player = AudioPlayer();
      _player = player;
      await player.setFilePath(widget.filePath);
      _duration = player.duration ?? Duration.zero;
      _isInitialized = true;

      _subscriptions.add(player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }));

      _subscriptions.add(player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      }));

      _subscriptions.add(player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && mounted) {
          setState(() => _isPlaying = false);
          player.seek(Duration.zero);
        }
      }));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[AudioPreview] init failed: $e');
      _player?.dispose();
      _player = null;
      if (mounted) setState(() {});
    }
  }

  void _togglePlay() {
    if (_player == null || !_isInitialized) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                Icons.audiotrack_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            if (_isInitialized) ...[
              Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds /
                        _duration.inMilliseconds
                    : 0.0,
                onChanged: (v) {
                  final pos =
                      Duration(milliseconds: (v * _duration.inMilliseconds).round());
                  _player?.seek(pos);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 48,
                    color: cs.primary,
                  ),
                  onPressed: _isInitialized ? _togglePlay : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}
