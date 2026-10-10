import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A decoded and validated image payload ready to send to an OCR provider.
///
/// [format] is derived from the encoded bytes and uses `jpeg` for JPEG files.
/// If EXIF orientation had to be applied, [bytes] is a lossless PNG encoding
/// of the oriented pixels and [format] reflects that output.
class OcrImagePayload {
  final Uint8List bytes;
  final String format;
  final int width;
  final int height;

  const OcrImagePayload({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });

  String get mimeType => 'image/$format';
}

/// Validates and prepares OCR bytes away from the UI isolate where available.
Future<OcrImagePayload> prepareOcrImagePayload(Uint8List bytes) async {
  try {
    return await Isolate.run(() => prepareOcrImagePayloadSync(bytes));
  } on FormatException {
    rethrow;
  } catch (_) {
    // Web and constrained test runtimes may not support spawning isolates.
    return prepareOcrImagePayloadSync(bytes);
  }
}

/// Applies the import limits requested by image pickers to an already
/// validated payload. Desktop file pickers do not apply these options.
/// Passing null options leaves the payload byte-for-byte unchanged.
Future<OcrImagePayload> applyOcrImageImportQuality(
  OcrImagePayload payload, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  if (maxWidth == null && maxHeight == null && imageQuality == null) {
    return payload;
  }
  try {
    return await Isolate.run(
      () => applyOcrImageImportQualitySync(
        payload,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      ),
    );
  } catch (_) {
    // Web and constrained test runtimes may not support spawning isolates.
    return applyOcrImageImportQualitySync(
      payload,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
}

/// Synchronous core for desktop import resizing and compression.
OcrImagePayload applyOcrImageImportQualitySync(
  OcrImagePayload payload, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) {
  if (maxWidth == null && maxHeight == null && imageQuality == null) {
    return payload;
  }
  if ((maxWidth != null && maxWidth <= 0) ||
      (maxHeight != null && maxHeight <= 0)) {
    throw ArgumentError('Image maximum dimensions must be positive.');
  }
  if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
    throw ArgumentError.value(imageQuality, 'imageQuality');
  }

  final decoded = img.decodeImage(payload.bytes);
  if (decoded == null) {
    throw const FormatException('无法处理图片，请重新选择后重试。');
  }
  final oriented = img.bakeOrientation(decoded);
  var scale = 1.0;
  if (maxWidth != null && oriented.width > maxWidth) {
    scale = math.min(scale, maxWidth / oriented.width);
  }
  if (maxHeight != null && oriented.height > maxHeight) {
    scale = math.min(scale, maxHeight / oriented.height);
  }
  final width = math.max(1, (oriented.width * scale).round());
  final height = math.max(1, (oriented.height * scale).round());
  final resized = width != oriented.width || height != oriented.height;
  if (!resized && imageQuality == null) return payload;

  final working = resized
      ? img.copyResize(
          oriented,
          width: width,
          height: height,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  final Uint8List encoded;
  if (imageQuality != null) {
    // Preserve transparent document backgrounds when encoding to JPEG.
    final flattened = img.Image(
      width: working.width,
      height: working.height,
      numChannels: 3,
    )..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(flattened, working);
    encoded = Uint8List.fromList(img.encodeJpg(
      flattened,
      quality: imageQuality,
      chroma: img.JpegChroma.yuv420,
    ));
  } else {
    encoded = Uint8List.fromList(img.encodePng(working, level: 6));
  }
  return prepareOcrImagePayloadSync(encoded);
}

/// Synchronous core shared by the background and fallback paths.
OcrImagePayload prepareOcrImagePayloadSync(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('图片为空，请重新选择。');
  }

  final format = _detectOcrImageFormat(bytes);
  if (format == null) {
    throw FormatException(_unsupportedFormatMessage(bytes));
  }

  late final img.Image decoded;
  try {
    final image = img.decodeImage(bytes);
    if (image == null) throw const FormatException('无法解码图片');
    decoded = image;
  } catch (_) {
    throw const FormatException(
      '图片内容损坏或无法解码，请重新选择，或转换为 PNG、JPEG、WebP 后重试。',
    );
  }

  final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation ??
      decoded.exif.imageIfd.orientation;
  if (orientation != null && orientation != 1) {
    try {
      // The JPEG decoder already applies EXIF orientation while decoding.
      // Other supported decoders may leave it in metadata, so bake it here.
      final decodedOrientation = decoded.exif.imageIfd.orientation;
      final oriented = decodedOrientation != null && decodedOrientation != 1
          ? img.bakeOrientation(decoded)
          : decoded;
      // The image package has no lossless JPEG transform. PNG preserves the
      // decoded pixels and avoids another lossy encode, with no resize.
      final normalized = img.encodePng(oriented, level: 6);
      return OcrImagePayload(
        bytes: normalized,
        format: 'png',
        width: oriented.width,
        height: oriented.height,
      );
    } catch (_) {
      throw const FormatException(
        '无法校正图片方向，请转换为 PNG、JPEG 或 WebP 后重试。',
      );
    }
  }

  return OcrImagePayload(
    bytes: bytes,
    format: format,
    width: decoded.width,
    height: decoded.height,
  );
}

String? _detectOcrImageFormat(Uint8List bytes) {
  if (_startsWith(
      bytes, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'png';
  }
  if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) return 'jpeg';
  if (_startsWith(bytes, ascii.encode('GIF87a')) ||
      _startsWith(bytes, ascii.encode('GIF89a'))) {
    return 'gif';
  }
  if (bytes.length >= 12 &&
      _startsWith(bytes, ascii.encode('RIFF')) &&
      _matchesAscii(bytes, 8, 'WEBP')) {
    return 'webp';
  }
  return null;
}

String _unsupportedFormatMessage(Uint8List bytes) {
  if (_isTiff(bytes) || _isSvg(bytes) || _isHeic(bytes)) {
    return '暂不支持 HEIC、SVG 或 TIFF 图片，请先转换为 PNG、JPEG 或 WebP 后重试。';
  }
  return '不支持此图片格式，请先转换为 PNG、JPEG 或 WebP 后重试。';
}

bool _isTiff(Uint8List bytes) =>
    _startsWith(bytes, const [0x49, 0x49, 0x2a, 0x00]) ||
    _startsWith(bytes, const [0x4d, 0x4d, 0x00, 0x2a]) ||
    _startsWith(bytes, const [0x49, 0x49, 0x2b, 0x00]) ||
    _startsWith(bytes, const [0x4d, 0x4d, 0x00, 0x2b]);

bool _isHeic(Uint8List bytes) {
  if (bytes.length < 12 || !_matchesAscii(bytes, 4, 'ftyp')) return false;
  final brand = String.fromCharCodes(bytes.sublist(8, 12));
  return const {'heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1', 'heif'}
      .contains(brand);
}

bool _isSvg(Uint8List bytes) {
  final text = utf8.decode(bytes.take(2048).toList(), allowMalformed: true);
  final normalized = text.replaceFirst('\uFEFF', '').trimLeft().toLowerCase();
  return normalized.startsWith('<svg') ||
      (normalized.startsWith('<?xml') && normalized.contains('<svg'));
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

bool _matchesAscii(Uint8List bytes, int offset, String text) {
  if (bytes.length < offset + text.length) return false;
  for (var i = 0; i < text.length; i++) {
    if (bytes[offset + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}
