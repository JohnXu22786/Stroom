import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

// ============================================================================
// 纯 Dart MPEG-TS → MP4 转封装（Remux）实现
//
// 设计目标（参照 FFmpeg 中 libavformat 的 mpegts.c / movenc.c 最刚需部分）：
//   1. 解析 TS 包（PAT/PMT 获取 PID，PES 重组并提取 PTS/DTS）
//   2. 从 SPS 解析分辨率/帧率，从 ADTS 头解析 AAC 参数
//   3. 两遍式处理：第一遍解复用并将样本写入临时 spool 文件（内存有界），
//      第二遍封装 MP4（mdat + moov），保证 stts/ctts/stss/stco/stsz 正确
//   4. 仅支持免重编码的编码格式：H.264 / H.265 视频 + AAC 音频
//      （与 MP4 容器兼容，可直接转封装；其他编码格式给出明确错误）
//
// 转封装（remux）不是转码：不修改任何视频/音频帧数据，
// 只改变容器（MPEG-TS → ISO BMFF / MP4）。
// ============================================================================

// ============================================================================
// 数据结构
// ============================================================================

/// 单个 MPEG-TS 包（188 字节）。
class TsPacket {
  final int pid;
  final Uint8List payload;
  final bool payloadUnitStart;

  const TsPacket({
    required this.pid,
    required this.payload,
    this.payloadUnitStart = false,
  });
}

/// 通过 PAT/PMT 得到的节目流 PID。
class ProgramPids {
  final int videoPid;
  final int? audioPid;

  /// PMT 中的 stream_type：0x1B = H.264，0x24 = H.265，0x0F = AAC
  final int videoStreamType;
  final int? audioStreamType;

  const ProgramPids({
    required this.videoPid,
    this.audioPid,
    this.videoStreamType = 0x1B,
    this.audioStreamType,
  });
}

/// 一个已解析的 H.264/H.265 NAL 单元（不含起始码）。
class H264NalUnit {
  final int type;
  final Uint8List data;

  const H264NalUnit({required this.type, required this.data});
}

/// 一个原始 AAC 帧（不含 ADTS 头）。
class AacFrame {
  final Uint8List data;

  const AacFrame({required this.data});
}

/// 一个完整的 PES 包（已剥离 PES 头，PTS/DTS 为 90kHz 时钟）。
class PesPacket {
  final int? pts;
  final int? dts;
  final Uint8List data;

  const PesPacket({required this.pts, required this.dts, required this.data});
}

/// 一个待写入 MP4 的样本（数据位于 spool 文件中）。
class Mp4Sample {
  /// 样本数据在 spool 文件中的偏移
  final int spoolOffset;

  /// 样本数据长度（字节）
  final int size;

  /// 展示时间戳（90kHz）
  final int pts;

  /// 解码时间戳（90kHz）
  final int dts;

  /// 是否为关键帧（视频）
  final bool sync;

  const Mp4Sample({
    required this.spoolOffset,
    required this.size,
    required this.pts,
    required this.dts,
    required this.sync,
  });
}

/// 视频编码配置（用于 MP4 的 stsd / avcC / hvcC）。
class VideoFormat {
  final bool isHevc;

  /// H.264: SPS/PPS 原始 NAL 数据（含 NAL 头，不含起始码）
  final List<Uint8List> sps;
  final List<Uint8List> pps;

  /// H.265: VPS 原始 NAL 数据
  final List<Uint8List> vps;

  /// 直接使用现成的配置记录（如 FLV 流中的 avcC/hvcC 原样拷贝）
  final Uint8List? rawConfig;

  final int width;
  final int height;

  /// 估算帧率（可选，来自 SPS VUI）
  final double? frameRate;

  const VideoFormat({
    this.isHevc = false,
    this.sps = const [],
    this.pps = const [],
    this.vps = const [],
    this.rawConfig,
    this.width = 0,
    this.height = 0,
    this.frameRate,
  });
}

/// 音频编码配置（用于 MP4 的 mp4a / esds）。
class AudioFormat {
  /// AudioSpecificConfig（2~5 字节）
  final Uint8List asc;

  /// MPEG-4 Audio Object Type（AAC LC = 2）
  final int objectType;

  final int sampleRate;
  final int channels;

  /// 每帧采样数（AAC 固定 1024）
  final int samplesPerFrame;

  const AudioFormat({
    required this.asc,
    required this.objectType,
    required this.sampleRate,
    required this.channels,
    this.samplesPerFrame = 1024,
  });
}

/// 从 H.264 SPS 解析出的信息。
class H264SpsInfo {
  final int width;
  final int height;
  final double? frameRate;

  const H264SpsInfo({
    required this.width,
    required this.height,
    this.frameRate,
  });
}

/// 从 ADTS/ASC 解析出的 AAC 参数。
class AacStreamInfo {
  final int objectType;
  final int sampleRate;
  final int channels;
  final Uint8List asc;

  const AacStreamInfo({
    required this.objectType,
    required this.sampleRate,
    required this.channels,
    required this.asc,
  });
}

// ============================================================================
// 位读取器（用于 SPS 解析）
// ============================================================================

class _BitReader {
  final Uint8List data;
  int _bitPos = 0;

  _BitReader(this.data);

  int readBits(int n) {
    int value = 0;
    for (int i = 0; i < n; i++) {
      final byteIdx = _bitPos >> 3;
      if (byteIdx >= data.length) break;
      final bit = (data[byteIdx] >> (7 - (_bitPos & 7))) & 1;
      value = (value << 1) | bit;
      _bitPos++;
    }
    return value;
  }

  void skipBits(int n) => _bitPos += n;

  /// 无符号指数哥伦布编码（ue(v)）
  int readUe() {
    int zeros = 0;
    while (readBits(1) == 0) {
      zeros++;
      if (zeros > 31) break;
    }
    if (zeros == 0) return 0;
    return (1 << zeros) - 1 + readBits(zeros);
  }

  /// 有符号指数哥伦布编码（se(v)）
  int readSe() {
    final ue = readUe();
    final k = ue >> 1;
    return (ue & 1) == 0 ? -k : k + 1;
  }
}

// ============================================================================
// H.264 SPS 解析（分辨率 + VUI 帧率）
// ============================================================================

class H264SpsParser {
  H264SpsParser._();

  static const _highProfiles = {
    100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135,
  };

  /// 解析 H.264 SPS NAL 单元（数据含 NAL 头字节）。
  static H264SpsInfo? parse(Uint8List sps) {
    if (sps.length < 4) return null;
    final reader = _BitReader(sps);
    reader.skipBits(8); // NAL 头
    final profileIdc = reader.readBits(8);
    reader.skipBits(8); // constraint flags
    reader.readBits(8); // level_idc
    reader.readUe(); // seq_parameter_set_id

    if (_highProfiles.contains(profileIdc)) {
      final chromaFormatIdc = reader.readUe();
      if (chromaFormatIdc == 3) reader.skipBits(1); // separate_colour_plane_flag
      reader.readUe(); // bit_depth_luma_minus8
      reader.readUe(); // bit_depth_chroma_minus8
      reader.skipBits(1); // qpprime_y_zero_transform_bypass_flag
      if (reader.readBits(1) == 1) {
        // seq_scaling_matrix_present_flag —— 带缩放矩阵的 SPS 极少见，放弃解析
        return null;
      }
    }

    reader.readUe(); // log2_max_frame_num_minus4
    final pocType = reader.readUe();
    if (pocType == 0) {
      reader.readUe(); // log2_max_pic_order_cnt_lsb_minus4
    } else if (pocType == 1) {
      reader.skipBits(1); // delta_pic_order_always_zero_flag
      reader.readSe(); // offset_for_non_ref_pic
      reader.readSe(); // offset_for_top_to_bottom_field
      final n = reader.readUe(); // num_ref_frames_in_pic_order_cnt_cycle
      for (int i = 0; i < n; i++) {
        reader.readSe();
      }
    }
    reader.readUe(); // max_num_ref_frames
    reader.skipBits(1); // gaps_in_frame_num_value_allowed_flag
    final picWidthInMbsMinus1 = reader.readUe();
    final picHeightInMapUnitsMinus1 = reader.readUe();
    final frameMbsOnlyFlag = reader.readBits(1);
    if (frameMbsOnlyFlag == 0) {
      reader.skipBits(1); // mb_adaptive_frame_field_flag
    }
    reader.skipBits(1); // direct_8x8_inference_flag

    var cropLeft = 0, cropRight = 0, cropTop = 0, cropBottom = 0;
    if (reader.readBits(1) == 1) {
      // frame_cropping_flag
      cropLeft = reader.readUe();
      cropRight = reader.readUe();
      cropTop = reader.readUe();
      cropBottom = reader.readUe();
    }

    double? frameRate;
    if (reader.readBits(1) == 1) {
      // vui_parameters_present_flag
      frameRate = _parseVuiTiming(reader);
    }

    // 4:2:0 裁剪单位为 2
    final width = (picWidthInMbsMinus1 + 1) * 16 - (cropLeft + cropRight) * 2;
    final heightUnit = 2 - frameMbsOnlyFlag;
    final height = (picHeightInMapUnitsMinus1 + 1) * 16 * heightUnit -
        (cropTop + cropBottom) * heightUnit * 2;
    if (width <= 0 || height <= 0) return null;
    return H264SpsInfo(width: width, height: height, frameRate: frameRate);
  }

