import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for web compilation compatibility.
///
/// Verifies that:
/// - `main.dart` no longer directly imports `package:fvp` (which uses `dart:ffi`)
/// - A conditional export wrapper (`video_player_init.dart`) is used instead
/// - The native implementation calls `fvp.registerWith()`
/// - The web stub is a no-op
void main() {
  group('fvp conditional import for web', () {
    test('kIsWeb constant is accessible from package:flutter/foundation.dart',
        () {
      // This verifies the import works and the constant is available
      // kIsWeb is a compile-time constant, true on web, false otherwise
      expect(kIsWeb, isA<bool>());
    });

    test('main.dart does NOT directly import fvp', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      // fvp should not be directly imported in main.dart
      expect(mainSource, isNot(contains("import 'package:fvp/fvp.dart'")));
      expect(mainSource, isNot(contains('fvp.registerWith()')));
    });

    test('main.dart calls registerVideoPlayer() instead', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('registerVideoPlayer()'));
      expect(
        mainSource,
        contains("import 'services/video_player_init.dart'"),
      );
    });

    test('video_player_init.dart uses conditional export', () {
      final initSource =
          File('lib/services/video_player_init.dart').readAsStringSync();
      expect(initSource, contains('export'));
      expect(initSource, contains("if (dart.library.io)"));
      expect(initSource, contains("video_player_init_stub.dart"));
      expect(initSource, contains("video_player_init_io.dart"));
    });

    test('video_player_init_io.dart registers fvp on native', () {
      final ioSource =
          File('lib/services/video_player_init_io.dart').readAsStringSync();
      expect(ioSource, contains("import 'package:fvp/fvp.dart'"));
      expect(ioSource, contains('fvp.registerWith()'));
    });

    test('video_player_init_stub.dart is a no-op for web', () {
      final stubSource =
          File('lib/services/video_player_init_stub.dart').readAsStringSync();
      expect(stubSource, contains('void registerVideoPlayer()'));
      // Should NOT import fvp (no dart:ffi on web)
      expect(stubSource, isNot(contains("import 'package:fvp/fvp.dart'")));
      expect(stubSource, isNot(contains('registerWith')));
    });

    test('main.dart already imports package:flutter/foundation.dart', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(
        mainSource,
        contains("import 'package:flutter/foundation.dart'"),
      );
    });
  });
}
