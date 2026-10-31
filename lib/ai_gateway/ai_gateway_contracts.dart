import 'package:dio/dio.dart' show CancelToken, ProgressCallback;

import '../models/stroom_conversation.dart';

class AiGatewayProviderDefinition {
  final String id;
  final String displayName;
  final Set<String> supportedAuthTypes;
  final Set<String> capabilities;
  final bool supportsChatAdapter;
  final String? chatProtocolId;
  final Map<String, String> authTypeLimitations;

  const AiGatewayProviderDefinition({
    required this.id,
    required this.displayName,
    required this.supportedAuthTypes,
    this.capabilities = const {},
    this.supportsChatAdapter = false,
    this.chatProtocolId,
    this.authTypeLimitations = const {},
  });
}

/// Gateway-owned, redacted metadata for a connector-prepared native request.
/// Authorization headers, request bodies and URL query data are never
/// retained here.
class AiGatewayPreparedRequest {
  final String host;
  final String method;
  final Set<String> headerNames;
  final bool hasBody;
  final String transport;

  AiGatewayPreparedRequest({
    required Uri uri,
    required this.method,
    required Map<String, String> headers,
    required Object? body,
    this.transport = 'http',
  })  : headerNames = Set.unmodifiable(headers.keys),
        hasBody = body != null,
        host = uri.host;
}

/// Response data exposed at the Gateway boundary without connector-service
/// observation or transport implementation types.
class AiGatewayResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Object? body;
  final AiGatewayConnectorObservation observation;
  final Future<AiGatewayConnectorObservation>? completedObservation;

  const AiGatewayResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
    this.observation = const AiGatewayConnectorObservation(),
    this.completedObservation,
  });
}

enum AiGatewayFailureKind {
  request,
  cancelled,
  authenticationRequired,
  transportUnavailable,
}

/// Safe, Gateway-owned request failure details. Raw transport messages and
/// arbitrary response headers are intentionally excluded.
class AiGatewayExecutionException implements Exception {
  final AiGatewayFailureKind kind;
  final int? statusCode;
  final String? code;
  final Map<String, String> headers;

  AiGatewayExecutionException({
    required this.kind,
    this.statusCode,
    this.code,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);

  @override
  String toString() => switch (kind) {
        AiGatewayFailureKind.cancelled => 'AI Gateway request was cancelled.',
        AiGatewayFailureKind.authenticationRequired =>
          'AI Gateway authentication is required.',
        AiGatewayFailureKind.transportUnavailable =>
          'AI Gateway transport is unavailable.',
        AiGatewayFailureKind.request => statusCode == null
            ? 'AI Gateway request could not be completed.'
            : 'AI Gateway request failed with status $statusCode.',
      };
}

class AiGatewayMetricObservation {
  final String? unit;
  final num? value;
  final bool isKnown;
  final String? source;
  final DateTime? observedAt;
  final DateTime? resetAt;

  const AiGatewayMetricObservation.unknown()
      : unit = null,
        value = null,
        isKnown = false,
        source = null,
        observedAt = null,
        resetAt = null;

  const AiGatewayMetricObservation({
    required this.unit,
    required this.value,
    required this.isKnown,
    this.source,
    this.observedAt,
    this.resetAt,
  });
}

class AiGatewayConnectorObservation {
  final AiGatewayMetricObservation requestUsage;
  final AiGatewayMetricObservation remainingQuota;
  final Map<String, AiGatewayMetricObservation> quotaSignals;

  const AiGatewayConnectorObservation({
    this.requestUsage = const AiGatewayMetricObservation.unknown(),
    this.remainingQuota = const AiGatewayMetricObservation.unknown(),
    this.quotaSignals = const {},
  });
}

enum AiGatewayAccountStatus { unknown, ready, paused, needsAttention }

enum AiGatewayFallbackScope { modelGroup, account }

enum AiGatewaySelectionStrategy {
  leastUsed,
  roundRobin,
  balanceHigher,
  balanceLower,
}

enum AiGatewayUsageWindow { fiveHour, day, week, month }

enum AiGatewayWindowMode { rolling, calendar }

enum AiGatewayLimitKind { fixed, percentage }

class AiGatewayLimitThreshold {
  final AiGatewayLimitKind kind;
  final num value;
  final String? unit;

  const AiGatewayLimitThreshold.fixed(this.value, {this.unit})
      : kind = AiGatewayLimitKind.fixed;

