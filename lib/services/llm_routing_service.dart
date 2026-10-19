import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../models/llm_account.dart';
import 'llm_account_migration_service.dart';
import 'llm_connector_service.dart';
import 'llm_quota_window_service.dart';

final _routingIdentifierPattern = RegExp(
  r'^[A-Za-z0-9_][A-Za-z0-9._:/-]{0,127}$',
);

final _routingStateIdentityPattern = RegExp(r'^[^\s\x00-\x1f\x7f]{1,1024}$');

enum LlmRequestFailureKind {
  authentication,
  quotaExhausted,
  rateLimited,
  connection,
  server,
  invalidRequest,
  cancelled,
  other,
}

class LlmRouteRequestException implements Exception {
  final int? statusCode;
  final String? code;
  final Map<String, String> headers;
  final DateTime? resetAt;

  const LlmRouteRequestException({
    this.statusCode,
    this.code,
    this.headers = const {},
    this.resetAt,
  });

  @override
  String toString() => 'The LLM provider request failed.';
}

class LlmRequestFailureClassification {
  final LlmRequestFailureKind kind;
  final bool retryable;
  final DateTime? cooldownUntil;

  const LlmRequestFailureClassification({
    required this.kind,
    required this.retryable,
    this.cooldownUntil,
  });
}

/// Classifies only structured status/type information; response text is never
/// copied into persisted routing state or diagnostics.
class LlmRequestErrorClassifier {
  LlmRequestErrorClassifier._();

  static LlmRequestFailureClassification classify(
    Object error, {
    required DateTime now,
    DateTime? resetAt,
  }) {
    final instant = now.toUtc();
    var kind = LlmRequestFailureKind.other;
    var statusCode = 0;
    var code = '';
    final headers = <String, String>{};
    var explicitReset = resetAt;

    if (error is LlmRouteRequestException) {
      statusCode = error.statusCode ?? 0;
      code = error.code?.toLowerCase().trim() ?? '';
      for (final entry in error.headers.entries) {
        headers[entry.key.toLowerCase()] = entry.value;
      }
      explicitReset ??= error.resetAt;
    } else if (error is DioException) {
      statusCode = error.response?.statusCode ?? 0;
      final responseHeaders = error.response?.headers.map;
      if (responseHeaders != null) {
        for (final entry in responseHeaders.entries) {
          if (entry.value.isNotEmpty) {
            headers[entry.key.toLowerCase()] = entry.value.join(',');
          }
        }
      }
      if (error.type == DioExceptionType.cancel) {
        kind = LlmRequestFailureKind.cancelled;
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        kind = LlmRequestFailureKind.connection;
      }
    } else if (error is TimeoutException) {
      kind = LlmRequestFailureKind.connection;
    }

    if (kind != LlmRequestFailureKind.cancelled &&
        kind != LlmRequestFailureKind.connection) {
      kind = _classifyStatusOrCode(statusCode, code);
    }
    final retryable = switch (kind) {
      LlmRequestFailureKind.authentication ||
      LlmRequestFailureKind.quotaExhausted ||
      LlmRequestFailureKind.rateLimited ||
      LlmRequestFailureKind.connection ||
      LlmRequestFailureKind.server => true,
      _ => false,
    };
    if (!retryable) {
      return LlmRequestFailureClassification(kind: kind, retryable: false);
    }

    final retryAt = _retryAfter(headers['retry-after'], instant);
    final headerReset = _resetAt(headers, instant);
    final hintedUntil = _laterOf([
      retryAt,
      explicitReset?.toUtc(),
      headerReset,
    ]);
    final defaultDelay = switch (kind) {
      LlmRequestFailureKind.authentication => const Duration(minutes: 5),
      LlmRequestFailureKind.quotaExhausted ||
      LlmRequestFailureKind.rateLimited => const Duration(minutes: 1),
      LlmRequestFailureKind.connection => const Duration(seconds: 15),
      LlmRequestFailureKind.server => const Duration(seconds: 30),
      _ => Duration.zero,
    };
    final cooldownUntil = hintedUntil ?? instant.add(defaultDelay);
    return LlmRequestFailureClassification(
      kind: kind,
      retryable: true,
      cooldownUntil: cooldownUntil,
    );
  }

  static LlmRequestFailureKind _classifyStatusOrCode(int status, String code) {
    if (status == 401) {
      return LlmRequestFailureKind.authentication;
    }
    if (code.contains('unauthor') ||
        code.contains('invalid_api_key') ||
        code.contains('authentication')) {
      return LlmRequestFailureKind.authentication;
    }
    if (code.contains('quota') || code.contains('insufficient_credit')) {
      return LlmRequestFailureKind.quotaExhausted;
    }
    if (code.contains('rate_limit') || code.contains('rate-limit')) {
      return LlmRequestFailureKind.rateLimited;
    }
    if (status == 403) return LlmRequestFailureKind.authentication;
    if (status == 402) return LlmRequestFailureKind.quotaExhausted;
    if (status == 429) return LlmRequestFailureKind.rateLimited;
    if (status == 408) return LlmRequestFailureKind.connection;
    if (status >= 500 && status <= 599) return LlmRequestFailureKind.server;
    if (status >= 400 && status <= 499) {
      return LlmRequestFailureKind.invalidRequest;
    }
    if (code.contains('connection') || code.contains('timeout')) {
      return LlmRequestFailureKind.connection;
    }
    if (code.contains('invalid_request') || code.contains('invalid-argument')) {
      return LlmRequestFailureKind.invalidRequest;
    }
    if (code.contains('server') || code.contains('upstream_5')) {
      return LlmRequestFailureKind.server;
    }
    return LlmRequestFailureKind.other;
  }

  static DateTime? _retryAfter(String? value, DateTime now) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final seconds = num.tryParse(trimmed);
    if (seconds != null) {
      if (seconds < 0 || !seconds.isFinite) return null;
      final milliseconds = seconds * 1000;
      final remainingDateTimeRange =
          8640000000000000 - now.millisecondsSinceEpoch;
      if (!milliseconds.isFinite || milliseconds > remainingDateTimeRange) {
        return null;
      }
      return now.add(Duration(milliseconds: milliseconds.round()));
    }
    final parsed = DateTime.tryParse(trimmed) ?? _parseHttpDate(trimmed);
    if (parsed == null) return null;
    final utc = parsed.toUtc();
    return utc.isAfter(now) ? utc : now;
  }

  static DateTime? _resetAt(Map<String, String> headers, DateTime now) {
    DateTime? latest;
    for (final name in const [
      'x-ratelimit-reset',
      'x-rate-limit-reset',
      'x-quota-reset',
      'x-reset-at',
    ]) {
      final value = headers[name];
      if (value == null || value.trim().isEmpty) continue;
      final numeric = num.tryParse(value.trim());
      DateTime? parsed;
      if (numeric != null && numeric > 0 && numeric.isFinite) {
        final millisecondsValue = numeric > 1000000000000
            ? numeric
            : numeric * 1000;
        // DateTime's supported Unix-millisecond range is finite. Ignore
        // malformed provider hints before rounding/converting so parsing an
        // extreme value cannot escape request cleanup and strand a reservation.
        if (millisecondsValue <= 8640000000000000) {
          parsed = DateTime.fromMillisecondsSinceEpoch(
            millisecondsValue.round(),
            isUtc: true,
          );
        }
      }
      parsed ??= DateTime.tryParse(value.trim()) ?? _parseHttpDate(value);
      if (parsed == null) continue;
      final utc = parsed.toUtc();
      if (utc.isAfter(now) && (latest == null || utc.isAfter(latest))) {
        latest = utc;
      }
    }
    return latest;
  }

  static DateTime? _parseHttpDate(String value) {
    try {
      return DateFormat(
        "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
        'en_US',
      ).parseUtc(value.trim());
    } catch (_) {
      return null;
    }
  }

  static DateTime? _laterOf(List<DateTime?> values) {
    DateTime? latest;
    for (final value in values) {
      if (value != null && (latest == null || value.isAfter(latest))) {
        latest = value;
      }
    }
    return latest;
  }
}

class LlmUsageMeasurement {
  final String unit;
  final num value;
  final String source;

  const LlmUsageMeasurement({
    required this.unit,
    required this.value,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'unit': unit,
    'value': value,
    'source': source,
  };

  factory LlmUsageMeasurement.fromMap(Map<String, dynamic> map) {
    final unit = map['unit'];
    final value = map['value'];
    final source = map['source'];
    if (unit is! String ||
        !_routingIdentifierPattern.hasMatch(unit) ||
        value is! num ||
        !value.isFinite ||
        value < 0 ||
        source is! String ||
        !_routingIdentifierPattern.hasMatch(source)) {
      throw const LlmRoutingStateException();
    }
    return LlmUsageMeasurement(unit: unit, value: value, source: source);
  }
}

class LlmUsageEvent {
  final String accountId;
  final String groupId;
  final DateTime occurredAt;
  final List<LlmUsageMeasurement> measurements;

