import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/browser_page.dart';

// Tests for the UserScript match-rule engine used by BrowserPage._injectScripts.
void main() {
  group('UserScript.matchesUrl', () {
    test('empty matches list means "run everywhere"', () {
      final script = UserScript(name: 'x', code: 'y', matches: []);
      expect(script.matchesUrl('https://anywhere.example/path'), isTrue);
    });

    test('wildcard scheme/host pattern matches subdomains', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(script.matchesUrl('https://m.example.com/page'), isTrue);
      expect(script.matchesUrl('http://www.example.com/a/b'), isTrue);
    });

    test('wildcard pattern does not match unrelated hosts', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      // evil-example.com is not under example.com
      expect(script.matchesUrl('https://evil-example.com/'), isFalse);
      expect(script.matchesUrl('https://example.org/'), isFalse);
    });

    test('host wildcard cannot bleed into the path', () {
      // Regression: a flat glob would let the host wildcard consume "/" and
      // match URLs whose PATH merely contains ".example.com/".
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(
        script.matchesUrl('https://attacker.com/x.example.com/y'),
        isFalse,
      );
      expect(
        script.matchesUrl('https://attacker.com/example.com'),
        isFalse,
      );
    });

    test('leading *. host wildcard also matches the apex domain', () {
      // Chrome match-pattern semantics: *://*.example.com/* matches the
      // apex domain too.
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/'), isTrue);
      expect(script.matchesUrl('https://deep.sub.example.com/'), isTrue);
    });

    test('scheme and host match case-insensitively', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['HTTPS://EXAMPLE.com/*'],
      );
      expect(script.matchesUrl('https://example.com/path'), isTrue);
      expect(script.matchesUrl('https://EXAMPLE.com/Path'), isTrue);
    });

    test('pattern without scheme defaults to any scheme', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/a'), isTrue);
      expect(script.matchesUrl('http://example.com/a'), isTrue);
      expect(script.matchesUrl('https://other.com/a'), isFalse);
    });

    test('pattern without path matches any path', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com'],
      );
      expect(script.matchesUrl('https://example.com/'), isTrue);
      expect(script.matchesUrl('https://example.com/a/b'), isTrue);
    });

    test('path matching is case-sensitive (scheme/host are not)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/API/*'],
      );
      expect(script.matchesUrl('https://example.com/API/list'), isTrue);
      expect(script.matchesUrl('https://example.com/api/list'), isFalse);
    });

    test('ports are ignored in the host pattern', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com:8080/*'],
      );
      expect(script.matchesUrl('https://example.com:8080/a'), isTrue);
      expect(script.matchesUrl('https://example.com/a'), isTrue);
    });

    test('file:///* matches file URLs (empty host)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['file:///*'],
      );
      expect(script.matchesUrl('file:///C:/docs/video.mp4'), isTrue);
      expect(script.matchesUrl('https://example.com/'), isFalse);
    });

    test('a "://" inside a query does not confuse scheme detection', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['example.com/redirect?to=http://x'],
      );
      expect(
        script.matchesUrl('https://example.com/redirect?to=http://x'),
        isTrue,
      );
      expect(
          script.matchesUrl('https://other.com/redirect?to=http://x'), isFalse);
    });

    test('userinfo in the pattern is ignored', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://user:pass@example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/a'), isTrue);
    });

    test('IPv6 host patterns match (brackets are normalized)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://[::1]/*'],
      );
      expect(script.matchesUrl('https://[::1]/x'), isTrue);
      expect(script.matchesUrl('https://[::1]:8080/x'), isTrue);
      expect(script.matchesUrl('https://example.com/x'), isFalse);
    });

    test('path-only pattern matches the path on any host', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['/foo/*'],
      );
      expect(script.matchesUrl('https://example.com/foo/a'), isTrue);
      expect(script.matchesUrl('https://other.org/foo/a'), isTrue);
      expect(script.matchesUrl('https://example.com/bar/a'), isFalse);
    });

    test('exact scheme pattern only matches that scheme', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/path'), isTrue);
      expect(script.matchesUrl('http://example.com/path'), isFalse);
    });

    test('any URL pattern matches everything', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*/*'],
      );
      expect(script.matchesUrl('https://a.b/c'), isTrue);
    });

    test('pattern special characters are escaped, not treated as regex', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/a.b?c=d'],
      );
      // '.' in the pattern must match a literal dot, not any character.
      expect(script.matchesUrl('https://example.com/aXb?cXd'), isFalse);
      expect(script.matchesUrl('https://example.com/a.b?c=d'), isTrue);
    });

    test('matches is OR: any matching rule suffices', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.foo.com/*', '*://*.bar.com/*'],
      );
      expect(script.matchesUrl('https://x.bar.com/'), isTrue);
      expect(script.matchesUrl('https://x.baz.com/'), isFalse);
    });
  });
}