  /// 跳过 VUI 中 timing_info 之前的字段，读取帧率。
  static double? _parseVuiTiming(_BitReader reader) {
    if (reader.readBits(1) == 1) {
      // aspect_ratio_info_present_flag
      final aspectIdc = reader.readBits(8);
      if (aspectIdc == 255) {
        reader.skipBits(32); // sar_width + sar_height
      }
    }
    if (reader.readBits(1) == 1) {
      reader.skipBits(1); // overscan_appropriate_flag
    }
    if (reader.readBits(1) == 1) {
      // video_signal_type_present_flag
      reader.skipBits(3); // video_format
      reader.skipBits(1); // video_full_range_flag
      if (reader.readBits(1) == 1) {
        // colour_description_present_flag
        reader.skipBits(24);
      }
    }
    if (reader.readBits(1) == 1) {
      // chroma_loc_info_present_flag
      reader.readUe(); // chroma_sample_loc_type_top_field
      reader.readUe(); // chroma_sample_loc_type_bottom_field
    }
    if (reader.readBits(1) != 1) {
      // timing_info_present_flag
      return null;
    }
    final numUnitsInTick = reader.readBits(32);
    final timeScale = reader.readBits(32);
    reader.skipBits(1); // fixed_frame_rate_flag
    if (numUnitsInTick == 0 || timeScale == 0) return null;
    return timeScale / (2 * numUnitsInTick);
  }
}

// ============================================================================
// AAC：ADTS 头 / AudioSpecificConfig 解析
// ============================================================================

class AacConfigParser {
  AacConfigParser._();

  static const List<int?> _sampleRates = [
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
    16000, 12000, 11025, 8000, 7350, null, null, null,
  ];

  /// 从 ADTS 帧头（至少 7 字节）解析 AAC 参数。
  static AacStreamInfo? fromAdts(Uint8List data) {
    if (data.length < 7) return null;
    if (data[0] != 0xFF || (data[1] & 0xF0) != 0xF0) return null;
    final objectType = ((data[2] >> 6) & 0x03) + 1;
    final sfIndex = (data[2] >> 2) & 0x0F;
    final channelConfig = ((data[2] & 0x01) << 2) | (data[3] >> 6);
    final sampleRate = _sampleRates[sfIndex];
    if (sfIndex == 15 || sampleRate == null) return null;
    return AacStreamInfo(
      objectType: objectType,
      sampleRate: sampleRate,
      channels: channelConfig,
      asc: buildAsc(objectType: objectType, sfIndex: sfIndex, channels: channelConfig),
    );
  }

  /// 从 FLV 流中的 AudioSpecificConfig（2 字节）解析 AAC 参数。
  static AacStreamInfo? fromAsc(Uint8List asc) {
    if (asc.length < 2) return null;
    final objectType = (asc[0] >> 3) & 0x1F;
    final sfIndex = ((asc[0] & 0x07) << 1) | (asc[1] >> 7);
    final channelConfig = (asc[1] >> 3) & 0x0F;
    final sampleRate = _sampleRates[sfIndex];
    if (sfIndex == 15 || sampleRate == null) return null;
    return AacStreamInfo(
      objectType: objectType,
      sampleRate: sampleRate,
      channels: channelConfig,
      asc: Uint8List.fromList(asc.sublist(0, 2)),
    );
  }

  /// 构造 2 字节 AudioSpecificConfig。
  static Uint8List buildAsc({
    required int objectType,
    required int sfIndex,
    required int channels,
  }) {
    return Uint8List.fromList([
      (objectType << 3) | ((sfIndex >> 1) & 0x07),
      ((sfIndex & 0x01) << 7) | (channels << 3),
    ]);
  }
}

// ============================================================================
// TS 解复用器
// ============================================================================

class TsDemuxer {
  TsDemuxer._();

  // ---------------------------------------------------------------------------
  // TS 包解析
  // ---------------------------------------------------------------------------

  /// 解析原始字节为 [TsPacket] 列表（每个包 188 字节）。
  ///
  /// 带容错：自动跳过开头的垃圾字节，遇到丢失的同步字节会重新同步。
  /// 数据不足 188 字节时抛出 [ArgumentError]；完全找不到同步字节时抛出
  /// [FormatException]。
  static List<TsPacket> parseTsPackets(Uint8List data) {
    if (data.isEmpty) {
      throw ArgumentError('TS data is empty');
    }
    if (data.length < 188) {
      throw ArgumentError(
          'TS data too short: ${data.length} bytes (minimum 188)');
    }

    final packets = <TsPacket>[];
    int offset = _findSync(data, 0);
    if (offset < 0) {
      throw FormatException('Missing TS sync byte');
    }

    while (offset + 188 <= data.length) {
      if (data[offset] != 0x47) {
        // 包损坏，重新同步
        final next = _findSync(data, offset + 1);
        if (next < 0) break;
        offset = next;
        continue;
      }

      final pid = ((data[offset + 1] & 0x1F) << 8) | data[offset + 2];
      final payloadUnitStart = (data[offset + 1] & 0x40) != 0;

      // Adaptation field control：低 2 位
      final adaptFieldCtrl = data[offset + 3] & 0x30;
      int payloadStart = 4;
      if (adaptFieldCtrl == 0x20 || adaptFieldCtrl == 0x30) {
        final adaptLen = data[offset + 4];
        payloadStart = 4 + 1 + adaptLen;
      }

      final absolutePayloadStart = offset + payloadStart;
      final absolutePayloadEnd = offset + 188;
      if (absolutePayloadStart < absolutePayloadEnd) {
        packets.add(TsPacket(
          pid: pid,
          payload: data.sublist(absolutePayloadStart, absolutePayloadEnd),
          payloadUnitStart: payloadUnitStart,
        ));
      } else {
        packets.add(TsPacket(
          pid: pid,
          payload: Uint8List(0),
          payloadUnitStart: payloadUnitStart,
        ));
      }
      offset += 188;
    }
    return packets;
  }

  /// 从 [start] 开始查找下一个合理的同步字节位置。
  static int _findSync(Uint8List data, int start) {
    for (int i = start; i + 188 <= data.length; i++) {
      if (data[i] == 0x47) {
        // 候选：其后 188 字节处也是同步字节（或已到末尾）
        if (i + 376 <= data.length && data[i + 188] == 0x47) {
          return i;
        }
        if (i + 188 >= data.length) return i;
        if (i + 376 > data.length) {
          // 只有一个包的空间，检查是否所有字节都是对齐的包
          var aligned = true;
          for (int j = i + 188; j < data.length; j += 188) {
            if (data[j] != 0x47) {
              aligned = false;
              break;
            }
          }
          if (aligned) return i;
        }
      }
    }
    return -1;
  }

  // ---------------------------------------------------------------------------
  // PAT / PMT 解析（PSI section 重组，支持跨包）
  // ---------------------------------------------------------------------------

  /// 找到视频/音频 PID（通过 PAT + PMT）。
  static ProgramPids? findProgramMap(List<TsPacket> packets) {
    int? pmtPid;
    final pat = _PsiAssembler();
    final pmt = _PsiAssembler();
    ProgramPids? result;

    for (final pkt in packets) {
      if (result != null) break;
      if (pkt.pid == 0x0000) {
        pat.feed(pkt.payload, pkt.payloadUnitStart, (section) {
          pmtPid ??= _parsePat(section);
        });
      } else if (pmtPid != null && pkt.pid == pmtPid) {
        pmt.feed(pkt.payload, pkt.payloadUnitStart, (section) {
          result ??= _parsePmt(section);
        });
      }
    }
    return result;
  }

  /// 解析 PAT section，返回 PMT PID；无效则返回 null。
  static int? _parsePat(Uint8List section) {
    if (section.length < 12) return null;
    if (section[0] != 0x00) return null; // table_id = PAT
    final sectionLength = ((section[1] & 0x0F) << 8) | section[2];
    final sectionEnd = 3 + sectionLength - 4; // 去掉 CRC
    if (sectionEnd > section.length) return null;

    int offset = 8; // 跳过 ts_id(2) version(1) section(1) last_section(1)
    while (offset + 4 <= sectionEnd) {
      final programNumber = (section[offset] << 8) | section[offset + 1];
      final pid = ((section[offset + 2] & 0x1F) << 8) | section[offset + 3];
      offset += 4;
      if (programNumber != 0) return pid;
    }
    return null;
  }

  /// 解析 PMT section，返回节目流 PID 信息；无效则返回 null。
  static ProgramPids? _parsePmt(Uint8List section) {
    if (section.length < 16) return null;
    if (section[0] != 0x02) return null; // table_id = PMT
    final sectionLength = ((section[1] & 0x0F) << 8) | section[2];
    final sectionEnd = 3 + sectionLength - 4; // 去掉 CRC
    if (sectionEnd > section.length) return null;

    // 跳过 table_id(1) section_length(2) program_number(2) version(1)
    // section_number(1) last_section_number(1) PCR_PID(2) → 共 10 字节
    int offset = 10;
    if (offset + 2 > sectionEnd) return null;
    final programInfoLength = ((section[offset] & 0x0F) << 8) | section[offset + 1];
    offset += 2 + programInfoLength;

    int? videoPid;
    int? audioPid;
    var videoStreamType = 0x1B;
    int? audioStreamType;

    while (offset + 5 <= sectionEnd) {
      final streamType = section[offset];
      final pid = ((section[offset + 1] & 0x1F) << 8) | section[offset + 2];
      final esInfoLength =
          ((section[offset + 3] & 0x0F) << 8) | section[offset + 4];
      offset += 5 + esInfoLength;

      switch (streamType) {
        case 0x1B: // H.264
        case 0x24: // H.265
          videoPid ??= pid;
          if (videoPid == pid) videoStreamType = streamType;
        case 0x0F: // AAC
          audioPid ??= pid;
          if (audioPid == pid) audioStreamType = streamType;
      }
    }

    if (videoPid == null) return null;
    return ProgramPids(
      videoPid: videoPid,
      audioPid: audioPid,
      videoStreamType: videoStreamType,
      audioStreamType: audioStreamType,
    );
  }