  const AiGatewayLimitThreshold.percentage(this.value)
      : kind = AiGatewayLimitKind.percentage,
        unit = 'percent';
}

class AiGatewayWindowPolicy {
  final AiGatewayWindowMode mode;
  final String? timeZone;
  final AiGatewayLimitThreshold? reserveFloor;
  final AiGatewayLimitThreshold? usageCeiling;

  const AiGatewayWindowPolicy({
    this.mode = AiGatewayWindowMode.rolling,
    this.timeZone,
    this.reserveFloor,
    this.usageCeiling,
  });
}

class AiGatewayRoutingPolicy {
  final AiGatewayFallbackScope fallbackScope;
  final AiGatewaySelectionStrategy strategy;
  final Map<AiGatewayUsageWindow, AiGatewayWindowPolicy> windows;
  final int? concurrencyLimit;

  AiGatewayRoutingPolicy({
    this.fallbackScope = AiGatewayFallbackScope.modelGroup,
    this.strategy = AiGatewaySelectionStrategy.leastUsed,
    Map<AiGatewayUsageWindow, AiGatewayWindowPolicy>? windows,
    this.concurrencyLimit,
  }) : windows = Map.unmodifiable({
          for (final window in AiGatewayUsageWindow.values)
            window: windows?[window] ?? const AiGatewayWindowPolicy(),
        });
}

class AiGatewayUsageWindowState {
  final AiGatewayMetricObservation quota;
  final AiGatewayMetricObservation used;
  final AiGatewayMetricObservation remaining;
  final DateTime? resetAt;
  final String? source;

  const AiGatewayUsageWindowState({
    this.quota = const AiGatewayMetricObservation.unknown(),
    this.used = const AiGatewayMetricObservation.unknown(),
    this.remaining = const AiGatewayMetricObservation.unknown(),
    this.resetAt,
    this.source,
  });
}

class AiGatewayUpstreamModel {
  final String id;
  final String upstreamModelId;
  final String displayName;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> config;

  AiGatewayUpstreamModel({
    required this.id,
    required this.upstreamModelId,
    required this.displayName,
    Map<String, dynamic> capabilities = const {},
    Map<String, dynamic> config = const {},
  })  : capabilities = Map.unmodifiable(capabilities),
        config = Map.unmodifiable(config);
}

/// Gateway-owned account data. Credential references are opaque, non-secret
/// secure-storage keys; secret values remain private to the Gateway adapter.
class AiGatewayAccount {
  final String id;
  final String connectorType;
  final String authType;
  final String displayName;
  final AiGatewayAccountStatus status;
  final bool hasCredential;

  /// Opaque, non-secret secure-storage key used to resolve this credential.
  final String? credentialRef;
  final Map<String, dynamic> endpointConfig;
  final List<AiGatewayUpstreamModel> models;
  final AiGatewayRoutingPolicy policy;
  final Map<AiGatewayUsageWindow, AiGatewayUsageWindowState> usageByWindow;
  final AiGatewayMetricObservation remainingQuota;
  final Map<String, AiGatewayMetricObservation> quotaSignals;

  AiGatewayAccount({
    required this.id,
    required this.connectorType,
    required this.authType,
    required this.displayName,
    this.status = AiGatewayAccountStatus.unknown,
    this.hasCredential = false,
    this.credentialRef,
    Map<String, dynamic> endpointConfig = const {},
    List<AiGatewayUpstreamModel> models = const [],
    AiGatewayRoutingPolicy? policy,
    Map<AiGatewayUsageWindow, AiGatewayUsageWindowState>? usageByWindow,
    this.remainingQuota = const AiGatewayMetricObservation.unknown(),
    Map<String, AiGatewayMetricObservation> quotaSignals = const {},
  })  : endpointConfig = Map.unmodifiable(endpointConfig),
        models = List.unmodifiable(models),
        policy = policy ?? AiGatewayRoutingPolicy(),
        usageByWindow = Map.unmodifiable(usageByWindow ?? const {}),
        quotaSignals = Map.unmodifiable(quotaSignals);
}

class AiGatewayModelGroupMember {
  final String accountId;
  final String upstreamModelId;
  final int priorityTier;
  final String? localModelId;

