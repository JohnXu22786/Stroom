import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/app_version.dart';

void main() {
  group('decodeReleaseNotes', () {
    test('decodes UTF-8 base64 encoded release notes', () {
      const notes = '修复了若干问题\n新增深色模式';
      final encoded = base64Encode(utf8.encode(notes));
      expect(decodeReleaseNotes(encoded), notes);
    });

    test('returns empty string for empty input', () {
      expect(decodeReleaseNotes(''), '');
    });

    test('returns empty string for invalid base64 input', () {
      expect(decodeReleaseNotes('!!!not-base64!!!'), '');
    });
  });

  group('formatReleaseTime', () {
    test('formats ISO 8601 UTC time as local yyyy-MM-dd HH:mm', () {
      final formatted = formatReleaseTime('2026-08-08T09:30:00Z');
      // Shape check: yyyy-MM-dd HH:mm
      expect(formatted, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
      // Exact check against the same instant converted to local time
      final local = DateTime.parse('2026-08-08T09:30:00Z').toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(
        formatted,
        '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}',
      );
    });

    test('returns empty string for empty input', () {
      expect(formatReleaseTime(''), '');
    });

    test('returns empty string for unparseable input', () {
      expect(formatReleaseTime('not-a-date'), '');
    });
  });

  // The build-info constants are compile-time dart-defines; in tests (no
  // --dart-define passed) they must fall back to safe empty defaults.
  test('build-info constants fall back to empty defaults without defines', () {
    expect(appReleaseTime, '');
    expect(appReleaseNotesEncoded, '');
    expect(appReleaseNotes, '');
    expect(appReleaseTimeFormatted, '');
  });
}
