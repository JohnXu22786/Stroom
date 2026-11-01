import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../ai_gateway/ai_gateway_contracts.dart';
import '../../models/llm_account.dart';
import '../../services/llm_account_migration_service.dart';
import '../../services/llm_connector_service.dart';
import '../../services/llm_connector_http_client.dart';
import '../../services/llm_credential_store.dart';
import '../../services/llm_oauth_flow.dart';
import '../../services/llm_oauth_loopback.dart';
import '../../services/llm_oauth_token_client.dart';
import '../../services/llm_routing_service.dart';

/// Reproduces M1's stable identity for a legacy account/model reference.
String stableLlmModelGroupId(String accountId, String localModelId) {
  final encodedAccountId = Uri.encodeComponent(accountId);
  final encodedLocalModelId = Uri.encodeComponent(localModelId);
  return 'stroom.model-group.${encodedAccountId.length}:$encodedAccountId'
      '${encodedLocalModelId.length}:$encodedLocalModelId';
}

String? stableLlmModelGroupLocalModelId(String groupId) {
  const prefix = 'stroom.model-group.';
  if (!groupId.startsWith(prefix)) return null;
  final accountLengthEnd = groupId.indexOf(':', prefix.length);
  if (accountLengthEnd < 0) return null;
  final accountLength = int.tryParse(
    groupId.substring(prefix.length, accountLengthEnd),
  );
  if (accountLength == null || accountLength < 1) return null;
  final accountStart = accountLengthEnd + 1;
  final accountEnd = accountStart + accountLength;
  if (accountEnd >= groupId.length) return null;
  final localLengthEnd = groupId.indexOf(':', accountEnd);
  if (localLengthEnd < 0) return null;
  final localLength = int.tryParse(
    groupId.substring(accountEnd, localLengthEnd),
  );
  if (localLength == null || localLength < 1) return null;
  final localStart = localLengthEnd + 1;
  final localEnd = localStart + localLength;
  if (localEnd != groupId.length) return null;
  try {
    return Uri.decodeComponent(groupId.substring(localStart, localEnd));
  } on FormatException {
    return null;
  }
}

/// Shared account/model-group boundary used by ChatAdapter and direct LLM
/// callers. UI code may use the same account service for configuration, while
/// routing stays in [LlmRoutingService].
class LlmChatRoutingRuntime implements AiGatewayFacade {
  static Future<LlmChatRoutingRuntime>? _sharedPlatformRuntime;

  static AiGatewayProviderCatalog get defaultProviderCatalog =>
      _LlmGatewayProviderCatalog();

  final LlmAccountConnectorService _accountService;
  final Dio? _oauthDio;
  final AiGatewayOAuthAuthorization? _oauthAuthorizationOverride;
  @override
  final AiGatewayAccountManagement accountManagement;
  @override
  late final AiGatewayOAuthAuthorization oauthAuthorization =
      _oauthAuthorizationOverride ??
          _LlmGatewayOAuthAuthorization(
            _accountService,
            accountManagement as _LlmGatewayAccountManagement,
            dio: _oauthDio,
          );
  @override
  late final AiGatewayProviderCatalog providerCatalog = defaultProviderCatalog;
  @override
  late final AiGatewayModelDiscovery modelDiscovery = _LlmGatewayModelDiscovery(
    _accountService,
  );
  final LlmRoutingService _routingService;
  final LlmConnectorHttpClient _connectorClient;
  @override
  late final AiGatewayExecutor executor = _LlmGatewayExecutor(_connectorClient);

  LlmChatRoutingRuntime({
    required LlmAccountConnectorService accountService,
    required LlmRoutingService routingService,
    LlmConnectorHttpClient? connectorClient,
    Dio? oauthDio,
    AiGatewayOAuthAuthorization? oauthAuthorization,
  })  : _accountService = accountService,
        _oauthDio = oauthDio,
        _oauthAuthorizationOverride = oauthAuthorization,
        accountManagement = _LlmGatewayAccountManagement(accountService),
        _routingService = routingService,
        _connectorClient = connectorClient ??
            LlmConnectorHttpClient(accountService: accountService);

