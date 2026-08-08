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
    test('formats ISO 8601 UTC time as UTC yyyy-MM-dd HH:mm', () {
      final formatted = formatReleaseTime('2026-08-08T09:30:00Z');
      // Shape check: yyyy-MM-dd HH:mm
      expect(formatted, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
      // 展示统一 UTC+0，不做本地时区转换
      expect(formatted, '2026-08-08 09:30');
    });

    test('normalizes explicit timezone offsets to UTC', () {
      // 带 +08:00 偏移的输入（17:30 东八区 == 09:30 UTC）
      expect(
          formatReleaseTime('2026-08-08T17:30:00+08:00'), '2026-08-08 09:30');
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
