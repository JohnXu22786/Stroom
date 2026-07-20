import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/dart_ts_remuxer.dart';

/// Build a minimal valid MPEG-TS packet with a given PID and payload.
///
/// Layout:
///   - Sync byte (0x47)
///   - PID (13 bits)
///   - Various flags
///   - Continuity counter
///   - Payload
Uint8List _buildTsPacket(int pid, int continuityCounter, Uint8List payload,
    {bool payloadUnitStart = false}) {
  final data = Uint8List(188);
  data[0] = 0x47; // sync byte

  // PID: bits 8-0 of pid go in byte 1 (lower 5 bits),
  // bits 12-8 go in byte 2 (upper 8 bits)
  data[1] = ((pid >> 8) & 0x1F) | (payloadUnitStart ? 0x40 : 0x00);
  data[2] = pid & 0xFF;

  // Adaptation field control = 01 (no adaptation, payload only)
  data[3] = 0x10 | (continuityCounter & 0x0F);

  // Copy payload
  for (int i = 0; i < payload.length && i < 184; i++) {
    data[4 + i] = payload[i];
  }
  // Fill rest with padding
  for (int i = 4 + payload.length; i < 188; i++) {
    data[i] = 0xFF;
  }

  return data;
}

/// Build a PAT (Program Association Table) section payload.
///
/// Includes the pointer_field (0x00) at the start, as it appears in
/// a TS packet payload with payload_unit_start set.
Uint8List _buildPat(int pmtPid) {
  // Section data (from table_id to end of CRC):
  //   table_id(1) + section_length(2) + ts_id(2) + version(1) + section(1)
  //   + last_section(1) + program(4) + CRC(4) = 16
  // section_length = 16 - 1(table_id) - 2(section_length) = 13 = 0x0D
  // Total with pointer_field = 17
  final sectionLength = 16 - 1 - 2; // = 13
  final data = Uint8List(17); // pointer_field + section data
  data[0] = 0x00; // pointer_field = 0 (section starts at next byte)
  data[1] = 0x00; // table_id = PAT
  data[2] = 0xB0 |
      ((sectionLength >> 8) & 0x0F); // section_syntax_indicator=1, length high
  data[3] = sectionLength & 0xFF; // section_length low
  data[4] = 0x00; // transport_stream_id high byte
  data[5] = 0x01; // transport_stream_id low byte = 1
  data[6] = 0xC1; // version=0, current=1
  data[7] = 0x00; // section_number = 0
  data[8] = 0x00; // last_section_number = 0
  // Program 1
  data[9] = 0x00; // program_number high = 0
  data[10] = 0x01; // program_number low = 1
  data[11] = ((pmtPid >> 8) & 0x1F) | 0xE0; // PID high
  data[12] = pmtPid & 0xFF; // PID low
  // CRC32 (4 bytes)
  data[13] = 0x00;
  data[14] = 0x00;
  data[15] = 0x00;
  data[16] = 0x00;
  return data;
}

/// Build a PMT (Program Map Table) section payload.
///
/// Includes the pointer_field (0x00) at the start, as it appears in
/// a TS packet payload with payload_unit_start set.
Uint8List _buildPmt(int videoPid, int audioPid) {
  // Table ID = 0x02 for PMT
  // Program number = 1
  // PCR PID = videoPid
  // Stream: H.264 (0x1B) on videoPid, AAC (0x0F) on audioPid
  // Section includes: table_id(1) + section_length(2) + program_number(2)
  //   + version/current(1) + section(1) + last_section(1) + PCR_PID(2)
  //   + info_length(2) + video_entry(5) + audio_entry(5) + CRC32(4) = 26
  // section_length = 26 - 1(table_id) - 2(section_length) = 23 = 0x17
  // Total with pointer_field = 27
  final sectionLength = 26 - 1 - 2; // = 23
  final data = Uint8List(27); // pointer_field + section data
  data[0] = 0x00; // pointer_field = 0 (section starts at next byte)
  data[1] = 0x02; // table_id = PMT
  data[2] = 0xB0 |
      ((sectionLength >> 8) & 0x0F); // section_syntax_indicator=1, length high
  data[3] = sectionLength & 0xFF; // section_length low
  data[4] = 0x00; // program_number high = 0
  data[5] = 0x01; // program_number low = 1
  data[6] = 0xC1; // version=0, current=1
  data[7] = 0x00; // section_number = 0
  data[8] = 0x00; // last_section_number = 0
  data[9] = 0xE0 | ((videoPid >> 8) & 0x0F); // PCR PID high
  data[10] = videoPid & 0xFF; // PCR PID low
  data[11] = 0xF0; // program_info_length = 0
  data[12] = 0x00;
  // Stream 1: H.264 video (0x1B)
  data[13] = 0x1B; // stream_type = H.264
  data[14] = 0xE0 | ((videoPid >> 8) & 0x0F); // elementary_PID high
  data[15] = videoPid & 0xFF; // elementary_PID low
  data[16] = 0xF0; // ES_info_length = 0
  data[17] = 0x00;
  // Stream 2: AAC audio (0x0F)
  data[18] = 0x0F; // stream_type = AAC
  data[19] = 0xE0 | ((audioPid >> 8) & 0x0F); // elementary_PID high
  data[20] = audioPid & 0xFF; // elementary_PID low
  data[21] = 0xF0; // ES_info_length = 0
  data[22] = 0x00;
  // CRC32 (4 bytes)
  data[23] = 0x00;
  data[24] = 0x00;
  data[25] = 0x00;
  data[26] = 0x00;
  return data;
}

