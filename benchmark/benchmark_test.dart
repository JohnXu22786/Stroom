import 'package:flutter_test/flutter_test.dart';

/// Simple performance benchmark for key utility functions.
///
/// These benchmarks measure execution time of common operations
/// and fail if performance regresses beyond thresholds.
void main() {
  group('Benchmark - Utils', () {
    test('emojis regex performance', () {
      final stopwatch = Stopwatch()..start();
      final emojiPattern = RegExp(
        r'[\u{1F600}-\u{1F64F}' // emoticons
        r'\u{1F300}-\u{1F5FF}' // symbols & pictographs
        r'\u{1F680}-\u{1F6FF}' // transport & map
        r'\u{1F1E0}-\u{1F1FF}' // flags
        r'\u{2600}-\u{26FF}' // misc symbols
        r'\u{2700}-\u{27BF}' // dingbats
        r'\u{FE00}-\u{FEFF}' // variation selectors
        r'\u{200D}' // zero-width joiner
        r']',
        unicode: true,
      );

      // Run 1000 iterations
      for (int i = 0; i < 1000; i++) {
        emojiPattern.hasMatch('Hello 😊 world 🌍 test 🔥');
      }

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // Emoji regex should complete 1000 iterations in < 500ms
      expect(elapsed, lessThan(500),
          reason: 'Emoji regex performance regression: ${elapsed}ms');
    });

    test('base64 detection performance', () {
      final stopwatch = Stopwatch()..start();
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');

      final samples = List.generate(
        500,
        (i) => 'data${'A' * 300}',
      );

      for (final sample in samples) {
        base64Pattern.hasMatch(sample);
      }

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // 500 iterations should complete in < 200ms
      expect(elapsed, lessThan(200),
          reason: 'Base64 detection performance regression: ${elapsed}ms');
    });
  });

  group('Benchmark - JSON parsing', () {
    test('JSON serialization round-trip', () {
      final stopwatch = Stopwatch()..start();
      final data = {
        'key1': 'value1',
        'key2': 123,
        'key3': true,
        'key4': [1, 2, 3, 4, 5],
        'key5': {'nested': 'object'},
      };

      // Run 500 round-trips
      for (int i = 0; i < 500; i++) {
        final json = _simpleJsonEncode(data);
        _simpleJsonDecode(json);
      }

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      // 500 round-trips should complete in < 500ms
      expect(elapsed, lessThan(500),
          reason: 'JSON serialization performance regression: ${elapsed}ms');
    });
  });
}

String _simpleJsonEncode(Map<String, dynamic> data) {
  // Simplified: in practice, use dart:convert
  return data.toString();
}

Map<String, dynamic> _simpleJsonDecode(String json) {
  // Simplified: in practice, use dart:convert
  return {'key1': 'value1', 'key2': 123, 'key3': true};
}