  @override
  Future<AiGatewayRoutingSnapshot> loadRoutingState() async {
    final state = await LlmRoutingStateStore(
      preferences: _accountService.preferences,
    ).load();
    return AiGatewayRoutingSnapshot(
      events: state.events
          .map(
            (event) => AiGatewayUsageEvent(
              accountId: event.accountId,
              groupId: event.groupId,
              measurements: event.measurements
                  .map(
                    (measurement) => AiGatewayUsageMeasurement(
                      unit: measurement.unit,
                      value: measurement.value,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  static Future<LlmChatRoutingRuntime> createPlatform() async {
    final preferences = _SharedPreferencesLlmAccountPreferences(
      await SharedPreferences.getInstance(),
    );
    final accountService = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: PlatformLlmCredentialStore(),
    );
    return LlmChatRoutingRuntime(
      accountService: accountService,
      routingService: LlmRoutingService(accountService: accountService),
    );
  }

  /// Returns the process-wide platform runtime so independent task services
  /// share routing state such as the round-robin cursor.
  static Future<LlmChatRoutingRuntime> sharedPlatform() {
    final existing = _sharedPlatformRuntime;
    if (existing != null) return existing;

    late final Future<LlmChatRoutingRuntime> sharedRuntime;
    sharedRuntime = createPlatform().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (identical(_sharedPlatformRuntime, sharedRuntime)) {
        _sharedPlatformRuntime = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _sharedPlatformRuntime = sharedRuntime;
    return sharedRuntime;
  }

  Future<LlmModelGroup> _resolveGroupForModelReference({
    required String accountId,
    required String localModelId,
  }) async {
    final groups = await _accountService.listModelGroups();
    final stableId = stableLlmModelGroupId(accountId, localModelId);
    for (final group in groups) {
      if (group.id == stableId) return group;
    }

    final matchingGroups = groups
        .where(
          (group) => group.members.any(
            (member) =>
                member.accountId == accountId &&
                member.localModelId == localModelId,
          ),
        )
        .toList(growable: false);
    if (matchingGroups.length == 1) return matchingGroups.single;
    throw AiGatewayRoutingException([
      AiGatewayRouteDecision(
        subjectId: accountId,
        reason: matchingGroups.isEmpty
            ? 'model_group_missing'
            : 'model_group_ambiguous',
      ),
    ]);
  }

  Future<AiGatewayRoutingExecution<T>> executeForModelReference<T>({
    required String accountId,
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
  }) async {
    final stableId = stableLlmModelGroupId(accountId, localModelId);
    final LlmModelGroup group;
    try {
      group = await _resolveGroupForModelReference(
        accountId: accountId,
        localModelId: localModelId,
      );
    } on AiGatewayRoutingException catch (error) {
      LlmChatRouteDiagnostics.record(
        groupId: stableId,
        localModelId: localModelId,
        decisions: error.decisions,
      );
      rethrow;
    }
    final execution = await _executeGroup(
      group: group,
      localModelId: localModelId,
      request: (candidate, progress) => request(
        _gatewayCandidate(candidate),
        _GatewayRouteProgressAdapter(progress),
      ),
      requiredCapabilities: requiredCapabilities,
      estimatedUsage: estimatedUsage,
      supportedConnectorTypes: supportedConnectorTypes,
      conversationId: conversationId,
      selectedAccountId: selectedAccountId,
    );
    return _gatewayExecution(execution);
  }

  /// Executes through one exact saved group identity. Used for selector and
  /// Task Flow references whose config ID is already the stable group ID.
  @override
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
    bool Function(AiGatewayRouteCandidate candidate)? candidateFilter,
    String? conversationId,
    String? selectedAccountId,
  }) async {
    final matching = (await _accountService.listModelGroups())
        .where((group) => group.id == groupId)
        .toList(growable: false);
    if (matching.length != 1) {
      final decisions = [
        LlmRouteDecision(
          subjectId: groupId,
          reason: matching.isEmpty
              ? 'model_group_missing'
              : 'model_group_ambiguous',
        ),
      ];
      LlmChatRouteDiagnostics.record(
        groupId: groupId,
        localModelId: localModelId,
        decisions: _gatewayRouteDecisions(decisions),
      );
      throw AiGatewayRoutingException(_gatewayRouteDecisions(decisions));
    }
    final execution = await _executeGroup(
      group: matching.single,
      localModelId: localModelId,
      request: (candidate, progress) => request(
        _gatewayCandidate(candidate),
        _GatewayRouteProgressAdapter(progress),
      ),
      requiredCapabilities: requiredCapabilities,
      estimatedUsage: estimatedUsage,
      supportedConnectorTypes: supportedConnectorTypes,
      candidateFilter: candidateFilter == null
          ? null
          : (candidate) => candidateFilter(_gatewayCandidate(candidate)),
      conversationId: conversationId,
      selectedAccountId: selectedAccountId,
    );
    return _gatewayExecution(execution);
  }

  /// Upgrades a selected legacy OCR provider model into a secure account and
  /// exact stable group before its first routed request. The generated account
  /// ID is namespaced by [llmOcrAccountIdForConfig] so it cannot collide with
  /// an ordinary account that happens to reuse the provider config ID.
  @override
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
  }) async {
    final expectedGroupId = stableLlmModelGroupId(accountId, localModelId);
    if (accountId.length <= 4 ||
        !accountId.startsWith('ocr-') ||
        groupId != expectedGroupId ||
        localModelId.trim().isEmpty ||
        upstreamModelId.trim().isEmpty ||
        baseUrl.trim().isEmpty) {
      throw AiGatewayRoutingException([
        AiGatewayRouteDecision(
          subjectId: groupId,
          reason: 'model_group_missing',
        ),
      ]);
    }
    final sourceConfigId = accountId.substring(4);
    try {
      await _accountService.ensureLegacyOcrModelGroup(
        accountId: accountId,
        sourceConfigId: sourceConfigId,
        groupId: groupId,
        localModelId: localModelId,
        upstreamModelId: upstreamModelId,
        displayName: displayName,
        baseUrl: baseUrl,
        apiKey: apiKey,
        synchronizeEndpoint: synchronizeEndpoint,
        synchronizeCredential: synchronizeCredential,
        synchronizeModel: synchronizeModel,
      );
    } on LlmRoutingUnavailableException catch (error) {
      throw _gatewayRoutingFailure(error);
    }
  }

  @override
  Future<void> synchronizeLegacyOcrModelSet({
    required String accountId,
    required Set<String> localModelIds,
  }) async {
    if (!accountId.startsWith('ocr-') || accountId.length <= 4) {
      throw AiGatewayRoutingException([
        AiGatewayRouteDecision(
          subjectId: accountId,
          reason: 'model_group_missing',
        ),
      ]);
    }
    try {
      await _accountService.synchronizeLegacyOcrModelSet(
        accountId: accountId,
        sourceConfigId: accountId.substring(4),
        localModelIds: localModelIds,
      );
    } on LlmRoutingUnavailableException catch (error) {
      throw _gatewayRoutingFailure(error);
    }
  }

  Future<LlmRoutingExecution<T>> _executeGroup<T>({
    required LlmModelGroup group,
    required String localModelId,
    required Future<T> Function(
      LlmRouteCandidate candidate,
      LlmRouteProgress progress,
    ) request,
    required Set<String> requiredCapabilities,
    required Map<String, num> estimatedUsage,
    required Set<String>? supportedConnectorTypes,
    bool Function(LlmRouteCandidate candidate)? candidateFilter,
    String? conversationId,
    String? selectedAccountId,
  }) async {
    // Every routed connector invocation sends one HTTP request. Keep that
    // known usage estimate available to account/group request-count policies
    // while preserving any more specific estimates supplied by a caller.
    final routeEstimatedUsage = Map<String, num>.from(estimatedUsage)
      ..['requests'] = 1;
    final excluded = <LlmRouteDecision>[];
    final failedRequests = <LlmRouteDecision>[];
    LlmRouteCandidate? lastAttemptedCandidate;
    try {
      var routeGroup = group;
      final allowedConnectorTypes = supportedConnectorTypes ??
          LlmConnectorRegistry.all
              .where(
                (connector) =>
                    LlmConnectorRegistry.chatAdapterEndpointType(
                      connector.id,
                    ) !=
                    null,
              )
              .map((connector) => connector.id)
              .toSet();
      {
        final accounts = {
          for (final account in await _accountService.listAccounts())
            account.id: account,
        };
        final eligibleMembers = <LlmModelGroupMember>[];
        for (final entry in group.members.indexed) {
          final member = entry.$2;
          final account = accounts[member.accountId];
          final connectorType = account == null
              ? null
              : LlmConnectorRegistry.canonicalId(account.connectorType);
          final candidateIsSupported = account == null ||
              candidateFilter == null ||
              candidateFilter(
                LlmRouteCandidate(
                  account: account,
                  member: member,
                  localModelId: member.localModelId ?? localModelId,
                  upstreamModelId: member.upstreamModelId,
                  priorityTier: member.priorityTier,
                  memberIndex: entry.$1,
                ),
              );
          if (connectorType != null &&
              (!allowedConnectorTypes.contains(connectorType) ||
                  !candidateIsSupported ||
                  !LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
                    connectorType,
                    account!.authType,
                  ))) {
            excluded.add(
              LlmRouteDecision(
                subjectId: member.accountId,
                reason: 'connector_protocol_incompatible',
              ),
            );
            continue;
          }
          eligibleMembers.add(member);
        }
        routeGroup = LlmModelGroup(
          id: group.id,
          displayName: group.displayName,
          members: eligibleMembers,
          policy: group.policy,
          legacyModelId: group.legacyModelId,
          legacyProviderName: group.legacyProviderName,
        );
      }
      final selectedAccountIsIneligible = selectedAccountId != null &&
          group.members.any(
            (member) => member.accountId == selectedAccountId,
          ) &&
          !routeGroup.members.any(
            (member) => member.accountId == selectedAccountId,
          );

      final execution = await _routingService.execute<T>(
        group: routeGroup,
        requestedModelId: localModelId,
        request: (candidate, progress) async {
          lastAttemptedCandidate = candidate;
          try {
            return await request(candidate, progress);
          } on AiGatewayExecutionException catch (error) {
            if (error.kind != AiGatewayFailureKind.request) rethrow;
            throw LlmRouteRequestException(
              statusCode: error.statusCode,
              code: error.code,
              headers: error.headers,
            );
          } catch (error) {
            final classification = LlmRequestErrorClassifier.classify(
              error,
              now: DateTime.now().toUtc(),
            );
            failedRequests.add(
              LlmRouteDecision(
                subjectId: candidate.account.id,
                reason: 'request_${classification.kind.name}',
              ),
            );
            rethrow;
          }
        },
        requiredCapabilities: requiredCapabilities,
        estimatedUsage: routeEstimatedUsage,
        conversationId: conversationId,
        selectedAccountId: selectedAccountId,
        selectedAccountIsIneligible: selectedAccountIsIneligible,
      );
      final result = LlmRoutingExecution<T>(
        value: execution.value,
        candidate: execution.candidate,
        attemptedAccountIds: execution.attemptedAccountIds,
        decisions: [...excluded, ...execution.decisions],
      );
      LlmChatRouteDiagnostics.record(
        groupId: group.id,
        localModelId: localModelId,
        selectedAccountId: result.candidate.account.id,
        decisions: _gatewayRouteDecisions(result.decisions),
        requestSucceeded: true,
      );
      return result;
    } on LlmRoutingUnavailableException catch (error) {
      final decisions = [...excluded, ...error.decisions];
      LlmChatRouteDiagnostics.record(
        groupId: group.id,
        localModelId: localModelId,
        decisions: _gatewayRouteDecisions(decisions),
      );
      throw AiGatewayRoutingException(_gatewayRouteDecisions(decisions));
    } catch (error) {
      final candidate = lastAttemptedCandidate;
      final decisions = [...excluded, ...failedRequests];
      if (failedRequests.isEmpty && candidate != null) {
        final classification = LlmRequestErrorClassifier.classify(
          error,
          now: DateTime.now().toUtc(),
        );
        decisions.add(
          LlmRouteDecision(
            subjectId: candidate.account.id,
            reason: 'request_${classification.kind.name}',
          ),
        );
      }
      LlmChatRouteDiagnostics.record(
        groupId: group.id,
        localModelId: localModelId,
        selectedAccountId: candidate?.account.id,
        decisions: _gatewayRouteDecisions(decisions),
      );
      if (error is LlmRouteRequestException) {
        throw AiGatewayExecutionException(
          kind: AiGatewayFailureKind.request,
          statusCode: error.statusCode,
          code: error.code,
          headers: error.headers,
        );
      }
      rethrow;
    }
  }
}

class _LlmGatewayOAuthAuthorization implements AiGatewayOAuthAuthorization {
  static const _hostIdPreferenceKey = 'stroom.llm.oauth.openai.host_id';

