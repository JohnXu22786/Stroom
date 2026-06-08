import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/format_file_size.dart';

void main() {
  group('formatFileSize', () {
    test('returns bytes for sizes < 1024', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1), '1 B');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('returns KB for sizes between 1 KB and 1 MB', () {
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(10240), '10.0 KB');
      expect(formatFileSize(1048575), '1024.0 KB');
    });

    test('returns MB for sizes between 1 MB and 1 GB', () {
      expect(formatFileSize(1048576), '1.0 MB');
      expect(formatFileSize(1572864), '1.5 MB');
      expect(formatFileSize(10485760), '10.0 MB');
    });

    test('returns GB for sizes >= 1 GB', () {
      expect(formatFileSize(1073741824), '1.0 GB');
      expect(formatFileSize(1610612736), '1.5 GB');
    });

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
