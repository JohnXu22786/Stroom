import 'package:flutter_test/flutter_test.dart';

/// The formatDuration function from video_gallery_page.dart
/// (copied here as a pure function for testing)
String _formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

void main() {
  group('_formatDuration', () {
    test('0 ms -> 00:00', () {
      expect(_formatDuration(0), equals('00:00'));
    });

    test('1000 ms (1s) -> 00:01', () {
      expect(_formatDuration(1000), equals('00:01'));
    });

    test('60000 ms (1min) -> 01:00', () {
      expect(_formatDuration(60000), equals('01:00'));
    });

    test('61000 ms (1min1s) -> 01:01', () {
      expect(_formatDuration(61000), equals('01:01'));
    });

    test('3600000 ms (1 hour) -> 60:00', () {
      // Note: This format doesn't show hours, just minutes:seconds
      expect(_formatDuration(3600000), equals('60:00'));
    });

    test('654321 ms -> 10:54', () {
      // 654321 ms = 654 seconds = 10 minutes 54 seconds
      expect(_formatDuration(654321), equals('10:54'));
    });
  });
}