  final LlmAccountConnectorService _accounts;
  final _LlmGatewayAccountManagement _accountManagement;
  final LlmOAuthTokenClient _tokenClient;
  final Dio _dio;

  _LlmGatewayOAuthAuthorization(
    this._accounts,
    this._accountManagement, {
    Dio? dio,
    LlmOAuthTokenClient? tokenClient,
  })  : _dio = dio ?? _createOAuthDio(),
        _tokenClient =
            tokenClient ?? LlmOAuthTokenClient(dio: dio ?? _createOAuthDio());

  static Dio _createOAuthDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  @override
  Future<AiGatewayAccount> authorize(
    AiGatewayAccount account, {
    Map<String, String> configuration = const {},
  }) async {
    if (account.authType != 'oauth' ||
        !LlmOAuthProviderPolicy.forProvider(account.connectorType).supported) {
      throw const AiGatewayOAuthException();
    }
    LlmOAuthLoopback? listener;
    try {
      final isOpenAi = account.connectorType == 'codex';
      final isGemini = account.connectorType == 'gemini' ||
          account.connectorType == 'aistudio';
      if (!isOpenAi && !isGemini) {
        throw const AiGatewayOAuthException();
      }
      if (isGemini &&
          !_isGoogleCloudProjectId(
            account.endpointConfig['googleCloudProjectId'],
          )) {
        throw const AiGatewayOAuthException();
      }
      if (kIsWeb) throw const AiGatewayOAuthException();

      listener = await LlmOAuthLoopback.bind(isGemini ? '/' : '/auth/callback');
      final redirectUri = isGemini
          ? listener.redirectUri.replace(path: '')
          : listener.redirectUri;
      final previousBundle =
          isGemini || isOpenAi ? await _existingOAuthBundle(account) : null;
      final previousOpenAiBundle =
          previousBundle?['oauth_contract'] == 'openai-siwc-v1'
              ? previousBundle
              : null;
      late final LlmOAuthAuthorizationAttempt attempt;
      if (isOpenAi) {
        attempt = LlmOAuthAuthorizationAttempt.openAiChatGpt(
          redirectUri: listener.redirectUri,
          hostId: await _openAiHostId(),
          existingClientId: previousOpenAiBundle?['client_id'] as String?,
          idTokenHint: previousOpenAiBundle?['id_token'] as String?,
        );
      } else {
        final clientId = (configuration['clientId'] ?? '').trim().isNotEmpty
            ? configuration['clientId']!.trim()
            : previousBundle?['client_id'] as String? ?? '';
        attempt = LlmOAuthAuthorizationAttempt.geminiDeveloperApi(
          redirectUri: redirectUri,
          clientId: clientId,
        );
      }
      if (!await launchUrl(
        attempt.authorizationUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw const AiGatewayOAuthException();
      }
      final callbackUri = await listener.nextCallback().timeout(
            const Duration(minutes: 5),
          );
      final callback = attempt.consumeCallback(callbackUri);
      final tokenBundle = isOpenAi
          ? await _tokenClient.exchangeOpenAiChatGpt(
              attempt: attempt,
              callback: callback,
              expectedSubject: previousOpenAiBundle?['identity_sub'] as String?,
            )
          : await _tokenClient.exchangeGeminiDeveloperApi(
              attempt: attempt,
              callback: callback,
              clientSecret:
                  (configuration['clientSecret'] ?? '').trim().isNotEmpty
                      ? configuration['clientSecret']!.trim()
                      : previousBundle?['client_secret'] as String? ?? '',
            );
      final saved = await _accountManagement.saveAuthorizedOAuthAccount(
        AiGatewayAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: account.authType,
          displayName: account.displayName,
          status: AiGatewayAccountStatus.ready,
          hasCredential: true,
          credentialRef: account.credentialRef,
          endpointConfig: account.endpointConfig,
          models: account.models,
          policy: account.policy,
          usageByWindow: account.usageByWindow,
          remainingQuota: account.remainingQuota,
          quotaSignals: account.quotaSignals,
        ),
        secret: jsonEncode(tokenBundle),
      );
      await listener.respond(accepted: true);
      return saved;
    } catch (_) {
      if (listener != null) await listener.respond(accepted: false);
      throw const AiGatewayOAuthException();
    } finally {
      await listener?.close();
    }
  }