  const AiGatewayModelGroupMember({
    required this.accountId,
    required this.upstreamModelId,
    this.priorityTier = 0,
    this.localModelId,
  });
}

class AiGatewayModelGroup {
  final String id;
  final String displayName;
  final List<AiGatewayModelGroupMember> members;
  final AiGatewayRoutingPolicy policy;
  final String? legacyModelId;
  final String? legacyProviderName;

  AiGatewayModelGroup({
    required this.id,
    required this.displayName,
    required List<AiGatewayModelGroupMember> members,
    AiGatewayRoutingPolicy? policy,
    this.legacyModelId,
    this.legacyProviderName,
  })  : members = List.unmodifiable(members),
        policy = policy ?? AiGatewayRoutingPolicy();
}

class AiGatewayRouteCandidate {
  final AiGatewayAccount account;
  final AiGatewayModelGroupMember member;
  final String localModelId;
  final String upstreamModelId;
  final int priorityTier;
  final int memberIndex;

  const AiGatewayRouteCandidate({
    required this.account,
    required this.member,
    required this.localModelId,
    required this.upstreamModelId,
    required this.priorityTier,
    required this.memberIndex,
  });
}

abstract interface class AiGatewayRouteProgress {
  bool get requestWasSent;
  bool get visibleOutput;
  bool get toolSideEffect;
  Future<void> markRequestSent();
  Future<void> markOutputVisible();
  Future<void> markToolSideEffect();
  Future<void> recordUsage({
    required String unit,
    required num value,
    required String source,
  });
}

class AiGatewayRouteDecision {
  final String subjectId;
  final String reason;

  const AiGatewayRouteDecision({required this.subjectId, required this.reason});
}

class AiGatewayRoutingExecution<T> {
  final T value;
  final AiGatewayRouteCandidate candidate;
  final List<String> attemptedAccountIds;
  final List<AiGatewayRouteDecision> decisions;

  AiGatewayRoutingExecution({
    required this.value,
    required this.candidate,
    required List<String> attemptedAccountIds,
    required List<AiGatewayRouteDecision> decisions,
  })  : attemptedAccountIds = List.unmodifiable(attemptedAccountIds),
        decisions = List.unmodifiable(decisions);
}

class AiGatewayRoutingException implements Exception {
  final List<AiGatewayRouteDecision> decisions;

  AiGatewayRoutingException(Iterable<AiGatewayRouteDecision> decisions)
      : decisions = List.unmodifiable(decisions);

  @override
  String toString() => decisions.isNotEmpty &&
          decisions.every(
            (decision) => decision.reason == 'capability_mismatch',
          )
      ? 'No connected account and model support the capabilities required for this request.'
      : 'No eligible account is available for this model group.';
}

class AiGatewayUsageMeasurement {
  final String unit;
  final num value;

  const AiGatewayUsageMeasurement({required this.unit, required this.value});
}

class AiGatewayUsageEvent {
  final String accountId;
  final String groupId;
  final List<AiGatewayUsageMeasurement> measurements;

  AiGatewayUsageEvent({
    required this.accountId,
    required this.groupId,
    required List<AiGatewayUsageMeasurement> measurements,
  }) : measurements = List.unmodifiable(measurements);
}

class AiGatewayRoutingSnapshot {
  final List<AiGatewayUsageEvent> events;

  AiGatewayRoutingSnapshot({required List<AiGatewayUsageEvent> events})
      : events = List.unmodifiable(events);
}

/// Public account and model-group operations exposed to management surfaces.
/// Credentials remain references managed by the Gateway's secure storage.
abstract interface class AiGatewayAccountManagement {
  Future<List<AiGatewayAccount>> listAccounts();
  Future<List<AiGatewayModelGroup>> listModelGroups();
  Future<AiGatewayAccount> saveAccount(
    AiGatewayAccount account, {
    String? secret,
  });
  Future<void> deleteAccount(String accountId);
  Future<void> saveModelGroup(AiGatewayModelGroup group);
  Future<void> deleteModelGroup(String groupId);
  Future<void> recordQuotaObservation({
    required String accountId,
    required AiGatewayMetricObservation remainingQuota,
    required Map<String, AiGatewayMetricObservation> quotaSignals,
  });
}

/// Provider and supported-capability metadata, kept separate from account
/// state and request execution.
abstract interface class AiGatewayProviderCatalog {
  Iterable<AiGatewayProviderDefinition> get providers;
  AiGatewayProviderDefinition? findProvider(String providerId);
}

/// One provider-specific connector owns connection validation and provider
/// request preparation, independently of catalog, execution and routing.
abstract interface class AiGatewayConnector {
  String get providerId;
  Future<void> validateConnection(AiGatewayAccount account);
  AiGatewayPreparedRequest prepareRequest({
    required AiGatewayAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
  });
}

/// Capability lookup has its own contract so routing and model selectors do
/// not infer capabilities from provider names.
abstract interface class AiGatewayCapabilityCatalog {
  Set<String> capabilitiesFor({
    required String providerId,
    required String modelId,
  });
}

/// Lifecycle hooks for provider-authenticated accounts. Implementations must
/// keep token material in secure storage and report only non-secret state.
abstract interface class AiGatewayAuthLifecycle {
  Future<AiGatewayAccount> connect(
    AiGatewayAccount account, {
    required String credential,
  });
  Future<bool> refresh(AiGatewayAccount account);
  Future<void> revoke(AiGatewayAccount account);
}

/// Performs provider browser OAuth without exposing token material through the
/// public Gateway. Implementations commit tokens directly to secure storage.
abstract interface class AiGatewayOAuthAuthorization {
  Future<AiGatewayAccount> authorize(
    AiGatewayAccount account, {
    Map<String, String> configuration = const {},
  });
  Future<void> revoke(AiGatewayAccount account);