  // ---------------------------------------------------------------------------
  // PES 重组
  // ---------------------------------------------------------------------------

  /// 按 PID 重组 TS 包为 PES 包列表。
  static List<PesPacket> extractPesPackets(List<TsPacket> packets, int pid) {
    final result = <PesPacket>[];
    final assembler = _PesAssembler();
    for (final pkt in packets) {
      if (pkt.pid != pid) continue;
      assembler.feed(pkt.payload, pkt.payloadUnitStart, result.add);
    }
    assembler.flush(result.add);
    return result;
  }

  /// 提取视频 PID 的连续码流（PES 载荷拼接，annex B 格式）。
  static Uint8List extractVideoBitstream(
      List<TsPacket> packets, ProgramPids pids) {
    final builder = BytesBuilder();
    final assembler = _PesAssembler();
    for (final pkt in packets) {
      if (pkt.pid != pids.videoPid) continue;
      assembler.feed(pkt.payload, pkt.payloadUnitStart, (pes) {
        builder.add(pes.data);
      });
    }
    assembler.flush((pes) => builder.add(pes.data));
    return builder.toBytes();
  }

  /// 提取音频 PID 的连续码流（PES 载荷拼接，ADTS 格式）。
  static Uint8List extractAudioBitstream(
      List<TsPacket> packets, ProgramPids pids) {
    if (pids.audioPid == null) return Uint8List(0);
    final builder = BytesBuilder();
    final assembler = _PesAssembler();
    for (final pkt in packets) {
      if (pkt.pid != pids.audioPid) continue;
      assembler.feed(pkt.payload, pkt.payloadUnitStart, (pes) {
        builder.add(pes.data);
      });
    }
    assembler.flush((pes) => builder.add(pes.data));
    return builder.toBytes();
  }

  // ---------------------------------------------------------------------------
  // NAL / AAC 帧提取
  // ---------------------------------------------------------------------------

  /// 从 annex B 格式数据中提取 NAL 单元。
  ///
  /// [hevc] 为 true 时按 H.265 的 NAL 头（2 字节）解析类型。
  static List<H264NalUnit> extractNalus(Uint8List data, {bool hevc = false}) {
    final nalus = <H264NalUnit>[];
    if (data.length < 4) return nalus;

    int i = 0;
    while (i < data.length - 3) {
      // 查找起始码
      int startLen = 0;
      if (data[i] == 0x00 && data[i + 1] == 0x00) {
        if (data[i + 2] == 0x01) {
          startLen = 3;
        } else if (i + 3 < data.length &&
            data[i + 2] == 0x00 &&
            data[i + 3] == 0x01) {
          startLen = 4;
        }
      }

      if (startLen > 0) {
        final naluStart = i + startLen;

        // 找到本 NAL 单元的结束位置（下一个起始码）
        int naluEnd = naluStart;
        while (naluEnd < data.length) {
          if (naluEnd + 3 < data.length &&
              data[naluEnd] == 0x00 &&
              data[naluEnd + 1] == 0x00 &&
              data[naluEnd + 2] == 0x01) {
            break;
          }
          if (naluEnd + 4 < data.length &&
              data[naluEnd] == 0x00 &&
              data[naluEnd + 1] == 0x00 &&
              data[naluEnd + 2] == 0x00 &&
              data[naluEnd + 3] == 0x01) {
            break;
          }
          naluEnd++;
        }

        if (naluEnd > naluStart) {
          final naluData = data.sublist(naluStart, naluEnd);
          final nalType = hevc ? (naluData[0] >> 1) & 0x3F : naluData[0] & 0x1F;
          nalus.add(H264NalUnit(type: nalType, data: naluData));
        }
        i = naluEnd;
      } else {
        i++;
      }
    }
    return nalus;
  }

  /// 提取 H.264 NAL 单元（兼容旧 API）。
  static List<H264NalUnit> extractH264Nalus(Uint8List data) =>
      extractNalus(data, hevc: false);

  /// 从 ADTS 封装的数据中提取 AAC 帧（去掉 ADTS 头）。
  static List<AacFrame> extractAacFrames(Uint8List data) {
    final frames = <AacFrame>[];
    int i = 0;

    while (i + 6 < data.length) {
      if (data[i] == 0xFF && (data[i + 1] & 0xF0) == 0xF0) {
        final frameLength = ((data[i + 3] & 0x03) << 11) |
            (data[i + 4] << 3) |
            ((data[i + 5] >> 5) & 0x07);

        if (frameLength < 7 || i + frameLength > data.length) {
          i++;
          continue;
        }

        frames.add(AacFrame(data: data.sublist(i + 7, i + frameLength)));
        i += frameLength;
      } else {
        i++;
      }
    }

    return frames;
  }

