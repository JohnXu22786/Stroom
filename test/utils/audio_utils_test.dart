import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_utils.dart';

void main() {
  group('detectAudioFormat', () {
    test('detects WAV from RIFF magic bytes', () {
      final data = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('wav'));
    });

    test('detects MP3 from ID3 magic bytes', () {
      final data = Uint8List.fromList([0x49, 0x44, 0x33, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('mp3'));
    });

    test('detects MP3 from MPEG sync bytes', () {
      // 0xFFFx pattern
      final data = Uint8List.fromList([0xFF, 0xF0, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('mp3'));
    });

    test('detects FLAC from magic bytes', () {
      final data = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('flac'));
    });

    test('detects OGG from magic bytes', () {
      final data = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53, 0, 0, 0, 0]);
      expect(detectAudioFormat(data), equals('ogg'));
    });

    test('detects M4A from ftyp magic bytes (ISO base media)', () {
      // M4A/MP4: box size (4 bytes) + "ftyp" at offset 4
      final data =
          Uint8List.fromList([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]);
      expect(detectAudioFormat(data), equals('m4a'));
    });

    test('detects M4A with different box size prefix', () {
      // Larger box size
      final data =
          Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]);
      expect(detectAudioFormat(data), equals('m4a'));
    });

    test('returns pcm for unknown data', () {
      final data = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(detectAudioFormat(data), equals('pcm'));
    });

    test('returns pcm for empty data', () {
      final data = Uint8List.fromList([]);
      expect(detectAudioFormat(data), equals('pcm'));
    });

    test('returns pcm for data smaller than 4 bytes', () {
      final data = Uint8List.fromList([0x00, 0x01, 0x02]);
      expect(detectAudioFormat(data), equals('pcm'));
    });
  });

  group('getMimeType', () {
    test('returns correct MIME for wav', () {
      expect(getMimeType('wav'), equals('audio/wav'));
    });

    test('returns correct MIME for mp3', () {
      expect(getMimeType('mp3'), equals('audio/mpeg'));
    });

    test('returns correct MIME for flac', () {
      expect(getMimeType('flac'), equals('audio/flac'));
    });

    test('returns correct MIME for ogg', () {
      expect(getMimeType('ogg'), equals('audio/ogg'));
    });

    test('returns correct MIME for aac', () {
      expect(getMimeType('aac'), equals('audio/aac'));
    });

    test('returns correct MIME for m4a', () {
      expect(getMimeType('m4a'), equals('audio/mp4'));
    });

    test('returns correct MIME for wma', () {
      expect(getMimeType('wma'), equals('audio/x-ms-wma'));
    });

    test('returns correct MIME for opus', () {
      expect(getMimeType('opus'), equals('audio/ogg'));
    });

    test('returns correct MIME for pcm', () {
      expect(getMimeType('pcm'), equals('audio/L16;rate=24000;channels=1'));
    });

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
    test('returns empty data as-is', () {
      final result = ensureValidAudioFormat(Uint8List.fromList([]));
      expect(result.$1, isEmpty);
    });

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

    test('detects and keeps m4a format', () {
      // Simulate m4a data (ftyp box)
      final m4aData = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, // ftyp
        0x6D, 0x70, 0x34, 0x32, // major brand
      ]);
      final result = ensureValidAudioFormat(m4aData, requestedFormat: 'm4a');
      expect(result.$2, equals('m4a'));
    });
  });
}