/// Build a PES packet payload containing H.264 NAL units.
///
/// Returns the PES packet payload (without TS header).
/// Uses data that avoids false start code (0x00000001) detection.
Uint8List _buildH264PesPayload() {
  // Build a minimal H.264 bitstream:
  // - SPS (sequence parameter set)
  // - PPS (picture parameter set)
  // - IDR slice
  // - Non-IDR slice
  final buffer = BytesBuilder();

  // SPS NAL unit (0x67): start code + NAL header + minimal SPS data
  buffer.add([0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x1E, 0x8D]);
  // PPS NAL unit (0x68)
  buffer.add([0x00, 0x00, 0x00, 0x01, 0x68, 0xCE, 0x38, 0x80]);
  // IDR slice NAL unit (0x65) — avoid 0x00000001 inside payload
  buffer.add([
    0x00,
    0x00,
    0x00,
    0x01,
    0x65,
    0x88,
    0x84,
    0xAF,
    0x60,
    0xA0,
    0xB0,
    0xC0,
    0xD0,
    0xE0,
    0xF0,
    0x12,
  ]);
  // Non-IDR slice NAL unit (0x41)
  buffer.add([0x00, 0x00, 0x00, 0x01, 0x41, 0x9A, 0x22, 0x00]);

  return buffer.toBytes();
}

/// Build a PES packet (wrapping the payload with PES header).
///
/// PES header structure per ISO 13818-1:
///   [0-2]: start_code_prefix (0x00 0x00 0x01) — 3 bytes
///   [3]: stream_id — 1 byte
///   [4-5]: PES_packet_length — 2 bytes
///   [6]: first flags byte: '10' + scrambling + ... — 1 byte
///   [7]: second flags byte: PTS_DTS_flags + ... — 1 byte
///   [8]: PES_header_data_length — 1 byte
///   [9..13]: PTS data (5 bytes) when PTS_DTS_flags = '10'
///   [14+]: elementary stream payload
Uint8List _buildPesPacket(int streamId, Uint8List pesPayload, {int pts = 0}) {
  const pesHeaderLen = 14; // 9 fixed + 5 (PTS) = 14
  final totalLen = pesHeaderLen + pesPayload.length;
  final data = Uint8List(totalLen);
  data[0] = 0x00; // start_code_prefix[0]
  data[1] = 0x00; // start_code_prefix[1]
  data[2] = 0x01; // start_code_prefix[2]
  data[3] = streamId; // e0=video, c0=audio
  data[4] = ((totalLen - 6) >> 8) & 0xFF; // PES_packet_length high
  data[5] = (totalLen - 6) & 0xFF; // PES_packet_length low
  data[6] = 0x80; // '10' + zeros (scrambling/priority/alignment/copyright/copy)
  data[7] = 0x80; // PTS_DTS_flags='10' (PTS only)
  data[8] = 0x05; // PES_header_data_length = 5 (for PTS)
  data[9] = 0x05; // PTS[32-30] + marker_bit
  data[10] = 0x00; // PTS[29-22]
  data[11] = 0x01; // PTS[21-14]
  data[12] = 0x00; // PTS[13-7]
  data[13] = 0x00; // PTS[6-0] + marker_bit
  // Elementary stream payload starts at 14
  for (int i = 0; i < pesPayload.length; i++) {
    data[14 + i] = pesPayload[i];
  }
  return data;
}

