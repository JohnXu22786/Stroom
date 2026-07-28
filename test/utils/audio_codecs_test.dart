import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_codecs.dart';

/// Generate a synthetic sine wave as Int16List.
Int16List _sineWave(int samples, {double freq = 440, int sampleRate = 16000}) {
  final pcm = Int16List(samples);
  for (int i = 0; i < samples; i++) {
    pcm[i] = (sin(2 * pi * freq * i / sampleRate) * 15000).round();
  }
  return pcm;
}

void main() {
  group('ADPCM encoder', () {
    test('encodes and produces smaller output than PCM', () {
      final pcm = _sineWave(8192);

      final adpcm = encodeAdpcm(pcm, AdpcmConfig());
      final pcmSize = pcm.length * 2; // 16-bit = 2 bytes/sample

      // ADPCM should be significantly smaller (~4x for 16-bit)
      expect(adpcm.length, lessThan(pcmSize));
      // Should be roughly pcmSize / 4 + headers
      expect(adpcm.length, greaterThan(pcmSize ~/ 8));
    });

    test('handles silence (all zeros)', () {
      final pcm = Int16List(1024); // all zeros
      final adpcm = encodeAdpcm(pcm, AdpcmConfig());
      expect(adpcm.isNotEmpty, true);
    });

    test('handles max amplitude', () {
      final pcm = Int16List(512);
      for (int i = 0; i < 512; i++) {
        pcm[i] = 32767;
      }
      final adpcm = encodeAdpcm(pcm, AdpcmConfig());
      expect(adpcm.isNotEmpty, true);
    });
  });

  group('FLAC encoder', () {
    test('produces valid FLAC file with fLaC marker', () {
      final pcm = _sineWave(8192);

      final flac = encodeFlac(pcm, sampleRate: 16000);

      // fLaC marker
      expect(flac[0], 0x66); // 'f'
      expect(flac[1], 0x4C); // 'L'
      expect(flac[2], 0x61); // 'a'
      expect(flac[3], 0x43); // 'C'
    });

    test('produces smaller output than PCM for tonal content', () {
      final pcm = _sineWave(8192);
      final pcmSize = pcm.length * 2;

      final flac = encodeFlac(pcm, sampleRate: 16000);

      // FLAC should compress tonal content significantly
      expect(flac.length, lessThan(pcmSize));
    });

    test('handles multiple blocks (larger than 4096 samples)', () {
      final pcm = _sineWave(10000); // > 4096 → 3 blocks

      final flac = encodeFlac(pcm, sampleRate: 16000);
      expect(flac.isNotEmpty, true);
      // Should still have the fLaC marker
      expect(flac[0], 0x66);
    });

    test('handles silence compression', () {
      final pcm = Int16List(8192);
      final pcmSize = pcm.length * 2;

      final flac = encodeFlac(pcm, sampleRate: 16000);

      // Silence should compress extremely well with FLAC
      expect(flac.length, lessThan(pcmSize ~/ 10));
    });

    test('handles small input (< 4096 samples)', () {
      final pcm = _sineWave(1024);
      final flac = encodeFlac(pcm, sampleRate: 8000);
      expect(flac.isNotEmpty, true);
    });
  });

  group('compressPcm', () {
    test('AudioCodec.none returns S16LE bytes', () {
      final pcm = Int16List.fromList([100, 200, 300]);
      final out = compressPcm(pcm, AudioCodec.none);
      // 3 samples × 2 bytes = 6 bytes
      expect(out.length, 6);
    });

    test('AudioCodec.adpcm compresses', () {
      final pcm = _sineWave(4096);
      final out = compressPcm(pcm, AudioCodec.adpcm);
      expect(out.isNotEmpty, true);
      expect(out.length, lessThan(pcm.length * 2));
    });

    test('AudioCodec.flac compresses and has fLaC marker', () {
      final pcm = _sineWave(4096);
      final out = compressPcm(pcm, AudioCodec.flac);
      expect(out[0], 0x66);
    });

    test('opus/mp3 fall back to uncompressed', () {
      final pcm = Int16List.fromList([100, 200]);
      final opusOut = compressPcm(pcm, AudioCodec.opus);
      final mp3Out = compressPcm(pcm, AudioCodec.mp3);
      // Fallback to S16LE bytes
      expect(opusOut.length, 4);
      expect(mp3Out.length, 4);
    });
  });
}
