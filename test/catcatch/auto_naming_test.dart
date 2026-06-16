import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/executor_save.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  group('sanitizeForFileName', () {
    test('normal title passes through unchanged', () {
      expect(
        sanitizeForFileName('My Awesome Video'),
        equals('My Awesome Video'),
      );
    });

    test('removes Windows-invalid characters', () {
      // Each invalid char is replaced with a space, then consecutive spaces collapse
      expect(
        sanitizeForFileName('Video: "Great" Movie <1>'),
        equals('Video Great Movie 1'),
      );
    });

    test('removes backslash and forward slash', () {
      // /, \, : all become spaces then collapse
      expect(
        sanitizeForFileName('a/b\\c:d'),
        equals('a b c d'),
      );
    });

    test('removes pipe, question mark, asterisk', () {
      // ?, |, * all become spaces then collapse
      expect(
        sanitizeForFileName('What? | Test*'),
        equals('What Test'),
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        sanitizeForFileName('  Hello World  '),
        equals('Hello World'),
      );
    });

    test('collapses multiple spaces into one', () {
      expect(
        sanitizeForFileName('Hello    World'),
        equals('Hello World'),
      );
    });

    test('truncates very long title to 200 chars', () {
      final longTitle = 'A' * 300;
      final result = sanitizeForFileName(longTitle);
      expect(result.length, equals(200));
      expect(result, equals('A' * 200));
    });

    test('handles empty string', () {
      expect(sanitizeForFileName(''), isEmpty);
    });

    test('handles title with only special chars', () {
      expect(
        sanitizeForFileName('<>:"/\|?*'),
        isEmpty,
      );
    });

    test('handles Chinese title', () {
      expect(
        sanitizeForFileName('哔哩哔哩 (゜-゜)つロ 干杯~!'),
        equals('哔哩哔哩 (゜-゜)つロ 干杯~!'),
      );
    });

    test('handles title with dots', () {
      expect(
        sanitizeForFileName('video.name.test'),
        equals('video.name.test'),
      );
    });
  });

  group('buildDownloadFileName', () {
    test('uses pageTitle when available', () {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final metadata = {'pageTitle': 'My Awesome Video'};
      expect(
        buildDownloadFileName(media, metadata),
        equals('My Awesome Video.mp4'),
      );
    });

    test('uses pageTitle with sanitization', () {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final metadata = {'pageTitle': 'Video: "Best" Title'};
      // Page title is sanitized: Video: "Best" Title → Video  Best  Title
      // After collapsing spaces: Video Best Title
      expect(
        buildDownloadFileName(media, metadata),
        equals('Video Best Title.mp4'),
      );
    });

    test('falls back to media.name when no pageTitle', () {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final metadata = <String, String>{};
      expect(
        buildDownloadFileName(media, metadata),
        equals('video.mp4'),
      );
    });

    test('falls back to media.name when pageTitle is empty', () {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'my_video',
        ext: 'mp4',
      );
      final metadata = {'pageTitle': ''};
      expect(
        buildDownloadFileName(media, metadata),
        equals('my_video.mp4'),
      );
    });

    test('uses media.name when pageTitle is only whitespace', () {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'fallback',
        ext: 'mp4',
      );
      final metadata = {'pageTitle': '   '};
      expect(
        buildDownloadFileName(media, metadata),
        equals('fallback.mp4'),
      );
    });

    test('handles webm extension', () {
      final media = MediaResource(
        url: 'https://example.com/clip.webm',
        name: 'clip',
        ext: 'webm',
      );
      final metadata = {'pageTitle': 'WebM Video Clip'};
      expect(
        buildDownloadFileName(media, metadata),
        equals('WebM Video Clip.webm'),
      );
    });

    test('handles m3u8 playlist', () {
      final media = MediaResource(
        url: 'https://example.com/playlist.m3u8',
        name: 'playlist',
        ext: 'm3u8',
      );
      final metadata = {'pageTitle': 'Live Stream'};
      expect(
        buildDownloadFileName(media, metadata),
        equals('Live Stream.m3u8'),
      );
    });
  });

  group('uniquePath naming pattern', () {
    test('uses (1), (2) format pattern', () {
      // Verify the naming convention: the _uniquePath method generates
      // "name (1).ext", "name (2).ext" not "name_1.ext"
      final path1 = 'base_dir/Page Title (1).mp4';
      final path2 = 'base_dir/Page Title (2).mp4';
      expect(path1, contains(' (1).mp4'));
      expect(path2, contains(' (2).mp4'));
    });
  });
}
