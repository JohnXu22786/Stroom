import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/pages/provider_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';

void main() {
  test('syncs a rotated secure credential reference to the legacy config',
      () async {
    final preferences = _MemoryAccountPreferences();
    final credentials = _MemoryCredentialStore();
    final accountService = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const sharedReference = 'shared-credential-reference';
    const originalSecret = 'original-secret-value';
    const rotatedSecret = 'rotated-secret-value';
    final account = LlmAccount(
      id: 'account-1',
      connectorType: 'openai-compatibility',
      authType: 'api_key',
      displayName: 'Account',
      status: LlmAccountStatus.ready,
      credentialRef: sharedReference,
    );
    preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
        jsonEncode({
      'version': 1,
      'items': [
        account.toMap(),
        LlmAccount(
          id: 'account-2',
          connectorType: account.connectorType,
          authType: account.authType,
          displayName: 'Shared owner',
          status: LlmAccountStatus.ready,
          credentialRef: sharedReference,
        ).toMap(),
      ],
    });
    await credentials.write(sharedReference, originalSecret);
    final original = await accountService.getAccount(account.id);
    expect(original, isNotNull);
    expect(original!.credentialRef, sharedReference);
    final runtime = LlmChatRoutingRuntime(
      accountService: accountService,
      routingService: LlmRoutingService(accountService: accountService),
    );
    final gatewayAccount = (await runtime.accountManagement.listAccounts())
        .singleWhere((item) => item.id == account.id);
    final editedAccount = AiGatewayAccount(
      id: gatewayAccount.id,
      connectorType: gatewayAccount.connectorType,
      authType: gatewayAccount.authType,
      displayName: gatewayAccount.displayName,
      status: gatewayAccount.status,
      hasCredential: gatewayAccount.hasCredential,
    );
    final saved = await runtime.accountManagement.saveAccount(
      editedAccount,
      secret: rotatedSecret,
    );
    final config = ProviderConfigItem(
      id: account.id,
      providerName: account.displayName,
      key: originalSecret,
      credentialRef: original.credentialRef,
    );

    final updated = syncLegacyLlmAccountCredentialReference(config, saved);

    expect(saved.credentialRef, isNot(original.credentialRef));
    expect(updated.credentialRef, saved.credentialRef);
    final serialized = updated.toMap(includeKey: true);
    expect(serialized['credentialRef'], saved.credentialRef);
    final serializedJson = jsonEncode(serialized);
    expect(serializedJson, isNot(contains(originalSecret)));
    expect(serializedJson, isNot(contains(rotatedSecret)));
    expect(
      await accountService.readCredential(account.id),
      rotatedSecret,
    );
    expect(await accountService.readCredential('account-2'), originalSecret);
    expect(
      preferences.values.values.any(
        (value) =>
            value.contains(originalSecret) || value.contains(rotatedSecret),
      ),
      isFalse,
    );
  });
  testWidgets(
    'keeps legacy LLM configs reachable when secure migration is unavailable',
    (tester) async {
      final entry = ProviderEntry(
        id: 'legacy-llm',
        type: 'llm',
        name: 'LLM供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Legacy OpenAI',
            host: 'https://legacy.example.test/v1',
            key: 'legacy-key',
            models: [
              ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
            ],
          ),
        ],
      );
      final state = ProviderEntriesState(
        entries: [entry],
        llmCredentialMigrationUnavailable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = state;
              return notifier;
            }),
          ],
          child: MaterialApp(home: ProviderConfigPage(entryId: entry.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('config_legacy-llm_0')), findsOneWidget);
      expect(find.text('Legacy OpenAI'), findsWidgets);
      expect(find.text('LLM 账号与模型组'), findsNothing);
    },
  );

  testWidgets(
    'keeps legacy LLM configs reachable when the account catalog is unavailable',
    (tester) async {
      final entry = ProviderEntry(
        id: 'legacy-llm-catalog-failure',
        type: 'llm',
        name: 'LLM供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Legacy OpenAI',
            host: 'https://legacy.example.test/v1',
            key: 'legacy-key',
            models: [
              ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
            ],
          ),
        ],
      );
      final state = ProviderEntriesState(
        entries: [entry],
        llmModelGroupCatalogUnavailable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = state;
              return notifier;
            }),
          ],
          child: MaterialApp(home: ProviderConfigPage(entryId: entry.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('config_legacy-llm-catalog-failure_0')),
        findsOneWidget,
      );
      expect(find.text('Legacy OpenAI'), findsWidgets);
      expect(find.text('LLM 账号与模型组'), findsNothing);
    },
  );
}

class _MemoryAccountPreferences implements LlmAccountPreferences {
  final values = <String, String>{};

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
