import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation.dart'
    show AudioSeparationEngine;

void main() {
  // Ensure Flutter bindings are initialized for platform plugin testing
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioSeparationEngine', () {
    late AudioSeparationEngine engine;

    setUp(() {
      engine = AudioSeparationEngine();
    });

    test('isAvailable returns a boolean', () async {
      final available = await engine.isAvailable();
      // In test environment, no actual FFmpeg binary is available,
      // but the method should always return a boolean
      expect(available, isA<bool>());
    });

    test('canHandleVideoFormat returns correct results', () {
      // All major video formats should be claimable
      expect(engine.canHandleVideoFormat('mp4'), isTrue);
      expect(engine.canHandleVideoFormat('mov'), isTrue);
      expect(engine.canHandleVideoFormat('avi'), isTrue);
      expect(engine.canHandleVideoFormat('mkv'), isTrue);
      expect(engine.canHandleVideoFormat('webm'), isTrue);
      expect(engine.canHandleVideoFormat('flv'), isTrue);
      expect(engine.canHandleVideoFormat('m4v'), isTrue);
      expect(engine.canHandleVideoFormat('3gp'), isTrue);
    });

    test('extractAudio throws when engine is not available', () async {
      final available = await engine.isAvailable();
      if (!available) {
        await expectLater(
          engine.extractAudio(
            videoBytes: Uint8List.fromList([0, 1, 2, 3]),
            videoFormat: 'mp4',
          ),
          throwsA(isA<Error>()),
        );
      }
    });

    test('extractAudio throws on empty video bytes', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([]),
          videoFormat: 'mp4',
        ),
        throwsA(isA<Error>()),
      );
    });

    test('extractAudio throws on unsupported format', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([0, 1, 2, 3]),
          videoFormat: 'unknown',
        ),
        throwsA(isA<Error>()),
      );
    });

    test('canHandleVideoFormat rejects null or empty format', () {
      expect(engine.canHandleVideoFormat(''), isFalse);
      expect(engine.canHandleVideoFormat('  '), isFalse);
    });

    test('isAvailable returns false when ffmpeg not found', () async {
      // In test environment, FFmpeg should not be available
      // This applies to both mobile (ffmpeg_kit_flutter) and desktop (Process.run) paths
      final available = await engine.isAvailable();
      expect(available, isFalse);
    });
  });
}
