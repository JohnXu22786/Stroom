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
      // With media_kit, isAvailable should return true (engine is always available)
      expect(available, isA<bool>());
      expect(available, isTrue);
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
          videoFormat: 'unknown',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('canHandleVideoFormat rejects null or empty format', () {
      expect(engine.canHandleVideoFormat(''), isFalse);
      expect(engine.canHandleVideoFormat('  '), isFalse);
    });

    test('isAvailable returns true with media_kit', () async {
      // media_kit is integrated as a dependency, engine should be available
      final available = await engine.isAvailable();
      expect(available, isTrue);
    });
  });
}
