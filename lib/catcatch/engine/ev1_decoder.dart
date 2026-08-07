import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart_flv_remuxer.dart';

// ============================================================================
// EV1 视频解码器（纯 Dart）
//
// EV1 是部分中文视频站点使用的混淆格式：本质是标准 FLV，
// 但文件开头 100 字节被逐字节 XOR 0xFF 加密
// （参考 https://github.com/Phantom1003/ev1-decoder 的 ev1-dec.py）。
//
// 解码流程：
//   1. 校验文件头（前 3 字节应为 "FLV" XOR 0xFF = 0xB9 0xB3 0xA9）
//   2. 对前 100 字节 XOR 0xFF 还原为 FLV
//   3. 将还原的 FLV 转封装为通用 MP4（H.264/H.265 + AAC，免重编码）
//
// 与参考项目不同：参考项目只还原成 .flv，本项目直接输出通用 MP4。
// ============================================================================

class Ev1Decoder {
  Ev1Decoder._();

  /// EV1 混淆魔数："FLV" ^ 0xFF。
  static const List<int> ev1Magic = [0xB9, 0xB3, 0xA9];

  /// 被混淆的字节数（与参考实现一致）。
  static const int obfuscatedBytes = 100;

  /// 判断文件头是否为 EV1 混淆格式。
  static bool isEv1(Uint8List head) {
    if (head.length < 3) return false;
    for (int i = 0; i < 3; i++) {
      if (head[i] != ev1Magic[i]) return false;
    }
    return true;
  }

  /// 还原 EV1 混淆：对前 [obfuscatedBytes] 字节 XOR 0xFF。
  ///
  /// 这是纯 XOR 变换（应用两次即还原）。调用方应先通过 [isEv1]
  /// 判断是否需要对输入执行还原。
  static Uint8List deobfuscate(Uint8List bytes) {
    final n = bytes.length < obfuscatedBytes ? bytes.length : obfuscatedBytes;
    final out = Uint8List.fromList(bytes);
    for (int i = 0; i < n; i++) {
      out[i] = bytes[i] ^ 0xFF;
    }
    return out;
  }

  /// 将 EV1 文件解码并转封装为 MP4。
  ///
  /// 内部流程：把还原后的 FLV 写入临时文件，再交给 [FlvDemuxer]
  /// 转封装为 MP4（临时文件随后删除）。
  ///
  /// 返回输出路径。
  static Future<String> convertEv1ToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('EV1 file not found', inputPath);
    }

    final raf = await inputFile.open();
    late final Uint8List head;
    try {
      head = await raf.read(16);
    } finally {
      await raf.close();
    }

    if (isEv1(head)) {
      debugPrint('[Ev1Decoder] 检测到 EV1 混淆格式，正在还原为 FLV');
      onProgress?.call(5);

      // 还原前 100 字节，写入临时 FLV 文件
      final tempFlvPath = '$outputPath.ev1_tmp.flv';
      final tempFile = File(tempFlvPath);
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        final rafIn = await inputFile.open();
        try {
          final rafOut = await tempFile.open(mode: FileMode.write);
          try {
            var position = 0;
            const chunkSize = 4 * 1024 * 1024;
            while (true) {
              if (isCancelled?.call() ?? false) {
                throw FormatException('转换已取消');
              }
              final chunk = await rafIn.read(chunkSize);
              if (chunk.isEmpty) break;
              // 只有第一个分块包含被混淆的前 100 字节，其余分块原样写入
              final outChunk = position == 0 ? deobfuscate(chunk) : chunk;
              await rafOut.writeFrom(outChunk);
              position += chunk.length;
              if (onProgress != null) {
                final total = await inputFile.length();
                onProgress(5 + (position * 5 ~/ total).clamp(0, 5));
              }
            }
          } finally {
            await rafOut.close();
          }
        } finally {
          await rafIn.close();
        }

        // 交由 FLV 转封装为 MP4
        return await FlvDemuxer.convertFlvToMp4(
          inputPath: tempFlvPath,
          outputPath: outputPath,
          onProgress: (p) => onProgress?.call(10 + p * 90 ~/ 100),
          isCancelled: isCancelled,
        );
      } finally {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }

    if (FlvDemuxer.isFlv(head)) {
      debugPrint('[Ev1Decoder] 文件实为标准 FLV，直接转封装');
      return await FlvDemuxer.convertFlvToMp4(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    }

    throw FormatException('不是有效的 EV1/FLV 文件（文件头不匹配）');
  }
}
