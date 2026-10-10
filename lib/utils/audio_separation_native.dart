import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:dio/dio.dart' show CancelToken;
import 'audio_utils.dart' show pcmToWav;

/// Synchronous audio extraction for use with [Isolate.run].
/// Extracts audio from MP4 video bytes without blocking the main isolate.
/// Returns the extracted audio bytes (WAV for PCM, ADTS-wrapped AAC).
///
/// This must be a top-level function (not a method) so it can be sent to
/// a background isolate via Isolate.run.
Uint8List extractAudioSync({
  required Uint8List videoBytes,
  required String videoFormat,
}) {
  if (videoBytes.isEmpty) {
    throw Exception('Video data is empty');
  }
  if (!AudioSeparationEngine._supportedFormats
      .contains(videoFormat.toLowerCase().trim())) {
    throw Exception('Unsupported video format: $videoFormat');
  }

  // Step 1: Parse MP4 container and find audio track
  final mp4 = _Mp4Demuxer(videoBytes);
  final audioTrack = mp4.findAudioTrack();
  if (audioTrack == null) {
    throw Exception('No audio track found in video');
  }

  // Step 2: Extract audio sample data
  final frames = mp4.extractAudioFrames(audioTrack);
  if (frames.isEmpty) {
    throw Exception('No audio data extracted');
  }

  // Step 3: Package into playable format
  final engine = AudioSeparationEngine();
  return engine._packageFrames(frames, audioTrack);
}

/// Pure-Dart MP4/ISOBMFF audio extraction engine.
///
/// Parses MP4/MOV/M4V/3GP container format and extracts the audio track.
/// Supports AAC and PCM audio codecs commonly found in MP4 containers.
/// - PCM audio: output as WAV format
/// - AAC audio: output as ADTS-wrapped AAC (playable by all major players)
///
/// This is a Dart port of FFmpeg's audio demuxing approach:
/// 1. Parse container (ffmpeg: avformat_open_input)
/// 2. Find audio stream (ffmpeg: av_find_best_stream)
/// 3. Read audio packets (ffmpeg: av_read_frame)
/// 4. Output as playable audio file
class AudioSeparationEngine {
  /// Always available — pure Dart implementation with no platform dependencies.
  Future<bool> isAvailable() async => true;

