import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

/// A quick image editor using [ExtendedImage]'s built-in editor mode.
///
/// Provides crop, rotate, and flip operations. The edited image bytes are
/// returned via [Navigator.pop] as [Uint8List], or `null` if cancelled.
class ExtendedImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  const ExtendedImageEditorPage({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  @override
  State<ExtendedImageEditorPage> createState() =>
      _ExtendedImageEditorPageState();
}

class _ExtendedImageEditorPageState extends State<ExtendedImageEditorPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey =
      GlobalKey<ExtendedImageEditorState>();

  bool _isSaving = false;

  Future<void> _onSave() async {
    setState(() => _isSaving = true);
    try {
      final editorState = _editorKey.currentState;
      if (editorState == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('编辑器尚未就绪，请稍后重试')),
          );
        }
        return;
      }

      final action = editorState.editAction;
      final cropRect = editorState.getCropRect();
      final rawData = editorState.rawImageData;

      // Decode original image
      final codec = await ui.instantiateImageCodec(rawData);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;
      codec.dispose();

      // Determine output size accounting for rotation
      final needsRotation = action != null && action.rotateAngle % 180 != 0;
      final int outputWidth =
          needsRotation ? originalImage.height : originalImage.width;
      final int outputHeight =
          needsRotation ? originalImage.width : originalImage.height;

      final output = await _processImage(
        image: originalImage,
        cropRect: cropRect,
        rotateAngle: action?.rotateAngle ?? 0,
        flipX: action?.flipX ?? false,
        flipY: action?.flipY ?? false,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        needsRotation: needsRotation,
      );

      if (output != null && mounted) {
        Navigator.pop(context, output);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('处理图片失败')),
        );
      }
    } catch (e) {
      debugPrint('ExtendedImageEditor save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Process the image: crop, rotate, and flip.
  Future<Uint8List?> _processImage({
    required ui.Image image,
    required Rect? cropRect,
    required double rotateAngle,
    required bool flipX,
    required bool flipY,
    required int outputWidth,
    required int outputHeight,
    required bool needsRotation,
  }) async {
    final srcW = cropRect?.width ?? image.width.toDouble();
    final srcH = cropRect?.height ?? image.height.toDouble();

    // When the canvas is rotated (90/270 degrees), the effective drawing
    // width/height are swapped relative to the output dimensions.
    final drawW =
        needsRotation ? outputHeight.toDouble() : outputWidth.toDouble();
    final drawH =
        needsRotation ? outputWidth.toDouble() : outputHeight.toDouble();

    // Scale so the source image (or crop region) fills the drawing area
    // while preserving aspect ratio.
    final scale =
        (drawW / srcW) < (drawH / srcH) ? (drawW / srcW) : (drawH / srcH);
    final destW = srcW * scale;
    final destH = srcH * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.save();
    // Move to center of drawing area
    canvas.translate(drawW / 2.0, drawH / 2.0);
    // Apply flip
    if (flipX) canvas.scale(-1.0, 1.0);
    if (flipY) canvas.scale(1.0, -1.0);
    // Apply rotation
    canvas.rotate(rotateAngle * 3.141592653589793 / 180.0);

    final src = cropRect != null
        ? Rect.fromLTWH(
            cropRect.left, cropRect.top, cropRect.width, cropRect.height)
        : Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(-destW / 2.0, -destH / 2.0, destW, destH);

    canvas.drawImageRect(image, src, dst, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(outputWidth, outputHeight);
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    finalImage.dispose();

    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '快速编辑 - ${widget.fileName}',
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _onSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
            label: const Text(
              '完成',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ExtendedImage.memory(
        widget.imageBytes,
        fit: BoxFit.contain,
        mode: ExtendedImageMode.editor,
        extendedImageEditorKey: _editorKey,
        initEditorConfigHandler: (_) => EditorConfig(
          maxScale: 5.0,
          cropRectPadding: const EdgeInsets.all(20),
          hitTestSize: 44,
          cropAspectRatio: CropAspectRatios.custom,
          initCropRectType: InitCropRectType.imageRect,
        ),
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.failed) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.white54),
                  SizedBox(height: 8),
                  Text('无法加载图片', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          return null;
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToolButton(
              icon: Icons.rotate_left,
              label: '左旋',
              onTap: () {
                _editorKey.currentState?.rotate(right: false);
              },
            ),
            _buildToolButton(
              icon: Icons.rotate_right,
              label: '右旋',
              onTap: () {
                _editorKey.currentState?.rotate(right: true);
              },
            ),
            _buildToolButton(
              icon: Icons.flip,
              label: '翻转',
              onTap: () {
                _editorKey.currentState?.flip();
              },
            ),
            _buildToolButton(
              icon: Icons.crop,
              label: '裁剪',
              onTap: () {
                // Cropping is always active in editor mode — this button
                // is informational; the user can drag crop handles directly.
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