  /// 找到第一段 ADTS 帧头（用于解析 AAC 参数）。
  static Uint8List? findFirstAdtsHeader(Uint8List data) {
    for (int i = 0; i + 6 < data.length; i++) {
      if (data[i] == 0xFF && (data[i + 1] & 0xF0) == 0xF0) {
        final frameLength = ((data[i + 3] & 0x03) << 11) |
            (data[i + 4] << 3) |
            ((data[i + 5] >> 5) & 0x07);
        if (frameLength >= 7 && i + frameLength <= data.length) {
          return data.sublist(i, i + 7);
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 主入口：TS → MP4
  // ---------------------------------------------------------------------------

  /// 将 TS 文件转封装为 MP4 文件。
  ///
  /// 两遍式处理：
  ///   - 第一遍：流式读取 TS，重组 PES，提取 H.264/H.265 与 AAC 样本，
  ///     将样本数据写入临时 spool 文件（内存占用有界）；
  ///   - 第二遍：由 [Mp4Muxer] 将 spool 中的样本封装为 MP4。
  ///
  /// [isCancelled] 每次读取后检查，返回 true 时停止转换并抛出
  /// [FormatException]。
  ///
  /// 返回输出路径。
  static Future<String> convertTsToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('TS file not found', inputPath);
    }

    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    onProgress?.call(5);

    final fileSize = await inputFile.length();
    if (fileSize < 188) {
      throw FormatException('TS 文件太小，不是有效的 TS 流');
    }

    final spoolPath = '$outputPath.spool.tmp';
    final spoolFile = File(spoolPath);
    if (await spoolFile.exists()) {
      await spoolFile.delete();
    }
    final spool = await spoolFile.open(mode: FileMode.write);

    final videoSamples = <Mp4Sample>[];
    final audioSamples = <Mp4Sample>[];
    final spsList = <Uint8List>[];
    final ppsList = <Uint8List>[];
    final vpsList = <Uint8List>[];
    AudioFormat? audioFormat;
    VideoFormat? videoFormat;
    int? lastVideoDts;
    int? audioLastPts90k;
    double? frameRate;
    // 时间轴真实标志：初始为 true，任一样本时间戳为合成时置 false
    var videoTimelineReal = true;
    var audioTimelineReal = true;
    var spoolOffset = 0;

    try {
      // ---- 第一遍：解复用 ----
      final raf = await inputFile.open();
      final patAssembler = _PsiAssembler();
      final pmtAssembler = _PsiAssembler();
      ProgramPids? pids;
      int? pmtPid;
      final videoAssembler = _PesAssembler();
      final audioAssembler = _PesAssembler();
      var carry = Uint8List(0);
      var readBytes = 0;
      const chunkSize = 4 * 1024 * 1024;

      void handleVideoPes(PesPacket pes) {
        final nalus = extractNalus(pes.data, hevc: pids!.videoStreamType == 0x24);
        if (nalus.isEmpty) return;

        // 收集 SPS/PPS/VPS（用于 avcC/hvcC）
        for (final n in nalus) {
          if (pids!.videoStreamType == 0x24) {
            if (n.type == 32) vpsList.add(n.data);
            if (n.type == 33 && !spsList.contains(n.data)) spsList.add(n.data);
            if (n.type == 34 && !ppsList.contains(n.data)) ppsList.add(n.data);
          } else {
            if (n.type == 7 && !spsList.contains(n.data)) {
              spsList.add(n.data);
              // 尽早解析 SPS 帧率（PES 缺时间戳时用于合成时间轴）
              frameRate ??= H264SpsParser.parse(n.data)?.frameRate;
            }
            if (n.type == 8 && !ppsList.contains(n.data)) ppsList.add(n.data);
          }
        }

        // 仅包含参数集/SEI 的 PES 不构成样本
        final isHevc = pids!.videoStreamType == 0x24;
        final hasVcl = nalus.any((n) =>
            isHevc ? n.type <= 31 : (n.type == 1 || n.type == 5));
        if (!hasVcl) return;

        // 样本数据 = 4 字节长度前缀的 NAL 串联（MP4 mdat 格式）
        final sampleData = BytesBuilder();
        for (final n in nalus) {
          _writeU32(sampleData, n.data.length);
          sampleData.add(n.data);
        }
        final bytes = sampleData.toBytes();
        spool.writeFromSync(bytes);

        // 时间轴真实标志：任一样本时间戳为合成则整条时间轴不可信
        videoTimelineReal = videoTimelineReal && (pes.pts != null || pes.dts != null);
        var pts = pes.pts;
        var dts = pes.dts;
        dts ??= pts;
        if (dts == null) {
          // PES 无时间戳：按帧率估算
          final fr = frameRate;
          final dur = fr != null && fr > 0
              ? (90000 / fr).round()
              : 3000;
          dts = (lastVideoDts ?? 0) + dur;
          pts = dts;
        }
        lastVideoDts = dts;

        final sync = nalus.any((n) =>
            isHevc ? (n.type >= 16 && n.type <= 21) : n.type == 5);
        videoSamples.add(Mp4Sample(
          spoolOffset: spoolOffset,
          size: bytes.length,
          pts: pts ?? dts,
          dts: dts,
          sync: sync,
        ));
        spoolOffset += bytes.length;
      }

      void handleAudioPes(PesPacket pes) {
        final frames = extractAacFrames(pes.data);
        if (frames.isEmpty) return;
        if (audioFormat == null) {
          // 解析 AAC 参数失败时放弃音频（无法封装为 MP4 音轨）
          final header = findFirstAdtsHeader(pes.data);
          final info =
              header == null ? null : AacConfigParser.fromAdts(header);
          if (info == null) {
            debugPrint('[TsDemuxer] 无法解析 ADTS 头，音频将被丢弃');
            return;
          }
          audioFormat = AudioFormat(
            asc: info.asc,
            objectType: info.objectType,
            sampleRate: info.sampleRate,
            channels: info.channels,
          );
        }
        // PES 内多帧时按 1024 采样/帧分摊 PTS（90kHz）
        final frameDur90k = audioFormat!.samplesPerFrame * Mp4Muxer.kTimescale ~/
            audioFormat!.sampleRate;
        audioTimelineReal = audioTimelineReal && pes.pts != null;
        final pesPts = pes.pts;
        for (int i = 0; i < frames.length; i++) {
          final frame = frames[i];
          spool.writeFromSync(frame.data);
          final int pts90k;
          if (pesPts != null) {
            pts90k = pesPts + i * frameDur90k;
          } else if (audioLastPts90k != null) {
            // 本 PES 无时间戳：接续上一 PES 的时间轴
            pts90k = audioLastPts90k! + (i + 1) * frameDur90k;
          } else {
            pts90k = i * frameDur90k;
          }
          audioLastPts90k = pts90k;
          audioSamples.add(Mp4Sample(
            spoolOffset: spoolOffset,
            size: frame.data.length,
            pts: pts90k,
            dts: pts90k,
            sync: true,
          ));
          spoolOffset += frame.data.length;
        }
      }

      try {
        while (true) {
          if (isCancelled?.call() ?? false) {
            throw FormatException('转换已取消');
          }
          final chunk = await raf.read(chunkSize);
          if (chunk.isEmpty) break;
          readBytes += chunk.length;

          final buffer =
              carry.isEmpty ? chunk : Uint8List.fromList([...carry, ...chunk]);
          if (buffer.length < 188) {
            carry = buffer;
            continue;
          }
          late final List<TsPacket> packets;
          try {
            packets = parseTsPackets(buffer);
          } on FormatException {
            // 后续全是垃圾字节（文件尾部损坏），停止解析
            break;
          }
          // 保留末尾不足 188 字节的部分，下一轮继续
          final usable = packets.length * 188;
          carry = usable < buffer.length ? buffer.sublist(usable) : Uint8List(0);

          if (pids == null) {
            for (final pkt in packets) {
              if (pkt.pid == 0x0000) {
                patAssembler.feed(pkt.payload, pkt.payloadUnitStart, (s) {
                  pmtPid ??= _parsePat(s);
                });
              } else if (pmtPid != null && pkt.pid == pmtPid) {
                pmtAssembler.feed(pkt.payload, pkt.payloadUnitStart, (s) {
                  pids ??= _parsePmt(s);
                });
              }
            }
            if (pids != null) {
              _validatePids(pids!);
            }
          }

          if (pids != null) {
            for (final pkt in packets) {
              if (pkt.pid == pids!.videoPid) {
                videoAssembler.feed(pkt.payload, pkt.payloadUnitStart,
                    handleVideoPes);
              } else if (pids!.audioPid != null && pkt.pid == pids!.audioPid) {
                audioAssembler.feed(pkt.payload, pkt.payloadUnitStart,
                    handleAudioPes);
              }
            }
          }

          if (fileSize > 0) {
            final progress = 10 + (readBytes * 45 ~/ fileSize);
            onProgress?.call(progress.clamp(10, 55));
          }
        }
      } finally {
        await raf.close();
      }

      if (pids == null) {
        throw FormatException('未在 TS 流中找到节目映射（PAT/PMT），无法转换');
      }

      // EOF：冲刷残留 PES
      videoAssembler.flush(handleVideoPes);
      audioAssembler.flush(handleAudioPes);

      // 构建视频配置
      final isHevc = pids!.videoStreamType == 0x24;
      if (isHevc) {
        if (spsList.isEmpty && ppsList.isEmpty) {
          throw FormatException('TS 流中未找到 H.265 参数集（VPS/SPS/PPS），无法封装 MP4');
        }
      } else {
        if (spsList.isEmpty || ppsList.isEmpty) {
          throw FormatException('TS 流中未找到 H.264 参数集（SPS/PPS），无法封装 MP4');
        }
      }

      var width = 0, height = 0;
      if (spsList.isNotEmpty) {
        final info = H264SpsParser.parse(spsList.first);
        if (info != null) {
          width = info.width;
          height = info.height;
          frameRate ??= info.frameRate;
        }
      }

      videoFormat = VideoFormat(
        isHevc: isHevc,
        sps: spsList,
        pps: ppsList,
        vps: vpsList,
        width: width,
        height: height,
        frameRate: frameRate,
      );

      onProgress?.call(55);
      debugPrint(
        '[TsDemuxer] Demuxed: ${videoSamples.length} video samples, '
        '${audioSamples.length} audio samples'
        '${audioFormat != null ? " (AAC ${audioFormat!.sampleRate}Hz/${audioFormat!.channels}ch)" : ""}',
      );

      // ---- 第二遍：封装 MP4 ----
      if (videoSamples.isEmpty && audioSamples.isEmpty) {
        throw FormatException('TS 流中没有提取到任何可用的音视频样本');
      }
      await spool.flush();
      await Mp4Muxer.muxMp4(
        spoolPath: spoolPath,
        videoSamples: videoSamples,
        audioSamples: audioSamples,
        video: videoFormat,
        audio: audioFormat,
        outputPath: outputPath,
        isCancelled: isCancelled,
        videoTimelineReal: videoTimelineReal,
        audioTimelineReal: audioTimelineReal,
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

    debugPrint('[TsDemuxer] MP4 written to $outputPath');
    return outputPath;
  }

  /// 校验 PID/编码支持情况。
  static void _validatePids(ProgramPids pids) {
    final vType = pids.videoStreamType;
    if (vType != 0x1B && vType != 0x24) {
      throw FormatException(
          '不支持的 TS 视频编码（stream_type=0x${vType.toRadixString(16)}），'
          '仅支持 H.264/H.265');
    }
  }

  /// 4 字节大端写入（样本数据长度前缀）。
  static void _writeU32(BytesBuilder builder, int value) {
    builder.add(Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]));
  }
}

// ============================================================================
// PSI（PAT/PMT）section 重组器
// ============================================================================

class _PsiAssembler {
  final BytesBuilder _buf = BytesBuilder();
  final List<int> _prefix = [];
  bool _inSection = false;
  int _sectionLen = 0;

  void feed(Uint8List payload, bool pusi, void Function(Uint8List) onSection) {
    if (pusi) {
      _reset();
      if (payload.length < 2) return;
      final pointer = payload[0];
      final start = 1 + pointer;
      if (start >= payload.length) return;
      _append(payload, start);
    } else {
      if (!_inSection && _buf.length == 0) return;
      _append(payload, 0);
    }
    if (_sectionLen > 0 && _buf.length >= _sectionLen) {
      final section = _buf.toBytes();
      _reset();
      onSection(section);
    }
  }

  void _append(Uint8List bytes, int start) {
    for (int i = start; i < bytes.length; i++) {
      if (_prefix.length < 3) _prefix.add(bytes[i]);
      _buf.addByte(bytes[i]);
    }
    if (_prefix.length >= 3) {
      // section_length 字段 = 其后字节数（不含 table_id 和 section_length 自身）
      _sectionLen = ((_prefix[1] & 0x0F) << 8) | _prefix[2] + 3;
      _inSection = true;
    }
  }

  void _reset() {
    _buf.clear();
    _prefix.clear();
    _inSection = false;
    _sectionLen = 0;
  }

  void flush(void Function(Uint8List) onSection) {
    if (_sectionLen > 0 && _buf.length >= _sectionLen) {
      final section = _buf.toBytes();
      _reset();
      onSection(section);
    }
  }
}

// ============================================================================
// PES 重组器（按帧累积，PES_packet_length 决定帧边界）
// ============================================================================

class _PesAssembler {
  BytesBuilder? _frame;
  final List<int> _first6 = [];
  int _frameBytes = 0;
  int? _expectedTotal; // 帧总字节数（6 + pes_packet_length），null = 直到下一个 PUSI
  bool _drop = false;

  void feed(Uint8List payload, bool pusi, void Function(PesPacket) onPes) {
    if (pusi) {
      // 新 PES 开始：冲刷上一个（PES_packet_length == 0 的帧在此结束）
      if (_frame != null && !_drop) _flush(onPes);
      _frame = BytesBuilder();
      _first6.clear();
      _frameBytes = 0;
      _expectedTotal = null;
      _drop = false;
      _append(payload, 0, onPes);
    } else {
      if (_frame == null) {
        // 流中段的孤儿数据，忽略
        _drop = true;
        return;
      }
      if (_drop) return;
      _append(payload, 0, onPes);
    }
  }

  void _append(Uint8List payload, int start, void Function(PesPacket) onPes) {
    for (int i = start; i < payload.length && _first6.length < 6; i++) {
      _first6.add(payload[i]);
    }
    if (_drop) return;

    if (_expectedTotal == null && _first6.length >= 6) {
      if (_first6[0] == 0x00 && _first6[1] == 0x00 && _first6[2] == 0x01) {
        final pesLen = (_first6[4] << 8) | _first6[5];
        _expectedTotal = pesLen == 0 ? null : 6 + pesLen;
      } else {
        // 不是 PES 起始码，丢弃到下一个 PUSI
        _drop = true;
        return;
      }
    }

    if (_expectedTotal != null) {
      final remaining = _expectedTotal! - _frameBytes;
      if (remaining <= payload.length - start) {
        _frame!.add(payload.sublist(start, start + remaining));
        _frameBytes += remaining;
        _flush(onPes);
        // 超出帧长度的字节为填充数据，忽略
        return;
      }
    }

    _frame!.add(payload.sublist(start));
    _frameBytes += payload.length - start;
  }

  void _flush(void Function(PesPacket) onPes) {
    final bytes = _frame!.toBytes();
    _reset();
    if (bytes.length < 9) return;
    if (!(bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01)) return;

    final flags2 = bytes[7];
    final headerDataLen = bytes[8];
    final headerTotal = 9 + headerDataLen;
    if (bytes.length < headerTotal) return;

    int? pts;
    int? dts;
    if ((flags2 & 0x80) != 0 && headerTotal >= 14) {
      pts = _parsePts(bytes, 9);
      if ((flags2 & 0x40) != 0 && headerTotal >= 19) {
        dts = _parsePts(bytes, 14);
      }
    }

    final data = bytes.sublist(headerTotal);
    if (data.isEmpty) return;
    onPes(PesPacket(pts: pts, dts: dts, data: data));
  }

  static int _parsePts(Uint8List b, int o) {
    return ((b[o] >> 1) & 0x07) << 30 |
        b[o + 1] << 22 |
        ((b[o + 2] >> 1) & 0x7F) << 15 |
        b[o + 3] << 7 |
        ((b[o + 4] >> 1) & 0x7F);
  }

  void _reset() {
    _frame = null;
    _first6.clear();
    _frameBytes = 0;
    _expectedTotal = null;
    _drop = false;
  }

  void flush(void Function(PesPacket) onPes) {
    if (_frame != null && !_drop) _flush(onPes);
    _reset();
  }
}

// ============================================================================
// MP4 封装器（ISO BMFF 最小实现）
// ============================================================================

class Mp4Muxer {
  Mp4Muxer._();

  /// 时间戳时基（90kHz，与 PES PTS 一致）
  static const int kTimescale = 90000;

  // ---------------------------------------------------------------------------
  // 主入口
  // ---------------------------------------------------------------------------

  /// 将 spool 文件中的样本封装为 MP4。
  ///
  /// [videoSamples] / [audioSamples] 的 [Mp4Sample.spoolOffset] 指向
  /// [spoolPath] 中样本数据的位置（视频样本为 4 字节长度前缀的 NAL 串联，
  /// 音频样本为原始 AAC 帧）。
  ///
  /// 写入期间检查 [isCancelled]，取消时抛出 [FormatException]；
  /// 失败或取消时不会留下半成品输出文件（先写临时文件，成功后改名）。
  ///
  /// 返回输出路径。
  static Future<String> muxMp4({
    required String spoolPath,
    required List<Mp4Sample> videoSamples,
    required List<Mp4Sample> audioSamples,
    required VideoFormat? video,
    AudioFormat? audio,
    required String outputPath,
    void Function(int progress)? onProgress,
    bool Function()? isCancelled,
    bool videoTimelineReal = true,
    bool audioTimelineReal = true,
  }) async {
    if (videoSamples.isEmpty && audioSamples.isEmpty) {
      throw FormatException('没有可写入的样本');
    }

    final v = List<Mp4Sample>.from(videoSamples)
      ..sort((a, b) {
        final c = a.dts.compareTo(b.dts);
        return c != 0 ? c : a.pts.compareTo(b.pts);
      });
    final a = List<Mp4Sample>.from(audioSamples);

    // ---- 视频时间轴（90kHz）----
    final videoStts = <int>[]; // 每样本时长
    final videoCtts = <int>[]; // 每样本合成偏移
    final syncSamples = <int>[]; // 关键帧序号（1 起）
    var videoDuration90k = 0;
    int? videoMinPts90k;

    if (v.isNotEmpty) {
      final minDts = v.map((s) => s.dts).reduce((x, y) => x < y ? x : y);
      videoMinPts90k =
          v.map((s) => s.pts).reduce((x, y) => x < y ? x : y);
      final shift = -minDts; // 任意平移，不影响 stts 增量
      // ctts = pts - dts 允许为负（B 帧重排）：ctts 盒子使用 version 1（有符号）
      var prevDts = 0;
      for (int i = 0; i < v.length; i++) {
        final s = v[i];
        final dts = s.dts + shift;
        final pts = s.pts + shift;
        if (i == 0) {
          prevDts = dts;
        } else {
          var dur = dts - prevDts;
          if (dur < 0) dur = 0;
          videoStts.add(dur);
          prevDts = dts;
        }
        videoCtts.add(pts - dts);
        if (s.sync) syncSamples.add(i + 1);
      }
      // 最后一帧时长：用中位数估算
      final sortedDurs = List<int>.from(videoStts)..sort();
      var lastDur = 3000; // 默认 ~33ms@90k
      if (video?.frameRate != null && video!.frameRate! > 0) {
        lastDur = (kTimescale / video.frameRate!).round();
      } else if (sortedDurs.isNotEmpty) {
        lastDur = sortedDurs[sortedDurs.length ~/ 2];
        if (lastDur <= 0) lastDur = 3000;
      }
      videoStts.add(lastDur);

      // 时长 = 最后一个展示时间 + 其时长（B 帧时 PTS 可能晚于 DTS）
      var videoEnd = 0;
      for (int i = 0; i < v.length; i++) {
        final pts = v[i].pts + shift;
        final end = pts + videoStts[i];
        if (end > videoEnd) videoEnd = end;
      }
      videoDuration90k = videoEnd;
    }

    // ---- 音频时间轴（采样率时基）----
    // AAC 每帧固定 samplesPerFrame 个采样，帧间时序恒定；
    // 音频 PTS 仅用于计算音视频起始偏移（通过 edit list 表达）
    var audioDuration = 0;
    int? audioMinPts90k;
    List<(int, int)> audioSttsRuns = const [(1, 1024)];
    final audioTimescale = audio?.sampleRate ?? 44100;
    if (a.isNotEmpty && audio != null) {
      audioMinPts90k = a.map((s) => s.pts).reduce((x, y) => x < y ? x : y);
      audioDuration = a.length * audio.samplesPerFrame;
      audioSttsRuns = [(a.length, audio.samplesPerFrame)];
    }

    // ---- 音视频起始偏移（通过 edit list 表达）----
    // 任一轨道的时间轴为合成（源 PES 无时间戳）时无法比较，跳过 edit list
    final avOffset90k =
        (audioMinPts90k != null && videoMinPts90k != null &&
                videoTimelineReal && audioTimelineReal)
            ? audioMinPts90k - videoMinPts90k
            : 0;

    // ---- 计算 mdat 布局 ----
    final ftyp = buildFtypBox();
    final videoDataSize = v.fold(0, (sum, s) => sum + s.size);
    final audioDataSize = a.fold(0, (sum, s) => sum + s.size);
    final mdatPayloadSize = videoDataSize + audioDataSize;
    // 超过 4GB 时 mdat 使用 16 字节头（size=1 + largesize）
    final useLargeMdat = mdatPayloadSize + 8 > 0xFFFFFFFF;
    final mdatHeaderSize = useLargeMdat ? 16 : 8;
    final videoChunkOffset = ftyp.length + mdatHeaderSize;
    final audioChunkOffset = videoChunkOffset + videoDataSize;

    final audioEnd90k = audioDuration * kTimescale ~/ audioTimescale;
    // 空编辑（音视频起始偏移）也计入电影时长与轨道时长
    final videoEdit90k = avOffset90k < 0 ? -avOffset90k : 0;
    final audioEdit90k = avOffset90k > 0 ? avOffset90k : 0;
    final videoMovieDuration = videoDuration90k + videoEdit90k;
    final audioMovieDuration = audioEnd90k + audioEdit90k;
    final mvhdDuration90k =
        videoMovieDuration > audioMovieDuration ? videoMovieDuration : audioMovieDuration;

    // ---- moov ----
    final moov = buildMoovBox(
      videoSamples: v,
      audioSamples: a,
      video: video,
      audio: audio,
      videoTimescale: kTimescale,
      audioTimescale: audioTimescale,
      videoDuration: videoDuration90k,
      videoMovieDuration: videoMovieDuration,
      audioDuration: audioDuration,
      audioMovieDuration: audioMovieDuration,
      mvhdDuration: mvhdDuration90k,
      videoChunkOffset: videoChunkOffset,
      audioChunkOffset: audioChunkOffset,
      videoStts: videoStts,
      videoCtts: videoCtts,
      syncSamples: syncSamples,
      audioSttsRuns: audioSttsRuns,
      avOffset90k: avOffset90k,
    );

    // ---- 写文件：ftyp + mdat + moov（先写临时文件，成功后再改名）----
    final tmpPath = '$outputPath.tmp';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }
    var success = false;
    final out = await tmpFile.open(mode: FileMode.write);
    final spool = await File(spoolPath).open();
    try {
      await out.writeFrom(ftyp);

      // mdat 头（支持 >4GB 的 64 位大尺寸）
      final mdatHeader =
          buildMdatHeader(mdatPayloadSize + mdatHeaderSize);
      await out.writeFrom(mdatHeader);

      var expectedSpool = 0;
      for (final s in v) {
        _checkCancelled(isCancelled);
        expectedSpool = await _copySample(spool, out, s, expectedSpool);
      }
      for (final s in a) {
        _checkCancelled(isCancelled);
        expectedSpool = await _copySample(spool, out, s, expectedSpool);
      }

      await out.writeFrom(moov);
      await out.flush();
      success = true;
    } finally {
      await spool.close();
      await out.close();
      if (!success) {
        // 失败/取消：不留下半成品输出文件
        try {
          if (await tmpFile.exists()) {
            await tmpFile.delete();
          }
        } catch (_) {}
      }
    }

    // 成功：临时文件改名为最终输出
    final finalFile = File(outputPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tmpFile.rename(outputPath);

    onProgress?.call(100);
    return outputPath;
  }

  static void _checkCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw FormatException('转换已取消');
    }
  }