  /// Supported video formats (ISOBMFF-based containers).
  static const _supportedFormats = ['mp4', 'mov', 'm4v', '3gp'];

  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedFormats.contains(format.toLowerCase().trim());
  }

  /// Extract audio from a video file.
  ///
  /// [videoBytes] must contain a valid ISOBMFF container (MP4/MOV).
  /// Returns audio bytes. For PCM tracks, returns WAV format data.
  /// For AAC tracks, returns ADTS-wrapped AAC frames.
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (videoBytes.isEmpty) {
      throw Exception('Video data is empty');
    }
    if (!canHandleVideoFormat(videoFormat)) {
      throw Exception('Unsupported video format: $videoFormat');
    }

    onProgress?.call(0);

    // Step 1: Parse MP4 container and find audio track
    final mp4 = _Mp4Demuxer(videoBytes);
    final audioTrack = mp4.findAudioTrack();
    if (audioTrack == null) {
      throw Exception('No audio track found in video');
    }

    onProgress?.call(30);

    // Step 2: Extract audio sample data as individual frames with their sizes
    final frames = mp4.extractAudioFrames(audioTrack);
    if (frames.isEmpty) {
      throw Exception('No audio data extracted');
    }

    onProgress?.call(60);

    // Step 3: Package into playable format
    final result = _packageFrames(frames, audioTrack);
    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Audio extraction was cancelled');
    }

    onProgress?.call(100);
    return result;
  }

  /// Package audio frames into a playable format.
  /// For PCM, wrap in WAV. For AAC, wrap in a valid M4A (MP4 container).
  Uint8List _packageFrames(List<_AudioFrame> frames, _AudioTrackInfo track) {
    if (track.codec == 'raw ' ||
        track.codec == 'twos' ||
        track.codec == 'sowt') {
      // PCM audio — concatenate frames and wrap in WAV
      final concatenated = BytesBuilder();
      for (final frame in frames) {
        concatenated.add(frame.data);
      }
      final pcmBytes = concatenated.toBytes();
      final bitsPerSample = track.bitsPerSample > 0 ? track.bitsPerSample : 16;
      if (bitsPerSample == 8 &&
          (track.codec == 'twos' || track.codec == 'sowt')) {
        // QuickTime stores these PCM samples as signed; 8-bit WAV PCM is
        // unsigned, so shift the sample range before writing the WAV.
        for (var i = 0; i < pcmBytes.length; i++) {
          pcmBytes[i] = pcmBytes[i] ^ 0x80;
        }
      } else if (track.codec == 'twos') {
        // QuickTime 'twos' PCM stores each sample big-endian; WAV PCM is
        // little-endian, so reverse the bytes within each sample.
        final bytesPerSample = (bitsPerSample + 7) ~/ 8;
        for (var sampleOffset = 0;
            sampleOffset + bytesPerSample <= pcmBytes.length;
            sampleOffset += bytesPerSample) {
          for (var left = 0; left < bytesPerSample ~/ 2; left++) {
            final right = bytesPerSample - 1 - left;
            final tmp = pcmBytes[sampleOffset + left];
            pcmBytes[sampleOffset + left] = pcmBytes[sampleOffset + right];
            pcmBytes[sampleOffset + right] = tmp;
          }
        }
      }
      final sampleRate = track.sampleRate > 0 ? track.sampleRate : 44100;
      return pcmToWav(
        pcmBytes,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        numChannels: track.channels > 0 ? track.channels : 2,
      );
    }

    // AAC — wrap raw frames in a valid M4A (MP4) container so the output
    // is accepted by Whisper ASR APIs (which require m4a, not raw ADTS AAC).
    return _createM4aFromAacFrames(frames, track);
  }

  // ==================================================================
  // M4A (MP4 container) muxer for AAC audio
  // ==================================================================

  /// Wrap raw AAC frames in a minimal valid M4A (MP4) container.
  ///
  /// Produces a standard ISOBMFF file with ftyp + moov + mdat boxes.
  /// The resulting bytes form a valid .m4a file playable by all major
  /// players and accepted by Whisper ASR APIs.
  Uint8List _createM4aFromAacFrames(
      List<_AudioFrame> frames, _AudioTrackInfo track) {
    final sampleRate = track.sampleRate > 0 ? track.sampleRate : 44100;
    final channels = track.channels > 0 ? track.channels : 2;
    final sampleCount = frames.length;

    // ---------- AAC configuration ----------
    const freqMap = {
      96000: 0,
      88200: 1,
      64000: 2,
      48000: 3,
      44100: 4,
      32000: 5,
      24000: 6,
      22050: 7,
      16000: 8,
      12000: 9,
      11025: 10,
      8000: 11,
      7350: 12,
    };
    final freqIdx = freqMap[sampleRate] ?? 4;
    final chanCfg = channels > 6 ? 6 : channels;
    const audioObjectType = 2; // AAC-LC

    // Prefer the source configuration so profiles such as HE-AAC/SBR and
    // non-default AAC frame lengths survive the remux.
    final asc = track.audioSpecificConfig ??
        Uint8List.fromList([
          (audioObjectType << 3) | (freqIdx >> 1),
          ((freqIdx & 1) << 7) | (chanCfg << 3),
        ]);

    // ---------- Compute frame info ----------
    int totalDataSize = 0;
    final sampleSizes = <int>[];
    for (final frame in frames) {
      final s = frame.data.length;
      sampleSizes.add(s);
      totalDataSize += s;
    }

    // ---------- Pre-compute box sizes ----------
    final samplesPerFrame = _samplesPerAacFrame(asc, sampleRate);
    final duration = sampleCount * samplesPerFrame;

    // stsd entry size: mp4a base (36) + esds box
    final esdsSize = _esdsBoxSize(asc);
    final stsdEntrySize = 36 + esdsSize;
    final stsdSize =
        16 + stsdEntrySize; // header(8)+ver/flags(4)+entryCount(4)+entry
    const sttsSize = 24; // header + 1 entry
    const stscSize = 28; // header + 1 entry
    final stszSize = 20 + sampleCount * 4; // header + per-sample sizes
    const stcoSize = 20; // header + 1 chunk offset
    // each level below includes +8 for its own box header
    final stblSize = 8 + stsdSize + sttsSize + stscSize + stszSize + stcoSize;

    const smhdSize = 16;
    const dinfSize = 36; // danf header(8) + dref(28)
    final minfSize = 8 + smhdSize + dinfSize + stblSize;

    const mdhdSize = 32;
    const hdlrSize = 33;
    final mdiaSize = 8 + mdhdSize + hdlrSize + minfSize;

    const tkhdSize = 92;
    final trakSize = 8 + tkhdSize + mdiaSize;

    const mvhdSize = 108;
    final moovSize = 8 + mvhdSize + trakSize;

    // ftyp: header(8) + major(4) + minor(4) + 3 compatible brands(12) = 28
    const ftypSize = 28;
    final mdatSize = 8 + totalDataSize;

    // File layout: ftyp | moov | mdat
    final moovOffset = ftypSize;
    final mdatOffset = moovOffset + moovSize;
    final mdatDataOffset = mdatOffset + 8; // skip mdat box header

    // ---------- Build file ----------
    final buf = BytesBuilder();

    // ---- ftyp ----
    _writeBoxHeader(buf, ftypSize, 'ftyp');
    _writeCString(buf, 'M4A '); // major brand
    _writeU32be(buf, 0x00000200); // minor version
    _writeCString(buf, 'M4A '); // compatible brand
    _writeCString(buf, 'mp42');
    _writeCString(buf, 'isom');

    // ---- moov ----
    _writeBoxHeader(buf, moovSize, 'moov');

    // mvhd
    _writeBoxHeader(buf, mvhdSize, 'mvhd');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 0); // creation_time
    _writeU32be(buf, 0); // modification_time
    _writeU32be(buf, sampleRate); // timescale
    _writeU32be(buf, duration); // duration
    _writeU32be(buf, 0x00010000); // rate (1.0 fixed-point)
    _writeU16be(buf, 0x0100); // volume (1.0)
    _writeBytes(buf, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]); // reserved(10)
    // matrix (identity)
    for (final v in [0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000]) {
      _writeU32be(buf, v);
    }
    // pre-defined (6 x 4 bytes)
    for (var i = 0; i < 6; i++) {
      _writeU32be(buf, 0);
    }
    _writeU32be(buf, 2); // next_track_id

    // trak
    _writeBoxHeader(buf, trakSize, 'trak');

    // tkhd
    _writeBoxHeader(buf, tkhdSize, 'tkhd');
    _writeU32be(buf, 0x00000007); // version=0, flags=0x000007 (enabled)
    _writeU32be(buf, 0); // creation_time
    _writeU32be(buf, 0); // modification_time
    _writeU32be(buf, 1); // track_id
    _writeU32be(buf, 0); // reserved
    _writeU32be(buf, duration); // duration
    _writeBytes(buf, [0, 0, 0, 0, 0, 0, 0, 0]); // reserved(8)
    _writeU16be(buf, 0); // layer
    _writeU16be(buf, 0); // alternate_group
    _writeU16be(buf, 0x0100); // volume (1.0)
    _writeU16be(buf, 0); // reserved
    // matrix (identity)
    for (final v in [0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000]) {
      _writeU32be(buf, v);
    }
    _writeU32be(buf, 0); // width
    _writeU32be(buf, 0); // height

    // mdia
    _writeBoxHeader(buf, mdiaSize, 'mdia');

    // mdhd
    _writeBoxHeader(buf, mdhdSize, 'mdhd');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 0); // creation_time
    _writeU32be(buf, 0); // modification_time
    _writeU32be(buf, sampleRate); // timescale
    _writeU32be(buf, duration); // duration
    _writeU16be(buf, 0x55C4); // language code (und)
    _writeU16be(buf, 0); // quality

    // hdlr
    _writeBoxHeader(buf, hdlrSize, 'hdlr');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 0); // pre_defined
    _writeCString(buf, 'soun'); // handler_type
    _writeU32be(buf, 0); // reserved
    _writeU32be(buf, 0); // reserved
    _writeU32be(buf, 0); // reserved
    _writeBytes(buf, [0]); // null name terminator

    // minf
    _writeBoxHeader(buf, minfSize, 'minf');

    // smhd
    _writeBoxHeader(buf, smhdSize, 'smhd');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU16be(buf, 0); // balance
    _writeU16be(buf, 0); // reserved

    // dinf
    _writeBoxHeader(buf, dinfSize, 'dinf');

    // dref
    _writeBoxHeader(buf, dinfSize - 8, 'dref');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 1); // entry_count
    // url box (self-contained)
    _writeBoxHeader(buf, 12, 'url ');
    _writeU32be(buf, 0x00000001); // version=0, flags=0x000001 (self-contained)

    // stbl
    _writeBoxHeader(buf, stblSize, 'stbl');

    // stsd
    _writeBoxHeader(buf, stsdSize, 'stsd');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 1); // entry_count = 1

    // SampleEntry: mp4a
    _writeU32be(buf, stsdEntrySize); // entry_size
    _writeCString(buf, 'mp4a'); // codec
    _writeBytes(buf, [0, 0, 0, 0, 0, 0]); // reserved(6)
    _writeU16be(buf, 1); // data_reference_index
    _writeBytes(buf, [0, 0, 0, 0, 0, 0, 0, 0]); // reserved(8)
    _writeU16be(buf, channels); // channel count
    _writeU16be(buf, 16); // sample size
    _writeU16be(buf, 0); // pre-defined
    _writeU16be(buf, 0); // reserved
    _writeU32be(buf, sampleRate << 16); // sample rate (16.16 fixed-point)

    // esds box inside stsd
    _writeEsdsBox(buf, asc);

    // stts
    _writeBoxHeader(buf, sttsSize, 'stts');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 1); // entry_count
    _writeU32be(buf, sampleCount); // sample_count
    _writeU32be(buf, samplesPerFrame); // sample_duration

    // stsc
    _writeBoxHeader(buf, stscSize, 'stsc');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 1); // entry_count
    _writeU32be(buf, 1); // first_chunk
    _writeU32be(buf, sampleCount); // samples_per_chunk
    _writeU32be(buf, 1); // sample_description_index

    // stsz
    _writeBoxHeader(buf, stszSize, 'stsz');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 0); // sample_size (0 = non-constant)
    _writeU32be(buf, sampleCount);
    for (final s in sampleSizes) {
      _writeU32be(buf, s);
    }

    // stco
    _writeBoxHeader(buf, stcoSize, 'stco');
    _writeU32be(buf, 0); // version=0, flags=0
    _writeU32be(buf, 1); // entry_count
    _writeU32be(buf, mdatDataOffset); // chunk_offset

    // ---- mdat ----
    _writeBoxHeader(buf, mdatSize, 'mdat');
    for (final frame in frames) {
      buf.add(frame.data);
    }

    return buf.toBytes();
  }

  // ==================================================================
  // esds box builder
  // ==================================================================

  /// Compute the total size of an esds box containing the given ASC.
  static int _esdsBoxSize(Uint8List asc) {
    // DecoderSpecificInfo: tag(1) + length + asc(N)
    final dsiTotal = 1 + _descriptorLengthSize(asc.length) + asc.length;
    // DecoderConfigDescriptor body: objType(1) + streamType(1) + bufSize(3) +
    //   maxBR(4) + avgBR(4) + DSI_total
    final decConfigBody = 13 + dsiTotal;
    // DecoderConfigDescriptor total: tag(1) + length + body
    final decConfigTotal =
        1 + _descriptorLengthSize(decConfigBody) + decConfigBody;
    // SLConfigDescriptor total: tag(1) + length(1) + predef(1)
    const slConfigTotal = 3;
    // ES_Descriptor body: ES_ID(2) + flags(1) + DecConfig + SLConfig
    final esBody = 3 + decConfigTotal + slConfigTotal;
    // esds box: header(8) + ver/flags(4) + ES tag and variable length + body
    return 12 + 1 + _descriptorLengthSize(esBody) + esBody;
  }

  /// Write a complete esds box with AudioSpecificConfig.
  static void _writeEsdsBox(BytesBuilder buf, Uint8List asc) {
    final size = _esdsBoxSize(asc);
    _writeBoxHeader(buf, size, 'esds');
    _writeU32be(buf, 0); // version=0, flags=0

    // ES_Descriptor (tag 0x03)
    buf.addByte(0x03);
    _writeDescLength(buf, _esdsDescriptorBodyLength(asc));
    _writeU16be(buf, 0); // ES_ID
    buf.addByte(0x00); // flags

    // DecoderConfigDescriptor (tag 0x04)
    buf.addByte(0x04);
    final dsiTotal = 1 + _descriptorLengthSize(asc.length) + asc.length;
    final decConfigBody = 13 + dsiTotal;
    _writeDescLength(buf, decConfigBody);
    buf.addByte(0x40); // objectTypeIndication (Audio ISO/IEC 14496-3)
    buf.addByte(0x15); // streamType (Audio) + bufferSizeDB flag
    _writeBytes(buf, [0, 0, 0]); // bufferSizeDB
    _writeU32be(buf, 0); // maxBitrate
    _writeU32be(buf, 0); // avgBitrate

    // DecoderSpecificInfo (tag 0x05)
    buf.addByte(0x05);
    _writeDescLength(buf, asc.length);
    buf.add(asc);

    // SLConfigDescriptor (tag 0x06)
    buf.addByte(0x06);
    _writeDescLength(buf, 1);
    buf.addByte(0x02); // predef = 2
  }

  /// Compute the length of the ES_Descriptor body (for the length field).
  static int _esdsDescriptorBodyLength(Uint8List asc) {
    final dsiTotal = 1 + _descriptorLengthSize(asc.length) + asc.length;
    final decConfigBody = 13 + dsiTotal;
    final decConfigTotal =
        1 + _descriptorLengthSize(decConfigBody) + decConfigBody;
    return 3 + decConfigTotal + 3;
  }

  // ==================================================================
  // ISOBMFF binary write helpers
  // ==================================================================

  /// Write an 8-byte ISOBMFF box header.
  static void _writeBoxHeader(BytesBuilder buf, int size, String type) {
    _writeU32be(buf, size);
    _writeCString(buf, type);
  }

  /// Write a 4-character code.
  static void _writeCString(BytesBuilder buf, String s) {
    buf.add(s.codeUnits.map((c) => c.toInt()).toList());
  }

  /// Write a 32-bit big-endian integer.
  static void _writeU32be(BytesBuilder buf, int v) {
    buf.addByte((v >> 24) & 0xFF);
    buf.addByte((v >> 16) & 0xFF);
    buf.addByte((v >> 8) & 0xFF);
    buf.addByte(v & 0xFF);
  }

  /// Write a 16-bit big-endian integer.
  static void _writeU16be(BytesBuilder buf, int v) {
    buf.addByte((v >> 8) & 0xFF);
    buf.addByte(v & 0xFF);
  }

  /// Write raw bytes.
  static void _writeBytes(BytesBuilder buf, List<int> bytes) {
    buf.add(Uint8List.fromList(bytes));
  }

  /// Number of bytes used by an MPEG-4 descriptor's 7-bit length field.
  static int _descriptorLengthSize(int length) {
    if (length < 0 || length > 0x0FFFFFFF) {
      throw RangeError('MPEG-4 descriptor length is outside its 28-bit range.');
    }
    var size = 1;
    while (length > 0x7F) {
      size++;
      length >>= 7;
    }
    return size;
  }

  /// Write an MPEG-4 descriptor length as big-endian 7-bit groups.
  static void _writeDescLength(BytesBuilder buf, int length) {
    final size = _descriptorLengthSize(length);
    for (var index = size - 1; index >= 0; index--) {
      final byte = (length >> (index * 7)) & 0x7F;
      buf.addByte(byte | (index > 0 ? 0x80 : 0));
    }
  }

  // ==================================================================
  // Legacy ADTS output (kept for reference)
  // ==================================================================

  /// Add ADTS headers to individual AAC frames using actual frame sizes.
  ///
  /// Note: This outputs raw ADTS AAC which is NOT accepted by Whisper ASR
  /// APIs. Use the M4A container output from [_createM4aFromAacFrames]
  /// instead for API compatibility.
  @visibleForTesting
  Uint8List _addAdtsHeadersToFrames(
      List<_AudioFrame> frames, _AudioTrackInfo track) {
    const freqMap = {
      96000: 0,
      88200: 1,
      64000: 2,
      48000: 3,
      44100: 4,
      32000: 5,
      24000: 6,
      22050: 7,
      16000: 8,
      12000: 9,
      11025: 10,
      8000: 11,
      7350: 12,
    };
    final sampleRate = track.sampleRate > 0 ? track.sampleRate : 44100;
    final freqIdx = freqMap[sampleRate] ?? 4;
    final channels = track.channels > 0 ? track.channels : 2;
    final chanConfig = channels > 6 ? 6 : channels;
    const profile = 2; // AAC-LC

    final result = BytesBuilder();

    for (final frame in frames) {
      final dataLen = frame.data.length;
      final adtsHeaderLen = 7;
      final fullLen = adtsHeaderLen + dataLen;

      // ADTS fixed header (7 bytes)
      result.addByte(0xFF); // Sync word byte 1
      result.addByte(
          0xF1); // Sync word byte 2: MPEG-4, layer 0, protection absent
      // profile (2 bits), sampling_frequency_index (4 bits), channel_configuration (2 bits high)
      result.addByte(((profile - 1) << 6) | (freqIdx << 2) | (chanConfig >> 2));
      // channel_configuration low 2 bits + frame_length high 2 bits
      result.addByte(((chanConfig & 0x03) << 6) | ((fullLen >> 11) & 0x03));
      // frame_length middle 8 bits
      result.addByte((fullLen >> 3) & 0xFF);
      // frame_length low 3 bits + buffer fullness (2 bits) + number_of_raw_data_blocks (2 bits)
      result.addByte(((fullLen & 0x07) << 5) | 0x1F);
      result.addByte(0xFC);

      // AAC frame data
      result.add(frame.data);
    }

    return result.toBytes();
  }
}

