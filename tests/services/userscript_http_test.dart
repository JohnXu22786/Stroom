import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/userscript_http.dart';

void main() {
  group('normalizeUserscriptUrl', () {
    test('rewrites Greasy Fork install URLs to the update host', () {
      expect(
        normalizeUserscriptUrl(
          'https://greasyfork.org/scripts/123/example.user.js?version=4',
        ),
        'https://update.greasyfork.org/scripts/123/example.user.js?version=4',
      );
    });

    test('converts GitHub blob links to raw URLs and keeps the branch', () {
      expect(
        normalizeUserscriptUrl(
          'https://github.com/owner/repo/blob/main/scripts/example.user.js',
        ),
        'https://raw.githubusercontent.com/owner/repo/main/scripts/example.user.js',
      );
    });

    test('rejects insecure, nonstandard-port, and unsupported URLs', () {
      expect(
        () => normalizeUserscriptUrl('http://greasyfork.org/scripts/a.user.js'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => normalizeUserscriptUrl(
            'https://raw.githubusercontent.com:8443/a/b/main/script.js'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => normalizeUserscriptUrl('https://example.com/script.js'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('validateUserscriptResponse', () {
    test('accepts JSON-looking and error-named JavaScript source by MIME', () {
      expect(
        () => validateUserscriptResponse(
          'error();',
          contentType: 'application/javascript; charset=utf-8',
        ),
        returnsNormally,
      );
      expect(
        () => validateUserscriptResponse(
          '42',
          contentType: 'application/ecmascript',
        ),
        returnsNormally,
      );
    });

    test('rejects HTML and error text, but accepts plain text userscripts', () {
      expect(
        () => validateUserscriptResponse(
          '<html>denied</html>',
          contentType: 'application/javascript',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => validateUserscriptResponse(
          'Access denied',
          contentType: 'text/plain; charset=utf-8',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => validateUserscriptResponse(
          '// ==UserScript==\n// @name Example\n// ==/UserScript==\nerror();',
          contentType: 'text/plain',
        ),
        returnsNormally,
      );
    });
  });
}
