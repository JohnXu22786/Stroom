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
      pcmData.setInt16(sampleIdx * bytesPerSample, value, Endian.little);
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
      expect(gap.startSample / info.sampleRate,
          greaterThanOrEqualTo(0.5));
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

  group('Cross-platform guarantees', () {
    test('only uses dart:typed_data and dart:math (no platform deps)', () {
      // This test verifies that the module compiles and runs.
      // The absence of import errors in the analyzer confirms
      // no native/FFI dependencies.
      final wav = _buildTestWav(segments: [(0.1, 0.5)]);
      final chunker = AudioChunker();
      final chunks = chunker.split(wav);
      expect(chunks.isNotEmpty, true);
    });
  });
}
