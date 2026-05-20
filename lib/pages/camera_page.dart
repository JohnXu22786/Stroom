import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import '../utils/image_manifest.dart';

class CameraPage extends ConsumerStatefulWidget {
  final String folder;
  const CameraPage({super.key, this.folder = ''});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  double _zoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;
  int _aspectIndex = 0;
  bool _isSaving = false;
  bool _discardRequested = false;

  double _shutterScale = 1.0;
  bool _showFlash = false;
  bool _showGrid = false;
  Offset _focusOffset = Offset.zero;
  bool _showFocusIndicator = false;

  static const _aspectRatios = [4 / 3, 16 / 9, 1 / 1];
  static const _aspectLabels = ['4:3', '16:9', '1:1'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discardRequested = true;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initCamera();
    } else if (state == AppLifecycleState.paused) {
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

      final settings = ref.read(cameraSettingsProvider);
      final preset = settings.highQuality
          ? ResolutionPreset.veryHigh
          : ResolutionPreset.medium;

      _controller =
          CameraController(camera, preset, enableAudio: false);
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

  void _toggleFlash() {
    if (_controller == null || !_isInitialized) return;
    const modes = [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.torch
    ];
    final idx = (modes.indexOf(_flashMode) + 1) % modes.length;
    setState(() => _flashMode = modes[idx]);
    _controller!.setFlashMode(_flashMode);
  }

  void _toggleAspectRatio() {
    setState(() {
      _aspectIndex = (_aspectIndex + 1) % _aspectRatios.length;
    });
  }

  void _zoomIn() {
    if (_controller == null || !_isInitialized) return;
    setState(() => _zoomLevel = (_zoomLevel + 0.5).clamp(1.0, 5.0));
    _controller!.setZoomLevel(_zoomLevel);
  }

  void _zoomOut() {
    if (_controller == null || !_isInitialized) return;
    setState(() => _zoomLevel = (_zoomLevel - 0.5).clamp(1.0, 5.0));
    _controller!.setZoomLevel(_zoomLevel);
  }

  Future<Uint8List> _cropToAspectRatio(
      Uint8List imageData, double aspectRatio) async {
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final srcWidth = image.width;
    final srcHeight = image.height;
    double targetW = srcWidth.toDouble();
    double targetH = targetW / aspectRatio;
    if (targetH > srcHeight) {
      targetH = srcHeight.toDouble();
      targetW = targetH * aspectRatio;
    }
    final dx = (srcWidth - targetW) / 2;
    final dy = (srcHeight - targetH) / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetW, targetH));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(dx, dy, targetW, targetH),
      Rect.fromLTWH(0, 0, targetW, targetH),
      Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImage =
        await picture.toImage(targetW.round(), targetH.round());
    final byteData =
        await croppedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return imageData;
    final rgbaBytes = byteData.buffer.asUint8List();
    final result = await FlutterImageCompress.compressWithList(
      rgbaBytes,
      minWidth: targetW.round(),
      minHeight: targetH.round(),
      quality: 100,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  void _animateShutter() {
    setState(() => _shutterScale = 0.85);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _shutterScale = 1.0);
    });
  }

  void _triggerFlash() {
    setState(() => _showFlash = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showFlash = false);
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_controller == null || !_isInitialized) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localOffset = box.globalToLocal(details.globalPosition);
    final size = box.size;

    final normalizedOffset = Offset(
      (localOffset.dx / size.width).clamp(0.0, 1.0),
      (localOffset.dy / size.height).clamp(0.0, 1.0),
    );

    _controller!.setFocusPoint(normalizedOffset);
    _controller!.setExposurePoint(normalizedOffset);

    setState(() {
      _focusOffset = localOffset;
      _showFocusIndicator = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showFocusIndicator = false);
    });
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null || _isSaving) return;

    _animateShutter();
    _triggerFlash();

    setState(() => _isSaving = true);

    try {
      final xFile = await _controller!.takePicture();
      if (_discardRequested) return;

      var bytes = await xFile.readAsBytes();
      if (_discardRequested) return;

      final aspectRatio = _aspectRatios[_aspectIndex];
      if (aspectRatio != 4 / 3) {
        bytes = await _cropToAspectRatio(bytes, aspectRatio);
        if (_discardRequested) return;
      }

      final settings = ref.read(cameraSettingsProvider);
      final quality = (settings.compressionQuality * 100).round();
      final finalBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (_discardRequested) return;

      final hash = computeImageHash(finalBytes);
      const format = 'jpg';
      final fileName = '$hash.$format';

      await ImageManifest.writeFile(fileName, finalBytes);
      if (_discardRequested) {
        await ImageManifest.deleteFile(fileName);
        return;
      }

      final thumbnailBytes = await _generateThumbnail(finalBytes);
      final thumbFileName = '${hash}_thumb.png';
      await ImageManifest.writeFile(thumbFileName, thumbnailBytes);
      if (_discardRequested) {
        await ImageManifest.deleteFile(fileName);
        await ImageManifest.deleteFile(thumbFileName);
        return;
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final record = ImageRecord(
        name: '照片_$timestamp',
        hash: hash,
        format: format,
        createdAt: DateTime.now(),
        size: finalBytes.length,
        folder: widget.folder,
      );
      await ImageManifest.addRecord(record);

      final filePath = await ImageManifest.readFilePath(fileName);
      if (mounted && !_discardRequested) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片已保存'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, filePath);
      }
    } catch (e) {
      if (mounted && !_discardRequested) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('拍照失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<Uint8List> _generateThumbnail(Uint8List imageData,
      {int maxDimension = 256}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return Uint8List(0);
      return byteData.buffer.asUint8List();
    } catch (_) {
      return Uint8List(0);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isInitialized && _controller != null)
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _onTapDown,
              child: CameraPreview(_controller!),
            ),
          )
        else
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),

        // Grid overlay
        if (_showGrid && _isInitialized)
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

        // Focus indicator
        Positioned(
          left: _focusOffset.dx - 25,
          top: _focusOffset.dy - 25,
          child: AnimatedOpacity(
            opacity: _showFocusIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),
          ),
        ),

        // Flash overlay
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showFlash ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 50),
              child: Container(color: Colors.white),
            ),
          ),
        ),

        // Saving overlay
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '保存中...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Top overlay
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        _discardRequested = true;
                        Navigator.pop(context);
                      },
                icon:
                    const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_zoomLevel.toStringAsFixed(1)}x',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      _flashIcon(),
                      color: _flashMode == FlashMode.off
                          ? Colors.white
                          : Colors.amber,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showGrid = !_showGrid),
                    icon: Icon(
                      _showGrid ? Icons.grid_on : Icons.grid_off,
                      color: _showGrid ? Colors.amber : Colors.white,
                      size: 28,
                    ),
                  ),
                ],
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
              // Aspect ratio toggle
              GestureDetector(
                onTap: _toggleAspectRatio,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _aspectLabels[_aspectIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Zoom in/out
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _overlayButton(Icons.zoom_out, _zoomOut),
                  const SizedBox(width: 48),
                  _overlayButton(Icons.zoom_in, _zoomIn),
                ],
              ),
              const SizedBox(height: 24),
              // Camera switch + shutter
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _toggleCamera,
                    icon: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: _takePicture,
                    child: AnimatedScale(
                      scale: _shutterScale,
                      duration: const Duration(milliseconds: 80),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              _isSaving ? Colors.grey : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt,
                            color: _isSaving
                                ? Colors.grey
                                : Colors.black,
                            size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 80),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overlayButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
      child: IconButton(
        onPressed: _isSaving ? null : onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), paint);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), paint);
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), paint);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