  LlmUsageEvent({
    required this.accountId,
    required this.groupId,
    required this.occurredAt,
    required List<LlmUsageMeasurement> measurements,
  }) : measurements = List.unmodifiable(measurements);

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'groupId': groupId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'measurements': measurements.map((item) => item.toMap()).toList(),
  };

  factory LlmUsageEvent.fromMap(Map<String, dynamic> map) {
    final accountId = map['accountId'];
    final groupId = map['groupId'];
    final occurredAt = map['occurredAt'];
    final measurements = map['measurements'];
    final instant = occurredAt is String ? DateTime.tryParse(occurredAt) : null;
    if (accountId is! String ||
        accountId.isEmpty ||
        groupId is! String ||
        groupId.isEmpty ||
        instant == null ||
        measurements is! List) {
      throw const LlmRoutingStateException();
    }
    final parsedMeasurements = <LlmUsageMeasurement>[];
    for (final item in measurements) {
      if (item is! Map) throw const LlmRoutingStateException();
      parsedMeasurements.add(
        LlmUsageMeasurement.fromMap(Map<String, dynamic>.from(item)),
      );
    }
    if (parsedMeasurements.isEmpty) throw const LlmRoutingStateException();
    return LlmUsageEvent(
      accountId: accountId,
      groupId: groupId,
      occurredAt: instant.toUtc(),
      measurements: parsedMeasurements,
    );
  }
}

class LlmCooldown {
  final DateTime until;
  final LlmRequestFailureKind reason;

  const LlmCooldown({required this.until, required this.reason});

  Map<String, dynamic> toMap() => {
    'until': until.toUtc().toIso8601String(),
    'reason': reason.name,
  };

  factory LlmCooldown.fromMap(Map<String, dynamic> map) {
    final untilValue = map['until'];
    final until = untilValue is String ? DateTime.tryParse(untilValue) : null;
    final reasonName = map['reason'];
    LlmRequestFailureKind? reason;
    for (final item in LlmRequestFailureKind.values) {
      if (item.name == reasonName) {
        reason = item;
        break;
      }
    }
    if (until == null || reason == null) {
      throw const LlmRoutingStateException();
    }
    return LlmCooldown(until: until.toUtc(), reason: reason);
  }
}

class LlmRoutingRuntimeState {
  final DateTime trackingStartedAt;
  final List<LlmUsageEvent> events;
  final List<LlmPendingUsage> pendingUsage;
  final Map<String, LlmCooldown> cooldowns;

  LlmRoutingRuntimeState({
    required this.trackingStartedAt,
    required List<LlmUsageEvent> events,
    List<LlmPendingUsage> pendingUsage = const [],
    required Map<String, LlmCooldown> cooldowns,
  }) : events = List.unmodifiable(events),
       pendingUsage = List.unmodifiable(pendingUsage),
       cooldowns = Map.unmodifiable(cooldowns);

  Map<String, dynamic> toMap() => {
    'version': 1,
    'trackingStartedAt': trackingStartedAt.toUtc().toIso8601String(),
    'events': events.map((item) => item.toMap()).toList(),
    'pendingUsage': pendingUsage.map((item) => item.toMap()).toList(),
    'cooldowns': {
      for (final entry in cooldowns.entries) entry.key: entry.value.toMap(),
    },
  };

  factory LlmRoutingRuntimeState.fromMap(Map<String, dynamic> map) {
    final startedValue = map['trackingStartedAt'];
    final started = startedValue is String
        ? DateTime.tryParse(startedValue)
        : null;
    final events = map['events'];
    final pendingUsage = map['pendingUsage'] ?? const [];
    final cooldowns = map['cooldowns'];
    if (map['version'] != 1 ||
        started == null ||
        events is! List ||
        pendingUsage is! List ||
        cooldowns is! Map) {
      throw const LlmRoutingStateException();
    }
    final parsedEvents = <LlmUsageEvent>[];
    for (final item in events) {
      if (item is! Map) throw const LlmRoutingStateException();
      parsedEvents.add(LlmUsageEvent.fromMap(Map<String, dynamic>.from(item)));
    }
    final parsedPendingUsage = <LlmPendingUsage>[];
    final pendingIds = <String>{};
    for (final item in pendingUsage) {
      if (item is! Map) throw const LlmRoutingStateException();
      final pending = LlmPendingUsage.fromMap(Map<String, dynamic>.from(item));
      if (!pendingIds.add(pending.id)) throw const LlmRoutingStateException();
      parsedPendingUsage.add(pending);
    }
    final parsedCooldowns = <String, LlmCooldown>{};
    for (final entry in cooldowns.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const LlmRoutingStateException();
      }
      parsedCooldowns[entry.key as String] = LlmCooldown.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return LlmRoutingRuntimeState(
      trackingStartedAt: started.toUtc(),
      events: parsedEvents,
      pendingUsage: parsedPendingUsage,
      cooldowns: parsedCooldowns,
    );
  }
}

class LlmPendingUsage {
  final String id;
  final String accountId;
  final String groupId;
  final DateTime startedAt;

  const LlmPendingUsage({
    required this.id,
    required this.accountId,
    required this.groupId,
    required this.startedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'accountId': accountId,
    'groupId': groupId,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };

  factory LlmPendingUsage.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final accountId = map['accountId'];
    final groupId = map['groupId'];
    final startedValue = map['startedAt'];
    final started = startedValue is String
        ? DateTime.tryParse(startedValue)
        : null;
    if (id is! String ||
        !_routingIdentifierPattern.hasMatch(id) ||
        accountId is! String ||
        !_routingStateIdentityPattern.hasMatch(accountId) ||
        groupId is! String ||
        !_routingStateIdentityPattern.hasMatch(groupId) ||
        started == null) {
      throw const LlmRoutingStateException();
    }
    return LlmPendingUsage(
      id: id,
      accountId: accountId,
      groupId: groupId,
      startedAt: started.toUtc(),
    );
  }
}

class LlmRoutingStateException implements Exception {
  const LlmRoutingStateException();

  @override
  String toString() => 'LLM routing state could not be read or saved.';
}

/// Persists only local measurement numbers, account/group IDs, and cooldowns.
/// The M1 transaction lease prevents concurrent writes from losing events.
class LlmRoutingStateStore {
  static const preferenceKey = 'llm_routing_runtime_v1';
  static const _retention = Duration(days: 62);
  static final _memoryCooldownsByPreferences =
      Expando<Map<String, LlmCooldown>>('llm routing cooldowns');

  final LlmAccountPreferences preferences;
  final DateTime Function() _clock;
  final Map<String, LlmCooldown> _memoryCooldowns;
  var _nextPendingUsageId = 0;

  LlmRoutingStateStore({required this.preferences, DateTime Function()? clock})
    : _memoryCooldowns = _memoryCooldownsByPreferences[preferences] ??=
          <String, LlmCooldown>{},
      _clock = clock ?? DateTime.now;