  @override
  Future<void> revoke(AiGatewayAccount account) async {
    try {
      if (account.authType != 'oauth') {
        throw const AiGatewayOAuthException();
      }
      if (!LlmOAuthProviderPolicy.forProvider(
        account.connectorType,
      ).supported) {
        return;
      }
      final raw = await _accounts.readCredential(account.id);
      if (raw == null) throw const AiGatewayOAuthException();
      final bundle = _decodeOAuthBundle(raw);
      await _revokeBundle(account, bundle);
    } catch (_) {
      throw const AiGatewayOAuthException();
    }
  }

  @override
  Future<bool> deleteAccountAndRevoke(AiGatewayAccount account) async {
    if (account.authType != 'oauth' ||
        !LlmOAuthProviderPolicy.forProvider(account.connectorType).supported) {
      await _accountManagement.deleteAccount(account.id);
      return true;
    }

    Map<String, dynamic>? bundle;
    try {
      final raw = await _accounts.readCredential(account.id);
      if (raw != null) bundle = _decodeOAuthBundle(raw);
    } catch (_) {
      // Preserve local deletion even when the credential cannot be read for
      // provider revocation. The caller will report the revocation failure.
    }

    // The account service can restore its record and credential if deletion
    // fails. Revoke only after it succeeds so the retained account stays
    // usable on that failure path.
    await _accountManagement.deleteAccount(account.id);
    if (bundle == null) return false;
    try {
      await _revokeBundle(account, bundle);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _revokeBundle(
    AiGatewayAccount account,
    Map<String, dynamic> bundle,
  ) async {
    try {
      final refreshToken = bundle['refresh_token'];
      if (refreshToken is! String || refreshToken.isEmpty) {
        throw const AiGatewayOAuthException();
      }
      late final Uri revocationEndpoint;
      late final Map<String, String> body;
      if (account.connectorType == 'codex') {
        final discovery = await _dio.getUri<Object?>(
          Uri.parse('https://auth.openai.com/.well-known/openid-configuration'),
        );
        final discoveryBody = _decodeOAuthBundle(jsonEncode(discovery.data));
        final endpoint = discoveryBody['revocation_endpoint'];
        final parsed = endpoint is String ? Uri.tryParse(endpoint) : null;
        if (parsed == null ||
            parsed.scheme != 'https' ||
            parsed.host != 'auth.openai.com') {
          throw const AiGatewayOAuthException();
        }
        revocationEndpoint = parsed;
        final clientId = bundle['client_id'];
        if (clientId is! String || clientId.isEmpty) {
          throw const AiGatewayOAuthException();
        }
        body = {
          'client_id': clientId,
          'token': refreshToken,
          'token_type_hint': 'refresh_token',
        };
      } else if (account.connectorType == 'gemini' ||
          account.connectorType == 'aistudio') {
        revocationEndpoint = Uri.parse('https://oauth2.googleapis.com/revoke');
        body = {'token': refreshToken};
      } else {
        throw const AiGatewayOAuthException();
      }
      final response = await _dio.postUri<Object?>(
        revocationEndpoint,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null,
        ),
      );
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300) {
        throw const AiGatewayOAuthException();
      }
    } catch (_) {
      throw const AiGatewayOAuthException();
    }
  }

