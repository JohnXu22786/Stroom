import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

// ====================================================================
// Data models
// ====================================================================

/// A relative crop rectangle (values 0.0-1.0, clamped).
class CropRect {
  final double x;
  final double y;
  final double width;
  final double height;

  CropRect({
    double x = 0,
    double y = 0,
    double width = 1,
    double height = 1,
  })  : x = x.clamp(0.0, 1.0),
        y = y.clamp(0.0, 1.0),
        width = width.clamp(0.0, 1.0),
       height = height.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropRect &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// A freehand drawing path (list of points + color + stroke width).
class EditorPath {
  final List<ui.Offset> points;
  final ui.Color color;
  final double strokeWidth;

  const EditorPath({
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
  });
}

/// Supported color filter types.
enum ImageFilterType {
  none('原图'),
  grayscale('灰度'),
  sepia('棕褐'),
  negative('负片'),
  vintage('复古'),
  cool('冷色'),
  warm('暖色');

  final String displayName;
  const ImageFilterType(this.displayName);
}

// ====================================================================
// ImageEditorPipeline — all image processing in one place
// ====================================================================

class ImageEditorPipeline {
  ImageEditorPipeline._();

  /// Decode raw bytes into a [ui.Image].
  static Future<ui.Image> decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Encode a [ui.Image] to PNG bytes (dart:ui only supports PNG output).
  static Future<Uint8List> encodeImage(ui.Image image) async {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw StateError('Failed to encode image');
    }
    return byteData.buffer.asUint8List();
  }

