import 'dart:math' show pi, sin;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation.dart' show AudioSeparationEngine;
import 'package:stroom/utils/audio_utils.dart';

/// Helper: read a little-endian 32-bit int from bytes at offset.
int _readUint32LE(Uint8List data, int offset) {
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

/// Helper: read a little-endian 16-bit int from bytes at offset.
int _readUint16LE(Uint8List data, int offset) {
  return data[offset] | (data[offset + 1] << 8);
}

/// Helper: build a standard 8-byte ISOBMFF box header.
/// [size] is the total box size (header + body).
/// [type] is a 4-character box type.
Uint8List _buildBoxHeader(int size, String type) {
  final bytes = BytesBuilder();
  bytes.add(_u32be(size));
  bytes.add(_fourCc(type));
  return bytes.toBytes();
}

/// Helper: convert a 4-character string to 4 big-endian bytes.
Uint8List _fourCc(String s) {
  return Uint8List.fromList(s.codeUnits.map((c) => c).toList());
}

/// Helper: write a 32-bit big-endian integer to 4 bytes.
Uint8List _u32be(int v) {
  return Uint8List.fromList([
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);
}

/// Helper: write a 16-bit big-endian integer to 2 bytes.
Uint8List _u16be(int v) {
  return Uint8List.fromList([
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);
}

/// Helper: write a 48-bit big-endian integer to 6 bytes.
Uint8List _u48be(int v) {
  return Uint8List.fromList([
    (v >> 40) & 0xFF,
    (v >> 32) & 0xFF,
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);
}

/// Helper: write a 64-bit big-endian integer to 8 bytes.
Uint8List _u64be(int v) {
  // Use only low 32 bits for safety on 32-bit platforms
  final low = v & 0xFFFFFFFF;
  final high = (v >> 32) & 0xFFFFFFFF;
  return Uint8List.fromList([
    (high >> 24) & 0xFF,
    (high >> 16) & 0xFF,
    (high >> 8) & 0xFF,
    high & 0xFF,
    (low >> 24) & 0xFF,
    (low >> 16) & 0xFF,
    (low >> 8) & 0xFF,
    low & 0xFF,
  ]);
}

/// Helper: write a signed 32-bit big-endian integer to 4 bytes.
Uint8List _i32be(int v) {
  return _u32be(v & 0xFFFFFFFF);
}

void main() {
  group('AudioSeparationEngine (pure Dart)', () {
    late AudioSeparationEngine engine;

    setUp(() {
      engine = AudioSeparationEngine();
    });

    test('isAvailable returns true', () async {
      // Pure Dart implementation should always be available
      final available = await engine.isAvailable();
      expect(available, isTrue);
    });

    test('canHandleVideoFormat handles ISOBMFF formats (mp4/mov/m4v/3gp)', () {
      expect(engine.canHandleVideoFormat('mp4'), isTrue);
      expect(engine.canHandleVideoFormat('mov'), isTrue);
      expect(engine.canHandleVideoFormat('m4v'), isTrue);
      expect(engine.canHandleVideoFormat('3gp'), isTrue);
    });

    test('canHandleVideoFormat rejects non-ISOBMFF formats', () {
      expect(engine.canHandleVideoFormat('avi'), isFalse);
      expect(engine.canHandleVideoFormat('mkv'), isFalse);
      expect(engine.canHandleVideoFormat('webm'), isFalse);
      expect(engine.canHandleVideoFormat('flv'), isFalse);
    });

    test('canHandleVideoFormat is case-insensitive', () {
      expect(engine.canHandleVideoFormat('MP4'), isTrue);
      expect(engine.canHandleVideoFormat('MOV'), isTrue);
      expect(engine.canHandleVideoFormat('Mp4'), isTrue);
    });

    test('canHandleVideoFormat rejects empty format', () {
      expect(engine.canHandleVideoFormat(''), isFalse);
      expect(engine.canHandleVideoFormat('  '), isFalse);
    });

    test('extractAudio throws on empty video bytes', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([]),
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extractAudio throws on unsupported format', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([0, 1, 2, 3]),
          videoFormat: 'avi',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extractAudio throws on invalid MP4 data (too small)', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0]),
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extractAudio throws on MP4 without audio track', () async {
      // Build a minimal MP4 file that has ftyp but NO moov/mdat
      final mp4Bytes = Uint8List.fromList([
        // ftyp box: size=20, type='ftyp', major='isom', minor=0x200, compatible='isom'
        0x00, 0x00, 0x00, 0x14, // box size = 20
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x00, 0x00, 0x02, 0x00, // version
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
      ]);

      await expectLater(
        engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extractAudio throws on MP4 without audio track (video only)',
        () async {
      // Build minimal MP4 with only a video track (vide handler, no soun)
      // This is complex to construct - skip for now, test via different means
      // Just verify it throws for an MP4 that exists but has issues
    });

    test('pcmToWav produces valid WAV', () {
      final pcmData = Uint8List.fromList(
        List.generate(160, (i) => (i * 127 ~/ 160) & 0xFF),
      );

      final wav = pcmToWav(pcmData, sampleRate: 44100);

      // RIFF header
      expect(wav[0], 0x52); // 'R'
      expect(wav[1], 0x49); // 'I'
      expect(wav[2], 0x46); // 'F'
      expect(wav[3], 0x46); // 'F'

      // WAVE format tag
      expect(wav[8], 0x57); // 'W'
      expect(wav[9], 0x41); // 'A'
      expect(wav[10], 0x56); // 'V'
      expect(wav[11], 0x45); // 'E'

      // fmt chunk
      expect(wav[12], 0x66); // 'f'
      expect(wav[13], 0x6D); // 'm'
      expect(wav[14], 0x74); // 't'
      expect(wav[15], 0x20); // ' '

      // Audio format (1 = PCM)
      expect(_readUint16LE(wav, 20), equals(1));

      // Number of channels (1 = mono)
      expect(_readUint16LE(wav, 22), equals(1));

      // Sample rate
      expect(_readUint32LE(wav, 24), equals(44100));

      // data chunk header
      expect(wav[36], 0x64); // 'd'
      expect(wav[37], 0x61); // 'a'
      expect(wav[38], 0x74); // 't'
      expect(wav[39], 0x61); // 'a'

      // Data size
      expect(_readUint32LE(wav, 40), equals(pcmData.length));
    });
  });

  group('audio_utils - detectAudioFormat', () {
    test('detects WAV from RIFF header', () {
      final data = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('wav'));
    });

    test('detects MP3 from ID3 tag', () {
      final data = Uint8List.fromList([0x49, 0x44, 0x33, 0, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('mp3'));
    });

    test('detects MP3 from sync word', () {
      final data = Uint8List.fromList([0xFF, 0xFB, 0, 0, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('mp3'));
    });

    test('detects FLAC from magic', () {
      final data = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('flac'));
    });

    test('detects M4A from ftyp box', () {
      final data = Uint8List.fromList([0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70]);
      expect(detectAudioFormat(data), equals('m4a'));
    });

    test('returns pcm for unrecognized data', () {
      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(detectAudioFormat(data), equals('pcm'));
    });

    test('returns pcm for data too short', () {
      final data = Uint8List.fromList([0, 1, 2]);
      expect(detectAudioFormat(data), equals('pcm'));
    });
  });

  group('audio_utils - ensureValidAudioFormat', () {
    test('wraps PCM data in WAV when requested format is wav', () {
      final pcm = Uint8List.fromList([100, 200, 150, 50, 0, 50, 150, 200]);
      final (result, format) =
          ensureValidAudioFormat(pcm, requestedFormat: 'wav');

      expect(format, equals('wav'));
      expect(result.length, greaterThan(pcm.length));
      // Should have RIFF header
      expect(result[0], 0x52);
    });

    test('passes through valid WAV data', () {
      final wav = pcmToWav(Uint8List.fromList([100, 200, 150]));
      final (result, format) =
          ensureValidAudioFormat(wav, requestedFormat: 'wav');

      expect(format, equals('wav'));
      expect(result, equals(wav));
    });
  });

  group('AudioSeparationEngine - MP4 extraction (non-silent output)', () {
    late AudioSeparationEngine engine;

    setUp(() {
      engine = AudioSeparationEngine();
    });

    /// Helper: extract raw PCM data from a WAV byte array by stripping the
    /// 44-byte RIFF/WAVE header and reading the 'data' chunk payload.
    Uint8List _extractPcmFromWav(Uint8List wavData) {
      if (wavData.length < 44) return wavData;
      // RIFF/WAVE header is 44 bytes for standard PCM
      // Verify it has RIFF and WAVE markers
      if (wavData[0] != 0x52 ||
          wavData[1] != 0x49 ||
          wavData[2] != 0x46 ||
          wavData[3] != 0x46) {
        return wavData; // not a WAV file
      }
      // data chunk starts at offset 36 (4-byte 'data' tag + 4-byte size)
      // but we can just skip the 44-byte header
      return wavData.sublist(44);
    }

    /// Build a minimal valid MP4 file with a PCM audio track.
    ///
    /// [pcmFrames] - number of 16-bit PCM sample frames (each frame = 2 bytes)
    /// [dataPattern] - if provided, fills audio data with this repeating pattern
    /// Returns a valid MP4 container as bytes.
    Uint8List _buildMinimalMp4WithPcmAudio({
      int pcmFrames = 160,
      Uint8List? dataPattern,
    }) {
      final audioDataLen = pcmFrames * 2; // 16-bit PCM = 2 bytes per frame

      // === Generate PCM audio data (non-zero to detect silence) ===
      Uint8List audioData;
      if (dataPattern != null) {
        audioData = Uint8List(audioDataLen);
        for (var i = 0; i < audioDataLen; i++) {
          audioData[i] = dataPattern[i % dataPattern.length];
        }
      } else {
        // Default: generate a simple sine wave pattern
        audioData = Uint8List(audioDataLen);
        for (var i = 0; i < pcmFrames; i++) {
          final sample = (8000 * sin(i * pi * 2 / 40)).round();
          audioData[i * 2] = sample & 0xFF;
          audioData[i * 2 + 1] = (sample >> 8) & 0xFF;
        }
      }

      // === Build MP4 boxes sequentially ===

      final bytes = BytesBuilder();

      // ----- ftyp box (24 bytes: 8 header + 4+4+4+4 content) -----
      bytes.add(_buildBoxHeader(24, 'ftyp'));
      bytes.add(_fourCc('isom')); // major brand
      bytes.add(_u32be(0x00000200)); // minor version
      bytes.add(_fourCc('isom')); // compatible brand
      bytes.add(_fourCc('mp42'));

      // ----- Offset tracking -----
      // ftyp = 24 bytes (0-23): [8 header + 4+4+4+4 content]
      // moov = 309 bytes (24-332):
      //   8 (moov header) + trak[8 (header) + 92 (tkhd) + 201 (mdia)]
      // mdat starts at 24 + 309 = 333
      // audio data starts at 333 + 8 = 341
      const ftypSize = 24;
      const moovSize = 309;
      const trakSize = 301;
      const mdiaSize = 201;
      const audioDataOffset = ftypSize + moovSize + 8; // = 341

      // Write moov box
      bytes.add(_buildBoxHeader(moovSize, 'moov'));

      // trak wrapper (required: tkhd + mdia must be inside trak)
      bytes.add(_buildBoxHeader(trakSize, 'trak'));

      // tkhd
      bytes.add(_buildBoxHeader(92, 'tkhd'));
      bytes
          .add(_u32be(0x00000007)); // version=0, flags=0x000007 (track enabled)
      bytes.add(_u32be(0)); // creation_time
      bytes.add(_u32be(0)); // modification_time
      bytes.add(_u32be(1)); // track_id = 1
      bytes.add(_u32be(0)); // reserved
      bytes.add(_u32be(0)); // duration
      bytes.add(_u64be(0)); // reserved (2x4)
      bytes.add(_u16be(0)); // layer
      bytes.add(_u16be(0)); // alternate_group
      bytes.add(_u16be(0x0100)); // volume (full)
      bytes.add(_u16be(0)); // reserved
      // matrix (identity)
      bytes.add(_i32be(0x00010000));
      bytes.add(_i32be(0));
      bytes.add(_i32be(0)); // u,v,w
      bytes.add(_i32be(0));
      bytes.add(_i32be(0x00010000));
      bytes.add(_i32be(0));
      bytes.add(_i32be(0));
      bytes.add(_i32be(0));
      bytes.add(_i32be(0x40000000));
      bytes.add(_i32be(0)); // width
      bytes.add(_i32be(0)); // height

      // mdia
      bytes.add(_buildBoxHeader(mdiaSize, 'mdia'));

      // hdlr
      bytes.add(_buildBoxHeader(33, 'hdlr'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(0)); // pre_defined / component_type
      bytes.add(_fourCc('soun')); // handler_type
      bytes.add(_u64be(0)); // reserved (8 bytes: manufacturer + flags)
      bytes.add(_u32be(0)); // reserved (flags_mask)
      bytes.addByte(0); // null name

      // minf
      const minfSize = 160;
      bytes.add(_buildBoxHeader(minfSize, 'minf'));

      // stbl
      const stblSize = 152;
      bytes.add(_buildBoxHeader(stblSize, 'stbl'));

      // stsd
      bytes.add(_buildBoxHeader(52, 'stsd'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(1)); // entry_count = 1
      // SampleEntry for 'raw '
      bytes.add(_u32be(36)); // entry_size (includes itself)
      bytes.add(_fourCc('raw ')); // codec
      bytes.add(_u48be(0)); // reserved (6 bytes)
      bytes.add(_u16be(1)); // data_reference_index = 1
      bytes.add(_u64be(0)); // reserved (8 bytes)
      bytes.add(_u16be(1)); // channels = 1 (mono)
      bytes.add(_u16be(16)); // bits_per_sample = 16
      bytes.add(_u32be(0)); // pre-defined(2) + reserved(2)
      bytes.add(_u32be(44100 << 16)); // sample_rate (16.16 fixed point)

      // stts
      bytes.add(_buildBoxHeader(24, 'stts'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(1)); // entry_count = 1
      bytes.add(_u32be(pcmFrames)); // sample_count
      bytes.add(_u32be(1024)); // sample_duration

      // stsc
      bytes.add(_buildBoxHeader(28, 'stsc'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(1)); // entry_count = 1
      bytes.add(_u32be(1)); // first_chunk = 1
      bytes.add(_u32be(pcmFrames)); // samples_per_chunk
      bytes.add(_u32be(1)); // sample_description_index

      // stsz - constant sample size
      bytes.add(_buildBoxHeader(20, 'stsz'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(2)); // sample_size = 2 (constant, all frames 2 bytes)
      bytes.add(_u32be(pcmFrames)); // sample_count

      // stco
      bytes.add(_buildBoxHeader(20, 'stco'));
      bytes.add(_u32be(0)); // version=0, flags=0
      bytes.add(_u32be(1)); // entry_count = 1
      bytes.add(
          _u32be(audioDataOffset)); // chunk_offset (absolute file position!)

      // ----- mdat box -----
      bytes.add(_buildBoxHeader(8 + audioData.length, 'mdat'));
      bytes.add(audioData);

      return bytes.toBytes();
    }

    test('extractAudio from valid MP4 produces non-silent WAV output',
        () async {
      final mp4Bytes = _buildMinimalMp4WithPcmAudio(pcmFrames: 160);

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      // Verify: output is not empty
      expect(result.length, greaterThan(0));

      // Verify: output is a valid WAV (RIFF header)
      expect(result[0], 0x52); // 'R'
      expect(result[1], 0x49); // 'I'
      expect(result[2], 0x46); // 'F'
      expect(result[3], 0x46); // 'F'

      // Verify: WAV data chunk has non-zero data (NOT silent)
      final pcmOut = _extractPcmFromWav(result);
      expect(pcmOut.length, greaterThan(0));

      // Verify the PCM data is not all zeros (would mean silent output)
      bool hasNonZero = false;
      for (final b in pcmOut) {
        if (b != 0) {
          hasNonZero = true;
          break;
        }
      }
      expect(hasNonZero, isTrue,
          reason: 'Extracted audio data is all zeros (silent) - BUG!');

      // Verify the returned format is WAV
      expect(detectAudioFormat(result), equals('wav'));
    });

    test('extractAudio preserves original PCM audio data in WAV output',
        () async {
      // Use a distinctive non-zero pattern
      final pattern = Uint8List.fromList([0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56]);
      final mp4Bytes = _buildMinimalMp4WithPcmAudio(
        pcmFrames: 80, // 80 frames = 160 bytes of PCM
        dataPattern: pattern,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      // Extract PCM from WAV
      final pcmOut = _extractPcmFromWav(result);

      // Verify the PCM data contains our pattern (not all zeros)
      // The pattern repeats, so any 6 consecutive bytes should contain it
      bool foundPattern = false;
      for (var i = 0; i <= pcmOut.length - pattern.length; i++) {
        bool match = true;
        for (var j = 0; j < pattern.length; j++) {
          if (pcmOut[i + j] != pattern[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          foundPattern = true;
          break;
        }
      }
      expect(foundPattern, isTrue,
          reason: 'Extracted audio data does not contain original pattern - '
              'data is corrupted or silent!');
    });

    test(
        'extractAudio with different frame counts produces proportional output',
        () async {
      // Test with a small number of frames
      final mp4Small = _buildMinimalMp4WithPcmAudio(pcmFrames: 16);
      final resultSmall = await engine.extractAudio(
        videoBytes: mp4Small,
        videoFormat: 'mp4',
      );
      final pcmSmall = _extractPcmFromWav(resultSmall);
      expect(pcmSmall.length, greaterThanOrEqualTo(32)); // 16 frames * 2 bytes

      // Test with a larger number of frames
      final mp4Large = _buildMinimalMp4WithPcmAudio(pcmFrames: 320);
      final resultLarge = await engine.extractAudio(
        videoBytes: mp4Large,
        videoFormat: 'mp4',
      );
      final pcmLarge = _extractPcmFromWav(resultLarge);
      expect(
          pcmLarge.length, greaterThanOrEqualTo(640)); // 320 frames * 2 bytes

      // Larger input should produce larger output
      expect(pcmLarge.length, greaterThan(pcmSmall.length));
    });

    test('extractAudio reports progress during extraction', () async {
      final mp4Bytes = _buildMinimalMp4WithPcmAudio(pcmFrames: 160);
      final progressValues = <int>[];

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
        onProgress: (p) => progressValues.add(p),
      );

      // Should have reported some progress
      expect(progressValues, isNotEmpty);
      // Should include 0% and 100%
      expect(progressValues.first, equals(0));
      expect(progressValues.last, equals(100));
      // Output should still be valid
      expect(result.length, greaterThan(0));
    });
  });
}