  Future<LlmRoutingRuntimeState> load() async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    try {
      final state = await _readUnsafe();
      final pruned = _prune(state, _clock().toUtc());
      if (!_equal(state, pruned)) await _writeUnsafe(pruned);
      return pruned;
    } on LlmRoutingStateException {
      rethrow;
    } catch (_) {
      throw const LlmRoutingStateException();
    } finally {
      lease.release();
    }
  }

  Future<void> recordUsage(LlmUsageEvent event) async {
    final validatedEvent = LlmUsageEvent.fromMap(event.toMap());
    await _update((state) {
      final events = [...state.events, validatedEvent];
      return LlmRoutingRuntimeState(
        trackingStartedAt: state.trackingStartedAt,
        events: events,
        pendingUsage: state.pendingUsage,
        cooldowns: state.cooldowns,
      );
    });
  }

  Future<String> beginPendingUsage({
    required String accountId,
    required String groupId,
  }) async {
    if (!_routingStateIdentityPattern.hasMatch(accountId) ||
        !_routingStateIdentityPattern.hasMatch(groupId)) {
      throw const LlmRoutingStateException();
    }
    late String id;
    await _update((state) {
      do {
        id =
            'pending-${_clock().toUtc().microsecondsSinceEpoch}-${_nextPendingUsageId++}';
      } while (state.pendingUsage.any((pending) => pending.id == id));
      return LlmRoutingRuntimeState(
        trackingStartedAt: state.trackingStartedAt,
        events: state.events,
        pendingUsage: [
          ...state.pendingUsage,
          LlmPendingUsage(
            id: id,
            accountId: accountId,
            groupId: groupId,
            startedAt: _clock().toUtc(),
          ),
        ],
        cooldowns: state.cooldowns,
      );
    });
    return id;
  }

  Future<void> markPendingUsageSent(String id, DateTime sentAt) =>
      _update((state) {
        var found = false;
        final pendingUsage = state.pendingUsage
            .map((pending) {
              if (pending.id != id) return pending;
              found = true;
              return LlmPendingUsage(
                id: pending.id,
                accountId: pending.accountId,
                groupId: pending.groupId,
                startedAt: sentAt.toUtc(),
              );
            })
            .toList(growable: false);
        if (!found) throw const LlmRoutingStateException();
        return LlmRoutingRuntimeState(
          trackingStartedAt: state.trackingStartedAt,
          events: state.events,
          pendingUsage: pendingUsage,
          cooldowns: state.cooldowns,
        );
      });

  Future<void> completePendingUsage(String id) => _update((state) {
    final pendingUsage = state.pendingUsage
        .where((pending) => pending.id != id)
        .toList(growable: false);
    if (pendingUsage.length == state.pendingUsage.length) return state;
    return LlmRoutingRuntimeState(
      trackingStartedAt: state.trackingStartedAt,
      events: state.events,
      pendingUsage: pendingUsage,
      cooldowns: state.cooldowns,
    );
  });

  Future<void> recordCooldown(String accountId, LlmCooldown cooldown) async {
    final previous = _memoryCooldowns[accountId];
    if (previous == null || previous.until.isBefore(cooldown.until)) {
      _memoryCooldowns[accountId] = cooldown;
    }
    await _update((state) {
      final old = state.cooldowns[accountId];
      if (old != null && old.until.isAfter(cooldown.until)) return state;
      return LlmRoutingRuntimeState(
        trackingStartedAt: state.trackingStartedAt,
        events: state.events,
        pendingUsage: state.pendingUsage,
        cooldowns: {...state.cooldowns, accountId: cooldown},
      );
    });
  }

  Future<void> clearCooldown(String accountId) async {
    final memoryCooldown = _memoryCooldowns.remove(accountId);
    try {
      await _update((state) {
        if (!state.cooldowns.containsKey(accountId)) return state;
        final cooldowns = Map<String, LlmCooldown>.from(state.cooldowns)
          ..remove(accountId);
        return LlmRoutingRuntimeState(
          trackingStartedAt: state.trackingStartedAt,
          events: state.events,
          pendingUsage: state.pendingUsage,
          cooldowns: cooldowns,
        );
      });
    } catch (_) {
      final current = _memoryCooldowns[accountId];
      if (memoryCooldown != null &&
          (current == null || current.until.isBefore(memoryCooldown.until))) {
        _memoryCooldowns[accountId] = memoryCooldown;
      }
      rethrow;
    }
  }

  Future<void> _update(
    LlmRoutingRuntimeState Function(LlmRoutingRuntimeState state) update,
  ) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    try {
      final now = _clock().toUtc();
      final next = _prune(update(await _readUnsafe()), now);
      await _writeUnsafe(next);
    } on LlmRoutingStateException {
      rethrow;
    } catch (_) {
      throw const LlmRoutingStateException();
    } finally {
      lease.release();
    }
  }

  Future<LlmRoutingRuntimeState> _readUnsafe() async {
    final encoded = await preferences.getString(preferenceKey);
    if (encoded == null || encoded.isEmpty) {
      return LlmRoutingRuntimeState(
        trackingStartedAt: _clock().toUtc(),
        events: const [],
        pendingUsage: const [],
        cooldowns: const {},
      );
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) throw const LlmRoutingStateException();
    return LlmRoutingRuntimeState.fromMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> _writeUnsafe(LlmRoutingRuntimeState state) async {
    final saved = await preferences.setString(
      preferenceKey,
      jsonEncode(state.toMap()),
    );
    if (!saved) throw const LlmRoutingStateException();
  }

  LlmRoutingRuntimeState _prune(LlmRoutingRuntimeState state, DateTime now) {
    final cutoff = now.subtract(_retention);
    final cooldowns = {
      for (final entry in state.cooldowns.entries)
        if (entry.value.until.isAfter(now)) entry.key: entry.value,
    };
    _memoryCooldowns.removeWhere((_, cooldown) => !cooldown.until.isAfter(now));
    for (final entry in _memoryCooldowns.entries) {
      final persisted = cooldowns[entry.key];
      if (persisted == null || persisted.until.isBefore(entry.value.until)) {
        cooldowns[entry.key] = entry.value;
      }
    }
    return LlmRoutingRuntimeState(
      trackingStartedAt: state.trackingStartedAt,
      events: state.events
          .where((event) => !event.occurredAt.isBefore(cutoff))
          .toList(growable: false),
      pendingUsage: state.pendingUsage
          .where((pending) => !pending.startedAt.isBefore(cutoff))
          .toList(growable: false),
      cooldowns: cooldowns,
    );
  }

  bool _equal(LlmRoutingRuntimeState left, LlmRoutingRuntimeState right) =>
      jsonEncode(left.toMap()) == jsonEncode(right.toMap());
}

class LlmRouteCandidate {
  final LlmAccount account;
  final LlmModelGroupMember member;
  final String localModelId;
  final String upstreamModelId;
  final int priorityTier;
  final int memberIndex;

  const LlmRouteCandidate({
    required this.account,
    required this.member,
    required this.localModelId,
    required this.upstreamModelId,
    required this.priorityTier,
    required this.memberIndex,
  });
}

class LlmRouteDecision {
  final String subjectId;
  final String reason;

  const LlmRouteDecision({required this.subjectId, required this.reason});
}

class LlmRoutingExecution<T> {
  final T value;
  final LlmRouteCandidate candidate;
  final List<String> attemptedAccountIds;
  final List<LlmRouteDecision> decisions;

  LlmRoutingExecution({
    required this.value,
    required this.candidate,
    required List<String> attemptedAccountIds,
    required List<LlmRouteDecision> decisions,
  }) : attemptedAccountIds = List.unmodifiable(attemptedAccountIds),
       decisions = List.unmodifiable(decisions);
}

class LlmRoutingUnavailableException implements Exception {
  final List<LlmRouteDecision> decisions;

  LlmRoutingUnavailableException(Iterable<LlmRouteDecision> decisions)
    : decisions = List.unmodifiable(decisions);

  @override
  String toString() => 'No eligible account is available for this model group.';
}

class LlmRouteProgress {
  final DateTime Function() _clock;
  final Future<void> Function(DateTime sentAt) _persistRequestSent;
  final List<LlmUsageMeasurement> _measurements = [];
  DateTime? _requestSentAt;
  Future<void>? _requestSentFuture;
  var _visibleOutput = false;
  var _toolSideEffect = false;

  LlmRouteProgress(this._clock, this._persistRequestSent);

  bool get requestWasSent => _requestSentAt != null;
  bool get visibleOutput => _visibleOutput;
  bool get toolSideEffect => _toolSideEffect;

  Future<void> markRequestSent() {
    if (_requestSentAt != null) return Future<void>.value();
    return _requestSentFuture ??= _persistAndMarkRequestSent();
  }

  Future<void> markOutputVisible() async {
    await markRequestSent();
    _visibleOutput = true;
  }

  Future<void> markToolSideEffect() async {
    await markRequestSent();
    _toolSideEffect = true;
  }

  Future<void> recordUsage({
    required String unit,
    required num value,
    required String source,
  }) async {
    if (!_routingIdentifierPattern.hasMatch(unit) ||
        unit.trim() == 'requests' ||
        !_routingIdentifierPattern.hasMatch(source) ||
        !value.isFinite ||
        value < 0) {
      throw ArgumentError('Usage measurements need a known unit and value.');
    }
    await markRequestSent();
    _measurements.add(
      LlmUsageMeasurement(
        unit: unit.trim(),
        value: value,
        source: source.trim(),
      ),
    );
  }

  Future<void> _persistAndMarkRequestSent() async {
    final sentAt = _clock().toUtc();
    await _persistRequestSent(sentAt);
    _requestSentAt = sentAt;
  }

  LlmUsageEvent? _eventFor(LlmRouteCandidate candidate, String groupId) {
    final occurredAt = _requestSentAt;
    if (occurredAt == null) return null;
    return LlmUsageEvent(
      accountId: candidate.account.id,
      groupId: groupId,
      occurredAt: occurredAt,
      measurements: [
        const LlmUsageMeasurement(unit: 'requests', value: 1, source: 'local'),
        ..._measurements,
      ],
    );
  }
}

class LlmRouteReservation {
  final LlmConcurrencyReservations _owner;
  final int _id;
  var _released = false;

  LlmRouteReservation._(this._owner, this._id);

  void release() {
    if (_released) return;
    _released = true;
    _owner._release(_id);
  }
}

class _ActiveReservation {
  final String accountId;
  final String groupId;
  final Map<String, num> estimatedUsage;
  String? pendingUsageId;

  _ActiveReservation({
    required this.accountId,
    required this.groupId,
    required Map<String, num> estimatedUsage,
  }) : estimatedUsage = Map.unmodifiable(estimatedUsage);
}

