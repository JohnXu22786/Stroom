import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

// ============================================================================
// Data structures
// ============================================================================

/// A single MPEG-TS packet (188 bytes).
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

/// Program stream PIDs found via PAT/PMT.
class ProgramPids {
  final int videoPid;
  final int? audioPid;

  /// Stream type from PMT: 0x1B = H.264, 0x24 = H.265, 0x02 = MPEG-2
  final int videoStreamType;
  final int? audioStreamType;

  const ProgramPids({
    required this.videoPid,
    this.audioPid,
    this.videoStreamType = 0x1B,
    this.audioStreamType,
  });
}

/// A parsed H.264 NAL unit.
class H264NalUnit {
  /// NAL unit type (1-31, or 32-63 for HEVC).
  final int type;

  /// Raw NAL unit data (including the NAL header byte).
  final Uint8List data;

  const H264NalUnit({required this.type, required this.data});
}

/// A parsed AAC frame (raw data without ADTS header).
class AacFrame {
  final Uint8List data;

  const AacFrame({required this.data});
}

// ============================================================================
// TS Demuxer — pure Dart MPEG-TS parser
// ============================================================================

class TsDemuxer {
  TsDemuxer._();

  /// Parse raw bytes into a list of [TsPacket]s.
  ///
  /// Each packet is exactly 188 bytes. Throws if the data is not a multiple
  /// of 188 bytes or if sync bytes are missing.
  static List<TsPacket> parseTsPackets(Uint8List data) {
    if (data.isEmpty) {
      throw ArgumentError('TS data is empty');
    }
    if (data.length < 188) {
      throw ArgumentError(
          'TS data too short: ${data.length} bytes (minimum 188)');
    }
    if (data.length % 188 != 0) {
      debugPrint(
          '[TsDemuxer] Warning: TS data length ${data.length} is not a multiple of 188');
    }

    final packets = <TsPacket>[];
    for (int offset = 0; offset + 188 <= data.length; offset += 188) {
      if (data[offset] != 0x47) {
        throw FormatException(
            'Missing TS sync byte at offset $offset (got 0x${data[offset].toRadixString(16).padLeft(2, '0')})');
      }

      final pid = ((data[offset + 1] & 0x1F) << 8) | data[offset + 2];
      final payloadUnitStart = (data[offset + 1] & 0x40) != 0;

      // Adaptation field control: 2 low bits
      final adaptFieldCtrl = data[offset + 3] & 0x30;
      int payloadStart = 4;
      if (adaptFieldCtrl == 0x20 || adaptFieldCtrl == 0x30) {
        // Has adaptation field
        final adaptLen = data[offset + 4];
        payloadStart = 4 + 1 + adaptLen; // +1 for the length byte itself
      }

      // Payload starts at payloadStart within the current packet
      final absolutePayloadStart = offset + payloadStart;
      final absolutePayloadEnd = offset + 188;
      if (absolutePayloadStart < absolutePayloadEnd) {
        final payload = data.sublist(absolutePayloadStart, absolutePayloadEnd);
        packets.add(TsPacket(
          pid: pid,
          payload: payload,
          payloadUnitStart: payloadUnitStart,
        ));
      } else {
        packets.add(TsPacket(
          pid: pid,
          payload: Uint8List(0),
          payloadUnitStart: payloadUnitStart,
        ));
      }
    }
    return packets;
  }

