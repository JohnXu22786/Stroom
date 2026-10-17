/// Persisted, connector-neutral account and model-group data.
///
/// These types describe configuration and observations only. They do not
/// select accounts or make connector requests.
enum LlmAccountStatus { unknown, ready, paused, needsAttention }

enum LlmFallbackScope { modelGroup, account }

enum LlmSelectionStrategy { leastUsed, roundRobin, balanceHigher, balanceLower }

enum LlmUsageWindow { fiveHour, day, week, month }

enum LlmWindowMode { rolling, calendar }

enum LlmLimitKind { fixed, percentage }

class LlmLimitThreshold {
  final LlmLimitKind kind;
  final num value;
  final String? unit;

  const LlmLimitThreshold.fixed(this.value, {this.unit})
      : kind = LlmLimitKind.fixed;

  const LlmLimitThreshold.percentage(this.value)
      : kind = LlmLimitKind.percentage,
        unit = 'percent';

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'value': value,
        if (unit != null) 'unit': unit,
      };

  factory LlmLimitThreshold.fromMap(Map<String, dynamic> map) {
    final kind = _enumByName(
      LlmLimitKind.values,
      map['kind'],
      fallback: LlmLimitKind.fixed,
    );
    final value = map['value'];
    return LlmLimitThreshold._(
      kind,
      value is num ? value : 0,
      map['unit'] is String ? map['unit'] as String : null,
    );
  }

  const LlmLimitThreshold._(this.kind, this.value, this.unit);
}

class LlmWindowPolicy {
  final LlmWindowMode mode;
  final String? timeZone;
  final LlmLimitThreshold? reserveFloor;
  final LlmLimitThreshold? usageCeiling;

  const LlmWindowPolicy({
    this.mode = LlmWindowMode.rolling,
    this.timeZone,
    this.reserveFloor,
    this.usageCeiling,
  });

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        if (timeZone != null) 'timeZone': timeZone,
        if (reserveFloor != null) 'reserveFloor': reserveFloor!.toMap(),
        if (usageCeiling != null) 'usageCeiling': usageCeiling!.toMap(),
      };

  factory LlmWindowPolicy.fromMap(Map<String, dynamic> map) => LlmWindowPolicy(
        mode: _enumByName(
          LlmWindowMode.values,
          map['mode'],
          fallback: LlmWindowMode.rolling,
        ),
        timeZone: map['timeZone'] is String ? map['timeZone'] as String : null,
        reserveFloor: map['reserveFloor'] is Map
            ? LlmLimitThreshold.fromMap(
                Map<String, dynamic>.from(map['reserveFloor'] as Map),
              )
            : null,
        usageCeiling: map['usageCeiling'] is Map
            ? LlmLimitThreshold.fromMap(
                Map<String, dynamic>.from(map['usageCeiling'] as Map),
              )
            : null,
      );
}

class LlmRoutingPolicy {
  final LlmFallbackScope fallbackScope;
  final LlmSelectionStrategy strategy;
  final Map<LlmUsageWindow, LlmWindowPolicy> windows;
  final int? concurrencyLimit;

  LlmRoutingPolicy({
    this.fallbackScope = LlmFallbackScope.modelGroup,
    this.strategy = LlmSelectionStrategy.leastUsed,
    Map<LlmUsageWindow, LlmWindowPolicy>? windows,
    this.concurrencyLimit,
  }) : windows = _completeWindows(windows);

  Map<String, dynamic> toMap() => {
        'fallbackScope': fallbackScope.name,
        'strategy': strategy.name,
        'windows': {
          for (final entry in windows.entries)
            entry.key.name: entry.value.toMap(),
        },
        if (concurrencyLimit != null) 'concurrencyLimit': concurrencyLimit,
      };

