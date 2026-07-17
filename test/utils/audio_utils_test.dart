import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_utils.dart';

void main() {
  group('detectAudioFormat', () {
    test('detects M4A with different box size prefix', () {
      // Larger box size
      final data =
          Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]);
      expect(detectAudioFormat(data), equals('m4a'));
    });

    test('returns pcm for data smaller than 4 bytes', () {
      final data = Uint8List.fromList([0x00, 0x01, 0x02]);
      expect(detectAudioFormat(data), equals('pcm'));
    });

    test('detects AAC ADTS and does not confuse with MP3', () {
      // AAC ADTS frame header: sync=0xFFF, MPEG-4, layer=00
      // Byte 2: profile(1)<<6 | freqIdx(4)<<2 | chanConfig_h(2)
      // Byte 3: chanConfig_l<<6 | frameLen_h<<2  ...
      final data = Uint8List.fromList([
        0xFF, 0xF1, // sync (12 bits) + ID(0=MPEG4) + layer(00) + protect(1)
        0x50, 0x80, // profile, freq, channels, frame length
      ]);
      expect(detectAudioFormat(data), equals('aac'));
    });

    test('detects regular MP3 sync (not confused with AAC)', () {
      // MPEG1 Layer3: sync=0xFFF, version=11, layer=01
      final data = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
      expect(detectAudioFormat(data), equals('mp3'));
    });

    test('detects MP3 with ID3 tag', () {
      final data = Uint8List.fromList([
        0x49, 0x44, 0x33, // ID3
        0x03, 0x00, 0x00, // version, flags
      ]);
      expect(detectAudioFormat(data), equals('mp3'));
    });
  });

  group('getMimeType', () {
    test('defaults to audio/wav for unknown format', () {
      expect(getMimeType('unknown'), equals('audio/wav'));
    });

    test('is case-insensitive', () {
      expect(getMimeType('MP3'), equals('audio/mpeg'));
      expect(getMimeType('WAV'), equals('audio/wav'));
      expect(getMimeType('M4A'), equals('audio/mp4'));
    });
  });

  group('ensureValidAudioFormat', () {
    test('converts PCM to WAV when requested format is wav', () {
      // Fake PCM data
      final pcmData = Uint8List.fromList(
          List.generate(160, (i) => i)); // 160 bytes = 80 samples at 16bit
      final result = ensureValidAudioFormat(pcmData,
          requestedFormat: 'wav', sampleRate: 24000);
      expect(result.$2, equals('wav'));
      // WAV header is 44 bytes + data
      expect(result.$1.length, greaterThan(pcmData.length));
    });

    test('detects and keeps actual format when it differs from requested', () {
      // WAV data requested as pcm
      final wavData = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ]);
      final result = ensureValidAudioFormat(wavData, requestedFormat: 'pcm');
      // Should detect it's actually wav and keep it
      expect(result.$2, equals('wav'));
    });
  });
}
