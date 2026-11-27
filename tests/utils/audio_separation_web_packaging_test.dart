import 'dart:async' show Timer;
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation_web.dart' as web;
import 'package:stroom/utils/audio_utils.dart' show detectAudioFormat;

void main() {
  final engine = web.AudioSeparationEngine();

  test('packages extracted PCM fixture as WAV', () async {
    final videoBytes =
        await File('tests/fixtures/audio_separation/pcm.mov').readAsBytes();

    final result = await engine.extractAudio(
      videoBytes: videoBytes,
      videoFormat: 'mov',
    );

    expect(detectAudioFormat(result), 'wav');
    expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(result.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(result.sublist(36, 40)), 'data');
    expect(result.length, greaterThan(44));
  });

  test('packages extracted AAC fixture as M4A', () async {
    final videoBytes =
        await File('tests/fixtures/catcatch/audio_only.mp4').readAsBytes();

    final result = await engine.extractAudio(
      videoBytes: videoBytes,
      videoFormat: 'mp4',
    );

    expect(detectAudioFormat(result), 'm4a');
    expect(String.fromCharCodes(result.sublist(4, 8)), 'ftyp');
    expect(String.fromCharCodes(result.sublist(8, 12)), 'M4A ');
    expect(result.length, greaterThan(100));
  });

  test('throws if cancelled during final PCM packaging yield', () async {
    final videoBytes = await File(
      'tests/fixtures/audio_separation/pcm.mov',
    ).readAsBytes();
    final cancelToken = CancelToken();
    final progress = <int>[];

    await expectLater(
      engine.extractAudio(
        videoBytes: videoBytes,
        videoFormat: 'mov',
        cancelToken: cancelToken,
        onProgress: (value) {
          progress.add(value);
          if (value == 60) Timer.run(cancelToken.cancel);
        },
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Audio extraction was cancelled'),
        ),
      ),
    );
    expect(progress, [0, 30, 60]);
  });
}
