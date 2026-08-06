import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;

import '../utils/pop_animation.dart';

/// Outcome of the quick editor's background processing.
///
/// The editor pops immediately on confirm; processing continues in the
/// background and [ExtendedImageEditorPage.onProcessed] is invoked with
/// the outcome — ALWAYS, on success and on failure — after the page has
/// been disposed.
sealed class QuickEditProcessingResult {
  const QuickEditProcessingResult();
}

/// Processing succeeded — [editedBytes] holds the processed image.
class QuickEditProcessingSuccess extends QuickEditProcessingResult {
  final Uint8List editedBytes;

  const QuickEditProcessingSuccess(this.editedBytes);
}

/// Processing failed — [error] describes the failure.
///
/// A failure snackbar is also shown automatically; callers typically use
/// this to release their own in-flight guards.
class QuickEditProcessingFailure extends QuickEditProcessingResult {
  final Object error;

  const QuickEditProcessingFailure(this.error);
}

/// A quick image editor using [ExtendedImage]'s built-in editor mode.
///
/// Provides crop, rotate, and flip operations.
///
/// When the user confirms editing (完成), the page pops IMMEDIATELY and
/// the edited image is processed in the background — the user is never
/// blocked by the (potentially slow) decode → crop → rotate → re-encode
/// pipeline. The outcome is delivered via [onProcessed], which fires
/// after the page has been disposed, so callers must not capture widget
/// state (only plain values and their own `State` via `mounted` checks).
class ExtendedImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  /// Called with the processing outcome after the user confirms editing.
  ///
  /// The editor pops immediately on confirm and pops with `true` as the
  /// route result; image processing continues in the background
  /// (decoupled from the widget lifecycle — all needed state is captured
  /// before the pop) and this callback fires when it completes. It fires
  /// on BOTH success and failure, but is NOT called when the user closes
  /// the editor without confirming.
  final FutureOr<void> Function(QuickEditProcessingResult result) onProcessed;

  const ExtendedImageEditorPage({
    super.key,
    required this.imageBytes,
    required this.fileName,
    required this.onProcessed,
  });

  @override
  State<ExtendedImageEditorPage> createState() =>
      _ExtendedImageEditorPageState();
}

