import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/llm_account.dart';

/// The interval used to evaluate a quota or usage observation at [endsAt].
class LlmQuotaWindowBounds {
  final DateTime startsAt;
  final DateTime endsAt;
  final bool includeEnd;

  const LlmQuotaWindowBounds({
    required this.startsAt,
    required this.endsAt,
    this.includeEnd = false,
  });

  bool contains(DateTime value) {
    final instant = value.toUtc();
    return !instant.isBefore(startsAt.toUtc()) &&
        (includeEnd
            ? !instant.isAfter(endsAt.toUtc())
            : instant.isBefore(endsAt.toUtc()));
  }
}

class LlmQuotaWindowException implements Exception {
  const LlmQuotaWindowException();

  @override
  String toString() => 'The LLM quota window timezone is invalid.';
}

/// Computes rolling or IANA timezone-based calendar windows for M3 routing.
class LlmQuotaWindowService {
  LlmQuotaWindowService._();

  static var _timeZonesInitialized = false;

  /// Rolling months are trailing 30-day periods; calendar months use local
  /// month boundaries. Calendar 5-hour buckets are aligned to local midnight,
  /// leaving a four-hour final bucket in a normal 24-hour day.
  static LlmQuotaWindowBounds bounds(
    LlmUsageWindow window,
    LlmWindowPolicy policy,
    DateTime now,
  ) {
    final instant = now.toUtc();
    if (policy.mode == LlmWindowMode.rolling) {
      final duration = switch (window) {
        LlmUsageWindow.fiveHour => const Duration(hours: 5),
        LlmUsageWindow.day => const Duration(days: 1),
        LlmUsageWindow.week => const Duration(days: 7),
        LlmUsageWindow.month => const Duration(days: 30),
      };
      return LlmQuotaWindowBounds(
        startsAt: instant.subtract(duration),
        endsAt: instant,
        includeEnd: true,
      );
    }

    final zoneName = policy.timeZone?.trim();
    if (zoneName == null || zoneName.isEmpty) {
      throw const LlmQuotaWindowException();
    }
    _initializeTimeZones();

    final timezone.Location location;
    try {
      location = timezone.getLocation(zoneName);
    } catch (_) {
      throw const LlmQuotaWindowException();
    }
    final localNow = timezone.TZDateTime.from(instant, location);
    late final timezone.TZDateTime start;
    late final timezone.TZDateTime end;

    switch (window) {
      case LlmUsageWindow.fiveHour:
        final startHour = (localNow.hour ~/ 5) * 5;
        start = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day,
          startHour,
        );
        end = startHour == 20
            ? timezone.TZDateTime(
                location,
                localNow.year,
                localNow.month,
                localNow.day + 1,
              )
            : timezone.TZDateTime(
                location,
                localNow.year,
                localNow.month,
                localNow.day,
                startHour + 5,
              );
      case LlmUsageWindow.day:
        start = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day,
        );
        end = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day + 1,
        );
      case LlmUsageWindow.week:
        final daysFromMonday = localNow.weekday - DateTime.monday;
        start = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day - daysFromMonday,
        );
        end = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day - daysFromMonday + 7,
        );
      case LlmUsageWindow.month:
        start = timezone.TZDateTime(location, localNow.year, localNow.month, 1);
        end = timezone.TZDateTime(
          location,
          localNow.year,
          localNow.month + 1,
          1,
        );
    }

    return LlmQuotaWindowBounds(startsAt: start.toUtc(), endsAt: end.toUtc());
  }

  static void _initializeTimeZones() {
    if (_timeZonesInitialized) return;
    timezone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}
