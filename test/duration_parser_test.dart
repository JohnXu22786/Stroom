import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/duration_parser.dart';

void main() {
  group('parseSmartDuration', () {
    test('empty string returns null', () {
      expect(parseSmartDuration(''), isNull);
      expect(parseSmartDuration('   '), isNull);
    });

    test('single number is treated as total seconds', () {
      final r = parseSmartDuration('30')!;
      expect(r.hours, 0);
      expect(r.minutes, 0);
      expect(r.seconds, 30);
    });

    test('single number rolls over minutes', () {
      final r = parseSmartDuration('90')!;
      expect(r.hours, 0);
      expect(r.minutes, 1);
      expect(r.seconds, 30);
    });

    test('single number rolls over hours', () {
      final r = parseSmartDuration('3661')!;
      expect(r.hours, 1);
      expect(r.minutes, 1);
      expect(r.seconds, 1);
    });

    test('two numbers: minutes and seconds', () {
      final r = parseSmartDuration('2 30')!;
      expect(r.hours, 0);
      expect(r.minutes, 2);
      expect(r.seconds, 30);
    });

    test('two numbers: minutes and seconds with space', () {
      final r = parseSmartDuration('5 0')!;
      expect(r.hours, 0);
      expect(r.minutes, 5);
      expect(r.seconds, 0);
    });

    test('two numbers: minutes > 59 returns null', () {
      expect(parseSmartDuration('60 0'), isNull);
      expect(parseSmartDuration('99 1'), isNull);
    });

    test('two numbers: seconds > 59 returns null', () {
      expect(parseSmartDuration('1 60'), isNull);
      expect(parseSmartDuration('0 99'), isNull);
    });

    test('three numbers: hours, minutes, seconds', () {
      final r = parseSmartDuration('2 30 15')!;
      expect(r.hours, 2);
      expect(r.minutes, 30);
      expect(r.seconds, 15);
    });

    test('three numbers with leading zeros', () {
      final r = parseSmartDuration('1 0 8')!;
      expect(r.hours, 1);
      expect(r.minutes, 0);
      expect(r.seconds, 8);
    });

    test('three numbers: minutes > 59 returns null', () {
      expect(parseSmartDuration('1 60 0'), isNull);
    });

    test('three numbers: seconds > 59 returns null', () {
      expect(parseSmartDuration('1 0 99'), isNull);
    });

    test('space-separated like "空空30" = 30s', () {
      // Simulating "  30" with leading spaces
      final r = parseSmartDuration('  30')!;
      expect(r.hours, 0);
      expect(r.minutes, 0);
      expect(r.seconds, 30);
    });

    test('space-separated like "2空8" = 2m 8s (two numbers = minutes seconds)', () {
      // "2空8" in user notation = "2  8" in practice, parsed as 2 numbers: min=2, sec=8
      final r = parseSmartDuration('2  8')!;
      expect(r.hours, 0);
      expect(r.minutes, 2);
      expect(r.seconds, 8);
    });

    test('explicit "2 0 8" = 2h 0m 8s', () {
      final r = parseSmartDuration('2 0 8')!;
      expect(r.hours, 2);
      expect(r.minutes, 0);
      expect(r.seconds, 8);
    });

    test('space-separated like "1空空" = 1m 0s', () {
      final r = parseSmartDuration('1')!;
      expect(r.hours, 0);
      expect(r.minutes, 0);
      expect(r.seconds, 1);
    });
  });

  group('formatDurationDisplay', () {
    test('only seconds', () {
      expect(formatDurationDisplay(const DurationResult(hours: 0, minutes: 0, seconds: 30)), '30秒');
    });

    test('minutes and seconds', () {
      expect(formatDurationDisplay(const DurationResult(hours: 0, minutes: 1, seconds: 30)), '1分30秒');
    });

    test('hours, minutes, seconds', () {
      expect(formatDurationDisplay(const DurationResult(hours: 2, minutes: 30, seconds: 15)), '2时30分15秒');
    });

    test('only hours', () {
      expect(formatDurationDisplay(const DurationResult(hours: 1, minutes: 0, seconds: 0)), '1时0分0秒');
    });

    test('hours and seconds only', () {
      expect(formatDurationDisplay(const DurationResult(hours: 2, minutes: 0, seconds: 8)), '2时0分8秒');
    });
  });
}
