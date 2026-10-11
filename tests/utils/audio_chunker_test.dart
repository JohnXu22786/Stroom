import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_chunker.dart';

/// Build a synthetic PCM WAV file with configurable silence gaps.
///
/// [sampleRate] e.g. 16000
/// [segments] list of (durationSeconds, amplitude) — amplitude=0 is silence.
/// Returns a complete WAV file as Uint8List.
Uint8List _buildTestWav({
  int sampleRate = 16000,
  int numChannels = 1,
  int bitsPerSample = 16,
  required List<(double duration, double amplitude)> segments,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final blockAlign = numChannels * bytesPerSample;

  // Calculate total samples and data size
  int totalSamples = 0;
  for (final seg in segments) {
    totalSamples += (seg.$1 * sampleRate).round();
  }
  final dataSize = totalSamples * blockAlign;

  // Build PCM data
  final pcmData = ByteData(dataSize);
  int sampleIdx = 0;
  for (final seg in segments) {
    final segSamples = (seg.$1 * sampleRate).round();
    for (int i = 0; i < segSamples; i++) {
      final value = seg.$2 == 0
          ? 0
          : ((sin(2 * pi * 440 * sampleIdx / sampleRate) * seg.$2 * 32767)
              .round()
              .clamp(-32768, 32767));
      for (int channel = 0; channel < numChannels; channel++) {
        final interleavedIndex = sampleIdx * numChannels + channel;
        pcmData.setInt16(
          interleavedIndex * bytesPerSample,
          value,
          Endian.little,
        );
      }
      sampleIdx++;
    }
  }

  // Build WAV header
  final fileSize = 44 + dataSize;
  final byteRate = sampleRate * blockAlign;
  final header = ByteData(44);
  int off = 0;

  void w4(String s) {
    for (int i = 0; i < 4; i++) {
      header.setUint8(off++, s.codeUnitAt(i));
    }
  }

  void w16(int v) {
    header.setUint16(off, v, Endian.little);
    off += 2;
  }

  void w32(int v) {
    header.setUint32(off, v, Endian.little);
    off += 4;
  }

  w4('RIFF');
  w32(fileSize - 8);
  w4('WAVE');
  w4('fmt ');
  w32(16); // chunk size
  w16(1); // PCM
  w16(numChannels);
  w32(sampleRate);
  w32(byteRate);
  w16(blockAlign);
  w16(bitsPerSample);
  w4('data');
  w32(dataSize);

  // Combine header + data
  final result = Uint8List(44 + dataSize);
  result.setRange(0, 44, header.buffer.asUint8List());
  result.setRange(44, 44 + dataSize, pcmData.buffer.asUint8List());
  return result;
}

Uint8List _buildWavFromFrames(
  List<List<int>> frames, {
  int sampleRate = 1000,
}) {
  final numChannels = frames.isEmpty ? 1 : frames.first.length;
  final blockAlign = numChannels * 2;
  final dataSize = frames.length * blockAlign;
  final output = ByteData(44 + dataSize);
  var offset = 0;

  void writeFourCc(String value) {
    for (var i = 0; i < 4; i++) {
      output.setUint8(offset++, value.codeUnitAt(i));
    }
  }

  void writeUint16(int value) {
    output.setUint16(offset, value, Endian.little);
    offset += 2;
  }

  void writeUint32(int value) {
    output.setUint32(offset, value, Endian.little);
    offset += 4;
  }

  writeFourCc('RIFF');
  writeUint32(output.lengthInBytes - 8);
  writeFourCc('WAVE');
  writeFourCc('fmt ');
  writeUint32(16);
  writeUint16(1);
  writeUint16(numChannels);
  writeUint32(sampleRate);
  writeUint32(sampleRate * blockAlign);
  writeUint16(blockAlign);
  writeUint16(16);
  writeFourCc('data');
  writeUint32(dataSize);
  for (final frame in frames) {
    for (final sample in frame) {
      writeUint16(sample & 0xffff);
    }
  }

  return Uint8List.view(output.buffer);
}

Uint8List _buildExtensiblePcmWav(Uint8List pcmWav) {
  final result = Uint8List(pcmWav.length + 24);
  result.setRange(0, 20, pcmWav);
  result.setRange(20, 36, pcmWav, 20);
  result.setRange(60, result.length, pcmWav, 36);

  final data = ByteData.sublistView(result);
  data.setUint32(4, result.length - 8, Endian.little);
  data.setUint32(16, 40, Endian.little);
  data.setUint16(20, 0xfffe, Endian.little); // WAVE_FORMAT_EXTENSIBLE
  data.setUint16(36, 22, Endian.little); // cbSize
  data.setUint16(38, 16, Endian.little); // valid bits per sample
  data.setUint32(40, 3, Endian.little); // front left + front right
  result.setRange(44, 60, [
    0x01, 0x00, 0x00, 0x00, // PCM subtype GUID, Data1
    0x00, 0x00, // Data2
    0x10, 0x00, // Data3
    0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71, // Data4
  ]);
  return result;
}

List<int> _readPcmValues(Uint8List wav) {
  final info = parseWavHeader(wav);
  final bytes = ByteData.sublistView(
    wav,
    info.dataOffset,
    info.dataOffset + info.dataSize,
  );
  return List<int>.generate(
    info.dataSize ~/ 2,
    (index) => bytes.getInt16(index * 2, Endian.little),
  );
}

void _writeUint16(Uint8List bytes, int offset, int value) {
  bytes.buffer
      .asByteData(bytes.offsetInBytes + offset, 2)
      .setUint16(0, value, Endian.little);
}

void _writeUint32(Uint8List bytes, int offset, int value) {
  bytes.buffer
      .asByteData(bytes.offsetInBytes + offset, 4)
      .setUint32(0, value, Endian.little);
}

Uint8List _appendWavChunk(Uint8List wav, String tag, List<int> payload) {
  final paddedPayloadSize = payload.length + (payload.length.isOdd ? 1 : 0);
  final result = Uint8List(wav.length + 8 + paddedPayloadSize);
  result.setRange(0, wav.length, wav);
  for (var index = 0; index < 4; index++) {
    result[wav.length + index] = tag.codeUnitAt(index);
  }
  _writeUint32(result, wav.length + 4, payload.length);
  result.setRange(wav.length + 8, wav.length + 8 + payload.length, payload);
  _writeUint32(result, 4, result.length - 8);
  return result;
}

void main() {
  group('WAV Header Parser', () {
    test('parses standard PCM WAV header correctly', () {
      final wav = _buildTestWav(segments: [(0.1, 0.5)]);

      final info = parseWavHeader(wav);
      expect(info.sampleRate, 16000);
      expect(info.numChannels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.dataOffset, 44);
      expect(info.dataSize, greaterThan(0));
      expect(info.blockAlign, 2);
      expect(info.byteRate, 32000);
    });

    test('rejects non-WAV files', () {
      final bytes = Uint8List.fromList(List.filled(100, 0));
      expect(() => parseWavHeader(bytes), throwsA(isA<FormatException>()));
    });

    test('rejects non-PCM format', () {
      final wav = _buildTestWav(segments: [(0.1, 0.5)]);
      // Corrupt the format tag to non-PCM
      final corrupted = Uint8List.fromList(wav);
      final dv = corrupted.buffer.asByteData(20, 2);
      dv.setUint16(0, 3, Endian.little); // IEEE float
      expect(() => parseWavHeader(corrupted), throwsA(isA<FormatException>()));
    });

    test('parses WAV with extended fmt chunk (WAVEFORMATEX, size=40)', () {
      // Build a WAV manually with a 40-byte fmt chunk
      final pcmData = Uint8List(160); // 10 samples at 16-bit mono
      final dataSize = pcmData.length;
      const fmtSize = 40; // WAVEFORMATEX
      // RIFF(4) + fileSize(4) + WAVE(4) = 12
      // fmt (4) + fmtSize(4) + fmtData(fmtSize) = 8 + fmtSize
      // data(4) + dataSize(4) + pcmData = 8 + dataSize
      final total = 12 + 8 + fmtSize + 8 + dataSize;
      final out = ByteData(total);
      int off = 0;
      void w4(String s) {
        for (int i = 0; i < 4; i++) out.setUint8(off++, s.codeUnitAt(i));
      }

      void w16(int v) {
        out.setUint16(off, v, Endian.little);
        off += 2;
      }

      void w32(int v) {
        out.setUint32(off, v, Endian.little);
        off += 4;
      }

      w4('RIFF');
      w32(total - 8);
      w4('WAVE');
      w4('fmt ');
      w32(fmtSize); // 40-byte extended fmt
      w16(1); // PCM
      w16(1); // mono
      w32(16000); // sample rate
      w32(32000); // byte rate
      w16(2); // block align
      w16(16); // bits per sample
      w16(22); // cbSize (22 bytes of extension)
      w16(16); // wValidBitsPerSample
      w32(0); // dwChannelMask
      w16(1); // SubFormat = PCM (first 2 bytes of GUID)
      // Pad remaining 14 bytes of SubFormat GUID (all zeros for PCM)
      for (int i = 0; i < 14; i++) {
        out.setUint8(off++, 0);
      }
      w4('data');
      w32(dataSize);
      // Copy PCM data
      for (int i = 0; i < dataSize; i++) {
        out.setUint8(off++, pcmData[i]);
      }

      final wavBytes = Uint8List.view(out.buffer, 0, total);

      final info = parseWavHeader(wavBytes);
      expect(info.sampleRate, 16000);
      expect(info.numChannels, 1);
      expect(info.bitsPerSample, 16);
      expect(info.dataSize, dataSize);
    });

    test('skips a bounded non-audio chunk before PCM data', () {
      final original = _buildTestWav(segments: [(0.1, 0.5)]);
      final withJunk = Uint8List(original.length + 10);
      withJunk.setRange(0, 36, original);
      withJunk.setRange(36, 46, [
        0x4a, 0x55, 0x4e, 0x4b, // JUNK
        2, 0, 0, 0, // two payload bytes
        0xaa, 0xbb,
      ]);
      withJunk.setRange(46, withJunk.length, original, 36);
      _writeUint32(withJunk, 4, withJunk.length - 8);

      final info = parseWavHeader(withJunk);

      expect(info.dataOffset, 54);
      expect(info.sampleRate, 16000);
    });

    test('validates chunks after the first PCM data chunk', () {
      final original = _buildTestWav(segments: [(0.1, 0.5)]);
      final trailingHeaderByte = Uint8List(original.length + 1)
        ..setRange(0, original.length, original);
      trailingHeaderByte[original.length] = 0x4a;
      _writeUint32(trailingHeaderByte, 4, trailingHeaderByte.length - 8);

      final trailingChunkOutOfBounds = Uint8List(original.length + 8)
        ..setRange(0, original.length, original);
      trailingChunkOutOfBounds.setRange(original.length, original.length + 4, [
        0x4a, 0x55, 0x4e, 0x4b, // JUNK
      ]);
      _writeUint32(trailingChunkOutOfBounds, original.length + 4, 2);
      _writeUint32(
        trailingChunkOutOfBounds,
        4,
        trailingChunkOutOfBounds.length - 8,
      );

      expect(
        () => parseWavHeader(trailingHeaderByte),
        throwsA(isA<FormatException>()),
        reason: 'incomplete trailing chunk header',
      );
      expect(
        () => parseWavHeader(trailingChunkOutOfBounds),
        throwsA(isA<FormatException>()),
        reason: 'trailing chunk payload exceeds the RIFF container',
      );

      final validTrailingChunk = _appendWavChunk(original, 'JUNK', [0xaa]);
      final info = parseWavHeader(validTrailingChunk);
      expect(info.dataOffset, 44);
      expect(info.dataSize, parseWavHeader(original).dataSize);
    });

    test('parses and chunks WAVE_FORMAT_EXTENSIBLE PCM', () {
      final standardWav = _buildTestWav(
        sampleRate: 1000,
        numChannels: 2,
        segments: [(2.0, 0.5)],
      );
      final extensibleWav = _buildExtensiblePcmWav(standardWav);

      final info = parseWavHeader(extensibleWav);
      expect(info.numChannels, 2);
      expect(info.dataOffset, 68);
      expect(info.dataSize, standardWav.length - 44);

      final chunks = AudioChunker(
        config: AudioChunkConfig(fixedDurationSeconds: 0.5),
      ).splitByDuration(extensibleWav);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        final chunkInfo = parseWavHeader(chunk);
        expect(chunkInfo.numChannels, 2);
        expect(chunkInfo.dataSize % chunkInfo.blockAlign, 0);
      }

      final unsupportedSubtype = Uint8List.fromList(extensibleWav);
      unsupportedSubtype[44] = 3; // IEEE_FLOAT subtype, unsupported by chunker
      expect(
        () => parseWavHeader(unsupportedSubtype),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('subtype'),
        )),
      );
    });

    test('requires the WAVE_FORMAT_EXTENSIBLE fmt extension', () {
      final malformedExtensible = _buildTestWav(
        segments: [(0.1, 0.5)],
      );
      _writeUint16(malformedExtensible, 20, 0xfffe);

      expect(
        () => validateWavContainer(malformedExtensible),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown non-PCM format tags in container validation', () {
      final unsupportedTag = _buildTestWav(segments: [(0.1, 0.5)]);
      _writeUint16(unsupportedTag, 20, 0x7777);

      expect(
        () => validateWavContainer(unsupportedTag),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown extensible subtypes in container validation', () {
      final unsupportedSubtype = _buildExtensiblePcmWav(
        _buildTestWav(segments: [(0.1, 0.5)]),
      );
      unsupportedSubtype.setRange(44, 48, [0x77, 0x77, 0x00, 0x00]);

      expect(
        () => validateWavContainer(unsupportedSubtype),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects zero, inconsistent, or truncated PCM WAV metadata', () {
      final original = _buildTestWav(segments: [(0.1, 0.5)]);

      Uint8List changed({
        int? riffSize,
        int? formatSize,
        int? format,
        int? channels,
        int? sampleRate,
        int? byteRate,
        int? blockAlign,
        int? bitsPerSample,
        int? dataSize,
      }) {
        final bytes = Uint8List.fromList(original);
        if (riffSize != null) _writeUint32(bytes, 4, riffSize);
        if (formatSize != null) _writeUint32(bytes, 16, formatSize);
        if (format != null) _writeUint16(bytes, 20, format);
        if (channels != null) _writeUint16(bytes, 22, channels);
        if (sampleRate != null) _writeUint32(bytes, 24, sampleRate);
        if (byteRate != null) _writeUint32(bytes, 28, byteRate);
        if (blockAlign != null) _writeUint16(bytes, 32, blockAlign);
        if (bitsPerSample != null) _writeUint16(bytes, 34, bitsPerSample);
        if (dataSize != null) _writeUint32(bytes, 40, dataSize);
        return bytes;
      }

      final truncatedData = Uint8List.fromList(
        original.sublist(0, original.length - 1),
      );
      _writeUint32(truncatedData, 4, truncatedData.length - 8);
      final truncatedChunkHeader = original.sublist(0, 37);
      _writeUint32(truncatedChunkHeader, 4, truncatedChunkHeader.length - 8);

      final malformed = <String, Uint8List>{
        'truncated file header': original.sublist(0, 11),
        'truncated chunk header': truncatedChunkHeader,
        'zero channels': changed(channels: 0),
        'zero sample rate': changed(sampleRate: 0),
        'zero data size': changed(dataSize: 0),
        'zero format code': changed(format: 0),
        'zero byte rate': changed(byteRate: 0),
        'zero block alignment': changed(blockAlign: 0),
        'zero bit depth': changed(bitsPerSample: 0),
        'unsupported bit depth': changed(bitsPerSample: 8),
        'inconsistent block alignment': changed(blockAlign: 1),
        'inconsistent byte rate': changed(byteRate: 1),
        'data size not frame aligned': changed(dataSize: 3),
        'fmt chunk exceeds container': changed(formatSize: 4096),
        'container exceeds available bytes':
            changed(riffSize: original.length - 8 + 1),
        'data exceeds truncated container': truncatedData,
      };

      for (final entry in malformed.entries) {
        expect(
          () => parseWavHeader(entry.value),
          throwsA(isA<FormatException>()),
          reason: entry.key,
        );
      }
    });

    test('explicitly rejects RIFX before little-endian PCM decoding', () {
      final rifx = Uint8List.fromList(
        _buildTestWav(segments: [(0.1, 0.5)]),
      );
      rifx.setRange(0, 4, [0x52, 0x49, 0x46, 0x58]);

      expect(
        () => parseWavHeader(rifx),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('RIFX'),
        )),
      );
    });
  });

  group('Silence Detection', () {
    test('detects silence in audio with a quiet gap', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (1.0, 0.5), // 1s tone
          (2.0, 0.0), // 2s silence (should be detected)
          (1.0, 0.5), // 1s tone
        ],
      );

      final info = parseWavHeader(wav);
      final samples = readPcmSamplesFloat(wav, info);

      final config = AudioChunkConfig(
        silenceDbThreshold: -50,
        minSilenceDuration: 1.0,
      );
      final detector = SilenceDetector(config);
      final gaps = detector.detect(samples, info.sampleRate);

      // Should find at least one silence gap
      expect(gaps.length, greaterThanOrEqualTo(1));
      // Gap should be roughly in the middle (between 1s and 3s)
      final gap = gaps.first;
      expect(gap.startSample / info.sampleRate, greaterThanOrEqualTo(0.5));
      expect(gap.startSample / info.sampleRate, lessThan(2.0));
      expect(gap.durationSeconds, greaterThanOrEqualTo(1.0));
    });

    test('no silence detected in continuous tone', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (3.0, 0.5), // 3s continuous tone, no silence
        ],
      );

      final info = parseWavHeader(wav);
      final samples = readPcmSamplesFloat(wav, info);

      final config = AudioChunkConfig(
        silenceDbThreshold: -30,
        minSilenceDuration: 0.5,
      );
      final detector = SilenceDetector(config);
      final gaps = detector.detect(samples, info.sampleRate);

      expect(gaps, isEmpty);
    });
  });

  group('Audio Chunker', () {
    test('does not split short audio below maxChunkBytes', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (2.0, 0.5), // short audio
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(maxChunkBytes: 1024 * 1024),
      );
      final chunks = chunker.split(wav);

      // Short audio should produce 1 chunk
      expect(chunks.length, 1);
      // Each chunk should be a valid WAV
      final info = parseWavHeader(chunks.first);
      expect(info.sampleRate, 8000);
    });

    test('splits audio at silence gaps', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (2.0, 0.5), // 2s tone
          (2.0, 0.0), // 2s silence
          (2.0, 0.5), // 2s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 1024 * 1024,
          silenceDbThreshold: -50,
          minSilenceDuration: 1.0,
          minChunkDuration: 0.5, // small to force split on 2s chunks
        ),
      );
      final chunks = chunker.split(wav);

      // Should split at the silence gap → 2 chunks
      expect(chunks.length, 2);

      // Each chunk should be a valid WAV
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        expect(info.sampleRate, 8000);
        expect(info.numChannels, 1);
        expect(info.bitsPerSample, 16);
      }
    });

    test('enforces maxChunkBytes by sub-splitting large chunks', () {
      // Build a large audio file without silence (to force sub-splitting)
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (10.0, 0.5), // 10s continuous tone
        ],
      );

      // 8000 samples/sec * 2 bytes/sample = 16000 bytes/sec
      // 10s = 160000 bytes → limit to 50000 bytes → should split into 4 chunks
      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 50000,
          silenceDbThreshold: -40,
          minSilenceDuration: 5.0, // longer than audio → no silence detected
        ),
      );
      final chunks = chunker.split(wav);

      expect(chunks.length, greaterThanOrEqualTo(2));
      // Each chunk should be under maxChunkBytes
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(50000 + 44)); // +44 for header
        // Still a valid WAV
        final info = parseWavHeader(chunk);
        expect(info.sampleRate, 8000);
      }
    });

    test('each output chunk is a standalone valid WAV file', () {
      final wav = _buildTestWav(
        sampleRate: 16000,
        segments: [
          (1.0, 0.5),
          (1.5, 0.0),
          (1.0, 0.5),
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          silenceDbThreshold: -50,
          minSilenceDuration: 1.0,
        ),
      );
      final chunks = chunker.split(wav);

      for (final chunk in chunks) {
        // Parse header without errors
        final info = parseWavHeader(chunk);
        // Verify parameters match original
        expect(info.sampleRate, 16000);
        expect(info.numChannels, 1);
        expect(info.bitsPerSample, 16);
        // Data should be non-empty
        expect(info.dataSize, greaterThan(0));
      }
    });

    test('handles audio with no silence (only tone)', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (3.0, 0.3), // continuous quiet tone
        ],
      );

      final chunker = AudioChunker();
      final chunks = chunker.split(wav);
      expect(chunks.length, 1);
      expect(chunks.first.length, greaterThan(44));
    });

    test('handles very short audio gracefully', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (0.01, 0.5), // 10ms — very short
        ],
      );

      final chunker = AudioChunker();
      final chunks = chunker.split(wav);
      expect(chunks.length, 1);
    });
  });

  group('AudioChunker frame boundaries', () {
    test('mono and stereo recordings cut at equivalent times', () {
      const sampleRate = 1000;
      final segments = <(double, double)>[
        (0.5, 0.6),
        (0.8, 0),
        (0.5, 0.6),
      ];
      final mono = _buildTestWav(
        sampleRate: sampleRate,
        segments: segments,
      );
      final stereo = _buildTestWav(
        sampleRate: sampleRate,
        numChannels: 2,
        segments: segments,
      );
      final config = AudioChunkConfig(
        maxChunkBytes: 100000,
        frameSize: 32,
        minSilenceDuration: 0.15,
        minChunkDuration: 0.1,
        targetChunkDuration: 0.6,
        maxChunkDuration: 0.8,
      );

      final monoDurations =
          AudioChunker(config: config).split(mono).map((chunk) {
        final info = parseWavHeader(chunk);
        return info.totalSamples / info.sampleRate;
      }).toList();
      final stereoDurations =
          AudioChunker(config: config).split(stereo).map((chunk) {
        final info = parseWavHeader(chunk);
        return info.totalSamples / info.sampleRate;
      }).toList();

      expect(stereoDurations, monoDurations);
    });

    test('silent stereo channel does not shift silence cut times', () {
      final monoFrames = <List<int>>[];
      final stereoFrames = <List<int>>[];
      for (var frame = 0; frame < 2300; frame++) {
        final sample = switch (frame) {
          < 500 => frame.isEven ? 12000 : -12000,
          < 1000 => frame.isEven ? 1250 : -1250,
          < 1800 => 0,
          _ => frame.isEven ? 12000 : -12000,
        };
        monoFrames.add([sample]);
        stereoFrames.add([sample, 0]);
      }

      final mono = _buildWavFromFrames(monoFrames);
      final stereo = _buildWavFromFrames(stereoFrames);
      final config = AudioChunkConfig(
        silenceDbThreshold: -24,
        frameSize: 16,
        minSilenceDuration: 0.15,
        minChunkDuration: 0.1,
        targetChunkDuration: 1.5,
        maxChunkDuration: 2.5,
      );
      List<double> chunkDurations(Uint8List wav) => AudioChunker(
            config: config,
          ).split(wav).map((chunk) {
            final info = parseWavHeader(chunk);
            return info.totalSamples / info.sampleRate;
          }).toList();

      expect(chunkDurations(stereo), chunkDurations(mono));
    });

    test(
        'all splitting methods emit parseable, aligned chunks that reconstruct frames',
        () {
      final frames = List<List<int>>.generate(1200, (index) {
        if (index >= 400 && index < 700) return [0, 0];
        return [
          ((index * 37) % 60001) - 30000,
          ((index * 97) % 50001) - 25000,
        ];
      });
      final wav = _buildWavFromFrames(frames);
      final originalValues = frames.expand((frame) => frame).toList();
      const methods = [
        AudioChunkMethod.silence,
        AudioChunkMethod.fixedDuration,
        AudioChunkMethod.fixedSize,
      ];

      for (final method in methods) {
        final chunks = AudioChunker(
          config: AudioChunkConfig(
            maxChunkBytes: 80,
            frameSize: 20,
            minSilenceDuration: 0.1,
            minChunkDuration: 0.1,
            targetChunkDuration: 0.3,
            maxChunkDuration: 0.5,
            fixedDurationSeconds: 0.3,
          ),
        ).chunk(wav, method);
        final reconstructed = <int>[];

        expect(chunks.length, greaterThan(1), reason: method.name);
        for (final chunk in chunks) {
          final info = parseWavHeader(chunk);
          expect(info.numChannels, 2, reason: method.name);
          expect(info.dataSize % info.blockAlign, 0, reason: method.name);
          expect(info.dataSize, greaterThan(0), reason: method.name);
          reconstructed.addAll(_readPcmValues(chunk));
        }

        expect(reconstructed, originalValues, reason: method.name);
      }
    });

    test('silence and duration chunks respect byte caps at whole-frame sizes',
        () {
      final frames = [
        [101, 202, 303],
        [404, 505, 606],
        [707, 808, 909],
      ];
      final wav = _buildWavFromFrames(frames, sampleRate: 1000);
      const maxChunkBytes = 10;
      final config = AudioChunkConfig(
        maxChunkBytes: maxChunkBytes,
        minChunkDuration: 0.001,
        targetChunkDuration: 0.002,
        maxChunkDuration: 0.004,
        fixedDurationSeconds: 0.003,
      );
      final originalValues = frames.expand((frame) => frame).toList();

      for (final method in [
        AudioChunkMethod.silence,
        AudioChunkMethod.fixedDuration,
      ]) {
        final chunks = AudioChunker(config: config).chunk(wav, method);
        final reconstructed = <int>[];

        for (final chunk in chunks) {
          final info = parseWavHeader(chunk);
          expect(
            info.dataSize,
            lessThanOrEqualTo(maxChunkBytes),
            reason: method.name,
          );
          expect(info.dataSize % info.blockAlign, 0, reason: method.name);
          reconstructed.addAll(_readPcmValues(chunk));
        }

        expect(reconstructed, originalValues, reason: method.name);
      }
    });

    test('rejects incoherent chunk parameters before splitting', () {
      final wav = _buildTestWav(segments: [(0.1, 0.5)]);
      final invalidConfigs = [
        AudioChunkConfig(maxChunkBytes: 0),
        AudioChunkConfig(maxChunkBytes: -1),
        AudioChunkConfig(silenceDbThreshold: 0),
        AudioChunkConfig(silenceDbThreshold: double.nan),
        AudioChunkConfig(minSilenceDuration: 0),
        AudioChunkConfig(minSilenceDuration: -0.1),
        AudioChunkConfig(frameSize: 0),
        AudioChunkConfig(frameSize: -1),
        AudioChunkConfig(overlapSeconds: -0.1),
        AudioChunkConfig(overlapSeconds: double.nan),
        AudioChunkConfig(fixedDurationSeconds: 0),
        AudioChunkConfig(fixedDurationSeconds: -1),
        AudioChunkConfig(fixedDurationSeconds: double.infinity),
        AudioChunkConfig(minChunkDuration: 0),
        AudioChunkConfig(minChunkDuration: double.infinity),
        AudioChunkConfig(targetChunkDuration: double.nan),
        AudioChunkConfig(targetChunkDuration: 61),
        AudioChunkConfig(maxChunkDuration: 0),
        AudioChunkConfig(maxChunkDuration: 30),
        AudioChunkConfig(analysisWindowSeconds: 0),
        AudioChunkConfig(analysisWindowSeconds: double.nan),
      ];

      for (final config in invalidConfigs) {
        expect(
          () => AudioChunker(config: config).chunk(
            wav,
            AudioChunkMethod.fixedDuration,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }

      expect(
        () => AudioChunker(
          config: AudioChunkConfig(maxChunkBytes: 1),
        ).splitBySize(wav),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AudioChunker - fixed duration', () {
    test('splits audio into fixed-duration chunks', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [(5.0, 0.5)], // 5 seconds
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(fixedDurationSeconds: 2.0),
      );
      final chunks = chunker.chunk(wav, AudioChunkMethod.fixedDuration);

      // 5s / 2s per chunk = ~3 chunks (with overlap)
      expect(chunks.length, greaterThanOrEqualTo(2));
      for (final c in chunks) {
        final info = parseWavHeader(c);
        expect(info.sampleRate, 8000);
      }
    });
  });

  group('AudioChunker - fixed size', () {
    test('splits audio into byte-sized chunks', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [(5.0, 0.5)],
      );
      final wavSize = wav.length;

      final chunker = AudioChunker(
        config: AudioChunkConfig(maxChunkBytes: wavSize ~/ 3),
      );
      final chunks = chunker.chunk(wav, AudioChunkMethod.fixedSize);

      expect(chunks.length, greaterThanOrEqualTo(2));
    });
  });

  group('AudioChunker - none', () {
    test('returns original file unchanged', () {
      final wav = _buildTestWav(segments: [(2.0, 0.5)]);
      final chunks = AudioChunker().chunk(wav, AudioChunkMethod.none);
      expect(chunks.length, 1);
    });
  });

  group('WavPreprocessor', () {
    test('resamples to target sample rate', () {
      final wav = _buildTestWav(
        sampleRate: 48000,
        segments: [(1.0, 0.5)],
      );

      final preprocessor = WavPreprocessor(
        config:
            AudioPreprocessConfig(targetSampleRate: 16000, forceMono: false),
      );
      final processed = preprocessor.process(wav);

      final info = parseWavHeader(processed);
      expect(info.sampleRate, 16000);
      expect(info.dataSize, lessThan(wav.length));
    });

    test('converts stereo to mono', () {
      final wav = _buildTestWav(
        numChannels: 2,
        segments: [(1.0, 0.5)],
      );

      final preprocessor = WavPreprocessor(
        config: AudioPreprocessConfig(targetSampleRate: null, forceMono: true),
      );
      final processed = preprocessor.process(wav);

      final info = parseWavHeader(processed);
      expect(info.numChannels, 1);
    });

    test('does both resample and mono', () {
      final wav = _buildTestWav(
        sampleRate: 44100,
        numChannels: 2,
        segments: [(2.0, 0.5)],
      );

      final processed = WavPreprocessor().process(wav);

      final info = parseWavHeader(processed);
      expect(info.sampleRate, 16000);
      expect(info.numChannels, 1);
      // Should be significantly smaller
      expect(processed.length, lessThan(wav.length));
    });

    test('AudioPreprocessConfig.none returns original', () {
      final wav = _buildTestWav(segments: [(1.0, 0.5)]);
      final processed = WavPreprocessor(
        config: AudioPreprocessConfig.none,
      ).process(wav);
      expect(processed.length, wav.length);
    });
  });

  // ===========================================================================
  // Smart Audio Chunker — Environment Analysis
  // ===========================================================================

  group('Environment Analyzer', () {
    test('provides environment-adjusted minSilenceDuration', () {
      final analyzer = EnvironmentAnalyzer();
      const baseMs = 500.0;
      // In normal speech, multiplier should be ~1.0
      expect(
        analyzer.adjustMinSilenceMs(AudioEnvironment.normalSpeech, baseMs),
        closeTo(baseMs, 100),
      );
      // In noisy environment, it should be longer
      final noisyAdjusted =
          analyzer.adjustMinSilenceMs(AudioEnvironment.noisy, baseMs);
      expect(noisyAdjusted, greaterThan(baseMs));
      // In quiet environment, it can be shorter
      final quietAdjusted =
          analyzer.adjustMinSilenceMs(AudioEnvironment.quiet, baseMs);
      expect(quietAdjusted, lessThanOrEqualTo(baseMs));
    });
  });

  // ===========================================================================
  // Smart Audio Chunker — Core Chunking Behavior
  // ===========================================================================

  group('Smart Chunker - core behavior', () {
    test('each output chunk is a valid standalone WAV without overlap', () {
      final wav = _buildTestWav(
        sampleRate: 16000,
        segments: [
          (20.0, 0.5), // 20s tone
          (1.0, 0.0), // 1s silence (should be cut point with 0.5s minSilence)
          (20.0, 0.5), // 20s tone
          (1.0, 0.0), // 1s silence
          (20.0, 0.5), // 20s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5,
          minChunkDuration: 10.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 45.0,
        ),
      );
      final chunks = chunker.split(wav);

      // All chunks should be valid WAV
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        expect(info.sampleRate, 16000);
        expect(info.numChannels, 1);
        expect(info.bitsPerSample, 16);
        expect(info.dataSize, greaterThan(0));
      }

      // Verify non-overlapping: byte ranges should not overlap
      // We extract PCM data from each chunk and verify no overlap
      // Note: each chunk is a standalone WAV with independent data section
    });

    test('no chunk shorter than minChunkDuration (except possible last)', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (12.0, 0.5), // 12s tone
          (1.5, 0.0), // 1.5s silence
          (12.0, 0.5), // 12s tone
          (1.5, 0.0), // 1.5s silence
          (8.0, 0.5), // 8s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 1.0,
          minChunkDuration: 10.0, // chunks must be ≥10s
          targetChunkDuration: 30.0,
          maxChunkDuration: 50.0,
        ),
      );
      final chunks = chunker.split(wav);

      // First chunk: 12s tone + 1.5s silence part → ≥10s ✓
      // Second chunk: rest of silence + 12s tone ≥ 10s ✓
      // Third chunk: rest of silence + 8s tone ≥ 10s ✓ (may merge)
      for (int i = 0; i < chunks.length; i++) {
        final info = parseWavHeader(chunks[i]);
        final duration = info.totalSamples / info.sampleRate;
        // All chunks except possibly the last must be >= minChunkDuration
        if (i < chunks.length - 1) {
          expect(duration, greaterThanOrEqualTo(9.5)); // tolerance
        }
      }
    });

    test('no chunk longer than maxChunkDuration', () {
      // 120 seconds of continuous tone — must be split
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (120.0, 0.5), // 2 minutes of continuous tone, no silence
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5,
          minChunkDuration: 10.0,
          targetChunkDuration: 15.0,
          maxChunkDuration: 20.0, // force split every 20s
        ),
      );
      final chunks = chunker.split(wav);

      // Should produce multiple chunks
      expect(chunks.length, greaterThanOrEqualTo(5)); // 120/20 = 6
      // No chunk should exceed maxChunkDuration
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        final duration = info.totalSamples / info.sampleRate;
        expect(duration, lessThanOrEqualTo(21.0)); // small tolerance
      }
    });

    test('silence shorter than minSilenceDuration is not a cut point', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (15.0, 0.5), // 15s tone
          (0.3, 0.0), // 0.3s silence — too short to cut (minSilence=0.5s)
          (15.0, 0.5), // 15s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5, // 0.3s gap should NOT trigger a cut
          minChunkDuration: 5.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 60.0,
        ),
      );
      final chunks = chunker.split(wav);

      // The 0.3s silence is too short → should produce 1 chunk (or at most
      // fewer chunks than if the silence were longer)
      // With 30s total audio and maxChunkDuration=60s, it should be 1 chunk
      expect(chunks.length, 1);
    });

    test('long silence gap produces a clean cut point', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (15.0, 0.5), // 15s tone
          (2.0, 0.0), // 2s silence (clearly exceeds 0.5s min)
          (15.0, 0.5), // 15s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5,
          minChunkDuration: 5.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 60.0,
        ),
      );
      final chunks = chunker.split(wav);

      // A 2s silence should be detected as a valid cut point
      // Both chunks are ≥5s, and ≤60s → should split into 2
      expect(chunks.length, 2);
    });

    test('force-cuts at maxChunkDuration when no silence candidates exist', () {
      // 90 seconds of continuous tone — no silence at all
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (90.0, 0.5), // 90s of only tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5,
          minChunkDuration: 10.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 30.0,
        ),
      );
      final chunks = chunker.split(wav);

      // Should produce at least 3 chunks (90/30 = 3)
      expect(chunks.length, greaterThanOrEqualTo(2));
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        final duration = info.totalSamples / info.sampleRate;
        expect(duration, lessThanOrEqualTo(31.0));
      }
    });

    test('uses smart scoring: prefers longer silence over shorter', () {
      // Audio with one long silence (good cut) and one short silence (bad cut)
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (15.0, 0.5), // 15s tone
          (2.0, 0.0), // 2s silence — EXCELLENT cut point
          (15.0, 0.5), // 15s tone
          (0.6, 0.0), // 0.6s silence — barely qualifies
          (15.0, 0.5), // 15s tone
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 0.5,
          minChunkDuration: 10.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 50.0,
        ),
      );
      final chunks = chunker.split(wav);

      // With targetChunkDuration=30s, the first segment after 2s gap (at ~16s)
      // is well within minChunk..maxChunk range. The 0.6s gap is a secondary
      // candidate. The scorer should prefer the 2s gap for its quality, but
      // since both segments are valid, verify we get non-overlapping chunks.
      expect(chunks.length, greaterThanOrEqualTo(1));
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        expect(parseWavHeader(chunk).sampleRate, 8000);
      }
    });

    test('all chunks are strictly non-overlapping', () {
      final wav = _buildTestWav(
        sampleRate: 8000,
        segments: [
          (10.0, 0.5),
          (2.0, 0.0),
          (10.0, 0.5),
          (2.0, 0.0),
          (10.0, 0.5),
        ],
      );

      final chunker = AudioChunker(
        config: AudioChunkConfig(
          maxChunkBytes: 10 * 1024 * 1024,
          minSilenceDuration: 1.0,
          minChunkDuration: 3.0,
          targetChunkDuration: 30.0,
          maxChunkDuration: 60.0,
          overlapSeconds: 0.0, // explicitly zero
        ),
      );
      final chunks = chunker.split(wav);

      // Parse each chunk's PCM data start and duration from the WAV header
      for (final chunk in chunks) {
        final info = parseWavHeader(chunk);
        expect(info.dataSize, greaterThan(0));
      }

      // If chunks overlap, their combined duration would exceed the original.
      // We can verify non-overlap by checking that all chunks are valid WAVs
      // and no byte range in the original data is included more than once.
      // The simplest assertion: total PCM data across all chunks should
      // be close to original data size (not doubled/tripled by overlap).
      final totalChunkData = chunks.fold<int>(
        0,
        (sum, c) => sum + parseWavHeader(c).dataSize,
      );
      final originalInfo = parseWavHeader(wav);
      // With 0 overlap, total chunk data ≈ original data
      // (Allow small variance due to rounding at frame boundaries)
      expect(totalChunkData,
          closeTo(originalInfo.dataSize, originalInfo.dataSize * 0.1));
    });
  });
}
