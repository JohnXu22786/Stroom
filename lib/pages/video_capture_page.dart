import 'dart:async';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import '../providers/video_provider.dart';
import '../utils/video_manifest.dart';

class VideoCapturePage extends ConsumerStatefulWidget {
  final String folder;

  const VideoCapturePage({super.key, this.folder = ''});

  @override
  ConsumerState<VideoCapturePage> createState() => _VideoCapturePageState();
}

class _VideoCapturePageState extends ConsumerState<VideoCapturePage> {
  bool _isFrontCamera = false;
  bool _isRecording = false;
  int _recordingDurationMs = 0;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    super.dispose();
  }

  void _startTimer() {
    _recordingDurationMs = 0;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _recordingDurationMs += 100);
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final hundredths = (ms % 1000) ~/ 10;
    return '${_pad(minutes)}:${_pad(seconds)}.${_pad(hundredths)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ====================================================================
  // Camera controls
  // ====================================================================

  void _toggleCamera(CameraState state) {
    setState(() => _isFrontCamera = !_isFrontCamera);
    state.switchCameraSensor();
  }

  Future<void> _toggleRecording(CameraState state) async {
    if (_isRecording) {
      // Stop recording
      state.when(
        onVideoRecordingMode: (recordingState) async {
          try {
            await recordingState.stopRecording(
              onVideo: (request) {
                request.when(
                  single: (single) {
                    final filePath = single.file?.path;
                    if (filePath != null) {
                      _saveVideoFromPath(filePath);
                    }
                  },
                );
              },
              onVideoFailed: (exception) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('录像保存失败: $exception'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('停止录像失败: $e'),
                    backgroundColor: Colors.red),
              );
            }
          }
          _stopTimer();
          if (mounted) {
            setState(() => _isRecording = false);
          }
        },
      );
    } else {
      // Start recording
      state.when(
        onVideoMode: (videoState) async {
          try {
            await videoState.startRecording();
            if (mounted) {
              setState(() => _isRecording = true);
              _startTimer();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('开始录像失败: $e'),
                    backgroundColor: Colors.red),
              );
            }
          }
        },
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickVideo(source: ImageSource.gallery);
      if (xFile == null || !mounted) return;
      await _saveVideo(xFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择视频失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Called when camerawesome finishes saving a recorded video.
  /// The [filePath] points to a temporary file written by camerawesome.
  void _saveVideoFromPath(String filePath) {
    // Reuse _saveVideo by wrapping the path in an XFile.
    _saveVideo(XFile(filePath));
  }

  Future<void> _saveVideo(XFile videoFile) async {
    try {
      final now = DateTime.now();
      final displayName =
          '视频_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final videoBytes = await videoFile.readAsBytes();
      var format = p.extension(videoFile.path).replaceAll('.', '');
      if (format.isEmpty) format = 'mp4';
      final hash = computeVideoHash(videoBytes);

      // Write video file and get local path (for thumbnail generation)
      String? videoPath;
      try {
        videoPath = await VideoManifest.writeFile('$hash.$format', videoBytes);
      } catch (_) {}

      // Generate video thumbnail
      if (videoPath != null && videoPath.isNotEmpty) {
        try {
          final thumbBytes = await VideoThumbnail.thumbnailData(
            video: videoPath,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 256,
            quality: 75,
            timeMs: 1000,
          );
          if (thumbBytes != null) {
            await VideoManifest.writeThumbnail(hash, thumbBytes);
          }
        } catch (e) {
          debugPrint('_saveVideo thumbnail error: $e');
        }
      }

      final record = VideoRecord(
        name: displayName,
        hash: hash,
        format: format,
        createdAt: DateTime.now(),
        size: videoBytes.length,
        duration: _recordingDurationMs,
        folder: widget.folder,
      );
      await VideoManifest.addRecord(record);
      ref.read(videoRecordsProvider.notifier).loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('视频已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('保存视频失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ====================================================================
  // UI builders
  // ====================================================================

  Widget _buildLoadingUI() {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildVideoUI(CameraState state) {
    return Stack(
      children: [
        // Recording timer (top)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordingDurationMs),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Bottom overlay
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pick from gallery
                  IconButton(
                    onPressed: _isRecording ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 32),
                  // Record button
                  GestureDetector(
                    onTap: () => _toggleRecording(state),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: _isRecording
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : const Icon(Icons.videocam,
                                color: Colors.red, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Toggle camera
                  IconButton(
                    onPressed: _isRecording ? null : () => _toggleCamera(state),
                    icon: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.custom(
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(
            _isFrontCamera ? SensorPosition.front : SensorPosition.back,
          ),
          aspectRatio: CameraAspectRatios.ratio_16_9,
        ),
        saveConfig: SaveConfig.video(),
        builder: (state, _) {
          return state.when(
            onPreparingCamera: (_) => _buildLoadingUI(),
            onVideoMode: (_) => _buildVideoUI(state),
            onVideoRecordingMode: (_) => _buildVideoUI(state),
            onPhotoMode: (_) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
