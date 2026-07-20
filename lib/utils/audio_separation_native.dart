import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:dio/dio.dart' show CancelToken;
import 'audio_utils.dart' show pcmToWav;

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
  /// For raw PCM, wrap in WAV. For AAC, wrap in a valid M4A (MP4 container).
  Uint8List _packageFrames(List<_AudioFrame> frames, _AudioTrackInfo track) {
    if (track.codec == 'raw ') {
      // PCM audio — concatenate frames and wrap in WAV
      final concatenated = BytesBuilder();
      for (final frame in frames) {
        concatenated.add(frame.data);
      }
      final sampleRate = track.sampleRate > 0 ? track.sampleRate : 44100;
      return pcmToWav(
        concatenated.toBytes(),
        sampleRate: sampleRate,
        bitsPerSample: track.bitsPerSample > 0 ? track.bitsPerSample : 16,
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

    // AudioSpecificConfig (2 bytes): objectType(5) + freqIdx(4) + chanCfg(4)
    final asc = Uint8List.fromList([
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
    // AAC frames have 1024 samples per frame in MP4 timing.
    const samplesPerFrame = 1024;
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
    // DecoderSpecificInfo: tag(1) + length(1) + asc(N)
    final dsiTotal = 2 + asc.length;
    // DecoderConfigDescriptor body: objType(1) + streamType(1) + bufSize(3) +
    //   maxBR(4) + avgBR(4) + DSI_total
    final decConfigBody = 13 + dsiTotal;
    // DecoderConfigDescriptor total: tag(1) + length(1) + body
    final decConfigTotal = 2 + decConfigBody;
    // SLConfigDescriptor total: tag(1) + length(1) + predef(1)
    const slConfigTotal = 3;
    // ES_Descriptor body: ES_ID(2) + flags(1) + DecConfig + SLConfig
    final esBody = 3 + decConfigTotal + slConfigTotal;
    // esds box: header(8) + ver/flags(4) + ES_tag(1) + ES_length(1) + esBody
    return 14 + esBody;
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
    final decConfigBody = 13 + (2 + asc.length);
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
    final decConfigBody = 13 + (2 + asc.length);
    final decConfigTotal = 2 + decConfigBody;
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

  /// Write an MP4 descriptor length (compact form: 1 byte, MSB=0 means end).
  static void _writeDescLength(BytesBuilder buf, int length) {
    // For lengths < 128, use single byte (MSB=0).
    // This is sufficient for our esds boxes since they're always < 128 bytes.
    buf.addByte(length & 0x7F);
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
    required this.sampleCount,
    required this.sampleSizes,
    required this.chunkOffsets,
    required this.sampleToChunkMap,
  });
}

/// Type for an stsc entry: (firstChunk, samplesPerChunk)
typedef _StscEntry = (int, int);

/// Pure-Dart MP4/ISOBMFF container parser.
class _Mp4Demuxer {
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

        final boxSize = _readUint32();
        final boxType = _readString(4);

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
              audioTrack = trackInfo;
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
                  final scStart = _offset;
                  _readUint32(); // box size (advances offset)
                  final scType = _readString(4);

                  if (scType == 'stsd') {
                    _offset += 4; // version + flags
                    final entryCount = _readUint32();
                    for (var i = 0; i < entryCount; i++) {
                      final es = _offset;
                      _readUint32(); // entrySize
                      codec = _readString(4);
                      _offset += 6; // reserved
                      _offset += 2; // data reference index
                      if (codec == 'mp4a' || codec == 'raw ') {
                        _offset += 8; // reserved
                        channels = _readUint16();
                        bitsPerSample = _readUint16();
                        _offset += 4; // pre-defined + reserved
                        sampleRate = _readUint32() >> 16;
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
                      _readUint32(); // sample description index
                      stscEntries.add((firstChunk, spc));
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

    if (handlerType != 'soun' || codec == null) return null;
    if (sampleSizes.isEmpty || chunkOffsets.isEmpty) return null;

    // Build per-chunk samples-per-chunk map from stsc entries.
    // Each stsc entry specifies: firstChunk (1-based), samplesPerChunk.
    // The entry applies from firstChunk to the next entry's firstChunk - 1.
    final sampleToChunk = List.filled(chunkOffsets.length, 1);
    if (stscEntries.isNotEmpty) {
      for (var i = 0; i < stscEntries.length; i++) {
        final (firstChunk, spc) = stscEntries[i];
        final endChunk = (i + 1 < stscEntries.length)
            ? stscEntries[i + 1].$1 - 1
            : chunkOffsets.length;
        for (var c = firstChunk - 1;
            c < endChunk && c < chunkOffsets.length;
            c++) {
          sampleToChunk[c] = spc;
        }
      }
    }

    return _AudioTrackInfo(
      trackId: trackId,
      codec: codec,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      sampleCount: sampleCount,
      sampleSizes: sampleSizes,
      chunkOffsets: chunkOffsets,
      sampleToChunkMap: sampleToChunk,
    );
  }

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

// ============================================================================