/// Synchronous reservations prevent two callers from both passing the
/// account/group cap. The operation queue coordinates admission with runtime
/// usage persistence and reservation release.
class LlmConcurrencyReservations {
  static final shared = LlmConcurrencyReservations();

  final Map<int, _ActiveReservation> _active = {};
  Future<void> _operationQueue = Future<void>.value();
  var _nextId = 0;

  Future<T> runAtomically<T>(Future<T> Function() operation) async {
    final predecessor = _operationQueue;
    final release = Completer<void>();
    _operationQueue = release.future;
    await predecessor;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  int activeForAccount(String accountId) => _active.values
      .where((reservation) => reservation.accountId == accountId)
      .length;

  int activeForGroup(String groupId) => _active.values
      .where((reservation) => reservation.groupId == groupId)
      .length;

  int activeForAccounts(Iterable<String> accountIds) {
    final ids = accountIds.toSet();
    return _active.values
        .where((reservation) => ids.contains(reservation.accountId))
        .length;
  }

  void attachPendingUsageId(LlmRouteReservation reservation, String id) {
    _active[reservation._id]?.pendingUsageId = id;
  }

  bool hasActivePendingUsage(String id) =>
      _active.values.any((reservation) => reservation.pendingUsageId == id);

  num reservedUsageForAccount(String accountId, String unit) => _active.values
      .where((reservation) => reservation.accountId == accountId)
      .fold<num>(
        0,
        (sum, reservation) => sum + (reservation.estimatedUsage[unit] ?? 0),
      );

  num reservedUsageForGroup(String groupId, String unit) => _active.values
      .where((reservation) => reservation.groupId == groupId)
      .fold<num>(
        0,
        (sum, reservation) => sum + (reservation.estimatedUsage[unit] ?? 0),
      );

  num reservedUsageForAccounts(Iterable<String> accountIds, String unit) {
    final ids = accountIds.toSet();
    return _active.values
        .where((reservation) => ids.contains(reservation.accountId))
        .fold<num>(
          0,
          (sum, reservation) => sum + (reservation.estimatedUsage[unit] ?? 0),
        );
  }

  bool hasUnknownUsageForAccount(String accountId, String unit) =>
      _active.values.any(
        (reservation) =>
            reservation.accountId == accountId &&
            (reservation.estimatedUsage[unit] ?? 0) <= 0,
      );

  bool hasUnknownUsageForGroup(String groupId, String unit) =>
      _active.values.any(
        (reservation) =>
            reservation.groupId == groupId &&
            (reservation.estimatedUsage[unit] ?? 0) <= 0,
      );

  bool hasUnknownUsageForAccounts(Iterable<String> accountIds, String unit) {
    final ids = accountIds.toSet();
    return _active.values.any(
      (reservation) =>
          ids.contains(reservation.accountId) &&
          (reservation.estimatedUsage[unit] ?? 0) <= 0,
    );
  }

  LlmRouteReservation? tryReserve({
    required String accountId,
    required String groupId,
    required int? accountLimit,
    required int? groupLimit,
    required Map<String, num> estimatedUsage,
  }) {
    if (accountLimit != null && activeForAccount(accountId) >= accountLimit) {
      return null;
    }
    if (groupLimit != null && activeForGroup(groupId) >= groupLimit) {
      return null;
    }
    final id = ++_nextId;
    _active[id] = _ActiveReservation(
      accountId: accountId,
      groupId: groupId,
      estimatedUsage: estimatedUsage,
    );
    return LlmRouteReservation._(this, id);
  }

  void _release(int id) => _active.remove(id);
}

class LlmRoundRobinCursor {
  final Map<String, int> _positions = {};

  int next(String groupId, int tier, int length) {
    if (length <= 0) return 0;
    final key = '$groupId:$tier';
    final position = _positions[key] ?? 0;
    _positions[key] = position + 1;
    return position % length;
  }
}

class LlmRoutingService {
  final LlmAccountConnectorService accountService;
  final LlmRoutingStateStore stateStore;
  final DateTime Function() _clock;
  final LlmConcurrencyReservations concurrency;
  final LlmRoundRobinCursor roundRobin;

  LlmRoutingService({
    required this.accountService,
    LlmRoutingStateStore? stateStore,
    DateTime Function()? clock,
    LlmConcurrencyReservations? concurrency,
    LlmRoundRobinCursor? roundRobin,
  }) : stateStore =
           stateStore ??
           LlmRoutingStateStore(preferences: accountService.preferences),
       _clock = clock ?? DateTime.now,
       concurrency = concurrency ?? LlmConcurrencyReservations.shared,
       roundRobin = roundRobin ?? LlmRoundRobinCursor();

  Future<LlmRoutingExecution<T>> execute<T>({
    required LlmModelGroup group,
    required String requestedModelId,
    required Future<T> Function(
      LlmRouteCandidate candidate,
      LlmRouteProgress progress,
    )
    request,
    Set<String> requiredCapabilities = const {},
    Map<String, num> estimatedUsage = const {},
  }) async {
    if (!_routingStateIdentityPattern.hasMatch(group.id) ||
        requestedModelId.trim().isEmpty) {
      throw LlmRoutingUnavailableException(const []);
    }
    final estimates = _validatedEstimates(estimatedUsage);
    final accounts = await accountService.listAccounts();
    final accountById = {for (final account in accounts) account.id: account};
    final attempted = <String>{};
    final decisions = <LlmRouteDecision>[];
    String? providerScope;

    while (true) {
      final selection = await concurrency.runAtomically(() async {
        final state = await stateStore.load();
        final selected = _selectNext(
          group: group,
          requestedModelId: requestedModelId,
          requiredCapabilities: requiredCapabilities,
          accounts: accountById,
          state: state,
          attempted: attempted,
          providerScope: providerScope,
          estimates: estimates,
          decisions: decisions,
        );
        if (selected == null) return null;
        try {
          final pendingUsageId = await stateStore.beginPendingUsage(
            accountId: selected.candidate.account.id,
            groupId: group.id,
          );
          concurrency.attachPendingUsageId(
            selected.reservation,
            pendingUsageId,
          );
          return _CandidateSelection(
            selected.candidate,
            selected.reservation,
            pendingUsageId,
          );
        } catch (_) {
          selected.reservation.release();
          rethrow;
        }
      });
      if (selection == null) {
        throw LlmRoutingUnavailableException(decisions);
      }
      final candidate = selection.candidate;
      attempted.add(candidate.account.id);
      if (group.policy.fallbackScope == LlmFallbackScope.account &&
          providerScope == null) {
        providerScope = LlmConnectorRegistry.canonicalId(
          candidate.account.connectorType,
        );
      }

      final progress = LlmRouteProgress(
        _clock,
        (sentAt) =>
            stateStore.markPendingUsageSent(selection.pendingUsageId, sentAt),
      );
      Object? failure;
      StackTrace? failureStack;
      Object? value;
      var succeeded = false;
      try {
        value = await request(candidate, progress);
        succeeded = true;
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }

      final event = progress._eventFor(candidate, group.id);
      final error = failure ?? StateError('The provider request failed.');
      final classification = succeeded
          ? null
          : LlmRequestErrorClassifier.classify(error, now: _clock());
      await concurrency.runAtomically(() async {
        try {
          final cooldownUntil = classification?.cooldownUntil;
          if (cooldownUntil != null) {
            await stateStore.recordCooldown(
              candidate.account.id,
              LlmCooldown(until: cooldownUntil, reason: classification!.kind),
            );
          }
          if (event != null) await stateStore.recordUsage(event);
          await stateStore.completePendingUsage(selection.pendingUsageId);
        } finally {
          selection.reservation.release();
        }
      });
      if (succeeded) {
        return LlmRoutingExecution<T>(
          value: value as T,
          candidate: candidate,
          attemptedAccountIds: attempted.toList(),
          decisions: decisions,
        );
      }

      final requestClassification = classification!;
      decisions.add(
        LlmRouteDecision(
          subjectId: candidate.account.id,
          reason: 'request_${requestClassification.kind.name}',
        ),
      );
      final definitiveRejection = switch (requestClassification.kind) {
        LlmRequestFailureKind.authentication ||
        LlmRequestFailureKind.quotaExhausted ||
        LlmRequestFailureKind.rateLimited => true,
        _ => false,
      };
      final mayHaveBeenProcessed =
          progress.requestWasSent && !definitiveRejection;
      if (!requestClassification.retryable ||
          mayHaveBeenProcessed ||
          progress.visibleOutput ||
          progress.toolSideEffect) {
        Error.throwWithStackTrace(error, failureStack ?? StackTrace.current);
      }
    }
  }

