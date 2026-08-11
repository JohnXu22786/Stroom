import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;

/// Outcome of the quick editor's background processing.
///
/// The editor keeps the page alive until processing finishes: the UI is
/// hidden on confirm (so the caller's page shows through — the route must
/// be pushed non-opaque), processing runs while the page is still
/// mounted, and only after [ExtendedImageEditorPage.onProcessed] has
/// delivered the outcome does the page pop (deferred destroy). The
/// callback fires ALWAYS, on success and on failure.
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
/// When the user confirms editing (完成), the editor page does NOT pop
/// away and get destroyed while the image is being processed. Instead:
///
/// 1. The editor UI is removed immediately (the page below becomes
///    visible — the caller must push the route with `opaque: false`),
///    but the page itself stays mounted. The route's modal barrier keeps
///    the page below visible-but-frozen while the image processes; the
///    caller's own gating UI (processing banner / disabled buttons)
///    communicates the state.
/// 2. The decode → crop → rotate → re-encode pipeline runs while the
///    page is still alive; the user is never blocked by it and the edit
///    is never lost.
/// 3. Only after [onProcessed] has delivered the outcome (success or
///    failure) does the page pop itself — the deferred destroy.
///
/// The page pops with `true` as the route result once the outcome has
/// been delivered, or with `null` when the user closes the editor without
/// confirming (no processing runs in that case).
class ExtendedImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final String fileName;

  /// Called with the processing outcome after the user confirms editing.
  ///
  /// Fires when the background pipeline completes — on BOTH success and
  /// failure — while the editor page is still alive. The page pops only
  /// AFTER this callback returns (deferred destroy), so the edited image
  /// is already received by the caller when the page is destroyed. It is
  /// NOT called when the user closes the editor without confirming.
  final FutureOr<void> Function(QuickEditProcessingResult result) onProcessed;

  /// Called synchronously the moment the user confirms editing (完成),
  /// before processing starts.
  ///
  /// Callers use this to hold their in-flight guard (blocking send /
  /// confirm while the pipeline runs) and release it in [onProcessed].
  /// Not called when the user closes the editor without confirming.
  final VoidCallback? onSubmitted;

  const ExtendedImageEditorPage({
    super.key,
    required this.imageBytes,
    required this.fileName,
    required this.onProcessed,
    this.onSubmitted,
  });

  @override
  State<ExtendedImageEditorPage> createState() =>
      _ExtendedImageEditorPageState();
}

