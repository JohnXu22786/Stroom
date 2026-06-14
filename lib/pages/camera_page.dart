import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/camera_settings_provider.dart';
import '../utils/image_manifest.dart';
import 'image_editor_page.dart';

class CameraPage extends ConsumerStatefulWidget {
  final String folder;
  final bool editAfterCapture;
  const CameraPage({super.key, this.folder = '', this.editAfterCapture = false});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  bool _isFrontCamera = false;
  double _zoomLevel = 0.0; // 0.0–1.0 (camerawesome normalized zoom)
  FlashMode _flashMode = FlashMode.none;
  int _aspectIndex = 0;
  bool _isSaving = false;
  bool _discardRequested = false;

  double _shutterScale = 1.0;
  bool _showFlash = false;
  bool _showGrid = false;

  static const _aspectRatios = [
    CameraAspectRatios.ratio_4_3,
    CameraAspectRatios.ratio_16_9,
    CameraAspectRatios.ratio_1_1,
  ];
  static const _aspectLabels = ['4:3', '16:9', '1:1'];

  /// Display zoom (1.0x–5.0x), derived from normalized _zoomLevel.
  double get _displayZoom => 1.0 + _zoomLevel * 4.0;

  @override
  void dispose() {
    _discardRequested = true;
    super.dispose();
  }

  // ====================================================================
  // Animations
  // ====================================================================

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

  // ====================================================================
  // Camera controls
  // ====================================================================

  void _toggleCamera(CameraState state) {
    setState(() => _isFrontCamera = !_isFrontCamera);
    state.switchCameraSensor();
  }

  void _toggleFlash(SensorConfig sensorConfig) {
    const modes = [
      FlashMode.none,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.on,
    ];
    final idx = (modes.indexOf(_flashMode) + 1) % modes.length;
    setState(() => _flashMode = modes[idx]);
    sensorConfig.setFlashMode(_flashMode);
  }

  void _zoomIn(SensorConfig sensorConfig) {
    final newZoom = (_zoomLevel + 0.1).clamp(0.0, 1.0);
    setState(() => _zoomLevel = newZoom);
    sensorConfig.setZoom(newZoom);
  }

  void _zoomOut(SensorConfig sensorConfig) {
    final newZoom = (_zoomLevel - 0.1).clamp(0.0, 1.0);
    setState(() => _zoomLevel = newZoom);
    sensorConfig.setZoom(newZoom);
  }

