import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart_ts_remuxer.dart';

// ============================================================================
// 纯 Dart FLV → MP4 转封装（Remux）实现
//
// 解析 FLV 容器（参照 FFmpeg libavformat/flvdec.c 的最刚需部分），
// 支持最常见的网页视频组合：
//   - 视频：H.264 (codecId 7, AVC) / H.265 (codecId 12, Enhanced RTMP)
//   - 音频：AAC (soundFormat 10)
// 其他编码（VP6/Sorenson/MP3 等）无法免重编码封装进 MP4，
// 视频编码不支持时抛出明确错误；音频编码不支持时跳过音频。
//
// 与 EV1 配合：EV1 解码后的数据即为标准 FLV（见 ev1_decoder.dart）。
// ============================================================================

/// FLV 标签类型。
class FlvTagType {
  static const int audio = 8;
  static const int video = 9;
  static const int script = 18;
}

/// FLV 解析结果（供测试与调试使用）。
class FlvParseInfo {
  final bool hasVideo;
  final bool hasAudio;
  final int videoSampleCount;
  final int audioSampleCount;
  final int durationMs;
  final int? width;
  final int? height;

  const FlvParseInfo({
    required this.hasVideo,
    required this.hasAudio,
    required this.videoSampleCount,
    required this.audioSampleCount,
    required this.durationMs,
    this.width,
    this.height,
  });
}

/// 内部：一个 FLV 标签在文件中的位置。
class _TagRef {
  final int type;
  final int dataOffset;
  final int dataSize;
  final int timestamp;

  const _TagRef({
    required this.type,
    required this.dataOffset,
    required this.dataSize,
    required this.timestamp,
  });
}

/// 按需读取数据源的接口（文件 / 内存，便于测试）。
abstract class _ByteSource {
  Future<Uint8List> readAt(int offset, int length);
}

class _FileSource implements _ByteSource {
  final RandomAccessFile _raf;
  _FileSource(this._raf);

  @override
  Future<Uint8List> readAt(int offset, int length) async {
    await _raf.setPosition(offset);
    final buf = Uint8List(length);
    var read = 0;
    while (read < length) {
      final n = await _raf.readInto(buf, read, length);
      if (n <= 0) break;
      read += n;
    }
    return read == length ? buf : buf.sublist(0, read);
  }
}

class _MemorySource implements _ByteSource {
  final Uint8List _data;
  _MemorySource(this._data);

  @override
  Future<Uint8List> readAt(int offset, int length) async {
    if (offset >= _data.length) return Uint8List(0);
    final end = (offset + length) > _data.length ? _data.length : offset + length;
    return _data.sublist(offset, end);
  }
}

class FlvDemuxer {
  FlvDemuxer._();

  /// FLV 文件魔数："FLV"。
  static bool isFlv(Uint8List head) =>
      head.length >= 3 && head[0] == 0x46 && head[1] == 0x4C && head[2] == 0x56;

  // ---------------------------------------------------------------------------
  // 主入口
  // ---------------------------------------------------------------------------