  /// Rotate the image by [degrees] (must be 0, 90, 180, or 270).
  static Future<Uint8List> applyRotate(Uint8List bytes, int degrees) async {
    // Normalize to [0, 360) and snap to valid angles
    degrees = ((degrees % 360) ~/ 90) * 90;
    if (degrees == 0) return bytes;

    final image = await decodeImage(bytes);
    final srcW = image.width;
    final srcH = image.height;

    final isSideways = (degrees % 180 != 0);
    final dstW = isSideways ? srcH : srcW;
    final dstH = isSideways ? srcW : srcH;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()));

    canvas.save();
    canvas.translate(dstW / 2, dstH / 2);
    canvas.rotate(degrees * math.pi / 180);
    canvas.drawImage(image, ui.Offset(-srcW / 2, -srcH / 2), ui.Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(dstW, dstH);
    return encodeImage(result);
  }

  /// Flip the image horizontally and/or vertically.
  static Future<Uint8List> applyFlip(Uint8List bytes,
      {bool flipH = false, bool flipV = false}) async {
    if (!flipH && !flipV) return bytes;

    final image = await decodeImage(bytes);
    final w = image.width;
    final h = image.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    canvas.save();
    canvas.translate(flipH ? w.toDouble() : 0, flipV ? h.toDouble() : 0);
    canvas.scale(flipH ? -1 : 1, flipV ? -1 : 1);
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    return encodeImage(result);
  }

  /// Crop the image to a relative rectangle.
  static Future<Uint8List> applyCrop(Uint8List bytes, CropRect rect) async {
    if (rect.width <= 0 || rect.height <= 0) {
      throw ArgumentError('Crop width and height must be > 0');
    }

    final image = await decodeImage(bytes);
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();

    final cropX = (rect.x * srcW).round();
    final cropY = (rect.y * srcH).round();
    final cropW = (rect.width * srcW).round();
    final cropH = (rect.height * srcH).round();

    if (cropW <= 0 || cropH <= 0) {
      throw ArgumentError('Crop dimensions too small');
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
    );

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropW.toDouble(), cropH.toDouble()),
      ui.Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
      ui.Paint(),
    );

    final picture = recorder.endRecording();
    final result = await picture.toImage(cropW, cropH);
    return encodeImage(result);
  }

  /// Apply brightness, contrast, and saturation adjustments via ColorMatrix.
  static Future<Uint8List> applyColorAdjust(
    Uint8List bytes, {
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) async {
    if (brightness == 0.0 && contrast == 1.0 && saturation == 1.0) {
      return bytes;
    }

    final image = await decodeImage(bytes);
    final w = image.width;
    final h = image.height;

    final colorMatrix = _buildAdjustMatrix(brightness, contrast, saturation);
    final paint = ui.Paint()..colorFilter = ui.ColorFilter.matrix(colorMatrix);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawImage(image, ui.Offset.zero, paint);

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    return encodeImage(result);
  }

  /// Apply a color filter.
  static Future<Uint8List> applyFilter(
    Uint8List bytes,
    ImageFilterType filter,
  ) async {
    if (filter == ImageFilterType.none) return bytes;

    final image = await decodeImage(bytes);
    final w = image.width;
    final h = image.height;

    final matrix = _buildFilterMatrix(filter);
    final paint = ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawImage(image, ui.Offset.zero, paint);

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    return encodeImage(result);
  }

  /// Composite drawing paths onto the image.
  static Future<Uint8List> applyDrawings(
    Uint8List bytes,
    List<EditorPath> paths,
  ) async {
    if (paths.isEmpty) return bytes;

    final image = await decodeImage(bytes);
    final w = image.width;
    final h = image.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Draw base image
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    // Draw each path
    for (final path in paths) {
      if (path.points.length < 2) continue;
      final paint = ui.Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..style = ui.PaintingStyle.stroke;

      final uiPath = ui.Path();
      uiPath.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        uiPath.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(uiPath, paint);
    }

    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    return encodeImage(result);
  }

  /// Apply all edits in a pipeline. The [editorState] map can contain:
  /// - 'rotation' (int): 0, 90, 180, 270
  /// - 'flipH' (bool): horizontal flip
  /// - 'flipV' (bool): vertical flip
  /// - 'cropRect' (CropRect?): crop rectangle (null = no crop)
  /// - 'brightness' (double): -1..1
  /// - 'contrast' (double): 0..3
  /// - 'saturation' (double): 0..3
  /// - 'filter' (ImageFilterType): filter to apply
  /// - 'drawings' (List<EditorPath>): drawing paths
  static Future<Uint8List> applyAll(
    Uint8List bytes, {
    Map<String, dynamic>? editorState,
  }) async {
    if (editorState == null) return bytes;

    Uint8List result = bytes;

    // 1. Crop (before rotation to crop from original orientation)
    final cropRect = editorState['cropRect'] as CropRect?;
    if (cropRect != null) {
      result = await applyCrop(result, cropRect);
    }

    // 2. Rotate
    final rotation = (editorState['rotation'] as int?) ?? 0;
    if (rotation != 0) {
      result = await applyRotate(result, rotation);
    }

    // 3. Flip
    final flipH = (editorState['flipH'] as bool?) ?? false;
    final flipV = (editorState['flipV'] as bool?) ?? false;
    if (flipH || flipV) {
      result = await applyFlip(result, flipH: flipH, flipV: flipV);
    }

    // 4. Color adjustments
    final brightness = (editorState['brightness'] as double?) ?? 0.0;
    final contrast = (editorState['contrast'] as double?) ?? 1.0;
    final saturation = (editorState['saturation'] as double?) ?? 1.0;
    if (brightness != 0.0 || contrast != 1.0 || saturation != 1.0) {
      result = await applyColorAdjust(result,
          brightness: brightness, contrast: contrast, saturation: saturation);
    }

    // 5. Filter
    final filter = (editorState['filter'] as ImageFilterType?) ?? ImageFilterType.none;
    if (filter != ImageFilterType.none) {
      result = await applyFilter(result, filter);
    }

    // 6. Drawings (on top of everything)
    final drawings = (editorState['drawings'] as List<EditorPath>?) ?? [];
    if (drawings.isNotEmpty) {
      result = await applyDrawings(result, drawings);
    }

    return result;
  }

  // ======== Public helpers for preview use ========

  /// Build a [ColorFilter] for adjust (brightness/contrast/saturation) preview.
  static ui.ColorFilter buildAdjustColorFilter({
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    return ui.ColorFilter.matrix(
      _buildAdjustMatrix(brightness, contrast, saturation),
    );
  }

  /// Build a [ColorFilter] for filter preview.
  static ui.ColorFilter buildFilterColorFilter(ImageFilterType filter) {
    return ui.ColorFilter.matrix(_buildFilterMatrix(filter));
  }

  // ======== Private helpers ========

  /// Build a 20-element ColorMatrix for brightness, contrast, saturation.
  static Float64List _buildAdjustMatrix(
    double brightness,
    double contrast,
    double saturation,
  ) {
    // Luminosity weights
    const wr = 0.299;
    const wg = 0.587;
    const wb = 0.114;

    // Clamp values
    brightness = brightness.clamp(-1.0, 1.0);
    contrast = contrast.clamp(0.0, 3.0);
    saturation = saturation.clamp(0.0, 3.0);

    final b = brightness * 255; // offset for brightness
    final c = contrast; // scale for contrast
    final t = (1 - c) / 2; // translate for contrast

    final s = saturation;
    final sr = wr + (1 - wr) * s;
    final sg = wg + (1 - wg) * s;
    final sb = wb + (1 - wb) * s;
    // Off-diagonal: (1 - s) * source_luminosity_weight
    final rOff = wr * (1 - s);
    final gOff = wg * (1 - s);
    final bOff = wb * (1 - s);

    final matrix = Float64List(20);

    // R = saturate(R) * contrast + brightness
    matrix[0] = sr * c;
    matrix[1] = gOff * c;
    matrix[2] = bOff * c;
    matrix[4] = b + t * 255;

    // G = saturate(G) * contrast + brightness
    matrix[5] = rOff * c;
    matrix[6] = sg * c;
    matrix[7] = bOff * c;
    matrix[9] = b + t * 255;

    // B = saturate(B) * contrast + brightness
    matrix[10] = rOff * c;
    matrix[11] = gOff * c;
    matrix[12] = sb * c;
    matrix[14] = b + t * 255;

    // A = unchanged
    matrix[15] = 0;
    matrix[16] = 0;
    matrix[17] = 0;
    matrix[18] = 1;
    matrix[19] = 0;

    return matrix;
  }

  /// Build a 20-element ColorMatrix for a named filter.
  static Float64List _buildFilterMatrix(ImageFilterType filter) {
    switch (filter) {
      case ImageFilterType.none:
        return Float64List(20)..[0] = 1..[6] = 1..[12] = 1..[18] = 1;
      case ImageFilterType.grayscale:
        return Float64List(20)
          ..[0] = 0.299
          ..[1] = 0.587
          ..[2] = 0.114
          ..[5] = 0.299
          ..[6] = 0.587
          ..[7] = 0.114
          ..[10] = 0.299
          ..[11] = 0.587
          ..[12] = 0.114
          ..[18] = 1;
      case ImageFilterType.sepia:
        return Float64List(20)
          ..[0] = 0.393
          ..[1] = 0.769
          ..[2] = 0.189
          ..[5] = 0.349
          ..[6] = 0.686
          ..[7] = 0.168
          ..[10] = 0.272
          ..[11] = 0.534
          ..[12] = 0.131
          ..[18] = 1;
      case ImageFilterType.negative:
        return Float64List(20)
          ..[0] = -1
          ..[4] = 255
          ..[6] = -1
          ..[9] = 255
          ..[12] = -1
          ..[14] = 255
          ..[18] = 1;
      case ImageFilterType.vintage:
        return Float64List(20)
          ..[0] = 0.9
          ..[1] = 0.5
          ..[2] = 0.1
          ..[4] = 10
          ..[5] = 0.3
          ..[6] = 0.8
          ..[7] = 0.1
          ..[9] = 5
          ..[10] = 0.2
          ..[11] = 0.3
          ..[12] = 0.7
          ..[14] = -5
          ..[18] = 1
          ..[19] = 0;
      case ImageFilterType.cool:
        return Float64List(20)
          ..[0] = 0.9
          ..[1] = 0
          ..[2] = 0
          ..[4] = 0
          ..[5] = 0
          ..[6] = 1.0
          ..[7] = 0.1
          ..[9] = 0
          ..[10] = 0
          ..[11] = 0
          ..[12] = 1.2
          ..[14] = 10
          ..[18] = 1;
      case ImageFilterType.warm:
        return Float64List(20)
          ..[0] = 1.2
          ..[1] = 0.1
          ..[2] = 0
          ..[4] = 10
          ..[5] = 0
          ..[6] = 1.0
          ..[7] = 0
          ..[9] = 0
          ..[10] = 0
          ..[11] = 0
          ..[12] = 0.8
          ..[14] = -10
          ..[18] = 1;
    }
  }
}