  Future<String> _openAiHostId() async {
    final preferences = _accounts.preferences;
    final existing = await preferences.getString(_hostIdPreferenceKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final created = 'urn:uuid:${const Uuid().v4()}';
    if (!await preferences.setString(_hostIdPreferenceKey, created)) {
      throw const AiGatewayOAuthException();
    }
    return created;
  }

  Future<Map<String, dynamic>?> _existingOAuthBundle(
    AiGatewayAccount account,
  ) async {
    final raw = await _accounts.readCredential(account.id);
    if (raw == null) return null;
    try {
      return _decodeOAuthBundle(raw);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeOAuthBundle(String raw) {
    final value = jsonDecode(raw);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const AiGatewayOAuthException();
  }

  static bool _isGoogleCloudProjectId(Object? value) =>
      value is String &&
      RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(value.trim());
}

class LlmChatRouteDiagnostic {
  final String groupId;
  final String localModelId;
  final String? selectedAccountId;
  final List<AiGatewayRouteDecision> decisions;
  final bool requestSucceeded;
  final DateTime recordedAt;

  LlmChatRouteDiagnostic({
    required this.groupId,
    required this.localModelId,
    this.selectedAccountId,
    required Iterable<AiGatewayRouteDecision> decisions,
    this.requestSucceeded = false,
    DateTime? recordedAt,
  })  : decisions = List.unmodifiable(decisions),
        recordedAt = (recordedAt ?? DateTime.now()).toUtc();
}

class LlmChatRouteDiagnostics {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, LlmChatRouteDiagnostic> _latest = {};

  static LlmChatRouteDiagnostic? latestForGroup(String groupId) =>
      _latest[groupId];

  static void record({
    required String groupId,
    required String localModelId,
    String? selectedAccountId,
    required Iterable<AiGatewayRouteDecision> decisions,
    bool requestSucceeded = false,
  }) {
    _latest[groupId] = LlmChatRouteDiagnostic(
      groupId: groupId,
      localModelId: localModelId,
      selectedAccountId: selectedAccountId,
      decisions: decisions,
      requestSucceeded: requestSucceeded,
    );
    revision.value++;
  }
}

String llmRouteDecisionLabel(String reason) => switch (reason) {
      'session_affinity' => '沿用此对话最近成功的账号',
      'session_affinity_persistence_failed' => '本次账号连续性未能保存',
      'explicit_account_selection' => '按用户选择的账号路由',
      'selected_account_outside_group' => '所选账号不属于当前模型组',
      'conversation_id_invalid' => '对话标识无效，未使用会话亲和',
      'model_group_missing' => '没有找到此模型的稳定模型组',
      'model_group_ambiguous' => '此模型同时关联多个模型组',
      'connector_protocol_incompatible' => '连接器协议不适用于此聊天模型',
      'connection_unknown' => '连接状态未知',
      'account_missing' => '账号已删除',
      'account_id_invalid' => '账号标识无效',
      'account_unavailable' => '账号已暂停或需要重新认证',
      'model_mapping_mismatch' => '账号没有映射到所选模型',
      'model_not_mapped' => '账号中找不到对应的上游模型',
      'capability_mismatch' => '账号模型不支持此请求所需能力',
      'fallback_scope' => '回退范围不允许切换到此连接器',
      'cooldown' => '账号仍在故障冷却期',
      'concurrency_limit' => '账号或模型组已达到并发上限',
      'balance_unknown_or_incomparable' => '额度未知或计量单位不可比较',
      'balance_at_or_below_reserve' => '余额已达到或低于保留线',
      'usage_unknown' => '使用量未知，无法判断限制',
      'reserve_balance_unknown' => '剩余额度未知，无法判断保留线',
      'reserve_unit_unknown_or_incomparable' => '保留线计量单位未知或不可比较',
      'reserve_total_unknown_or_incomparable' => '额度总量未知或不可比较',
      'reserve_total_unknown' => '额度总量未知，无法计算保留线',
      'reserve_usage_estimate_unknown' => '请求用量估算未知，无法判断保留线',
      'reserve_in_flight_usage_unknown' => '进行中的请求用量未知，无法判断保留线',
      'reserve_floor_reached' => '剩余额度低于保留线',
      'usage_ceiling_reached' => '已达到使用上限',
      'usage_ceiling_total_unknown' => '使用总额未知，无法判断上限',
      'usage_unit_mismatch' => '使用量计量单位不匹配',
      'usage_source_mismatch' => '使用量与额度数据来源不匹配',
      'usage_in_flight_unknown' => '进行中的请求用量未知，无法判断上限',
      'usage_estimate_unknown' => '请求用量估算未知，无法判断上限',
      'invalid_window_timezone' => '额度窗口时区配置无效',
      'reserve_floor' => '剩余额度低于保留线',
      'usage_ceiling' => '已达到使用上限',
      'request_authentication' => '上游拒绝了认证',
      'request_quotaExhausted' => '上游报告额度耗尽',
      'request_rateLimited' => '上游限流',
      'request_connection' => '连接上游失败',
      'request_server' => '上游服务错误',
      'request_invalidRequest' => '上游拒绝了请求参数',
      'request_cancelled' => '请求已取消',
      'request_other' => '上游请求失败',
      _ => '账号未被选择：$reason',
    };

class _LlmGatewayAccountManagement implements AiGatewayAccountManagement {
  final LlmAccountConnectorService _accounts;

  const _LlmGatewayAccountManagement(this._accounts);

  @override
  Future<List<AiGatewayAccount>> listAccounts() async =>
      (await _accounts.listAccounts()).map(_gatewayAccount).toList();

  @override
  Future<List<AiGatewayModelGroup>> listModelGroups() async =>
      (await _accounts.listModelGroups()).map(_gatewayModelGroup).toList();

  @override
  Future<AiGatewayAccount> saveAccount(
    AiGatewayAccount account, {
    String? secret,
  }) async {
    final existing = (await _accounts.listAccounts())
        .where((item) => item.id == account.id)
        .firstOrNull;
    if (account.authType == 'oauth') {
      final alreadyOAuthForConnector = existing?.authType == 'oauth' &&
          existing?.connectorType == account.connectorType;
      if (!alreadyOAuthForConnector || secret != null) {
        throw const AiGatewayOAuthException();
      }
    }
    final saved = await _accounts.saveAccount(
      _legacyAccount(account, credentialRef: existing?.credentialRef),
      secret: secret,
    );
    return _gatewayAccount(saved);
  }

  Future<AiGatewayAccount> saveAuthorizedOAuthAccount(
    AiGatewayAccount account, {
    required String secret,
  }) async {
    if (account.authType != 'oauth' ||
        secret.isEmpty ||
        !LlmOAuthProviderPolicy.forProvider(account.connectorType).supported) {
      throw const AiGatewayOAuthException();
    }
    final existing = (await _accounts.listAccounts())
        .where((item) => item.id == account.id)
        .firstOrNull;
    final saved = await _accounts.saveAccount(
      _legacyAccount(account, credentialRef: existing?.credentialRef),
      secret: secret,
    );
    return _gatewayAccount(saved);
  }

  @override
  Future<void> deleteAccount(String accountId) =>
      _accounts.deleteAccount(accountId);

  @override
  Future<void> saveModelGroup(AiGatewayModelGroup group) async {
    await _accounts.saveModelGroup(_legacyModelGroup(group));
  }

  @override
  Future<void> deleteModelGroup(String groupId) =>
      _accounts.deleteModelGroup(groupId);

  @override
  Future<void> recordQuotaObservation({
    required String accountId,
    required AiGatewayMetricObservation remainingQuota,
    required Map<String, AiGatewayMetricObservation> quotaSignals,
  }) =>
      _accounts.recordQuotaObservation(
        accountId: accountId,
        remainingQuota: _llmMetricObservation(remainingQuota),
        quotaSignals: {
          for (final entry in quotaSignals.entries)
            entry.key: _llmMetricObservation(entry.value),
        },
      );
}

class _LlmGatewayProviderCatalog implements AiGatewayProviderCatalog {
  @override
  Iterable<AiGatewayProviderDefinition> get providers =>
      LlmConnectorRegistry.all.map(
        (connector) => AiGatewayProviderDefinition(
          id: connector.id,
          displayName: connector.displayName,
          supportedAuthTypes: Set.unmodifiable(connector.authTypes),
          capabilities:
              LlmConnectorRegistry.chatAdapterEndpointType(connector.id) == null
                  ? const {}
                  : const {'chat'},
          supportsChatAdapter:
              LlmConnectorRegistry.chatAdapterEndpointType(connector.id) !=
                  null,
          chatProtocolId: LlmConnectorRegistry.chatAdapterEndpointType(
            connector.id,
          ),
          authTypeLimitations: _oauthLimitations(connector),
        ),
      );

  @override
  AiGatewayProviderDefinition? findProvider(String providerId) {
    final connector = LlmConnectorRegistry.find(providerId);
    if (connector == null) return null;
    final supportsChatAdapter =
        LlmConnectorRegistry.chatAdapterEndpointType(connector.id) != null;
    return AiGatewayProviderDefinition(
      id: connector.id,
      displayName: connector.displayName,
      supportedAuthTypes: Set.unmodifiable(connector.authTypes),
      capabilities: supportsChatAdapter ? const {'chat'} : const {},
      supportsChatAdapter: supportsChatAdapter,
      chatProtocolId: LlmConnectorRegistry.chatAdapterEndpointType(
        connector.id,
      ),
      authTypeLimitations: _oauthLimitations(connector),
    );
  }

  static Map<String, String> _oauthLimitations(
    LlmConnectorDefinition connector,
  ) {
    final policy = LlmOAuthProviderPolicy.forProvider(connector.id);
    return policy.supported ? const {} : {'oauth': policy.reason!};
  }
}

class _LlmGatewayModelDiscovery implements AiGatewayModelDiscovery {
  final LlmAccountConnectorService _accounts;

  const _LlmGatewayModelDiscovery(this._accounts);

  @override
  Future<List<AiGatewayUpstreamModel>> discoverModels(
    AiGatewayAccount account, {
    bool refreshRemote = false,
  }) async =>
      (await _accounts.discoverModels(
        _legacyAccount(account),
        refreshRemote: refreshRemote,
      ))
          .map(_gatewayModel)
          .toList(growable: false);

  @override
  Future<List<AiGatewayUpstreamModel>> discoverGroupModels({
    required String groupId,
    required String localModelId,
    Set<String> requiredCapabilities = const {},
    bool refreshRemote = false,
  }) async {
    final groups = await _accounts.listModelGroups();
    final group = groups.where((item) => item.id == groupId).firstOrNull;
    if (group == null) return const [];
    final accounts = {
      for (final account in await _accounts.listAccounts()) account.id: account,
    };
    final models = <AiGatewayUpstreamModel>[];
    for (final member in group.members.where(
      (item) => (item.localModelId ?? group.id) == localModelId,
    )) {
      final account = accounts[member.accountId];
      if (account == null || account.status != LlmAccountStatus.ready) continue;
      final definition = LlmConnectorRegistry.find(account.connectorType);
      if (definition == null ||
          LlmConnectorRegistry.chatAdapterEndpointType(account.connectorType) ==
              null ||
          !LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            account.connectorType,
            account.authType,
          )) {
        continue;
      }
      final discovered = await _accounts.discoverModels(
        account,
        refreshRemote: refreshRemote,
      );
      final model = discovered
          .where((item) => item.upstreamModelId == member.upstreamModelId)
          .firstOrNull;
      if (model == null ||
          !LlmConnectorRegistry.isConversationalModel(
            model.upstreamModelId,
            model.capabilities,
          ) ||
          !_hasRequiredModelCapabilities(
            model.capabilities,
            requiredCapabilities,
            definition.protocol,
          )) {
        continue;
      }
      models.add(_gatewayModel(model));
    }
    return List.unmodifiable(models);
  }
}

bool _hasRequiredModelCapabilities(
  Map<String, dynamic> capabilities,
  Set<String> required,
  LlmNativeProtocol protocol,
) {
  const streamingProtocols = {
    LlmNativeProtocol.openAIResponses,
    LlmNativeProtocol.anthropicMessages,
    LlmNativeProtocol.geminiGenerateContent,
    LlmNativeProtocol.geminiInteractions,
    LlmNativeProtocol.openAIChatCompletions,
    LlmNativeProtocol.ollamaChat,
    LlmNativeProtocol.kimiChatCompletions,
    LlmNativeProtocol.xaiResponses,
    LlmNativeProtocol.metaResponses,
  };
  for (final capability in required) {
    final explicitlyEnabled = capabilities[capability] == true;
    final explicitlyDisabled =
        capabilities.containsKey(capability) && !explicitlyEnabled;
    final methods = capabilities['supportedGenerationMethods'];
    final chatMethodsExplicitlyUnsupported = capability == 'chat' &&
        methods is Iterable &&
        !methods.contains('generateContent') &&
        !methods.contains('streamGenerateContent');
    final inputModalities = capabilities['inputModalities'];
    final methodSupported = methods is Iterable &&
        switch (capability) {
          'chat' => methods.contains('generateContent') ||
              methods.contains('streamGenerateContent'),
          'streaming' => methods.contains('streamGenerateContent'),
          _ => false,
        };
    final modalitySupported = inputModalities is Iterable &&
        switch (capability) {
          'vision' => inputModalities.contains('image'),
          'audio' => inputModalities.contains('audio'),
          _ => false,
        };
    final protocolObserved = capability == 'chat' &&
            const {
              LlmNativeProtocol.openAIResponses,
              LlmNativeProtocol.anthropicMessages,
              LlmNativeProtocol.geminiGenerateContent,
              LlmNativeProtocol.geminiInteractions,
              LlmNativeProtocol.openAIChatCompletions,
              LlmNativeProtocol.ollamaChat,
              LlmNativeProtocol.kimiChatCompletions,
              LlmNativeProtocol.xaiResponses,
              LlmNativeProtocol.metaResponses,
              LlmNativeProtocol.bedrockConverse,
            }.contains(protocol) ||
        capability == 'streaming' && streamingProtocols.contains(protocol);
    final geminiMethodListOverridesProtocol = !explicitlyEnabled &&
        methods is Iterable &&
        const {
          LlmNativeProtocol.geminiGenerateContent,
          LlmNativeProtocol.geminiInteractions,
        }.contains(protocol) &&
        (capability == 'chat'
            ? !(methods.contains('generateContent') ||
                methods.contains('streamGenerateContent'))
            : capability == 'streaming' &&
                !methods.contains('streamGenerateContent'));
    if (explicitlyDisabled ||
        chatMethodsExplicitlyUnsupported ||
        geminiMethodListOverridesProtocol ||
        !explicitlyEnabled &&
            !methodSupported &&
            !modalitySupported &&
            !protocolObserved) {
      return false;
    }
  }
  return true;
}

class _LlmGatewayExecutor implements AiGatewayExecutor {
  final LlmConnectorHttpClient _client;

  const _LlmGatewayExecutor(this._client);

  @override
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
  }) async {
    try {
      final response = await _client.request(
        account: _legacyAccount(account),
        modelId: modelId,
        body: body,
        stream: stream,
        nativeFormat: nativeFormat,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onRequestSent: onRequestSent,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      );
      return AiGatewayResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        observation: _gatewayObservation(response.observation),
        completedObservation: response.completedObservation?.then(
          _gatewayObservation,
        ),
      );
    } on LlmConnectorHttpException catch (error) {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.request,
        statusCode: error.statusCode,
        code: error.code,
        headers: error.headers,
      );
    } on LlmConnectorRequestCancelled {
      throw AiGatewayExecutionException(kind: AiGatewayFailureKind.cancelled);
    } on LlmConnectorAuthenticationRequired {
      throw AiGatewayExecutionException(
        kind: AiGatewayFailureKind.authenticationRequired,
      );
    }
  }
}

