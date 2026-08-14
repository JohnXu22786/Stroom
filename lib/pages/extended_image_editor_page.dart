import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;

/// A quick image editor using [ExtendedImage]'s built-in editor mode.
///
/// Provides crop, rotate, and flip operations. The edited image bytes are
/// returned via [Navigator.pop] as [Uint8List], or `null` if cancelled.
///
/// When the user confirms (保存) the image is processed IN PLACE: the page
/// stays on screen showing a processing overlay while the image is
/// decoded, cropped, rotated and re-encoded. Only after processing
/// finishes does the page pop back with the edited bytes. While the image
/// is being processed the user cannot leave — system back, the close
/// button and 保存 are all blocked until the pipeline completes.
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

  /// True while the image is being processed in place. While true the
  /// editor stays on screen (a full-screen processing overlay is shown),
  /// leaving is blocked, and the edited bytes are popped once the
  /// pipeline completes.
  bool _isProcessing = false;

  /// True after the user tapped X to close. Latched synchronously before
  /// the pop so a second tap during the exit transition can never pop
  /// the page BELOW the editor. Unlike [_isProcessing] it must NOT show
  /// the processing overlay — closing runs no pipeline.
  bool _isClosing = false;

  /// Closes the editor without saving (X button).
  void _onClose() {
    if (_isProcessing || _isClosing) return;
    setState(() => _isClosing = true);
    Navigator.pop(context, null);
  }

  Future<void> _onSave() async {
    if (_isProcessing || _isClosing) return;

    final editorState = _editorKey.currentState;
    if (editorState == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('编辑器尚未就绪，请稍后重试')),
        );
      }
      return;
    }

    // Capture everything the pipeline needs synchronously — after the UI
    // is locked the editor state must not be touched.
    final action = editorState.editAction;
    final cropRect = editorState.getCropRect();
    final rawData = editorState.rawImageData;

    setState(() => _isProcessing = true);
    try {
      final output = await processQuickEditImage(
        rawData: rawData,
        cropRect: cropRect,
        action: action,
      );
      if (!mounted) return;
      // Pop with the edited bytes. `_isProcessing` deliberately stays
      // true — the leave controls remain disabled through the exit
      // transition, so a second pop can never be triggered while the
      // route is still on screen.
      Navigator.pop(context, output);
    } catch (e) {
      debugPrint('ExtendedImageEditor save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片处理失败: $e')),
      );
      // Stay on the page and unlock it so the user can retry or close.
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // While the image is processed in place the user must not leave —
      // the edited bytes are popped by [_onSave] once processing is done.
      // [_isClosing] additionally latches the exit transition after X so
      // a second pop can never fire while the route is still on screen.
      canPop: !_isProcessing && !_isClosing,
      child: Scaffold(
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
            // Blocked while processing or closing — the user cannot leave
            // until the edited bytes are delivered. The leave guard is
            // latched synchronously before the pop so a second tap during
            // the exit transition can never pop the page BELOW the editor.
            onPressed: (_isProcessing || _isClosing) ? null : _onClose,
          ),
          actions: [
            TextButton.icon(
              onPressed: (_isProcessing || _isClosing) ? null : _onSave,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                '保存',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            ExtendedImage.memory(
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
                        Icon(Icons.broken_image,
                            size: 48, color: Colors.white54),
                        SizedBox(height: 8),
                        Text('无法加载图片', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }
                return null;
              },
            ),
            // 全屏处理遮罩：保存按钮点击后图片解码/裁剪/旋转/编码
            // 需要时间，用明显的遮罩 + 文案给出 UI 反馈，避免用户
            // 以为界面卡死。关闭（X）时 [_isClosing] 为 true，不显示。
            if (_isProcessing && !_isClosing)
              const Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '正在处理图片，请稍候…',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                onTap: (_isProcessing || _isClosing)
                    ? null
                    : () {
                        _editorKey.currentState?.rotate(degree: -90);
                      },
              ),
              _buildToolButton(
                icon: Icons.rotate_right,
                label: '右旋',
                onTap: (_isProcessing || _isClosing)
                    ? null
                    : () {
                        _editorKey.currentState?.rotate(degree: 90);
                      },
              ),
              _buildToolButton(
                icon: Icons.flip,
                label: '翻转',
                onTap: (_isProcessing || _isClosing)
                    ? null
                    : () {
                        _editorKey.currentState?.flip();
                      },
              ),
              _buildToolButton(
                icon: Icons.crop,
                label: '裁剪',
                onTap: (_isProcessing || _isClosing)
                    ? null
                    : () {
                        // Cropping is always active in editor mode — this
                        // button is informational; the user can drag crop
                        // handles directly.
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    // Disabled while processing/closing — dim the row so the buttons
    // don't look tappable.
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: disabled ? Colors.white38 : Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: disabled ? Colors.white38 : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs the crop/rotate/flip pipeline and returns the processed bytes.
///
/// Throws on failure — the caller decides how to surface it (the editor
/// page shows a snackbar). All inputs are plain values captured before
/// the processing starts, so the pipeline never touches the widget tree.
///
/// 输出格式：JPEG 照片源 → 质量 90 的 JPEG；其余源 → 无损 PNG
/// （见 [_isJpegPhotoSource]）。
Future<Uint8List> processQuickEditImage({
  required Uint8List rawData,
  required Rect? cropRect,
  required EditActionDetails? action,
}) async {
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
    throw StateError('处理图片失败');
  }
  return output;
}

/// Process the image: crop, rotate, and flip.
///
/// Disposes [image] (and the intermediate result) on every path.
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