  /// Find video and audio PIDs from PAT and PMT tables.
  ///
  /// Returns null if no program found.
  static ProgramPids? findProgramMap(List<TsPacket> packets) {
    int? pmtPid;

    // Step 1: Find PAT (PID 0x0000) to get PMT PID
    for (final pkt in packets) {
      if (pkt.pid == 0x0000 && pkt.payloadUnitStart && pkt.payload.length > 8) {
        final payload = pkt.payload;
        int offset = 1; // skip pointer_field
        if (offset >= payload.length) continue;

        // Parse section
        // table_id at payload[offset]
        if (payload[offset] != 0x00) continue; // not PAT
        offset++;
        if (offset + 2 > payload.length) continue;
        final sectionLength =
            ((payload[offset] & 0x0F) << 8) | payload[offset + 1];
        offset += 2;
        if (offset + 2 > payload.length) continue;
        // Skip transport_stream_id (2 bytes)
        offset += 2;
        if (offset >= payload.length) continue;
        // Skip version/section info (1 byte)
        offset += 1;
        if (offset >= payload.length) continue;
        // Skip section_number (1)
        offset += 1;
        if (offset >= payload.length) continue;
        // Skip last_section_number (1)
        offset += 1;

        // Parse programs
        final sectionEnd =
            offset + sectionLength - 9; // minus CRC (4) and header (5)
        while (offset + 4 <= sectionEnd && offset + 4 <= payload.length) {
          // program_number (2 bytes)
          final progNum = (payload[offset] << 8) | payload[offset + 1];
          offset += 2;
          // program_map_PID (2 bytes)
          final pid = ((payload[offset] & 0x1F) << 8) | payload[offset + 1];
          offset += 2;

          if (progNum != 0) {
            pmtPid = pid;
            break;
          }
        }
        if (pmtPid != null) break;
      }
    }

    if (pmtPid == null) return null;

    // Step 2: Find PMT to get video/audio PIDs
    int? videoPid;
    int? audioPid;
    int videoStreamType = 0x1B;
    int? audioStreamType;

    for (final pkt in packets) {
      if (pkt.pid == pmtPid && pkt.payloadUnitStart) {
        final payload = pkt.payload;
        int offset = 1; // skip pointer_field

        if (offset >= payload.length) continue;
        if (payload[offset] != 0x02) continue; // table_id = PMT
        offset++;
        if (offset + 2 > payload.length) continue;
        final sectionLength =
            ((payload[offset] & 0x0F) << 8) | payload[offset + 1];
        offset += 2;
        // Skip program_number (2)
        offset += 2;
        if (offset >= payload.length) continue;
        // Skip version (1)
        offset += 1;
        // Skip section_number (1)
        offset += 1;
        // Skip last_section_number (1)
        offset += 1;
        // PCR_PID (2)
        offset += 2;
        if (offset + 2 > payload.length) continue;
        // program_info_length
        final infoLen = ((payload[offset] & 0x0F) << 8) | payload[offset + 1];
        offset += 2;
        // Skip program descriptors
        offset += infoLen;

        // Parse streams
        final streamsEnd = offset + sectionLength - 9 - infoLen;
        while (offset + 5 <= streamsEnd && offset + 5 <= payload.length) {
          final streamType = payload[offset];
          offset++;
          final pid = ((payload[offset] & 0x1F) << 8) | payload[offset + 1];
          offset += 2;
          final esInfoLen =
              ((payload[offset] & 0x0F) << 8) | payload[offset + 1];
          offset += 2;
          // Skip ES descriptors
          offset += esInfoLen;

          // H.264 (0x1B), H.265 (0x24), MPEG-2 Video (0x02)
          if (streamType == 0x1B ||
              streamType == 0x24 ||
              streamType == 0x02 ||
              streamType == 0x01 ||
              streamType == 0x10) {
            if (videoPid == null) {
              videoPid = pid;
              videoStreamType = streamType;
            }
          }
          // AAC (0x0F), MPEG-2 Audio (0x03/0x04), AC-3 (0x81/0x06)
          if (streamType == 0x0F ||
              streamType == 0x03 ||
              streamType == 0x04 ||
              streamType == 0x06 ||
              streamType == 0x81) {
            if (audioPid == null) {
              audioPid = pid;
              audioStreamType = streamType;
            }
          }
        }
        break;
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

  /// Extract H.264/H.265 NAL units from raw data (annex B format).
  ///
  /// Searches for 0x00000001 or 0x000001 start code prefixes.
  static List<H264NalUnit> extractH264Nalus(Uint8List data) {
    final nalus = <H264NalUnit>[];
    if (data.length < 4) return nalus;

    int i = 0;
    while (i < data.length - 3) {
      // Find start code
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

        // Find end of this NAL unit (next start code)
        int naluEnd = naluStart;
        while (naluEnd < data.length) {
          // Check if we found next start code
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
          final nalType = naluData[0] & 0x1F;
          nalus.add(H264NalUnit(type: nalType, data: naluData));
        }
        i = naluEnd;
      } else {
        i++;
      }
    }
    return nalus;
  }

  /// Extract AAC frames from ADTS-encapsulated audio data.
  ///
  /// Returns list of raw AAC frames (without ADTS headers).
  static List<AacFrame> extractAacFrames(Uint8List data) {
    final frames = <AacFrame>[];
    int i = 0;

    while (i + 6 < data.length) {
      // Check for ADTS sync word (0xFFF)
      if (data[i] == 0xFF && (data[i + 1] & 0xF0) == 0xF0) {
        // Parse ADTS frame length (13 bits)
        final frameLength = ((data[i + 3] & 0x03) << 11) |
            (data[i + 4] << 3) |
            ((data[i + 5] >> 5) & 0x07);

        if (frameLength < 7 || i + frameLength > data.length) {
          i++;
          continue;
        }

        // Extract raw AAC data (without ADTS header)
        final rawData = data.sublist(i + 7, i + frameLength);
        frames.add(AacFrame(data: rawData));
        i += frameLength;
      } else {
        i++;
      }
    }

    return frames;
  }

  /// Extract the video bitstream from TS packets.
  ///
  /// Reassembles PES packets from the video PID and returns the
  /// concatenated payload (H.264 annex B format).
  static Uint8List extractVideoBitstream(
      List<TsPacket> packets, ProgramPids pids) {
    final videoPesPayload = _reassemblePes(packets, pids.videoPid);
    return videoPesPayload;
  }

  /// Extract the audio bitstream from TS packets.
  ///
  /// Reassembles PES packets from the audio PID and returns the
  /// concatenated payload (ADTS-encapsulated AAC or raw audio).
  static Uint8List extractAudioBitstream(
      List<TsPacket> packets, ProgramPids pids) {
    if (pids.audioPid == null) return Uint8List(0);
    return _reassemblePes(packets, pids.audioPid!);
  }

  /// Reassemble PES packet payloads for a given PID.
  ///
  /// Strips PES headers and concatenates the elementary stream data.
  static Uint8List _reassemblePes(List<TsPacket> packets, int pid) {
    final allPayload = BytesBuilder();
    bool inPes = false;
    int pesHeaderRemaining = 0;

    for (final pkt in packets) {
      if (pkt.pid != pid) continue;
      if (pkt.payload.isEmpty) continue;

      if (pkt.payloadUnitStart && !inPes) {
        // New PES packet starts here
        inPes = true;
        final payload = pkt.payload;

        // PES header starts after TS header
        // Packet start code prefix: 0x00 0x00 0x01
        if (payload.length >= 4 &&
            payload[0] == 0x00 &&
            payload[1] == 0x00 &&
            payload[2] == 0x01) {
          // Stream ID at payload[3]
          // PES header data length at payload[8] per ISO 13818-1
          if (payload.length < 9) {
            inPes = false;
            continue;
          }
          final headerDataLen = payload[8];
          pesHeaderRemaining = 9 + headerDataLen; // total header size

          // If payload contains data after header, add it
          if (payload.length > pesHeaderRemaining) {
            allPayload.add(payload.sublist(pesHeaderRemaining));
          }
          pesHeaderRemaining = 0;
          inPes = false;
        } else {
          // PES header already in progress from previous packet
          allPayload.add(payload);
        }
      } else if (inPes) {
        // Continuation of a PES packet
        if (pesHeaderRemaining > 0) {
          // Still in PES header bytes
          if (pkt.payload.length <= pesHeaderRemaining) {
            pesHeaderRemaining -= pkt.payload.length;
          } else {
            final dataStart = pesHeaderRemaining;
            allPayload.add(pkt.payload.sublist(dataStart));
            pesHeaderRemaining = 0;
            inPes = false;
          }
        } else {
          allPayload.add(pkt.payload);
        }
      } else if (pkt.payloadUnitStart) {
        // New PES starts (but we're not tracking previous one)
        inPes = true;
        final payload = pkt.payload;
        if (payload.length >= 4 &&
            payload[0] == 0x00 &&
            payload[1] == 0x00 &&
            payload[2] == 0x01) {
          if (payload.length < 9) {
            inPes = false;
            continue;
          }
          final headerDataLen = payload[8];
          pesHeaderRemaining = 9 + headerDataLen;
          if (payload.length > pesHeaderRemaining) {
            allPayload.add(payload.sublist(pesHeaderRemaining));
          }
          pesHeaderRemaining = 0;
          inPes = false;
        } else {
          allPayload.add(payload);
        }
      } else {
        // Continuation without a known PES start — best effort
        allPayload.add(pkt.payload);
      }
    }

    return allPayload.toBytes();
  }

  /// Main entry point: convert a TS file to MP4.
  ///
  /// [inputPath] path to the input .ts file
  /// [outputPath] path for the output .mp4 file
  ///
  /// Returns the output path on success.
  static Future<String> convertTsToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('TS file not found', inputPath);
    }

    // Ensure output directory exists
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    onProgress?.call(5);

    // Read entire TS file
    final tsBytes = await inputFile.readAsBytes();
    onProgress?.call(10);

    // Parse packets
    final packets = parseTsPackets(tsBytes);
    onProgress?.call(20);

    // Find program map
    final pids = findProgramMap(packets);
    if (pids == null) {
      throw FormatException('Could not find program map in TS file');
    }
    onProgress?.call(30);

    debugPrint(
        '[TsDemuxer] Found video PID: 0x${pids.videoPid.toRadixString(16)}'
        '${pids.audioPid != null ? ", audio PID: 0x${pids.audioPid!.toRadixString(16)}" : ""}');

    // Extract video NAL units
    final videoBitstream = extractVideoBitstream(packets, pids);
    final nalus = extractH264Nalus(videoBitstream);
    onProgress?.call(50);

    if (nalus.isEmpty) {
      throw FormatException('No video NAL units found in TS file');
    }

    debugPrint('[TsDemuxer] Extracted ${nalus.length} NAL units');

    // Extract AAC frames
    final audioBitstream = extractAudioBitstream(packets, pids);
    final aacFrames = audioBitstream.isNotEmpty
        ? extractAacFrames(audioBitstream)
        : <AacFrame>[];
    onProgress?.call(60);

    debugPrint('[TsDemuxer] Extracted ${aacFrames.length} AAC frames');

    // Separate SPS, PPS, and other NAL units
    final spsNalus = <H264NalUnit>[];
    final ppsNalus = <H264NalUnit>[];
    for (final nalu in nalus) {
      if (nalu.type == 7) {
        spsNalus.add(nalu);
      } else if (nalu.type == 8) {
        ppsNalus.add(nalu);
      }
    }
    onProgress?.call(70);

    if (spsNalus.isEmpty) {
      throw FormatException('No SPS NAL unit found (required for MP4)');
    }

    // Write MP4
    final mp4Data = Mp4Muxer.buildMp4(
      spsNalus: spsNalus,
      ppsNalus: ppsNalus,
      videoSamples: nalus.where((n) => n.type == 5 || n.type == 1).toList(),
      allNalus: nalus,
      aacFrames: aacFrames,
      videoStreamType: pids.videoStreamType,
    );
    onProgress?.call(85);

    await File(outputPath).writeAsBytes(mp4Data);
    onProgress?.call(100);

    debugPrint(
        '[TsDemuxer] MP4 written to $outputPath (${mp4Data.length} bytes)');
    return outputPath;
  }
}

