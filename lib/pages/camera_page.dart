import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../utils/image_manifest.dart';

class CameraPage extends StatefulWidget {
  final String folder;
  const CameraPage({super.key, this.folder = ''});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  double _zoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

      _controller =
          CameraController(camera, ResolutionPreset.high, enableAudio: false);
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

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null) return;
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final hash = computeImageHash(bytes);
      const format = 'jpg';
      final fileName = '$hash.$format';

      await ImageManifest.writeFile(fileName, bytes);

      // Generate and save thumbnail
      final thumbnailBytes = await _generateThumbnail(bytes);
      final thumbFileName = '${hash}_thumb.png';
      await ImageManifest.writeFile(thumbFileName, thumbnailBytes);

      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final record = ImageRecord(
        name: '照片_$timestamp',
        hash: hash,
        format: format,
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: widget.folder,
      );
      await ImageManifest.addRecord(record);

      final filePath = await ImageManifest.readFilePath(fileName);
      if (mounted) Navigator.pop(context, filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
        );
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
      if (byteData == null) return imageData;
      return byteData.buffer.asUint8List();
    } catch (e) {
      return imageData;
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

        // Top overlay: close button, zoom indicator, flash toggle
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
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _flashIcon(),
                  color:
                      _flashMode == FlashMode.off ? Colors.white : Colors.amber,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        // Bottom overlay: zoom controls, switch camera, shutter
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  // Shutter button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.black, size: 36),
                    ),
                  ),
                  const SizedBox(width: 80), // balance layout
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
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
