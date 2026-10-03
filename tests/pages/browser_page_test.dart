import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/browser_page.dart';

void main() {
  group('normalizeBrowserUrl', () {
    test('recognizes HTTP schemes case-insensitively', () {
      expect(
        normalizeBrowserUrl('HTTP://example.com/path'),
        'HTTP://example.com/path',
      );
      expect(
        normalizeBrowserUrl('HtTpS://example.com/Path'),
        'HtTpS://example.com/Path',
      );
      expect(
        normalizeBrowserUrl('example.com/path'),
        'https://example.com/path',
      );
    });
  });
}
