import 'dart:async';
import 'package:camera/camera.dart' hide ImageFormat;
import 'package:flutter/foundation.dart' show debugPrint;
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

class _VideoCapturePageState extends ConsumerState<VideoCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  int _recordingDurationMs = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initCamera();
    } else if (state == AppLifecycleState.paused) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _controller?.dispose();
      _controller = null;
    }
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final camera = _isFrontCamera
          ? _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras!.first,
            )
          : _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras!.first,
            );

      _controller =
          CameraController(camera, ResolutionPreset.high, enableAudio: true);
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (_) {}
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() => _isFrontCamera = !_isFrontCamera);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _initCamera();
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

  Future<void> _toggleRecording() async {
    if (!_isInitialized || _controller == null) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (_controller!.value.isRecordingVideo) return;
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() => _isRecording = true);
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始录像失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_controller!.value.isRecordingVideo) return;
      final xFile = await _controller!.stopVideoRecording();
      _stopTimer();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      await _saveVideo(xFile);
    } catch (e) {
      _stopTimer();
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止录像失败: $e'), backgroundColor: Colors.red),
        );
      }
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

  Future<void> _saveVideo(XFile videoFile) async {
    try {
      final now = DateTime.now();
      final displayName =
          '视频_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final videoBytes = await videoFile.readAsBytes();
      var format = p.extension(videoFile.path).replaceAll('.', '');
      if (format.isEmpty) format = 'mp4';
      final hash = computeVideoHash(videoBytes);

      // 写入视频文件并获取本地路径（用于生成缩略图）
      String? videoPath;
      try {
        videoPath = await VideoManifest.writeFile('$hash.$format', videoBytes);
      } catch (_) {}

      // 生成视频缩略图
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
          SnackBar(content: Text('保存视频失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview or loading indicator
        if (_isInitialized && _controller != null)
          Positioned.fill(child: CameraPreview(_controller!))
        else
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),

        // Top overlay: close button, recording timer
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              if (_isRecording)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

        // Bottom overlay: toggle camera, record button, pick from gallery
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
                    onTap: _toggleRecording,
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
                    onPressed: _isRecording ? null : _toggleCamera,
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
}
