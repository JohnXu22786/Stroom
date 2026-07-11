import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for main.dart web compatibility changes.
///
/// Verifies that:
/// - fvp.registerWith() is guarded by `if (!kIsWeb)` so it's not called on web
/// - The import for kIsWeb is already present in main.dart
void main() {
  group('main.dart web compatibility', () {
    test('kIsWeb constant is accessible from package:flutter/foundation.dart',
        () {
      // This verifies the import works and the constant is available
      // kIsWeb is a compile-time constant, true on web, false otherwise
      expect(kIsWeb, isA<bool>());
    });

    test('fvp.registerWith() is guarded by if (!kIsWeb)', () {
      // Read main.dart source to verify the guard pattern
      final mainSource = File('lib/main.dart').readAsStringSync();

      // Verify fvp.registerWith() is present
      expect(mainSource, contains('fvp.registerWith()'));

      // Verify it is wrapped with if (!kIsWeb)
      // We check that the line containing fvp.registerWith() is preceded by
      // an if (!kIsWeb) block
      final lines = mainSource.split('\n');
      bool foundGuard = false;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('fvp.registerWith()')) {
          // Check surrounding lines for the kIsWeb guard
          final start = i > 2 ? i - 2 : 0;
          final end = i < lines.length - 1 ? i + 1 : lines.length - 1;
          final context = lines.sublist(start, end + 1).join('\n');
          if (context.contains('if (!kIsWeb)')) {
            foundGuard = true;
          }
        }
      }
      expect(foundGuard, isTrue,
          reason:
              'fvp.registerWith() should be wrapped with if (!kIsWeb) { ... }');
    });

    test('main.dart already imports package:flutter/foundation.dart', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(
        mainSource,
        contains("import 'package:flutter/foundation.dart'"),
      );
    });

    test(
        'existing kIsWeb pattern in _initGlobalErrorHandling is consistent with new guard',
        () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      // Verify the existing pattern uses `if (!kIsWeb)` style (not `if (kIsWeb)`)
      // to ensure consistency with our new guard
      expect(mainSource, contains('if (!kIsWeb)'));
    });
  });
}