AiGatewayConnectorObservation _gatewayObservation(
  LlmConnectorObservation observation,
) =>
    AiGatewayConnectorObservation(
      requestUsage: _gatewayMetricObservation(observation.requestUsage),
      remainingQuota: _gatewayMetricObservation(observation.remainingQuota),
      quotaSignals: {
        for (final entry in observation.quotaSignals.entries)
          entry.key: _gatewayMetricObservation(entry.value),
      },
    );

AiGatewayMetricObservation _gatewayMetricObservation(
  LlmMetricObservation observation,
) =>
    AiGatewayMetricObservation(
      unit: observation.unit,
      value: observation.value,
      isKnown: observation.isKnown,
      source: observation.source,
      observedAt: observation.observedAt,
      resetAt: observation.resetAt,
    );

LlmMetricObservation _llmMetricObservation(
  AiGatewayMetricObservation observation,
) =>
    observation.isKnown
        ? LlmMetricObservation.reported(
            observation.value,
            unit: observation.unit,
            source: observation.source,
            observedAt: observation.observedAt,
            resetAt: observation.resetAt,
          )
        : const LlmMetricObservation.unknown();

AiGatewayAccount _gatewayAccount(LlmAccount account) => AiGatewayAccount(
      id: account.id,
      connectorType: account.connectorType,
      authType: account.authType,
      displayName: account.displayName,
      status: AiGatewayAccountStatus.values.byName(account.status.name),
      hasCredential: account.credentialRef != null,
      credentialRef: account.credentialRef,
      endpointConfig: account.endpointConfig,
      models: account.models.map(_gatewayModel).toList(growable: false),
      policy: _gatewayPolicy(account.policy),
      usageByWindow: {
        for (final entry in account.usageByWindow.entries)
          AiGatewayUsageWindow.values.byName(
            entry.key.name,
          ): AiGatewayUsageWindowState(
            quota: _gatewayMetricObservation(entry.value.quota),
            used: _gatewayMetricObservation(entry.value.used),
            remaining: _gatewayMetricObservation(entry.value.remaining),
            resetAt: entry.value.resetAt,
            source: entry.value.source,
          ),
      },
      remainingQuota: _gatewayMetricObservation(account.remainingQuota),
      quotaSignals: {
        for (final entry in account.quotaSignals.entries)
          entry.key: _gatewayMetricObservation(entry.value),
      },
    );