  void _showAspectRatioPicker(SensorConfig sensorConfig) {
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '选择画面比例',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_aspectLabels.length, (i) {
                  final label = _aspectLabels[i];
                  final isSelected = i == _aspectIndex;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.pop(context, i),
                  );
                }),
              ],
            ),
          ),
        );
      },
    ).then((index) {
      if (index != null && mounted) {
        setState(() => _aspectIndex = index);
        sensorConfig.setAspectRatio(_aspectRatios[index]);
      }
    });
  }

  // ====================================================================
  // Photo capture
  // ====================================================================

  Future<void> _takePicture(PhotoCameraState state) async {
    if (_isSaving) return;

    _animateShutter();
    _triggerFlash();
    setState(() => _isSaving = true);

    try {
      final request = await state.takePhoto();
      if (_discardRequested || !mounted) return;

      final filePath = request.when(
        single: (single) => single.file?.path,
      );

      if (filePath == null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('拍照失败: 无法获取文件'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _processAndSave(filePath);
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

  Future<void> _processAndSave(String filePath) async {
    try {
      // Read bytes from the camerawesome-temp file
      var bytes = await File(filePath).readAsBytes();
      if (_discardRequested) return;

      // Step 1: Re-encode to correct EXIF orientation
      bytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 100,
        format: CompressFormat.jpeg,
      );
      if (_discardRequested) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // If edit-after-capture is enabled, show the editor before saving
      if (widget.editAfterCapture) {
        setState(() => _isSaving = false);
        if (!mounted) return;

        final result = await Navigator.push<ImageEditorResult>(
          context,
          MaterialPageRoute(
            builder: (_) => ImageEditorPage(
              imageBytes: bytes,
              fromCamera: true,
            ),
          ),
        );
        if (!mounted || _discardRequested) return;

        if (result == null) {
          // User cancelled editing — discard the photo
          Navigator.pop(context, null);
          return;
        }

        // Save the edited image
        setState(() => _isSaving = true);
        bytes = result.editedBytes;
      } else {
        // Step 2: Crop + target quality (in one compressWithList call)
        final settings = ref.read(cameraSettingsProvider);
        final quality = (settings.compressionQuality * 100).round();

        // Map camerawesome aspect ratio index to actual ratio value
        final ratios = [4 / 3, 16 / 9, 1 / 1];
        final aspectRatio = ratios[_aspectIndex];

        if (aspectRatio != ratios[0]) {
          final codec = await ui.instantiateImageCodec(bytes);
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
          final canvas =
              Canvas(recorder, Rect.fromLTWH(0, 0, targetW, targetH));
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
              await croppedImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) return;
          final pngBytes = byteData.buffer.asUint8List();
          bytes = await FlutterImageCompress.compressWithList(
            pngBytes,
            minWidth: targetW.round(),
            minHeight: targetH.round(),
            quality: quality < 100 ? quality : 100,
            format: CompressFormat.jpeg,
          );
        } else if (quality < 100) {
          bytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: quality,
            format: CompressFormat.jpeg,
          );
        }
      }
      if (_discardRequested) return;

      final Uint8List finalBytes = bytes;

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
      if (thumbnailBytes.isNotEmpty) {
        await ImageManifest.writeFile(thumbFileName, thumbnailBytes);
      }
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

      final savedFilePath = await ImageManifest.readFilePath(fileName);
      if (mounted && !_discardRequested) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片已保存'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, savedFilePath);
      }
    } catch (e) {
      if (mounted && !_discardRequested) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('保存照片失败: $e'), backgroundColor: Colors.red),
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
      if (byteData == null) return Uint8List(0);
      return byteData.buffer.asUint8List();
    } catch (_) {
      return Uint8List(0);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.none:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.on:
        return Icons.highlight;
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

  Widget _buildPhotoUI(PhotoCameraState state) {
    final sensorConfig = state.sensorConfig;

    return Stack(
      children: [
        // Grid overlay
        if (_showGrid)
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
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
                  '${_displayZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _toggleFlash(sensorConfig),
                    icon: Icon(
                      _flashIcon(),
                      color: _flashMode == FlashMode.none
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
                onTap: () => _showAspectRatioPicker(sensorConfig),
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
                  _overlayButton(Icons.zoom_out, () => _zoomOut(sensorConfig)),
                  const SizedBox(width: 48),
                  _overlayButton(Icons.zoom_in, () => _zoomIn(sensorConfig)),
                ],
              ),
              const SizedBox(height: 24),
              // Camera switch + shutter
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _toggleCamera(state),
                    icon: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () => _takePicture(state),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _discardRequested = true;
          Navigator.pop(context);
        }
      },
      child: CameraAwesomeBuilder.custom(
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(
            _isFrontCamera ? SensorPosition.front : SensorPosition.back,
          ),
          flashMode: _flashMode,
          aspectRatio: _aspectRatios[_aspectIndex],
          zoom: _zoomLevel,
        ),
        saveConfig: SaveConfig.photo(),
        builder: (state, _) {
          return state.when(
            onPreparingCamera: (_) => _buildLoadingUI(),
            onPhotoMode: (pState) => _buildPhotoUI(pState),
            onVideoMode: (_) => const SizedBox.shrink(),
            onVideoRecordingMode: (_) => const SizedBox.shrink(),
          );
        },
        onPreviewTapBuilder: (state) => OnPreviewTap(
          onTap: (position, flutterSize, pixelSize) {
            state.when(
              onPhotoMode: (s) => s.focusOnPoint(
                flutterPosition: position,
                flutterPreviewSize: flutterSize,
                pixelPreviewSize: pixelSize,
              ),
              onVideoMode: (s) => s.focusOnPoint(
                flutterPosition: position,
                flutterPreviewSize: flutterSize,
                pixelPreviewSize: pixelSize,
              ),
              onVideoRecordingMode: (s) => s.focusOnPoint(
                flutterPosition: position,
                flutterPreviewSize: flutterSize,
                pixelPreviewSize: pixelSize,
              ),
            );
          },
        ),
        onPreviewScaleBuilder: (state) => OnPreviewScale(
          onScale: (scale) {
            _zoomLevel = scale.clamp(0.0, 1.0);
            state.sensorConfig.setZoom(_zoomLevel);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }
}

// ====================================================================
// Grid painter — unchanged from the original
// ====================================================================

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