  /// Deletes an OAuth account before attempting provider revocation. Returns
  /// false when local deletion succeeded but provider revocation did not.
  Future<bool> deleteAccountAndRevoke(AiGatewayAccount account);
}

class AiGatewayOAuthException implements Exception {
  const AiGatewayOAuthException();

  @override
  String toString() => 'OAuth authorization could not be completed.';
}

/// Capability and model discovery is independent of provider registration.
abstract interface class AiGatewayModelDiscovery {
  Future<List<AiGatewayUpstreamModel>> discoverModels(
    AiGatewayAccount account, {
    bool refreshRemote = false,
  });

  /// Discovers only models mapped into a saved group from connected accounts
  /// and satisfying each requested, provider-observed capability.
  Future<List<AiGatewayUpstreamModel>> discoverGroupModels({
    required String groupId,
    required String localModelId,
    Set<String> requiredCapabilities = const {},
    bool refreshRemote = false,
  });
}

/// Adapts one upstream protocol to Stroom's protocol-neutral conversation
/// representation. Concrete protocol mappings are implemented in later units.
abstract interface class AiGatewayProtocolBridge<TExternal> {
  String get protocolId;
  StroomMessage toStroom(TExternal message);
  TExternal fromStroom(StroomMessage message);
}

/// Executes a provider-native HTTP request. Executors do not own account
/// selection, request preparation or protocol conversion.
abstract interface class AiGatewayExecutor {
  Future<AiGatewayResponse> request({
    required AiGatewayAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Future<void> Function()? onRequestSent,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  });
}

/// Account and model-group selection stays behind this routing contract.
abstract interface class AiGatewayRouting {
  Future<AiGatewayRoutingExecution<T>> executeForGroupId<T>({
    required String groupId,
    required String localModelId,
    required Future<T> Function(
      AiGatewayRouteCandidate candidate,
      AiGatewayRouteProgress progress,
    ) request,
    Set<String> requiredCapabilities = const {},
    Map<String, num> estimatedUsage = const {},
    Set<String>? supportedConnectorTypes,
    String? conversationId,
    String? selectedAccountId,
  });
}

/// Stable application-facing Gateway API. Its operations use only
/// Gateway-owned contracts; infrastructure implementations stay internal.
abstract interface class AiGatewayFacade implements AiGatewayRouting {
  AiGatewayAccountManagement get accountManagement;
  AiGatewayOAuthAuthorization get oauthAuthorization;
  AiGatewayProviderCatalog get providerCatalog;
  AiGatewayModelDiscovery get modelDiscovery;
  AiGatewayExecutor get executor;

  Future<AiGatewayRoutingSnapshot> loadRoutingState();

  Future<void> ensureLegacyOcrModelGroup({
    required String accountId,
    required String groupId,
    required String localModelId,
    required String upstreamModelId,
    required String displayName,
    required String baseUrl,
    required String apiKey,
    bool synchronizeEndpoint = false,
    bool synchronizeCredential = false,
    bool synchronizeModel = false,
  });

  Future<void> synchronizeLegacyOcrModelSet({
    required String accountId,
    required Set<String> localModelIds,
  });
}