  /// 将 FLV 文件转封装为 MP4 文件。
  ///
  /// 两遍处理：第一遍扫描标签（视频/音频样本数据写入临时 spool 文件），
  /// 第二遍由 [Mp4Muxer] 封装为 MP4。内存占用有界。
  ///
  /// 返回输出路径。
  static Future<String> convertFlvToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('FLV file not found', inputPath);
    }
    final fileSize = await inputFile.length();
    if (fileSize < 13) {
      throw FormatException('FLV 文件太小，不是有效的 FLV 流');
    }

    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    onProgress?.call(5);

    final raf = await inputFile.open();
    try {
      final source = _FileSource(raf);
      final head = await source.readAt(0, 13);
      if (!isFlv(head)) {
        throw FormatException('不是有效的 FLV 文件（缺少 FLV 头）');
      }
      final dataOffset = _u32(head, 5);
      if (dataOffset < 9 || dataOffset > fileSize) {
        throw FormatException('FLV 头数据偏移无效');
      }

      final spoolPath = '$outputPath.spool.tmp';
      final spoolFile = File(spoolPath);
      if (await spoolFile.exists()) {
        await spoolFile.delete();
      }
      final spool = await spoolFile.open(mode: FileMode.write);

      try {
        // ---- 第一遍：扫描标签 ----
        final videoSamples = <Mp4Sample>[];
        final audioSamples = <Mp4Sample>[];
        VideoFormat? video;
        AudioFormat? audio;
        var spoolOffset = 0;
        var lastTimestamp = 0;

        await _scanTags(
          source: source,
          fileSize: fileSize,
          startOffset: dataOffset,
          onProgress: (p) => onProgress?.call(5 + p * 50 ~/ 100),
          isCancelled: isCancelled,
          onTag: (tag) async {
            if (tag.type == FlvTagType.video) {
              final data = await source.readAt(tag.dataOffset, tag.dataSize);
              final parsed = _parseVideoTag(data, tag.timestamp);
              if (parsed == null) return; // 结束序列标记等
              if (parsed.avcC != null || parsed.hvcC != null) {
                video = _buildVideoFormat(parsed);
                return;
              }
              if (parsed.sample != null) {
                if (video == null) {
                  throw FormatException('FLV 中缺少视频序列头（avcC/hvcC），无法封装 MP4');
                }
                final sample = parsed.sample!;
                await spool.writeFrom(sample);
                videoSamples.add(Mp4Sample(
                  spoolOffset: spoolOffset,
                  size: sample.length,
                  pts: parsed.pts,
                  dts: parsed.dts,
                  sync: parsed.sync,
                ));
                spoolOffset += sample.length;
              }
            } else if (tag.type == FlvTagType.audio) {
              final data = await source.readAt(tag.dataOffset, tag.dataSize);
              final parsed = _parseAudioTag(data, tag.timestamp);
              if (parsed == null) return; // 不支持的音频编码，跳过
              if (parsed.asc != null) {
                final info = AacConfigParser.fromAsc(parsed.asc!);
                if (info == null) {
                  throw FormatException('FLV 中音频参数（AudioSpecificConfig）无效');
                }
                audio = AudioFormat(
                  asc: info.asc,
                  objectType: info.objectType,
                  sampleRate: info.sampleRate,
                  channels: info.channels,
                );
                return;
              }
              if (parsed.frame != null) {
                if (audio == null) {
                  debugPrint('[FlvDemuxer] 音频样本先于参数出现，丢弃');
                  return;
                }
                await spool.writeFrom(parsed.frame!);
                final audioPts = tag.timestamp * 90;
                audioSamples.add(Mp4Sample(
                  spoolOffset: spoolOffset,
                  size: parsed.frame!.length,
                  pts: audioPts,
                  dts: audioPts,
                  sync: true,
                ));
                spoolOffset += parsed.frame!.length;
              }
            }
            if (tag.timestamp > lastTimestamp) {
              lastTimestamp = tag.timestamp;
            }
          },
        );

        if (video == null && audio == null) {
          throw FormatException('FLV 中没有提取到任何可用的音视频流');
        }
        if (video != null && videoSamples.isEmpty) {
          throw FormatException('FLV 中没有提取到视频样本');
        }

        onProgress?.call(55);
        debugPrint(
          '[FlvDemuxer] Scanned: ${videoSamples.length} video samples, '
          '${audioSamples.length} audio samples',
        );

        // ---- 第二遍：封装 MP4 ----
        await spool.flush();
        await Mp4Muxer.muxMp4(
          spoolPath: spoolPath,
          videoSamples: videoSamples,
          audioSamples: audioSamples,
          video: video,
          audio: audio,
          outputPath: outputPath,
          isCancelled: isCancelled,
          onProgress: (p) => onProgress?.call(60 + p * 40 ~/ 100),
        );
      } finally {
        try {
          await spool.close();
        } catch (_) {}
        try {
          if (await spoolFile.exists()) {
            await spoolFile.delete();
          }
        } catch (_) {}
      }
    } finally {
      await raf.close();
    }

    debugPrint('[FlvDemuxer] MP4 written to $outputPath');
    return outputPath;
  }

  /// 仅解析 FLV 结构信息（不转换），供测试/调试。
  static Future<FlvParseInfo> probe({
    required Uint8List data,
  }) async {
    if (data.length < 13) {
      throw FormatException('不是有效的 FLV 文件（数据过短）');
    }
    final source = _MemorySource(data);
    if (!isFlv(data)) {
      throw FormatException('不是有效的 FLV 文件');
    }
    final head = await source.readAt(0, 13);
    final dataOffset = _u32(head, 5);

    var hasVideo = false, hasAudio = false;
    var videoSamples = 0, audioSamples = 0;
    var lastTimestamp = 0;
    VideoFormat? video;

    await _scanTags(
      source: source,
      fileSize: data.length,
      startOffset: dataOffset,
      onTag: (tag) async {
        if (tag.type == FlvTagType.video) {
          final tagData = await source.readAt(tag.dataOffset, tag.dataSize);
          final parsed = _parseVideoTag(tagData, tag.timestamp);
          if (parsed == null) return;
          hasVideo = true;
          if (parsed.avcC != null || parsed.hvcC != null) {
            video = _buildVideoFormat(parsed);
          } else if (parsed.sample != null) {
            videoSamples++;
          }
        } else if (tag.type == FlvTagType.audio) {
          final tagData = await source.readAt(tag.dataOffset, tag.dataSize);
          final parsed = _parseAudioTag(tagData, tag.timestamp);
          if (parsed == null) return;
          hasAudio = true;
          if (parsed.frame != null) audioSamples++;
        }
        if (tag.timestamp > lastTimestamp) lastTimestamp = tag.timestamp;
      },
    );

    return FlvParseInfo(
      hasVideo: hasVideo,
      hasAudio: hasAudio,
      videoSampleCount: videoSamples,
      audioSampleCount: audioSamples,
      durationMs: lastTimestamp,
      width: video?.width,
      height: video?.height,
    );
  }

  // ---------------------------------------------------------------------------
  // 标签扫描
  // ---------------------------------------------------------------------------

  static Future<void> _scanTags({
    required _ByteSource source,
    required int fileSize,
    required int startOffset,
    required Future<void> Function(_TagRef tag) onTag,
    void Function(int progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var offset = startOffset;
    var prevDataSize = 0;

    while (offset + 15 <= fileSize) {
      if (isCancelled?.call() ?? false) {
        throw FormatException('转换已取消');
      }
      final header = await source.readAt(offset, 15);
      if (header.length < 15) break;

      // PreviousTagSize(4) + TagHeader(11)
      final prevTagSize = _u32(header, 0);
      if (prevDataSize > 0 && prevTagSize != 11 + prevDataSize) {
        debugPrint(
            '[FlvDemuxer] PreviousTagSize 不匹配（期望 ${11 + prevDataSize}，实际 $prevTagSize），'
            '继续尝试解析');
      }
      final tagType = header[4];
      final dataSize = _u24(header, 5);
      final timestamp = _u24(header, 8) | (header[11] << 24);

      final dataOffset = offset + 15;
      final tagEnd = dataOffset + dataSize;
      if (tagEnd > fileSize) break; // 尾部损坏，截断处理

      if (tagType == FlvTagType.video ||
          tagType == FlvTagType.audio ||
          tagType == FlvTagType.script) {
        await onTag(_TagRef(
          type: tagType,
          dataOffset: dataOffset,
          dataSize: dataSize,
          timestamp: timestamp,
        ));
      }

      offset = tagEnd;
      prevDataSize = dataSize;
      if (onProgress != null && fileSize > 0) {
        final progress = (offset * 100 ~/ fileSize).clamp(0, 100);
        onProgress(progress);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 标签解析
  // ---------------------------------------------------------------------------

  /// 视频标签解析结果。
  static ({Uint8List? avcC, Uint8List? hvcC, Uint8List? sample, int pts, int dts, bool sync})?
      _parseVideoTag(Uint8List data, int timestampMs) {
    if (data.length < 5) return null;
    final frameType = data[0] >> 4; // 1=关键帧
    final codecId = data[0] & 0x0F;

    if (codecId == 7) {
      // H.264 / AVC（经典布局：packetType 在字节 1）
      final packetType = data[1];
      final cts24 = _u24(data, 2);
      final cts = cts24 >= 0x800000 ? cts24 - 0x1000000 : cts24; // 有符号
      final payload = data.sublist(5);

      if (packetType == 0) {
        // AVCDecoderConfigurationRecord（avcC 载荷）
        return (avcC: payload, hvcC: null, sample: null, pts: 0, dts: 0, sync: false);
      }
      if (packetType == 2) return null; // end of sequence
      if (packetType != 1) return null;

      final dts = timestampMs * 90;
      return (
        avcC: null,
        hvcC: null,
        sample: payload,
        pts: dts + cts * 90,
        dts: dts,
        sync: frameType == 1,
      );
    }

    if (codecId == 12) {
      // H.265 / HEVC。兼容两种布局：
      //  - Enhanced RTMP：data[1..4] 为 FourCC（'hvc1'/'hev1'），packetType 在字节 5
      //  - 传统扩展布局（旧 FFmpeg 补丁等）：packetType 在字节 1，与 AVC 一致
      final isFourCcLayout = data.length >= 9 &&
          ((data[1] == 0x68 && data[2] == 0x76 && data[3] == 0x63) ||
              (data[1] == 0x68 && data[2] == 0x65 && data[3] == 0x76));
      if (isFourCcLayout) {
        // 'hvc1' 或 'hev1' FourCC：Enhanced RTMP 布局
        final packetType = data[5];
        final cts24 = _u24(data, 6);
        final cts = cts24 >= 0x800000 ? cts24 - 0x1000000 : cts24;
        final payload = data.sublist(9);

        if (packetType == 0) {
          return (avcC: null, hvcC: payload, sample: null, pts: 0, dts: 0, sync: false);
        }
        if (packetType == 1) {
          final dts = timestampMs * 90;
          return (
            avcC: null,
            hvcC: null,
            sample: payload,
            pts: dts + cts * 90,
            dts: dts,
            sync: frameType == 1,
          );
        }
        return null;
      }

      // 传统布局
      final packetType = data[1];
      final cts24 = _u24(data, 2);
      final cts = cts24 >= 0x800000 ? cts24 - 0x1000000 : cts24;
      final payload = data.sublist(5);

      if (packetType == 0) {
        // HEVCDecoderConfigurationRecord（hvcC 载荷）
        return (avcC: null, hvcC: payload, sample: null, pts: 0, dts: 0, sync: false);
      }
      if (packetType == 1) {
        final dts = timestampMs * 90;
        return (
          avcC: null,
          hvcC: null,
          sample: payload,
          pts: dts + cts * 90,
          dts: dts,
          sync: frameType == 1,
        );
      }
      return null;
    }

    // Sorenson H.263(2) / Screen(3) / VP6(4,5) 等：无法免重编码封装进 MP4
    throw FormatException('不支持的 FLV 视频编码（codecId=$codecId），仅支持 H.264/H.265');
  }

  /// 音频标签解析结果。
  static ({Uint8List? asc, Uint8List? frame})? _parseAudioTag(
      Uint8List data, int timestampMs) {
    if (data.isEmpty) return null;
    final soundFormat = data[0] >> 4;

    if (soundFormat == 10) {
      // AAC
      if (data.length < 2) return null;
      final packetType = data[1];
      final payload = data.sublist(2);
      if (packetType == 0) {
        // AudioSpecificConfig
        return (asc: payload, frame: null);
      }
      if (packetType == 1) {
        return (asc: null, frame: payload);
      }
      return null;
    }

    // MP3(2)/ADPCM(1)/Nellymoser(5)/Speex(11) 等：跳过音频，保留视频
    debugPrint('[FlvDemuxer] 不支持的 FLV 音频编码（soundFormat=$soundFormat），跳过音频');
    return null;
  }

  /// 从序列头构建视频配置。
  static VideoFormat _buildVideoFormat(
      ({Uint8List? avcC, Uint8List? hvcC, Uint8List? sample, int pts, int dts, bool sync}) parsed) {
    if (parsed.hvcC != null) {
      return VideoFormat(isHevc: true, rawConfig: parsed.hvcC);
    }
    final avcC = parsed.avcC!;
    final sps = <Uint8List>[];
    final pps = <Uint8List>[];
    _parseAvcC(avcC, sps, pps);
    if (sps.isEmpty || pps.isEmpty) {
      throw FormatException('FLV 中的 avcC 缺少 SPS/PPS');
    }

    var width = 0, height = 0;
    double? frameRate;
    if (sps.isNotEmpty) {
      final info = H264SpsParser.parse(sps.first);
      if (info != null) {
        width = info.width;
        height = info.height;
        frameRate = info.frameRate;
      }
    }
    return VideoFormat(
      isHevc: false,
      sps: sps,
      pps: pps,
      rawConfig: avcC,
      width: width,
      height: height,
      frameRate: frameRate,
    );
  }

  /// 解析 avcC 记录，提取 SPS/PPS NAL 列表。
  static void _parseAvcC(
      Uint8List avcC, List<Uint8List> sps, List<Uint8List> pps) {
    if (avcC.length < 7) return;
    final spsCount = avcC[5] & 0x1F;
    var offset = 6;
    for (int i = 0; i < spsCount && offset + 2 <= avcC.length; i++) {
      final len = (avcC[offset] << 8) | avcC[offset + 1];
      offset += 2;
      if (offset + len > avcC.length) break;
      sps.add(avcC.sublist(offset, offset + len));
      offset += len;
    }
    if (offset >= avcC.length) return;
    final ppsCount = avcC[offset++];
    for (int i = 0; i < ppsCount && offset + 2 <= avcC.length; i++) {
      final len = (avcC[offset] << 8) | avcC[offset + 1];
      offset += 2;
      if (offset + len > avcC.length) break;
      pps.add(avcC.sublist(offset, offset + len));
      offset += len;
    }
  }

  // ---------------------------------------------------------------------------
  // 字节读取辅助
  // ---------------------------------------------------------------------------

  static int _u24(Uint8List data, int offset) =>
      (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];

  static int _u32(Uint8List data, int offset) =>
      (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}
