import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image/image.dart' as img;

// ============================================================================
// 图片发送压缩（无感知质量损失）
// ============================================================================
//
// 背景：4MB 的照片在简单裁剪编辑后变成 12MB 的 PNG（dart:ui 只能输出
// PNG）。而各家 API 对请求体有严格的总量上限（Anthropic Messages API
// 32MB、Gemini inline 20MB，base64 再膨胀 33%，多轮对话每轮还会重发
// 历史图片），单图超过 ~5-10MB 的会被服务器直接 413/400 拒绝。
//
// 策略（只在该出手时才出手，通用阈值，不做逐供应商优化）：
// 1. 输入未超过调用方给定的 [maxBytes]（通用阈值，见
//    chat_protocol.dart 的 imageCompressThresholdBytes）→ 不压缩
//    （字节原样保留 = 真正无损，零 CPU 开销）。
// 2. 输入超过阈值 → 解码后：
//    a. 无损优先：PNG 源（或带 alpha）先用 level 6 无损重编码
//       （level 6 已获得 level 9 的绝大部分压缩收益，但耗时显著更少）；
//    b. JPEG 降级：仍超限则按 90 → 75 → 60 → 50 质量递减编码
//       （50 仅用于噪声大的高像素照片），JPEG 编码器会把 alpha 合成
//       到背景色上；
//    c. 每次只保留"确实比当前最小结果更小"的候选。
// 3. 无法解码 → [ImageCompressionResult.decodable] = false，调用方据此
//    决定跳过（发送必然被 API 拒绝）；可解码但压缩无收益 → null 压缩
//    结果，调用方按"用户已选择必须发送"发送原字节。
//
// 大图解码/编码是 CPU 密集操作，优先在后台 isolate 执行；
// Web / 测试环境不支持 Isolate.run 时自动回退到同步执行。
// ============================================================================

/// 压缩结果：新的字节 + 实际编码格式。
///
/// [mimeType] 在格式发生转换时（如 PNG→JPEG）必须用于覆盖请求中的
/// media_type，否则 API 收到"宣称是 PNG 实为 JPEG"的载荷会解码失败。
class CompressedImage {
  final Uint8List bytes;
  final String mimeType;

  const CompressedImage({required this.bytes, required this.mimeType});
}

/// 一次压缩尝试的结果。
class ImageCompressionResult {
  /// 输入是否为可解码的图片。
  ///
  /// false 表示格式无法解码（HEIC/AVIF 等）：压缩无从下手，即使发送
  /// 原字节 API 也无法读取，调用方应走"跳过"路径而不是发送。
  final bool decodable;

  /// 压缩产物；null 表示无需/无法压缩（解码成功但压缩无收益）。
  final CompressedImage? compressed;

  const ImageCompressionResult({required this.decodable, this.compressed});
}

/// JPEG 质量递减梯度：先视觉无损（90），再逐步让步。
/// 50 档仅在 60 档仍超阈值时触发（如噪声较大的高像素照片）。
const List<int> _jpegQualitySteps = [90, 75, 60, 50];

/// 将 [input] 压缩到不超过 [maxBytes]。
///
/// - 输入未超限 → [ImageCompressionResult.decodable]=true, compressed=null
/// - 无法解码 → decodable=false, compressed=null
/// - 可解码但压缩无收益（结果不小于原字节）→ decodable=true, compressed=null
/// - 成功 → decodable=true, compressed=[CompressedImage]，其中
///   [CompressedImage.mimeType] 是实际编码格式（'image/jpeg' 或 'image/png'）。
Future<ImageCompressionResult> compressImageForSend(
  Uint8List input, {
  required int maxBytes,
}) async {
  if (input.isEmpty || input.length <= maxBytes) {
    return const ImageCompressionResult(decodable: true);
  }
  try {
    return await Isolate.run(() => _compressSync(input, maxBytes));
  } catch (e) {
    // Web / 受限测试环境不支持 Isolate.run：同步执行。
    debugPrint('[ImageSendCompressor] Isolate.run 不可用，回退同步执行: $e');
    try {
      return _compressSync(input, maxBytes);
    } catch (e2) {
      debugPrint('[ImageSendCompressor] 压缩失败: $e2');
      return const ImageCompressionResult(decodable: false);
    }
  }
}

/// 同步压缩核心（供 isolate / 回退路径共用）。
ImageCompressionResult _compressSync(Uint8List input, int maxBytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return const ImageCompressionResult(decodable: false);
  }

  // EXIF 方向烘焙：相机照片可能带旋转标记，解码后不处理直接重编码
  // 会让 API 收到的图片方向错误（缩略图/预览都是"已应用方向"的）。
  img.Image working = decoded;
  try {
    working = img.bakeOrientation(working);
  } catch (_) {
    working = decoded;
  }

  final isPngSource = _hasPngSignature(input);
  Uint8List? bestBytes;
  String? bestMime;

  // 1) 无损优先：PNG 源 / 带 alpha 的图 → level 6 无损重编码
  if (isPngSource || working.hasAlpha) {
    try {
      final png = img.encodePng(working, level: 6);
      if (png.length < input.length) {
        bestBytes = png;
        bestMime = 'image/png';
        if (png.length <= maxBytes) {
          return ImageCompressionResult(
            decodable: true,
            compressed: CompressedImage(bytes: png, mimeType: 'image/png'),
          );
        }
      }
    } catch (_) {
      // 无损路径失败 → 继续尝试 JPEG 降级
    }
  }

  // 2) JPEG 降级：质量递减，只保留更小的候选
  for (final quality in _jpegQualitySteps) {
    try {
      final jpg = img.encodeJpg(
        working,
        quality: quality,
        chroma: img.JpegChroma.yuv420,
      );
      if (bestBytes == null || jpg.length < bestBytes.length) {
        bestBytes = jpg;
        bestMime = 'image/jpeg';
      }
      if (bestBytes.length <= maxBytes) {
        return ImageCompressionResult(
          decodable: true,
          compressed: CompressedImage(bytes: bestBytes, mimeType: 'image/jpeg'),
        );
      }
    } catch (_) {
      // 单档失败继续下一档
    }
  }

  if (bestBytes != null && bestBytes.length < input.length) {
    return ImageCompressionResult(
      decodable: true,
      compressed: CompressedImage(bytes: bestBytes, mimeType: bestMime!),
    );
  }
  // 压缩没有收益（或全部失败）：让调用方决定，不强行降质。
  return const ImageCompressionResult(decodable: true);
}

bool _hasPngSignature(Uint8List bytes) {
  // 8 字节 PNG 魔数: 89 50 4E 47 0D 0A 1A 0A
  if (bytes.length < 8) return false;
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}