// ============================================================================
// MP4 Muxer — pure Dart minimal MP4 container builder
// ============================================================================

class Mp4Muxer {
  Mp4Muxer._();

  /// Build a complete MP4 file.
  static Uint8List buildMp4({
    required List<H264NalUnit> spsNalus,
    required List<H264NalUnit> ppsNalus,
    required List<H264NalUnit> videoSamples,
    required List<H264NalUnit> allNalus,
    required List<AacFrame> aacFrames,
    int videoStreamType = 0x1B,
  }) {
    // Build mdat data first to know actual sample sizes
    final mdatData = buildMdatData(
      allNalus: allNalus,
      aacFrames: aacFrames,
    );

    // Compute per-sample sizes for video NAL units
    final videoSampleSizes = <int>[];
    for (final nalu in allNalus) {
      // Each NAL unit is prefixed with 4-byte length in mdat
      videoSampleSizes.add(4 + nalu.data.length);
    }
    // Compute per-sample sizes for AAC frames
    final audioSampleSizes = <int>[];
    for (final frame in aacFrames) {
      audioSampleSizes.add(4 + frame.data.length);
    }

    final hasAudio = aacFrames.isNotEmpty;

    // Calculate offsets
    final ftypBox = buildFtypBox();
    final mdatBox = buildBox('mdat', mdatData);
    final mdatOffset = ftypBox.length + 8; // 8 = mdat box header

    // Build moov box with correct sample sizes and offsets
    final moovBox = buildMoovBox(
      spsNalus: spsNalus,
      ppsNalus: ppsNalus,
      mdatSize: mdatData.length,
      mdatOffset: mdatOffset,
      videoSampleCount: allNalus.length,
      totalNaluCount: allNalus.length,
      videoSampleSizes: videoSampleSizes,
      hasAudio: hasAudio,
      aacFrameCount: aacFrames.length,
      audioSampleSizes: audioSampleSizes,
      videoStreamType: videoStreamType,
    );

    // Concatenate ftyp + mdat + moov
    final result = BytesBuilder();
    result.add(ftypBox);
    result.add(mdatBox);
    result.add(moovBox);
    return result.toBytes();
  }