class _ExtendedImageEditorPageState extends State<ExtendedImageEditorPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey =
      GlobalKey<ExtendedImageEditorState>();

  /// Guards against double-taps on 完成 while the exit transition runs.
  bool _submitting = false;

  Future<void> _onSave() async {
    if (_submitting) return;

    final editorState = _editorKey.currentState;
    if (editorState == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('编辑器尚未就绪，请稍后重试')),
        );
      }
      return;
    }

    // Capture EVERYTHING the background pipeline needs BEFORE pop.
    // After the route is disposed, `editorState` and `context` are
    // invalid — only plain values are safe to use afterwards.
    final action = editorState.editAction;
    final cropRect = editorState.getCropRect();
    final rawData = editorState.rawImageData;
    final messenger = ScaffoldMessenger.of(context);
    final onProcessed = widget.onProcessed;
    final route = ModalRoute.of(context);

    _submitting = true;

    // Pop IMMEDIATELY — the user is not blocked by image processing.
    // Pop with `true` so callers can tell "confirmed" from "closed"
    // without waiting for the background pipeline.
    Navigator.pop(context, true);

    // Wait for the pop transition to finish BEFORE starting the
    // pipeline: decode/rasterize work competes with the transition
    // frames and would freeze the pop animation mid-flight.
    await waitForPopAnimation(route);

    // Route transition is complete — fire-and-forget the pipeline.
    // It is a top-level function with no access to `this` or `context`,
    // so it's safe to run after the widget is disposed.
    unawaited(runQuickEditProcessing(
      rawData: rawData,
      cropRect: cropRect,
      action: action,
      messenger: messenger,
      onProcessed: onProcessed,
    ));
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
          onPressed: () {
            // Runtime check — same pattern as _onSave: the exiting route
            // is not rebuilt, so the closure captured at build time stays
            // live. Once EITHER button popped the route, a second pop
            // would target the page BELOW the editor instead.
            if (_submitting) return;
            _submitting = true;
            Navigator.pop(context, null);
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: _submitting ? null : _onSave,
            icon: const Icon(Icons.check, color: Colors.white),
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
                _editorKey.currentState?.rotate(degree: -90);
              },
            ),
            _buildToolButton(
              icon: Icons.rotate_right,
              label: '右旋',
              onTap: () {
                _editorKey.currentState?.rotate(degree: 90);
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

// ====================================================================
// Background processing pipeline — decoupled from the widget lifecycle.
//
// All inputs are plain values captured before the editor pops, so this
// can safely run after the page has been disposed.
// ====================================================================

/// Runs the crop/rotate/flip pipeline in the background and delivers the
/// outcome via [onProcessed] — ALWAYS, on success and on failure.
///
/// Errors are also reported via a snackbar on [messenger] (captured
/// before the pop). The callback is invoked AFTER the try/catch so a
/// throwing callback is the caller's bug, not a processing failure.
///
/// Top-level and parameterized so it can run after the editor page is
/// disposed; exposed for direct testing of the delivery contract.
Future<void> runQuickEditProcessing({
  required Uint8List rawData,
  required Rect? cropRect,
  required EditActionDetails? action,
  required ScaffoldMessengerState messenger,
  required FutureOr<void> Function(QuickEditProcessingResult result)
      onProcessed,
}) async {
  QuickEditProcessingResult result;
  try {
    // Decode original image
    final codec = await ui.instantiateImageCodec(rawData);
    final ui.Image originalImage;
    try {
      final frame = await codec.getNextFrame();
      originalImage = frame.image;
    } finally {
      codec.dispose();
    }

    // Determine output size accounting for rotation
    final needsRotation = action != null && action.rotateDegrees % 180 != 0;
    final int outputWidth =
        needsRotation ? originalImage.height : originalImage.width;
    final int outputHeight =
        needsRotation ? originalImage.width : originalImage.height;

    final output = await _processImage(
      image: originalImage,
      cropRect: cropRect,
      rotateAngle: action?.rotateDegrees ?? 0,
      flipX: action?.flipY ?? false,
      flipY: false,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      needsRotation: needsRotation,
      isJpegSource: _isJpegPhotoSource(rawData),
    );

    if (output == null) {
      messenger.showSnackBar(const SnackBar(content: Text('处理图片失败')));
      result = QuickEditProcessingFailure(Exception('处理图片失败'));
    } else {
      result = QuickEditProcessingSuccess(output);
    }
  } catch (e) {
    debugPrint('ExtendedImageEditor save error: $e');
    messenger.showSnackBar(SnackBar(content: Text('图片处理失败: $e')));
    result = QuickEditProcessingFailure(e);
  }

  await onProcessed(result);
}

/// Process the image: crop, rotate, and flip.
///
/// Disposes [image] (and the intermediate result) on every path.
///
/// 输出格式：JPEG 照片源 → 质量 90 的 JPEG；其余源 → 无损 PNG
/// （见 [runQuickEditProcessing] 的 [isJpegSource]）。
Future<Uint8List?> _processImage({
  required ui.Image image,
  required Rect? cropRect,
  required double rotateAngle,
  required bool flipX,
  required bool flipY,
  required int outputWidth,
  required int outputHeight,
  required bool needsRotation,
  required bool isJpegSource,
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

  ui.Picture? picture;
  ui.Image? finalImage;
  try {
    picture = recorder.endRecording();
    finalImage = await picture.toImage(outputWidth, outputHeight);

    // ── 输出格式选择（修复 4MB → 12MB 体积暴涨）──
    // dart:ui 只能输出 PNG/rawRgba。旧实现无条件输出 PNG：一张 4MB 的
    // JPEG 照片编辑后变成 12MB PNG，超过发送阈值被请求跳过，API 只能
    // 收到用户选择的部分图片。现在：JPEG 照片源 → 质量 90 的 JPEG
    // （视觉无损，体积与源相当甚至更小）；其余源（PNG 截图/带透明
    // 通道等）→ 保持无损 PNG 输出。
    // 注意：rawStraightRgba（非预乘 alpha）—— 用 rawRgba 会把半透明
    // 像素的预乘值当成直通值，重编码后出现发暗光晕。
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (byteData == null) return null;
    final frame = img.Image.fromBytes(
      width: outputWidth,
      height: outputHeight,
      bytes: byteData.buffer,
      bytesOffset: byteData.offsetInBytes,
      numChannels: 4,
    );
    return isJpegSource
        ? img.encodeJpg(frame, quality: 90, chroma: img.JpegChroma.yuv420)
        : img.encodePng(frame);
  } finally {
    image.dispose();
    picture?.dispose();
    finalImage?.dispose();
  }
}

/// JPEG 源（FFD8FF 魔数）→ 输出 JPEG q90。
bool _isJpegPhotoSource(Uint8List bytes) {
  return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}
