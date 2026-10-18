import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_quota_service.dart';
import 'package:stroom/services/llm_credential_store.dart';

void main() {
  group('LlmConnectorRegistry', () {
    test('covers the pinned core auth and executor provider identifiers', () {
      final ids = LlmConnectorRegistry.all.map((item) => item.id).toSet();

      expect(
        ids,
        containsAll({
          'codex',
          'claude',
          'antigravity',
          'kimi',
          'kimi-ai',
          'kimi.ai',
          'xai',
          'devin',
          'meta',
          'gemini',
          'gemini-interactions',
          'aistudio',
          'vertex',
          'openai-compatibility',
        }),
      );
      expect(LlmConnectorRegistry.find('gemini-cli'), isNull);
      expect(LlmConnectorRegistry.find('KIMI.AI')?.id, 'kimi.ai');
      expect(LlmConnectorRegistry.find('anthropic')?.id, 'claude');
      expect(LlmConnectorRegistry.find('openai')?.id, 'openai-compatibility');
      expect(
        LlmConnectorRegistry.find('kimi.ai')?.quotaAvailability,
        LlmQuotaAvailability.unknown,
      );
    });
  });

  group('LlmAccountConnectorService', () {
    late _MemoryPreferences preferences;
    late _MemoryCredentials credentials;
    late LlmAccountConnectorService service;

    setUp(() {
      preferences = _MemoryPreferences();
      credentials = _MemoryCredentials();
      service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
    });

    test(
      'stores secrets by reference and removes them with account deletion',
      () async {
        final account = _account('custom-1', 'openai-compatibility');
        const secret = 'sk-private-account-secret';

        final savedAccount = await service.saveAccount(account, secret: secret);

        final storedJson = preferences
            .values[LlmAccountMigrationService.accountsPreferenceKey]!;
        expect(storedJson, isNot(contains(secret)));
        final stored = (jsonDecode(storedJson) as Map)['items'] as List;
        expect(stored.single['credentialRef'], savedAccount.credentialRef);
        expect(await service.readCredential(account.id), secret);

        await service.deleteAccount(account.id);

        expect(await service.listAccounts(), isEmpty);
        expect(await service.readCredential(account.id), isNull);
        expect(credentials.values, isEmpty);
      },
    );

    test(
      'rolls secure credential updates back when preference write fails',
      () async {
        final account = _account('custom-2', 'openai-compatibility');
        final savedAccount = await service.saveAccount(
          account,
          secret: 'old-secret',
        );
        preferences.failNextWriteKey =
            LlmAccountMigrationService.accountsPreferenceKey;

        await expectLater(
          service.saveAccount(account, secret: 'new-secret'),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect(await service.readCredential(account.id), 'old-secret');
        final saved = (jsonDecode(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        ) as Map)['items'] as List;
        expect(saved.single['credentialRef'], savedAccount.credentialRef);
      },
    );

    test(
      'rolls back a credential write that fails after persisting bytes',
      () async {
        final account = _account('partial-write', 'openai-compatibility');
        await service.saveAccount(account, secret: 'old-secret');
        credentials.failNextWriteAfterPersist = true;

        await expectLater(
          service.saveAccount(account, secret: 'new-secret'),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect(await service.readCredential(account.id), 'old-secret');
      },
    );

    test(
      'keeps credential references unique and deletes retired secrets',
      () async {
        final first = await service.saveAccount(
          _account('credential-owner', 'openai-compatibility'),
          secret: 'owner-secret',
        );
        final second = _account('credential-intruder', 'openai-compatibility');

        await expectLater(
          service.saveAccount(
            LlmAccount(
              id: second.id,
              connectorType: second.connectorType,
              authType: second.authType,
              displayName: second.displayName,
              credentialRef: first.credentialRef,
            ),
            secret: 'replacement-secret',
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        await service.saveAccount(
          LlmAccount(
            id: first.id,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: 'No auth',
          ),
        );

        expect(await service.readCredential(first.id), isNull);
        expect(credentials.values, isEmpty);
        expect(await service.getAccount(second.id), isNull);
      },
    );

    test('rejects caller-supplied credential refs for a new account', () async {
      credentials.values['unrelated-secret-ref'] = 'existing-secure-secret';
      final account = LlmAccount(
        id: 'credential-ref-spoof',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Custom',
        credentialRef: 'unrelated-secret-ref',
      );

      await expectLater(
        service.saveAccount(account, secret: 'replacement-secret'),
        throwsA(isA<LlmAccountConnectorException>()),
      );

      expect(credentials.values, {
        'unrelated-secret-ref': 'existing-secure-secret',
      });
      expect(preferences.values, isEmpty);
    });

    test(
      'does not let a reference-less account adopt a caller-supplied ref',
      () async {
        final account = await service.saveAccount(
          _account(
            'credential-ref-transition',
            'openai-compatibility',
            authType: 'none',
          ),
        );
        credentials.values['unrelated-secret-ref'] = 'existing-secure-secret';
        final updated = LlmAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: 'api_key',
          displayName: account.displayName,
          credentialRef: 'unrelated-secret-ref',
        );

        await expectLater(
          service.saveAccount(updated),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect((await service.getAccount(account.id))?.authType, 'none');
        expect(credentials.values, {
          'unrelated-secret-ref': 'existing-secure-secret',
        });
      },
    );

    test(
      'requires replacement credentials when account auth type changes',
      () async {
        final account = await service.saveAccount(
          _account('credential-auth-type-change', 'codex'),
          secret: 'private-api-key',
        );
        final updated = LlmAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: 'oauth',
          displayName: account.displayName,
          credentialRef: account.credentialRef,
        );

        await expectLater(
          service.saveAccount(updated),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect((await service.getAccount(account.id))?.authType, 'api_key');
        expect(await service.readCredential(account.id), 'private-api-key');
      },
    );

    test(
      'requires replacement credentials when connector type changes',
      () async {
        final account = await service.saveAccount(
          _account(
            'credential-connector-type-change',
            'codex',
            authType: 'oauth',
          ),
          secret: jsonEncode({'access_token': 'codex-access-token'}),
        );
        final updated = LlmAccount(
          id: account.id,
          connectorType: 'claude',
          authType: 'oauth',
          displayName: account.displayName,
          credentialRef: account.credentialRef,
        );

        await expectLater(
          service.saveAccount(updated),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect((await service.getAccount(account.id))?.connectorType, 'codex');
        expect(
          await service.readCredential(account.id),
          jsonEncode({'access_token': 'codex-access-token'}),
        );
      },
    );

    test(
      'rejects noncanonical connector identifiers before persistence',
      () async {
        await expectLater(
          service.saveAccount(
            _account('noncanonical-connector', 'CODEX', authType: 'oauth'),
            secret: jsonEncode({'access_token': 'codex-access-token'}),
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect(preferences.values, isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test(
      'maps migrated Anthropic and OpenAI accounts to native connectors',
      () async {
        const sharedRef = 'legacy-shared-credential';
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
            jsonEncode({
          'version': 1,
          'items': [
            {
              'id': 'legacy-anthropic',
              'connectorType': 'anthropic',
              'authType': 'api_key',
              'displayName': 'Legacy Anthropic',
              'credentialRef': sharedRef,
              'endpointConfig': {'host': 'https://claude.example.test'},
            },
            {
              'id': 'legacy-openai',
              'connectorType': 'openai',
              'authType': 'api_key',
              'displayName': 'Legacy OpenAI',
              'credentialRef': 'legacy-openai-credential',
              'endpointConfig': {'host': 'https://openai.example.test/v1'},
            },
          ],
        });
        credentials.values[sharedRef] = 'legacy-claude-key';
        credentials.values['legacy-openai-credential'] = 'legacy-openai-key';

        final migrated = await service.listAccounts();
        final anthropic = migrated.singleWhere(
          (item) => item.id == 'legacy-anthropic',
        );
        final openai = migrated.singleWhere(
          (item) => item.id == 'legacy-openai',
        );
        final anthropicRequest = LlmNativeRequestBuilder().build(
          account: anthropic,
          credential: await service.readCredential(anthropic.id),
          modelId: 'claude-sonnet-4',
          body: const {'model': 'claude-sonnet-4', 'messages': []},
        );
        final openaiRequest = LlmNativeRequestBuilder().build(
          account: openai,
          credential: await service.readCredential(openai.id),
          modelId: 'legacy-model',
          body: const {'model': 'legacy-model', 'messages': []},
        );

        expect(anthropic.connectorType, 'claude');
        expect(
          anthropic.endpointConfig['baseUrl'],
          'https://claude.example.test',
        );
        expect(
          anthropicRequest.uri.toString(),
          'https://claude.example.test/v1/messages',
        );
        expect(anthropicRequest.headers['x-api-key'], 'legacy-claude-key');
        expect(openai.connectorType, 'openai-compatibility');
        expect(
          openai.endpointConfig['baseUrl'],
          'https://openai.example.test/v1',
        );
        expect(
          openaiRequest.uri.toString(),
          'https://openai.example.test/v1/chat/completions',
        );
        expect(
          openaiRequest.headers['Authorization'],
          'Bearer legacy-openai-key',
        );
        expect(anthropic.credentialRef, sharedRef);
      },
    );

    test(
      'allows shared migrated credentials and preserves other owners',
      () async {
        const sharedRef = 'legacy-shared-credential';
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
            jsonEncode({
          'version': 1,
          'items': [
            for (final id in ['legacy-owner-one', 'legacy-owner-two'])
              {
                'id': id,
                'connectorType': 'codex',
                'authType': 'oauth',
                'displayName': id,
                'credentialRef': sharedRef,
                'endpointConfig': {},
              },
          ],
        });
        const oldSecret = '{"access_token":"shared-old-token"}';
        credentials.values[sharedRef] = oldSecret;
        final accounts = await service.listAccounts();
        final ownerOne = accounts.singleWhere(
          (item) => item.id == 'legacy-owner-one',
        );
        final ownerTwo = accounts.singleWhere(
          (item) => item.id == 'legacy-owner-two',
        );

        final retained = await service.saveAccount(ownerOne);
        expect(retained.credentialRef, sharedRef);
        expect(await service.readCredential(ownerTwo.id), oldSecret);

        final rotated = await service.saveAccount(
          ownerOne,
          secret: '{"access_token":"owner-one-new-token"}',
        );
        expect(rotated.credentialRef, isNot(sharedRef));
        expect(
          await service.readCredential(ownerOne.id),
          '{"access_token":"owner-one-new-token"}',
        );
        expect(await service.readCredential(ownerTwo.id), oldSecret);

        await service.deleteAccount(ownerTwo.id);
        expect(credentials.values.containsKey(sharedRef), isFalse);
        expect(
          await service.readCredential(ownerOne.id),
          '{"access_token":"owner-one-new-token"}',
        );
      },
    );

    test(
      'deletes a shared reference only after its final owner is removed',
      () async {
        const sharedRef = 'legacy-shared-credential';
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
            jsonEncode({
          'version': 1,
          'items': [
            for (final id in ['legacy-owner-one', 'legacy-owner-two'])
              {
                'id': id,
                'connectorType': 'codex',
                'authType': 'oauth',
                'displayName': id,
                'credentialRef': sharedRef,
                'endpointConfig': {},
              },
          ],
        });
        credentials.values[sharedRef] = '{"access_token":"shared-token"}';

        await service.deleteAccount('legacy-owner-one');

        expect(
          credentials.values[sharedRef],
          '{"access_token":"shared-token"}',
        );
        expect(
          await service.readCredential('legacy-owner-two'),
          '{"access_token":"shared-token"}',
        );

        await service.deleteAccount('legacy-owner-two');
        expect(credentials.values.containsKey(sharedRef), isFalse);
      },
    );

    test(
      'rejects sensitive URLs in model endpointUrl and url values',
      () async {
        for (final config in const [
          {'endpointUrl': 'https://example.test/#access_token=private-token'},
          {'url': 'https://example.test/?api_key=private-key'},
        ]) {
          final account = LlmAccount(
            id: 'unsafe-model-url-${config.keys.single}',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom',
            models: [
              LlmUpstreamModel(
                id: 'model-1',
                upstreamModelId: 'model-1',
                displayName: 'Model 1',
                config: config,
              ),
            ],
          );
          await expectLater(
            service.saveAccount(account, secret: 'secure-api-key'),
            throwsA(isA<LlmAccountConnectorException>()),
          );
        }
        expect(preferences.values, isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test(
      'rejects credential material in ordinary endpoint configuration',
      () async {
        for (final field in ['apiKey', 'key', 'accessKey']) {
          final account = LlmAccount(
            id: 'unsafe-config-$field',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom',
            endpointConfig: {
              'baseUrl': 'https://api.example.test/v1',
              field: 'must-not-be-persisted',
            },
          );

          await expectLater(
            service.saveAccount(account, secret: 'secure-api-key'),
            throwsA(isA<LlmAccountConnectorException>()),
          );
        }
        final headerAccount = LlmAccount(
          id: 'unsafe-config-header-access-key',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          endpointConfig: const {
            'baseUrl': 'https://api.example.test/v1',
            'headers': {'X-Access-Key': 'must-not-be-persisted'},
          },
        );
        await expectLater(
          service.saveAccount(headerAccount, secret: 'secure-api-key'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        final cookieHeaderAccount = LlmAccount(
          id: 'unsafe-config-header-cookie',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          endpointConfig: const {
            'baseUrl': 'https://api.example.test/v1',
            'headers': {'X-Session-Cookie': 'must-not-be-persisted'},
          },
        );
        await expectLater(
          service.saveAccount(cookieHeaderAccount, secret: 'secure-api-key'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(preferences.values, isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test('rejects credential fields in saved model config maps', () async {
      final account = LlmAccount(
        id: 'unsafe-model-config',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Custom',
        models: const [
          LlmUpstreamModel(
            id: 'model-1',
            upstreamModelId: 'model-1',
            displayName: 'Model 1',
            config: {'accessKey': 'must-not-be-persisted'},
          ),
        ],
      );

      await expectLater(
        service.saveAccount(account, secret: 'secure-api-key'),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      expect(preferences.values, isEmpty);
      expect(credentials.values, isEmpty);
    });

    test(
      'rejects credentials in fragments inside model endpoint config',
      () async {
        final account = LlmAccount(
          id: 'unsafe-model-url-fragment',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          models: const [
            LlmUpstreamModel(
              id: 'model-1',
              upstreamModelId: 'model-1',
              displayName: 'Model 1',
              config: {
                'baseUrl': 'https://example.test/#access_token=private-token',
              },
            ),
          ],
        );

        await expectLater(
          service.saveAccount(account, secret: 'private-api-key'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(preferences.values, isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test(
      'rejects credential query parameters in configured endpoint URLs',
      () async {
        for (final field in ['api_key', 'key', 'access_key', 'x-access-key']) {
          final account = LlmAccount(
            id: 'unsafe-url-$field',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom',
            endpointConfig: {
              'baseUrl': 'https://api.example.test/v1?$field=private-value',
            },
          );

          await expectLater(
            service.saveAccount(account, secret: 'secure-api-key'),
            throwsA(isA<LlmAccountConnectorException>()),
          );
        }
        expect(preferences.values, isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test('rejects fragments in configured endpoint URLs', () async {
      final account = LlmAccount(
        id: 'unsafe-url-fragment',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Custom',
        endpointConfig: const {
          'baseUrl': 'https://api.example.test/v1#access_token=private-token',
        },
      );

      await expectLater(
        service.saveAccount(account, secret: 'private-api-key'),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      expect(preferences.values, isEmpty);
      expect(credentials.values, isEmpty);
    });

    test(
      'requires stored accounts before refresh or Antigravity project lookup',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'unexpected-fresh-token',
                'cloudaicompanionProject': {'id': 'unexpected-project'},
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final credentialService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final codexOwner = await credentialService.saveAccount(
          _account('stored-codex-owner', 'codex', authType: 'oauth'),
          secret: jsonEncode({'refresh_token': 'other-account-refresh-token'}),
        );
        final forgedCodex = LlmAccount(
          id: 'unregistered-codex',
          connectorType: 'codex',
          authType: 'oauth',
          displayName: 'Unregistered Codex',
          credentialRef: codexOwner.credentialRef,
        );
        final antigravityOwner = await credentialService.saveAccount(
          _account(
            'stored-antigravity-owner',
            'antigravity',
            authType: 'oauth',
          ),
          secret: jsonEncode({'access_token': 'other-account-access-token'}),
        );
        final forgedAntigravity = LlmAccount(
          id: 'unregistered-antigravity',
          connectorType: 'antigravity',
          authType: 'oauth',
          displayName: 'Unregistered Antigravity',
          credentialRef: antigravityOwner.credentialRef,
        );

        await expectLater(
          credentialService.refreshCredential(forgedCodex),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        await expectLater(
          credentialService.ensureAntigravityProjectId(forgedAntigravity),
          throwsA(isA<LlmAccountConnectorException>()),
        );

        expect(requestsSent, 0);
      },
    );

    test('discovers the pinned catalog for an OAuth account', () async {
      final models = await service.discoverModels(
        _account('claude-catalog', 'claude', authType: 'oauth'),
      );

      expect(
        models.map((model) => model.upstreamModelId),
        contains('claude-sonnet-4-6'),
      );
      expect(models, isNotEmpty);
    });

    test(
      'keeps persisted model mappings when refreshing a pinned catalog',
      () async {
        final account = await service.saveAccount(
          LlmAccount(
            id: 'codex-custom-model-map',
            connectorType: 'codex',
            authType: 'oauth',
            displayName: 'Codex',
            models: const [
              LlmUpstreamModel(
                id: 'codex-user-alias',
                upstreamModelId: 'gpt-5.5',
                displayName: 'My Codex alias',
                config: {'alias': true},
              ),
            ],
          ),
          secret: jsonEncode({'access_token': 'codex-access'}),
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(models, hasLength(1));
        expect(models.single.id, 'codex-user-alias');
        expect(models.single.displayName, 'My Codex alias');
        expect(models.single.config['alias'], isTrue);
      },
    );

    test('discovers Gemini models over its native models endpoint', () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-3.1-pro',
                  'displayName': 'Gemini 3.1 Pro',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/text-embedding-004',
                  'supportedGenerationMethods': ['embedContent'],
                },
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
        dio: dio,
      );
      final account = await service.saveAccount(
        _account('gemini-discovery', 'gemini'),
        secret: 'gemini-private-key',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(captured?.uri.path, '/v1beta/models');
      expect(captured?.headers['x-goog-api-key'], 'gemini-private-key');
      expect(models.map((model) => model.upstreamModelId), ['gemini-3.1-pro']);
      expect(models.single.displayName, 'Gemini 3.1 Pro');
    });

    test(
      'rejects unapproved Gemini model discovery hosts before key use',
      () async {
        var requestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestSent = true;
            return ResponseBody.fromString('{}', 200);
          });
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await discoveryService.saveAccount(
          LlmAccount(
            id: 'gemini-untrusted-discovery',
            connectorType: 'gemini',
            authType: 'api_key',
            displayName: 'Gemini',
            endpointConfig: const {'baseUrl': 'https://attacker.example'},
          ),
          secret: 'gemini-private-key',
        );

        await expectLater(
          discoveryService.discoverModels(account, refreshRemote: true),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(requestSent, isFalse);
      },
    );

    test(
      'discovers compatible endpoint models from a full completion URL',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'local-model'},
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await discoveryService.saveAccount(
          LlmAccount(
            id: 'custom-full-url',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom endpoint',
            endpointConfig: const {
              'baseUrl':
                  'https://llm.example.test/v1/chat/completions?api-version=2024-01-01&tenant=alpha',
            },
          ),
          secret: 'custom-discovery-key',
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(
          captured?.uri.toString(),
          'https://llm.example.test/v1/models?api-version=2024-01-01&tenant=alpha',
        );
        expect(
          captured?.headers['Authorization'],
          'Bearer custom-discovery-key',
        );
        expect(models.single.upstreamModelId, 'local-model');
      },
    );

    test(
      'uses persisted account configuration for remote model discovery',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'trusted-model'},
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final saved = await discoveryService.saveAccount(
          LlmAccount(
            id: 'model-discovery-owner',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Trusted endpoint',
            endpointConfig: const {'baseUrl': 'https://trusted.example/v1'},
          ),
          secret: 'trusted-discovery-key',
        );
        final forged = LlmAccount(
          id: saved.id,
          connectorType: saved.connectorType,
          authType: saved.authType,
          displayName: saved.displayName,
          credentialRef: saved.credentialRef,
          endpointConfig: const {'baseUrl': 'https://attacker.example/v1'},
        );

        final models = await discoveryService.discoverModels(
          forged,
          refreshRemote: true,
        );

        expect(captured?.uri.host, 'trusted.example');
        expect(
          captured?.headers['Authorization'],
          'Bearer trusted-discovery-key',
        );
        expect(models.single.upstreamModelId, 'trusted-model');
      },
    );

    test(
      'rejects remote HTTP model discovery before sending credentials',
      () async {
        var requestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestSent = true;
            return ResponseBody.fromString('{}', 200);
          });
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await discoveryService.saveAccount(
          LlmAccount(
            id: 'plaintext-discovery',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Plaintext endpoint',
            endpointConfig: const {'baseUrl': 'http://models.example/v1'},
          ),
          secret: 'plaintext-discovery-key',
        );

        await expectLater(
          discoveryService.discoverModels(account, refreshRemote: true),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(requestSent, isFalse);
      },
    );

    test(
      'refreshes Codex OAuth and securely replaces rotated tokens',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'fresh-access-token',
                'refresh_token': 'fresh-refresh-token',
                'expires_in': 3600,
                'token_type': 'Bearer',
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final refreshService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await refreshService.saveAccount(
          _account('codex-refresh', 'codex', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'old-access-token',
            'refresh_token': 'old-refresh-token',
          }),
        );

        final didRefresh = await refreshService.refreshCredential(account);
        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        final storedAccounts = jsonEncode(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
        );

        expect(didRefresh, isTrue);
        expect(captured?.uri.toString(), 'https://auth.openai.com/oauth/token');
        expect(captured?.method, 'POST');
        expect(refreshed['access_token'], 'fresh-access-token');
        expect(refreshed['refresh_token'], 'fresh-refresh-token');
        expect(storedAccounts, isNot(contains('fresh-access-token')));
      },
    );

    test(
      'refreshes Claude, Antigravity, Kimi aliases, and Grok Build OAuth',
      () async {
        final refreshRequests = <String, RequestOptions>{};
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            refreshRequests[options.uri.host] = options;
            return ResponseBody.fromString(
              jsonEncode({'access_token': 'fresh-${options.uri.host}'}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final refreshService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );

        for (final connector in [
          'claude',
          'antigravity',
          'kimi',
          'kimi-ai',
          'kimi.ai',
          'xai',
        ]) {
          final endpoint =
              connector == 'xai' ? 'https://auth.x.ai/oauth/token' : null;
          final tokenEndpointFields = <String, String>{};
          if (endpoint != null) {
            tokenEndpointFields['token_endpoint'] = endpoint;
          }
          final account = await refreshService.saveAccount(
            _account('refresh-$connector', connector, authType: 'oauth'),
            secret: jsonEncode({
              'access_token': 'old-$connector',
              'refresh_token': 'refresh-$connector',
              if (connector == 'antigravity') ...{
                'client_id': 'test-antigravity-client-id',
                'client_secret': 'test-antigravity-client-secret',
              },
              if (connector.startsWith('kimi'))
                'domain': connector == 'kimi' ? 'kimi.com' : 'kimi.ai',
              ...tokenEndpointFields,
            }),
          );

          expect(
            await refreshService.refreshCredential(account),
            isTrue,
            reason: connector,
          );
          expect(
            jsonDecode(
              (await refreshService.readCredential(account.id))!,
            )['access_token'],
            startsWith('fresh-'),
            reason: connector,
          );
        }

        expect(
          refreshRequests.keys,
          containsAll({
            'platform.claude.com',
            'oauth2.googleapis.com',
            'auth.kimi.com',
            'auth.kimi.ai',
            'auth.x.ai',
          }),
        );
        final antigravityRequestData =
            refreshRequests['oauth2.googleapis.com']?.data;
        Map<String, dynamic> antigravityFormFields() {
          if (antigravityRequestData is String) {
            return Uri.splitQueryString(antigravityRequestData);
          }
          if (antigravityRequestData is Map) {
            return antigravityRequestData.cast<String, dynamic>();
          }
          fail('Antigravity refresh request did not contain form fields');
        }

        expect(
          antigravityFormFields(),
          containsPair('client_id', 'test-antigravity-client-id'),
        );
        expect(
          antigravityFormFields(),
          containsPair('client_secret', 'test-antigravity-client-secret'),
        );
        expect(
          refreshRequests['platform.claude.com']?.contentType,
          Headers.jsonContentType,
        );
        expect(refreshRequests['oauth2.googleapis.com']?.uri.path, '/token');
      },
    );

    test('requires secure Antigravity OAuth app credentials for refresh',
        () async {
      var refreshRequests = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          refreshRequests++;
          return ResponseBody.fromString(
            jsonEncode({'access_token': 'unexpected-access-token'}),
            200,
          );
        });
      final refreshService = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await refreshService.saveAccount(
        _account(
          'antigravity-missing-oauth-app-credentials',
          'antigravity',
          authType: 'oauth',
        ),
        secret: jsonEncode({
          'access_token': 'antigravity-access-token',
          'refresh_token': 'antigravity-refresh-token',
        }),
      );

      expect(await refreshService.refreshCredential(account), isFalse);
      expect(refreshRequests, 0);
    });

    test(
      'mints Meta Muse API keys from accepted DCA OAuth credentials',
      () async {
        RequestOptions? mintRequest;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            mintRequest = options;
            return ResponseBody.fromString(
              jsonEncode({
                'api_key': 'meta-private-api-key',
                'base_url': 'https://api.meta.ai/v1',
                'subs_tier_name': 'Pro',
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final refreshService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await refreshService.saveAccount(
          _account('meta-dca', 'meta', authType: 'oauth'),
          secret: jsonEncode({'dca_token': 'dca:private-session-token'}),
        );

        expect(
          LlmConnectorRegistry.find('meta')?.canRefreshCredentials,
          isTrue,
        );
        expect(await refreshService.refreshCredential(account), isTrue);

        final storedCredential =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        final preferencesJson = preferences.values.values.join();
        expect(
          mintRequest?.uri.toString(),
          'https://api.meta.ai/muse-code/key',
        );
        expect(
          mintRequest?.headers['Authorization'],
          'Bearer dca:private-session-token',
        );
        expect(mintRequest?.headers['User-Agent'], startsWith('muse-code/'));
        expect(storedCredential['api_key'], 'meta-private-api-key');
        expect(storedCredential['dca_token'], 'dca:private-session-token');
        expect(preferencesJson, isNot(contains('meta-private-api-key')));
        expect(preferencesJson, isNot(contains('dca:private-session-token')));
      },
    );
  });

  group('LlmNativeRequestBuilder', () {
    final builder = LlmNativeRequestBuilder();

    test('redacts query values from prepared request diagnostics', () {
      final request = LlmPreparedNativeRequest(
        uri: Uri.parse(
          'https://api.example.test/private-path-secret/v1?token=private-token',
        ),
        method: 'POST',
        headers: const {'Authorization': 'Bearer private-token'},
        body: const {'prompt': 'private prompt'},
      );

      expect(request.toString(), isNot(contains('private-token')));
      expect(request.toString(), isNot(contains('private-path-secret')));
      expect(request.toString(), isNot(contains('private prompt')));
      expect(request.toString(), contains('api.example.test'));
    });

    test('rejects OAuth bundles without an access token', () {
      expect(
        () => builder.build(
          account: _account('codex-refresh-only', 'codex', authType: 'oauth'),
          credential: jsonEncode({'refresh_token': 'private-refresh-token'}),
          modelId: 'gpt-5.5',
          body: const {'input': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test(
      'rejects unrelated API keys and non-map JSON as OAuth credentials',
      () {
        final account = _account(
          'codex-invalid-bundle',
          'codex',
          authType: 'oauth',
        );
        for (final credential in [
          jsonEncode({'api_key': 'private-api-key'}),
          jsonEncode([]),
        ]) {
          expect(
            () => builder.build(
              account: account,
              credential: credential,
              modelId: 'gpt-5.5',
              body: const {'input': []},
            ),
            throwsA(isA<LlmAccountConnectorException>()),
          );
        }
      },
    );

    test('uses Anthropic Messages with Claude Code OAuth credentials', () {
      final request = builder.build(
        account: _account('claude-1', 'claude', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'claude-access-secret'}),
        modelId: 'claude-sonnet-4-6',
        body: const {'model': 'claude-sonnet-4-6', 'messages': []},
      );

      expect(request.uri.path, '/v1/messages');
      expect(request.headers['Authorization'], 'Bearer claude-access-secret');
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(request.headers['X-App'], 'cli');
      expect(request.toString(), isNot(contains('claude-access-secret')));
    });

    test('uses Responses for Codex, Grok Build, and Meta', () {
      for (final connector in ['codex', 'xai', 'meta']) {
        final request = builder.build(
          account: _account('$connector-1', connector, authType: 'oauth'),
          credential: jsonEncode({
            'access_token': '$connector-access',
            if (connector == 'codex') 'account_id': 'codex-account-1',
          }),
          modelId: 'model-1',
          body: const {'model': 'model-1', 'input': []},
        );

        expect(request.uri.path, endsWith('/responses'), reason: connector);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer $connector-access');
        if (connector == 'codex') {
          expect(request.headers['Chatgpt-Account-Id'], 'codex-account-1');
        }
      }
    });

    test('sets native body stream flags for body-controlled protocols', () {
      final cases = <(LlmAccount, String?, String?)>[
        (
          _account('stream-codex', 'codex', authType: 'oauth'),
          jsonEncode({'access_token': 'codex-token'}),
          null,
        ),
        (
          _account('stream-claude', 'claude', authType: 'oauth'),
          jsonEncode({'access_token': 'claude-token'}),
          null,
        ),
        (
          _account('stream-kimi', 'kimi', authType: 'oauth'),
          jsonEncode({'access_token': 'kimi-token'}),
          null,
        ),
        (
          _account('stream-xai', 'xai', authType: 'oauth'),
          jsonEncode({'access_token': 'xai-token'}),
          null,
        ),
        (_account('stream-meta', 'meta'), 'meta-api-key', null),
        (
          _account('stream-interactions', 'gemini-interactions'),
          'interactions-api-key',
          null,
        ),
        (
          LlmAccount(
            id: 'stream-vertex-interactions',
            connectorType: 'vertex',
            authType: 'api_key',
            displayName: 'Vertex Interactions',
            endpointConfig: const {'interactions': true},
          ),
          'vertex-api-key',
          'interactions',
        ),
        (
          LlmAccount(
            id: 'stream-compatible',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Compatible',
            endpointConfig: const {'baseUrl': 'https://compat.example.test/v1'},
          ),
          'compatible-api-key',
          null,
        ),
      ];

      for (final (account, credential, nativeFormat) in cases) {
        final request = builder.build(
          account: account,
          credential: credential,
          modelId: 'model-1',
          body: const {'stream': false},
          stream: true,
          nativeFormat: nativeFormat,
        );

        expect(
          (request.body as Map)['stream'],
          isTrue,
          reason: account.connectorType,
        );
      }

      final nonStreaming = builder.build(
        account: LlmAccount(
          id: 'stream-compatible-off',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Compatible',
          endpointConfig: const {'baseUrl': 'https://compat.example.test/v1'},
        ),
        credential: 'compatible-api-key',
        modelId: 'model-1',
        body: const {'stream': true},
      );
      expect((nonStreaming.body as Map)['stream'], isFalse);
    });

    test(
      'uses native Google API paths and the Generative Language key header',
      () {
        final gemini = builder.build(
          account: _account('gemini-1', 'gemini'),
          credential: 'google-api-secret',
          modelId: 'gemini-3.1-pro-preview',
          body: const {'contents': []},
        );
        final interactions = builder.build(
          account: _account('interactions-1', 'gemini-interactions'),
          credential: 'interactions-secret',
          modelId: 'gemini-3.1-pro-preview',
          body: const {'model': 'gemini-3.1-pro-preview', 'input': []},
        );

        expect(
          gemini.uri.path,
          '/v1beta/models/gemini-3.1-pro-preview:generateContent',
        );
        expect(gemini.headers['x-goog-api-key'], 'google-api-secret');
        expect(interactions.uri.path, '/v1beta/interactions');
        expect(interactions.headers['x-goog-api-key'], 'interactions-secret');
        expect(interactions.headers['Api-Revision'], '2026-05-20');
      },
    );

    test('uses Vertex project and location in its native generate path', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'vertex-1',
          connectorType: 'vertex',
          authType: 'api_key',
          displayName: 'Vertex',
          endpointConfig: const {
            'projectId': 'my-project',
            'location': 'us-central1',
          },
        ),
        credential: 'vertex-api-secret',
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(
        request.uri.path,
        '/v1/projects/my-project/locations/us-central1/publishers/google/models/gemini-3.1-pro:generateContent',
      );
      expect(request.headers['x-goog-api-key'], 'vertex-api-secret');
    });

    test('uses the native Vertex Imagen predict request shape', () {
      const imageBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'a red fox in snow'},
            ],
          },
        ],
        'aspectRatio': '16:9',
        'sampleCount': 2,
        'negativePrompt': 'blurry',
      };
      final request = builder.build(
        account: LlmAccount(
          id: 'vertex-imagen',
          connectorType: 'vertex',
          authType: 'service_account',
          displayName: 'Vertex Imagen',
          endpointConfig: const {
            'projectId': 'my-project',
            'location': 'us-central1',
          },
        ),
        credential: jsonEncode({'access_token': 'vertex-access-token'}),
        modelId: 'imagen-4.0-generate-001',
        body: imageBody,
      );
      final apiKeyRequest = builder.build(
        account: LlmAccount(
          id: 'vertex-imagen-api-key',
          connectorType: 'vertex',
          authType: 'api_key',
          displayName: 'Vertex Imagen API key',
          endpointConfig: const {
            'projectId': 'my-project',
            'location': 'us-central1',
          },
        ),
        credential: 'vertex-api-secret',
        modelId: 'imagen-4.0-generate-001',
        body: imageBody,
      );

      expect(
        request.uri.path,
        '/v1/projects/my-project/locations/us-central1/publishers/google/models/imagen-4.0-generate-001:predict',
      );
      expect(request.body, {
        'instances': [
          {'prompt': 'a red fox in snow', 'negativePrompt': 'blurry'},
        ],
        'parameters': {'sampleCount': 2, 'aspectRatio': '16:9'},
      });
      expect(apiKeyRequest.uri.path, request.uri.path);
      expect(apiKeyRequest.body, request.body);
    });

    test('rejects streaming Vertex Imagen requests', () {
      expect(
        () => builder.build(
          account: _account('vertex-imagen-stream', 'vertex'),
          credential: 'vertex-api-secret',
          modelId: 'imagen-4.0-generate-001',
          body: const {'prompt': 'a red fox in snow'},
          stream: true,
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('allows HTTPS custom endpoints for provider API-key accounts', () {
      final cases = [
        (
          LlmAccount(
            id: 'custom-codex-key',
            connectorType: 'codex',
            authType: 'api_key',
            displayName: 'Codex gateway',
            endpointConfig: const {'baseUrl': 'https://codex.example.test/v1'},
          ),
          'https://codex.example.test/v1/responses',
        ),
        (
          LlmAccount(
            id: 'custom-claude-key',
            connectorType: 'claude',
            authType: 'api_key',
            displayName: 'Claude gateway',
            endpointConfig: const {'baseUrl': 'https://claude.example.test'},
          ),
          'https://claude.example.test/v1/messages',
        ),
        (
          LlmAccount(
            id: 'custom-vertex-key',
            connectorType: 'vertex',
            authType: 'api_key',
            displayName: 'Vertex gateway',
            endpointConfig: const {
              'baseUrl': 'https://vertex.example.test',
              'projectId': 'project-1',
              'location': 'global',
            },
          ),
          'https://vertex.example.test/v1/projects/project-1/locations/global/publishers/google/models/gemini-3.1-pro:generateContent',
        ),
      ];

      for (final (account, expectedUri) in cases) {
        final request = builder.build(
          account: account,
          credential: 'provider-api-key',
          modelId: 'gemini-3.1-pro',
          body: const {},
        );

        expect(request.uri.toString(), expectedUri);
      }
    });

    test('rejects plaintext remote endpoints for first-party connectors', () {
      expect(
        () => builder.build(
          account: LlmAccount(
            id: 'plaintext-codex-key',
            connectorType: 'codex',
            authType: 'api_key',
            displayName: 'Plaintext Codex gateway',
            endpointConfig: const {'baseUrl': 'http://codex.example.test/v1'},
          ),
          credential: 'provider-api-key',
          modelId: 'gpt-5.5',
          body: const {'input': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('uses Vertex Interactions only when explicitly enabled', () {
      final account = LlmAccount(
        id: 'vertex-interactions',
        connectorType: 'vertex',
        authType: 'api_key',
        displayName: 'Vertex Interactions',
        endpointConfig: const {'projectId': 'my-project', 'interactions': true},
      );

      final interactions = builder.build(
        account: account,
        credential: 'vertex-api-secret',
        modelId: 'gemini-3.1-pro',
        body: const {'model': 'gemini-3.1-pro', 'input': 'hello'},
        nativeFormat: 'interactions',
      );
      final regular = builder.build(
        account: account,
        credential: 'vertex-api-secret',
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(
        interactions.uri.toString(),
        'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/interactions',
      );
      expect(interactions.headers['x-goog-api-key'], 'vertex-api-secret');
      expect(interactions.headers['Api-Revision'], '2026-05-20');
      expect(interactions.body, {'model': 'gemini-3.1-pro', 'input': 'hello'});
      expect(
        regular.uri.path,
        '/v1/projects/my-project/locations/us-central1/publishers/google/models/gemini-3.1-pro:generateContent',
      );
      expect(regular.headers['Api-Revision'], isNull);
    });

    test('wraps Antigravity payloads with the pinned request metadata', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'antigravity-envelope',
          connectorType: 'antigravity',
          authType: 'oauth',
          displayName: 'Antigravity',
          endpointConfig: const {'projectId': 'antigravity-project'},
        ),
        credential: jsonEncode({'access_token': 'antigravity-access'}),
        modelId: 'gemini-3.1-pro',
        body: const {
          'request': {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': 'hello'},
                ],
              },
            ],
          },
        },
      );

      final body = request.body as Map;
      expect(request.uri.path, '/v1internal:generateContent');
      expect(request.headers['Authorization'], 'Bearer antigravity-access');
      expect(
        request.headers['User-Agent'],
        'antigravity/hub/2.9.1 darwin/arm64',
      );
      expect(body['model'], 'gemini-3.1-pro');
      expect(body['userAgent'], 'antigravity');
      expect(body['requestType'], 'agent');
      expect(body['project'], 'antigravity-project');
      expect(body['request']['contents'], isNotEmpty);
      expect(body['request']['sessionId'], isNotEmpty);
      expect(body['requestId'], startsWith('agent-'));
    });

    test('uses native Antigravity image and web-search envelope variants', () {
      final account = LlmAccount(
        id: 'antigravity-variants',
        connectorType: 'antigravity',
        authType: 'oauth',
        displayName: 'Antigravity',
        endpointConfig: const {'projectId': 'antigravity-project'},
      );

      final image = builder.build(
        account: account,
        credential: jsonEncode({'access_token': 'antigravity-access'}),
        modelId: 'gemini-image-generation',
        body: const {
          'request': {'contents': []},
        },
      );
      final webSearch = builder.build(
        account: account,
        credential: jsonEncode({'access_token': 'antigravity-access'}),
        modelId: 'gemini-3.1-pro',
        body: const {
          'requestType': 'web_search',
          'request': {'contents': []},
        },
      );
      final imageBody = image.body as Map;
      final webSearchBody = webSearch.body as Map;

      expect(
        imageBody['requestId'],
        matches(RegExp(r'^image_gen/\d+/[^/]+/12$')),
      );
      expect(imageBody['request']['sessionId'], isNull);
      expect(webSearchBody['requestType'], 'web_search');
      expect(webSearchBody.containsKey('requestId'), isFalse);
      expect(
        (webSearchBody['request'] as Map).containsKey('sessionId'),
        isFalse,
      );
    });

    test(
      'prepares Google AI Studio relay requests for the native Google API',
      () {
        final request = builder.build(
          account: _account('aistudio-1', 'aistudio', authType: 'relay'),
          credential: null,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
        );

        expect(
          request.uri.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
        );
        expect(request.transport, LlmNativeTransport.websocketRelay);
        expect(request.headers.containsKey('Authorization'), isFalse);

        final streaming = builder.build(
          account: _account('aistudio-stream', 'aistudio', authType: 'relay'),
          credential: null,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
          stream: true,
        );
        expect(streaming.uri.queryParameters['alt'], 'sse');
      },
    );

    test('preserves endpoint query values and generated stream parameters', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'gemini-query-params',
          connectorType: 'gemini',
          authType: 'api_key',
          displayName: 'Gemini',
          endpointConfig: const {
            'baseUrl':
                'https://generativelanguage.googleapis.com?region=us&alt=json',
          },
        ),
        credential: 'gemini-api-key',
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
        stream: true,
      );

      expect(request.uri.queryParameters['region'], 'us');
      expect(request.uri.queryParameters['alt'], 'sse');
    });

    test('keeps Kimi and Devin on their connector-specific routes', () {
      final kimi = builder.build(
        account: _account('kimi-1', 'kimi', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'kimi-access'}),
        modelId: 'kimi-k2.8',
        body: const {'model': 'kimi-k2.8', 'messages': []},
      );
      final devin = builder.build(
        account: _account('devin-1', 'devin', authType: 'session_token'),
        credential: 'devin-session-secret',
        modelId: 'devin/swe-2',
        body: Uint8List.fromList([0, 1, 2]),
      );

      expect(kimi.uri.path, '/coding/v1/chat/completions');
      expect(kimi.headers['Authorization'], 'Bearer kimi-access');
      expect(
        devin.uri.path,
        '/exa.api_server_pb.ApiServerService/GetChatMessage',
      );
      expect(
        devin.headers['Authorization'],
        'Basic devin-session-secret-devin-session-secret',
      );
      expect(devin.body, isA<Uint8List>());
    });

    test('rejects Devin streaming until its Connect stream is decoded', () {
      expect(
        () => builder.build(
          account: _account('devin-stream', 'devin', authType: 'session_token'),
          credential: 'devin-session-secret',
          modelId: 'devin/swe-2',
          body: Uint8List.fromList([0, 1, 2]),
          stream: true,
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test(
      'uses an OpenAI-compatible account base URL and configured safe headers',
      () {
        final request = builder.build(
          account: LlmAccount(
            id: 'custom-3',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Private endpoint',
            endpointConfig: const {
              'baseUrl':
                  'https://llm.example.test/api/v1?api-version=2024-01-01&tenant=alpha',
              'headers': {'X-Workspace': 'personal'},
            },
          ),
          credential: 'custom-api-secret',
          modelId: 'local-model',
          body: const {'model': 'local-model', 'messages': []},
        );

        expect(
          request.uri.toString(),
          'https://llm.example.test/api/v1/chat/completions?api-version=2024-01-01&tenant=alpha',
        );
        expect(request.headers['X-Workspace'], 'personal');
        expect(request.headers['Authorization'], 'Bearer custom-api-secret');
        expect(request.toString(), isNot(contains('custom-api-secret')));
      },
    );

    test('normalizes full completion URLs with a trailing slash', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'custom-trailing-completion-slash',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Private endpoint',
          endpointConfig: const {
            'baseUrl': 'https://llm.example.test/v1/chat/completions/',
          },
        ),
        credential: 'custom-api-secret',
        modelId: 'local-model',
        body: const {'model': 'local-model', 'messages': []},
      );

      expect(request.uri.path, '/v1/chat/completions');
    });

    test(
      'allows loopback HTTP and rejects remote HTTP compatible endpoints',
      () {
        final localRequest = builder.build(
          account: LlmAccount(
            id: 'local-compatible-http',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Loopback endpoint',
            endpointConfig: const {'baseUrl': 'http://localhost:1234/v1'},
          ),
          credential: 'local-api-key',
          modelId: 'local-model',
          body: const {'messages': []},
        );
        expect(
          localRequest.uri.toString(),
          'http://localhost:1234/v1/chat/completions',
        );

        expect(
          () => builder.build(
            account: LlmAccount(
              id: 'remote-compatible-http',
              connectorType: 'openai-compatibility',
              authType: 'api_key',
              displayName: 'Remote plaintext endpoint',
              endpointConfig: const {'baseUrl': 'http://models.example/v1'},
            ),
            credential: 'remote-api-key',
            modelId: 'remote-model',
            body: const {'messages': []},
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );
  });

  group('LlmConnectorHttpClient', () {
    test(
      'discovers and stores an Antigravity project before generation',
      () async {
        RequestOptions? generationRequest;
        var projectLookups = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.path.endsWith(':loadCodeAssist')) {
              projectLookups++;
              expect(
                options.headers['Authorization'],
                'Bearer antigravity-token',
              );
              return ResponseBody.fromString(
                jsonEncode({
                  'cloudaicompanionProject': {'id': 'resolved-project'},
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            generationRequest = options;
            return ResponseBody.fromString('{}', 200);
          });
        final preferences = _MemoryPreferences();
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account(
            'antigravity-project-lookup',
            'antigravity',
            authType: 'oauth',
          ),
          secret: jsonEncode({'access_token': 'antigravity-token'}),
        );

        await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {
            'request': {'contents': []},
          },
        );

        expect(projectLookups, 1);
        expect(
          generationRequest?.data,
          containsPair('project', 'resolved-project'),
        );
        expect(
          (await accounts.getAccount(account.id))?.endpointConfig['projectId'],
          'resolved-project',
        );
        final storedPreferences = preferences.values.values.join();
        expect(storedPreferences, isNot(contains('antigravity-token')));
      },
    );

    test('does not use non-map JSON as an Antigravity project token', () async {
      var requestsSent = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestsSent++;
          return ResponseBody.fromString(
            jsonEncode({
              'cloudaicompanionProject': {'id': 'project'},
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await accounts.saveAccount(
        _account('antigravity-array-token', 'antigravity', authType: 'oauth'),
        secret: jsonEncode([]),
      );

      await expectLater(
        LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {
            'request': {'contents': []},
          },
        ),
        throwsA(isA<LlmConnectorHttpException>()),
      );

      expect(requestsSent, 0);
    });

    test('executes each pinned HTTP connector through its native route',
        () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            '{}',
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final client = LlmConnectorHttpClient(accountService: accounts, dio: dio);
      final scenarios = [
        (
          _account('native-codex', 'codex', authType: 'oauth'),
          jsonEncode({'access_token': 'codex-token'}),
          'https://chatgpt.com/backend-api/codex/responses',
          const {'model': 'gpt-5.5', 'input': []},
        ),
        (
          _account('native-claude', 'claude', authType: 'oauth'),
          jsonEncode({'access_token': 'claude-token'}),
          'https://api.anthropic.com/v1/messages?beta=true',
          const {'model': 'claude-sonnet-4-6', 'messages': []},
        ),
        (
          LlmAccount(
            id: 'native-antigravity',
            connectorType: 'antigravity',
            authType: 'oauth',
            displayName: 'Antigravity',
            endpointConfig: const {'projectId': 'native-project'},
          ),
          jsonEncode({'access_token': 'antigravity-token'}),
          'https://cloudcode-pa.googleapis.com/v1internal:generateContent',
          const {
            'request': {'contents': []},
          },
        ),
        for (final connector in ['kimi', 'kimi-ai', 'kimi.ai'])
          (
            _account('native-$connector', connector, authType: 'oauth'),
            jsonEncode({'access_token': 'kimi-token'}),
            'https://${connector == 'kimi' ? 'api.kimi.com' : 'api.kimi.ai'}/coding/v1/chat/completions',
            const {'model': 'kimi-k2.8', 'messages': []},
          ),
        (
          _account('native-xai', 'xai', authType: 'oauth'),
          jsonEncode({'access_token': 'xai-token'}),
          'https://cli-chat-proxy.grok.com/v1/responses',
          const {'model': 'grok-code-fast-1', 'input': []},
        ),
        (
          _account('native-devin', 'devin', authType: 'session_token'),
          'devin-session',
          'https://server.codeium.com/exa.api_server_pb.ApiServerService/GetChatMessage',
          Uint8List.fromList([1, 2, 3]),
        ),
        (
          _account('native-meta', 'meta'),
          'meta-api-key',
          'https://api.meta.ai/v1/responses',
          const {'model': 'muse-code-model', 'input': []},
        ),
        (
          _account('native-gemini', 'gemini'),
          'gemini-api-key',
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
          const {'contents': []},
        ),
        (
          _account('native-interactions', 'gemini-interactions'),
          'interactions-api-key',
          'https://generativelanguage.googleapis.com/v1beta/interactions',
          const {'model': 'gemini-3.1-pro', 'input': []},
        ),
        (
          LlmAccount(
            id: 'native-vertex',
            connectorType: 'vertex',
            authType: 'api_key',
            displayName: 'Vertex',
            endpointConfig: const {
              'projectId': 'native-project',
              'location': 'us-central1',
            },
          ),
          'vertex-api-key',
          'https://us-central1-aiplatform.googleapis.com/v1/projects/native-project/locations/us-central1/publishers/google/models/gemini-3.1-pro:generateContent',
          const {'contents': []},
        ),
        (
          LlmAccount(
            id: 'native-custom',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom',
            endpointConfig: const {'baseUrl': 'https://llm.example.test/v1'},
          ),
          'custom-api-key',
          'https://llm.example.test/v1/chat/completions',
          const {'model': 'local-model', 'messages': []},
        ),
      ];

      for (final (account, secret, expectedUri, body) in scenarios) {
        final saved = await accounts.saveAccount(account, secret: secret);
        final modelId = switch (account.connectorType) {
          'gemini' || 'gemini-interactions' || 'vertex' => 'gemini-3.1-pro',
          _ => 'connector-test-model',
        };
        await client.request(account: saved, modelId: modelId, body: body);
        expect(
          requests.last.uri.toString(),
          expectedUri,
          reason: account.connectorType,
        );
      }
      expect(requests, hasLength(scenarios.length));
    });

    test('dispatches AI Studio through its connected relay executor', () async {
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account('aistudio-relay', 'aistudio', authType: 'relay'),
      );
      LlmPreparedNativeRequest? captured;
      final client = LlmConnectorHttpClient(
        accountService: accounts,
        aiStudioRelayExecutor: (receivedAccount, request) async {
          expect(receivedAccount.id, account.id);
          captured = request;
          return LlmConnectorResponse(
            statusCode: 200,
            body: const {'candidates': []},
            observation: LlmConnectorObservation(),
          );
        },
      );

      final response = await client.request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(captured?.transport, LlmNativeTransport.websocketRelay);
      expect(captured?.uri.host, 'generativelanguage.googleapis.com');
      expect(response.statusCode, 200);
    });

    test(
      'mints Meta OAuth credentials before the native Responses request',
      () async {
        RequestOptions? modelRequest;
        var minted = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.path == '/muse-code/key') {
              minted = true;
              return ResponseBody.fromString(
                jsonEncode({'api_key': 'meta-minted-key'}),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            modelRequest = options;
            return ResponseBody.fromString(
              jsonEncode({
                'usage': {'input_tokens': 2, 'output_tokens': 3},
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('meta-request', 'meta', authType: 'oauth'),
          secret: jsonEncode({'dca_token': 'dca:request-token'}),
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        await client.request(
          account: account,
          modelId: 'muse-code-model',
          body: const {'model': 'muse-code-model', 'input': []},
        );

        expect(minted, isTrue);
        expect(
          modelRequest?.uri.toString(),
          'https://api.meta.ai/v1/responses',
        );
        expect(
          modelRequest?.headers['Authorization'],
          'Bearer meta-minted-key',
        );
        expect(modelRequest?.headers['User-Agent'], startsWith('muse-build/'));
        expect(modelRequest?.headers['X-Client-Id'], 'tbh:tui');
      },
    );

    test(
      'exchanges Vertex service account credentials and executes natively',
      () async {
        RequestOptions? tokenRequest;
        RequestOptions? modelRequest;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.host == 'oauth2.googleapis.com') {
              tokenRequest = options;
              return ResponseBody.fromString(
                jsonEncode({
                  'access_token': 'vertex-access-token',
                  'expires_in': 3600,
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            modelRequest = options;
            return ResponseBody.fromString(
              jsonEncode({'candidates': []}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await accounts.saveAccount(
          LlmAccount(
            id: 'vertex-service-account',
            connectorType: 'vertex',
            authType: 'service_account',
            displayName: 'Vertex account',
          ),
          secret: jsonEncode(_vertexServiceAccount),
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        await client.request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
        );

        final form = _requestForm(tokenRequest!.data);
        final assertion = form['assertion']!;
        final assertionParts = assertion.split('.');
        final claims = jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(assertionParts[1])),
          ),
        ) as Map;
        expect(
          tokenRequest?.uri.toString(),
          'https://oauth2.googleapis.com/token',
        );
        expect(
          form['grant_type'],
          'urn:ietf:params:oauth:grant-type:jwt-bearer',
        );
        expect(claims['iss'], _vertexServiceAccount['client_email']);
        expect(
          claims['scope'],
          'https://www.googleapis.com/auth/cloud-platform',
        );
        expect(assertionParts, hasLength(3));
        expect(assertionParts[2], isNotEmpty);
        expect(
          modelRequest?.uri.toString(),
          'https://us-central1-aiplatform.googleapis.com/v1/projects/vertex-project/locations/us-central1/publishers/google/models/gemini-3.1-pro:generateContent',
        );
        expect(
          modelRequest?.headers['Authorization'],
          'Bearer vertex-access-token',
        );
        expect(
          preferences.values.values.join(),
          isNot(contains(_vertexServiceAccount['private_key'] as String)),
        );
        expect(
          await accounts.readCredential(account.id),
          contains('vertex-access-token'),
        );
      },
    );

    test(
      'reports AI Studio relay unavailable when no connection is injected',
      () async {
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('aistudio-no-relay', 'aistudio', authType: 'relay'),
        );
        final client = LlmConnectorHttpClient(accountService: accounts);

        await expectLater(
          client.request(
            account: account,
            modelId: 'gemini-3.1-pro',
            body: const {'contents': []},
          ),
          throwsA(isA<LlmConnectorTransportUnavailable>()),
        );
      },
    );

    test('executes the native request and returns request usage', () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'id': 'resp-1',
              'usage': {
                'input_tokens': 7,
                'output_tokens': 5,
                'total_tokens': 12,
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
      final account = await accounts.saveAccount(
        _account('codex-http', 'codex', authType: 'oauth'),
        secret: jsonEncode({'access_token': 'private-access-token'}),
      );
      final client = LlmConnectorHttpClient(accountService: accounts, dio: dio);

      final response = await client.request(
        account: account,
        modelId: 'gpt-5.5',
        body: const {'model': 'gpt-5.5', 'input': []},
      );

      expect(
        captured?.uri.toString(),
        'https://chatgpt.com/backend-api/codex/responses',
      );
      expect(captured?.headers['Authorization'], 'Bearer private-access-token');
      expect(response.statusCode, 200);
      expect(response.body, containsPair('id', 'resp-1'));
      expect(response.observation.requestUsage.value, 12);
      expect(response.observation.remainingQuota.isKnown, isFalse);
    });

    test(
      'streams native response chunks and observes Codex usage and quota',
      () async {
        final source = StreamController<Uint8List>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            expect(options.responseType, ResponseType.stream);
            expect(options.data, containsPair('stream', true));
            return ResponseBody(
              source.stream,
              200,
              headers: const {
                'x-codex-primary-used-percent': ['80'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('codex-stream', 'codex', authType: 'oauth'),
          secret: jsonEncode({'access_token': 'codex-stream-token'}),
        );
        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gpt-5.5',
          body: const {'model': 'gpt-5.5', 'input': []},
          stream: true,
        );

        expect(response.body, isA<Stream<List<int>>>());
        final event = utf8.encode(
          'data: {"type":"codex.rate_limits","rate_limits":{"primary":{"used_percent":65}}}\n\n'
          'data: {"type":"response.completed","response":{"usage":{"input_tokens":7,"output_tokens":5,"total_tokens":12}}}\n\n',
        );
        source.add(Uint8List.fromList(event));
        source.close();
        final delivered = await (response.body as Stream<List<int>>).toList();
        final observation = await response.completedObservation;

        expect(delivered, hasLength(1));
        expect(observation?.requestUsage.value, 12);
        expect(observation?.quotaSignals['primaryRemainingPercent']?.value, 35);
      },
    );

    test(
      'bounds accumulated SSE event data across multiple data lines',
      () async {
        final source = StreamController<Uint8List>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody(
              source.stream,
              200,
              headers: const {
                'content-type': ['text/event-stream'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('gemini-large-sse-frame', 'gemini'),
          secret: 'gemini-api-key',
        );
        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
          stream: true,
        );

        final repeatedFields = List<String>.filled(1000, '"padding":0,').join();
        final oversizedEvent =
            'data: {"usageMetadata":{"promptTokenCount":7},\n'
            '${List<String>.filled(90, 'data: $repeatedFields').join('\n')}\n'
            'data: "last":0}\n\n';
        expect(utf8.encode(oversizedEvent).length, greaterThan(1048576));
        final bytes = Uint8List.fromList(utf8.encode(oversizedEvent));
        for (var offset = 0; offset < bytes.length; offset += 32768) {
          final end =
              offset + 32768 < bytes.length ? offset + 32768 : bytes.length;
          source.add(Uint8List.sublistView(bytes, offset, end));
        }
        await source.close();

        final delivered = await (response.body as Stream<List<int>>).toList();
        final observation = await response.completedObservation;

        expect(delivered, isNotEmpty);
        expect(
          utf8.decode(delivered.expand((chunk) => chunk).toList()),
          oversizedEvent,
        );
        expect(observation?.requestUsage.isKnown, isFalse);
      },
    );

    test(
      'processes bounded SSE events when one source chunk exceeds the cap',
      () async {
        final source = StreamController<Uint8List>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody(
              source.stream,
              200,
              headers: const {
                'content-type': ['text/event-stream'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('gemini-multiple-sse-events', 'gemini'),
          secret: 'gemini-api-key',
        );
        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
          stream: true,
        );

        final padding = 'x' * 600000;
        String event(int tokens) =>
            'data: {"usageMetadata":{"promptTokenCount":$tokens},'
            '"padding":"$padding"}\n\n';
        final events = '${event(2)}${event(3)}';
        expect(utf8.encode(events).length, greaterThan(1048576));
        source.add(Uint8List.fromList(utf8.encode(events)));
        await source.close();

        final delivered = await (response.body as Stream<List<int>>).toList();
        final observation = await response.completedObservation;

        expect(delivered, hasLength(1));
        expect(observation?.requestUsage.isKnown, isTrue);
        expect(observation?.requestUsage.value, 3);
      },
    );

    test(
      'maps native Dio stream cancellation to connector cancellation',
      () async {
        final source = StreamController<Uint8List>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody(
              source.stream,
              200,
              headers: const {
                'content-type': ['text/event-stream'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('gemini-native-stream-cancel', 'gemini'),
          secret: 'gemini-api-key',
        );
        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
          stream: true,
        );
        final receivedError = Completer<Object>();
        (response.body as Stream<List<int>>).listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (!receivedError.isCompleted) receivedError.complete(error);
          },
        );
        source.addError(
          DioException.requestCancelled(
            requestOptions: RequestOptions(path: '/generate'),
            reason: 'cancelled',
          ),
        );

        final error = await receivedError.future;
        await source.close();

        expect(error, isA<LlmConnectorRequestCancelled>());
      },
    );

    test(
      'completes stream observations when the response consumer cancels',
      () async {
        final source = StreamController<Uint8List>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody(
              source.stream,
              200,
              headers: const {
                'x-codex-primary-used-percent': ['80'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('codex-stream-cancel', 'codex', authType: 'oauth'),
          secret: jsonEncode({'access_token': 'codex-stream-token'}),
        );
        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gpt-5.5',
          body: const {'model': 'gpt-5.5', 'input': []},
          stream: true,
        );
        final delivered = Completer<void>();
        final subscription = (response.body as Stream<List<int>>).listen((_) {
          delivered.complete();
        });
        source.add(
          Uint8List.fromList(
            utf8.encode(
              'data: {"type":"response.completed","response":{"usage":{"input_tokens":7,"output_tokens":5,"total_tokens":12}}}\n\n',
            ),
          ),
        );

        await delivered.future;
        await subscription.cancel();
        final observation = await response.completedObservation!.timeout(
          const Duration(seconds: 1),
        );

        expect(observation.requestUsage.value, 12);
        expect(observation.quotaSignals['primaryRemainingPercent']?.value, 20);
      },
    );

    test(
      'refreshes an OAuth bundle before using its refresh token as auth',
      () async {
        RequestOptions? refreshRequest;
        RequestOptions? providerRequest;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.host == 'auth.openai.com') {
              refreshRequest = options;
              return ResponseBody.fromString(
                jsonEncode({'access_token': 'fresh-access-token'}),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            providerRequest = options;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('codex-refresh-only', 'codex', authType: 'oauth'),
          secret: jsonEncode({'refresh_token': 'private-refresh-token'}),
        );

        await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'gpt-5.5',
          body: const {'input': []},
        );

        expect(refreshRequest?.uri.host, 'auth.openai.com');
        expect(
          providerRequest?.headers['Authorization'],
          'Bearer fresh-access-token',
        );
        expect(
          providerRequest?.headers['Authorization'],
          isNot(contains('private-refresh-token')),
        );
      },
    );

    test(
      'fails closed when refresh-only OAuth credentials cannot refresh',
      () async {
        var providerRequestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            providerRequestSent = options.uri.host != 'auth.openai.com';
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('codex-no-access-token', 'codex', authType: 'oauth'),
          secret: jsonEncode({'id_token': 'private-id-token'}),
        );

        await expectLater(
          LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
            account: account,
            modelId: 'gpt-5.5',
            body: const {'input': []},
          ),
          throwsA(isA<LlmConnectorHttpException>()),
        );
        expect(providerRequestSent, isFalse);
      },
    );

    test(
      'refreshes an expired OAuth credential and retries once on 401',
      () async {
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        var requestCount = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.host == 'auth.openai.com') {
              return ResponseBody.fromString(
                jsonEncode({
                  'access_token': 'rotated-access-token',
                  'refresh_token': 'rotated-refresh-token',
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            requestCount++;
            if (requestCount == 1) {
              return ResponseBody.fromString(
                jsonEncode({'error': 'auth rejected private-token-fragment'}),
                401,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            expect(
              options.headers['Authorization'],
              'Bearer rotated-access-token',
            );
            return ResponseBody.fromString(
              '{}',
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('codex-retry', 'codex', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'expired-access-token',
            'refresh_token': 'old-refresh-token',
          }),
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        final response = await client.request(
          account: account,
          modelId: 'gpt-5.5',
          body: const {'model': 'gpt-5.5', 'input': []},
        );

        expect(response.statusCode, 200);
        expect(requestCount, 2);
        final rotated = jsonDecode(
          (await accounts.readCredential(account.id))!,
        );
        expect(rotated['refresh_token'], 'rotated-refresh-token');
      },
    );

    test('does not expose upstream error text or credentials', () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter(
          (options) async => ResponseBody.fromString(
            jsonEncode({'error': 'private token leaked by upstream'}),
            500,
            headers: const {
              'content-type': ['application/json'],
            },
          ),
        );
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'compat-error',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Private endpoint',
          endpointConfig: const {'baseUrl': 'https://llm.example.test/v1'},
        ),
        secret: 'custom-private-api-key',
      );
      final client = LlmConnectorHttpClient(accountService: accounts, dio: dio);

      try {
        await client.request(
          account: account,
          modelId: 'private-model',
          body: const {'model': 'private-model', 'messages': []},
        );
        fail('Expected a sanitized connector failure.');
      } on LlmConnectorHttpException catch (error) {
        expect(error.statusCode, 500);
        expect(error.toString(), isNot(contains('private token')));
        expect(error.toString(), isNot(contains('custom-private-api-key')));
      }
    });
  });

  group('LlmConnectorQuotaService', () {
    test('accepts legacy M1 connector aliases for unknown quota', () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentials(),
      );
      preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
          jsonEncode({
        'version': 1,
        'items': [
          {
            'id': 'legacy-anthropic-quota',
            'connectorType': 'anthropic',
            'authType': 'api_key',
            'displayName': 'Legacy Anthropic',
          },
          {
            'id': 'legacy-openai-quota',
            'connectorType': 'openai',
            'authType': 'api_key',
            'displayName': 'Legacy OpenAI',
          },
        ],
      });
      final quota = LlmConnectorQuotaService(accountService: accounts);

      for (final record in const [
        {
          'id': 'legacy-anthropic-quota',
          'connectorType': 'anthropic',
          'authType': 'api_key',
          'displayName': 'Legacy Anthropic',
        },
        {
          'id': 'legacy-openai-quota',
          'connectorType': 'openai',
          'authType': 'api_key',
          'displayName': 'Legacy OpenAI',
        },
      ]) {
        final observation = await quota.observeAccountQuota(
          LlmAccount.fromMap(record),
        );
        expect(observation.remainingQuota.value, isNull);
        expect(observation.quotaSignals, isEmpty);
      }
    });

    test(
      'reads Antigravity credits from loadCodeAssist without changing units',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'paidTier': {
                  'id': 'tier-1',
                  'availableCredits': [
                    {
                      'creditType': 'GOOGLE_ONE_AI',
                      'creditAmount': '25000',
                      'minimumCreditAmountForUsage': '50',
                    },
                  ],
                },
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('antigravity-quota', 'antigravity', authType: 'oauth'),
          secret: jsonEncode({'access_token': 'antigravity-access-token'}),
        );

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);

        expect(
          captured?.uri.toString(),
          'https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist',
        );
        expect(
          captured?.headers['Authorization'],
          'Bearer antigravity-access-token',
        );
        expect(observation.remainingQuota.value, 25000);
        expect(observation.remainingQuota.unit, 'credits');
      },
    );

    test(
      'does not send refresh-only OAuth bundles to quota endpoints',
      () async {
        var quotaRequestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            quotaRequestSent = true;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account(
            'antigravity-refresh-only-quota',
            'antigravity',
            authType: 'oauth',
          ),
          secret: jsonEncode({'refresh_token': 'private-refresh-token'}),
        );

        await expectLater(
          LlmConnectorQuotaService(
            accountService: accounts,
            dio: dio,
          ).observeAccountQuota(account),
          throwsA(isA<LlmConnectorQuotaException>()),
        );
        expect(quotaRequestSent, isFalse);
      },
    );

    test(
      'does not send non-map JSON to quota endpoints as an OAuth token',
      () async {
        var quotaRequestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            quotaRequestSent = true;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('antigravity-array-quota', 'antigravity', authType: 'oauth'),
          secret: jsonEncode([]),
        );

        await expectLater(
          LlmConnectorQuotaService(
            accountService: accounts,
            dio: dio,
          ).observeAccountQuota(account),
          throwsA(isA<LlmConnectorQuotaException>()),
        );
        expect(quotaRequestSent, isFalse);
      },
    );

    test(
      'does not use Devin session-token fields for an OAuth account',
      () async {
        var quotaRequestSent = false;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            quotaRequestSent = true;
            return ResponseBody.fromBytes(
              _devinQuotaResponse(daily: 91, weekly: 47),
              200,
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('devin-oauth-session-field', 'devin', authType: 'oauth'),
          secret: jsonEncode({'session_token': 'private-session-token'}),
        );

        await expectLater(
          LlmConnectorQuotaService(
            accountService: accounts,
            dio: dio,
          ).observeAccountQuota(account),
          throwsA(isA<LlmConnectorQuotaException>()),
        );
        expect(quotaRequestSent, isFalse);
      },
    );

    test('refreshes an expired Antigravity token after a quota 401', () async {
      var quotaRequests = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          if (options.uri.host == 'oauth2.googleapis.com') {
            return ResponseBody.fromString(
              jsonEncode({'access_token': 'fresh-antigravity-token'}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          quotaRequests++;
          if (options.headers['Authorization'] == 'Bearer old-token') {
            return ResponseBody.fromString('{}', 401);
          }
          return ResponseBody.fromString(
            jsonEncode({
              'paidTier': {
                'availableCredits': [
                  {'creditType': 'GOOGLE_ONE_AI', 'creditAmount': '7'},
                ],
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await accounts.saveAccount(
        _account('antigravity-expired-quota', 'antigravity', authType: 'oauth'),
        secret: jsonEncode({
          'access_token': 'old-token',
          'refresh_token': 'old-refresh-token',
          'client_id': 'test-antigravity-client-id',
          'client_secret': 'test-antigravity-client-secret',
        }),
      );

      final observation = await LlmConnectorQuotaService(
        accountService: accounts,
        dio: dio,
      ).observeAccountQuota(account);

      expect(quotaRequests, 2);
      expect(observation.remainingQuota.value, 7);
    });

    test(
      'reads Devin daily and weekly quota as separate percent signals',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromBytes(
              _devinQuotaResponse(daily: 91, weekly: 47),
              200,
              headers: const {
                'content-type': ['application/proto'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account('devin-quota', 'devin', authType: 'session_token'),
          secret: 'devin-session-token',
        );

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);

        expect(
          captured?.uri.path,
          '/exa.seat_management_pb.SeatManagementService/GetUserStatus',
        );
        expect(
          captured?.headers['Authorization'],
          'Basic devin-session-token-devin-session-token',
        );
        expect(observation.quotaSignals['dailyRemainingPercent']?.value, 91);
        expect(
          observation.quotaSignals['dailyRemainingPercent']?.unit,
          'percent',
        );
        expect(observation.quotaSignals['weeklyRemainingPercent']?.value, 47);
        expect(observation.remainingQuota.isKnown, isFalse);
      },
    );

    test('rejects negative Devin remaining quota percentages', () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          return ResponseBody.fromBytes(
            _devinQuotaResponse(daily: -1, weekly: 47),
            200,
            headers: const {
              'content-type': ['application/proto'],
            },
          );
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account('devin-negative-quota', 'devin', authType: 'session_token'),
        secret: 'devin-session-token',
      );

      final observation = await LlmConnectorQuotaService(
        accountService: accounts,
        dio: dio,
      ).observeAccountQuota(account);

      expect(
        observation.quotaSignals,
        isNot(contains('dailyRemainingPercent')),
      );
      expect(observation.quotaSignals['weeklyRemainingPercent']?.value, 47);
    });

    test('keeps unavailable provider quota unknown', () async {
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account('claude-quota', 'claude', authType: 'oauth'),
        secret: jsonEncode({'access_token': 'claude-token'}),
      );

      final observation = await LlmConnectorQuotaService(
        accountService: accounts,
        dio: Dio(),
      ).observeAccountQuota(account);

      expect(observation.remainingQuota.isKnown, isFalse);
      expect(observation.quotaSignals, isEmpty);
    });
  });

  test(
    'parses response usage but leaves unsupported account quota unknown',
    () {
      final observation = parseLlmConnectorObservation(
          'gemini',
          {
            'usageMetadata': {
              'promptTokenCount': 12,
              'candidatesTokenCount': 8
            },
          },
          observedAt: DateTime.utc(2026, 10, 17));

      expect(observation.requestUsage.isKnown, isTrue);
      expect(observation.requestUsage.value, 20);
      expect(observation.requestUsage.unit, 'tokens');
      expect(observation.remainingQuota.isKnown, isFalse);
    },
  );

  test('bounds accumulated nonstream SSE event data', () {
    final padding = 'x' * 12000;
    final event = <String>[
      'data: {"usageMetadata":{"promptTokenCount":7},',
      for (var index = 0; index < 90; index++)
        'data: "padding$index":"$padding",',
      'data: "last":0}',
      '',
    ].join('\n');
    final bytes = utf8.encode(event);
    expect(bytes.length, greaterThan(1048576));

    final observation = parseLlmConnectorSseObservation('gemini', bytes);

    expect(observation.requestUsage.isKnown, isFalse);
  });

  test('parses Codex rate limit events as percent quota signals', () {
    final observation = parseLlmConnectorObservation('codex', {
      'type': 'codex.rate_limits',
      'rate_limits': {
        'primary': {'used_percent': 72},
        'secondary': {'used_percent': 25},
      },
    });

    expect(observation.quotaSignals['primaryRemainingPercent']?.value, 28);
    expect(
      observation.quotaSignals['primaryRemainingPercent']?.unit,
      'percent',
    );
    expect(observation.quotaSignals['secondaryRemainingPercent']?.value, 75);
    expect(observation.remainingQuota.isKnown, isFalse);
  });

  test('parses usage from native Devin Connect-proto response frames', () {
    final usage = <int>[];
    _appendTag(usage, 2, 0);
    _appendVarint(usage, 10);
    _appendTag(usage, 3, 0);
    _appendVarint(usage, 4);
    _appendTag(usage, 5, 0);
    _appendVarint(usage, 3);
    final frame = <int>[];
    _appendBytesField(frame, 7, usage);
    final connectFrame = Uint8List.fromList([
      0,
      0,
      0,
      0,
      frame.length,
      ...frame,
    ]);

    final observation = parseLlmConnectorObservation('devin', connectFrame);

    expect(observation.requestUsage.value, 17);
    expect(observation.requestUsage.unit, 'tokens');
    expect(observation.remainingQuota.isKnown, isFalse);
  });
}

Uint8List _devinQuotaResponse({required int daily, required int weekly}) {
  final plan = <int>[];
  _appendTag(plan, 14, 0);
  _appendVarint(plan, daily);
  _appendTag(plan, 15, 0);
  _appendVarint(plan, weekly);
  final user = <int>[];
  _appendBytesField(user, 13, plan);
  final response = <int>[];
  _appendBytesField(response, 1, user);
  return Uint8List.fromList(response);
}

void _appendBytesField(List<int> output, int fieldNumber, List<int> value) {
  _appendTag(output, fieldNumber, 2);
  _appendVarint(output, value.length);
  output.addAll(value);
}

void _appendTag(List<int> output, int fieldNumber, int wireType) =>
    _appendVarint(output, (fieldNumber << 3) | wireType);

void _appendVarint(List<int> output, int value) {
  var remaining = BigInt.from(value);
  if (value < 0) remaining += BigInt.one << 64;
  while (remaining >= BigInt.from(0x80)) {
    output.add(((remaining & BigInt.from(0x7f)).toInt()) | 0x80);
    remaining >>= 7;
  }
  output.add(remaining.toInt());
}

LlmAccount _account(
  String id,
  String connector, {
  String authType = 'api_key',
}) =>
    LlmAccount(
      id: id,
      connectorType: connector,
      authType: authType,
      displayName: connector,
    );

const _vertexServiceAccount = {
  'type': 'service_account',
  'project_id': 'vertex-project',
  'private_key_id': 'test-key',
  'private_key': '''-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAuDOwXO14ltE1j2O0iDSuqtbw/1kMKjeiki3oehk2zNoUte42
/s2rX15nYCkKtYG/r8WYvKzb31P4Uow1S4fFydKNWxgX4VtEjHgeqfPxeCL9wiJc
9KkEt4fyhj1Jo7193gCLtovLAFwPzAMbFLiXWkfqalJ5Z77fOE4Mo7u4pEgxNPgL
VFGe0cEOAsHsKlsze+m1pmPHwWNVTcoKe5o0hOzy6hCPgVc6me6Y7aO8Fb4OVg0l
XQdQpWn2ikVBpzBcZ6InnYyJ/CJNa3WL1LJ65mmYnfHtKGoMqhLK48OReguwRwwF
e9/2+8UcdZcN5rsvt7yg3ZrKNH8rx+wZ36sRewIDAQABAoIBAQCn1HCcOsHkqDlk
rDOQ5m8+uRhbj4bF8GrvRWTL2q1TeF/mY2U4Q6wg+KK3uq1HMzCzthWz0suCb7+R
dq4YY1ySxoSEuy8G5WFPmyJVNy6Lh1Yty6FmSZlCn1sZdD3kMoK8A0NIz5Xmffrm
pu3Fs2ozl9K9jOeQ3xgC9RoPFLrm8lHJ45Vn+SnTxZnsXT6pwpg3TnFIx5ZinU8k
l0Um1n80qD2QQDakQ5jyr2odAELLBDlyCkxAglBXAVt4nk9Kl6nxb4snd9dnrL70
WjLynWQsDczaV9TZIl2hYkMud+9OLVlUUtB+0c5b0p2t2P0sLltDaq3H6pT6yu2G
8E86J9IBAoGBAPJaTNV5ysVOFn+YwWwRztzrvNArUJkVq8abN0gGp3gUvDEZnvzK
weF7+lfZzcwVRmQkL3mWLzzZvCx77RfulAzLi5iFuRBPhhhxAPDiDuyL9B7O81G/
M/W5DPctGOyD/9cnLuh72oij0unc5MLSfzJf8wblpcjJnPBDqIVh6Qt9AoGBAMKT
Gacf4iSj1xW+0wrnbZlDuyCl6Msptj8ePcvLQrFqQmBwsXmWgVR+gFc/1G3lRft0
QC6chsmafQHIIPpaDjq3sQ01/tUu7LXL+g/Hw9XtUHbkg3sZIQBtC26rKdStfHNS
KTvuCgn/dAJNjiohfhWMt9R4Q6E5FV6PqQHJzPJXAoGAC41qZDKuC8GxKNvrPG+M
4NML6RBngySZT5pOhExs5zh10BFclshDfbAfOtjTCotpE5T1/mG+VrQ6WBSANMfW
ntWFDfwx2ikwRzH7zX+5HmV9eYp75sWqgGgVyiKIMZ4JMARaJBLjU+gbQbKZ5P+L
uKcCOq3vvSZ/KKTQ/6qvJTECgYBiWgbCgoxF5wdmd4Gn5llw+lqRYyur3hbACuJD
rCe3FDYfF3euNRSEiDkJYTtYnWbldtqmdPpw14VOrEF3KqQ8q/Nz8RIx4jlGn6dz
6I8mCIH+xv1q8MXMuFHqC9zmIxdgF2y+XVF3wkd6jodI5oscC3g0juHokbkqhkVw
oPfWmwKBgBfR6jv0gWWeWTfkNwj+cMLHQV1uvz6JyLH5K4iISEDFxYkd37jrHB8A
9hz9UDfmCbSs2j8CXDg7zCayM6tfu4Vtx+8S5g3oN6sa1JXFY1Os7SoXhTfX9M+7
QpYYDJZwkgZrVQoKMIdCs9xfyVhZERq945NYLekwE1t2W+tOVBgR
-----END RSA PRIVATE KEY-----''',
  'client_email': 'vertex-test@example.iam.gserviceaccount.com',
  'client_id': '1234567890',
};

Map<String, String> _requestForm(Object? body) {
  if (body is Map) return body.map((key, value) => MapEntry('$key', '$value'));
  if (body is String) return Uri.splitQueryString(body);
  throw StateError('Expected an encoded form body.');
}

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};
  String? failNextWriteKey;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failNextWriteKey == key) {
      failNextWriteKey = null;
      return false;
    }
    values[key] = value;
    return true;
  }
}

class _MemoryCredentials implements LlmCredentialStore {
  final Map<String, String> values = {};
  bool failNextWriteAfterPersist = false;

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
    if (failNextWriteAfterPersist) {
      failNextWriteAfterPersist = false;
      throw StateError('simulated partial credential-store write');
    }
  }
}

class _FunctionalAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _FunctionalAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}