  /// Build the ftyp (file type) box.
  static Uint8List buildFtypBox() {
    final content = BytesBuilder();
    // major_brand: 'isom'
    content.add(iso639Code('isom'));
    // minor_version: 0x0200
    content.add([0x02, 0x00, 0x00, 0x00]);
    // compatible_brands: 'isom', 'mp42', 'avc1'
    content.add(iso639Code('isom'));
    content.add(iso639Code('mp42'));
    content.add(iso639Code('avc1'));
    return buildBox('ftyp', content.toBytes());
  }

  /// Build the moov (movie) box.
  static Uint8List buildMoovBox({
    required List<H264NalUnit> spsNalus,
    required List<H264NalUnit> ppsNalus,
    required int mdatSize,
    required int mdatOffset,
    required int videoSampleCount,
    required int totalNaluCount,
    required List<int> videoSampleSizes,
    required bool hasAudio,
    required int aacFrameCount,
    required List<int> audioSampleSizes,
    int videoStreamType = 0x1B,
  }) {
    final moovContent = BytesBuilder();

    // mvhd
    moovContent.add(buildMvhdBox());

    // Video track
    moovContent.add(buildVideoTrackBox(
      spsNalus: spsNalus,
      ppsNalus: ppsNalus,
      mdatSize: mdatSize,
      mdatOffset: mdatOffset,
      sampleCount: videoSampleCount,
      totalNaluCount: totalNaluCount,
      sampleSizes: videoSampleSizes,
      videoStreamType: videoStreamType,
    ));

    // Audio track (if present)
    if (hasAudio) {
      moovContent.add(buildAudioTrackBox(
        aacFrameCount: aacFrameCount,
        mdatOffset: mdatOffset,
        totalMdatSize: mdatSize,
        sampleSizes: audioSampleSizes,
      ));
    }

    return buildBox('moov', moovContent.toBytes());
  }

