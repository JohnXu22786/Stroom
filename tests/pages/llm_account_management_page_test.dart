import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/pages/llm_account_management_page.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/services/llm_routing_service.dart';

void main() {
  testWidgets('shows unknown quota and connection readiness as unknown', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'local-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Local endpoint',
        status: LlmAccountStatus.unknown,
        endpointConfig: {'baseUrl': 'https://example.test/v1'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local endpoint'), findsOneWidget);
    expect(find.text('连接状态未知'), findsOneWidget);
    expect(find.text('额度未知'), findsOneWidget);
  });

  testWidgets('shows connector remaining quota and named quota signals', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'reported-quota-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Reported quota account',
        status: LlmAccountStatus.ready,
      ),
    );
    final accountsEnvelope =
        jsonDecode(
              preferences.values[LlmAccountMigrationService
                  .accountsPreferenceKey]!,
            )
            as Map;
    final accountRecord = Map<String, dynamic>.from(
      (accountsEnvelope['items'] as List).single as Map,
    );
    accountRecord['remainingQuota'] = {
      'state': 'reported',
      'value': 250,
      'unit': 'credits',
      'source': 'test.connector',
      'observedAt': DateTime.utc(2026, 10, 18).toIso8601String(),
    };
    accountRecord['quotaSignals'] = {
      'dailyRemainingPercent': {
        'state': 'reported',
        'value': 75,
        'unit': 'percent',
        'source': 'test.daily',
        'observedAt': DateTime.utc(2026, 10, 18).toIso8601String(),
      },
    };
    accountsEnvelope['items'] = [accountRecord];
    preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
        jsonEncode(accountsEnvelope);

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('剩余额度：250 credits'), findsOneWidget);
    expect(find.text('每日额度剩余：75 percent'), findsOneWidget);
    expect(find.text('额度未知'), findsNothing);
  });

  testWidgets('saves an account with no authentication and no secret', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加账号'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Local endpoint');
    await tester.enterText(
      find.byType(TextField).at(1),
      'https://example.test/v1',
    );
    await tester.enterText(find.byType(TextField).at(3), 'local-model,vision');
    final authDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(authDropdown);
    await tester.tap(authDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('无认证').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final account = (await service.listAccounts()).single;
    expect(account.displayName, 'Local endpoint');
    expect(account.authType, 'none');
    expect(account.credentialRef, isNull);
  });

  testWidgets('account edits preserve unknown model capability metadata', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    const capabilities = <String, dynamic>{
      'streaming': true,
      'vendorMode': 'unknown',
      'metadata': {'source': 'legacy-import'},
    };
    await service.saveAccount(
      LlmAccount(
        id: 'unknown-capability-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Unknown capability account',
        models: [
          LlmUpstreamModel(
            id: 'unknown-capability-model',
            upstreamModelId: 'unknown-capability-model',
            displayName: 'Unknown capability model',
            capabilities: capabilities,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑账号'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'Renamed capability account',
    );
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    final saved = (await service.listAccounts()).single;
    expect(saved.displayName, 'Renamed capability account');
    expect(saved.models.single.capabilities, capabilities);
  });

  testWidgets(
    'editing an anchor upstream model preserves its stable group mapping',
    (tester) async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentialStore(),
      );
      const accountId = 'edited-anchor';
      const localModelId = 'stable-local-model';
      final groupId = stableLlmModelGroupId(accountId, localModelId);
      await service.saveAccount(
        LlmAccount(
          id: accountId,
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Edited anchor',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: localModelId,
              upstreamModelId: 'old-upstream-model',
              displayName: 'Original model',
              capabilities: {'streaming': true},
            ),
          ],
        ),
      );
      await service.saveModelGroup(
        LlmModelGroup(
          id: groupId,
          displayName: 'Stable model',
          legacyModelId: 'old-upstream-model',
          legacyProviderName: 'Edited anchor',
          members: const [
            LlmModelGroupMember(
              accountId: accountId,
              localModelId: localModelId,
              upstreamModelId: 'old-upstream-model',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑账号'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(3),
        'new-upstream-model,streaming',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final savedAccount = (await service.listAccounts()).single;
      final savedGroup = (await service.listModelGroups()).single;
      expect(savedAccount.models.single.id, localModelId);
      expect(savedAccount.models.single.upstreamModelId, 'new-upstream-model');
      expect(savedGroup.id, groupId);
      expect(savedGroup.members.single.localModelId, localModelId);
      expect(savedGroup.members.single.upstreamModelId, 'new-upstream-model');
      final selectorConfig = buildLlmModelGroupProviderConfigs(
        accounts: [savedAccount],
        groups: [savedGroup],
      ).single;
      expect(selectorConfig.id, groupId);
      expect(selectorConfig.models.single.id, localModelId);
      expect(selectorConfig.models.single.modelId, 'old-upstream-model');
    },
  );

  testWidgets(
    'replacing a deleted stable-group anchor keeps its encoded local model ID',
    (tester) async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentialStore(),
      );
      const localModelId = 'legacy-local-model';
      final groupId = stableLlmModelGroupId(
        'deleted-anchor-account',
        localModelId,
      );
      await service.saveAccount(
        LlmAccount(
          id: 'replacement-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Replacement account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'replacement-model-record',
              upstreamModelId: 'replacement-upstream-model',
              displayName: 'Replacement model',
            ),
          ],
        ),
      );
      await service.saveModelGroup(
        LlmModelGroup(
          id: groupId,
          displayName: 'Retained stable group',
          legacyModelId: 'legacy-upstream-model',
          legacyProviderName: 'Deleted account',
          members: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('模型组'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑模型组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加成员'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加').last);
      await tester.pumpAndSettle();
      final replacementAlias = find.byKey(
        const ValueKey('local_alias_replacement-account_0'),
      );
      expect(tester.widget<TextFormField>(replacementAlias).enabled, isFalse);
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final savedGroup = (await service.listModelGroups()).single;
      expect(savedGroup.id, groupId);
      expect(savedGroup.members.single.accountId, 'replacement-account');
      expect(savedGroup.members.single.localModelId, localModelId);
    },
  );

  testWidgets(
    'editing an imported OCR endpoint switches back to base URL behavior',
    (tester) async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentialStore(),
      );
      await service.saveAccount(
        LlmAccount(
          id: 'legacy-ocr-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Legacy OCR',
          status: LlmAccountStatus.ready,
          endpointConfig: const {
            'baseUrl': 'https://legacy.example.test/ocr/custom?region=west',
            'legacyOcrProviderConfigId': 'legacy-ocr-source',
            'legacyOcrFullEndpoint': true,
          },
          models: const [
            LlmUpstreamModel(
              id: 'legacy-ocr-model',
              upstreamModelId: 'vision-model',
              displayName: 'Vision model',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑账号'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://edited.example.test/v1',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final savedAccount = (await service.listAccounts()).single;
      expect(
        savedAccount.endpointConfig.containsKey('legacyOcrFullEndpoint'),
        isFalse,
      );
      final request = LlmNativeRequestBuilder().build(
        account: savedAccount,
        credential: null,
        modelId: 'vision-model',
        body: const {'model': 'vision-model', 'messages': []},
      );
      expect(
        request.uri.toString(),
        'https://edited.example.test/v1/chat/completions',
      );
    },
  );

  testWidgets('clearing an account endpoint removes stale endpoint aliases', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'cleared-endpoint-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Endpoint account',
        status: LlmAccountStatus.ready,
        endpointConfig: const {
          'baseUrl': 'https://old.example.test/v1',
          'host': 'https://old-host.example.test/v1',
          'apiBase': 'https://stale.example.test/v1',
        },
        models: const [
          LlmUpstreamModel(
            id: 'cleared-endpoint-model',
            upstreamModelId: 'clear-endpoint-model',
            displayName: 'Clear endpoint model',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑账号'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    final saved = (await service.listAccounts()).single;
    expect(saved.endpointConfig, isNot(contains('baseUrl')));
    expect(saved.endpointConfig, isNot(contains('host')));
    expect(saved.endpointConfig, isNot(contains('apiBase')));
  });

  testWidgets(
    'account policy hides group-only strategy and fallback controls',
    (tester) async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentialStore(),
      );
      await service.saveAccount(
        LlmAccount(
          id: 'policy-editor-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Policy account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'policy-editor-model',
              upstreamModelId: 'policy-model',
              displayName: 'Policy model',
            ),
          ],
        ),
      );
      await service.saveModelGroup(
        LlmModelGroup(
          id: 'policy-editor-group',
          displayName: 'Policy group',
          members: const [
            LlmModelGroupMember(
              accountId: 'policy-editor-account',
              localModelId: 'policy-model',
              upstreamModelId: 'policy-model',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('额度与并发策略'));
      await tester.pumpAndSettle();

      expect(find.text('并发上限'), findsOneWidget);
      expect(find.text('同优先级选择'), findsNothing);
      expect(find.text('跨账号回退范围'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模型组'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('额度与回退策略'));
      await tester.pumpAndSettle();

      expect(find.text('同优先级选择'), findsOneWidget);
      expect(find.text('跨账号回退范围'), findsOneWidget);
    },
  );

  testWidgets('changing a member priority preserves its edited local ID', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    final account = LlmAccount(
      id: 'priority-account',
      connectorType: 'openai-compatibility',
      authType: 'none',
      displayName: 'Priority account',
      status: LlmAccountStatus.ready,
      models: const [
        LlmUpstreamModel(
          id: 'priority-upstream-model',
          upstreamModelId: 'gpt-priority',
          displayName: 'Priority model',
        ),
      ],
    );
    await service.saveAccount(account);
    await service.saveModelGroup(
      LlmModelGroup(
        id: 'custom-priority-group',
        displayName: 'Priority group',
        members: const [
          LlmModelGroupMember(
            accountId: 'priority-account',
            localModelId: 'original-local-model',
            upstreamModelId: 'gpt-priority',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑模型组'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'edited-local-model',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('层级 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    final saved = (await service.listModelGroups()).single;
    expect(saved.members.single.localModelId, 'edited-local-model');
    expect(saved.members.single.priorityTier, 1);
  });

  testWidgets('member selection follows the first duplicate upstream model', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'duplicate-upstream-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Duplicate upstream account',
        models: const [
          LlmUpstreamModel(
            id: 'duplicate-record-a',
            upstreamModelId: 'same-upstream-model',
            displayName: 'Model record A',
            capabilities: {'vision': false},
          ),
          LlmUpstreamModel(
            id: 'duplicate-record-b',
            upstreamModelId: 'same-upstream-model',
            displayName: 'Model record B',
            capabilities: {'vision': true},
          ),
        ],
      ),
    );
    await service.saveModelGroup(
      LlmModelGroup(
        id: 'duplicate-upstream-group',
        displayName: 'Duplicate upstream group',
        members: const [
          LlmModelGroupMember(
            accountId: 'duplicate-upstream-account',
            localModelId: 'duplicate-local-model',
            upstreamModelId: 'same-upstream-model',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final modelDropdown = find.byType(DropdownButtonFormField<String>).last;
    final modelButton = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: modelDropdown,
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(modelButton.items?.map((item) => item.value).toList(), [
      'duplicate-record-a',
    ]);
    await tester.tap(modelDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Model record A'), findsWidgets);
    expect(find.text('Model record B'), findsNothing);
    await tester.tap(find.text('Model record A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    final saved = (await service.listModelGroups()).single;
    expect(saved.members.last.upstreamModelId, 'same-upstream-model');
    final selectorConfig = buildLlmModelGroupProviderConfigs(
      accounts: await service.listAccounts(),
      groups: [saved],
    ).single;
    final capabilityMetadata =
        selectorConfig
                .models
                .single
                .legacyFields[kLlmModelCapabilitiesConfigField]
            as Map;
    expect(capabilityMetadata['vision'], isFalse);
  });

  testWidgets('explains and blocks mixed-protocol group members', (
    tester,
  ) async {
    final credentials = _MemoryCredentialStore();
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: credentials,
    );
    await service.saveAccount(
      LlmAccount(
        id: 'claude-anchor',
        connectorType: 'claude',
        authType: 'api_key',
        displayName: 'Claude anchor',
        models: const [
          LlmUpstreamModel(
            id: 'claude-model-record',
            upstreamModelId: 'claude-sonnet',
            displayName: 'Claude model',
          ),
        ],
      ),
      secret: 'claude-key',
    );
    await service.saveAccount(
      LlmAccount(
        id: 'openai-fallback',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'OpenAI fallback',
        models: const [
          LlmUpstreamModel(
            id: 'openai-model-record',
            upstreamModelId: 'gpt-model',
            displayName: 'OpenAI model',
          ),
        ],
      ),
    );
    await service.saveModelGroup(
      LlmModelGroup(
        id: stableLlmModelGroupId('claude-anchor', 'local-model'),
        displayName: 'Chat model',
        members: const [
          LlmModelGroupMember(
            accountId: 'claude-anchor',
            localModelId: 'local-model',
            upstreamModelId: 'claude-sonnet',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI fallback').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加').last);
    await tester.pumpAndSettle();

    expect(find.text('同一模型引用下的组成员必须使用相同聊天协议。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('local alias edits immediately update protocol validation', (
    tester,
  ) async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'claude-member',
        connectorType: 'claude',
        authType: 'api_key',
        displayName: 'Claude member',
        models: const [
          LlmUpstreamModel(
            id: 'claude-record',
            upstreamModelId: 'claude-model',
            displayName: 'Claude model',
          ),
        ],
      ),
      secret: 'claude-key',
    );
    await service.saveAccount(
      LlmAccount(
        id: 'openai-member',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'OpenAI member',
        models: const [
          LlmUpstreamModel(
            id: 'openai-record',
            upstreamModelId: 'openai-model',
            displayName: 'OpenAI model',
          ),
        ],
      ),
    );
    await service.saveModelGroup(
      LlmModelGroup(
        id: 'alias-protocol-group',
        displayName: 'Alias protocol group',
        members: const [
          LlmModelGroupMember(
            accountId: 'claude-member',
            localModelId: 'claude-alias',
            upstreamModelId: 'claude-model',
          ),
          LlmModelGroupMember(
            accountId: 'openai-member',
            localModelId: 'openai-alias',
            upstreamModelId: 'openai-model',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('模型组'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑模型组'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('local_alias_openai-member_1')),
      'claude-alias',
    );
    await tester.pumpAndSettle();

    expect(find.text('同一模型引用下的组成员必须使用相同聊天协议。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存').last)
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'discloses native connectors that are absent from chat selectors',
    (tester) async {
      final credentials = _MemoryCredentialStore();
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
      );
      await service.saveAccount(
        LlmAccount(
          id: 'codex-account',
          connectorType: 'codex',
          authType: 'api_key',
          displayName: 'Codex account',
          status: LlmAccountStatus.ready,
          credentialRef: null,
          models: const [
            LlmUpstreamModel(
              id: 'codex-model',
              upstreamModelId: 'gpt-5-codex',
              displayName: 'GPT 5 Codex',
            ),
          ],
        ),
        secret: 'codex-key',
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Codex account'), findsOneWidget);
      expect(find.text('ChatAdapter 暂不支持此连接器。'), findsOneWidget);
      expect(find.text('该账号的模型组不会出现在聊天与 Task Flow 模型选择器中。'), findsOneWidget);
    },
  );

  testWidgets('shows measured usage recorded by the routing state store', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'usage-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Usage account',
      ),
    );
    final stateStore = LlmRoutingStateStore(preferences: preferences);
    await stateStore.recordUsage(
      LlmUsageEvent(
        accountId: 'usage-account',
        groupId: 'usage-group',
        occurredAt: DateTime.now().toUtc(),
        measurements: const [
          LlmUsageMeasurement(unit: 'requests', value: 1, source: 'local'),
          LlmUsageMeasurement(unit: 'tokens', value: 14, source: 'provider'),
          LlmUsageMeasurement(unit: 'usd', value: 0.03, source: 'provider'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地观测用量'), findsOneWidget);
    expect(find.text('请求：1'), findsOneWidget);
    expect(find.text('tokens：14'), findsOneWidget);
    expect(find.text('USD：0.03'), findsOneWidget);
  });

  testWidgets(
    'keeps accounts and groups visible when local usage state is malformed',
    (tester) async {
      final preferences = _MemoryPreferences();
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await service.saveAccount(
        LlmAccount(
          id: 'usage-state-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Usage state account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'usage-state-model',
              upstreamModelId: 'gpt-usage-state',
              displayName: 'Usage state model',
            ),
          ],
        ),
      );
      await service.saveModelGroup(
        LlmModelGroup(
          id: 'usage-state-group',
          displayName: 'Usage state group',
          members: const [
            LlmModelGroupMember(
              accountId: 'usage-state-account',
              localModelId: 'usage-state-model',
              upstreamModelId: 'gpt-usage-state',
            ),
          ],
        ),
      );
      preferences.values[LlmRoutingStateStore.preferenceKey] = '{malformed';

      await tester.pumpWidget(
        MaterialApp(home: LlmAccountManagementPage(accountService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Usage state account'), findsOneWidget);
      expect(find.text('本地观测用量未知（路由记录无法读取）'), findsOneWidget);

      await tester.tap(find.text('模型组').first);
      await tester.pumpAndSettle();

      expect(find.text('Usage state group'), findsOneWidget);
      expect(find.text('模型组本地累计用量：未知（路由记录无法读取）'), findsOneWidget);
    },
  );

  testWidgets('shows account and group policy thresholds on their cards', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'group-usage-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Group usage account',
        status: LlmAccountStatus.ready,
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.fiveHour: LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(5, unit: 'USD'),
              usageCeiling: LlmLimitThreshold.fixed(50, unit: 'USD'),
            ),
            LlmUsageWindow.month: LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.percentage(10),
              usageCeiling: LlmLimitThreshold.percentage(80),
            ),
          },
        ),
        models: const [
          LlmUpstreamModel(
            id: 'group-usage-model',
            upstreamModelId: 'vision-model',
            displayName: 'Vision model',
          ),
        ],
      ),
    );
    await service.saveModelGroup(
      LlmModelGroup(
        id: 'group-usage',
        displayName: 'Group usage',
        members: const [
          LlmModelGroupMember(
            accountId: 'group-usage-account',
            localModelId: 'group-local-model',
            upstreamModelId: 'vision-model',
          ),
        ],
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(20, unit: 'tokens'),
              usageCeiling: LlmLimitThreshold.fixed(100, unit: 'tokens'),
            ),
            LlmUsageWindow.week: LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.percentage(15),
              usageCeiling: LlmLimitThreshold.percentage(90),
            ),
          },
        ),
      ),
    );
    await LlmRoutingStateStore(preferences: preferences).recordUsage(
      LlmUsageEvent(
        accountId: 'group-usage-account',
        groupId: 'group-usage',
        occurredAt: DateTime.now().toUtc(),
        measurements: const [
          LlmUsageMeasurement(unit: 'requests', value: 1, source: 'local'),
          LlmUsageMeasurement(unit: 'tokens', value: 14, source: 'provider'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('5 小时窗口剩余额度保留线：5 USD'),
      findsOneWidget,
      reason: 'account-card policy floors must be visible',
    );
    expect(find.text('5 小时窗口使用上限：50 USD'), findsOneWidget);
    expect(find.text('月窗口剩余额度保留线：10%'), findsOneWidget);
    expect(find.text('月窗口使用上限：80%'), findsOneWidget);
    await tester.tap(find.text('模型组'));
    await tester.pumpAndSettle();

    expect(find.text('模型组本地累计用量：请求 1 · tokens 14'), findsOneWidget);
    expect(find.text('日窗口剩余额度保留线：20 tokens'), findsOneWidget);
    expect(find.text('日窗口使用上限：100 tokens'), findsOneWidget);
    expect(find.text('周窗口剩余额度保留线：15%'), findsOneWidget);
    expect(find.text('周窗口使用上限：90%'), findsOneWidget);
  });

  testWidgets('refreshes displayed usage when routing diagnostics change', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await service.saveAccount(
      LlmAccount(
        id: 'usage-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Usage account',
      ),
    );
    final stateStore = LlmRoutingStateStore(preferences: preferences);

    await tester.pumpWidget(
      MaterialApp(home: LlmAccountManagementPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无本地记录（最近 62 天）'), findsOneWidget);

    await stateStore.recordUsage(
      LlmUsageEvent(
        accountId: 'usage-account',
        groupId: 'usage-group',
        occurredAt: DateTime.now().toUtc(),
        measurements: const [
          LlmUsageMeasurement(unit: 'requests', value: 1, source: 'local'),
          LlmUsageMeasurement(unit: 'tokens', value: 8, source: 'provider'),
        ],
      ),
    );
    LlmChatRouteDiagnostics.record(
      groupId: 'usage-group',
      localModelId: 'usage-model',
      decisions: const [],
    );
    await tester.pumpAndSettle();

    expect(find.text('tokens：8'), findsOneWidget);
    expect(find.text('暂无本地记录（最近 62 天）'), findsNothing);
  });
}

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
