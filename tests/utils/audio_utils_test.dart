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

  group('formatDisplayName', () {
    test('maps AAC to M4A (consumer-friendly name)', () {
      // Regression: raw AAC ADTS format should display as "M4A" because
      // "AAC" is a codec name unfamiliar to most users, while "M4A" is
      // the widely recognized consumer audio format name.
      expect(formatDisplayName('aac'), equals('M4A'));
    });

    test('returns same uppercase for wav', () {
      expect(formatDisplayName('wav'), equals('WAV'));
    });

    test('returns same uppercase for mp3', () {
      expect(formatDisplayName('mp3'), equals('MP3'));
    });

    test('returns same uppercase for m4a', () {
      expect(formatDisplayName('m4a'), equals('M4A'));
    });

    test('returns same uppercase for flac', () {
      expect(formatDisplayName('flac'), equals('FLAC'));
    });

    test('returns same uppercase for ogg', () {
      expect(formatDisplayName('ogg'), equals('OGG'));
    });

    test('returns same uppercase for opus', () {
      expect(formatDisplayName('opus'), equals('OPUS'));
    });

    test('returns same uppercase for webm', () {
      expect(formatDisplayName('webm'), equals('WEBM'));
    });

    test('returns same uppercase for weba', () {
      expect(formatDisplayName('weba'), equals('WEBA'));
    });

    test('returns same uppercase for wma', () {
      expect(formatDisplayName('wma'), equals('WMA'));
    });

    test('returns same uppercase for mp4', () {
      expect(formatDisplayName('mp4'), equals('MP4'));
    });

    test('returns same uppercase for mpeg', () {
      expect(formatDisplayName('mpeg'), equals('MPEG'));
    });

    test('returns same uppercase for pcm', () {
      expect(formatDisplayName('pcm'), equals('PCM'));
    });

    test('is case-insensitive - AAC upper', () {
      expect(formatDisplayName('AAC'), equals('M4A'));
    });

    test('is case-insensitive - Aac mixed', () {
      expect(formatDisplayName('Aac'), equals('M4A'));
    });

    test('handles empty string', () {
      expect(formatDisplayName(''), equals(''));
    });

    test('handles unknown format by uppercasing', () {
      expect(formatDisplayName('unknown'), equals('UNKNOWN'));
      expect(formatDisplayName('custom'), equals('CUSTOM'));
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

  // ====================================================================
  // normalizeAudioFormat — map internal format identifiers to the
  // consumer-facing extension used both for on-disk filenames and for
  // AudioRecord.format. Currently: aac -> m4a.
  // ====================================================================
  group('normalizeAudioFormat', () {
    test('aac maps to m4a (consumer-friendly file extension)', () {
      expect(normalizeAudioFormat('aac'), equals('m4a'),
          reason:
              'Audio extracted as ADTS-wrapped AAC should be saved with the '
              'm4a extension so users see the widely recognized consumer name.');
    });

    test('is case-insensitive (AAC, Aac -> m4a)', () {
      expect(normalizeAudioFormat('AAC'), equals('m4a'));
      expect(normalizeAudioFormat('Aac'), equals('m4a'));
    });

    test('m4a passes through as m4a', () {
      expect(normalizeAudioFormat('m4a'), equals('m4a'));
    });

    test('wav passes through as wav', () {
      expect(normalizeAudioFormat('wav'), equals('wav'));
    });

    test('mp3 passes through as mp3', () {
      expect(normalizeAudioFormat('mp3'), equals('mp3'));
    });

    test('flac passes through as flac', () {
      expect(normalizeAudioFormat('flac'), equals('flac'));
    });

    test('pcm passes through as pcm', () {
      expect(normalizeAudioFormat('pcm'), equals('pcm'));
    });

    test('empty string is preserved as empty', () {
      expect(normalizeAudioFormat(''), equals(''));
    });
  });

  // ====================================================================
  // getMimeType — must accept normalized (m4a) form too
  // ====================================================================
  group('getMimeType (normalized)', () {
    test('aac still maps to audio/aac (mime type unchanged)', () {
      // The mime type for raw ADTS stays audio/aac; only the file
      // extension is normalized to m4a for display.
      expect(getMimeType('aac'), equals('audio/aac'));
    });

    test('m4a maps to audio/mp4', () {
      expect(getMimeType('m4a'), equals('audio/mp4'));
    });
  });
}