// ============================================================================
// MP4/ISOBMFF Demuxer — Pure Dart implementation
// ============================================================================

/// A single audio frame extracted from the MP4 file.
class _AudioFrame {
  final Uint8List data;
  _AudioFrame(this.data);
}

/// Information about an audio track in the MP4 file.
class _AudioTrackInfo {
  final int trackId;
  final String codec; // 'mp4a' (AAC), 'raw ' (PCM), etc.
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Uint8List? audioSpecificConfig;
  final int sampleCount;
  final List<int> sampleSizes; // size of each sample
  final List<int>
      chunkOffsets; // absolute file offset of each chunk (from stco/co64)
  final List<int> sampleToChunkMap; // samples per chunk for each chunk index

  _AudioTrackInfo({
    required this.trackId,
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.audioSpecificConfig,
    required this.sampleCount,
    required this.sampleSizes,
    required this.chunkOffsets,
    required this.sampleToChunkMap,
  });
}

/// Type for an stsc entry: (firstChunk, samplesPerChunk)
typedef _StscEntry = (int, int, int);

class _AudioSampleDescription {
  final String codec;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Uint8List? audioSpecificConfig;

  const _AudioSampleDescription({
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.audioSpecificConfig,
  });

  bool hasSameOutputFormat(_AudioSampleDescription other) {
    if (codec != other.codec ||
        sampleRate != other.sampleRate ||
        channels != other.channels ||
        bitsPerSample != other.bitsPerSample) {
      return false;
    }
    final asc = audioSpecificConfig;
    final otherAsc = other.audioSpecificConfig;
    if (asc == null || otherAsc == null) return asc == otherAsc;
    if (asc.length != otherAsc.length) return false;
    for (var i = 0; i < asc.length; i++) {
      if (asc[i] != otherAsc[i]) return false;
    }
    return true;
  }
}

