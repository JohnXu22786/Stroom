import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/duration_parser.dart';

void main() {
  group('formatHms', () {
    test('0 seconds -> 00:00:00', () {
      expect(formatHms(DurationResult(hours: 0, minutes: 0, seconds: 0)),
          '00:00:00');
    });

    test('30 seconds -> 00:00:30', () {
      expect(formatHms(DurationResult(hours: 0, minutes: 0, seconds: 30)),
          '00:00:30');
    });

    test('150 seconds (2m30s) -> 00:02:30', () {
      expect(formatHms(DurationResult(hours: 0, minutes: 2, seconds: 30)),
          '00:02:30');
    });

    test('3725 seconds (1h2m5s) -> 01:02:05', () {
      expect(formatHms(DurationResult(hours: 1, minutes: 2, seconds: 5)),
          '01:02:05');
    });

    test('3661 seconds (1h1m1s) -> 01:01:01', () {
      expect(formatHms(DurationResult(hours: 1, minutes: 1, seconds: 1)),
          '01:01:01');
    });

    test('86400 seconds (24h) -> 24:00:00', () {
      expect(formatHms(DurationResult(hours: 24, minutes: 0, seconds: 0)),
          '24:00:00');
    });
  });

  group('totalSeconds', () {
    test('1h 30m 15s -> 5415', () {
      expect(totalSeconds(hours: 1, minutes: 30, seconds: 15), 5415);
    });

    test('minutes > 59 (no normalization needed, just multiply)', () {
      expect(totalSeconds(hours: 0, minutes: 90, seconds: 0), 5400);
    });

    test('seconds > 59 (no normalization needed, just multiply)', () {
      expect(totalSeconds(hours: 0, minutes: 0, seconds: 90), 90);
    });

    test('all zeros -> 0', () {
      expect(totalSeconds(hours: 0, minutes: 0, seconds: 0), 0);
    });

    test('only hours -> 7200', () {
      expect(totalSeconds(hours: 2, minutes: 0, seconds: 0), 7200);
    });
  });

  group('parseSmartDuration (backward compatibility)', () {
    test('single number treated as total seconds', () {
      final result = parseSmartDuration('90');
      expect(result, isNotNull);
      expect(result!.hours, 0);
      expect(result.minutes, 1);
      expect(result.seconds, 30);
    });

    test('two numbers treated as minutes seconds', () {
      final result = parseSmartDuration('2 30');
      expect(result, isNotNull);
      expect(result!.hours, 0);
      expect(result.minutes, 2);
      expect(result.seconds, 30);
    });

    test('three numbers treated as hours minutes seconds', () {
      final result = parseSmartDuration('1 2 30');
      expect(result, isNotNull);
      expect(result!.hours, 1);
      expect(result.minutes, 2);
      expect(result.seconds, 30);
    });

    test('empty string returns null', () {
      expect(parseSmartDuration(''), isNull);
      expect(parseSmartDuration('   '), isNull);
    });
  });
}