void main() {
  group('TsDemuxer - parseTsPackets', () {
    test('throws on empty data', () {
      expect(
        () => TsDemuxer.parseTsPackets(Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('throws on data smaller than one TS packet', () {
      expect(
        () => TsDemuxer.parseTsPackets(Uint8List(100)),
        throwsArgumentError,
      );
    });

    test('throws on missing sync byte', () {
      final invalidData = Uint8List(188);
      expect(
        () => TsDemuxer.parseTsPackets(invalidData),
        throwsFormatException,
      );
    });

    test('returns list of TS packets from valid data', () {
      final patPayload = _buildPat(0x100);
      final patPacket =
          _buildTsPacket(0x0000, 0, patPayload, payloadUnitStart: true);
      final pmtPayload = _buildPmt(0x101, 0x102);
      final pmtPacket =
          _buildTsPacket(0x0100, 0, pmtPayload, payloadUnitStart: true);

      final allData = Uint8List.fromList([...patPacket, ...pmtPacket]);
      final packets = TsDemuxer.parseTsPackets(allData);

      expect(packets.length, equals(2));
      expect(packets[0].pid, equals(0x0000));
      expect(packets[1].pid, equals(0x0100));
    });
  });

  group('TsDemuxer - findProgramMap', () {
    test('finds PAT and PMT correctly', () {
      final videoPid = 0x101;
      final audioPid = 0x102;
      final pmtPid = 0x100;

      final patPayload = _buildPat(pmtPid);
      final patPacket =
          _buildTsPacket(0x0000, 0, patPayload, payloadUnitStart: true);
      final pmtPayload = _buildPmt(videoPid, audioPid);
      final pmtPacket =
          _buildTsPacket(pmtPid, 0, pmtPayload, payloadUnitStart: true);

      final allData = Uint8List.fromList([...patPacket, ...pmtPacket]);
      final packets = TsDemuxer.parseTsPackets(allData);
      final pids = TsDemuxer.findProgramMap(packets);

      expect(pids, isNotNull);
      expect(pids!.videoPid, equals(videoPid));
      expect(pids.audioPid, equals(audioPid));
    });

    test('returns null when PAT is missing', () {
      final packets = <TsPacket>[
        TsPacket(pid: 0x0100, payload: Uint8List(10), payloadUnitStart: true),
      ];
      final pids = TsDemuxer.findProgramMap(packets);
      expect(pids, isNull);
    });
  });

  group('TsDemuxer - extractH264Nalus', () {
    test('extracts NAL units from PES payload', () {
      final h264Data = _buildH264PesPayload();
      final nalus = TsDemuxer.extractH264Nalus(h264Data);

      expect(nalus.length, equals(4));
      // SPS = type 7
      expect(nalus[0].type, equals(7));
      // PPS = type 8
      expect(nalus[1].type, equals(8));
      // IDR = type 5
      expect(nalus[2].type, equals(5));
      // Non-IDR = type 1
      expect(nalus[3].type, equals(1));
    });

    test('returns empty list for data without start codes', () {
      final noNalus = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      final nalus = TsDemuxer.extractH264Nalus(noNalus);
      expect(nalus, isEmpty);
    });

    test('extracts correct NAL data by byte length', () {
      final h264Data = _buildH264PesPayload();
      final nalus = TsDemuxer.extractH264Nalus(h264Data);

      // SPS should be 5 bytes (NAL header + data, without start code)
      expect(nalus[0].data.length, equals(5));
      // PPS should be 4 bytes
      expect(nalus[1].data.length, equals(4));
    });
  });

  group('TsDemuxer - extractAacFrames', () {
    test('extracts AAC frames from ADTS data', () {
      // Build a minimal AAC ADTS frame
      // ADTS header: 7 bytes, raw AAC data: 23 bytes, total frame = 30
      // Frame length = 30, buffer_fullness=0x7FF (VBR)
      //
      // Computing frame_length bits:
      //   30 >> 11 = 0, 30 >> 3 = 3 (0x03), 30 & 7 = 6
      //   data[4] = 0x03
      //   data[5] = (6 << 5) | (0x7FF >> 6 & 0x1F) = 0xC0 | 0x1F = 0xDF
      //   data[6] = (0x7FF & 0x3F) << 2 = 0x3F << 2 = 0xFC
      final adtsHeader = Uint8List.fromList([
        0xFF,
        0xF1,
        0x4C,
        0x80,
        0x03,
        0xDF,
        0xFC,
      ]);
      // Raw AAC frame data (23 bytes of dummy data)
      final aacFrame = Uint8List(23);
      for (int i = 0; i < 23; i++) {
        aacFrame[i] = 0x40 + i;
      }

      final adtsData = Uint8List.fromList([...adtsHeader, ...aacFrame]);
      final frames = TsDemuxer.extractAacFrames(adtsData);

      expect(frames.length, equals(1));
      expect(frames[0].data.length, equals(23));
    });

    test('returns empty for data too short for ADTS header', () {
      final shortData = Uint8List.fromList([0xFF, 0xF1, 0x4C]);
      final frames = TsDemuxer.extractAacFrames(shortData);
      expect(frames, isEmpty);
    });

    test('extracts two consecutive AAC frames', () {
      // Same ADTS header for both frames (frame_length = 30)
      const frameLen = 30;
      const rawLen = frameLen - 7; // 23
      final adtsHeader = Uint8List.fromList([
        0xFF,
        0xF1,
        0x4C,
        0x80,
        0x03,
        0xDF,
        0xFC,
      ]);
      final frameData1 = Uint8List(rawLen);
      final frameData2 =
          Uint8List(rawLen + 10); // second frame has more data (33 bytes raw)
      // For the second frame, need a different header with:
      // frame_length = 7 + 33 = 40
      // (40 >> 3) & 0xFF = 5 → data[4] = 0x05
      // (40 & 7) = 0 → data[5] = (0 << 5) | 0x1F = 0x1F
      final adtsHeader2 = Uint8List.fromList([
        0xFF,
        0xF1,
        0x4C,
        0x80,
        0x05,
        0x1F,
        0xFC,
      ]);

      final frame1 = Uint8List.fromList([...adtsHeader, ...frameData1]);
      final frame2 = Uint8List.fromList([...adtsHeader2, ...frameData2]);

      final allData = Uint8List.fromList([...frame1, ...frame2]);
      final frames = TsDemuxer.extractAacFrames(allData);

      expect(frames.length, equals(2));
      expect(frames[0].data.length, equals(rawLen));
      expect(frames[1].data.length, equals(33));
    });
  });

  group('Mp4Muxer - buildFtypBox', () {
    test('builds valid ftyp box', () {
      final ftyp = Mp4Muxer.buildFtypBox();
      // ftyp: size(4) + type(4) + major_brand(4) + minor_version(4) + compatible_brands(12)
      expect(ftyp.length, equals(28));

      // Check 'ftyp' type
      expect(String.fromCharCodes(ftyp.sublist(4, 8)), equals('ftyp'));
      // Check 'isom' major brand
      expect(String.fromCharCodes(ftyp.sublist(8, 12)), equals('isom'));
      // Check compatible brands (at offset 16, 20, 24)
      expect(String.fromCharCodes(ftyp.sublist(16, 20)), equals('isom'));
      expect(String.fromCharCodes(ftyp.sublist(20, 24)), equals('mp42'));
      expect(String.fromCharCodes(ftyp.sublist(24, 28)), equals('avc1'));
    });
  });

  group('Mp4Muxer - buildAvccBox', () {
    test('builds avcC box from SPS and PPS NAL units', () {
      final spsNal = H264NalUnit(
          type: 7,
          data: Uint8List.fromList([
            0x67,
            0x42,
            0x00,
            0x1E,
            0x8D,
          ]));
      final ppsNal = H264NalUnit(
          type: 8,
          data: Uint8List.fromList([
            0x68,
            0xCE,
            0x38,
            0x80,
          ]));

      final avcc = Mp4Muxer.buildAvccBox([spsNal], [ppsNal]);
      expect(avcc.length, greaterThan(20));

      // Check avcC box header
      expect(String.fromCharCodes(avcc.sublist(4, 8)), equals('avcC'));

      // AVC configuration version = 1
      expect(avcc[8], equals(1));
      // AVC profile (from SPS NAL byte 1)
      expect(avcc[9], equals(0x42));
      // AVC level (from SPS NAL byte 3)
      expect(avcc[11], equals(0x1E));
      // SPS count (1)
      final spsCountOffset = 13;
      expect(avcc[spsCountOffset] & 0x1F, equals(1));
      // PPS count (right after SPS data: sps_count_byte + sps_length(2) + sps_data(5))
      // After SPS count byte, each SPS has 2-byte length + data
      final ppsCountOffset = spsCountOffset + 1 + 2 + 5;
      expect(avcc[ppsCountOffset], equals(1));
    });

    test('returns configuration box even with empty SPS', () {
      final avcc = Mp4Muxer.buildAvccBox([], []);
      // Box header (8) + config (7): version(1) + profile(1) + compat(1) + level(1) + length/ss(1) + sps_count(1) + pps_count(1)
      expect(avcc.length, equals(15));
      // Still should have 'avcC' type
      expect(String.fromCharCodes(avcc.sublist(4, 8)), equals('avcC'));
    });
  });

  group('Mp4Muxer - box helpers', () {
    test('buildBox writes correct size and type', () {
      final content = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final box = Mp4Muxer.buildBox('test', content);
      // size(4) + type(4) + content(4) = 12
      expect(box.length, equals(12));
      // size = 12
      expect(box[0], equals(0x00));
      expect(box[1], equals(0x00));
      expect(box[2], equals(0x00));
      expect(box[3], equals(0x0C));
      // type
      expect(String.fromCharCodes(box.sublist(4, 8)), equals('test'));
    });

    test('buildFullBox handles version/flags', () {
      final content = Uint8List.fromList([0x01, 0x02, 0x03]);
      final box = Mp4Muxer.buildFullBox('mvhd', content, version: 0, flags: 0);
      // size(4) + type(4) + version(1) + flags(3) + content(3) = 15
      expect(box.length, equals(15));
      expect(box[8], equals(0)); // version
      expect(box[9], equals(0)); // flags
      expect(box[10], equals(0));
      expect(box[11], equals(0));
    });
  });

  group('TsDemuxer - extractVideoBitstream', () {
    test('extracts continuous H.264 bitstream from TS packets', () {
      final videoPid = 0x101;
      final pmtPid = 0x100;

      // Build PAT + PMT
      final patPid = 0x0000;
      final patPayload = _buildPat(pmtPid);
      final patPacket =
          _buildTsPacket(patPid, 0, patPayload, payloadUnitStart: true);

      final pmtPayload = _buildPmt(videoPid, 0x102);
      final pmtPacket =
          _buildTsPacket(pmtPid, 0, pmtPayload, payloadUnitStart: true);

      // Build larger video PES payload (big enough to split)
      final largePayload = Uint8List.fromList([
        ..._buildH264PesPayload(),
        ...Uint8List(200), // padding to make PES large enough to split
      ]);
      final pesPacket = _buildPesPacket(0xE0, largePayload);

      // Split PES across multiple TS packets
      final splitPoint = (pesPacket.length ~/ 2);
      final tsPacket1 = _buildTsPacket(
          videoPid, 0, pesPacket.sublist(0, splitPoint),
          payloadUnitStart: true);
      final tsPacket2 = _buildTsPacket(
          videoPid, 1, pesPacket.sublist(splitPoint),
          payloadUnitStart: false);

      final allData = Uint8List.fromList([
        ...patPacket,
        ...pmtPacket,
        ...tsPacket1,
        ...tsPacket2,
      ]);

      final packets = TsDemuxer.parseTsPackets(allData);
      final pids = TsDemuxer.findProgramMap(packets);
      expect(pids, isNotNull);

      final bitstream = TsDemuxer.extractVideoBitstream(packets, pids!);
      expect(bitstream.length, greaterThan(0));

      // Should contain H.264 start codes
      expect(bitstream[0], equals(0x00));
      expect(bitstream[1], equals(0x00));
      expect(bitstream[2], equals(0x00));
      expect(bitstream[3], equals(0x01));
    });
  });

  group('TsDemuxer - extractAudioBitstream', () {
    test('extracts AAC frames from TS packets', () {
      final audioPid = 0x102;
      final pmtPid = 0x100;

      // Build PAT + PMT
      final patPid = 0x0000;
      final patPayload = _buildPat(pmtPid);
      final patPacket =
          _buildTsPacket(patPid, 0, patPayload, payloadUnitStart: true);

      final pmtPayload = _buildPmt(0x101, audioPid);
      final pmtPacket =
          _buildTsPacket(pmtPid, 0, pmtPayload, payloadUnitStart: true);

      // Build AAC ADTS frame (frame_length = 7 + 50 = 57)
      // frame_length = 57
      // (57 >> 11) = 0, (57 >> 3) = 7 (0x07), (57 & 7) = 1
      // data[4] = 0x07
      // data[5] = (1 << 5) | (0x7FF >> 6 & 0x1F) = 0x20 | 0x1F = 0x3F
      // data[6] = 0xFC
      final adtsHeader = Uint8List.fromList([
        0xFF,
        0xF1,
        0x4C,
        0x80,
        0x07,
        0x3F,
        0xFC,
      ]);
      final aacData = Uint8List(50);
      for (int i = 0; i < 50; i++) {
        aacData[i] = 0x50 + i;
      }
      final aacFrame = Uint8List.fromList([...adtsHeader, ...aacData]);

      // Wrap in PES
      final pesPacket = _buildPesPacket(0xC0, aacFrame);

      // Place in TS packet
      final tsPacket =
          _buildTsPacket(audioPid, 0, pesPacket, payloadUnitStart: true);

      final allData =
          Uint8List.fromList([...patPacket, ...pmtPacket, ...tsPacket]);

      final packets = TsDemuxer.parseTsPackets(allData);
      final pids = TsDemuxer.findProgramMap(packets);
      expect(pids, isNotNull);

      final audioData = TsDemuxer.extractAudioBitstream(packets, pids!);
      expect(audioData.length, greaterThan(0));
    });

    test('returns empty when no audio PID found', () {
      final packets = <TsPacket>[
        TsPacket(pid: 0x0000, payload: Uint8List(10), payloadUnitStart: true)
      ];
      final pids = ProgramPids(videoPid: 0x101, audioPid: null);
      final audioData = TsDemuxer.extractAudioBitstream(packets, pids);
      expect(audioData, isEmpty);
    });
  });

  group('TsDemuxer - convertTsToMp4 (integration)', () {
    test('converts minimal TS to valid MP4', () async {
      final videoPid = 0x101;
      final audioPid = 0x102;
      final pmtPid = 0x100;

      // Build PAT
      final patData = _buildPat(pmtPid);
      final patPacket =
          _buildTsPacket(0x0000, 0, patData, payloadUnitStart: true);

      // Build PMT
      final pmtData = _buildPmt(videoPid, audioPid);
      final pmtPacket =
          _buildTsPacket(pmtPid, 0, pmtData, payloadUnitStart: true);

      // Build video data
      final h264Payload = _buildH264PesPayload();
      final videoPes = _buildPesPacket(0xE0, h264Payload);
      final videoPacket =
          _buildTsPacket(videoPid, 0, videoPes, payloadUnitStart: true);

      // Build AAC data (frame_length = 7 + 30 = 37)
      // (37 >> 11) = 0, (37 >> 3) = 4 (0x04), (37 & 7) = 5
      // data[4] = 0x04
      // data[5] = (5 << 5) | 0x1F = 0xA0 | 0x1F = 0xBF
      final adtsHeader = Uint8List.fromList([
        0xFF,
        0xF1,
        0x4C,
        0x80,
        0x04,
        0xBF,
        0xFC,
      ]);
      final aacRaw = Uint8List(30);
      final aacFrame = Uint8List.fromList([...adtsHeader, ...aacRaw]);
      final audioPes = _buildPesPacket(0xC0, aacFrame);
      final audioPacket =
          _buildTsPacket(audioPid, 0, audioPes, payloadUnitStart: true);

      final tsData = Uint8List.fromList([
        ...patPacket,
        ...pmtPacket,
        ...videoPacket,
        ...audioPacket,
      ]);

      // Write temp TS file
      final tempDir = Directory.systemTemp.createTempSync('ts_remuxer_test_');
      try {
        final tsPath = '${tempDir.path}\\input.ts';
        final mp4Path = '${tempDir.path}\\output.mp4';

        await File(tsPath).writeAsBytes(tsData);

        // Convert
        final resultPath = await TsDemuxer.convertTsToMp4(
          inputPath: tsPath,
          outputPath: mp4Path,
        );

        // Verify output exists and is a valid MP4
        expect(resultPath, equals(mp4Path));
        final mp4File = File(mp4Path);
        expect(await mp4File.exists(), isTrue);

        final mp4Bytes = await mp4File.readAsBytes();
        // Should contain 'ftyp' at start
        expect(String.fromCharCodes(mp4Bytes.sublist(4, 8)), equals('ftyp'));
        // Should be larger than just the header
        expect(mp4Bytes.length, greaterThan(100));
        // Should contain 'moov' somewhere
        final mp4Str = String.fromCharCodes(mp4Bytes);
        expect(mp4Str.contains('moov'), isTrue);
        expect(mp4Str.contains('avc1'), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws on non-existent input file', () async {
      await expectLater(
        () => TsDemuxer.convertTsToMp4(
          inputPath: '/nonexistent/file.ts',
          outputPath: '/tmp/out.mp4',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