  _CandidateSelection? _selectNext({
    required LlmModelGroup group,
    required String requestedModelId,
    required Set<String> requiredCapabilities,
    required Map<String, LlmAccount> accounts,
    required LlmRoutingRuntimeState state,
    required Set<String> attempted,
    required String? providerScope,
    required Map<String, num> estimates,
    required List<LlmRouteDecision> decisions,
  }) {
    final now = _clock().toUtc();
    final String? groupFailure;
    try {
      groupFailure = _groupPolicyFailure(
        group: group,
        accounts: accounts,
        state: state,
        estimates: estimates,
        now: now,
      );
    } on LlmQuotaWindowException {
      decisions.add(
        LlmRouteDecision(
          subjectId: group.id,
          reason: 'invalid_window_timezone',
        ),
      );
      return null;
    }
    if (groupFailure != null) {
      decisions.add(
        LlmRouteDecision(subjectId: group.id, reason: groupFailure),
      );
      return null;
    }

    final candidates = <LlmRouteCandidate>[];
    for (var index = 0; index < group.members.length; index++) {
      final member = group.members[index];
      final account = accounts[member.accountId];
      if (attempted.contains(member.accountId)) continue;
      if (account == null) {
        decisions.add(
          LlmRouteDecision(
            subjectId: member.accountId,
            reason: 'account_missing',
          ),
        );
        continue;
      }
      if (!_routingStateIdentityPattern.hasMatch(account.id)) {
        decisions.add(
          LlmRouteDecision(subjectId: account.id, reason: 'account_id_invalid'),
        );
        continue;
      }
      if (account.status == LlmAccountStatus.paused ||
          account.status == LlmAccountStatus.needsAttention) {
        decisions.add(
          LlmRouteDecision(
            subjectId: account.id,
            reason: 'account_unavailable',
          ),
        );
        continue;
      }
      final localModelId = member.localModelId ?? group.id;
      if (localModelId != requestedModelId) {
        decisions.add(
          LlmRouteDecision(
            subjectId: account.id,
            reason: 'model_mapping_mismatch',
          ),
        );
        continue;
      }
      final model = _findModel(account, member.upstreamModelId);
      if (model == null) {
        decisions.add(
          LlmRouteDecision(subjectId: account.id, reason: 'model_not_mapped'),
        );
        continue;
      }
      if (requiredCapabilities.any(
        (capability) => model.capabilities[capability] != true,
      )) {
        decisions.add(
          LlmRouteDecision(
            subjectId: account.id,
            reason: 'capability_mismatch',
          ),
        );
        continue;
      }
      final connector = LlmConnectorRegistry.canonicalId(account.connectorType);
      if (providerScope != null && connector != providerScope) {
        decisions.add(
          LlmRouteDecision(subjectId: account.id, reason: 'fallback_scope'),
        );
        continue;
      }
      final cooldown = state.cooldowns[account.id];
      if (cooldown != null && cooldown.until.isAfter(now)) {
        decisions.add(
          LlmRouteDecision(subjectId: account.id, reason: 'cooldown'),
        );
        continue;
      }
      final String? accountFailure;
      try {
        accountFailure = _accountPolicyFailure(
          account: account,
          group: group,
          state: state,
          estimates: estimates,
          now: now,
        );
      } on LlmQuotaWindowException {
        decisions.add(
          LlmRouteDecision(
            subjectId: account.id,
            reason: 'invalid_window_timezone',
          ),
        );
        continue;
      }
      if (accountFailure != null) {
        decisions.add(
          LlmRouteDecision(subjectId: account.id, reason: accountFailure),
        );
        continue;
      }
      candidates.add(
        LlmRouteCandidate(
          account: account,
          member: member,
          localModelId: localModelId,
          upstreamModelId: member.upstreamModelId,
          priorityTier: member.priorityTier,
          memberIndex: index,
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final tier = left.priorityTier.compareTo(right.priorityTier);
      return tier != 0 ? tier : left.memberIndex.compareTo(right.memberIndex);
    });
    final tiers =
        candidates.map((candidate) => candidate.priorityTier).toSet().toList()
          ..sort();
    for (final tier in tiers) {
      final tierCandidates = candidates
          .where((candidate) => candidate.priorityTier == tier)
          .toList(growable: false);
      final decisionStart = decisions.length;
      final ordered = _orderWithinTier(
        group: group,
        candidates: tierCandidates,
        state: state,
        now: now,
        estimates: estimates,
        decisions: decisions,
      );
      final tierAccountIds = tierCandidates
          .map((candidate) => candidate.account.id)
          .toSet();
      if (ordered.isEmpty &&
          decisions
              .skip(decisionStart)
              .any(
                (decision) =>
                    tierAccountIds.contains(decision.subjectId) &&
                    decision.reason == 'balance_unknown_or_incomparable',
              )) {
        return null;
      }
      for (final candidate in ordered) {
        final reservation = concurrency.tryReserve(
          accountId: candidate.account.id,
          groupId: group.id,
          accountLimit: candidate.account.policy.concurrencyLimit,
          groupLimit: group.policy.concurrencyLimit,
          estimatedUsage: estimates,
        );
        if (reservation != null) {
          return _CandidateSelection(candidate, reservation, '');
        }
        decisions.add(
          LlmRouteDecision(
            subjectId: candidate.account.id,
            reason: 'concurrency_limit',
          ),
        );
      }
    }
    return null;
  }

  List<LlmRouteCandidate> _orderWithinTier({
    required LlmModelGroup group,
    required List<LlmRouteCandidate> candidates,
    required LlmRoutingRuntimeState state,
    required DateTime now,
    required Map<String, num> estimates,
    required List<LlmRouteDecision> decisions,
  }) {
    switch (group.policy.strategy) {
      case LlmSelectionStrategy.roundRobin:
        if (candidates.length < 2) return candidates;
        final offset = roundRobin.next(
          group.id,
          candidates.first.priorityTier,
          candidates.length,
        );
        return [...candidates.skip(offset), ...candidates.take(offset)];
      case LlmSelectionStrategy.balanceHigher:
      case LlmSelectionStrategy.balanceLower:
        final ranking = _commonRemainingMetric(candidates, state, now);
        if (ranking == null) {
          for (final candidate in candidates) {
            decisions.add(
              LlmRouteDecision(
                subjectId: candidate.account.id,
                reason: 'balance_unknown_or_incomparable',
              ),
            );
          }
          return const [];
        }
        final lowerFirst =
            group.policy.strategy == LlmSelectionStrategy.balanceLower;
        final availableBalances = {
          for (final entry in ranking.values.entries)
            entry.key:
                entry.value -
                concurrency.reservedUsageForAccount(
                  entry.key.account.id,
                  ranking.unit,
                ) -
                (estimates[ranking.unit] ?? 0),
        };
        final comparable = ranking.values.entries.where(
          (entry) =>
              _balanceEligibleAfterEstimate(entry.key, ranking, estimates, now),
        );
        final ranked = [...comparable]
          ..sort((left, right) {
            final balance = availableBalances[left.key]!.compareTo(
              availableBalances[right.key]!,
            );
            if (balance != 0) return lowerFirst ? balance : -balance;
            return left.key.memberIndex.compareTo(right.key.memberIndex);
          });
        if (ranked.isEmpty) {
          for (final candidate in candidates) {
            decisions.add(
              LlmRouteDecision(
                subjectId: candidate.account.id,
                reason: 'balance_at_or_below_reserve',
              ),
            );
          }
        }
        return ranked.map((entry) => entry.key).toList(growable: false);
      case LlmSelectionStrategy.leastUsed:
        if (candidates.length < 2) return candidates;
        final counts = <LlmRouteCandidate, num>{};
        for (final candidate in candidates) {
          counts[candidate] =
              _requestCount(state, candidate.account.id, group.id, now) +
              concurrency.activeForAccount(candidate.account.id);
        }
        final ranked = [...counts.entries]
          ..sort((left, right) {
            final count = left.value.compareTo(right.value);
            return count != 0
                ? count
                : left.key.memberIndex.compareTo(right.key.memberIndex);
          });
        return ranked.map((entry) => entry.key).toList(growable: false);
    }
  }

  _BalanceRanking? _commonRemainingMetric(
    List<LlmRouteCandidate> candidates,
    LlmRoutingRuntimeState runtime,
    DateTime now,
  ) {
    for (final window in LlmUsageWindow.values) {
      final firstPolicy =
          candidates.first.account.policy.windows[window] ??
          const LlmWindowPolicy();
      if (candidates.any(
        (candidate) => !_matchingWindowPolicy(
          firstPolicy,
          candidate.account.policy.windows[window] ?? const LlmWindowPolicy(),
        ),
      )) {
        continue;
      }
      final values = <LlmRouteCandidate, LlmMetricObservation>{};
      for (final candidate in candidates) {
        final policy =
            candidate.account.policy.windows[window] ?? const LlmWindowPolicy();
        final LlmQuotaWindowBounds bounds;
        try {
          bounds = LlmQuotaWindowService.bounds(window, policy, now);
        } on LlmQuotaWindowException {
          values.clear();
          break;
        }
        final remaining = _accountRemaining(
          candidate.account,
          runtime,
          window,
          bounds,
          now,
        );
        if (remaining == null) {
          values.clear();
          break;
        }
        // Negative balances remain comparable; reserve eligibility below
        // removes only the depleted account instead of invalidating its tier.
        values[candidate] = LlmMetricObservation.reported(
          remaining.value,
          unit: remaining.unit,
          source: remaining.source,
          observedAt: now,
        );
      }
      if (values.length != candidates.length || values.isEmpty) continue;
      final first = values.values.first;
      if (first.source?.trim().isNotEmpty == true &&
          values.values.every(
            (value) => value.unit == first.unit && value.source == first.source,
          )) {
        return _BalanceRanking(
          window: window,
          unit: first.unit!,
          values: {
            for (final entry in values.entries) entry.key: entry.value.value!,
          },
        );
      }
    }
    return null;
  }

  bool _balanceEligibleAfterEstimate(
    LlmRouteCandidate candidate,
    _BalanceRanking ranking,
    Map<String, num> estimates,
    DateTime now,
  ) {
    final balance = ranking.values[candidate];
    if (balance == null) return false;
    final policy =
        candidate.account.policy.windows[ranking.window] ??
        const LlmWindowPolicy();
    final floor = policy.reserveFloor;
    num minimum = 0;
    if (floor != null) {
      if (_thresholdUnit(floor, ranking.unit) != ranking.unit ||
          !floor.value.isFinite ||
          floor.value < 0) {
        return false;
      }
      if (floor.kind == LlmLimitKind.fixed) {
        minimum = floor.value;
      } else {
        if (floor.value > 100) return false;
        final bounds = LlmQuotaWindowService.bounds(
          ranking.window,
          policy,
          now,
        );
        final total = _accountQuotaTotal(
          candidate.account,
          ranking.window,
          bounds,
          now,
          ranking.unit,
        );
        if (total == null) return false;
        final resolved = _resolveThreshold(floor, total);
        if (resolved == null) return false;
        minimum = resolved;
      }
    }
    final reserved = concurrency.reservedUsageForAccount(
      candidate.account.id,
      ranking.unit,
    );
    final afterRequest = balance - reserved - (estimates[ranking.unit] ?? 0);
    final estimate = estimates[ranking.unit];
    final requiresAvailableHeadroom = estimate == null || estimate <= 0;
    return requiresAvailableHeadroom
        ? afterRequest > minimum
        : afterRequest >= minimum;
  }

  String? _groupPolicyFailure({
    required LlmModelGroup group,
    required Map<String, LlmAccount> accounts,
    required LlmRoutingRuntimeState state,
    required Map<String, num> estimates,
    required DateTime now,
  }) {
    return _policyFailure(
      policy: group.policy,
      group: group,
      account: null,
      accounts: accounts,
      state: state,
      estimates: estimates,
      now: now,
    );
  }

  String? _accountPolicyFailure({
    required LlmAccount account,
    required LlmModelGroup group,
    required LlmRoutingRuntimeState state,
    required Map<String, num> estimates,
    required DateTime now,
  }) => _policyFailure(
    policy: account.policy,
    group: group,
    account: account,
    accounts: {account.id: account},
    state: state,
    estimates: estimates,
    now: now,
  );

  String? _policyFailure({
    required LlmRoutingPolicy policy,
    required LlmModelGroup group,
    required LlmAccount? account,
    required Map<String, LlmAccount> accounts,
    required LlmRoutingRuntimeState state,
    required Map<String, num> estimates,
    required DateTime now,
  }) {
    for (final window in LlmUsageWindow.values) {
      final windowPolicy = policy.windows[window] ?? const LlmWindowPolicy();
      if (windowPolicy.reserveFloor == null &&
          windowPolicy.usageCeiling == null) {
        continue;
      }
      final bounds = LlmQuotaWindowService.bounds(window, windowPolicy, now);
      if (_hasUnresolvedPendingUsage(
        state,
        (pending) => account == null
            ? pending.groupId == group.id
            : pending.accountId == account.id,
        bounds: bounds,
      )) {
        return 'usage_unknown';
      }
      if (windowPolicy.reserveFloor != null) {
        final threshold = windowPolicy.reserveFloor!;
        final groupAccountIds = account == null
            ? group.members.map((member) => member.accountId).toSet()
            : const <String>{};
        final remaining = account == null
            ? _groupRemaining(group, accounts, state, window, bounds, now)
            : _accountRemaining(account, state, window, bounds, now);
        if (remaining == null) return 'reserve_balance_unknown';
        final unit = _thresholdUnit(threshold, remaining.unit);
        if (unit == null || unit != remaining.unit) {
          return 'reserve_unit_unknown_or_incomparable';
        }
        final total = threshold.kind == LlmLimitKind.percentage
            ? (account == null
                  ? _groupQuotaTotal(group, accounts, window, bounds, now, unit)
                  : _accountQuotaTotal(account, window, bounds, now, unit))
            : null;
        if (threshold.kind == LlmLimitKind.percentage &&
            (total == null ||
                total.unit != remaining.unit ||
                total.source != remaining.source ||
                !_hasSameObservationTime(total, remaining))) {
          return 'reserve_total_unknown_or_incomparable';
        }
        final limit = _resolveThreshold(threshold, total);
        if (limit == null) return 'reserve_total_unknown';
        final reserved = account == null
            ? concurrency.reservedUsageForAccounts(groupAccountIds, unit)
            : concurrency.reservedUsageForAccount(account.id, unit);
        final estimate = estimates[unit];
        final hasUsableEstimate = estimate != null && estimate > 0;
        if (!hasUsableEstimate) {
          return 'reserve_usage_estimate_unknown';
        }
        final hasUnknownActiveUsage = account == null
            ? concurrency.hasUnknownUsageForAccounts(groupAccountIds, unit)
            : concurrency.hasUnknownUsageForAccount(account.id, unit);
        if (hasUnknownActiveUsage) {
          return 'reserve_in_flight_usage_unknown';
        }
        final pending = reserved + estimate;
        final afterPending = remaining.value - pending;
        if (afterPending < limit) {
          return 'reserve_floor_reached';
        }
      }
      if (windowPolicy.usageCeiling != null) {
        final threshold = windowPolicy.usageCeiling!;
        final total = threshold.kind == LlmLimitKind.percentage
            ? (account == null
                  ? _groupKnownQuotaTotal(group, accounts, window, bounds, now)
                  : _accountKnownQuotaTotal(account, window, bounds, now))
            : null;
        final unit = threshold.kind == LlmLimitKind.percentage
            ? total?.unit
            : _thresholdUnit(threshold, 'requests');
        if (unit == null) return 'usage_ceiling_total_unknown';
        final used = account == null
            ? _groupUsed(group, state, bounds, unit)
            : _accountUsed(account, state, window, bounds, now, unit);
        if (used == null) return 'usage_unknown';
        final limit = _resolveThreshold(threshold, total);
        if (limit == null) return 'usage_ceiling_total_unknown';
        if (used.unit != unit) return 'usage_unit_mismatch';
        if (threshold.kind == LlmLimitKind.percentage &&
            (used.source != total?.source ||
                total == null ||
                !_quotaObservationCoversUsage(total, used))) {
          return 'usage_source_mismatch';
        }
        final reserved = account == null
            ? concurrency.reservedUsageForGroup(group.id, unit)
            : concurrency.reservedUsageForAccount(account.id, unit);
        final hasUnknownActiveUsage = account == null
            ? concurrency.hasUnknownUsageForGroup(group.id, unit)
            : concurrency.hasUnknownUsageForAccount(account.id, unit);
        if (hasUnknownActiveUsage) return 'usage_in_flight_unknown';
        final nextRequest = estimates[unit];
        if (nextRequest == null) return 'usage_estimate_unknown';
        if (used.value + reserved + nextRequest > limit) {
          return 'usage_ceiling_reached';
        }
      }
    }
    return null;
  }

  _UsageAmount? _accountRemaining(
    LlmAccount account,
    LlmRoutingRuntimeState runtime,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
  ) {
    if (_hasUnresolvedPendingUsage(
      runtime,
      (pending) => pending.accountId == account.id,
      bounds: bounds,
    )) {
      return null;
    }
    final windowState = account.usageByWindow[window];
    if (windowState == null) return null;
    final remaining = _freshMetric(
      windowState.remaining,
      windowState,
      bounds,
      now,
    );
    final quota = _freshMetric(windowState.quota, windowState, bounds, now);
    final used = _freshMetric(windowState.used, windowState, bounds, now);
    if (remaining != null) {
      var remainingValue = remaining.value!;
      var observedAt = remaining.observedAt!;
      final comparableProviderPair =
          quota != null &&
          used != null &&
          quota.unit == used.unit &&
          quota.source == used.source &&
          quota.observedAt!.toUtc().isAtSameMomentAs(
            used.observedAt!.toUtc(),
          ) &&
          quota.unit == remaining.unit &&
          quota.source == remaining.source;
      if (!comparableProviderPair &&
          [quota, used].any(
            (metric) =>
                metric != null &&
                metric.unit == remaining.unit &&
                metric.source == remaining.source &&
                metric.observedAt!.toUtc().isAfter(observedAt.toUtc()),
          )) {
        return null;
      }
      if (comparableProviderPair) {
        final derivedRemaining = quota.value! - used.value!;
        final derivedObservedAt = used.observedAt!.toUtc();
        final remainingObservedAt = remaining.observedAt!.toUtc();
        if (derivedObservedAt.isAfter(remainingObservedAt)) {
          remainingValue = derivedRemaining;
          observedAt = used.observedAt!;
        } else if (derivedObservedAt.isAtSameMomentAs(remainingObservedAt) &&
            derivedRemaining < remainingValue) {
          // Conflicting values from one provider snapshot use the lower
          // remaining amount so the reserve check cannot over-allocate.
          remainingValue = derivedRemaining;
        }
      }
      if (runtime.trackingStartedAt.toUtc().isAfter(observedAt.toUtc())) {
        // The local ledger cannot account for consumption between this
        // provider snapshot and the point at which local tracking began.
        return null;
      }
      final consumed = _eventsAfterObservation(
        runtime.events,
        accountId: account.id,
        unit: remaining.unit!,
        bounds: bounds,
        after: observedAt,
      );
      if (consumed == null) return null;
      return _UsageAmount(
        remainingValue - consumed,
        remaining.unit!,
        remaining.source,
        observedAt,
      );
    }
    if (quota == null ||
        used == null ||
        quota.unit != used.unit ||
        quota.source != used.source ||
        !quota.observedAt!.toUtc().isAtSameMomentAs(used.observedAt!.toUtc())) {
      return null;
    }
    if (runtime.trackingStartedAt.toUtc().isAfter(used.observedAt!.toUtc())) {
      return null;
    }
    final consumed = _eventsAfterObservation(
      runtime.events,
      accountId: account.id,
      unit: quota.unit!,
      bounds: bounds,
      after: used.observedAt,
    );
    if (consumed == null) return null;
    return _UsageAmount(
      quota.value! - used.value! - consumed,
      quota.unit!,
      quota.source,
      used.observedAt,
    );
  }

  _UsageAmount? _groupRemaining(
    LlmModelGroup group,
    Map<String, LlmAccount> accounts,
    LlmRoutingRuntimeState runtime,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
  ) {
    if (_hasUnresolvedPendingUsage(
      runtime,
      (pending) => pending.groupId == group.id,
      bounds: bounds,
    )) {
      return null;
    }
    final members = _configuredGroupAccounts(group, accounts);
    if (members == null) return null;
    final values = <_UsageAmount>[];
    for (final account in members) {
      if (!_matchingWindowPolicy(
        account.policy.windows[window] ?? const LlmWindowPolicy(),
        group.policy.windows[window] ?? const LlmWindowPolicy(),
      )) {
        return null;
      }
      final amount = _accountRemaining(account, runtime, window, bounds, now);
      if (amount == null) return null;
      values.add(amount);
    }
    final first = values.first;
    if (first.source?.trim().isNotEmpty != true ||
        first.observedAt == null ||
        values.any(
          (value) =>
              value.unit != first.unit ||
              value.source != first.source ||
              value.observedAt == null ||
              !value.observedAt!.toUtc().isAtSameMomentAs(
                first.observedAt!.toUtc(),
              ),
        )) {
      return null;
    }
    final combined = values.fold<num>(0, (sum, value) => sum + value.value);
    if (!combined.isFinite) return null;
    return _UsageAmount(combined, first.unit, first.source, first.observedAt);
  }

  _UsageAmount? _accountQuotaTotal(
    LlmAccount account,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
    String unit,
  ) {
    final total = _accountKnownQuotaTotal(account, window, bounds, now);
    return total?.unit == unit ? total : null;
  }

  _UsageAmount? _accountKnownQuotaTotal(
    LlmAccount account,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
  ) {
    final state = account.usageByWindow[window];
    if (state == null) return null;
    final quota = _freshMetric(state.quota, state, bounds, now);
    if (quota != null) return _amount(quota);
    final remaining = _freshMetric(state.remaining, state, bounds, now);
    final used = _freshMetric(state.used, state, bounds, now);
    if (remaining == null ||
        used == null ||
        remaining.unit != used.unit ||
        remaining.source != used.source ||
        !remaining.observedAt!.toUtc().isAtSameMomentAs(
          used.observedAt!.toUtc(),
        )) {
      return null;
    }
    return _UsageAmount(
      remaining.value! + used.value!,
      remaining.unit!,
      remaining.source,
      remaining.observedAt,
    );
  }

  _UsageAmount? _groupQuotaTotal(
    LlmModelGroup group,
    Map<String, LlmAccount> accounts,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
    String unit,
  ) {
    final total = _groupKnownQuotaTotal(group, accounts, window, bounds, now);
    return total?.unit == unit ? total : null;
  }

  _UsageAmount? _groupKnownQuotaTotal(
    LlmModelGroup group,
    Map<String, LlmAccount> accounts,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
  ) {
    final members = _configuredGroupAccounts(group, accounts);
    if (members == null) return null;
    final values = <_UsageAmount>[];
    for (final account in members) {
      if (!_matchingWindowPolicy(
        account.policy.windows[window] ?? const LlmWindowPolicy(),
        group.policy.windows[window] ?? const LlmWindowPolicy(),
      )) {
        return null;
      }
      final amount = _accountKnownQuotaTotal(account, window, bounds, now);
      if (amount == null) return null;
      values.add(amount);
    }
    final first = values.first;
    if (first.source?.trim().isNotEmpty != true ||
        first.observedAt == null ||
        values.any(
          (value) =>
              value.unit != first.unit ||
              value.source != first.source ||
              value.observedAt == null ||
              !value.observedAt!.toUtc().isAtSameMomentAs(
                first.observedAt!.toUtc(),
              ),
        )) {
      return null;
    }
    final combined = values.fold<num>(0, (sum, value) => sum + value.value);
    if (!combined.isFinite) return null;
    return _UsageAmount(combined, first.unit, first.source, first.observedAt);
  }

  _UsageAmount? _accountUsed(
    LlmAccount account,
    LlmRoutingRuntimeState runtime,
    LlmUsageWindow window,
    LlmQuotaWindowBounds bounds,
    DateTime now,
    String unit, {
    String? groupId,
  }) {
    if (_hasUnresolvedPendingUsage(
      runtime,
      (pending) =>
          pending.accountId == account.id || pending.groupId == groupId,
      bounds: bounds,
    )) {
      return null;
    }
    final state = account.usageByWindow[window];
    // Provider observations are account-wide and cannot be apportioned to a
    // single model group's usage ceiling.
    final upstreamUsed = state == null || groupId != null
        ? null
        : _freshMetric(state.used, state, bounds, now);
    LlmMetricObservation? baseline = upstreamUsed?.unit == unit
        ? upstreamUsed
        : null;
    if (baseline == null && state != null && groupId == null) {
      final quota = _freshMetric(state.quota, state, bounds, now);
      final remaining = _freshMetric(state.remaining, state, bounds, now);
      if (quota?.unit == unit &&
          remaining?.unit == unit &&
          quota?.source == remaining?.source &&
          quota!.observedAt!.toUtc().isAtSameMomentAs(
            remaining!.observedAt!.toUtc(),
          ) &&
          quota.value! >= remaining.value!) {
        baseline = LlmMetricObservation.reported(
          quota.value! - remaining.value!,
          unit: unit,
          source: quota.source,
          observedAt: remaining.observedAt,
        );
      }
    }
    if (baseline == null &&
        runtime.trackingStartedAt.isAfter(bounds.startsAt.toUtc())) {
      // An empty local ledger only means zero after local tracking covers the
      // full active window; otherwise the unseen part of the window is unknown.
      return null;
    }
    if (baseline != null &&
        runtime.trackingStartedAt.toUtc().isAfter(
          baseline.observedAt!.toUtc(),
        )) {
      // Provider usage covers the interval through its snapshot. The local
      // ledger must cover the rest of the interval before adding local usage.
      return null;
    }
    final local = _localUsage(
      runtime.events,
      accountId: account.id,
      groupId: groupId,
      unit: unit,
      bounds: bounds,
      after: baseline?.observedAt,
    );
    if (local == null) return null;
    if (baseline == null) return local;
    return _UsageAmount(
      baseline.value! + local.value,
      unit,
      baseline.source ?? local.source,
      _laterObservationTime(baseline.observedAt, local.observedAt),
    );
  }

  _UsageAmount? _groupUsed(
    LlmModelGroup group,
    LlmRoutingRuntimeState runtime,
    LlmQuotaWindowBounds bounds,
    String unit,
  ) {
    if (_hasUnresolvedPendingUsage(
      runtime,
      (pending) => pending.groupId == group.id,
      bounds: bounds,
    )) {
      return null;
    }
    if (runtime.trackingStartedAt.isAfter(bounds.startsAt.toUtc())) {
      return null;
    }
    return _localUsage(
      runtime.events,
      accountId: null,
      groupId: group.id,
      unit: unit,
      bounds: bounds,
    );
  }

  _UsageAmount? _localUsage(
    List<LlmUsageEvent> events, {
    required String? accountId,
    required String? groupId,
    required String unit,
    required LlmQuotaWindowBounds bounds,
    DateTime? after,
  }) {
    final samples = <LlmUsageMeasurement>[];
    DateTime? observedAt;
    for (final event in events) {
      if (accountId != null && event.accountId != accountId) continue;
      if (groupId != null && event.groupId != groupId) continue;
      if (!bounds.contains(event.occurredAt)) continue;
      if (after != null && event.occurredAt.isBefore(after)) continue;
      final matching = event.measurements
          .where((item) => item.unit == unit)
          .toList();
      final recordsSentRequest = event.measurements.any(
        (item) => item.unit == 'requests' && item.value > 0,
      );
      if (unit != 'requests' && recordsSentRequest && matching.isEmpty) {
        // A request count proves local tracking saw a request, but it does
        // not prove how much of another usage unit that request consumed.
        return null;
      }
      if (matching.isNotEmpty &&
          (observedAt == null || event.occurredAt.isAfter(observedAt))) {
        observedAt = event.occurredAt;
      }
      samples.addAll(matching);
    }
    if (samples.isEmpty) return _UsageAmount(0, unit, 'local');
    final source = samples.first.source;
    if (samples.any((sample) => sample.source != source)) return null;
    return _UsageAmount(
      samples.fold<num>(0, (sum, sample) => sum + sample.value),
      unit,
      source,
      observedAt,
    );
  }

  num? _eventsAfterObservation(
    List<LlmUsageEvent> events, {
    required String accountId,
    required String unit,
    required LlmQuotaWindowBounds bounds,
    required DateTime? after,
  }) {
    final samples = <LlmUsageMeasurement>[];
    for (final event in events) {
      if (event.accountId != accountId || !bounds.contains(event.occurredAt)) {
        continue;
      }
      if (after != null && event.occurredAt.isBefore(after)) continue;
      final matching = event.measurements
          .where((item) => item.unit == unit)
          .toList();
      final recordsSentRequest = event.measurements.any(
        (item) => item.unit == 'requests' && item.value > 0,
      );
      if (recordsSentRequest && matching.isEmpty) {
        // Keep provider remaining balances unknown once a locally tracked
        // request lacks this unit's measurement.
        return null;
      }
      samples.addAll(matching);
    }
    if (samples.isEmpty) return 0;
    if (samples.any((sample) => sample.source != samples.first.source)) {
      return null;
    }
    return samples.fold<num>(0, (sum, sample) => sum + sample.value);
  }

  bool _hasUnresolvedPendingUsage(
    LlmRoutingRuntimeState runtime,
    bool Function(LlmPendingUsage pending) matches, {
    required LlmQuotaWindowBounds bounds,
  }) => runtime.pendingUsage.any(
    (pending) =>
        matches(pending) &&
        bounds.contains(pending.startedAt) &&
        !concurrency.hasActivePendingUsage(pending.id),
  );

  LlmMetricObservation? _freshMetric(
    LlmMetricObservation metric,
    LlmUsageWindowState state,
    LlmQuotaWindowBounds bounds,
    DateTime now,
  ) {
    final value = metric.value;
    final unit = metric.unit?.trim();
    if (!metric.isKnown ||
        value == null ||
        !value.isFinite ||
        value < 0 ||
        unit == null ||
        unit.isEmpty ||
        metric.source?.trim().isNotEmpty != true ||
        metric.observedAt == null ||
        metric.observedAt!.toUtc().isBefore(bounds.startsAt.toUtc()) ||
        metric.observedAt!.toUtc().isAfter(now.toUtc()) ||
        (metric.resetAt != null && !metric.resetAt!.toUtc().isAfter(now)) ||
        (state.resetAt != null && !state.resetAt!.toUtc().isAfter(now))) {
      return null;
    }
    return LlmMetricObservation.reported(
      value,
      unit: unit,
      source: metric.source,
      observedAt: metric.observedAt,
      resetAt: metric.resetAt ?? state.resetAt,
    );
  }

  num? _resolveThreshold(LlmLimitThreshold threshold, _UsageAmount? total) {
    final value = threshold.value;
    if (!value.isFinite || value < 0) return null;
    if (threshold.kind == LlmLimitKind.fixed) return value;
    if (value > 100 ||
        total == null ||
        !total.value.isFinite ||
        total.value < 0) {
      return null;
    }
    final resolved = total.value * (value / 100);
    return resolved.isFinite ? resolved : null;
  }

  bool _hasSameObservationTime(_UsageAmount left, _UsageAmount right) {
    final leftAt = left.observedAt;
    final rightAt = right.observedAt;
    return leftAt != null &&
        rightAt != null &&
        leftAt.toUtc().isAtSameMomentAs(rightAt.toUtc());
  }

  bool _quotaObservationCoversUsage(_UsageAmount quota, _UsageAmount used) {
    final quotaAt = quota.observedAt;
    final usedAt = used.observedAt;
    return quotaAt != null &&
        usedAt != null &&
        !quotaAt.toUtc().isBefore(usedAt.toUtc());
  }

  DateTime? _laterObservationTime(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return right.toUtc().isAfter(left.toUtc()) ? right : left;
  }

  String? _thresholdUnit(LlmLimitThreshold threshold, String? measuredUnit) {
    if (threshold.kind == LlmLimitKind.percentage) return measuredUnit;
    final configured = threshold.unit?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    return measuredUnit;
  }

  _UsageAmount _amount(LlmMetricObservation metric) => _UsageAmount(
    metric.value!,
    metric.unit!,
    metric.source,
    metric.observedAt,
  );

  num _requestCount(
    LlmRoutingRuntimeState state,
    String accountId,
    String groupId,
    DateTime now,
  ) {
    final bounds = LlmQuotaWindowService.bounds(
      LlmUsageWindow.fiveHour,
      const LlmWindowPolicy(),
      now,
    );
    final amount = _localUsage(
      state.events,
      accountId: accountId,
      groupId: groupId,
      unit: 'requests',
      bounds: bounds,
    );
    return amount?.value ?? 0;
  }

  Map<String, num> _validatedEstimates(Map<String, num> raw) {
    final estimates = <String, num>{};
    for (final entry in raw.entries) {
      final unit = entry.key.trim();
      final value = entry.value;
      if (unit.isEmpty || !value.isFinite || value < 0) {
        throw LlmRoutingUnavailableException(const []);
      }
      if (estimates.containsKey(unit)) {
        throw LlmRoutingUnavailableException(const []);
      }
      estimates[unit] = value;
    }
    final requestEstimate = estimates['requests'] ?? 0;
    estimates['requests'] = requestEstimate < 1 ? 1 : requestEstimate;
    return Map.unmodifiable(estimates);
  }

  LlmUpstreamModel? _findModel(LlmAccount account, String upstreamModelId) {
    for (final model in account.models) {
      if (model.upstreamModelId == upstreamModelId) return model;
    }
    return null;
  }

  bool _matchingWindowPolicy(LlmWindowPolicy account, LlmWindowPolicy group) =>
      account.mode == group.mode &&
      (account.timeZone?.trim() ?? '') == (group.timeZone?.trim() ?? '');

  List<LlmAccount>? _configuredGroupAccounts(
    LlmModelGroup group,
    Map<String, LlmAccount> accounts,
  ) {
    if (group.members.isEmpty) return null;
    final resolved = <LlmAccount>[];
    for (final member in group.members) {
      final account = accounts[member.accountId];
      if (account == null) return null;
      resolved.add(account);
    }
    return resolved.toSet().toList(growable: false);
  }
}

class _CandidateSelection {
  final LlmRouteCandidate candidate;
  final LlmRouteReservation reservation;
  final String pendingUsageId;

  const _CandidateSelection(
    this.candidate,
    this.reservation,
    this.pendingUsageId,
  );
}

class _BalanceRanking {
  final LlmUsageWindow window;
  final String unit;
  final Map<LlmRouteCandidate, num> values;

  const _BalanceRanking({
    required this.window,
    required this.unit,
    required this.values,
  });
}

class _UsageAmount {
  final num value;
  final String unit;
  final String? source;
  final DateTime? observedAt;

  const _UsageAmount(this.value, this.unit, this.source, [this.observedAt]);
}