  factory LlmRoutingPolicy.fromMap(Map<String, dynamic> map) {
    final rawWindows = map['windows'];
    final windows = <LlmUsageWindow, LlmWindowPolicy>{};
    if (rawWindows is Map) {
      for (final entry in rawWindows.entries) {
        final window = _enumByNameOrNull(LlmUsageWindow.values, entry.key);
        if (window != null && entry.value is Map) {
          windows[window] = LlmWindowPolicy.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return LlmRoutingPolicy(
      fallbackScope: _enumByName(
        LlmFallbackScope.values,
        map['fallbackScope'],
        fallback: LlmFallbackScope.modelGroup,
      ),
      strategy: _enumByName(
        LlmSelectionStrategy.values,
        map['strategy'],
        fallback: LlmSelectionStrategy.leastUsed,
      ),
      windows: windows,
      concurrencyLimit: (map['concurrencyLimit'] as num?)?.toInt(),
    );
  }
}

/// A metric can be explicitly unknown or a reported value with its provenance.
class LlmMetricObservation {
  final bool isKnown;
  final num? value;
  final String? unit;
  final String? source;
  final DateTime? observedAt;
  final DateTime? resetAt;

  const LlmMetricObservation.unknown()
      : isKnown = false,
        value = null,
        unit = null,
        source = null,
        observedAt = null,
        resetAt = null;

  const LlmMetricObservation.reported(
    this.value, {
    this.unit,
    this.source,
    this.observedAt,
    this.resetAt,
  }) : isKnown = true;

  Map<String, dynamic> toMap() => {
        'state': isKnown ? 'reported' : 'unknown',
        if (isKnown) 'value': value,
        if (unit != null) 'unit': unit,
        if (source != null) 'source': source,
        if (observedAt != null) 'observedAt': observedAt!.toIso8601String(),
        if (resetAt != null) 'resetAt': resetAt!.toIso8601String(),
      };

  factory LlmMetricObservation.fromMap(Map<String, dynamic> map) {
    if (map['state'] != 'reported' && map['isKnown'] != true) {
      return const LlmMetricObservation.unknown();
    }
    return LlmMetricObservation.reported(
      map['value'] is num ? map['value'] as num : null,
      unit: map['unit'] is String ? map['unit'] as String : null,
      source: map['source'] is String ? map['source'] as String : null,
      observedAt: _dateTime(map['observedAt']),
      resetAt: _dateTime(map['resetAt']),
    );
  }
}

class LlmUsageWindowState {
  final LlmMetricObservation quota;
  final LlmMetricObservation used;
  final LlmMetricObservation remaining;
  final DateTime? resetAt;
  final String? source;

  const LlmUsageWindowState({
    this.quota = const LlmMetricObservation.unknown(),
    this.used = const LlmMetricObservation.unknown(),
    this.remaining = const LlmMetricObservation.unknown(),
    this.resetAt,
    this.source,
  });

  Map<String, dynamic> toMap() => {
        'quota': quota.toMap(),
        'used': used.toMap(),
        'remaining': remaining.toMap(),
        if (resetAt != null) 'resetAt': resetAt!.toIso8601String(),
        if (source != null) 'source': source,
      };

  factory LlmUsageWindowState.fromMap(Map<String, dynamic> map) =>
      LlmUsageWindowState(
        quota: _observation(map['quota']),
        used: _observation(map['used']),
        remaining: _observation(map['remaining']),
        resetAt: _dateTime(map['resetAt']),
        source: map['source'] is String ? map['source'] as String : null,
      );
}

class LlmUpstreamModel {
  final String id;
  final String upstreamModelId;
  final String displayName;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> config;

  const LlmUpstreamModel({
    required this.id,
    required this.upstreamModelId,
    required this.displayName,
    this.capabilities = const {},
    this.config = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'upstreamModelId': upstreamModelId,
        'displayName': displayName,
        'capabilities': capabilities,
        'config': config,
      };

  factory LlmUpstreamModel.fromMap(Map<String, dynamic> map) =>
      LlmUpstreamModel(
        id: map['id'] as String? ?? '',
        upstreamModelId: map['upstreamModelId'] as String? ?? '',
        displayName: map['displayName'] as String? ?? '',
        capabilities: Map<String, dynamic>.from(
          map['capabilities'] as Map? ?? {},
        ),
        config: Map<String, dynamic>.from(map['config'] as Map? ?? {}),
      );
}

class LlmAccount {
  final String id;
  final String connectorType;
  final String authType;
  final String displayName;
  final LlmAccountStatus status;
  final String? credentialRef;
  final Map<String, dynamic> endpointConfig;
  final List<LlmUpstreamModel> models;
  final LlmRoutingPolicy policy;
  final Map<LlmUsageWindow, LlmUsageWindowState> usageByWindow;

  LlmAccount({
    required this.id,
    required this.connectorType,
    required this.authType,
    required this.displayName,
    this.status = LlmAccountStatus.unknown,
    this.credentialRef,
    this.endpointConfig = const {},
    this.models = const [],
    LlmRoutingPolicy? policy,
    Map<LlmUsageWindow, LlmUsageWindowState>? usageByWindow,
  })  : policy = policy ?? LlmRoutingPolicy(),
        usageByWindow = Map.unmodifiable(usageByWindow ?? const {});

  Map<String, dynamic> toMap() => {
        'id': id,
        'connectorType': connectorType,
        'authType': authType,
        'displayName': displayName,
        'status': status.name,
        if (credentialRef != null) 'credentialRef': credentialRef,
        'endpointConfig': endpointConfig,
        'models': models.map((model) => model.toMap()).toList(),
        'policy': policy.toMap(),
        'usageByWindow': {
          for (final entry in usageByWindow.entries)
            entry.key.name: entry.value.toMap(),
        },
      };

  factory LlmAccount.fromMap(Map<String, dynamic> map) {
    final rawModels = map['models'];
    final models = rawModels is List
        ? rawModels
            .whereType<Map>()
            .map(
              (item) =>
                  LlmUpstreamModel.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList()
        : <LlmUpstreamModel>[];
    final rawUsage = map['usageByWindow'];
    final usage = <LlmUsageWindow, LlmUsageWindowState>{};
    if (rawUsage is Map) {
      for (final entry in rawUsage.entries) {
        final window = _enumByNameOrNull(LlmUsageWindow.values, entry.key);
        if (window != null && entry.value is Map) {
          usage[window] = LlmUsageWindowState.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final rawPolicy = map['policy'];
    return LlmAccount(
      id: map['id'] as String? ?? '',
      connectorType: map['connectorType'] as String? ?? 'openai',
      authType: map['authType'] as String? ?? 'api_key',
      displayName: map['displayName'] as String? ?? '',
      status: _enumByName(
        LlmAccountStatus.values,
        map['status'],
        fallback: LlmAccountStatus.unknown,
      ),
      credentialRef: map['credentialRef'] is String
          ? map['credentialRef'] as String
          : null,
      endpointConfig: Map<String, dynamic>.from(
        map['endpointConfig'] as Map? ?? {},
      ),
      models: models,
      policy: rawPolicy is Map
          ? LlmRoutingPolicy.fromMap(Map<String, dynamic>.from(rawPolicy))
          : LlmRoutingPolicy(),
      usageByWindow: usage,
    );
  }
}

class LlmModelGroupMember {
  final String accountId;
  final String upstreamModelId;
  final int priorityTier;
  final String? localModelId;

  const LlmModelGroupMember({
    required this.accountId,
    required this.upstreamModelId,
    this.priorityTier = 0,
    this.localModelId,
  });

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'upstreamModelId': upstreamModelId,
        'priorityTier': priorityTier,
        if (localModelId != null) 'localModelId': localModelId,
      };

  factory LlmModelGroupMember.fromMap(Map<String, dynamic> map) =>
      LlmModelGroupMember(
        accountId: map['accountId'] as String? ?? '',
        upstreamModelId: map['upstreamModelId'] as String? ?? '',
        priorityTier: (map['priorityTier'] as num?)?.toInt() ?? 0,
        localModelId: map['localModelId'] is String
            ? map['localModelId'] as String
            : null,
      );
}

class LlmModelGroup {
  final String id;
  final String displayName;
  final List<LlmModelGroupMember> members;
  final LlmRoutingPolicy policy;

  LlmModelGroup({
    required this.id,
    required this.displayName,
    required this.members,
    LlmRoutingPolicy? policy,
  }) : policy = policy ?? LlmRoutingPolicy();

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'members': members.map((member) => member.toMap()).toList(),
        'policy': policy.toMap(),
      };

  factory LlmModelGroup.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map>()
            .map(
              (item) => LlmModelGroupMember.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <LlmModelGroupMember>[];
    final rawPolicy = map['policy'];
    return LlmModelGroup(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      members: members,
      policy: rawPolicy is Map
          ? LlmRoutingPolicy.fromMap(Map<String, dynamic>.from(rawPolicy))
          : LlmRoutingPolicy(),
    );
  }
}

Map<LlmUsageWindow, LlmWindowPolicy> _completeWindows(
  Map<LlmUsageWindow, LlmWindowPolicy>? values,
) =>
    {
      for (final window in LlmUsageWindow.values)
        window: values?[window] ?? const LlmWindowPolicy(),
    };

T _enumByName<T extends Enum>(
  List<T> values,
  Object? value, {
  required T fallback,
}) =>
    _enumByNameOrNull(values, value) ?? fallback;

T? _enumByNameOrNull<T extends Enum>(List<T> values, Object? value) {
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

LlmMetricObservation _observation(Object? value) => value is Map
    ? LlmMetricObservation.fromMap(Map<String, dynamic>.from(value))
    : const LlmMetricObservation.unknown();