  /// 从 spool 拷贝一个样本到输出，返回 spool 中下一个期望偏移。
  static Future<int> _copySample(RandomAccessFile spool,
      RandomAccessFile out, Mp4Sample s, int expected) async {
    if (s.spoolOffset != expected) {
      await spool.setPosition(s.spoolOffset);
    }
    final buf = Uint8List(s.size);
    var read = 0;
    while (read < s.size) {
      final n = await spool.readInto(buf, read, s.size);
      if (n <= 0) {
        throw FormatException('spool 文件读取异常（样本数据不完整）');
      }
      read += n;
    }
    await out.writeFrom(buf, 0, s.size);
    return s.spoolOffset + s.size;
  }

  // ---------------------------------------------------------------------------
  // 顶层盒子
  // ---------------------------------------------------------------------------

  /// ftyp（文件类型）盒子。
  static Uint8List buildFtypBox() {
    final content = BytesBuilder();
    content.add(iso639Code('isom'));
    content.add([0x02, 0x00, 0x00, 0x00]);
    content.add(iso639Code('isom'));
    content.add(iso639Code('mp42'));
    content.add(iso639Code('avc1'));
    return buildBox('ftyp', content.toBytes());
  }

  /// mdat 头（payloadSize 含 8 字节头自身）。
  static Uint8List buildMdatHeader(int payloadSize) {
    if (payloadSize <= 0xFFFFFFFF) {
      return buildBox('mdat', Uint8List(0))
        ..buffer.asByteData().setUint32(0, payloadSize);
    }
    // 64 位大尺寸：size=1 + largesize
    final data = Uint8List(16);
    data[3] = 1;
    data[4] = 0x6D; // 'm'
    data[5] = 0x64; // 'd'
    data[6] = 0x61; // 'a'
    data[7] = 0x74; // 't'
    final bd = data.buffer.asByteData(8);
    bd.setUint64(0, payloadSize);
    return data;
  }

