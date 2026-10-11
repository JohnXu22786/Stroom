import 'dart:isolate' show Isolate, ReceivePort, SendPort;
import 'dart:math' show pi, sin;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation.dart'
    show AudioSeparationEngine, extractAudioSync;
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

int _readUint32BE(Uint8List data, int offset) {
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

Uint8List _buildBox(String type, List<int> body) {
  final bytes = BytesBuilder();
  bytes.add(_buildBoxHeader(body.length + 8, type));
  bytes.add(body);
  return bytes.toBytes();
}

int _findFourCc(Uint8List data, String fourCc) {
  final marker = _fourCc(fourCc);
  for (var i = 0; i <= data.length - marker.length; i++) {
    var matches = true;
    for (var j = 0; j < marker.length; j++) {
      if (data[i + j] != marker[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}

bool _containsBytes(Uint8List data, Uint8List expected) {
  for (var i = 0; i <= data.length - expected.length; i++) {
    var matches = true;
    for (var j = 0; j < expected.length; j++) {
      if (data[i + j] != expected[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
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

Uint8List _f64be(double v) {
  final data = ByteData(8)..setFloat64(0, v, Endian.big);
  return data.buffer.asUint8List();
}

void _extractAudioInIsolateForTesting(List<Object?> args) {
  final response = args[0] as SendPort;
  try {
    extractAudioSync(videoBytes: args[1] as Uint8List, videoFormat: 'mp4');
    response.send('returned');
  } catch (error) {
    response.send(error.toString());
  }
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
    test('detects WAV from RIFF/WAVE signature', () {
      final data = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x41,
        0x56,
        0x45,
      ]);
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
    Uint8List extractPcmFromWav(Uint8List wavData) {
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
    /// [pcmFrames] - number of PCM samples; sample width comes from
    /// [bitsPerSample].
    /// [dataPattern] - if provided, fills audio data with this repeating pattern
    /// Returns a valid MP4 container as bytes.
    Uint8List buildMinimalMp4WithPcmAudio({
      int pcmFrames = 160,
      Uint8List? dataPattern,
      String codec = 'raw ',
      int sampleRate = 44100,
      int bitsPerSample = 16,
    }) {
      final bytesPerSample = (bitsPerSample + 7) ~/ 8;
      final audioDataLen = pcmFrames * bytesPerSample;

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
      // SampleEntry for the requested PCM codec.
      bytes.add(_u32be(36)); // entry_size (includes itself)
      bytes.add(_fourCc(codec)); // codec
      bytes.add(_u48be(0)); // reserved (6 bytes)
      bytes.add(_u16be(1)); // data_reference_index = 1
      bytes.add(_u64be(0)); // reserved (8 bytes)
      bytes.add(_u16be(1)); // channels = 1 (mono)
      bytes.add(_u16be(bitsPerSample)); // bits_per_sample
      bytes.add(_u32be(0)); // pre-defined(2) + reserved(2)
      bytes.add(_u32be(sampleRate << 16)); // sample_rate (16.16 fixed point)

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
      bytes.add(_u32be(bytesPerSample)); // constant bytes per sample
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

    Uint8List buildNonFaststartMp4WithExtendedMdat({
      required Uint8List audioData,
    }) {
      final faststart = buildMinimalMp4WithPcmAudio(
        pcmFrames: audioData.length ~/ 2,
        dataPattern: audioData,
      );
      final moovStart = _findFourCc(faststart, 'moov') - 4;
      final moovSize = _readUint32BE(faststart, moovStart);
      final ftyp = faststart.sublist(0, moovStart);
      final moov = Uint8List.fromList(
        faststart.sublist(moovStart, moovStart + moovSize),
      );
      final mdatStart = moovStart + moovSize;
      final mdatPayload = faststart.sublist(mdatStart + 8);
      final audioDataOffset = ftyp.length + 16;
      final stcoTypeOffset = _findFourCc(moov, 'stco');
      moov.setRange(
        stcoTypeOffset + 12,
        stcoTypeOffset + 16,
        _u32be(audioDataOffset),
      );
      final extendedMdat = Uint8List.fromList([
        ..._u32be(1),
        ..._fourCc('mdat'),
        ..._u64be(16 + mdatPayload.length),
        ...mdatPayload,
      ]);

      return Uint8List.fromList([...ftyp, ...extendedMdat, ...moov]);
    }

    Uint8List buildMinimalMp4WithTwoPcmAudioTracks() {
      final firstAudio = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);
      final secondAudio = Uint8List.fromList([0xA1, 0xB2, 0xC3, 0xD4]);
      final firstFixture = buildMinimalMp4WithPcmAudio(
        pcmFrames: 2,
        dataPattern: firstAudio,
      );
      final secondFixture = buildMinimalMp4WithPcmAudio(
        pcmFrames: 2,
        dataPattern: secondAudio,
      );

      Uint8List trackFrom(Uint8List fixture) {
        final moovStart = _findFourCc(fixture, 'moov') - 4;
        final trackStart = moovStart + 8;
        final trackSize = _readUint32BE(fixture, trackStart);
        return Uint8List.fromList(
          fixture.sublist(trackStart, trackStart + trackSize),
        );
      }

      Uint8List withChunkOffset(Uint8List track, int offset) {
        final copy = Uint8List.fromList(track);
        final stcoTypeOffset = _findFourCc(copy, 'stco');
        copy.setRange(
          stcoTypeOffset + 12,
          stcoTypeOffset + 16,
          _u32be(offset),
        );
        return copy;
      }

      final firstTrack = trackFrom(firstFixture);
      final secondTrack = trackFrom(secondFixture);
      final ftypEnd = _findFourCc(firstFixture, 'moov') - 4;
      final ftyp = firstFixture.sublist(0, ftypEnd);
      final moovSize = 8 + firstTrack.length + secondTrack.length;
      final firstAudioOffset = ftyp.length + moovSize + 8;
      final moov = _buildBox('moov', [
        ...withChunkOffset(firstTrack, firstAudioOffset),
        ...withChunkOffset(secondTrack, firstAudioOffset + firstAudio.length),
      ]);
      final mdat = _buildBox('mdat', [...firstAudio, ...secondAudio]);

      return Uint8List.fromList([...ftyp, ...moov, ...mdat]);
    }

    Uint8List buildMinimalMp4WithAacAudio({
      required Uint8List asc,
      required int sampleRate,
      int objectTypeIndication = 0x40,
      int channels = 2,
      int samplesPerFrame = 1024,
      int audioSampleEntryVersion = 0,
      List<Uint8List> additionalAudioSpecificConfigs = const [],
      int sampleDescriptionIndex = 1,
      List<int>? sampleDescriptionIndicesPerChunk,
      List<Uint8List>? sourceFrames,
      int? editListMediaTime,
      int? editListSegmentDuration,
      int editListMediaRateInteger = 1,
      int editListMediaRateFraction = 0,
    }) {
      final audioFrames = sourceFrames ??
          <Uint8List>[
            Uint8List.fromList([0x11, 0x22, 0x33]),
            Uint8List.fromList([0x44, 0x55, 0x66]),
          ];
      if ((editListMediaTime == null) != (editListSegmentDuration == null)) {
        throw ArgumentError(
          'An edit list needs both a media time and duration.',
        );
      }
      final mediaDuration = audioFrames.length * samplesPerFrame;
      final movieDuration = editListSegmentDuration ?? mediaDuration;

      Uint8List descriptor(int tag, List<int> body) {
        var remaining = body.length;
        var lengthBytes = 1;
        while (remaining > 0x7F) {
          lengthBytes++;
          remaining >>= 7;
        }
        final encodedLength = <int>[];
        for (var index = lengthBytes - 1; index >= 0; index--) {
          final byte = (body.length >> (index * 7)) & 0x7F;
          encodedLength.add(byte | (index > 0 ? 0x80 : 0));
        }
        return Uint8List.fromList([tag, ...encodedLength, ...body]);
      }

      Uint8List buildMp4aEntry(Uint8List sourceAsc) {
        final decoderSpecificInfo = descriptor(0x05, sourceAsc);
        final decoderConfig = descriptor(0x04, [
          objectTypeIndication, // objectTypeIndication
          0x15, // streamType: audio
          0, 0, 0, // bufferSizeDB
          ..._u32be(0), // maxBitrate
          ..._u32be(0), // avgBitrate
          ...decoderSpecificInfo,
        ]);
        final esDescriptor = descriptor(0x03, [
          0, 1, 0, // ES_ID and flags
          ...decoderConfig,
          0x06, 0x01, 0x02, // SLConfigDescriptor
        ]);
        final esds = _buildBox('esds', [0, 0, 0, 0, ...esDescriptor]);

        final mp4aBody = <int>[
          ...List.filled(6, 0), // reserved
          ..._u16be(1), // data_reference_index
          ..._u16be(audioSampleEntryVersion), // sample-entry version
          ..._u16be(0), // revision level
          ..._u32be(0), // vendor
        ];
        if (audioSampleEntryVersion == 2) {
          mp4aBody
            ..addAll(_u16be(3)) // always3
            ..addAll(_u16be(16)) // always16
            ..addAll(_u16be(0xFFFE)) // alwaysMinus2
            ..addAll(_u16be(0)) // always0
            ..addAll(_u32be(0x10000)) // always65536
            ..addAll(_u32be(72)) // sizeOfStructOnly
            ..addAll(_f64be(sampleRate.toDouble()))
            ..addAll(_u32be(channels)) // numAudioChannels
            ..addAll(_u32be(0x7F000000)) // always7F000000
            ..addAll(_u32be(16)) // constBitsPerChannel
            ..addAll(_u32be(0)) // formatSpecificFlags
            ..addAll(_u32be(0)) // constBytesPerAudioPacket
            ..addAll(_u32be(0)); // constLPCMFramesPerAudioPacket
        } else {
          mp4aBody
            ..addAll(_u16be(channels))
            ..addAll(_u16be(16)) // sample size
            ..addAll(_u16be(0)) // compression ID
            ..addAll(_u16be(0)) // packet size
            ..addAll(_u32be(sampleRate << 16));
          if (audioSampleEntryVersion == 1) {
            mp4aBody.addAll(List.filled(16, 0)); // version 1 fixed fields
          }
        }
        mp4aBody.addAll(esds);
        return _buildBox('mp4a', mp4aBody);
      }

      final mp4aEntries =
          [asc, ...additionalAudioSpecificConfigs].map(buildMp4aEntry).toList();
      final samplesPerChunk = sampleDescriptionIndicesPerChunk == null
          ? [audioFrames.length]
          : List.filled(audioFrames.length, 1);
      final descriptionsPerChunk =
          sampleDescriptionIndicesPerChunk ?? [sampleDescriptionIndex];
      if (descriptionsPerChunk.length != samplesPerChunk.length) {
        throw ArgumentError('Every fixture chunk needs a sample description.');
      }
      final stscRows = <(int, int, int)>[];
      for (var i = 0; i < samplesPerChunk.length; i++) {
        final descriptionIndex = descriptionsPerChunk[i];
        if (i == 0 ||
            descriptionIndex != descriptionsPerChunk[i - 1] ||
            samplesPerChunk[i] != samplesPerChunk[i - 1]) {
          stscRows.add((i + 1, samplesPerChunk[i], descriptionIndex));
        }
      }
      final frameOffsets = <int>[];
      var frameOffset = 0;
      for (final frame in audioFrames) {
        frameOffsets.add(frameOffset);
        frameOffset += frame.length;
      }
      final chunkSampleStarts = <int>[];
      var chunkSampleStart = 0;
      for (final count in samplesPerChunk) {
        chunkSampleStarts.add(chunkSampleStart);
        chunkSampleStart += count;
      }
      final stsd = _buildBox('stsd', [
        0, 0, 0, 0, // version + flags
        ..._u32be(mp4aEntries.length), // entry count
        for (final entry in mp4aEntries) ...entry,
      ]);
      final stts = _buildBox('stts', [
        0, 0, 0, 0, // version + flags
        ..._u32be(1), // entry count
        ..._u32be(audioFrames.length),
        ..._u32be(samplesPerFrame),
      ]);
      final stsc = _buildBox('stsc', [
        0, 0, 0, 0, // version + flags
        ..._u32be(stscRows.length), // entry count
        for (final (firstChunk, count, descriptionIndex) in stscRows) ...[
          ..._u32be(firstChunk),
          ..._u32be(count),
          ..._u32be(descriptionIndex),
        ],
      ]);
      final stsz = _buildBox('stsz', [
        0, 0, 0, 0, // version + flags
        ..._u32be(0), // variable sample sizes
        ..._u32be(audioFrames.length),
        for (final frame in audioFrames) ..._u32be(frame.length),
      ]);

      Uint8List buildMoov(int audioDataOffset) {
        final stco = _buildBox('stco', [
          0, 0, 0, 0, // version + flags
          ..._u32be(chunkSampleStarts.length), // entry count
          for (final start in chunkSampleStarts)
            ..._u32be(audioDataOffset + frameOffsets[start]),
        ]);
        final stbl = _buildBox('stbl', [
          ...stsd,
          ...stts,
          ...stsc,
          ...stsz,
          ...stco,
        ]);
        final minf = _buildBox('minf', stbl);
        final mdhd = _buildBox('mdhd', [
          0, 0, 0, 0, // version + flags
          ..._u32be(0), // creation time
          ..._u32be(0), // modification time
          ..._u32be(sampleRate),
          ..._u32be(mediaDuration),
          ..._u16be(0x55C4), // und
          ..._u16be(0), // predefined
        ]);
        final hdlr = _buildBox('hdlr', [
          0, 0, 0, 0, // version + flags
          ..._u32be(0), // pre-defined
          ..._fourCc('soun'),
          ...List.filled(12, 0), // reserved
          0, // name terminator
        ]);
        final mdia = _buildBox('mdia', [...mdhd, ...hdlr, ...minf]);
        final matrix = [
          for (final value in [
            0x00010000,
            0,
            0,
            0,
            0x00010000,
            0,
            0,
            0,
            0x40000000,
          ])
            ..._i32be(value),
        ];
        final mvhd = _buildBox('mvhd', [
          0, 0, 0, 0, // version + flags
          ..._u32be(0), // creation time
          ..._u32be(0), // modification time
          ..._u32be(sampleRate), // movie timescale
          ..._u32be(movieDuration),
          ..._u32be(0x00010000), // rate
          ..._u16be(0x0100), // volume
          ..._u16be(0), // reserved
          ..._u32be(0), // reserved
          ..._u32be(0), // reserved
          ...matrix,
          ...List.filled(24, 0), // predefined
          ..._u32be(2), // next track ID
        ]);
        final tkhd = _buildBox('tkhd', [
          0, 0, 0, 7, // version + flags
          ..._u32be(0), // creation time
          ..._u32be(0), // modification time
          ..._u32be(1), // track ID
          ..._u32be(0), // reserved
          ..._u32be(movieDuration),
          ..._u64be(0), // reserved
          ..._u16be(0), // layer
          ..._u16be(0), // alternate group
          ..._u16be(0x0100), // volume
          ..._u16be(0), // reserved
          ...matrix,
          ..._u32be(0), // width
          ..._u32be(0), // height
        ]);
        final edts = editListMediaTime == null
            ? <int>[]
            : _buildBox(
                'edts',
                _buildBox('elst', [
                  0, 0, 0, 0, // version + flags
                  ..._u32be(1), // entry count
                  ..._u32be(editListSegmentDuration!),
                  ..._i32be(editListMediaTime),
                  ..._u16be(editListMediaRateInteger),
                  ..._u16be(editListMediaRateFraction),
                ]),
              );
        final trak = _buildBox('trak', [...tkhd, ...edts, ...mdia]);
        return _buildBox('moov', [...mvhd, ...trak]);
      }

      final ftyp = _buildBox('ftyp', [
        ..._fourCc('isom'),
        ..._u32be(0x200),
        ..._fourCc('isom'),
        ..._fourCc('mp42'),
      ]);
      final moovWithoutOffset = buildMoov(0);
      final audioDataOffset = ftyp.length + moovWithoutOffset.length + 8;
      final moov = buildMoov(audioDataOffset);
      final audioData = BytesBuilder();
      for (final frame in audioFrames) {
        audioData.add(frame);
      }
      final mdat = _buildBox('mdat', audioData.toBytes());

      final result = BytesBuilder();
      result
        ..add(ftyp)
        ..add(moov)
        ..add(mdat);
      return result.toBytes();
    }

    Uint8List audioDataFromMp4(Uint8List data) {
      final mdatTypeOffset = _findFourCc(data, 'mdat');
      expect(mdatTypeOffset, greaterThanOrEqualTo(4));
      final mdatStart = mdatTypeOffset - 4;
      final mdatEnd = mdatStart + _readUint32BE(data, mdatStart);
      return Uint8List.fromList(data.sublist(mdatTypeOffset + 4, mdatEnd));
    }

    test('honors AAC edit-list trims around encoder priming', () async {
      final sourceFrames = [
        Uint8List.fromList([0x11, 0x22, 0x33]), // encoder priming
        Uint8List.fromList([0x44, 0x55, 0x66]), // retained audio
        Uint8List.fromList([0x77, 0x88, 0x99]), // beyond the edit segment
      ];
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: Uint8List.fromList([0x12, 0x10]),
        sampleRate: 44100,
        sourceFrames: sourceFrames,
        editListMediaTime: 1024,
        editListSegmentDuration: 1024,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(audioDataFromMp4(result), sourceFrames[1]);
    });

    test('honors positive non-unit AAC edit-list rates', () async {
      final sourceFrames = [
        Uint8List.fromList([0x11, 0x22, 0x33]), // before the media interval
        Uint8List.fromList([0x44, 0x55, 0x66]), // inside the media interval
        Uint8List.fromList([0x77, 0x88, 0x99]), // after the media interval
      ];
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: Uint8List.fromList([0x12, 0x10]),
        sampleRate: 44100,
        sourceFrames: sourceFrames,
        editListMediaTime: 1024,
        editListSegmentDuration: 512,
        editListMediaRateInteger: 2,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(audioDataFromMp4(result), sourceFrames[1]);
    });

    test(
      'preserves every AAC frame when the source has no edit list',
      () async {
        final sourceFrames = [
          Uint8List.fromList([0x11, 0x22, 0x33]),
          Uint8List.fromList([0x44, 0x55, 0x66]),
          Uint8List.fromList([0x77, 0x88, 0x99]),
        ];
        final mp4Bytes = buildMinimalMp4WithAacAudio(
          asc: Uint8List.fromList([0x12, 0x10]),
          sampleRate: 44100,
          sourceFrames: sourceFrames,
        );

        final result = await engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        );

        expect(
          audioDataFromMp4(result),
          Uint8List.fromList(sourceFrames.expand((frame) => frame).toList()),
        );
      },
    );

    test(
      'rejects a truncated trailing moov with oversized stbl without hanging',
      () async {
        final valid = buildMinimalMp4WithPcmAudio(pcmFrames: 2);
        final moovStart = _findFourCc(valid, 'moov') - 4;
        final moovSize = _readUint32BE(valid, moovStart);
        final mdatStart = moovStart + moovSize;
        final malformed = Uint8List.fromList([
          ...valid.sublist(0, moovStart),
          ...valid.sublist(mdatStart),
          ...valid.sublist(moovStart, mdatStart),
        ]);
        final moovHeader = _findFourCc(malformed, 'moov') - 4;
        malformed.setRange(moovHeader, moovHeader + 4, _u32be(0x7FFFFFFF));
        final stblHeader = _findFourCc(malformed, 'stbl') - 4;
        malformed.setRange(stblHeader, stblHeader + 4, _u32be(0x7FFFFFFF));

        final response = ReceivePort();
        final isolate = await Isolate.spawn(_extractAudioInIsolateForTesting, [
          response.sendPort,
          malformed,
        ]);
        final result = await response.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => 'timed-out',
        );
        isolate.kill(priority: Isolate.immediate);
        response.close();

        expect(result, equals('Exception: No audio track found in video'));
      },
    );

    test('preserves HE-AAC/SBR config and output frame timing', () async {
      // Cover AOT 5 and the backward-compatible AOT 2 + sync-extension form.
      final configs = [
        Uint8List.fromList([0x2B, 0x92, 0x08, 0x00]),
        Uint8List.fromList([0x13, 0x90, 0x56, 0xE5, 0xA0]),
      ];
      for (final asc in configs) {
        final mp4Bytes = buildMinimalMp4WithAacAudio(
          asc: asc,
          sampleRate: 44100,
          samplesPerFrame: 2048,
        );

        final result = await engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        );

        expect(_containsBytes(result, asc), isTrue,
            reason: 'Output discarded the source HE-AAC/SBR configuration.');
        final sttsTypeOffset = _findFourCc(result, 'stts');
        expect(sttsTypeOffset, greaterThanOrEqualTo(0));
        expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
        expect(_readUint32BE(result, sttsTypeOffset + 16), 2048,
            reason:
                'SBR output samples must be represented in the MP4 timing.');
      }
    });

    test('preserves AAC-LC 960-sample frame configuration and timing',
        () async {
      // AOT 2, 44100 Hz, stereo, frameLengthFlag=1 (960 samples/frame).
      final asc = Uint8List.fromList([0x12, 0x14]);
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: asc,
        sampleRate: 44100,
        samplesPerFrame: 960,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(_containsBytes(result, asc), isTrue,
          reason: 'Output discarded the source AAC AudioSpecificConfig.');
      final sttsTypeOffset = _findFourCc(result, 'stts');
      expect(sttsTypeOffset, greaterThanOrEqualTo(0));
      expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
      expect(_readUint32BE(result, sttsTypeOffset + 16), 960,
          reason: 'AAC-LC frameLengthFlag selects 960 samples per frame.');
    });

    test('reads AAC-LC 960-sample timing with a program config element',
        () async {
      // AOT 2, 44100 Hz, channelConfiguration=0 and a stereo PCE.
      // The GASpecificConfig frameLengthFlag appears before the PCE.
      final asc = Uint8List.fromList([
        0x12,
        0x04,
        0x05,
        0x04,
        0x00,
        0x00,
        0x20,
        0x00,
      ]);
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: asc,
        sampleRate: 44100,
        samplesPerFrame: 960,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(_containsBytes(result, asc), isTrue,
          reason: 'Output discarded the source AAC AudioSpecificConfig.');
      final sttsTypeOffset = _findFourCc(result, 'stts');
      expect(sttsTypeOffset, greaterThanOrEqualTo(0));
      expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
      expect(_readUint32BE(result, sttsTypeOffset + 16), 960,
          reason:
              'PCE follows the AAC-LC frameLengthFlag in GASpecificConfig.');
    });

    test('uses AAC-LD frame lengths for AudioObjectType 23', () async {
      // ER AAC LD uses 512 or 480 samples, selected by frameLengthFlag.
      final configs = [
        (Uint8List.fromList([0xBA, 0x10]), 512),
        (Uint8List.fromList([0xBA, 0x14]), 480),
      ];
      for (final (asc, samplesPerFrame) in configs) {
        final mp4Bytes = buildMinimalMp4WithAacAudio(
          asc: asc,
          sampleRate: 44100,
          samplesPerFrame: samplesPerFrame,
        );

        final result = await engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        );

        expect(_containsBytes(result, asc), isTrue,
            reason: 'Output discarded the source AAC AudioSpecificConfig.');
        final sttsTypeOffset = _findFourCc(result, 'stts');
        expect(sttsTypeOffset, greaterThanOrEqualTo(0));
        expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
        expect(_readUint32BE(result, sttsTypeOffset + 16), samplesPerFrame,
            reason: 'AAC-LD frameLengthFlag selects the expected frame size.');
      }
    });

    test('reads AAC-ELD frame lengths for AudioObjectType 39', () async {
      // AAC-ELD's ELDSpecificConfig uses 512 samples when the flag is clear
      // and 480 when it is set. Both configs have SBR disabled.
      final configs = [
        (Uint8List.fromList([0xF8, 0xE8, 0x40, 0x00]), 512),
        (Uint8List.fromList([0xF8, 0xE8, 0x50, 0x00]), 480),
      ];
      for (final (asc, samplesPerFrame) in configs) {
        final mp4Bytes = buildMinimalMp4WithAacAudio(
          asc: asc,
          sampleRate: 44100,
          samplesPerFrame: samplesPerFrame,
        );

        final result = await engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        );

        expect(_containsBytes(result, asc), isTrue,
            reason: 'Output discarded the source AAC AudioSpecificConfig.');
        final sttsTypeOffset = _findFourCc(result, 'stts');
        expect(sttsTypeOffset, greaterThanOrEqualTo(0));
        expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
        expect(_readUint32BE(result, sttsTypeOffset + 16), samplesPerFrame,
            reason: 'AAC-ELD frameLengthFlag selects the expected frame size.');
      }
    });

    test('reads AAC config after versioned QuickTime mp4a sample fields',
        () async {
      final asc = Uint8List.fromList([0x2B, 0x92, 0x08, 0x00]);
      for (final version in [1, 2]) {
        final mp4Bytes = buildMinimalMp4WithAacAudio(
          asc: asc,
          sampleRate: 44100,
          samplesPerFrame: 2048,
          audioSampleEntryVersion: version,
        );

        final result = await engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        );

        expect(_containsBytes(result, asc), isTrue,
            reason: 'Version $version mp4a entry lost its source ASC.');
        final sttsTypeOffset = _findFourCc(result, 'stts');
        expect(sttsTypeOffset, greaterThanOrEqualTo(0));
        expect(_readUint32BE(result, sttsTypeOffset + 12), 2);
        expect(_readUint32BE(result, sttsTypeOffset + 16), 2048,
            reason:
                'Version $version mp4a entries must retain the SBR timing.');
      }
    });

    test('uses the AAC config referenced by the sample-to-chunk table',
        () async {
      final activeAsc = Uint8List.fromList([0x2B, 0x92, 0x08, 0x00]);
      final unusedAsc = Uint8List.fromList([0x12, 0x10]);
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: activeAsc,
        additionalAudioSpecificConfigs: [unusedAsc],
        sampleDescriptionIndex: 1,
        sampleRate: 44100,
        samplesPerFrame: 2048,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(_containsBytes(result, activeAsc), isTrue,
          reason: 'Output discarded the AAC config used by the audio chunks.');
      expect(_containsBytes(result, unusedAsc), isFalse,
          reason: 'Output used an unused sample description\'s AAC config.');
      final sttsTypeOffset = _findFourCc(result, 'stts');
      expect(sttsTypeOffset, greaterThanOrEqualTo(0));
      expect(_readUint32BE(result, sttsTypeOffset + 16), 2048);
    });

    test('rejects AAC chunks with incompatible sample descriptions', () async {
      final activeAsc = Uint8List.fromList([0x2B, 0x92, 0x08, 0x00]);
      final otherAsc = Uint8List.fromList([0x12, 0x10]);
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: activeAsc,
        additionalAudioSpecificConfigs: [otherAsc],
        sampleDescriptionIndicesPerChunk: [1, 2],
        sampleRate: 44100,
        samplesPerFrame: 2048,
      );

      await expectLater(
        engine.extractAudio(videoBytes: mp4Bytes, videoFormat: 'mp4'),
        throwsA(isA<Exception>()),
      );
    });

    test('validates mp4a tracks against their decoder object type', () async {
      for (final objectTypeIndication in [0x66, 0x67, 0x68]) {
        final aacMp4Bytes = buildMinimalMp4WithAacAudio(
          asc: Uint8List.fromList([0x12, 0x10]),
          sampleRate: 44100,
          objectTypeIndication: objectTypeIndication,
        );
        final aacResult = await engine.extractAudio(
          videoBytes: aacMp4Bytes,
          videoFormat: 'mp4',
        );

        expect(_findFourCc(aacResult, 'mp4a'), greaterThanOrEqualTo(0),
            reason:
                'AAC DecoderConfig OTI 0x${objectTypeIndication.toRadixString(16)} should remain supported.');
      }

      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: Uint8List(0),
        sampleRate: 44100,
        objectTypeIndication: 0x6B, // MPEG audio, not AAC
      );

      await expectLater(
        engine.extractAudio(videoBytes: mp4Bytes, videoFormat: 'mp4'),
        throwsA(isA<Exception>()),
      );
    });

    test('writes multi-byte esds descriptor lengths for large source ASC',
        () async {
      // A 105-byte ASC makes the ES_Descriptor body exactly 128 bytes.
      final asc = Uint8List.fromList([0x12, 0x10, ...List.filled(103, 0)]);
      final mp4Bytes = buildMinimalMp4WithAacAudio(
        asc: asc,
        sampleRate: 44100,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(_containsBytes(result, asc), isTrue,
          reason: 'Output discarded the source AAC AudioSpecificConfig.');
      final esdsTypeOffset = _findFourCc(result, 'esds');
      expect(esdsTypeOffset, greaterThanOrEqualTo(0));
      expect(_readUint32BE(result, esdsTypeOffset - 4), 143,
          reason: 'The extra length byte must be included in the esds size.');
      expect(result[esdsTypeOffset + 8], 0x03);
      expect(result[esdsTypeOffset + 9], 0x81);
      expect(result[esdsTypeOffset + 10], 0x00,
          reason: 'Descriptor length 128 must use two base-128 bytes.');
    });

    test('extractAudio from valid MP4 produces non-silent WAV output',
        () async {
      final mp4Bytes = buildMinimalMp4WithPcmAudio(pcmFrames: 160);

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
      final pcmOut = extractPcmFromWav(result);
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

    test(
        'extractAudio reads audio after extended-size mdat before trailing moov',
        () async {
      final audioData = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);
      final mp4Bytes = buildNonFaststartMp4WithExtendedMdat(
        audioData: audioData,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(extractPcmFromWav(result), audioData);
    });

    test('extractAudio preserves original PCM audio data in WAV output',
        () async {
      // Use a distinctive non-zero pattern
      final pattern = Uint8List.fromList([0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56]);
      final mp4Bytes = buildMinimalMp4WithPcmAudio(
        pcmFrames: 80, // 80 frames = 160 bytes of PCM
        dataPattern: pattern,
      );

      final result = await engine.extractAudio(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      // Extract PCM from WAV
      final pcmOut = extractPcmFromWav(result);

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

    test('extractAudioSync selects the first supported audio track', () {
      final mp4Bytes = buildMinimalMp4WithTwoPcmAudioTracks();

      final result = extractAudioSync(
        videoBytes: mp4Bytes,
        videoFormat: 'mp4',
      );

      expect(extractPcmFromWav(result), [0x11, 0x22, 0x33, 0x44]);
    });

    test('extractAudio packages twos MOV PCM as WAV and swaps byte order',
        () async {
      final movBytes = buildMinimalMp4WithPcmAudio(
        pcmFrames: 2,
        dataPattern: Uint8List.fromList([0x12, 0x34]),
        codec: 'twos',
        sampleRate: 48000,
      );

      final result = await engine.extractAudio(
        videoBytes: movBytes,
        videoFormat: 'mov',
      );

      expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
      expect(_readUint16LE(result, 22), 1);
      expect(_readUint32LE(result, 24), 48000);
      expect(extractPcmFromWav(result), [0x34, 0x12, 0x34, 0x12]);
    });

    test('extractAudio packages sowt MOV PCM as WAV and preserves byte order',
        () async {
      final movBytes = buildMinimalMp4WithPcmAudio(
        pcmFrames: 2,
        dataPattern: Uint8List.fromList([0x34, 0x12]),
        codec: 'sowt',
        sampleRate: 48000,
      );

      final result = await engine.extractAudio(
        videoBytes: movBytes,
        videoFormat: 'mov',
      );

      expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
      expect(_readUint16LE(result, 22), 1);
      expect(_readUint32LE(result, 24), 48000);
      expect(extractPcmFromWav(result), [0x34, 0x12, 0x34, 0x12]);
    });

    test('extractAudio converts signed 8-bit MOV PCM to unsigned WAV samples',
        () async {
      for (final codec in ['twos', 'sowt']) {
        final movBytes = buildMinimalMp4WithPcmAudio(
          pcmFrames: 4,
          dataPattern: Uint8List.fromList([0x00, 0x7F, 0x80, 0xFF]),
          codec: codec,
          bitsPerSample: 8,
        );

        final result = await engine.extractAudio(
          videoBytes: movBytes,
          videoFormat: 'mov',
        );

        expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
        expect(_readUint16LE(result, 22), 1);
        expect(_readUint16LE(result, 34), 8);
        expect(extractPcmFromWav(result), [0x80, 0xFF, 0x00, 0x7F]);
      }
    });

    test(
        'extractAudio with different frame counts produces proportional output',
        () async {
      // Test with a small number of frames
      final mp4Small = buildMinimalMp4WithPcmAudio(pcmFrames: 16);
      final resultSmall = await engine.extractAudio(
        videoBytes: mp4Small,
        videoFormat: 'mp4',
      );
      final pcmSmall = extractPcmFromWav(resultSmall);
      expect(pcmSmall.length, greaterThanOrEqualTo(32)); // 16 frames * 2 bytes

      // Test with a larger number of frames
      final mp4Large = buildMinimalMp4WithPcmAudio(pcmFrames: 320);
      final resultLarge = await engine.extractAudio(
        videoBytes: mp4Large,
        videoFormat: 'mp4',
      );
      final pcmLarge = extractPcmFromWav(resultLarge);
      expect(
          pcmLarge.length, greaterThanOrEqualTo(640)); // 320 frames * 2 bytes

      // Larger input should produce larger output
      expect(pcmLarge.length, greaterThan(pcmSmall.length));
    });

    test('extractAudio reports progress during extraction', () async {
      final mp4Bytes = buildMinimalMp4WithPcmAudio(pcmFrames: 160);
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
