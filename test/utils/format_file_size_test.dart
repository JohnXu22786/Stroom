import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/format_file_size.dart';

void main() {
  group('formatFileSize', () {
    test('handles edge cases at boundary values', () {
      expect(formatFileSize(1023), '1023 B');
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1048575), '1024.0 KB');
      expect(formatFileSize(1048576), '1.0 MB');
      expect(formatFileSize(1073741823), '1024.0 MB');
      expect(formatFileSize(1073741824), '1.0 GB');
    });

    test('handles large file sizes', () {
      expect(formatFileSize(5368709120), '5.0 GB');
      expect(formatFileSize(1099511627776), '1024.0 GB');
    });
  });
}