LlmAccount _legacyAccount(AiGatewayAccount account, {String? credentialRef}) =>
    LlmAccount(
      id: account.id,
      connectorType: account.connectorType,
      authType: account.authType,
      displayName: account.displayName,
      status: LlmAccountStatus.values.byName(account.status.name),
      credentialRef: credentialRef ?? account.credentialRef,
      endpointConfig: account.endpointConfig,
      models: account.models.map(_legacyModel).toList(growable: false),
      policy: _legacyPolicy(account.policy),
      usageByWindow: {
        for (final entry in account.usageByWindow.entries)
          LlmUsageWindow.values.byName(entry.key.name): LlmUsageWindowState(
            quota: _llmMetricObservation(entry.value.quota),
            used: _llmMetricObservation(entry.value.used),
            remaining: _llmMetricObservation(entry.value.remaining),
            resetAt: entry.value.resetAt,
            source: entry.value.source,
          ),
      },
      remainingQuota: _llmMetricObservation(account.remainingQuota),
      quotaSignals: {
        for (final entry in account.quotaSignals.entries)
          entry.key: _llmMetricObservation(entry.value),
      },
    );

AiGatewayUpstreamModel _gatewayModel(LlmUpstreamModel model) =>
    AiGatewayUpstreamModel(
      id: model.id,
      upstreamModelId: model.upstreamModelId,
      displayName: model.displayName,
      capabilities: model.capabilities,
      config: model.config,
    );