class _Mp4aDecoderConfig {
  final int objectTypeIndication;
  final Uint8List? audioSpecificConfig;

  const _Mp4aDecoderConfig({
    required this.objectTypeIndication,
    required this.audioSpecificConfig,
  });
}

/// Pure-Dart MP4/ISOBMFF container parser.
class _Mp4Demuxer {
  // MPEG-4 Audio and MPEG-2 AAC Main, LC, and SSR are supported.
  static const _aacObjectTypeIndications = {0x40, 0x66, 0x67, 0x68};

  final Uint8List _data;
  int _offset = 0;

  _Mp4Demuxer(this._data);

  /// Find the first audio track in the MP4 file.
  _AudioTrackInfo? findAudioTrack() {
    try {
      _offset = 0;

      int moovOffset = -1;
      int mdatOffset = -1;

      while (_offset < _data.length) {
        final boxStart = _offset;
        if (_offset + 8 > _data.length) break;

        var boxSize = _readUint32();
        final boxType = _readString(4);
        if (boxSize == 1) {
          if (_offset + 8 > _data.length) break;
          boxSize = _readUint64();
        }

        if (boxType == 'moov') {
          moovOffset = boxStart;
        } else if (boxType == 'mdat') {
          mdatOffset = boxStart;
        }

        if (boxSize == 0) break;
        _offset = boxStart + boxSize;
      }

      if (moovOffset < 0 || mdatOffset < 0) return null;

      _offset = moovOffset + 8;
      final moovEnd = moovOffset + _boxSizeAt(moovOffset);

      _AudioTrackInfo? audioTrack;

      while (_offset < moovEnd) {
        final childStart = _offset;
        if (_offset + 8 > _data.length) break;

        _readUint32(); // size
        final childType = _readString(4);

        if (childType == 'trak') {
          final trackInfo = _parseTrack();
          if (trackInfo != null) {
            if (trackInfo.codec == 'mp4a' ||
                trackInfo.codec == 'raw ' ||
                trackInfo.codec == 'twos' ||
                trackInfo.codec == 'sowt') {
              audioTrack ??= trackInfo;
            }
          }
          _offset = childStart + _boxSizeAt(childStart);
        } else {
          _offset = childStart + _boxSizeAt(childStart);
        }
      }

      return audioTrack;
    } catch (e) {
      debugPrint('[Mp4Demuxer] parse error: $e');
      return null;
    }
  }

