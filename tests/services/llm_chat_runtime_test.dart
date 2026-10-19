import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';

void main() {
  test(
    'platform routing runtime is shared across independent OCR services',
    () async {
      SharedPreferences.setMockInitialValues({});

      final first = await LlmChatRoutingRuntime.sharedPlatform();
      final second = await LlmChatRoutingRuntime.sharedPlatform();

      expect(identical(first, second), isTrue);
    },
  );

  test('labels current M3 reserve and usage-window decisions', () {
    const policyReasons = [
      'usage_unknown',
      'reserve_balance_unknown',
      'reserve_unit_unknown_or_incomparable',
      'reserve_total_unknown_or_incomparable',
      'reserve_total_unknown',
      'reserve_usage_estimate_unknown',
      'reserve_in_flight_usage_unknown',
      'reserve_floor_reached',
      'usage_ceiling_total_unknown',
      'usage_unit_mismatch',
      'usage_source_mismatch',
      'usage_in_flight_unknown',
      'usage_estimate_unknown',
      'usage_ceiling_reached',
      'balance_at_or_below_reserve',
      'invalid_window_timezone',
    ];

    for (final reason in policyReasons) {
      expect(
        llmRouteDecisionLabel(reason),
        isNot(startsWith('账号未被选择：')),
        reason: reason,
      );
    }
    expect(llmRouteDecisionLabel('reserve_floor_reached'), '剩余额度低于保留线');
    expect(llmRouteDecisionLabel('usage_ceiling_reached'), '已达到使用上限');
    expect(llmRouteDecisionLabel('balance_at_or_below_reserve'), '余额已达到或低于保留线');
  });

  group('LlmAccountConnectorService model groups', () {
    test(
      'persists group membership and stable IDs through lifecycle',
      () async {
        final preferences = _MemoryPreferences();
        final service = _accountService(preferences);
        await service.saveAccount(
          _account('account-a', 'local-model-a', 'gpt-4o'),
        );
        final stableId = stableLlmModelGroupId('account-a', 'local-model-a');
        final group = _group(stableId, 'account-a', 'local-model-a');

        await service.saveModelGroup(group);

        final loaded = await service.listModelGroups();
        expect(loaded.single.id, stableId);
        expect(loaded.single.members.single.accountId, 'account-a');
        expect(loaded.single.members.single.localModelId, 'local-model-a');

        await service.deleteModelGroup(group.id);
        expect(await service.listModelGroups(), isEmpty);
        expect((await service.listAccounts()).single.id, 'account-a');
      },
    );

    test(
      'routes generated stable IDs with encoded parts and over 128 chars',
      () async {
        final preferences = _MemoryPreferences();
        final accountService = _accountService(preferences);
        const accountId = 'legacy:account';
        final localModelId = "model/!'()~*${List.filled(100, 'x').join()}";
        final groupId = stableLlmModelGroupId(accountId, localModelId);
        expect(groupId, contains('%3A'));
        expect(groupId, contains('%2F'));
        expect(groupId.length, greaterThan(128));
        await accountService.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: 'Legacy account',
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: localModelId,
                upstreamModelId: 'gpt-stable-id',
                displayName: 'Stable model',
              ),
            ],
          ),
        );
        await accountService.saveModelGroup(
          LlmModelGroup(
            id: groupId,
            displayName: 'Stable group',
            members: [
              LlmModelGroupMember(
                accountId: accountId,
                localModelId: localModelId,
                upstreamModelId: 'gpt-stable-id',
              ),
            ],
          ),
        );
        final runtime = LlmChatRoutingRuntime(
          accountService: accountService,
          routingService: LlmRoutingService(
            accountService: accountService,
            stateStore: LlmRoutingStateStore(preferences: preferences),
            concurrency: LlmConcurrencyReservations(),
          ),
        );

        final result = await runtime.executeForModelReference<String>(
          accountId: accountId,
          localModelId: localModelId,
          request: (candidate, progress) async => candidate.account.id,
        );

        expect(result.value, accountId);
        expect(result.candidate.account.id, accountId);
        expect(result.candidate.member.accountId, accountId);
        expect(result.candidate.localModelId, localModelId);
      },
    );
  });

  test('repeated legacy OCR imports preserve account workflow edits', () async {
    final preferences = _MemoryPreferences();
    final accountService = _accountService(preferences);
    final runtime = LlmChatRoutingRuntime(
      accountService: accountService,
      routingService: LlmRoutingService(
        accountService: accountService,
        stateStore: LlmRoutingStateStore(preferences: preferences),
        concurrency: LlmConcurrencyReservations(),
      ),
    );
    const accountId = 'ocr-legacy-edit';
    const localModelId = 'legacy-vision';
    final groupId = stableLlmModelGroupId(accountId, localModelId);

    await runtime.ensureLegacyOcrModelGroup(
      accountId: accountId,
      groupId: groupId,
      localModelId: localModelId,
      upstreamModelId: 'source-model',
      displayName: 'Legacy OCR model',
      baseUrl: 'https://source.example.test/ocr/complete',
      apiKey: 'source-key',
    );

    final original = (await accountService.getAccount(accountId))!;
    await accountService.saveAccount(
      LlmAccount(
        id: accountId,
        connectorType: original.connectorType,
        authType: original.authType,
        displayName: 'Edited OCR account',
        status: original.status,
        credentialRef: original.credentialRef,
        endpointConfig: {
          ...original.endpointConfig,
          'baseUrl': 'https://edited.example.test/custom/complete',
        },
        models: const [
          LlmUpstreamModel(
            id: localModelId,
            upstreamModelId: 'edited-upstream-model',
            displayName: 'Edited OCR model',
            capabilities: {'vision': true},
          ),
        ],
      ),
      secret: 'edited-key',
    );

    await runtime.ensureLegacyOcrModelGroup(
      accountId: accountId,
      groupId: groupId,
      localModelId: localModelId,
      upstreamModelId: 'source-model',
      displayName: 'Legacy OCR model',
      baseUrl: 'https://source.example.test/ocr/complete',
      apiKey: 'source-key',
    );

    final savedAccount = (await accountService.getAccount(accountId))!;
    final savedGroup = (await accountService.listModelGroups()).single;
    expect(savedAccount.displayName, 'Edited OCR account');
    expect(
      savedAccount.endpointConfig['baseUrl'],
      'https://edited.example.test/custom/complete',
    );
    expect(savedAccount.models.single.upstreamModelId, 'edited-upstream-model');
    expect(savedGroup.members.single.upstreamModelId, 'edited-upstream-model');
    expect(await accountService.readCredential(accountId), 'edited-key');
  });

  test(
    'legacy OCR settings edits refresh an already imported account',
    () async {
      final preferences = _MemoryPreferences();
      final accountService = _accountService(preferences);
      final runtime = LlmChatRoutingRuntime(
        accountService: accountService,
        routingService: LlmRoutingService(
          accountService: accountService,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
      );
      const accountId = 'ocr-legacy-source-edit';
      const localModelId = 'legacy-vision';
      final groupId = stableLlmModelGroupId(accountId, localModelId);

      await runtime.ensureLegacyOcrModelGroup(
        accountId: accountId,
        groupId: groupId,
        localModelId: localModelId,
        upstreamModelId: 'source-model',
        displayName: 'Original OCR model',
        baseUrl: 'https://source.example.test/ocr/complete',
        apiKey: 'source-key',
      );

      await runtime.ensureLegacyOcrModelGroup(
        accountId: accountId,
        groupId: groupId,
        localModelId: localModelId,
        upstreamModelId: 'edited-source-model',
        displayName: 'Edited OCR model',
        baseUrl: 'https://edited-source.example.test/ocr/complete',
        apiKey: 'edited-source-key',
        synchronizeEndpoint: true,
        synchronizeCredential: true,
        synchronizeModel: true,
      );

      final savedAccount = (await accountService.getAccount(accountId))!;
      final savedGroup = (await accountService.listModelGroups()).single;
      expect(
        savedAccount.endpointConfig['baseUrl'],
        'https://edited-source.example.test/ocr/complete',
      );
      expect(savedAccount.authType, 'api_key');
      expect(savedAccount.models.single.upstreamModelId, 'edited-source-model');
      expect(savedGroup.members.single.upstreamModelId, 'edited-source-model');
      expect(
        await accountService.readCredential(accountId),
        'edited-source-key',
      );

      await runtime.ensureLegacyOcrModelGroup(
        accountId: accountId,
        groupId: groupId,
        localModelId: localModelId,
        upstreamModelId: 'edited-source-model',
        displayName: 'Edited OCR model',
        baseUrl: 'https://edited-source.example.test/ocr/complete',
        apiKey: '',
        synchronizeCredential: true,
      );
      final noAuthAccount = (await accountService.getAccount(accountId))!;
      expect(noAuthAccount.authType, 'none');
      expect(noAuthAccount.credentialRef, isNull);
      expect(await accountService.readCredential(accountId), isNull);
    },
  );

  test(
    'concurrent legacy OCR imports merge all model and group records',
    () async {
      final preferences = _MemoryPreferences();
      final accountService = _accountService(preferences);
      final runtime = LlmChatRoutingRuntime(
        accountService: accountService,
        routingService: LlmRoutingService(
          accountService: accountService,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
      );
      const accountId = 'ocr-concurrent-source';
      const modelIds = ['vision-a', 'vision-b', 'vision-c'];

      await Future.wait([
        for (final localModelId in modelIds)
          runtime.ensureLegacyOcrModelGroup(
            accountId: accountId,
            groupId: stableLlmModelGroupId(accountId, localModelId),
            localModelId: localModelId,
            upstreamModelId: '$localModelId-upstream',
            displayName: localModelId,
            baseUrl: 'https://source.example.test/ocr/complete',
            apiKey: 'source-key',
          ),
      ]);

      final account = (await accountService.getAccount(accountId))!;
      final groups = await accountService.listModelGroups();
      expect(
        account.models.map((model) => model.id).toSet(),
        containsAll(modelIds),
      );
      expect(groups.map((group) => group.id).toSet(), {
        for (final localModelId in modelIds)
          stableLlmModelGroupId(accountId, localModelId),
      });
      for (final group in groups) {
        expect(
          account.models.any(
            (model) =>
                model.upstreamModelId == group.members.single.upstreamModelId,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'routes an exact account/model reference through its stable group',
    () async {
      final preferences = _MemoryPreferences();
      final accountService = _accountService(preferences);
      await accountService.saveAccount(
        _account('account-a', 'local-model-a', 'gpt-4o'),
      );
      await accountService.saveAccount(
        _account('account-b', 'local-model-a', 'other-model'),
      );
      await accountService.saveModelGroup(
        _group('unrelated-group', 'account-b', 'local-model-a', 'other-model'),
      );
      await accountService.saveModelGroup(
        _group('selected-group', 'account-a', 'local-model-a'),
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accountService,
        routingService: LlmRoutingService(
          accountService: accountService,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
      );

      final result = await runtime.executeForModelReference<String>(
        accountId: 'account-a',
        localModelId: 'local-model-a',
        request: (candidate, progress) async => candidate.account.id,
      );

      expect(result.candidate.account.id, 'account-a');
      expect(result.candidate.localModelId, 'local-model-a');
      expect(result.value, 'account-a');
    },
  );

  test(
    'supplies one known request for account request-count policies',
    () async {
      final preferences = _MemoryPreferences();
      final accountService = _accountService(preferences);
      final now = DateTime.now().toUtc();
      final observed = LlmMetricObservation.reported(
        0,
        unit: 'requests',
        source: 'provider',
        observedAt: now,
      );
      final account = LlmAccount(
        id: 'request-limited-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Request-limited account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'local-model-a',
            upstreamModelId: 'gpt-4o',
            displayName: 'GPT-4o',
          ),
        ],
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(1, unit: 'requests'),
              usageCeiling: LlmLimitThreshold.fixed(2, unit: 'requests'),
            ),
          },
        ),
        usageByWindow: {
          LlmUsageWindow.day: LlmUsageWindowState(
            quota: LlmMetricObservation.reported(
              10,
              unit: 'requests',
              source: 'provider',
              observedAt: now,
            ),
            used: observed,
            remaining: LlmMetricObservation.reported(
              10,
              unit: 'requests',
              source: 'provider',
              observedAt: now,
            ),
            resetAt: now.add(const Duration(days: 1)),
            source: 'provider',
          ),
        },
      );
      await accountService.saveAccount(account);
      await accountService.saveModelGroup(
        _group('request-limited-group', account.id, 'local-model-a'),
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accountService,
        routingService: LlmRoutingService(
          accountService: accountService,
          stateStore: LlmRoutingStateStore(
            preferences: preferences,
            clock: () => now,
          ),
          concurrency: LlmConcurrencyReservations(),
          clock: () => now,
        ),
      );

      final result = await runtime.executeForGroupId<String>(
        groupId: 'request-limited-group',
        localModelId: 'local-model-a',
        request: (candidate, progress) async => candidate.account.id,
      );

      expect(result.value, account.id);
      expect(result.candidate.account.id, account.id);
    },
  );

  test(
    'records the selected account and request reason for terminal errors',
    () async {
      final preferences = _MemoryPreferences();
      final accountService = _accountService(preferences);
      await accountService.saveAccount(
        _account('account-a', 'local-model-a', 'gpt-4o'),
      );
      await accountService.saveModelGroup(
        _group('selected-group', 'account-a', 'local-model-a'),
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accountService,
        routingService: LlmRoutingService(
          accountService: accountService,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
      );

      await expectLater(
        runtime.executeForGroupId<void>(
          groupId: 'selected-group',
          localModelId: 'local-model-a',
          request: (candidate, progress) async {
            await progress.markRequestSent();
            throw const LlmRouteRequestException(statusCode: 400);
          },
        ),
        throwsA(isA<LlmRouteRequestException>()),
      );

      final diagnostic = LlmChatRouteDiagnostics.latestForGroup(
        'selected-group',
      );
      expect(diagnostic?.selectedAccountId, 'account-a');
      expect(diagnostic?.decisions.single.reason, 'request_invalidRequest');
    },
  );
}

LlmAccountConnectorService _accountService(_MemoryPreferences preferences) =>
    LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );

LlmAccount _account(String id, String localModelId, String upstreamModelId) =>
    LlmAccount(
      id: id,
      connectorType: 'openai-compatibility',
      authType: 'none',
      displayName: id,
      status: LlmAccountStatus.ready,
      endpointConfig: {'baseUrl': 'https://api.example.test/v1'},
      models: [
        LlmUpstreamModel(
          id: localModelId,
          upstreamModelId: upstreamModelId,
          displayName: upstreamModelId,
          capabilities: const {'streaming': true},
        ),
      ],
    );

LlmModelGroup _group(
  String id,
  String accountId,
  String localModelId, [
  String upstreamModelId = 'gpt-4o',
]) => LlmModelGroup(
  id: id,
  displayName: id,
  members: [
    LlmModelGroupMember(
      accountId: accountId,
      localModelId: localModelId,
      upstreamModelId: upstreamModelId,
    ),
  ],
);

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _MemoryCredentialStore implements LlmCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String value) async {
    values[reference] = value;
  }
}
