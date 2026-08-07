import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/dart_flv_remuxer.dart';

/// Build a realistic 640x360 H.264 SPS NAL (without start code).
Uint8List _sps640x360() {
  // SPS payload built with a bit writer in the TS test suite; here we use
  // a compact hand-crafted sequence for 640x360 baseline (crop 8px bottom).
  final w = _BitWriter();
  w.writeBits(0x42, 8); // profile_idc
  w.writeBits(0x00, 8);
  w.writeBits(0x1E, 8); // level_idc
  w.writeUe(0); // seq_parameter_set_id
  w.writeUe(0); // log2_max_frame_num_minus4
  w.writeUe(0); // pic_order_cnt_type
  w.writeUe(0); // log2_max_pic_order_cnt_lsb_minus4
  w.writeUe(1); // max_num_ref_frames
  w.writeBits(0, 1); // gaps flag
  w.writeUe(39); // pic_width_in_mbs_minus1
  w.writeUe(22); // pic_height_in_map_units_minus1
  w.writeBits(1, 1); // frame_mbs_only_flag
  w.writeBits(1, 1); // direct_8x8_inference_flag
  w.writeBits(1, 1); // frame_cropping_flag
  w.writeUe(0); // crop_left
  w.writeUe(0); // crop_right
  w.writeUe(0); // crop_top
  w.writeUe(4); // crop_bottom
  w.writeBits(0, 1); // vui_parameters_present_flag
  return Uint8List.fromList([0x67, ...w.toBytes()]);
}

class _BitWriter {
  final List<int> _bits = [];

  void writeBits(int value, int count) {
    for (int i = count - 1; i >= 0; i--) {
      _bits.add((value >> i) & 1);
    }
  }

  void writeUe(int value) {
    final binary = (value + 1).toRadixString(2);
    for (int i = 0; i < binary.length - 1; i++) {
      _bits.add(0);
    }
    for (final c in binary.split('')) {
      _bits.add(c == '1' ? 1 : 0);
    }
  }

  Uint8List toBytes() {
    while (_bits.length % 8 != 0) {
      _bits.add(0);
    }
    final bytes = Uint8List(_bits.length ~/ 8);
    for (int i = 0; i < _bits.length; i++) {
      if (_bits[i] == 1) {
        bytes[i ~/ 8] |= 1 << (7 - (i % 8));
      }
    }
    return bytes;
  }
}

Uint8List _u32(int value) => Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);

int _u32At(Uint8List data, int offset) =>
    (data[offset] << 24) |
    (data[offset + 1] << 16) |
    (data[offset + 2] << 8) |
    data[offset + 3];

Uint8List? _findBox(Uint8List data, String type) {
  var offset = 0;
  while (offset + 8 <= data.length) {
    final size = _u32At(data, offset);
    final t = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
    if (size < 8 || offset + size > data.length) break;
    if (t == type) return data.sublist(offset + 8, offset + size);
    offset += size;
  }
  return null;
}

List<(String, Uint8List)> _boxChildren(Uint8List payload) {
  final children = <(String, Uint8List)>[];
  var offset = 0;
  while (offset + 8 <= payload.length) {
    final size = _u32At(payload, offset);
    final type = String.fromCharCodes(payload.sublist(offset + 4, offset + 8));
    if (size < 8 || offset + size > payload.length) break;
    children.add((type, payload.sublist(offset + 8, offset + size)));
    offset += size;
  }
  return children;
}

(Uint8List?, List<(String, Uint8List)>) _child(
    List<(String, Uint8List)> children, String type) {
  for (final (t, payload) in children) {
    if (t == type) return (payload, children);
  }
  return (null, children);
}

Uint8List? _stblOf(Uint8List trakPayload) {
  final mdia = _child(_boxChildren(trakPayload), 'mdia').$1!;
  final minf = _child(_boxChildren(mdia), 'minf').$1!;
  return _child(_boxChildren(minf), 'stbl').$1;
}