  /// Parse a single trak box.
  _AudioTrackInfo? _parseTrack() {
    final trackStart = _offset;
    final trackSize = _boxSizeAt(trackStart - 8);
    final trackEnd = trackStart + trackSize - 8;

    int trackId = 0;
    String? handlerType;
    String? codec;
    int sampleRate = 0;
    int channels = 0;
    int bitsPerSample = 16;
    Uint8List? audioSpecificConfig;
    final sampleDescriptions = <_AudioSampleDescription?>[];
    int sampleCount = 0;
    List<int> sampleSizes = [];
    List<int> chunkOffsets = [];
    final stscEntries = <_StscEntry>[];

    while (_offset < trackEnd) {
      final childStart = _offset;
      if (_offset + 8 > _data.length) break;

      final childSize = _readUint32();
      final childType = _readString(4);

      if (childType == 'tkhd') {
        _offset += 4; // version(1) + flags(3)
        _offset += 4; // creation time
        _offset += 4; // modification time
        trackId = _readUint32();
        _offset = childStart + childSize;
      } else if (childType == 'mdia') {
        final mdiaEnd = childStart + childSize;

        while (_offset < mdiaEnd) {
          final mcStart = _offset;
          final mcSize = _readUint32();
          final mcType = _readString(4);

          if (mcType == 'hdlr') {
            _offset += 4; // version + flags
            _offset += 4; // component type
            handlerType = _readString(4);
            _offset = mcStart + mcSize;
          } else if (mcType == 'minf') {
            final minfEnd = mcStart + mcSize;

            while (_offset < minfEnd) {
              final icStart = _offset;
              final icSize = _readUint32();
              final icType = _readString(4);

              if (icType == 'stbl') {
                final stblEnd = icStart + icSize;

                while (_offset < stblEnd) {
                  if (_offset + 8 > _data.length) return null;
                  final scStart = _offset;
                  _readUint32(); // box size (advances offset)
                  final scType = _readString(4);

                  if (scType == 'stsd') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final es = _offset;
                      final entrySize = _readUint32();
                      final entryCodec = _readString(4);
                      _offset += 6; // reserved
                      _offset += 2; // data reference index
                      if (entryCodec == 'mp4a' ||
                          entryCodec == 'raw ' ||
                          entryCodec == 'twos' ||
                          entryCodec == 'sowt') {
                        final audioSampleEntryVersion = _readUint16();
                        _offset += 2; // revision level
                        _offset += 4; // vendor
                        var entryChannels = _readUint16();
                        final entryBitsPerSample = _readUint16();
                        _offset += 4; // pre-defined + reserved
                        var entrySampleRate = _readUint32() >> 16;
                        Uint8List? entryAudioSpecificConfig;
                        var supportedMp4aEntry = true;
                        if (entryCodec == 'mp4a') {
                          if (audioSampleEntryVersion == 2 &&
                              entrySize >= 72 &&
                              es + 72 <= _data.length) {
                            final sampleEntryData = ByteData.sublistView(_data);
                            final version2SampleRate =
                                sampleEntryData.getFloat64(es + 40, Endian.big);
                            final version2Channels = _uint32At(es + 48);
                            if (version2SampleRate.isFinite &&
                                version2SampleRate > 0) {
                              entrySampleRate = version2SampleRate.round();
                            }
                            if (version2Channels > 0) {
                              entryChannels = version2Channels;
                            }
                          }
                          final decoderConfig = _readMp4aDecoderConfig(
                            es,
                            entrySize,
                            audioSampleEntryVersion,
                          );
                          if (decoderConfig != null) {
                            supportedMp4aEntry =
                                _aacObjectTypeIndications.contains(
                              decoderConfig.objectTypeIndication,
                            );
                            entryAudioSpecificConfig =
                                decoderConfig.audioSpecificConfig;
                          }
                        }
                        sampleDescriptions.add(supportedMp4aEntry
                            ? _AudioSampleDescription(
                                codec: entryCodec,
                                sampleRate: entrySampleRate,
                                channels: entryChannels,
                                bitsPerSample: entryBitsPerSample,
                                audioSpecificConfig: entryAudioSpecificConfig,
                              )
                            : null);
                      } else {
                        sampleDescriptions.add(null);
                      }
                      _offset = es + _boxSizeAt(es);
                    }
                  } else if (scType == 'stts') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    int total = 0;
                    for (var i = 0; i < entryCount; i++) {
                      total += _readUint32(); // sample count
                      _offset += 4; // sample duration
                    }
                    sampleCount = total;
                  } else if (scType == 'stsc') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final firstChunk = _readUint32();
                      final spc = _readUint32();
                      final sampleDescriptionIndex = _readUint32();
                      stscEntries
                          .add((firstChunk, spc, sampleDescriptionIndex));
                    }
                  } else if (scType == 'stsz') {
                    _offset += 4; // version + flags
                    final sampleSize = _readUint32();
                    sampleCount = _readUint32();
                    if (sampleSize == 0) {
                      for (var i = 0; i < sampleCount; i++) {
                        sampleSizes.add(_readUint32());
                      }
                    } else {
                      sampleSizes = List.filled(sampleCount, sampleSize);
                    }
                  } else if (scType == 'stco') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      chunkOffsets.add(_readUint32());
                    }
                  } else if (scType == 'co64') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final high = _readUint32();
                      final low = _readUint32();
                      chunkOffsets.add((high << 32) | low);
                    }
                  } else {
                    _offset = scStart + _boxSizeAt(scStart);
                  }
                }
              } else {
                _offset = icStart + _boxSizeAt(icStart);
              }
            }
          } else {
            _offset = mcStart + _boxSizeAt(mcStart);
          }
        }
      } else {
        _offset = childStart + _boxSizeAt(childStart);
      }
    }

    if (handlerType != 'soun') return null;
    if (sampleSizes.isEmpty || chunkOffsets.isEmpty) return null;

    // Build per-chunk samples-per-chunk map from stsc entries.
    // Each stsc entry specifies: firstChunk (1-based), samplesPerChunk, and
    // the sample-description index used by those chunks.
    // The entry applies from firstChunk to the next entry's firstChunk - 1.
    final sampleToChunk = List.filled(chunkOffsets.length, 1);
    final sampleDescriptionForChunk = List.filled(chunkOffsets.length, 1);
    if (stscEntries.isNotEmpty) {
      for (var i = 0; i < stscEntries.length; i++) {
        final (firstChunk, spc, sampleDescriptionIndex) = stscEntries[i];
        final endChunk = (i + 1 < stscEntries.length)
            ? stscEntries[i + 1].$1 - 1
            : chunkOffsets.length;
        for (var c = firstChunk - 1;
            c < endChunk && c < chunkOffsets.length;
            c++) {
          sampleToChunk[c] = spc;
          sampleDescriptionForChunk[c] = sampleDescriptionIndex;
        }
      }
    }

    final usedDescriptionIndices = <int>{};
    for (var i = 0; i < sampleToChunk.length; i++) {
      if (sampleToChunk[i] > 0) {
        usedDescriptionIndices.add(sampleDescriptionForChunk[i]);
      }
    }
    if (usedDescriptionIndices.isEmpty) return null;
    final activeDescriptions = <_AudioSampleDescription>[];
    for (final index in usedDescriptionIndices) {
      if (index < 1 || index > sampleDescriptions.length) return null;
      final description = sampleDescriptions[index - 1];
      if (description == null) return null;
      activeDescriptions.add(description);
    }
    final selectedDescription = activeDescriptions.first;
    if (activeDescriptions.skip(1).any((description) =>
        !selectedDescription.hasSameOutputFormat(description))) {
      // The output muxer emits one sample description, so it cannot represent
      // chunks that use incompatible source audio descriptions.
      return null;
    }
    codec = selectedDescription.codec;
    sampleRate = selectedDescription.sampleRate;
    channels = selectedDescription.channels;
    bitsPerSample = selectedDescription.bitsPerSample;
    audioSpecificConfig = selectedDescription.audioSpecificConfig;

    return _AudioTrackInfo(
      trackId: trackId,
      codec: codec,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      audioSpecificConfig: audioSpecificConfig,
      sampleCount: sampleCount,
      sampleSizes: sampleSizes,
      chunkOffsets: chunkOffsets,
      sampleToChunkMap: sampleToChunk,
    );
  }

  _Mp4aDecoderConfig? _readMp4aDecoderConfig(
      int entryStart, int entrySize, int audioSampleEntryVersion) {
    if (entrySize < 36 || entryStart + entrySize > _data.length) return null;
    final entryEnd = entryStart + entrySize;
    final childOffset = switch (audioSampleEntryVersion) {
      0 => 36,
      1 => 52,
      2 => entrySize >= 72 ? _uint32At(entryStart + 36) : 0,
      _ => 0,
    };
    if (childOffset < 36 || childOffset > entrySize) return null;
    if (audioSampleEntryVersion == 2 && childOffset < 72) return null;
    var childStart = entryStart + childOffset;

    while (childStart + 8 <= entryEnd && childStart + 8 <= _data.length) {
      final childSize = _uint32At(childStart);
      if (childSize < 8 || childStart + childSize > entryEnd) return null;
      final childType = String.fromCharCodes(
        _data.sublist(childStart + 4, childStart + 8),
      );
      if (childType == 'esds' && childSize >= 12) {
        return _findMp4aDecoderConfig(childStart + 12, childStart + childSize);
      }
      childStart += childSize;
    }
    return null;
  }

  _Mp4aDecoderConfig? _findMp4aDecoderConfig(int start, int end) {
    final esDescriptor = _readDescriptor(start, end);
    if (esDescriptor == null || esDescriptor.$1 != 0x03) return null;

    var cursor = esDescriptor.$2;
    final descriptorEnd = esDescriptor.$3;
    if (cursor + 3 > descriptorEnd) return null;
    final flags = _data[cursor + 2];
    cursor += 3; // ES_ID and flags
    if ((flags & 0x80) != 0) cursor += 2; // dependsOn_ES_ID
    if ((flags & 0x40) != 0) {
      if (cursor >= descriptorEnd) return null;
      cursor += 1 + _data[cursor]; // URL length and URL string
    }
    if ((flags & 0x20) != 0) cursor += 2; // OCR_ES_ID
    if (cursor > descriptorEnd) return null;

    while (cursor < descriptorEnd) {
      final descriptor = _readDescriptor(cursor, descriptorEnd);
      if (descriptor == null) return null;
      final (tag, bodyStart, bodyEnd) = descriptor;
      if (tag == 0x04) {
        // DecoderConfigDescriptor's fixed fields precede its child descriptors.
        final configChildren = bodyStart + 13;
        if (configChildren > bodyEnd) return null;
        final objectTypeIndication = _data[bodyStart];
        var child = configChildren;
        while (child < bodyEnd) {
          final config = _readDescriptor(child, bodyEnd);
          if (config == null) return null;
          final (configTag, configStart, configEnd) = config;
          if (configTag == 0x05) {
            return _Mp4aDecoderConfig(
              objectTypeIndication: objectTypeIndication,
              audioSpecificConfig: configStart == configEnd
                  ? null
                  : Uint8List.fromList(_data.sublist(configStart, configEnd)),
            );
          }
          child = configEnd;
        }
        return _Mp4aDecoderConfig(
          objectTypeIndication: objectTypeIndication,
          audioSpecificConfig: null,
        );
      }
      cursor = bodyEnd;
    }
    return null;
  }

  (int, int, int)? _readDescriptor(int start, int end) {
    if (start >= end) return null;
    final tag = _data[start];
    var cursor = start + 1;
    var length = 0;
    var lengthComplete = false;
    for (var i = 0; i < 4; i++) {
      if (cursor >= end) return null;
      final byte = _data[cursor++];
      length = (length << 7) | (byte & 0x7F);
      if ((byte & 0x80) == 0) {
        lengthComplete = true;
        break;
      }
    }
    final bodyEnd = cursor + length;
    if (!lengthComplete || bodyEnd > end) return null;
    return (tag, cursor, bodyEnd);
  }

  int _uint32At(int offset) =>
      (_data[offset] << 24) |
      (_data[offset + 1] << 16) |
      (_data[offset + 2] << 8) |
      _data[offset + 3];

  /// Extract audio frames from mdat box using sample table metadata.
  /// Returns individual frames with their raw data.
  List<_AudioFrame> extractAudioFrames(_AudioTrackInfo track) {
    if (track.sampleSizes.isEmpty || track.chunkOffsets.isEmpty) {
      return [];
    }

    final frames = <_AudioFrame>[];
    int sampleIdx = 0;

    for (var chunkIdx = 0;
        chunkIdx < track.chunkOffsets.length &&
            sampleIdx < track.sampleSizes.length;
        chunkIdx++) {
      final chunkMdatOffset = track.chunkOffsets[chunkIdx];
      final spc = chunkIdx < track.sampleToChunkMap.length
          ? track.sampleToChunkMap[chunkIdx]
          : 1;

      for (var s = 0; s < spc && sampleIdx < track.sampleSizes.length; s++) {
        final sampleSize = track.sampleSizes[sampleIdx];

        // Calculate offset within chunk: sum of sizes of previously read samples in this chunk
        int offsetInChunk = 0;
        if (s > 0) {
          for (var ps = sampleIdx - s; ps < sampleIdx; ps++) {
            offsetInChunk += track.sampleSizes[ps];
          }
        }

        final fileOffset = chunkMdatOffset + offsetInChunk;
        if (fileOffset + sampleSize <= _data.length) {
          frames.add(_AudioFrame(
            Uint8List.sublistView(_data, fileOffset, fileOffset + sampleSize),
          ));
        }
        sampleIdx++;
      }
    }

    return frames;
  }

  // ====================================================================
  // Binary reader helpers
  // ====================================================================

  int _readUint32() {
    if (_offset + 4 > _data.length) return 0;
    final value = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return value;
  }

  int _readUint64() {
    final high = _readUint32();
    final low = _readUint32();
    return high * 0x100000000 + low;
  }

  int _readUint16() {
    if (_offset + 2 > _data.length) return 0;
    final value = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return value;
  }

  String _readString(int length) {
    if (_offset + length > _data.length) return '';
    final s = String.fromCharCodes(_data.sublist(_offset, _offset + length));
    _offset += length;
    return s;
  }

  int _boxSizeAt(int offset) {
    if (offset + 4 > _data.length) return 0;
    return (_data[offset] << 24) |
        (_data[offset + 1] << 16) |
        (_data[offset + 2] << 8) |
        _data[offset + 3];
  }
}

