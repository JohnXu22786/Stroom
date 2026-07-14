import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/duration_parser.dart';

void main() {
  group('formatHms', () {
    test('3661 seconds (1h1m1s) -> 01:01:01', () {
      expect(formatHms(DurationResult(hours: 1, minutes: 1, seconds: 1)),
          '01:01:01');
    });

    test('86400 seconds (24h) -> 24:00:00', () {
      expect(formatHms(DurationResult(hours: 24, minutes: 0, seconds: 0)),
          '24:00:00');
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