List<int> _stszSizes(Uint8List trakPayload) {
  final stsz = _child(_boxChildren(_stblOf(trakPayload)!), 'stsz').$1!;
  // stsz 载荷：version/flags(4) + sample_size(4) + sample_count(4) + sizes
  final count = _u32At(stsz, 8);
  return [for (int i = 0; i < count; i++) _u32At(stsz, 12 + i * 4)];
}

List<(int, int)> _sttsRuns(Uint8List trakPayload) {
  final stts = _child(_boxChildren(_stblOf(trakPayload)!), 'stts').$1!;
  final count = _u32At(stts, 4);
  return [
    for (int i = 0; i < count; i++)
      (_u32At(stts, 8 + i * 8), _u32At(stts, 12 + i * 8))
  ];
}

List<(int, int)> _cttsRuns(Uint8List trakPayload) {
  final children = _boxChildren(_stblOf(trakPayload)!);
  final ctts = _child(children, 'ctts').$1;
  if (ctts == null) return const [];
  final count = _u32At(ctts, 4);
  final runs = <(int, int)>[];
  for (int i = 0; i < count; i++) {
    final raw = _u32At(ctts, 12 + i * 8);
    // ctts 可能为 version 1（有符号 32 位）
    final offset = raw >= 0x80000000 ? raw - 0x100000000 : raw;
    runs.add((_u32At(ctts, 8 + i * 8), offset));
  }
  return runs;
}

List<int> _stssSamples(Uint8List trakPayload) {
  final stss = _child(_boxChildren(_stblOf(trakPayload)!), 'stss').$1;
  if (stss == null) return const [];
  final count = _u32At(stss, 4);
  return [for (int i = 0; i < count; i++) _u32At(stss, 8 + i * 4)];
}

int _co64Offset(Uint8List trakPayload) {
  final co64 = _child(_boxChildren(_stblOf(trakPayload)!), 'co64').$1!;
  return co64.buffer.asByteData(8).getUint64(0);
}