int _samplesPerAacFrame(Uint8List asc, int outputSampleRate) {
  var bitOffset = 0;

  int readBits(int count) {
    if (count < 0 || bitOffset + count > asc.length * 8) {
      throw const FormatException('Truncated AudioSpecificConfig');
    }
    var value = 0;
    for (var i = 0; i < count; i++) {
      final byte = asc[bitOffset >> 3];
      final bit = (byte >> (7 - (bitOffset & 7))) & 1;
      value = (value << 1) | bit;
      bitOffset++;
    }
    return value;
  }

  int readAudioObjectType() {
    final objectType = readBits(5);
    return objectType == 31 ? 32 + readBits(6) : objectType;
  }

  int readSampleRate() {
    const sampleRates = [
      96000,
      88200,
      64000,
      48000,
      44100,
      32000,
      24000,
      22050,
      16000,
      12000,
      11025,
      8000,
      7350,
    ];
    final index = readBits(4);
    if (index == 15) return readBits(24);
    return index < sampleRates.length ? sampleRates[index] : 0;
  }

  void skipProgramConfigElement() {
    readBits(4); // element_instance_tag
    readBits(2); // object_type
    readBits(4); // sampling_frequency_index
    final frontElements = readBits(4);
    final sideElements = readBits(4);
    final backElements = readBits(4);
    final lfeElements = readBits(2);
    final assocDataElements = readBits(3);
    final validCcElements = readBits(4);

    if (readBits(1) == 1) readBits(4); // mono_mixdown_element_number
    if (readBits(1) == 1) readBits(4); // stereo_mixdown_element_number
    if (readBits(1) == 1) readBits(3); // matrix_mixdown fields

    for (var i = 0; i < frontElements + sideElements + backElements; i++) {
      readBits(5); // is_cpe and element tag select
    }
    for (var i = 0; i < lfeElements + assocDataElements; i++) {
      readBits(4); // element tag select
    }
    for (var i = 0; i < validCcElements; i++) {
      readBits(5); // is_ind_sw and valid_cc_element tag select
    }

    final alignmentBits = (8 - (bitOffset & 7)) & 7;
    if (alignmentBits > 0) readBits(alignmentBits);
    final commentBytes = readBits(8);
    readBits(commentBytes * 8);
  }

  try {
    var objectType = readAudioObjectType();
    final coreSampleRate = readSampleRate();
    final channelConfiguration = readBits(4);
    var outputRateFromConfig = coreSampleRate;
    var hasSbr = false;

    if (objectType == 5 || objectType == 29) {
      hasSbr = true;
      outputRateFromConfig = readSampleRate();
      objectType = readAudioObjectType();
      if (objectType == 22) readBits(4); // extensionChannelConfiguration
    }

    if (objectType == 39) {
      // AAC-ELD uses ELDSpecificConfig rather than GASpecificConfig.
      final frameLengthFlag = readBits(1);
      readBits(3); // AAC resilience flags
      final hasEldSbr = readBits(1) == 1;
      var eldOutputRate = coreSampleRate;
      if (hasEldSbr) {
        final sbrSamplingRate = readBits(1);
        readBits(1); // sbrCrcFlag
        eldOutputRate = coreSampleRate * (sbrSamplingRate + 1);
      }

      final coreSamplesPerFrame = frameLengthFlag == 1 ? 480 : 512;
      if (!hasEldSbr) return coreSamplesPerFrame;
      final outputRate =
          outputSampleRate > 0 ? outputSampleRate : eldOutputRate;
      if (coreSampleRate <= 0 || outputRate <= 0) return coreSamplesPerFrame;
      final outputSamples = coreSamplesPerFrame * outputRate / coreSampleRate;
      if (outputSamples != outputSamples.roundToDouble()) {
        return coreSamplesPerFrame;
      }
      return outputSamples.round();
    }

    const gaSpecificObjectTypes = {
      1,
      2,
      3,
      4,
      6,
      7,
      17,
      19,
      20,
      21,
      22,
      23,
    };
    if (!gaSpecificObjectTypes.contains(objectType)) {
      return 1024;
    }

    final frameLengthFlag = readBits(1);
    final dependsOnCoreCoder = readBits(1);
    if (dependsOnCoreCoder == 1) readBits(14);
    final extensionFlag = readBits(1);
    if (channelConfiguration == 0) skipProgramConfigElement();
    final coreSamplesPerFrame = objectType == 23
        ? (frameLengthFlag == 1 ? 480 : 512)
        : (frameLengthFlag == 1 ? 960 : 1024);

    // Backward-compatible HE-AAC signals SBR with a sync extension after
    // the AAC-LC GASpecificConfig rather than using AudioObjectType 5 upfront.
    if (!hasSbr &&
        objectType == 2 &&
        dependsOnCoreCoder == 0 &&
        extensionFlag == 0 &&
        bitOffset + 11 <= asc.length * 8 &&
        readBits(11) == 0x2B7) {
      if (readAudioObjectType() == 5 && readBits(1) == 1) {
        hasSbr = true;
        outputRateFromConfig = readSampleRate();
      }
    }

    if (!hasSbr) return coreSamplesPerFrame;

    final coreRate = coreSampleRate;
    final outputRate =
        outputSampleRate > 0 ? outputSampleRate : outputRateFromConfig;
    if (coreRate <= 0 || outputRate <= 0) return 1024;
    final outputSamples = coreSamplesPerFrame * outputRate / coreRate;
    if (outputSamples != outputSamples.roundToDouble()) return 1024;
    return outputSamples.round();
  } on FormatException {
    return 1024;
  } on RangeError {
    return 1024;
  }
}

// ============================================================================
