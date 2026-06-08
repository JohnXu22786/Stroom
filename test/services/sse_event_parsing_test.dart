import 'package:flutter_test/flutter_test.dart';

/// Tests for SSE event parsing logic.
///
/// The chat_api_provider.dart expects raw SSE lines ("data: {...}")
/// from sseStream and strips the "data: " prefix.  This test validates
/// that parsing works correctly for both long and short content fragments.
void main() {
  group('SSE event parsing', () {
    /// Simulates the *defensive* parsing logic from chat_api_provider.dart.
    /// Returns the parsed data string, null for [DONE], or skips non-SSE lines.
    String? processSseLine(String line) {
      const prefix = 'data: ';
      if (!line.startsWith(prefix)) return null; // defensive guard
      final dataStr = line.substring(prefix.length).trim();
      if (dataStr == '[DONE]') return null;
      // In production, jsonDecode follows — we don't test JSON here
      return dataStr;
    }

    test('yields parsed data for normal-length content lines', () {
      final line = 'data: {"id":"1","choices":[{"delta":{"content":"Hello world"}}]}';
      final result = processSseLine(line);
      expect(result, isNotNull);
      expect(result, contains('Hello world'));
    });

    test('yields parsed data for short content lines (the web bug)', () {
      // Content shorter than "data: ".length (6) triggers RangeError
      // if we strip the prefix from an already-parsed content string.
      final line = 'data: {"id":"2","choices":[{"delta":{"content":"Hel"}}]}';
      expect(() => processSseLine(line), returnsNormally);
      final result = processSseLine(line);
      expect(result, isNotNull);
      expect(result, contains('Hel'));
    });

    test('yields parsed data for single-character content', () {
      final line = 'data: {"id":"3","choices":[{"delta":{"content":"a"}}]}';
      expect(() => processSseLine(line), returnsNormally);
      final result = processSseLine(line);
      expect(result, isNotNull);
      expect(result, contains('"a"'));
    });

    test('handles [DONE] signal correctly', () {
      final line = 'data: [DONE]';
      final result = processSseLine(line);
      expect(result, isNull);
    });

    test('handles empty data string', () {
      final line = 'data: ';
      final result = processSseLine(line);
      expect(result, isEmpty);
    });

    test('handles lines that are exactly "data: " length (6 chars)', () {
      final line = 'data: ';
      expect(() => processSseLine(line), returnsNormally);
    });

    test('defensive guard: skips non-SSE lines without crash', () {
      // This is the 3rd occurrence — a line without "data: " prefix
      // should be skipped, not crash with RangeError.
      final line = 'Hel';
      expect(() => processSseLine(line), returnsNormally);
      expect(processSseLine(line), isNull);
    });

    test('defensive guard: empty line skipped without crash', () {
      expect(() => processSseLine(''), returnsNormally);
      expect(processSseLine(''), isNull);
    });

    test('defensive guard: arbitrary text skipped without crash', () {
      expect(() => processSseLine('some random text here'), returnsNormally);
      expect(processSseLine('some random text here'), isNull);
    });
  });
}