class _ExtendedImageEditorPageState extends State<ExtendedImageEditorPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey =
      GlobalKey<ExtendedImageEditorState>();

  /// Guards against double-taps on 完成 and marks the editor as
  /// "submitted" — the UI is hidden while the pipeline runs and the page
  /// is destroyed only after the result has been delivered.
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

    // Capture EVERYTHING the processing pipeline needs BEFORE the editor
    // UI is replaced. Only plain values are safe for the pipeline to read
    // afterwards.
    final action = editorState.editAction;
    final cropRect = editorState.getCropRect();
    final rawData = editorState.rawImageData;
    final messenger = ScaffoldMessenger.of(context);
    final onProcessed = widget.onProcessed;
    // The editor's own route — the deferred destroy removes THIS route by
    // identity, never "whatever happens to be on top".
    final route = ModalRoute.of(context);

    // The user confirmed — hold the caller's in-flight guard NOW so send
    // / confirm actions stay blocked while the pipeline runs. A throwing
    // guard must not abort the submit: the caller's guard would be held
    // with no pipeline to release it.
    try {
      widget.onSubmitted?.call();
    } catch (e) {
      debugPrint('QuickEditProcessing onSubmitted threw: $e');
    }

    setState(() => _submitting = true);

    // Run the pipeline while the page is still alive (deferred destroy).
    // The editor UI is now hidden; because the route was pushed
    // non-opaque, the caller's page below is visible — its modal barrier
    // blocks input until processing finishes (the caller's own gating UI,
    // e.g. the processing banner, shows the state).
    await runQuickEditProcessing(
      rawData: rawData,
      cropRect: cropRect,
      action: action,
      messenger: messenger,
      onProcessed: (result) async {
        try {
          // 1) Deliver the outcome to the caller FIRST — the edited
          //    image (or the failure) is now received by the caller.
          await onProcessed(result);
        } catch (e) {
          // A throwing caller callback must never surface as an
          // unhandled async error nor block the deferred destroy.
          debugPrint('QuickEditProcessing onProcessed threw: $e');
        } finally {
          // 2) Only now destroy the editor page (deferred destroy).
          //    Remove the editor ROUTE by identity — `Navigator.pop`
          //    would pop whatever route is on top (the gallery pushes its
          //    save dialog while the editor is hidden, and a route the
          //    caller pushed could otherwise be popped instead, leaving a
          //    zombie editor that swallows every system back press).
          if (mounted) {
            if (route != null) {
              try {
                Navigator.of(context).removeRoute(route, true);
              } catch (e) {
                // The route was already removed (e.g. an in-progress back
                // swipe completed) — nothing left to destroy.
                debugPrint('QuickEditProcessing route removal skipped: $e');
              }
            } else {
              debugPrint('QuickEditProcessing: editor route missing — deferred '
                  'destroy skipped');
            }
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // After the user confirms, the page is kept alive (deferred destroy)
    // but its UI is removed: the route below becomes visible again (the
    // caller pushed the route with `opaque: false`). The route's modal
    // barrier still absorbs input, so the caller's page is visible but
    // not interactive while the image processes — the caller's own gating
    // UI (processing banner / disabled buttons) communicates the state.
    // System back is blocked so nothing can destroy the page before the
    // pipeline delivers.
    if (_submitting) {
      return const PopScope(
        canPop: false,
        child: SizedBox.shrink(),
      );
    }

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
            // Runtime guard: a stale close closure captured before a
            // rebuild (e.g. from the frame where 完成 was just tapped)
            // must never pop the page BELOW the editor. Once `_submitting`
            // is set — by either button — every later handler is a no-op.
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
// All inputs are plain values captured before the editor UI is hidden,
// so it is safe to run regardless of whether the editor page is still
// mounted (it is — until the outcome is delivered).
// ====================================================================

/// Runs the crop/rotate/flip pipeline and delivers the outcome via
/// [onProcessed] — ALWAYS, on success and on failure.
///
/// Errors are also reported via a snackbar on [messenger] (captured
/// before the UI is hidden). The callback is invoked AFTER the try/catch
/// so a throwing callback is the caller's bug, not a processing failure.
///
/// Top-level and parameterized so it can run regardless of the editor
/// page's lifecycle; exposed for direct testing of the delivery contract.
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

// ====================================================================
// Transparent editor route
//
// The editor's deferred-destroy flow (hide UI on confirm, keep the page
// alive until the result is delivered) only works if the route below is
// painted once the editor's own UI is gone. [MaterialPageRoute] is always
// opaque in current Flutter, so the editor is presented through this
// non-opaque Material route instead.
// ====================================================================

/// A [MaterialPageRoute]-style route that is transparent (`opaque: false`).
///
/// [ExtendedImageEditorPage] relies on this: after the user confirms, the
/// editor removes its own UI while the page stays alive — a non-opaque
/// route lets the caller's page (chat / picker / gallery / OCR) show
/// through while the image processes. The route keeps its default modal
/// barrier, so the caller's page stays visible-but-frozen during that
/// window (its own gating UI communicates the state).
class QuickEditEditorRoute extends PageRoute<bool>
    with MaterialRouteTransitionMixin<bool> {
  QuickEditEditorRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;
}

/// Builds the route used to present the quick editor.
///
/// Every caller MUST push through this helper: the route is non-opaque,
/// which is what lets the caller's page become visible again the moment
/// the editor hides its UI on confirm (deferred destroy).
Route<bool> buildQuickEditEditorRoute({
  required Uint8List imageBytes,
  required String fileName,
  required FutureOr<void> Function(QuickEditProcessingResult result)
      onProcessed,
  VoidCallback? onSubmitted,
}) {
  return QuickEditEditorRoute(
    builder: (_) => ExtendedImageEditorPage(
      imageBytes: imageBytes,
      fileName: fileName,
      onProcessed: onProcessed,
      onSubmitted: onSubmitted,
    ),
  );
}
