import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/utils/image_send_compressor.dart';

/// 生成"照片风格"测试图片（渐变 + 少量噪点）：
/// - PNG 编码后足够大（约 3.6MB @1600x1200），用于测试超限压缩
/// - JPEG 编码后足够小（q90 约 340KB），保证能压缩到限制以下
img.Image buildPhotoLikeImage({int width = 1600, int height = 1200}) {
  final rng = Random(7);
  final im = img.Image(width: width, height: height, numChannels: 3);
  for (final p in im) {
    final dx = p.x - width / 2;
    final dy = p.y - height / 2;
    final d = (dx * dx + dy * dy) / (width * height);
    p
      ..r = (128 + 50 * (d % 1) + rng.nextInt(18)).round().clamp(0, 255)
      ..g = (100 + 80 * (p.x / width) + rng.nextInt(18)).round().clamp(0, 255)
      ..b = (150 + 60 * (p.y / height) + rng.nextInt(18)).round().clamp(0, 255);
  }
  return im;
}

void main() {
  // 懒加载的大夹具：1600x1200 照片风格 PNG（约 3.6MB），全组共享只生成一次。
  late Uint8List bigPng;
  late Uint8List bigJpeg;

  setUpAll(() {
    final im = buildPhotoLikeImage();
    bigPng = img.encodePng(im, level: 6);
    bigJpeg = img.encodeJpg(im, quality: 95);
  });

  group('compressImageForSend', () {
    test('JPEG 输入超过 maxBytes 时压缩为更小、可解码且低于上限的 JPEG',
        () async {
      expect(bigJpeg.length, greaterThan(500 * 1024),
          reason: '夹具 JPEG 应显著大于测试上限');
      const maxBytes = 500 * 1024;

      final result = (await compressImageForSend(bigJpeg, maxBytes: maxBytes)).compressed;

      expect(result, isNotNull);
      final bytes = result!.bytes;
      expect(bytes.length, lessThan(bigJpeg.length));
      expect(bytes.length, lessThan(maxBytes));
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
      expect(img.decodeImage(bytes), isNotNull,
          reason: '压缩结果必须是可解码的 JPEG');
    });

    test('PNG 输入超过 maxBytes 时先尝试无损 PNG 重编码，结果可解码且低于上限',
        () async {
      expect(bigPng.length, greaterThan(2 * 1024 * 1024),
          reason: '夹具 PNG 应显著大于测试上限');
      const maxBytes = 1024 * 1024;

      final result = (await compressImageForSend(bigPng, maxBytes: maxBytes)).compressed;

      expect(result, isNotNull);
      final bytes = result!.bytes;
      expect(bytes.length, lessThan(bigPng.length));
      expect(bytes.length, lessThan(maxBytes));
      expect(img.decodeImage(bytes), isNotNull,
          reason: '压缩结果必须是可解码的图片');
    });

    test('无损 PNG 重编码即可达标时优先返回 PNG（保真）', () async {
      // 构造一个 PNG 无损重压缩就能明显变小的图像：
      // 同色大块区域 → 未优化 PNG 很大，level 9 后显著变小。
      final im = img.Image(width: 1200, height: 1200, numChannels: 3);
      for (final p in im) {
        final block = ((p.x ~/ 8) + (p.y ~/ 8)) % 4;
        p
          ..r = [200, 120, 60, 20][block]
          ..g = [80, 200, 120, 60][block]
          ..b = [60, 80, 200, 120][block];
      }
      final loosePng = img.encodePng(im, level: 0); // 不压缩的 PNG
      expect(loosePng.length, greaterThan(2 * 1024 * 1024));

      const maxBytes = 1024 * 1024;
      final result = (await compressImageForSend(loosePng, maxBytes: maxBytes)).compressed;

      expect(result, isNotNull);
      final bytes = result!.bytes;
      expect(bytes.length, lessThan(maxBytes));
      // 无损路径成功：输出仍是 PNG（像素完全保真），而不是 JPEG 降级
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
    });

    test('PNG 带 alpha 通道时 JPEG 降级路径不崩溃且可解码', () async {
      final im = img.Image(width: 800, height: 800, numChannels: 4);
      final rng = Random(3);
      for (final p in im) {
        p
          ..r = rng.nextInt(256)
          ..g = rng.nextInt(256)
          ..b = rng.nextInt(256)
          ..a = rng.nextInt(256);
      }
      final alphaPng = img.encodePng(im, level: 0); // 大尺寸透明 PNG
      expect(alphaPng.length, greaterThan(2 * 1024 * 1024));

      const maxBytes = 1024 * 1024;
      final result = (await compressImageForSend(alphaPng, maxBytes: maxBytes)).compressed;

      expect(result, isNotNull);
      final bytes = result!.bytes;
      expect(bytes.length, lessThan(maxBytes));
      expect(img.decodeImage(bytes), isNotNull,
          reason: '带 alpha 的 PNG 降级为 JPEG 后必须可解码');
    });

    test('输入已在上限以内时返回 null（不做无谓重编码，字节原样保留）',
        () async {
      final tiny = img.encodePng(buildPhotoLikeImage(width: 64, height: 64));
      expect(tiny.length, lessThan(10 * 1024 * 1024));

      final outcome =
          await compressImageForSend(tiny, maxBytes: 10 * 1024 * 1024);

      expect(outcome.decodable, isTrue);
      expect(outcome.compressed, isNull);
    });

    test('无法解码的字节 decodable=false（优雅降级，不抛异常）', () async {
      final garbage = Uint8List.fromList(List.generate(256, (i) => i * 7 % 256));

      // maxBytes 必须小于输入才会触发解码尝试
      final outcome = await compressImageForSend(garbage, maxBytes: 128);

      expect(outcome.decodable, isFalse,
          reason: '无法解码的图片必须标记为不可发送，调用方据此走跳过路径');
      expect(outcome.compressed, isNull);
    });

    test('空输入 decodable=true 且无压缩结果', () async {
      final outcome =
          await compressImageForSend(Uint8List(0), maxBytes: 1024);

      expect(outcome.decodable, isTrue);
      expect(outcome.compressed, isNull);
    });
  });
}