  /// moov（电影）盒子。
  static Uint8List buildMoovBox({
    required List<Mp4Sample> videoSamples,
    required List<Mp4Sample> audioSamples,
    required VideoFormat? video,
    required AudioFormat? audio,
    required int videoTimescale,
    required int audioTimescale,
    required int videoDuration,
    required int videoMovieDuration,
    required int audioDuration,
    required int audioMovieDuration,
    required int mvhdDuration,
    required int videoChunkOffset,
    required int audioChunkOffset,
    required List<int> videoStts,
    required List<int> videoCtts,
    required List<int> syncSamples,
    List<(int, int)> audioSttsRuns = const [(1, 1024)],
    int avOffset90k = 0,
  }) {
    final moovContent = BytesBuilder();
    moovContent.add(buildMvhdBox(duration: mvhdDuration));

    if (videoSamples.isNotEmpty && video != null) {
      moovContent.add(buildVideoTrackBox(
        video: video,
        samples: videoSamples,
        timescale: videoTimescale,
        mediaDuration: videoDuration,
        movieDuration: videoMovieDuration,
        chunkOffset: videoChunkOffset,
        stts: videoStts,
        ctts: videoCtts,
        syncSamples: syncSamples,
        // 音频早于视频开始时，视频轨加空编辑
        emptyEdit90k: avOffset90k < 0 ? -avOffset90k : 0,
      ));
    }

    if (audioSamples.isNotEmpty && audio != null) {
      moovContent.add(buildAudioTrackBox(
        audio: audio,
        samples: audioSamples,
        timescale: audioTimescale,
        mediaDuration: audioDuration,
        movieDuration: audioMovieDuration,
        chunkOffset: audioChunkOffset,
        sttsRuns: audioSttsRuns,
        // 视频早于音频开始时，音频轨加空编辑
        emptyEdit90k: avOffset90k > 0 ? avOffset90k : 0,
      ));
    }

    return buildBox('moov', moovContent.toBytes());
  }

  /// mvhd（电影头）盒子（version 1，64 位时间戳）。
  static Uint8List buildMvhdBox({required int duration}) {
    final content = BytesBuilder();
    content.add(_u64(0)); // creation_time
    content.add(_u64(0)); // modification_time
    content.add(_u32(kTimescale));
    content.add(_u64(duration));
    content.add([0x00, 0x01, 0x00, 0x00]); // rate 1.0
    content.add([0x01, 0x00]); // volume 1.0
    content.add(Uint8List(10)); // reserved
    content.add(_matrix());
    content.add(Uint8List(24)); // pre_defined
    content.add(_u32(3)); // next_track_id
    return buildFullBox('mvhd', content.toBytes(), version: 1);
  }

