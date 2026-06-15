import 'dart:io';
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

    test('extractAudio throws when engine is not available', () async {
      final available = await engine.isAvailable();
      if (!available) {
        await expectLater(
          engine.extractAudio(
            videoBytes: Uint8List.fromList([0, 1, 2, 3]),
            videoFormat: 'mp4',
          ),
          throwsA(isA<Exception>()),
        );
      }
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

    // ==================================================================
    // Crash regression: verify setProperty calls do NOT pass waitForInitialization.
    // media_kit's NativePlayer.setProperty(String, String, {bool waitForInitialization = true})
    // skips player initialization when waitForInitialization=false, causing a native segfault
    // when mpv_set_property_string() is called on an uninitialized mpv context.
    // ==================================================================
    test('source code has no setProperty calls with waitForInitialization', () {
      // Read the source files and verify no setProperty calls use waitForInitialization.
      // This prevents regression if someone reintroduces the crash pattern.
      final sourcePaths = [
        'lib/utils/audio_separation_native.dart',
        'lib/catcatch/engine/ffmpeg_converter.dart',
      ];

      for (final path in sourcePaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Source file $path must exist');

        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('setProperty') && line.contains('waitForInitialization')) {
            fail('Line ${i + 1} in $path contains setProperty with waitForInitialization: '
                '${line.trim()}');
          }
        }
      }
    });

    test('setProperty calls only pass two positional arguments', () {
      // Verify that setProperty calls use the correct signature:
      // setProperty(String property, String value) — no extra named params.
      final sourcePaths = [
        'lib/utils/audio_separation_native.dart',
        'lib/catcatch/engine/ffmpeg_converter.dart',
      ];

      for (final path in sourcePaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Source file $path must exist');

        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Match setProperty(...) calls: should be `setProperty('key', 'value')`
          if (line.trimLeft().startsWith('await') && line.contains('setProperty')) {
            // Should not contain more than 2 string arguments + closing paren
            expect(line.contains(', waitForInitialization'), isFalse,
                reason: 'Line ${i + 1} in $path must not use waitForInitialization parameter');
            expect(line.contains(', true)'), isFalse,
                reason: 'Line ${i + 1} in $path must not pass explicit positional after value');
          }
        }
      }
    });
  });
}