/// Build a synthetic FLV file.
///
/// [videoCodecId] 7 = AVC，其他 = 模拟不支持的编码
/// [audioSoundFormat] 10 = AAC，2 = MP3（模拟不支持）
Uint8List _buildFlv({
  bool withVideo = true,
  bool withAudio = true,
  int videoCodecId = 7,
  int audioSoundFormat = 10,
}) {
  final buf = BytesBuilder();
  final flags = (withVideo ? 0x01 : 0x00) | (withAudio ? 0x04 : 0x00);
  buf.add([0x46, 0x4C, 0x56, 0x01, flags, 0x00, 0x00, 0x00, 0x09]);
  buf.add(_u32(0)); // previous tag size

  void addTag(int type, int timestampMs, Uint8List data) {
    buf.add([type]);
    buf.add([
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    // FLV 时间戳为 24 位大端
    buf.add([
      (timestampMs >> 16) & 0xFF,
      (timestampMs >> 8) & 0xFF,
      timestampMs & 0xFF,
      0x00, // timestamp extended
    ]);
    buf.add([0x00, 0x00, 0x00]); // stream ID
    buf.add(data);
    buf.add(_u32(11 + data.length)); // previous tag size
  }

  final sps = _sps640x360();
  final pps = Uint8List.fromList([0x68, 0xCE, 0x38, 0x80]);

  if (withVideo) {
    // AVC sequence header (avcC)
    final avcC = BytesBuilder();
    avcC.add([0x01, 0x42, 0x00, 0x1E, 0xFF, 0xE1]);
    avcC.add([(sps.length >> 8) & 0xFF, sps.length & 0xFF]);
    avcC.add(sps);
    avcC.add([0x01]);
    avcC.add([(pps.length >> 8) & 0xFF, pps.length & 0xFF]);
    avcC.add(pps);
    addTag(
        9,
        0,
        Uint8List.fromList([
          0x10 | videoCodecId,
          0x00,
          0x00,
          0x00,
          0x00,
          ...avcC.toBytes(),
        ]));

    // Video NALU tag 1: keyframe @1000ms, cts=0
    final nal1 = Uint8List.fromList([0x65, 0x88, 0x84, 0xAF]);
    addTag(
        9,
        1000,
        Uint8List.fromList([
          0x10 | videoCodecId,
          0x01,
          0x00,
          0x00,
          0x00,
          (nal1.length >> 24) & 0xFF,
          (nal1.length >> 16) & 0xFF,
          (nal1.length >> 8) & 0xFF,
          nal1.length & 0xFF,
          ...nal1,
        ]));

    // Video NALU tag 2: non-keyframe @2000ms, cts=+1ms
    final nal2 = Uint8List.fromList([0x41, 0x9A, 0x22]);
    addTag(
        9,
        2000,
        Uint8List.fromList([
          0x20 | videoCodecId,
          0x01,
          0x00,
          0x00,
          0x01,
          (nal2.length >> 24) & 0xFF,
          (nal2.length >> 16) & 0xFF,
          (nal2.length >> 8) & 0xFF,
          nal2.length & 0xFF,
          ...nal2,
        ]));

    // Video NALU tag 3: non-keyframe @3000ms, cts=-2ms（有符号 24 位：0xFFFFFE）
    // 负合成偏移用于验证 muxer 的有符号 version-1 ctts 输出
    final nal3 = Uint8List.fromList([0x41, 0x9B, 0x33]);
    addTag(
        9,
        3000,
        Uint8List.fromList([
          0x20 | videoCodecId,
          0x01,
          0xFF,
          0xFF,
          0xFE,
          (nal3.length >> 24) & 0xFF,
          (nal3.length >> 16) & 0xFF,
          (nal3.length >> 8) & 0xFF,
          nal3.length & 0xFF,
          ...nal3,
        ]));
  }

  if (withAudio) {
    if (audioSoundFormat == 10) {
      // AAC sequence header (AudioSpecificConfig: LC, 44100, 2ch)
      addTag(8, 0, Uint8List.fromList([0xAF, 0x00, 0x12, 0x10]));
      // Two AAC frames
      final frame = Uint8List(30);
      for (int i = 0; i < 30; i++) {
        frame[i] = 0x50 + i;
      }
      addTag(8, 1000, Uint8List.fromList([0xAF, 0x01, ...frame]));
      addTag(8, 2000, Uint8List.fromList([0xAF, 0x01, ...frame]));
    } else {
      // MP3-like audio (soundFormat=2), skipped by the demuxer
      addTag(8, 1000, Uint8List.fromList([0x20, 0x01, 0x02, 0x03]));
    }
  }

  return buf.toBytes();
}

void main() {
  group('FlvDemuxer - detection', () {
    test('isFlv detects FLV magic', () {
      final flv = _buildFlv();
      expect(FlvDemuxer.isFlv(flv.sublist(0, 8)), isTrue);
    });

    test('isFlv rejects non-FLV data', () {
      expect(FlvDemuxer.isFlv(Uint8List.fromList([1, 2, 3])), isFalse);
    });
  });

  group('FlvDemuxer - probe', () {
    test('parses FLV structure', () async {
      final flv = _buildFlv();
      final info = await FlvDemuxer.probe(data: flv);
      expect(info.hasVideo, isTrue);
      expect(info.hasAudio, isTrue);
      expect(info.videoSampleCount, equals(3));
      expect(info.audioSampleCount, equals(2));
      expect(info.durationMs, equals(3000));
      expect(info.width, equals(640));
      expect(info.height, equals(360));
    });

    test('probe rejects non-FLV data', () async {
      await expectLater(
        () => FlvDemuxer.probe(data: Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsFormatException,
      );
    });
  });

  group('FlvDemuxer - convertFlvToMp4 (integration)', () {
    test('converts FLV to valid MP4 with correct timing', () async {
      final tempDir = Directory.systemTemp.createTempSync('flv_test_');
      try {
        final flvPath = '${tempDir.path}\\input.flv';
        final mp4Path = '${tempDir.path}\\output.mp4';
        await File(flvPath).writeAsBytes(_buildFlv());

        final resultPath = await FlvDemuxer.convertFlvToMp4(
          inputPath: flvPath,
          outputPath: mp4Path,
        );
        expect(resultPath, equals(mp4Path));

        final mp4 = await File(mp4Path).readAsBytes();
        expect(_findBox(mp4, 'ftyp'), isNotNull);
        final moov = _findBox(mp4, 'moov');
        expect(moov, isNotNull);

        final traks = _boxChildren(moov!)
            .where((c) => c.$1 == 'trak')
            .map((c) => c.$2)
            .toList();
        expect(traks.length, equals(2));

        // 视频轨：3 个样本，间隔 1s；仅第 1 个是关键帧；
        // 合成偏移 = pts - dts = [0, +1ms, -2ms]（version 1 有符号 ctts）
        final videoSizes = _stszSizes(traks[0]);
        expect(videoSizes.length, equals(3));
        expect(_sttsRuns(traks[0]), equals([(3, 90000)]));
        expect(_stssSamples(traks[0]), equals([1]));
        expect(_cttsRuns(traks[0]), equals([(1, 0), (1, 90), (1, -180)]));
        // ctts 盒子必须为 version 1（有符号偏移）
        final stbl = _boxChildren(_stblOf(traks[0])!);
        final cttsBox = _child(stbl, 'ctts').$1!;
        expect(cttsBox[0], equals(1)); // version

        // 音频轨：2 个 30 字节 AAC 帧，每帧 1024 采样
        final audioSizes = _stszSizes(traks[1]);
        expect(audioSizes, equals([30, 30]));
        expect(_sttsRuns(traks[1]), equals([(2, 1024)]));

        // 音频块偏移紧跟视频数据之后
        final expectedAudioOffset =
            28 + 8 + videoSizes.fold(0, (a, b) => a + b);
        expect(_co64Offset(traks[1]), equals(expectedAudioOffset));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('converts video-only FLV', () async {
      final tempDir = Directory.systemTemp.createTempSync('flv_vonly_');
      try {
        final flvPath = '${tempDir.path}\\input.flv';
        final mp4Path = '${tempDir.path}\\output.mp4';
        await File(flvPath).writeAsBytes(_buildFlv(withAudio: false));

        await FlvDemuxer.convertFlvToMp4(
          inputPath: flvPath,
          outputPath: mp4Path,
        );

        final mp4 = await File(mp4Path).readAsBytes();
        final moov = _findBox(mp4, 'moov')!;
        final traks = _boxChildren(moov).where((c) => c.$1 == 'trak').toList();
        expect(traks.length, equals(1));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('skips unsupported audio codec (MP3) but keeps video', () async {
      final tempDir = Directory.systemTemp.createTempSync('flv_mp3_');
      try {
        final flvPath = '${tempDir.path}\\input.flv';
        final mp4Path = '${tempDir.path}\\output.mp4';
        await File(flvPath).writeAsBytes(_buildFlv(audioSoundFormat: 2));

        await FlvDemuxer.convertFlvToMp4(
          inputPath: flvPath,
          outputPath: mp4Path,
        );

        final mp4 = await File(mp4Path).readAsBytes();
        final moov = _findBox(mp4, 'moov')!;
        final traks = _boxChildren(moov).where((c) => c.$1 == 'trak').toList();
        expect(traks.length, equals(1));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws for unsupported video codec (VP6)', () async {
      final tempDir = Directory.systemTemp.createTempSync('flv_vp6_');
      try {
        final flvPath = '${tempDir.path}\\input.flv';
        final mp4Path = '${tempDir.path}\\output.mp4';
        await File(flvPath).writeAsBytes(_buildFlv(videoCodecId: 4));

        await expectLater(
          () => FlvDemuxer.convertFlvToMp4(
            inputPath: flvPath,
            outputPath: mp4Path,
          ),
          throwsFormatException,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws for non-FLV input', () async {
      final tempDir = Directory.systemTemp.createTempSync('flv_bad_');
      try {
        final flvPath = '${tempDir.path}\\input.flv';
        final mp4Path = '${tempDir.path}\\output.mp4';
        await File(flvPath)
            .writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6]));

        await expectLater(
          () => FlvDemuxer.convertFlvToMp4(
            inputPath: flvPath,
            outputPath: mp4Path,
          ),
          throwsFormatException,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