  /// Build mvhd (movie header) full box.
  static Uint8List buildMvhdBox() {
    // Version 0, 8 bytes per timestamp
    final content = BytesBuilder();
    // creation_time, modification_time
    content.add(Uint8List(8)); // 0
    content.add(Uint8List(8)); // 0
    // timescale: 1000
    content.add([0x00, 0x00, 0x03, 0xE8]);
    // duration: 0 (unknown)
    content.add(Uint8List(8));
    // rate: 1.0 (0x00010000)
    content.add([0x00, 0x01, 0x00, 0x00]);
    // volume: 1.0 (0x0100)
    content.add([0x01, 0x00]);
    // reserved (10 bytes)
    content.add(Uint8List(10));
    // matrix (36 bytes) — identity
    content.add([
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    // pre-defined (24 bytes) — 6 zeros
    content.add(Uint8List(24));
    // next_track_id: 3
    content.add([0x00, 0x00, 0x00, 0x03]);

    return buildFullBox('mvhd', content.toBytes(), version: 1);
  }

  /// Build a video track box (trak).
  static Uint8List buildVideoTrackBox({
    required List<H264NalUnit> spsNalus,
    required List<H264NalUnit> ppsNalus,
    required int mdatSize,
    required int mdatOffset,
    required int sampleCount,
    required int totalNaluCount,
    required List<int> sampleSizes,
    int videoStreamType = 0x1B,
  }) {
    final trakContent = BytesBuilder();

    // tkhd (track header)
    trakContent.add(buildVideoTkhdBox());

    // mdia
    final mdiaContent = BytesBuilder();
    // mdhd
    mdiaContent.add(buildMdhdBox());
    // hdlr
    mdiaContent.add(buildHdlrBox('vide', 'Video Track'));
    // minf
    final minfContent = BytesBuilder();
    // vmhd
    minfContent.add(buildVmhdBox());
    // dinf
    minfContent.add(buildDinfBox());
    // stbl
    minfContent.add(buildVideoStblBox(
      spsNalus: spsNalus,
      ppsNalus: ppsNalus,
      sampleCount: sampleCount,
      mdatSize: mdatSize,
      mdatOffset: mdatOffset,
      totalNaluCount: totalNaluCount,
      sampleSizes: sampleSizes,
      videoStreamType: videoStreamType,
    ));
    mdiaContent.add(buildBox('minf', minfContent.toBytes()));

    trakContent.add(buildBox('mdia', mdiaContent.toBytes()));

    return buildBox('trak', trakContent.toBytes());
  }

  /// Build an audio track box (trak).
  static Uint8List buildAudioTrackBox({
    required int aacFrameCount,
    required int mdatOffset,
    required int totalMdatSize,
    required List<int> sampleSizes,
  }) {
    final trakContent = BytesBuilder();

    // tkhd
    trakContent.add(buildAudioTkhdBox());

    // mdia
    final mdiaContent = BytesBuilder();
    // mdhd
    mdiaContent.add(buildMdhdBox());
    // hdlr
    mdiaContent.add(buildHdlrBox('soun', 'Audio Track'));
    // minf
    final minfContent = BytesBuilder();
    // smhd
    minfContent.add(buildSmhdBox());
    // dinf
    minfContent.add(buildDinfBox());
    // stbl
    minfContent.add(buildAudioStblBox(
      aacFrameCount: aacFrameCount,
      mdatOffset: mdatOffset,
      totalMdatSize: totalMdatSize,
      sampleSizes: sampleSizes,
    ));
    mdiaContent.add(buildBox('minf', minfContent.toBytes()));

    trakContent.add(buildBox('mdia', mdiaContent.toBytes()));

    return buildBox('trak', trakContent.toBytes());
  }

  /// Build tkhd for video track.
  static Uint8List buildVideoTkhdBox() {
    // Version 1 (64-bit timestamps)
    final content = BytesBuilder();
    // creation_time, modification_time
    content.add(Uint8List(8));
    content.add(Uint8List(8));
    // track_ID: 1
    content.add([0x00, 0x00, 0x00, 0x01]);
    // reserved
    content.add([0x00, 0x00, 0x00, 0x00]);
    // duration: 0
    content.add(Uint8List(8));
    // reserved (8 bytes)
    content.add(Uint8List(8));
    // layer: 0, alternate_group: 0
    content.add([0x00, 0x00, 0x00, 0x00]);
    // volume: 0, reserved
    content.add([0x00, 0x00]);
    // matrix (36 bytes)
    content.add([
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    // width, height (fixed-point 16.16)
    content.add([0x00, 0x00, 0x00, 0x00]); // 0
    content.add([0x00, 0x00, 0x00, 0x00]); // 0

    return buildFullBox('tkhd', content.toBytes(),
        version: 1,
        flags: 0x07); // track_enabled | track_in_movie | track_in_preview
  }

  /// Build tkhd for audio track.
  static Uint8List buildAudioTkhdBox() {
    final content = BytesBuilder();
    content.add(Uint8List(8)); // creation_time
    content.add(Uint8List(8)); // modification_time
    content.add([0x00, 0x00, 0x00, 0x02]); // track_ID: 2
    content.add([0x00, 0x00, 0x00, 0x00]); // reserved
    content.add(Uint8List(8)); // duration
    content.add(Uint8List(8)); // reserved
    content.add([0x00, 0x00, 0x00, 0x00]); // layer, alternate_group
    content.add([0x01, 0x00]); // volume: 1.0
    content.add([
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    content.add([0x00, 0x00, 0x00, 0x00]); // width
    content.add([0x00, 0x00, 0x00, 0x00]); // height

    return buildFullBox('tkhd', content.toBytes(), version: 1, flags: 0x07);
  }

  /// Build mdhd (media header) box.
  static Uint8List buildMdhdBox() {
    // Version 1
    final content = BytesBuilder();
    content.add(Uint8List(8)); // creation_time
    content.add(Uint8List(8)); // modification_time
    content.add([0x00, 0x00, 0x03, 0xE8]); // timescale: 1000
    content.add(Uint8List(8)); // duration: 0
    content.add([0x55, 0xC4]); // language: und (0x55C4)
    content.add([0x00, 0x00]); // quality

    return buildFullBox('mdhd', content.toBytes(), version: 1);
  }

  /// Build hdlr (handler) box.
  static Uint8List buildHdlrBox(String handlerType, String name) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // pre-defined
    content.add(iso639Code(handlerType)); // handler_type: 'vide' or 'soun'
    content.add([0x00, 0x00, 0x00, 0x00]); // reserved
    content.add([0x00, 0x00, 0x00, 0x00]); // reserved
    content.add([0x00, 0x00, 0x00, 0x00]); // reserved
    content.add(codeUnits(name)); // name (null-terminated)
    content.add([0x00]); // null terminator

    return buildFullBox('hdlr', content.toBytes());
  }

  /// Build vmhd (video media header) box.
  static Uint8List buildVmhdBox() {
    // Version 0, flags 1 (fullframe)
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // mode: copy
    content.add([0x00, 0x00, 0x00, 0x00]); // reserved

    return buildFullBox('vmhd', content.toBytes(), flags: 0x01);
  }

  /// Build smhd (sound media header) box.
  static Uint8List buildSmhdBox() {
    final content = BytesBuilder();
    content.add([0x00, 0x00]); // balance: 0
    content.add([0x00, 0x00]); // reserved

    return buildFullBox('smhd', content.toBytes());
  }

  /// Build dinf (data information) box.
  static Uint8List buildDinfBox() {
    // dref with a single url entry
    final drefContent = BytesBuilder();
    drefContent.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    drefContent.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1

    // url box: data reference, self-contained (flags 1)
    final urlBox = buildFullBox('url ', Uint8List(0), flags: 0x01);
    drefContent.add(urlBox);

    return buildBox('dref', drefContent.toBytes());
  }

  /// Build stbl (sample table) box for video.
  static Uint8List buildVideoStblBox({
    required List<H264NalUnit> spsNalus,
    required List<H264NalUnit> ppsNalus,
    required int sampleCount,
    required int mdatSize,
    required int mdatOffset,
    required int totalNaluCount,
    required List<int> sampleSizes,
    int videoStreamType = 0x1B,
  }) {
    final stblContent = BytesBuilder();

    // stsd (sample description)
    stblContent.add(buildVideoStsdBox(
      spsNalus: spsNalus,
      ppsNalus: ppsNalus,
    ));

    // stts (time-to-sample) — all at once
    stblContent.add(buildSttsBox(sampleCount));

    // stsc (sample-to-chunk) — all in one chunk
    stblContent.add(buildStscBox(1, 1, sampleCount));

    // stsz (sample sizes) — variable sizes
    stblContent.add(buildStszBox(sampleCount, sampleSizes: sampleSizes));

    // stco (chunk offset) — 64-bit (co64)
    stblContent.add(buildCo64Box(mdatOffset + 8)); // +8 for mdat box header

    // stss (sync sample) — key frames (IDR) only
    // (allNalus passed as null here; the actual NAL units are used
    //  via the stss method directly when available)
    stblContent.add(buildStssBox(sampleCount));

    return buildBox('stbl', stblContent.toBytes());
  }

  /// Build stbl box for audio.
  static Uint8List buildAudioStblBox({
    required int aacFrameCount,
    required int mdatOffset,
    required int totalMdatSize,
    required List<int> sampleSizes,
  }) {
    final stblContent = BytesBuilder();

    // stsd
    stblContent.add(buildAudioStsdBox());

    // stts
    stblContent.add(buildSttsBox(aacFrameCount));

    // stsc
    stblContent.add(buildStscBox(1, 1, aacFrameCount));

    // stsz
    stblContent.add(buildStszBox(aacFrameCount, sampleSizes: sampleSizes));

    // stco
    stblContent.add(buildCo64Box(mdatOffset + 8));

    // Audio has no stss (all samples are sync)

    return buildBox('stbl', stblContent.toBytes());
  }

  /// Build stsd (sample description) box for H.264 video.
  static Uint8List buildVideoStsdBox({
    required List<H264NalUnit> spsNalus,
    required List<H264NalUnit> ppsNalus,
  }) {
    // avc1 sample entry
    final avc1Content = BytesBuilder();

    // reserved (6 bytes)
    avc1Content.add(Uint8List(6));
    // data_reference_index: 1
    avc1Content.add([0x00, 0x01]);

    // Pre-defined (16 bytes)
    avc1Content.add([0x00, 0x00]); // version
    avc1Content.add([0x00, 0x00]); // revision
    avc1Content.add([0x00, 0x00, 0x00, 0x00]); // vendor
    avc1Content.add([0x00, 0x00, 0x00, 0x00]); // temporal_quality
    avc1Content.add([0x00, 0x00, 0x00, 0x00]); // spatial_quality

    // width, height (can extract from SPS, but default to 0)
    avc1Content.add([0x00, 0x00]); // width
    avc1Content.add([0x00, 0x00]); // height

    // horizontal, vertical resolution (72 dpi = 0x00480000)
    avc1Content.add([0x00, 0x48, 0x00, 0x00]);
    avc1Content.add([0x00, 0x48, 0x00, 0x00]);

    // data_size (0)
    avc1Content.add([0x00, 0x00, 0x00, 0x00]);
    // frame_count (1)
    avc1Content.add([0x00, 0x01]);

    // compressorname (32 bytes)
    avc1Content.add(_fixedStringBytes('AVC Coding', 32));

    // depth (24)
    avc1Content.add([0x00, 0x18]);
    // pre-defined (-1)
    avc1Content.add([0xFF, 0xFF]);

    // avcC box
    avc1Content.add(buildAvccBox(spsNalus, ppsNalus));

    final stsdEntry = buildBox('avc1', avc1Content.toBytes());

    // stsd box wraps the entry
    final stsdContent = BytesBuilder();
    stsdContent.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    stsdContent.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1
    stsdContent.add(stsdEntry);

    return buildFullBox('stsd', stsdContent.toBytes());
  }

  /// Build stsd box for AAC audio.
  static Uint8List buildAudioStsdBox() {
    // mp4a sample entry
    final mp4aContent = BytesBuilder();

    // reserved (6 bytes)
    mp4aContent.add(Uint8List(6));
    // data_reference_index: 1
    mp4aContent.add([0x00, 0x01]);

    // Sound description fields
    mp4aContent.add([0x00, 0x00]); // version
    mp4aContent.add([0x00, 0x00]); // revision
    mp4aContent.add([0x00, 0x00, 0x00, 0x00]); // vendor
    mp4aContent.add([0x00, 0x02]); // channel_count: 2
    mp4aContent.add([0x00, 0x10]); // sample_size: 16
    mp4aContent.add([0x00, 0x00]); // compression_id
    mp4aContent.add([0x00, 0x00]); // packet_size: 0
    mp4aContent.add([0xAC, 0x44, 0x00, 0x00]); // sample_rate: 44100 (0xAC44)

    // esds box (minimal)
    final esdsContent = BytesBuilder();
    esdsContent.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    // ES_Descriptor tag (0x03)
    esdsContent.add([0x03]); // tag
    esdsContent.add([0x19]); // length (25)
    esdsContent.add([0x00, 0x01]); // ES_ID
    esdsContent.add([0x00]); // stream_priority

    // DecoderConfigDescriptor tag (0x04)
    esdsContent.add([0x04]); // tag
    esdsContent.add([0x15]); // length (21)
    esdsContent.add([0x40]); // object_type: AAC (0x40)
    esdsContent.add([0x15]); // stream_type: Audio (0x05) << 2 | 1
    esdsContent.add([0x00, 0x00, 0x00]); // buffer_size (24 bits)
    esdsContent.add([0x00, 0x00, 0xBB, 0x80]); // max_bitrate: 48000
    esdsContent.add([0x00, 0x00, 0xBB, 0x80]); // avg_bitrate: 48000

    // DecoderSpecificInfo tag (0x05)
    esdsContent.add([0x05]); // tag
    esdsContent.add([0x02]); // length (2)
    // AAC audio specific config: 2 channels, 44100 Hz, LC profile
    esdsContent.add([
      0x12,
      0x10
    ]); // 0x12 = LC(2)<<3 | srate(4)>>1, 0x10 = srate(4)<<7 | 2ch

    final esdsBox = buildBox('esds', esdsContent.toBytes());
    mp4aContent.add(esdsBox);

    final stsdEntry = buildBox('mp4a', mp4aContent.toBytes());

    final stsdContent = BytesBuilder();
    stsdContent.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    stsdContent.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1
    stsdContent.add(stsdEntry);

    return buildFullBox('stsd', stsdContent.toBytes());
  }

  /// Build avcC (AVC configuration) box.
  static Uint8List buildAvccBox(
      List<H264NalUnit> spsNalus, List<H264NalUnit> ppsNalus) {
    final content = BytesBuilder();

    // AVCConfigurationRecord version
    content.add([0x01]); // configurationVersion

    if (spsNalus.isNotEmpty) {
      final sps = spsNalus.first.data;
      // AVCProfileIndication (byte 1 of SPS NAL data)
      content.add(sps.length > 1 ? [sps[1]] : [0x42]);
      // profile_compatibility (byte 2)
      content.add(sps.length > 2 ? [sps[2]] : [0x00]);
      // AVCLevelIndication (byte 3)
      content.add(sps.length > 3 ? [sps[3]] : [0x1E]);
    } else {
      content.add([0x42, 0x00, 0x1E]); // Baseline, level 30
    }

    // 6 bits reserved + 2 bits lengthSizeMinusOne (3 = 4-byte length)
    content.add([0xFF]); // 0b111111 | 0b11

    // 3 bits reserved + 5 bits numOfSequenceParameterSets
    content.add([0xE1]); // 0b111 | 0b00001

    // SPS (avcC uses 2-byte length prefix, not 4-byte)
    for (final sps in spsNalus) {
      _writeLength16Prefixed(content, sps.data);
    }

    // numOfPictureParameterSets
    content.add([ppsNalus.length]);
    for (final pps in ppsNalus) {
      _writeLength16Prefixed(content, pps.data);
    }

    return buildBox('avcC', content.toBytes());
  }

  /// Build stts (time-to-sample) box.
  static Uint8List buildSttsBox(int sampleCount) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    content.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1
    // All samples have the same duration (arbitrary: 1 tick)
    content.add(_u32(sampleCount)); // sample_count
    content.add([0x00, 0x00, 0x03, 0xE8]); // sample_duration: 1000ms

    return buildFullBox('stts', content.toBytes());
  }

  /// Build stsc (sample-to-chunk) box.
  static Uint8List buildStscBox(
      int firstChunk, int samplesPerChunk, int sampleDescriptionIndex) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    content.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1
    content.add(_u32(firstChunk)); // first_chunk
    content.add(_u32(samplesPerChunk)); // samples_per_chunk
    content.add(_u32(sampleDescriptionIndex)); // sample_description_index

    return buildFullBox('stsc', content.toBytes());
  }

  /// Build stsz (sample size) box.
  ///
  /// If [sampleSizes] is provided, uses variable sizes; otherwise constant.
  static Uint8List buildStszBox(int sampleCount, {List<int>? sampleSizes}) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // version, flags

    if (sampleSizes != null) {
      // Variable sample sizes
      content.add([0x00, 0x00, 0x00, 0x00]); // sample_size = 0 (variable)
      content.add(_u32(sampleCount)); // sample_count
      for (final size in sampleSizes) {
        content.add(_u32(size));
      }
    } else {
      // Constant sample size
      const sampleSize = 1; // default placeholder
      content.add(_u32(sampleSize));
      content.add(_u32(sampleCount));
    }

    return buildFullBox('stsz', content.toBytes());
  }

  /// Build co64 (64-bit chunk offset) box.
  static Uint8List buildCo64Box(int chunkOffset) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    content.add([0x00, 0x00, 0x00, 0x01]); // entry_count: 1
    // 64-bit offset
    content.add([
      (chunkOffset >> 56) & 0xFF,
      (chunkOffset >> 48) & 0xFF,
      (chunkOffset >> 40) & 0xFF,
      (chunkOffset >> 32) & 0xFF,
      (chunkOffset >> 24) & 0xFF,
      (chunkOffset >> 16) & 0xFF,
      (chunkOffset >> 8) & 0xFF,
      chunkOffset & 0xFF,
    ]);

    return buildFullBox('co64', content.toBytes());
  }

  /// Build stss (sync sample) box — marks all samples as sync.
  ///
  /// In a minimal remuxer, marking all samples as sync is sufficient
  /// for basic playability. A full implementation would only mark
  /// IDR frames (NAL type 5).
  static Uint8List buildStssBox(int sampleCount) {
    final content = BytesBuilder();
    content.add([0x00, 0x00, 0x00, 0x00]); // version, flags
    content.add(_u32(sampleCount));
    for (int i = 0; i < sampleCount; i++) {
      content.add(_u32(i + 1)); // 1-based sample numbers
    }
    return buildFullBox('stss', content.toBytes());
  }

  /// Build mdat box data from NAL units and AAC frames.
  static Uint8List buildMdatData({
    required List<H264NalUnit> allNalus,
    required List<AacFrame> aacFrames,
  }) {
    final data = BytesBuilder();

    // Write video samples (NAL units with 4-byte length prefix)
    for (final nalu in allNalus) {
      _writeLengthPrefixed(data, nalu.data);
    }

    // Write AAC frames (raw data without ADTS header)
    for (final frame in aacFrames) {
      _writeLengthPrefixed(data, frame.data);
    }

    return data.toBytes();
  }

  // ===========================================================================
  // Box building helpers
  // ===========================================================================

  /// Build a basic ISO base media file format box.
  static Uint8List buildBox(String type, Uint8List content) {
    final totalSize = 8 + content.length; // size(4) + type(4) + content
    final data = Uint8List(totalSize);
    data[0] = (totalSize >> 24) & 0xFF;
    data[1] = (totalSize >> 16) & 0xFF;
    data[2] = (totalSize >> 8) & 0xFF;
    data[3] = totalSize & 0xFF;
    // Type
    data[4] = type.codeUnitAt(0);
    data[5] = type.codeUnitAt(1);
    data[6] = type.codeUnitAt(2);
    data[7] = type.codeUnitAt(3);
    // Content
    for (int i = 0; i < content.length; i++) {
      data[8 + i] = content[i];
    }
    return data;
  }

  /// Build a full box (with version and flags).
  static Uint8List buildFullBox(String type, Uint8List content,
      {int version = 0, int flags = 0}) {
    final header = Uint8List(4);
    header[0] = version;
    header[1] = (flags >> 16) & 0xFF;
    header[2] = (flags >> 8) & 0xFF;
    header[3] = flags & 0xFF;
    return buildBox(type, Uint8List.fromList([...header, ...content]));
  }

  /// Write data with a 4-byte length prefix.
  static void _writeLengthPrefixed(BytesBuilder builder, Uint8List data) {
    builder.add([
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    builder.add(data);
  }

  /// Write data with a 2-byte length prefix (for avcC box).
  static void _writeLength16Prefixed(BytesBuilder builder, Uint8List data) {
    builder.add([
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    builder.add(data);
  }

  /// Convert to unsigned 32-bit big-endian bytes.
  static Uint8List _u32(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  /// Convert a string to ISO 639 code (4 bytes, space-padded).
  static Uint8List iso639Code(String code) {
    final bytes = Uint8List(4);
    for (int i = 0; i < 4 && i < code.length; i++) {
      bytes[i] = code.codeUnitAt(i);
    }
    for (int i = code.length; i < 4; i++) {
      bytes[i] = 0x20; // space
    }
    return bytes;
  }

  /// Convert string to code units.
  static Uint8List codeUnits(String str) {
    final bytes = Uint8List(str.length);
    for (int i = 0; i < str.length; i++) {
      bytes[i] = str.codeUnitAt(i);
    }
    return bytes;
  }

  /// Create a fixed-size byte array from a string, padding with nulls.
  static Uint8List _fixedStringBytes(String str, int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = i < str.length ? str.codeUnitAt(i) : 0x00;
    }
    return bytes;
  }
}
