import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/file_manager_utils.dart';

void main() {
  group('sanitizeFileName', () {
    test('replaces path separators and illegal chars with underscore', () {
      expect(sanitizeFileName('a/b\\c:d*e?f"g<h>i|j.txt'),
          'a_b_c_d_e_f_g_h_i_j.txt');
    });

    test('keeps short names unchanged', () {
      expect(sanitizeFileName('vacation.jpg'), 'vacation.jpg');
    });

    test('truncates long name but preserves extension within 110 chars', () {
      final name = '${'a' * 150}.txt';
      final result = sanitizeFileName(name);
      expect(result, endsWith('.txt'));
      expect(result.length, lessThanOrEqualTo(110));
    });

    test('truncates long name without extension to 110 chars', () {
      final result = sanitizeFileName('a' * 200);
      expect(result.length, 110);
      expect(result, 'a' * 110);
    });

    test('does not crash when the extension itself is longer than 110 chars',
        () {
      final result = sanitizeFileName('name.${'e' * 150}');
      expect(result.length, 110);
    });

    test('does not crash when the last dot sits early in a long name', () {
      // extIdx <= 100 with a long extension — previously triggered RangeError
      final result = sanitizeFileName('${'x' * 60}.${'e' * 120}');
      expect(result.length, lessThanOrEqualTo(110));
    });

    test('truncates base when name length exceeds limit with long extension',
        () {
      final result = sanitizeFileName('${'x' * 105}.${'e' * 20}');
      expect(result, endsWith('.${'e' * 20}'));
      expect(result.length, lessThanOrEqualTo(110));
    });
  });
}