LlmUpstreamModel _legacyModel(AiGatewayUpstreamModel model) => LlmUpstreamModel(
      id: model.id,
      upstreamModelId: model.upstreamModelId,
      displayName: model.displayName,
      capabilities: model.capabilities,
      config: model.config,
    );

AiGatewayModelGroupMember _gatewayMember(LlmModelGroupMember member) =>
    AiGatewayModelGroupMember(
      accountId: member.accountId,
      upstreamModelId: member.upstreamModelId,
      priorityTier: member.priorityTier,
      localModelId: member.localModelId,
    );

LlmModelGroupMember _legacyMember(AiGatewayModelGroupMember member) =>
    LlmModelGroupMember(
      accountId: member.accountId,
      upstreamModelId: member.upstreamModelId,
      priorityTier: member.priorityTier,
      localModelId: member.localModelId,
    );

AiGatewayModelGroup _gatewayModelGroup(LlmModelGroup group) =>
    AiGatewayModelGroup(
      id: group.id,
      displayName: group.displayName,
      members: group.members.map(_gatewayMember).toList(growable: false),
      policy: _gatewayPolicy(group.policy),
      legacyModelId: group.legacyModelId,
      legacyProviderName: group.legacyProviderName,
    );

LlmModelGroup _legacyModelGroup(AiGatewayModelGroup group) => LlmModelGroup(
      id: group.id,
      displayName: group.displayName,
      members: group.members.map(_legacyMember).toList(growable: false),
      policy: _legacyPolicy(group.policy),
      legacyModelId: group.legacyModelId,
      legacyProviderName: group.legacyProviderName,
    );

AiGatewayRoutingPolicy _gatewayPolicy(LlmRoutingPolicy policy) =>
    AiGatewayRoutingPolicy(
      fallbackScope: AiGatewayFallbackScope.values.byName(
        policy.fallbackScope.name,
      ),
      strategy: AiGatewaySelectionStrategy.values.byName(policy.strategy.name),
      windows: {
        for (final entry in policy.windows.entries)
          AiGatewayUsageWindow.values.byName(
            entry.key.name,
          ): AiGatewayWindowPolicy(
            mode: AiGatewayWindowMode.values.byName(entry.value.mode.name),
            timeZone: entry.value.timeZone,
            reserveFloor: _gatewayThreshold(entry.value.reserveFloor),
            usageCeiling: _gatewayThreshold(entry.value.usageCeiling),
          ),
      },
      concurrencyLimit: policy.concurrencyLimit,
    );

LlmRoutingPolicy _legacyPolicy(AiGatewayRoutingPolicy policy) =>
    LlmRoutingPolicy(
      fallbackScope: LlmFallbackScope.values.byName(policy.fallbackScope.name),
      strategy: LlmSelectionStrategy.values.byName(policy.strategy.name),
      windows: {
        for (final entry in policy.windows.entries)
          LlmUsageWindow.values.byName(entry.key.name): LlmWindowPolicy(
            mode: LlmWindowMode.values.byName(entry.value.mode.name),
            timeZone: entry.value.timeZone,
            reserveFloor: _legacyThreshold(entry.value.reserveFloor),
            usageCeiling: _legacyThreshold(entry.value.usageCeiling),
          ),
      },
      concurrencyLimit: policy.concurrencyLimit,
    );

AiGatewayLimitThreshold? _gatewayThreshold(LlmLimitThreshold? threshold) =>
    threshold == null
        ? null
        : threshold.kind == LlmLimitKind.percentage
            ? AiGatewayLimitThreshold.percentage(threshold.value)
            : AiGatewayLimitThreshold.fixed(threshold.value,
                unit: threshold.unit);

LlmLimitThreshold? _legacyThreshold(AiGatewayLimitThreshold? threshold) =>
    threshold == null
        ? null
        : threshold.kind == AiGatewayLimitKind.percentage
            ? LlmLimitThreshold.percentage(threshold.value)
            : LlmLimitThreshold.fixed(threshold.value, unit: threshold.unit);

List<AiGatewayRouteDecision> _gatewayRouteDecisions(
  Iterable<LlmRouteDecision> decisions,
) =>
    decisions
        .map(
          (decision) => AiGatewayRouteDecision(
            subjectId: decision.subjectId,
            reason: decision.reason,
          ),
        )
        .toList(growable: false);

AiGatewayRoutingException _gatewayRoutingFailure(
  LlmRoutingUnavailableException error,
) =>
    AiGatewayRoutingException(_gatewayRouteDecisions(error.decisions));

AiGatewayRouteCandidate _gatewayCandidate(LlmRouteCandidate candidate) =>
    AiGatewayRouteCandidate(
      account: _gatewayAccount(candidate.account),
      member: _gatewayMember(candidate.member),
      localModelId: candidate.localModelId,
      upstreamModelId: candidate.upstreamModelId,
      priorityTier: candidate.priorityTier,
      memberIndex: candidate.memberIndex,
    );

AiGatewayRoutingExecution<T> _gatewayExecution<T>(
  LlmRoutingExecution<T> execution,
) =>
    AiGatewayRoutingExecution(
      value: execution.value,
      candidate: _gatewayCandidate(execution.candidate),
      attemptedAccountIds: execution.attemptedAccountIds,
      decisions: _gatewayRouteDecisions(execution.decisions),
    );

class _GatewayRouteProgressAdapter implements AiGatewayRouteProgress {
  final LlmRouteProgress _progress;

  const _GatewayRouteProgressAdapter(this._progress);

  @override
  bool get requestWasSent => _progress.requestWasSent;

  @override
  bool get visibleOutput => _progress.visibleOutput;

  @override
  bool get toolSideEffect => _progress.toolSideEffect;

  @override
  Future<void> markRequestSent() => _progress.markRequestSent();

  @override
  Future<void> markOutputVisible() => _progress.markOutputVisible();

  @override
  Future<void> markToolSideEffect() => _progress.markToolSideEffect();

  @override
  Future<void> recordUsage({
    required String unit,
    required num value,
    required String source,
  }) =>
      _progress.recordUsage(unit: unit, value: value, source: source);
}

class _SharedPreferencesLlmAccountPreferences implements LlmAccountPreferences {
  final SharedPreferences _preferences;

  const _SharedPreferencesLlmAccountPreferences(this._preferences);

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);
}
