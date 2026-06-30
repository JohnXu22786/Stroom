import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation.dart' show AudioSeparationEngine;

void main() {
  // Ensure Flutter bindings are initialized for platform plugin testing
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioSeparationEngine (pure Dart)', () {
    late AudioSeparationEngine engine;

    setUp(() {
      engine = AudioSeparationEngine();
    });

    test('isAvailable returns true', () async {
      // Pure Dart implementation — always available, no platform deps
      final available = await engine.isAvailable();
      expect(available, isA<bool>());
      expect(available, isTrue);
    });

    test('canHandleVideoFormat returns correct results for ISOBMFF formats',
        () {
      // ISOBMFF-based formats (MP4, MOV, M4V, 3GP) are supported
      expect(engine.canHandleVideoFormat('mp4'), isTrue);
      expect(engine.canHandleVideoFormat('mov'), isTrue);
      expect(engine.canHandleVideoFormat('m4v'), isTrue);
      expect(engine.canHandleVideoFormat('3gp'), isTrue);
    });

    test('canHandleVideoFormat rejects non-ISOBMFF formats', () {
      // Non-ISOBMFF containers require container-specific parsers
      expect(engine.canHandleVideoFormat('avi'), isFalse);
      expect(engine.canHandleVideoFormat('mkv'), isFalse);
      expect(engine.canHandleVideoFormat('webm'), isFalse);
      expect(engine.canHandleVideoFormat('flv'), isFalse);
    });

    test('extractAudio throws when engine is not available', () async {
      // Pure Dart engine is always available, so this test verifies
      // that the error path for invalid data works correctly
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([0, 1, 2, 3]),
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
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
          videoFormat: 'avi',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('canHandleVideoFormat rejects empty format', () {
      expect(engine.canHandleVideoFormat(''), isFalse);
      expect(engine.canHandleVideoFormat('  '), isFalse);
    });

    test('isAvailable returns true (pure Dart)', () async {
      // Pure Dart implementation — no platform dependencies needed
      final available = await engine.isAvailable();
      expect(available, isTrue);
    });

    test('canHandleVideoFormat is case-insensitive', () {
      expect(engine.canHandleVideoFormat('MP4'), isTrue);
      expect(engine.canHandleVideoFormat('MOV'), isTrue);
      expect(engine.canHandleVideoFormat('Mp4'), isTrue);
    });

    test('extractAudio throws on invalid MP4 data (too small)', () async {
      await expectLater(
        engine.extractAudio(
          videoBytes: Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0]),
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extractAudio throws on MP4 without audio track', () async {
      // Minimal MP4 with ftyp but no moov/mdat with audio
      final mp4Bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x14, // box size = 20
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x00, 0x00, 0x02, 0x00, // version
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
      ]);
      await expectLater(
        engine.extractAudio(
          videoBytes: mp4Bytes,
          videoFormat: 'mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
