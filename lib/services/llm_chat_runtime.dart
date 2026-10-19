import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm_account.dart';
import 'llm_account_migration_service.dart';
import 'llm_connector_service.dart';
import 'llm_connector_http_client.dart';
import 'llm_credential_store.dart';
import 'llm_routing_service.dart';

/// Reproduces M1's stable identity for a legacy account/model reference.
String stableLlmModelGroupId(String accountId, String localModelId) {
  final encodedAccountId = Uri.encodeComponent(accountId);
  final encodedLocalModelId = Uri.encodeComponent(localModelId);
  return 'stroom.model-group.${encodedAccountId.length}:$encodedAccountId'
      '${encodedLocalModelId.length}:$encodedLocalModelId';
}

/// Shared account/model-group boundary used by ChatAdapter and direct LLM
/// callers. UI code may use the same account service for configuration, while
/// routing stays in [LlmRoutingService].
class LlmChatRoutingRuntime {
  static Future<LlmChatRoutingRuntime>? _sharedPlatformRuntime;

  final LlmAccountConnectorService accountService;
  final LlmRoutingService routingService;
  final LlmConnectorHttpClient connectorClient;

  LlmChatRoutingRuntime({
    required this.accountService,
    required this.routingService,
    LlmConnectorHttpClient? connectorClient,
  }) : connectorClient =
           connectorClient ??
           LlmConnectorHttpClient(accountService: accountService);

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
  static Future<LlmChatRoutingRuntime> sharedPlatform() =>
      _sharedPlatformRuntime ??= createPlatform();

  Future<LlmModelGroup> resolveGroupForModelReference({
    required String accountId,
    required String localModelId,
  }) async {
    final groups = await accountService.listModelGroups();
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
    throw LlmRoutingUnavailableException([
      LlmRouteDecision(
        subjectId: accountId,
        reason: matchingGroups.isEmpty
            ? 'model_group_missing'
            : 'model_group_ambiguous',
      ),
    ]);
  }

  Future<LlmRoutingExecution<T>> executeForModelReference<T>({
    required String accountId,
    required String localModelId,
    required Future<T> Function(
      LlmRouteCandidate candidate,
      LlmRouteProgress progress,
    )
    request,
    Set<String> requiredCapabilities = const {},
    Map<String, num> estimatedUsage = const {},
    Set<String>? supportedConnectorTypes,
  }) async {
    final stableId = stableLlmModelGroupId(accountId, localModelId);
    final LlmModelGroup group;
    try {
      group = await resolveGroupForModelReference(
        accountId: accountId,
        localModelId: localModelId,
      );
    } on LlmRoutingUnavailableException catch (error) {
      LlmChatRouteDiagnostics.record(
        groupId: stableId,
        localModelId: localModelId,
        decisions: error.decisions,
      );
      rethrow;
    }
    return _executeGroup(
      group: group,
      localModelId: localModelId,
      request: request,
      requiredCapabilities: requiredCapabilities,
      estimatedUsage: estimatedUsage,
      supportedConnectorTypes: supportedConnectorTypes,
    );
  }

  /// Executes through one exact saved group identity. Used for selector and
  /// Task Flow references whose config ID is already the stable group ID.
  Future<LlmRoutingExecution<T>> executeForGroupId<T>({
    required String groupId,
    required String localModelId,
    required Future<T> Function(
      LlmRouteCandidate candidate,
      LlmRouteProgress progress,
    )
    request,
    Set<String> requiredCapabilities = const {},
    Map<String, num> estimatedUsage = const {},
    Set<String>? supportedConnectorTypes,
  }) async {
    final matching = (await accountService.listModelGroups())
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
        decisions: decisions,
      );
      throw LlmRoutingUnavailableException(decisions);
    }
    return _executeGroup(
      group: matching.single,
      localModelId: localModelId,
      request: request,
      requiredCapabilities: requiredCapabilities,
      estimatedUsage: estimatedUsage,
      supportedConnectorTypes: supportedConnectorTypes,
    );
  }

  /// Upgrades a selected legacy OCR provider model into a secure account and
  /// exact stable group before its first routed request. The generated account
  /// ID is namespaced by [llmOcrAccountIdForConfig] so it cannot collide with
  /// an ordinary account that happens to reuse the provider config ID.
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
      throw LlmRoutingUnavailableException([
        LlmRouteDecision(subjectId: groupId, reason: 'model_group_missing'),
      ]);
    }
    final sourceConfigId = accountId.substring(4);
    await accountService.ensureLegacyOcrModelGroup(
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
  }

  Future<LlmRoutingExecution<T>> _executeGroup<T>({
    required LlmModelGroup group,
    required String localModelId,
    required Future<T> Function(
      LlmRouteCandidate candidate,
      LlmRouteProgress progress,
    )
    request,
    required Set<String> requiredCapabilities,
    required Map<String, num> estimatedUsage,
    required Set<String>? supportedConnectorTypes,
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
      if (supportedConnectorTypes != null) {
        final accounts = {
          for (final account in await accountService.listAccounts())
            account.id: account,
        };
        final eligibleMembers = <LlmModelGroupMember>[];
        for (final member in group.members) {
          final account = accounts[member.accountId];
          final connectorType = account == null
              ? null
              : LlmConnectorRegistry.canonicalId(account.connectorType);
          if (connectorType != null &&
              !supportedConnectorTypes.contains(connectorType)) {
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

      final execution = await routingService.execute<T>(
        group: routeGroup,
        requestedModelId: localModelId,
        request: (candidate, progress) async {
          lastAttemptedCandidate = candidate;
          try {
            return await request(candidate, progress);
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
        decisions: result.decisions,
      );
      return result;
    } on LlmRoutingUnavailableException catch (error) {
      final decisions = [...excluded, ...error.decisions];
      LlmChatRouteDiagnostics.record(
        groupId: group.id,
        localModelId: localModelId,
        decisions: decisions,
      );
      throw LlmRoutingUnavailableException(decisions);
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
        decisions: decisions,
      );
      rethrow;
    }
  }
}

class LlmChatRouteDiagnostic {
  final String groupId;
  final String localModelId;
  final String? selectedAccountId;
  final List<LlmRouteDecision> decisions;
  final DateTime recordedAt;

  LlmChatRouteDiagnostic({
    required this.groupId,
    required this.localModelId,
    this.selectedAccountId,
    required Iterable<LlmRouteDecision> decisions,
    DateTime? recordedAt,
  }) : decisions = List.unmodifiable(decisions),
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
    required Iterable<LlmRouteDecision> decisions,
  }) {
    _latest[groupId] = LlmChatRouteDiagnostic(
      groupId: groupId,
      localModelId: localModelId,
      selectedAccountId: selectedAccountId,
      decisions: decisions,
    );
    revision.value++;
  }
}

String llmRouteDecisionLabel(String reason) => switch (reason) {
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
