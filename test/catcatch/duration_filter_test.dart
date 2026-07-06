import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/sniffing_engine.dart';
import 'package:stroom/catcatch/engine/executor_utils.dart';
import 'package:stroom/catcatch/engine/executor_media.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  group('SniffingEngine.filterByDuration', () {
    final mediaWithDuration = MediaResource(
      url: 'https://example.com/video.mp4',
      name: 'video',
      ext: 'mp4',
      duration: '00:01:00.000', // 60 seconds
      isPlayable: true,
    );

    final mediaWithDuration2 = MediaResource(
      url: 'https://example.com/video2.mp4',
      name: 'video2',
      ext: 'mp4',
      duration: '00:03:05.000', // 185 seconds
      isPlayable: true,
    );

    final mediaWithDuration3 = MediaResource(
      url: 'https://example.com/video3.mp4',
      name: 'video3',
      ext: 'mp4',
      duration: '01:00:00.000', // 3600 seconds
      isPlayable: true,
    );

    final mediaWithoutDuration = MediaResource(
      url: 'https://example.com/no_duration.mp4',
      name: 'no_duration',
      ext: 'mp4',
    );

    final mediaWithUnparseableDuration = MediaResource(
      url: 'https://example.com/bad_duration.mp4',
      name: 'bad_duration',
      ext: 'mp4',
      duration: 'invalid',
    );

    test('returns all resources when expectedDurationSec <= 0', () {
      final resources = [mediaWithDuration, mediaWithoutDuration];
      final result = SniffingEngine.filterByDuration(resources, 0);
      expect(result, hasLength(2));
    });

    test('keeps resources with null duration', () {
      final resources = [mediaWithoutDuration];
      // Even with expectedDurationSec > 0, resources without duration are kept
      final result = SniffingEngine.filterByDuration(resources, 60);
      expect(result, hasLength(1));
      expect(result.first.url, mediaWithoutDuration.url);
    });

    test('keeps resources with unparseable duration', () {
      final resources = [mediaWithUnparseableDuration];
      final result = SniffingEngine.filterByDuration(resources, 60);
      expect(result, hasLength(1));
      expect(result.first.url, mediaWithUnparseableDuration.url);
    });

    test('keeps resources within ±tolerance seconds (exact match)', () {
      final resources = [mediaWithDuration]; // 60 seconds
      final result =
          SniffingEngine.filterByDuration(resources, 60, toleranceSec: 3);
      expect(result, hasLength(1));
      expect(result.first.url, mediaWithDuration.url);
    });

    test('keeps resources within ±tolerance seconds (lower boundary)', () {
      final resources = [mediaWithDuration]; // 60 seconds
      // 60 - 3 = 57 seconds → diff = |60 - 57| = 3 <= 3 → match
      final result =
          SniffingEngine.filterByDuration(resources, 57, toleranceSec: 3);
      expect(result, hasLength(1));
    });

    test('keeps resources within ±tolerance seconds (upper boundary)', () {
      final resources = [mediaWithDuration]; // 60 seconds
      // 60 + 3 = 63 seconds → diff = |60 - 63| = 3 <= 3 → match
      final result =
          SniffingEngine.filterByDuration(resources, 63, toleranceSec: 3);
      expect(result, hasLength(1));
    });

    test('excludes resources outside ±tolerance seconds', () {
      final resources = [mediaWithDuration]; // 60 seconds
      // 60 - 4 = 56 seconds → diff = |60 - 56| = 4 > 3 → no match
      final result =
          SniffingEngine.filterByDuration(resources, 56, toleranceSec: 3);
      expect(result, isEmpty);
    });

    test('excludes resources above upper bound of tolerance', () {
      final resources = [mediaWithDuration]; // 60 seconds
      // 60 + 4 = 64 seconds → diff = |60 - 64| = 4 > 3 → no match
      final result =
          SniffingEngine.filterByDuration(resources, 64, toleranceSec: 3);
      expect(result, isEmpty);
    });

    test('returns empty list when input is empty', () {
      final result = SniffingEngine.filterByDuration([], 60);
      expect(result, isEmpty);
    });

    test('handles mixed resources (some with, some without duration)', () {
      final resources = [mediaWithDuration, mediaWithoutDuration]; // 60s + null
      // Expected 60 seconds: 60 matches, null is kept
      final result =
          SniffingEngine.filterByDuration(resources, 60, toleranceSec: 3);
      expect(result, hasLength(2));
    });

    test('handles mixed resources with some excluded', () {
      final resources = [
        mediaWithDuration, // 60s - within range of 60
        mediaWithDuration2, // 185s - outside range of 60
        mediaWithoutDuration, // null - kept
      ];
      final result =
          SniffingEngine.filterByDuration(resources, 60, toleranceSec: 3);
      expect(result, hasLength(2));
      expect(result.map((r) => r.url), contains(mediaWithDuration.url));
      expect(result.map((r) => r.url), contains(mediaWithoutDuration.url));
      expect(result.map((r) => r.url), isNot(contains(mediaWithDuration2.url)));
    });

    test('with tolerance = 0 only matches exact', () {
      final exactMatch = MediaResource(
        url: 'https://example.com/exact.mp4',
        name: 'exact',
        ext: 'mp4',
        duration: '00:02:00.000', // 120 seconds
      );
      final closeMatch = MediaResource(
        url: 'https://example.com/close.mp4',
        name: 'close',
        ext: 'mp4',
        duration: '00:02:01.000', // 121 seconds
      );

      final result = SniffingEngine.filterByDuration(
          [exactMatch, closeMatch], 120,
          toleranceSec: 0);
      expect(result, hasLength(1));
      expect(result.first.url, exactMatch.url);
    });

    test('uses default tolerance from config (3 seconds)', () {
      final resources = [mediaWithDuration]; // 60 seconds
      // 63 seconds (diff=3) should match with default tolerance of 3
      final result = SniffingEngine.filterByDuration(resources, 63);
      expect(result, hasLength(1));
    });
  });

  group('_parseDurationToSeconds (via filterByDuration)', () {
    test('parses HH:MM:SS.mmm format (from formatExecutorDuration)', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '01:30:15.000',
      );
      final result = SniffingEngine.filterByDuration([resource], 5415);
      expect(result, hasLength(1));
    });

    test('parses H:MM:SS.mmmmmm format (from Duration.toString)', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '1:30:15.000000',
      );
      final result = SniffingEngine.filterByDuration([resource], 5415);
      expect(result, hasLength(1));
    });

    test('parses MM:SS.mmmmmm format (from Duration.toString for <1h)', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '2:05.000000', // 125 seconds
      );
      final result = SniffingEngine.filterByDuration([resource], 125);
      expect(result, hasLength(1));
    });

    test('handles duration with milliseconds', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '00:00:30.500', // 30.5 seconds
      );
      // User enters 30 seconds → diff = |30.5 - 30| = 0.5 <= 3 → match
      final result = SniffingEngine.filterByDuration([resource], 30);
      expect(result, hasLength(1));
    });

    test('handles duration with milliseconds just beyond tolerance', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '00:00:34.000', // 34 seconds
      );
      // User enters 30 seconds → diff = |34 - 30| = 4 > 3 → no match
      final result = SniffingEngine.filterByDuration([resource], 30);
      expect(result, isEmpty);
    });

    test('handles zero duration', () {
      final resource = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        duration: '00:00:00.000',
      );
      // User enters 0 seconds → expectedDurationSec == 0 → no filtering
      final result = SniffingEngine.filterByDuration([resource], 0);
      expect(result, hasLength(1));
    });
  });

  group('parseDurationToSeconds (executor_utils)', () {
    test('parses HH:MM:SS.mmm format correctly', () {
      expect(parseDurationToSeconds('01:30:15.000'), closeTo(5415, 0.001));
    });

    test('parses H:MM:SS.mmmmmm format correctly', () {
      expect(parseDurationToSeconds('1:30:15.000000'), closeTo(5415, 0.001));
    });

    test('parses MM:SS format correctly', () {
      expect(parseDurationToSeconds('02:05'), closeTo(125, 0.001));
    });

    test('parses MM:SS.mmmmmm format correctly', () {
      expect(parseDurationToSeconds('2:05.500000'), closeTo(125.5, 0.001));
    });

    test('parses raw seconds correctly', () {
      expect(parseDurationToSeconds('5415'), closeTo(5415, 0.001));
    });

    test('returns null for invalid format', () {
      expect(parseDurationToSeconds('invalid'), isNull);
    });
  });

  group('formatExecutorDuration', () {
    test('formats Duration with all components', () {
      final d = const Duration(hours: 1, minutes: 30, seconds: 15);
      expect(formatExecutorDuration(d), '01:30:15.000');
    });

    test('formats Duration with milliseconds', () {
      final d = const Duration(
        hours: 0,
        minutes: 2,
        seconds: 5,
        milliseconds: 500,
      );
      expect(formatExecutorDuration(d), '00:02:05.500');
    });

    test('formats Duration with zero values', () {
      final d = Duration.zero;
      expect(formatExecutorDuration(d), '00:00:00.000');
    });

    test('round-trip: format then parse returns same value', () {
      final original = const Duration(hours: 2, minutes: 15, seconds: 30);
      final formatted = formatExecutorDuration(original);
      final parsed = parseDurationToSeconds(formatted);
      expect(parsed, closeTo(original.inSeconds.toDouble(), 0.001));
    });
  });

  group('buildDurationFilterDetail', () {
    test('shows remaining count when some were excluded', () {
      final result = buildDurationFilterDetail(10, 3, 120);
      expect(result, contains('剩余3个结果'));
      expect(result, contains('已排除7个'));
    });

    test('shows all matched when none excluded', () {
      final result = buildDurationFilterDetail(5, 5, 120);
      expect(result, contains('全部匹配'));
    });

    test('formats duration string with hours, minutes, seconds', () {
      final result = buildDurationFilterDetail(10, 5, 3661); // 1h 1m 1s
      expect(result, contains('1小时'));
      expect(result, contains('1分钟'));
      expect(result, contains('1秒'));
    });

    test('formats duration string with only seconds', () {
      final result = buildDurationFilterDetail(10, 5, 30);
      expect(result, contains('30秒'));
      expect(result, isNot(contains('小时')));
      expect(result, isNot(contains('分钟')));
    });
  });
}
