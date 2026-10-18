import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_quota_window_service.dart';

void main() {
  group('LlmQuotaWindowService', () {
    test('rolling windows use exact trailing durations', () {
      final now = DateTime.utc(2026, 10, 18, 12, 34, 56);
      const durations = <LlmUsageWindow, Duration>{
        LlmUsageWindow.fiveHour: Duration(hours: 5),
        LlmUsageWindow.day: Duration(days: 1),
        LlmUsageWindow.week: Duration(days: 7),
        LlmUsageWindow.month: Duration(days: 30),
      };

      for (final entry in durations.entries) {
        final bounds = LlmQuotaWindowService.bounds(
          entry.key,
          const LlmWindowPolicy(),
          now,
        );
        expect(bounds.startsAt, now.subtract(entry.value));
        expect(bounds.endsAt, now);
        expect(bounds.contains(bounds.startsAt), isTrue);
        expect(bounds.contains(bounds.endsAt), isTrue);
      }
    });

    test(
      'calendar windows honor local five-hour, day, week, and month edges',
      () {
        // 12:34 PDT on Wednesday, May 20, 2026.
        final now = DateTime.utc(2026, 5, 20, 19, 34);
        LlmWindowPolicy calendar() => const LlmWindowPolicy(
          mode: LlmWindowMode.calendar,
          timeZone: 'America/Los_Angeles',
        );

        final fiveHour = LlmQuotaWindowService.bounds(
          LlmUsageWindow.fiveHour,
          calendar(),
          now,
        );
        expect(fiveHour.startsAt, DateTime.utc(2026, 5, 20, 17));
        expect(fiveHour.endsAt, DateTime.utc(2026, 5, 20, 22));

        final day = LlmQuotaWindowService.bounds(
          LlmUsageWindow.day,
          calendar(),
          now,
        );
        expect(day.startsAt, DateTime.utc(2026, 5, 20, 7));
        expect(day.endsAt, DateTime.utc(2026, 5, 21, 7));
        expect(day.contains(day.endsAt), isFalse);
        final nextDay = LlmQuotaWindowService.bounds(
          LlmUsageWindow.day,
          calendar(),
          day.endsAt,
        );
        expect(nextDay.startsAt, day.endsAt);
        expect(nextDay.contains(day.endsAt), isTrue);

        final week = LlmQuotaWindowService.bounds(
          LlmUsageWindow.week,
          calendar(),
          now,
        );
        expect(week.startsAt, DateTime.utc(2026, 5, 18, 7));
        expect(week.endsAt, DateTime.utc(2026, 5, 25, 7));

        final month = LlmQuotaWindowService.bounds(
          LlmUsageWindow.month,
          calendar(),
          now,
        );
        expect(month.startsAt, DateTime.utc(2026, 5, 1, 7));
        expect(month.endsAt, DateTime.utc(2026, 6, 1, 7));
      },
    );

    test('calendar day boundaries follow daylight-saving transitions', () {
      // Noon PDT on the spring-forward day in Los Angeles.
      final now = DateTime.utc(2026, 3, 8, 19);
      const policy = LlmWindowPolicy(
        mode: LlmWindowMode.calendar,
        timeZone: 'America/Los_Angeles',
      );

      final bounds = LlmQuotaWindowService.bounds(
        LlmUsageWindow.day,
        policy,
        now,
      );

      expect(bounds.startsAt, DateTime.utc(2026, 3, 8, 8));
      expect(bounds.endsAt, DateTime.utc(2026, 3, 9, 7));
      expect(
        bounds.endsAt.difference(bounds.startsAt),
        const Duration(hours: 23),
      );
    });

    test('calendar mode requires a valid explicit IANA timezone', () {
      expect(
        () => LlmQuotaWindowService.bounds(
          LlmUsageWindow.day,
          const LlmWindowPolicy(mode: LlmWindowMode.calendar),
          DateTime.utc(2026, 10, 18),
        ),
        throwsA(isA<LlmQuotaWindowException>()),
      );
      expect(
        () => LlmQuotaWindowService.bounds(
          LlmUsageWindow.day,
          const LlmWindowPolicy(
            mode: LlmWindowMode.calendar,
            timeZone: 'No/Such_Zone',
          ),
          DateTime.utc(2026, 10, 18),
        ),
        throwsA(isA<LlmQuotaWindowException>()),
      );
    });
  });
}
