import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_trim.dart';

void main() {
  group('trimAudio WAV metadata', () {
    test('preserves stereo PCM metadata and trims complete frames', () {
      final wav = _pcmWav(
        sampleRate: 48000,
        channels: 2,
        bitsPerSample: 16,
        pcm: List<int>.generate(24, (index) => index),
      );

      final trimmed = trimAudio(
        wav,
        preset: {'durationSeconds': 1 / 48000, 'direction': 'head'},
      );

      expect(_u16(trimmed, 22), 2);
      expect(_u32(trimmed, 24), 48000);
      expect(_u16(trimmed, 34), 16);
      expect(_u16(trimmed, 32), 4);
      expect(_data(trimmed), wav.sublist(48));
      expect(_u32(trimmed, 40), 20);
    });

    test('preserves non-default sample rate and 24-bit PCM', () {
      final wav = _pcmWav(
        sampleRate: 32000,
        channels: 1,
        bitsPerSample: 24,
        pcm: List<int>.generate(18, (index) => index),
      );

      final trimmed = trimAudio(
        wav,
        preset: {'durationSeconds': 1 / 32000, 'direction': 'tail'},
        sampleRate: 24000,
      );

      expect(_u16(trimmed, 22), 1);
      expect(_u32(trimmed, 24), 32000);
      expect(_u16(trimmed, 34), 24);
      expect(_u32(trimmed, 28), 96000);
      expect(_u16(trimmed, 32), 3);
      expect(_data(trimmed), wav.sublist(44, 59));
      expect(_u32(trimmed, 40), 15);
      expect(_u32(trimmed, 4), 52);
      expect(trimmed.length, 60);
    });

    test('keeps default mono 16-bit WAV trimming behavior', () {
      final wav = _pcmWav(
        sampleRate: defaultSampleRate,
        channels: 1,
        bitsPerSample: 16,
        pcm: List<int>.generate(12, (index) => index),
      );

      final trimmed = trimAudio(
        wav,
        preset: {'durationSeconds': 1 / defaultSampleRate, 'direction': 'head'},
      );

      expect(_u16(trimmed, 22), 1);
      expect(_u32(trimmed, 24), defaultSampleRate);
      expect(_u16(trimmed, 34), 16);
      expect(_data(trimmed), wav.sublist(46));
    });

    test('returns unsupported or malformed WAV input unchanged', () {
      final unsupported = _pcmWav(
        sampleRate: 24000,
        channels: 1,
        bitsPerSample: 16,
        pcm: List<int>.generate(12, (index) => index),
        formatCode: 3,
      );
      final malformed = Uint8List.fromList(
        _pcmWav(
          sampleRate: 24000,
          channels: 1,
          bitsPerSample: 16,
          pcm: List<int>.generate(12, (index) => index),
        ),
      )..[32] = 1;

      for (final wav in [unsupported, malformed]) {
        expect(
          trimAudio(wav, preset: {'durationSeconds': 1, 'direction': 'head'}),
          same(wav),
        );
      }
    });

    test('preserves RIFX input instead of trimming it as raw PCM', () {
      final rifx = _pcmWav(
        sampleRate: 24000,
        channels: 1,
        bitsPerSample: 16,
        pcm: List<int>.generate(12, (index) => index),
      )..setRange(0, 4, [0x52, 0x49, 0x46, 0x58]);

      expect(
        trimAudio(rifx, preset: {'durationSeconds': 1 / 24000}),
        same(rifx),
      );
    });
  });

  group('trimAudio compressed formats', () {
    test('preserves Ogg/Opus bytes when a trim preset is applied', () {
      final ogg = Uint8List(64)..setRange(0, 4, [0x4F, 0x67, 0x67, 0x53]);

      expect(
        trimAudio(ogg, preset: {'durationSeconds': 1 / defaultSampleRate}),
        same(ogg),
      );
    });

    test('preserves M4A bytes when a trim preset is applied', () {
      final m4a = Uint8List(64)..setRange(4, 8, [0x66, 0x74, 0x79, 0x70]);

      expect(
        trimAudio(m4a, preset: {'durationSeconds': 1 / defaultSampleRate}),
        same(m4a),
      );
    });
  });
}

Uint8List _pcmWav({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required List<int> pcm,
  int formatCode = 1,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final blockAlign = channels * bytesPerSample;
  final byteData = ByteData(44 + pcm.length);
  void writeFourCc(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      byteData.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeFourCc(0, 'RIFF');
  byteData.setUint32(4, 36 + pcm.length, Endian.little);
  writeFourCc(8, 'WAVE');
  writeFourCc(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, formatCode, Endian.little);
  byteData.setUint16(22, channels, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * blockAlign, Endian.little);
  byteData.setUint16(32, blockAlign, Endian.little);
  byteData.setUint16(34, bitsPerSample, Endian.little);
  writeFourCc(36, 'data');
  byteData.setUint32(40, pcm.length, Endian.little);
  for (var i = 0; i < pcm.length; i++) {
    byteData.setUint8(44 + i, pcm[i]);
  }
  return byteData.buffer.asUint8List();
}

Uint8List _data(Uint8List wav) => wav.sublist(44, 44 + _u32(wav, 40));

int _u16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint16(offset, Endian.little);

int _u32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);
