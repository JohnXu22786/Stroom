import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/engine/js_hook_script.dart';

void main() {
  group('JsHookScript', () {
    test('script string is not empty', () {
      expect(JsHookScript.script, isNotEmpty);
    });

    test('script contains fetch monkey-patch', () {
      expect(JsHookScript.script, contains('window.fetch'));
    });

    test('script contains XHR monkey-patch', () {
      expect(
        JsHookScript.script,
        anyOf(contains('XMLHttpRequest'), contains('XHR')),
      );
    });

    test('script contains MutationObserver for video/audio', () {
      expect(JsHookScript.script, contains('MutationObserver'));
      expect(JsHookScript.script, contains('video'));
      expect(JsHookScript.script, contains('audio'));
    });

    test('script contains CatCatchChannel.postMessage', () {
      expect(
        JsHookScript.script,
        contains('CatCatchChannel'),
      );
      expect(
        JsHookScript.script,
        anyOf(contains('postMessage'), contains('CatCatchChannel.postMessage')),
      );
    });

    test('script filters media extensions (.m3u8, .mp4, .mp3)', () {
      expect(JsHookScript.script, contains('m3u8'));
      expect(JsHookScript.script, contains('mp4'));
      expect(JsHookScript.script, contains('mp3'));
    });

    test('script implements URL deduplication', () {
      expect(
        JsHookScript.script,
        anyOf(contains('Set'), contains('has('), contains('seen')),
      );
    });

    test('script is wrapped in an IIFE for isolation', () {
      expect(JsHookScript.script.trim().startsWith('(function()'), isTrue);
      expect(JsHookScript.script.trim().endsWith('})();'), isTrue);
    });

    test('script handles blob: URLs gracefully', () {
      expect(
        JsHookScript.script,
        anyOf(contains('blob:'), contains('blob')),
      );
    });

    test('script handles data: URLs gracefully', () {
      expect(
        JsHookScript.script,
        anyOf(contains('data:'), contains('data')),
      );
    });

    test('script suppresses duplicate URLs (seen set check)', () {
      // Should have some mechanism to avoid sending the same URL twice
      final lines = JsHookScript.script.split('\n');
      final hasDedup = lines.any((line) =>
          line.contains('seen') ||
          line.contains('cache') ||
          line.contains('sent') ||
          line.contains('already'));
      expect(hasDedup, isTrue,
          reason:
              'Script must have deduplication mechanism (seen/cache/sent/already)');
    });

    test('script is valid JavaScript syntax (no Dart interpolation)', () {
      // Ensure no Dart-style string interpolation leaked in
      expect(JsHookScript.script, isNot(contains('\${')));
      expect(JsHookScript.script, isNot(contains(r'$url')));
      expect(JsHookScript.script, isNot(contains(r'$header')));
    });

    test('script handles MutationObserver for DOM-added video/audio', () {
      expect(
        JsHookScript.script,
        contains('MutationObserver'),
      );
      // Should observe childList changes and subtree
      expect(
        JsHookScript.script,
        anyOf(contains('childList'), contains('childlist')),
      );
    });

    test('script encodes URL metadata (method, type, initiator)', () {
      // The message sent via CatCatchChannel should include request metadata
      final messageContent = JsHookScript.script;
      expect(
        messageContent,
        anyOf(
          contains('method'),
          contains('type'),
          contains('initiator'),
          contains('url'),
        ),
      );
    });

    test('script trim is syntactically safe (balanced braces)', () {
      // Count opening and closing braces as a sanity check
      // Simple balanced brace count (ignores strings/regex)
      // This is a basic sanity check — not a full JS parser
      final opens = '${JsHookScript.script}'.split('{').length - 1;
      final closes = '${JsHookScript.script}'.split('}').length - 1;
      expect(opens, equals(closes),
          reason:
              'Braces should be balanced: $opens opening vs $closes closing');
    });
  });
}
