import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:stroom/utils/attachment_preview_lifecycle.dart';

import '../../../widgets/constrained_text.dart';

/// Audio preview dialog — plays an audio file using [just_audio].
/// Shows the file name with play/pause controls.
class AudioPreviewDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  /// Overrides player creation in widget tests.
  final AudioPlayer Function()? playerFactory;

  const AudioPreviewDialog({
    super.key,
    required this.filePath,
    required this.fileName,
    this.playerFactory,
  });

  @override
  State<AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<AudioPreviewDialog> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _hasInitializationError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subscriptions = [];
  late final AttachmentPreviewFileLifecycle _previewLifecycle;

  @override
  void initState() {
    super.initState();
    _previewLifecycle = AttachmentPreviewFileLifecycle(widget.filePath);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final player = widget.playerFactory?.call() ?? AudioPlayer();
      _player = player;
      await player.setFilePath(widget.filePath);
      if (!mounted) return;
      _duration = player.duration ?? Duration.zero;
      _isInitialized = true;

      _subscriptions.add(
        player.positionStream.listen((pos) {
          if (mounted) setState(() => _position = pos);
        }),
      );

      _subscriptions.add(
        player.playerStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _isPlaying = state.playing;
            });
          }
        }),
      );

      _subscriptions.add(
        player.processingStateStream.listen((state) {
          if (state == ProcessingState.completed && mounted) {
            setState(() => _isPlaying = false);
            player.seek(Duration.zero);
          }
        }),
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[AudioPreview] init failed: $e');
      final player = _player;
      _player = null;
      if (player != null) {
        try {
          await player.dispose();
        } catch (disposeError) {
          debugPrint(
            '[AudioPreview] failed player disposal failed: $disposeError',
          );
        }
      }
      if (mounted) setState(() => _hasInitializationError = true);
    }
  }

  Future<void> _retryInitialization() async {
    setState(() => _hasInitializationError = false);
    await _initPlayer();
  }

  void _togglePlay() {
    if (_player == null || !_isInitialized) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  Future<void> _releasePlayerAndDeletePreview(AudioPlayer? player) {
    return _previewLifecycle.disposePlayerAndDelete(
      () async => player?.dispose(),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    final player = _player;
    _player = null;
    unawaited(_releasePlayerAndDeletePreview(player));
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
            ConstrainedText(
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
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0.0,
                onChanged: (v) {
                  final pos = Duration(
                    milliseconds: (v * _duration.inMilliseconds).round(),
                  );
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
            ] else if (_hasInitializationError)
              Column(
                children: [
                  Icon(Icons.error_outline, color: cs.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.chatPreviewLoadFailed,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _retryInitialization,
                    child: ConstrainedText(
                      AppLocalizations.of(context)!.actionRetry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
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
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
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
              child: ConstrainedText(
                AppLocalizations.of(context)!.chatAudioPreviewClose,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