  /// 视频轨道（trak）。
  static Uint8List buildVideoTrackBox({
    required VideoFormat video,
    required List<Mp4Sample> samples,
    required int timescale,
    required int mediaDuration,
    required int movieDuration,
    required int chunkOffset,
    required List<int> stts,
    required List<int> ctts,
    required List<int> syncSamples,
    int emptyEdit90k = 0,
  }) {
    final trakContent = BytesBuilder();
    trakContent.add(buildTkhdBox(
        trackId: 1,
        duration: movieDuration,
        width: video.width,
        height: video.height));
    if (emptyEdit90k > 0) {
      trakContent.add(buildEdtsBox(emptyEdit90k));
    }

    final mdiaContent = BytesBuilder();
    mdiaContent.add(
        buildMdhdBox(timescale: timescale, duration: mediaDuration));
    mdiaContent.add(buildHdlrBox('vide', 'VideoHandler'));

    final minfContent = BytesBuilder();
    minfContent.add(buildFullBox('vmhd', Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0]),
        flags: 0x01));
    minfContent.add(buildDinfBox());
    minfContent.add(buildVideoStblBox(
      video: video,
      samples: samples,
      chunkOffset: chunkOffset,
      stts: stts,
      ctts: ctts,
      syncSamples: syncSamples,
    ));
    mdiaContent.add(buildBox('minf', minfContent.toBytes()));

    trakContent.add(buildBox('mdia', mdiaContent.toBytes()));
    return buildBox('trak', trakContent.toBytes());
  }

  /// 音频轨道（trak）。
  static Uint8List buildAudioTrackBox({
    required AudioFormat audio,
    required List<Mp4Sample> samples,
    required int timescale,
    required int mediaDuration,
    required int movieDuration,
    required int chunkOffset,
    List<(int, int)> sttsRuns = const [(1, 1024)],
    int emptyEdit90k = 0,
  }) {
    final trakContent = BytesBuilder();
    // tkhd 时长为电影时基（90kHz），需将媒体时长换算
    trakContent.add(buildTkhdBox(trackId: 2, duration: movieDuration));
    if (emptyEdit90k > 0) {
      trakContent.add(buildEdtsBox(emptyEdit90k));
    }

    final mdiaContent = BytesBuilder();
    mdiaContent.add(
        buildMdhdBox(timescale: timescale, duration: mediaDuration));
    mdiaContent.add(buildHdlrBox('soun', 'SoundHandler'));

    final minfContent = BytesBuilder();
    minfContent.add(buildFullBox('smhd', Uint8List.fromList([0, 0, 0, 0])));
    minfContent.add(buildDinfBox());
    minfContent.add(buildAudioStblBox(
      audio: audio,
      samples: samples,
      chunkOffset: chunkOffset,
      sttsRuns: sttsRuns,
    ));
    mdiaContent.add(buildBox('minf', minfContent.toBytes()));

    trakContent.add(buildBox('mdia', mdiaContent.toBytes()));
    return buildBox('trak', trakContent.toBytes());
  }

  /// edts + elst（编辑列表）盒子：用空编辑表达轨道起始延迟（电影时基）。
  static Uint8List buildEdtsBox(int emptyEdit90k) {
    final elstContent = BytesBuilder();
    elstContent.add(_u32(1)); // entry_count
    elstContent.add(_u64(emptyEdit90k)); // segment_duration（电影时基）
    elstContent.add(Uint8List.fromList(
        List.filled(8, 0xFF))); // media_time = -1（空编辑）
    elstContent.add([0x00, 0x01, 0x00, 0x00]); // media_rate = 1.0
    return buildBox('edts', buildFullBox('elst', elstContent.toBytes(), version: 1));
  }

  /// tkhd（轨道头）盒子（version 1）。
  static Uint8List buildTkhdBox({
    required int trackId,
    required int duration,
    int width = 0,
    int height = 0,
  }) {
    final content = BytesBuilder();
    content.add(_u64(0)); // creation_time
    content.add(_u64(0)); // modification_time
    content.add(_u32(trackId));
    content.add(_u32(0)); // reserved
    content.add(_u64(duration));
    content.add(Uint8List(8)); // reserved
    content.add([0x00, 0x00]); // layer
    content.add([0x00, 0x00]); // alternate_group
    content.add([0x00, 0x00]); // volume
    content.add([0x00, 0x00]); // reserved
    content.add(_matrix());
    content.add(_u32(width << 16)); // width (16.16)
    content.add(_u32(height << 16)); // height (16.16)
    return buildFullBox('tkhd', content.toBytes(),
        version: 1, flags: 0x07);
  }

  /// mdhd（媒体头）盒子（version 1）。
  static Uint8List buildMdhdBox({
    required int timescale,
    required int duration,
  }) {
    final content = BytesBuilder();
    content.add(_u64(0)); // creation_time
    content.add(_u64(0)); // modification_time
    content.add(_u32(timescale));
    content.add(_u64(duration));
    content.add([0x55, 0xC4]); // language: und
    content.add([0x00, 0x00]); // pre_defined
    return buildFullBox('mdhd', content.toBytes(), version: 1);
  }

  /// hdlr（处理器）盒子。
  static Uint8List buildHdlrBox(String handlerType, String name) {
    final content = BytesBuilder();
    content.add(_u32(0)); // pre_defined
    content.add(iso639Code(handlerType));
    content.add(_u32(0)); // reserved
    content.add(_u32(0));
    content.add(_u32(0));
    content.add(_codeUnits(name));
    content.add([0x00]); // null terminator
    return buildFullBox('hdlr', content.toBytes());
  }

  /// dinf（数据信息）盒子。
  static Uint8List buildDinfBox() {
    final drefContent = BytesBuilder();
    drefContent.add(_u32(0)); // version + flags
    drefContent.add(_u32(1)); // entry_count
    drefContent.add(buildFullBox('url ', Uint8List(0), flags: 0x01));
    return buildBox('dinf', buildBox('dref', drefContent.toBytes()));
  }

  /// 视频 stbl（样本表）盒子。
  static Uint8List buildVideoStblBox({
    required VideoFormat video,
    required List<Mp4Sample> samples,
    required int chunkOffset,
    required List<int> stts,
    required List<int> ctts,
    required List<int> syncSamples,
  }) {
    final stblContent = BytesBuilder();
    stblContent.add(buildVideoStsdBox(video));
    stblContent.add(buildSttsBox(stts));
    if (ctts.any((c) => c != 0)) {
      stblContent.add(buildCttsBox(ctts));
    }
    if (syncSamples.isNotEmpty) {
      stblContent.add(buildStssBox(syncSamples));
    }
    stblContent.add(buildStscBox(samples.length));
    stblContent.add(buildStszBox(samples));
    stblContent.add(buildCo64Box(chunkOffset));
    return buildBox('stbl', stblContent.toBytes());
  }

  /// 音频 stbl（样本表）盒子。
  static Uint8List buildAudioStblBox({
    required AudioFormat audio,
    required List<Mp4Sample> samples,
    required int chunkOffset,
    List<(int, int)> sttsRuns = const [(1, 1024)],
  }) {
    final stblContent = BytesBuilder();
    stblContent.add(buildAudioStsdBox(audio));
    stblContent.add(buildSttsBoxFromRuns(sttsRuns));
    stblContent.add(buildStscBox(samples.length));
    stblContent.add(buildStszBox(samples));
    stblContent.add(buildCo64Box(chunkOffset));
    return buildBox('stbl', stblContent.toBytes());
  }

  /// 视频 stsd（样本描述）盒子（avc1 / hvc1）。
  static Uint8List buildVideoStsdBox(VideoFormat video) {
    final isHevc = video.isHevc;
    final entryContent = BytesBuilder();
    entryContent.add(Uint8List(6)); // reserved
    entryContent.add([0x00, 0x01]); // data_reference_index

    // VisualSampleEntry 固定字段
    entryContent.add([0x00, 0x00]); // pre_defined
    entryContent.add([0x00, 0x00]); // reserved
    entryContent.add(_u32(0)); // pre_defined[0]
    entryContent.add(_u32(0)); // pre_defined[1]
    entryContent.add(_u32(0)); // pre_defined[2]
    entryContent.add(_u16(video.width));
    entryContent.add(_u16(video.height));
    entryContent.add(_u32(0x00480000)); // horizresolution (72dpi)
    entryContent.add(_u32(0x00480000)); // vertresolution
    entryContent.add(_u32(0)); // reserved
    entryContent.add(_u16(1)); // frame_count
    entryContent.add(_fixedStringBytes(isHevc ? 'HEVC Coding' : 'AVC Coding', 32));
    entryContent.add([0x00, 0x18]); // depth
    entryContent.add([0xFF, 0xFF]); // pre_defined

    // 配置记录：优先使用流中现成的 avcC/hvcC，否则由参数集构建
    if (video.rawConfig != null) {
      entryContent.add(buildBox(isHevc ? 'hvcC' : 'avcC', video.rawConfig!));
    } else if (isHevc) {
      entryContent.add(buildHvcCBox(video));
    } else {
      entryContent.add(buildAvccBox(
        video.sps.map((d) => H264NalUnit(type: 7, data: d)).toList(),
        video.pps.map((d) => H264NalUnit(type: 8, data: d)).toList(),
      ));
    }

    final stsdContent = BytesBuilder();
    stsdContent.add(_u32(1)); // entry_count
    stsdContent.add(buildBox(isHevc ? 'hvc1' : 'avc1', entryContent.toBytes()));
    return buildFullBox('stsd', stsdContent.toBytes());
  }

  /// 音频 stsd（样本描述）盒子（mp4a）。
  static Uint8List buildAudioStsdBox(AudioFormat audio) {
    final entryContent = BytesBuilder();
    entryContent.add(Uint8List(6)); // reserved
    entryContent.add([0x00, 0x01]); // data_reference_index

    // AudioSampleEntry 固定字段
    entryContent.add([0x00, 0x00]); // version
    entryContent.add([0x00, 0x00]); // revision
    entryContent.add(_u32(0)); // vendor
    entryContent.add(_u16(audio.channels));
    entryContent.add(_u16(16)); // sample_size
    entryContent.add(_u16(0)); // compression_id
    entryContent.add(_u16(0)); // packet_size
    entryContent.add(_u32(audio.sampleRate << 16)); // sample_rate (16.16)

    entryContent.add(buildEsdsBox(audio));

    final stsdContent = BytesBuilder();
    stsdContent.add(_u32(1)); // entry_count
    stsdContent.add(buildBox('mp4a', entryContent.toBytes()));
    return buildFullBox('stsd', stsdContent.toBytes());
  }

  // ---------------------------------------------------------------------------
  // 配置记录
  // ---------------------------------------------------------------------------

  /// avcC（AVC 配置）盒子。
  static Uint8List buildAvccBox(
      List<H264NalUnit> spsNalus, List<H264NalUnit> ppsNalus) {
    final content = BytesBuilder();
    content.add([0x01]); // configurationVersion

    if (spsNalus.isNotEmpty) {
      final sps = spsNalus.first.data;
      content.add(sps.length > 1 ? [sps[1]] : [0x42]); // profile
      content.add(sps.length > 2 ? [sps[2]] : [0x00]); // compatibility
      content.add(sps.length > 3 ? [sps[3]] : [0x1E]); // level
    } else {
      content.add([0x42, 0x00, 0x1E]);
    }

    content.add([0xFF]); // 6 位保留 + lengthSizeMinusOne=3
    content.add([0xE0 | (spsNalus.length.clamp(0, 31))]); // 保留位 + SPS 数量

    for (final sps in spsNalus) {
      _writeU16(content, sps.data.length);
      content.add(sps.data);
    }

    content.add([ppsNalus.length]);
    for (final pps in ppsNalus) {
      _writeU16(content, pps.data.length);
      content.add(pps.data);
    }

    return buildBox('avcC', content.toBytes());
  }

  /// hvcC（HEVC 配置）盒子：由 VPS/SPS/PPS 参数集构建。
  static Uint8List buildHvcCBox(VideoFormat video) {
    final content = BytesBuilder();

    // profile_tier_level（12 字节）从 SPS 提取：
    // SPS NAL 头(2) + vps_id/sub_layers/nesting(1) 之后即为 PTL
    var profileSpace = 0, tier = 0, profileIdc = 1, levelIdc = 0;
    var compatFlags = Uint8List(4);
    var constraintFlags = Uint8List(6);
    if (video.sps.isNotEmpty && video.sps.first.length >= 15) {
      final sps = video.sps.first;
      const p = 3;
      profileSpace = (sps[p] >> 6) & 0x03;
      tier = (sps[p] >> 5) & 0x01;
      profileIdc = sps[p] & 0x1F;
      compatFlags = Uint8List.fromList(sps.sublist(p + 1, p + 5));
      constraintFlags = Uint8List.fromList(sps.sublist(p + 5, p + 11));
      levelIdc = sps[p + 11];
    }

    content.add([0x01]); // configurationVersion
    content.add([(profileSpace << 6) | (tier << 5) | profileIdc]);
    content.add(compatFlags);
    content.add(constraintFlags);
    content.add([levelIdc]);
    content.add([0xF0, 0x00]); // min_spatial_segmentation_idc=0
    content.add([0xFC]); // parallelismType=0
    content.add([0xFC | 0x01]); // chroma_format_idc=1 (4:2:0)
    content.add([0xF8]); // bit_depth_luma_minus8=0
    content.add([0xF8]); // bit_depth_chroma_minus8=0
    content.add([0x00, 0x00]); // avgFrameRate=0
    content.add([0x0F]); // constantFrameRate=0, temporalLayers=1, nested=1, lengthSizeMinusOne=3

    // 参数集数组：VPS(32)、SPS(33)、PPS(34)
    final arrays = <(int, List<Uint8List>)>[
      if (video.vps.isNotEmpty) (32, video.vps),
      if (video.sps.isNotEmpty) (33, video.sps),
      if (video.pps.isNotEmpty) (34, video.pps),
    ];
    content.add([arrays.length]);
    for (final (nalType, nalus) in arrays) {
      content.add([0x80 | nalType]); // array_completeness=1
      content.add(_u16(nalus.length));
      for (final nalu in nalus) {
        _writeU16(content, nalu.length);
        content.add(nalu);
      }
    }

    return buildBox('hvcC', content.toBytes());
  }

  /// esds（元素流描述）盒子。
  static Uint8List buildEsdsBox(AudioFormat audio) {
    final content = BytesBuilder();
    content.add(_u32(0)); // version + flags

    // DecoderConfigDescriptor 内部（含 DecoderSpecificInfo）
    final decInner = BytesBuilder();
    decInner.add([0x40]); // objectTypeIndication: MPEG-4 Audio
    decInner.add([0x15]); // streamType: audio (0x05 << 2 | 1)
    decInner.add([0x00, 0x00, 0x00]); // bufferSizeDB
    decInner.add([0x00, 0x00, 0xBB, 0x80]); // maxBitrate
    decInner.add([0x00, 0x00, 0xBB, 0x80]); // avgBitrate
    decInner.add([0x05, audio.asc.length]); // DecoderSpecificInfo tag
    decInner.add(audio.asc);

    final esInner = BytesBuilder();
    esInner.add([0x00, 0x01]); // ES_ID
    esInner.add([0x00]); // streamPriority
    esInner.add([0x04, decInner.length]);
    esInner.add(decInner.toBytes());
    esInner.add([0x06, 0x01, 0x02]); // SLConfigDescriptor

    content.add([0x03, esInner.length]); // ES_Descriptor tag
    content.add(esInner.toBytes());

    return buildBox('esds', content.toBytes());
  }

  // ---------------------------------------------------------------------------
  // 样本表盒子
  // ---------------------------------------------------------------------------

  /// stts（时间到样本）盒子：输入每样本时长，按连续相同值压缩。
  static Uint8List buildSttsBox(List<int> durations) {
    return buildSttsBoxFromRuns(buildSttsRuns(durations));
  }

  /// 将每样本时长列表压缩为 (count, duration) 游程。
  static List<(int, int)> buildSttsRuns(List<int> durations) {
    final runs = <(int, int)>[];
    for (final d in durations) {
      if (runs.isNotEmpty && runs.last.$2 == d) {
        runs[runs.length - 1] = (runs.last.$1 + 1, d);
      } else {
        runs.add((1, d));
      }
    }
    return runs;
  }

  /// stts 盒子：直接输入游程。
  static Uint8List buildSttsBoxFromRuns(List<(int, int)> runs) {
    final content = BytesBuilder();
    content.add(_u32(runs.length));
    for (final (count, dur) in runs) {
      content.add(_u32(count));
      content.add(_u32(dur));
    }
    return buildFullBox('stts', content.toBytes());
  }

  /// ctts（合成时间偏移）盒子：输入每样本偏移，按连续相同值压缩。
  ///
  /// version 1：偏移为有符号 32 位（B 帧重排会产生负偏移）。
  static Uint8List buildCttsBox(List<int> offsets) {
    final runs = <(int, int)>[];
    for (final o in offsets) {
      if (runs.isNotEmpty && runs.last.$2 == o) {
        runs[runs.length - 1] = (runs.last.$1 + 1, o);
      } else {
        runs.add((1, o));
      }
    }
    final content = BytesBuilder();
    content.add(_u32(runs.length));
    for (final (count, offset) in runs) {
      content.add(_u32(count));
      content.add(_u32(offset));
    }
    return buildFullBox('ctts', content.toBytes(), version: 1);
  }

  /// stss（同步样本）盒子：关键帧序号（1 起）。
  static Uint8List buildStssBox(List<int> syncSamples) {
    final content = BytesBuilder();
    content.add(_u32(syncSamples.length));
    for (final n in syncSamples) {
      content.add(_u32(n));
    }
    return buildFullBox('stss', content.toBytes());
  }

  /// stsc（样本到块）盒子：所有样本在同一个块中。
  static Uint8List buildStscBox(int sampleCount) {
    final content = BytesBuilder();
    content.add(_u32(1)); // entry_count
    content.add(_u32(1)); // first_chunk
    content.add(_u32(sampleCount)); // samples_per_chunk
    content.add(_u32(1)); // sample_description_index
    return buildFullBox('stsc', content.toBytes());
  }

  /// stsz（样本大小）盒子。
  static Uint8List buildStszBox(List<Mp4Sample> samples) {
    final content = BytesBuilder();
    content.add(_u32(0)); // sample_size = 0（变长）
    content.add(_u32(samples.length));
    for (final s in samples) {
      content.add(_u32(s.size));
    }
    return buildFullBox('stsz', content.toBytes());
  }

  /// co64（块偏移）盒子（64 位）。
  static Uint8List buildCo64Box(int chunkOffset) {
    final content = BytesBuilder();
    content.add(_u32(1)); // entry_count
    content.add(_u64(chunkOffset));
    return buildFullBox('co64', content.toBytes());
  }

  // ---------------------------------------------------------------------------
  // 通用盒子辅助
  // ---------------------------------------------------------------------------

  /// 构建基础 ISO BMFF 盒子。
  static Uint8List buildBox(String type, Uint8List content) {
    final totalSize = 8 + content.length;
    final data = Uint8List(totalSize);
    final bd = data.buffer.asByteData();
    bd.setUint32(0, totalSize);
    bd.setUint32(4, (type.codeUnitAt(0) << 24) |
        (type.codeUnitAt(1) << 16) |
        (type.codeUnitAt(2) << 8) |
        type.codeUnitAt(3));
    data.setRange(8, totalSize, content);
    return data;
  }

  /// 构建 full box（带 version + flags）。
  static Uint8List buildFullBox(String type, Uint8List content,
      {int version = 0, int flags = 0}) {
    final header = Uint8List.fromList([
      version,
      (flags >> 16) & 0xFF,
      (flags >> 8) & 0xFF,
      flags & 0xFF,
    ]);
    return buildBox(type, Uint8List.fromList([...header, ...content]));
  }

  /// 单位矩阵（36 字节）。
  static Uint8List _matrix() => Uint8List.fromList([
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);

  static Uint8List _u16(int value) => Uint8List.fromList([
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);

  static Uint8List _u32(int value) => Uint8List.fromList([
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);

  static Uint8List _u64(int value) {
    final data = Uint8List(8);
    data.buffer.asByteData().setUint64(0, value);
    return data;
  }

  static void _writeU16(BytesBuilder builder, int value) {
    builder.add(_u16(value));
  }

  /// 4 字节 ISO 639 码（不足补空格）。
  static Uint8List iso639Code(String code) {
    final bytes = Uint8List(4);
    for (int i = 0; i < 4 && i < code.length; i++) {
      bytes[i] = code.codeUnitAt(i);
    }
    for (int i = code.length; i < 4; i++) {
      bytes[i] = 0x20;
    }
    return bytes;
  }

  static Uint8List _codeUnits(String str) {
    final bytes = Uint8List(str.length);
    for (int i = 0; i < str.length; i++) {
      bytes[i] = str.codeUnitAt(i);
    }
    return bytes;
  }

  static Uint8List _fixedStringBytes(String str, int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = i < str.length ? str.codeUnitAt(i) : 0x00;
    }
    return bytes;
  }
}
