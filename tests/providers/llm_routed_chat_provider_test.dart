import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/llm_routed_chat_provider.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';

void main() {
  for (final (connectorType, endpointType, upstreamModelId) in [
    ('openai-compatibility', 'openai', 'gpt-routed'),
    ('claude', 'anthropic', 'claude-routed'),
  ]) {
    test(
      '$endpointType request keeps the routed model over extraParams',
      () async {
        final preferences = _MemoryPreferences();
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentialStore(),
        );
        await accounts.saveAccount(
          LlmAccount(
            id: 'account-$endpointType',
            connectorType: connectorType,
            authType: connectorType == 'claude' ? 'api_key' : 'none',
            displayName: 'Test account',
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: 'local-model',
                upstreamModelId: upstreamModelId,
                displayName: 'Routed model',
              ),
            ],
          ),
          secret: connectorType == 'claude' ? 'test-api-key' : null,
        );
        await accounts.saveModelGroup(
          LlmModelGroup(
            id: 'group-$endpointType',
            displayName: 'Test group',
            members: [
              LlmModelGroupMember(
                accountId: 'account-$endpointType',
                localModelId: 'local-model',
                upstreamModelId: upstreamModelId,
              ),
            ],
          ),
        );
        final connector = _FakeConnectorClient(accounts);
        final runtime = LlmChatRoutingRuntime(
          accountService: accounts,
          routingService: LlmRoutingService(
            accountService: accounts,
            stateStore: LlmRoutingStateStore(preferences: preferences),
            concurrency: LlmConcurrencyReservations(),
          ),
          connectorClient: connector,
        );
        final provider = LlmRoutedChatProvider(
          runtime: Future.value(runtime),
          groupId: 'group-$endpointType',
          localModelId: 'local-model',
          endpointType: endpointType,
        );

        await provider.chat(
          const [
            {'role': 'user', 'content': 'hello'},
          ],
          extraParams: const {'model': 'caller-selected-model'},
        );

        expect(connector.requestBody?['model'], upstreamModelId);
      },
    );
  }

  for (final (connectorType, endpointType, errorStream) in [
    (
      'openai-compatibility',
      'openai',
      'data: {"error":{"message":"slow down","code":"rate_limit_exceeded"}}\n\n',
    ),
    (
      'claude',
      'anthropic',
      'data: {"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}\n\n',
    ),
  ]) {
    test(
      '$endpointType stream rate-limit error falls back within its group',
      () async {
        final preferences = _MemoryPreferences();
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentialStore(),
        );
        for (final suffix in ['a', 'b']) {
          await accounts.saveAccount(
            LlmAccount(
              id: '$endpointType-$suffix',
              connectorType: connectorType,
              authType: connectorType == 'claude' ? 'api_key' : 'none',
              displayName: '$endpointType $suffix',
              status: LlmAccountStatus.ready,
              models: [
                LlmUpstreamModel(
                  id: 'stream-fallback-model',
                  upstreamModelId: '$endpointType-$suffix-upstream',
                  displayName: '$endpointType $suffix',
                  capabilities: const {'streaming': true},
                ),
              ],
            ),
            secret: connectorType == 'claude' ? 'test-api-key' : null,
          );
        }
        await accounts.saveModelGroup(
          LlmModelGroup(
            id: 'stream-fallback-$endpointType',
            displayName: 'Stream fallback $endpointType',
            policy: LlmRoutingPolicy(
              fallbackScope: LlmFallbackScope.modelGroup,
            ),
            members: [
              LlmModelGroupMember(
                accountId: '$endpointType-a',
                localModelId: 'stream-fallback-model',
                upstreamModelId: '$endpointType-a-upstream',
              ),
              LlmModelGroupMember(
                accountId: '$endpointType-b',
                localModelId: 'stream-fallback-model',
                upstreamModelId: '$endpointType-b-upstream',
              ),
            ],
          ),
        );
        final successStream = endpointType == 'anthropic'
            ? 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"fallback"}}\n\n'
                  'data: {"type":"message_stop"}\n\n'
            : 'data: {"choices":[{"delta":{"content":"fallback"},"finish_reason":null}]}\n\n'
                  'data: [DONE]\n\n';
        final connector = _FakeConnectorClient(
          accounts,
          streamBodies: [
            Stream<List<int>>.value(utf8.encode(errorStream)),
            Stream<List<int>>.value(utf8.encode(successStream)),
          ],
        );
        final provider = LlmRoutedChatProvider(
          runtime: Future.value(
            LlmChatRoutingRuntime(
              accountService: accounts,
              routingService: LlmRoutingService(
                accountService: accounts,
                stateStore: LlmRoutingStateStore(preferences: preferences),
                concurrency: LlmConcurrencyReservations(),
              ),
              connectorClient: connector,
            ),
          ),
          groupId: 'stream-fallback-$endpointType',
          localModelId: 'stream-fallback-model',
          endpointType: endpointType,
        );

        final events = await provider.chatStream(const [
          {'role': 'user', 'content': 'hello'},
        ]).toList();

        expect(connector.requestedAccountIds, [
          '$endpointType-a',
          '$endpointType-b',
        ]);
        expect(events.map((event) => event.text).join(), 'fallback');
      },
    );
  }

  test(
    'non-stream OpenAI rate-limit error falls back within its group',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final suffix in ['a', 'b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: 'completion-$suffix',
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: 'Completion $suffix',
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: 'completion-local-model',
                upstreamModelId: 'completion-$suffix-upstream',
                displayName: 'Completion $suffix',
              ),
            ],
          ),
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'completion-fallback-group',
          displayName: 'Completion fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'completion-a',
              localModelId: 'completion-local-model',
              upstreamModelId: 'completion-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'completion-b',
              localModelId: 'completion-local-model',
              upstreamModelId: 'completion-b-upstream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBodies: [
          const {
            'error': {'message': 'slow down', 'code': 'rate_limit_exceeded'},
          },
          const {
            'choices': [
              {
                'message': {'content': 'fallback'},
              },
            ],
          },
        ],
      );
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: connector,
          ),
        ),
        groupId: 'completion-fallback-group',
        localModelId: 'completion-local-model',
        endpointType: 'openai',
      );

      final result = await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]);

      expect(result, 'fallback');
      expect(connector.requestedAccountIds, ['completion-a', 'completion-b']);
    },
  );

  test(
    'non-stream Anthropic rate-limit error falls back within its group',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final suffix in ['a', 'b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: 'anthropic-completion-$suffix',
            connectorType: 'claude',
            authType: 'api_key',
            displayName: 'Anthropic completion $suffix',
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: 'anthropic-completion-model',
                upstreamModelId: 'claude-completion-$suffix',
                displayName: 'Anthropic completion $suffix',
              ),
            ],
          ),
          secret: 'test-api-key-$suffix',
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'anthropic-completion-fallback-group',
          displayName: 'Anthropic completion fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'anthropic-completion-a',
              localModelId: 'anthropic-completion-model',
              upstreamModelId: 'claude-completion-a',
            ),
            LlmModelGroupMember(
              accountId: 'anthropic-completion-b',
              localModelId: 'anthropic-completion-model',
              upstreamModelId: 'claude-completion-b',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBodies: [
          const {
            'type': 'error',
            'error': {'type': 'rate_limit_error', 'message': 'slow down'},
          },
          const {
            'content': [
              {'type': 'text', 'text': 'fallback'},
            ],
          },
        ],
      );
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: connector,
          ),
        ),
        groupId: 'anthropic-completion-fallback-group',
        localModelId: 'anthropic-completion-model',
        endpointType: 'anthropic',
      );

      final result = await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]);

      expect(result, 'fallback');
      expect(connector.requestedAccountIds, [
        'anthropic-completion-a',
        'anthropic-completion-b',
      ]);
    },
  );

  test('OpenAI DONE sentinel cancels a still-open response stream', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'open-stream-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Open stream account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'open-stream-model',
            upstreamModelId: 'gpt-open-stream',
            displayName: 'Open stream model',
            capabilities: {'streaming': true},
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'open-stream-group',
        displayName: 'Open stream group',
        members: const [
          LlmModelGroupMember(
            accountId: 'open-stream-account',
            localModelId: 'open-stream-model',
            upstreamModelId: 'gpt-open-stream',
          ),
        ],
      ),
    );
    var sourceCancelled = false;
    final responseSource = StreamController<List<int>>(
      onCancel: () => sourceCancelled = true,
    );
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: responseSource.stream,
    );
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(
        LlmChatRoutingRuntime(
          accountService: accounts,
          routingService: LlmRoutingService(
            accountService: accounts,
            stateStore: LlmRoutingStateStore(preferences: preferences),
            concurrency: LlmConcurrencyReservations(),
          ),
          connectorClient: connector,
        ),
      ),
      groupId: 'open-stream-group',
      localModelId: 'open-stream-model',
      endpointType: 'openai',
    );
    final eventsFuture = provider.chatStream(const [
      {'role': 'user', 'content': 'hello'},
    ]).toList();

    try {
      await Future<void>.delayed(Duration.zero);
      responseSource.add(utf8.encode('data: [DONE]\n\n'));
      final events = await eventsFuture.timeout(const Duration(seconds: 1));

      expect(events, isEmpty);
      expect(sourceCancelled, isTrue);
    } finally {
      await responseSource.close();
      await eventsFuture;
    }
  });

  test(
    'chat falls back after a connection error before request dispatch',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final accountId in ['chat-a', 'chat-b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: accountId,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: '$accountId-model',
                upstreamModelId: '$accountId-upstream',
                displayName: accountId,
              ),
            ],
          ),
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'chat-fallback-group',
          displayName: 'Chat fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'chat-a',
              localModelId: 'chat-local-model',
              upstreamModelId: 'chat-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'chat-b',
              localModelId: 'chat-local-model',
              upstreamModelId: 'chat-b-upstream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        failFirstRequestBeforeSend: true,
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(runtime),
        groupId: 'chat-fallback-group',
        localModelId: 'chat-local-model',
        endpointType: 'openai',
      );

      final result = await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]);

      expect(result, 'ok');
      expect(connector.requestedAccountIds, ['chat-a', 'chat-b']);
    },
  );

  test(
    'chat preserves 4xx rate-limit metadata for same-group retry cooldown',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final accountId in ['chat-http-a', 'chat-http-b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: accountId,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: '$accountId-model',
                upstreamModelId: '$accountId-upstream',
                displayName: accountId,
              ),
            ],
          ),
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'chat-http-fallback-group',
          displayName: 'Chat HTTP fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'chat-http-a',
              localModelId: 'chat-http-local',
              upstreamModelId: 'chat-http-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'chat-http-b',
              localModelId: 'chat-http-local',
              upstreamModelId: 'chat-http-b-upstream',
            ),
          ],
        ),
      );
      final now = DateTime.utc(2026, 10, 18, 12);
      final stateStore = LlmRoutingStateStore(
        preferences: preferences,
        clock: () => now,
      );
      final connector = _FakeConnectorClient(
        accounts,
        firstRequestError: const _HttpExceptionWithHeaders(
          statusCode: 400,
          code: 'rate_limit_exceeded',
          headers: {'retry-after': '75'},
        ),
      );
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: stateStore,
              clock: () => now,
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: connector,
          ),
        ),
        groupId: 'chat-http-fallback-group',
        localModelId: 'chat-http-local',
        endpointType: 'openai',
      );

      final result = await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]);

      expect(result, 'ok');
      expect(connector.requestedAccountIds, ['chat-http-a', 'chat-http-b']);
      expect(
        (await stateStore.load()).cooldowns['chat-http-a']?.until,
        now.add(const Duration(seconds: 75)),
      );
    },
  );

  test(
    'empty OpenAI choices are reported as a routed request failure',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'empty-response-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Empty response account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'empty-response-model',
              upstreamModelId: 'gpt-empty-response',
              displayName: 'Empty response model',
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'empty-response-group',
          displayName: 'Empty response group',
          members: const [
            LlmModelGroupMember(
              accountId: 'empty-response-account',
              localModelId: 'empty-response-model',
              upstreamModelId: 'gpt-empty-response',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBody: const {'choices': []},
      );
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: connector,
          ),
        ),
        groupId: 'empty-response-group',
        localModelId: 'empty-response-model',
        endpointType: 'openai',
      );

      await expectLater(
        provider.chat(const [
          {'role': 'user', 'content': 'hello'},
        ]),
        throwsA(isA<LlmRouteRequestException>()),
      );
      expect(connector.requestedAccountIds, ['empty-response-account']);
    },
  );

  test(
    'missing or empty Anthropic content is a routed request failure',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'anthropic-empty-account',
          connectorType: 'claude',
          authType: 'api_key',
          displayName: 'Anthropic empty response account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'anthropic-empty-model',
              upstreamModelId: 'claude-empty-response',
              displayName: 'Anthropic empty response model',
            ),
          ],
        ),
        secret: 'test-api-key',
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'anthropic-empty-group',
          displayName: 'Anthropic empty response group',
          members: const [
            LlmModelGroupMember(
              accountId: 'anthropic-empty-account',
              localModelId: 'anthropic-empty-model',
              upstreamModelId: 'claude-empty-response',
            ),
          ],
        ),
      );

      for (final responseBody in <Object?>[
        const <String, dynamic>{},
        const <String, dynamic>{'content': []},
        const <String, dynamic>{
          'content': [
            {'type': 'text', 'text': ''},
          ],
        },
      ]) {
        final connector = _FakeConnectorClient(
          accounts,
          responseBody: responseBody,
        );
        final provider = LlmRoutedChatProvider(
          runtime: Future.value(
            LlmChatRoutingRuntime(
              accountService: accounts,
              routingService: LlmRoutingService(
                accountService: accounts,
                stateStore: LlmRoutingStateStore(preferences: preferences),
                concurrency: LlmConcurrencyReservations(),
              ),
              connectorClient: connector,
            ),
          ),
          groupId: 'anthropic-empty-group',
          localModelId: 'anthropic-empty-model',
          endpointType: 'anthropic',
        );

        await expectLater(
          provider.chat(const [
            {'role': 'user', 'content': 'hello'},
          ]),
          throwsA(isA<LlmRouteRequestException>()),
        );
      }
    },
  );

  test('unknown connection status remains eligible for chat routing', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'unknown-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Unknown account',
        status: LlmAccountStatus.unknown,
        models: const [
          LlmUpstreamModel(
            id: 'unknown-model',
            upstreamModelId: 'gpt-unknown',
            displayName: 'Unknown model',
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'unknown-group',
        displayName: 'Unknown group',
        members: const [
          LlmModelGroupMember(
            accountId: 'unknown-account',
            localModelId: 'unknown-model',
            upstreamModelId: 'gpt-unknown',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(accounts);
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(
        LlmChatRoutingRuntime(
          accountService: accounts,
          routingService: LlmRoutingService(
            accountService: accounts,
            stateStore: LlmRoutingStateStore(preferences: preferences),
            concurrency: LlmConcurrencyReservations(),
          ),
          connectorClient: connector,
        ),
      ),
      groupId: 'unknown-group',
      localModelId: 'unknown-model',
      endpointType: 'openai',
    );

    await provider.chat(const [
      {'role': 'user', 'content': 'hello'},
    ]);

    expect(connector.requestBody?['model'], 'gpt-unknown');
  });

  test('streaming chat only selects members with streaming capability', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    for (final (accountId, upstreamModelId, supportsStreaming) in [
      ('non-stream-account', 'gpt-non-stream', false),
      ('stream-account', 'gpt-stream', true),
    ]) {
      await accounts.saveAccount(
        LlmAccount(
          id: accountId,
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: accountId,
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: '$accountId-model',
              upstreamModelId: upstreamModelId,
              displayName: accountId,
              capabilities: {'streaming': supportsStreaming},
            ),
          ],
        ),
      );
    }
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'stream-group',
        displayName: 'Streaming group',
        members: const [
          LlmModelGroupMember(
            accountId: 'non-stream-account',
            localModelId: 'stream-model',
            upstreamModelId: 'gpt-non-stream',
          ),
          LlmModelGroupMember(
            accountId: 'stream-account',
            localModelId: 'stream-model',
            upstreamModelId: 'gpt-stream',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.value(
        utf8.encode(
          'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":null}]}\n\n'
          'data: [DONE]\n\n',
        ),
      ),
    );
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(
        LlmChatRoutingRuntime(
          accountService: accounts,
          routingService: LlmRoutingService(
            accountService: accounts,
            stateStore: LlmRoutingStateStore(preferences: preferences),
            concurrency: LlmConcurrencyReservations(),
          ),
          connectorClient: connector,
        ),
      ),
      groupId: 'stream-group',
      localModelId: 'stream-model',
      endpointType: 'openai',
    );

    await provider.chatStream(const [
      {'role': 'user', 'content': 'hello'},
    ]).toList();

    expect(connector.requestedAccountIds, ['stream-account']);
    expect(connector.requestBody?['model'], 'gpt-stream');
  });

  for (final (contentType, connectorType, endpointType, contentBlock) in [
    (
      'video_url',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'video_url',
        'video_url': {'url': 'https://example.test/video.mp4'},
      },
    ),
    (
      'file',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'file',
        'file': {'filename': 'report.pdf', 'file_data': 'data:application/pdf'},
      },
    ),
    (
      'document',
      'claude',
      'anthropic',
      <String, dynamic>{
        'type': 'document',
        'source': {'type': 'base64', 'media_type': 'application/pdf'},
      },
    ),
  ]) {
    test('$contentType content routes to a vision-capable member', () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final (suffix, supportsVision) in [
        ('text', false),
        ('vision', true),
      ]) {
        final accountId = '$contentType-$suffix';
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: connectorType,
            authType: connectorType == 'claude' ? 'api_key' : 'none',
            displayName: accountId,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: '$accountId-model',
                upstreamModelId: '$accountId-upstream',
                displayName: accountId,
                capabilities: {'vision': supportsVision},
              ),
            ],
          ),
          secret: connectorType == 'claude' ? 'test-api-key' : null,
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'multimodal-$contentType',
          displayName: 'Multimodal group',
          members: [
            LlmModelGroupMember(
              accountId: '$contentType-text',
              localModelId: 'multimodal-model',
              upstreamModelId: '$contentType-text-upstream',
            ),
            LlmModelGroupMember(
              accountId: '$contentType-vision',
              localModelId: 'multimodal-model',
              upstreamModelId: '$contentType-vision-upstream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(accounts);
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: connector,
          ),
        ),
        groupId: 'multimodal-$contentType',
        localModelId: 'multimodal-model',
        endpointType: endpointType,
      );

      await provider.chat([
        {
          'role': 'user',
          'content': [contentBlock],
        },
      ]);

      expect(connector.requestedAccountIds, ['$contentType-vision']);
    });
  }

  test('records response cost alongside connector token observations', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'usage-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Usage account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'usage-model',
            upstreamModelId: 'gpt-usage',
            displayName: 'Usage model',
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'usage-group',
        displayName: 'Usage group',
        members: const [
          LlmModelGroupMember(
            accountId: 'usage-account',
            upstreamModelId: 'gpt-usage',
            localModelId: 'usage-model',
          ),
        ],
      ),
    );
    final stateStore = LlmRoutingStateStore(preferences: preferences);
    final observedAt = DateTime.utc(2026, 10, 18);
    final runtime = LlmChatRoutingRuntime(
      accountService: accounts,
      routingService: LlmRoutingService(
        accountService: accounts,
        stateStore: stateStore,
        concurrency: LlmConcurrencyReservations(),
      ),
      connectorClient: _FakeConnectorClient(
        accounts,
        responseBody: {
          'choices': [
            {
              'message': {'content': 'ok'},
            },
          ],
          'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.03},
        },
        observation: LlmConnectorObservation(
          requestUsage: const LlmMetricObservation.reported(
            15,
            unit: 'tokens',
            source: 'openai-compatibility',
          ),
          remainingQuota: LlmMetricObservation.reported(
            250,
            unit: 'credits',
            source: 'test.connector',
            observedAt: observedAt,
          ),
          quotaSignals: {
            'dailyRemainingPercent': LlmMetricObservation.reported(
              75,
              unit: 'percent',
              source: 'test.daily',
              observedAt: observedAt,
            ),
            'weeklyRemainingPercent': LlmMetricObservation.reported(
              40,
              unit: 'percent',
              source: 'test.weekly',
              observedAt: observedAt,
            ),
          },
        ),
      ),
    );
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(runtime),
      groupId: 'usage-group',
      localModelId: 'usage-model',
      endpointType: 'openai',
    );

    await provider.chat(const [
      {'role': 'user', 'content': 'hello'},
    ]);

    final measurements = (await stateStore.load()).events.single.measurements;
    expect(
      measurements.where((item) => item.unit == 'tokens').single.value,
      15,
    );
    expect(measurements.where((item) => item.unit == 'usd').single.value, 0.03);

    Map<String, dynamic> storedAccountRecord() {
      final envelope =
          jsonDecode(
                preferences.values[LlmAccountMigrationService
                    .accountsPreferenceKey]!,
              )
              as Map;
      return Map<String, dynamic>.from(
        (envelope['items'] as List).single as Map,
      );
    }

    final savedAccount = storedAccountRecord();
    expect(savedAccount['remainingQuota']['value'], 250);
    expect(savedAccount['quotaSignals']['dailyRemainingPercent']['value'], 75);
    expect(savedAccount['usageByWindow']['day']['remaining']['value'], 75);
    expect(savedAccount['usageByWindow']['week']['remaining']['value'], 40);

    final unknownProvider = LlmRoutedChatProvider(
      runtime: Future.value(
        LlmChatRoutingRuntime(
          accountService: accounts,
          routingService: LlmRoutingService(
            accountService: accounts,
            stateStore: stateStore,
            concurrency: LlmConcurrencyReservations(),
          ),
          connectorClient: _FakeConnectorClient(accounts),
        ),
      ),
      groupId: 'usage-group',
      localModelId: 'usage-model',
      endpointType: 'openai',
    );
    await unknownProvider.chat(const [
      {'role': 'user', 'content': 'hello'},
    ]);
    final afterUnknownObservation = storedAccountRecord();
    expect(afterUnknownObservation['remainingQuota']['value'], 250);
    expect(
      afterUnknownObservation['quotaSignals']['dailyRemainingPercent']['value'],
      75,
    );
  });

  test(
    'persists quota reported only by the completed SSE observation',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'stream-quota-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Stream quota account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'stream-quota-model',
              upstreamModelId: 'gpt-stream-quota',
              displayName: 'Stream quota model',
              capabilities: {'streaming': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'stream-quota-group',
          displayName: 'Stream quota group',
          members: const [
            LlmModelGroupMember(
              accountId: 'stream-quota-account',
              upstreamModelId: 'gpt-stream-quota',
              localModelId: 'stream-quota-model',
            ),
          ],
        ),
      );
      final observedAt = DateTime.utc(2026, 10, 18);
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: _FakeConnectorClient(
              accounts,
              streamBody: Stream<List<int>>.value(
                utf8.encode('data: [DONE]\n\n'),
              ),
              completionObservation: Future.value(
                LlmConnectorObservation(
                  quotaSignals: {
                    'primaryRemainingPercent': LlmMetricObservation.reported(
                      62,
                      unit: 'percent',
                      source: 'test.stream',
                      observedAt: observedAt,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
        groupId: 'stream-quota-group',
        localModelId: 'stream-quota-model',
        endpointType: 'openai',
      );

      await provider.chatStream(const [
        {'role': 'user', 'content': 'hello'},
      ]).toList();

      final envelope =
          jsonDecode(
                preferences.values[LlmAccountMigrationService
                    .accountsPreferenceKey]!,
              )
              as Map;
      final savedAccount = Map<String, dynamic>.from(
        (envelope['items'] as List).single as Map,
      );
      expect(
        savedAccount['quotaSignals']['primaryRemainingPercent']['value'],
        62,
      );
    },
  );

  test(
    'persists header and completed quota when SSE fails without usage',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'failed-stream-quota-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Failed stream quota account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'failed-stream-quota-model',
              upstreamModelId: 'gpt-failed-stream-quota',
              displayName: 'Failed stream quota model',
              capabilities: {'streaming': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'failed-stream-quota-group',
          displayName: 'Failed stream quota group',
          members: const [
            LlmModelGroupMember(
              accountId: 'failed-stream-quota-account',
              upstreamModelId: 'gpt-failed-stream-quota',
              localModelId: 'failed-stream-quota-model',
            ),
          ],
        ),
      );
      final observedAt = DateTime.utc(2026, 10, 18);
      final provider = LlmRoutedChatProvider(
        runtime: Future.value(
          LlmChatRoutingRuntime(
            accountService: accounts,
            routingService: LlmRoutingService(
              accountService: accounts,
              stateStore: LlmRoutingStateStore(preferences: preferences),
              concurrency: LlmConcurrencyReservations(),
            ),
            connectorClient: _FakeConnectorClient(
              accounts,
              streamBody: Stream<List<int>>.value(
                utf8.encode(
                  'data: {"error":{"message":"slow down","code":"rate_limit_exceeded"}}\n\n',
                ),
              ),
              observation: LlmConnectorObservation(
                remainingQuota: LlmMetricObservation.reported(
                  320,
                  unit: 'credits',
                  source: 'test.headers',
                  observedAt: observedAt,
                ),
                quotaSignals: {
                  'headerRemainingPercent': LlmMetricObservation.reported(
                    80,
                    unit: 'percent',
                    source: 'test.headers',
                    observedAt: observedAt,
                  ),
                },
              ),
              completionObservation: Future.value(
                LlmConnectorObservation(
                  quotaSignals: {
                    'completedRemainingPercent': LlmMetricObservation.reported(
                      55,
                      unit: 'percent',
                      source: 'test.completed-stream',
                      observedAt: observedAt,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
        groupId: 'failed-stream-quota-group',
        localModelId: 'failed-stream-quota-model',
        endpointType: 'openai',
      );

      await expectLater(
        provider.chatStream(const [
          {'role': 'user', 'content': 'hello'},
        ]).toList(),
        throwsA(
          isA<LlmRoutingUnavailableException>().having(
            (error) => error.decisions.map((decision) => decision.reason),
            'decision reasons',
            contains('request_rateLimited'),
          ),
        ),
      );

      final envelope =
          jsonDecode(
                preferences.values[LlmAccountMigrationService
                    .accountsPreferenceKey]!,
              )
              as Map;
      final savedAccount = Map<String, dynamic>.from(
        (envelope['items'] as List).single as Map,
      );
      expect(savedAccount['remainingQuota']['value'], 320);
      expect(
        savedAccount['quotaSignals']['headerRemainingPercent']['value'],
        80,
      );
      expect(
        savedAccount['quotaSignals']['completedRemainingPercent']['value'],
        55,
      );
    },
  );
}

class _FakeConnectorClient extends LlmConnectorHttpClient {
  _FakeConnectorClient(
    LlmAccountConnectorService accountService, {
    this.responseBody,
    this.responseBodies,
    this.streamBody,
    this.streamBodies,
    LlmConnectorObservation? observation,
    this.completionObservation,
    this.failFirstRequestBeforeSend = false,
    this.firstRequestError,
  }) : observation = observation ?? LlmConnectorObservation(),
       super(accountService: accountService);

  final Object? responseBody;
  final List<Object?>? responseBodies;
  final Object? streamBody;
  final List<Object?>? streamBodies;
  final LlmConnectorObservation observation;
  final Future<LlmConnectorObservation>? completionObservation;
  final bool failFirstRequestBeforeSend;
  final LlmConnectorHttpException? firstRequestError;
  Map<String, dynamic>? requestBody;
  final requestedAccountIds = <String>[];

  @override
  Future<LlmConnectorResponse> request({
    required LlmAccount account,
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
    requestedAccountIds.add(account.id);
    requestBody = Map<String, dynamic>.from(body! as Map);
    if (failFirstRequestBeforeSend && requestedAccountIds.length == 1) {
      throw const LlmConnectorHttpException(code: 'connection_error');
    }
    await onRequestSent?.call();
    if (requestedAccountIds.length == 1 && firstRequestError != null) {
      throw firstRequestError!;
    }
    final requestStreamBody = streamBodies == null
        ? streamBody
        : streamBodies![requestedAccountIds.length - 1];
    final response = responseBodies == null
        ? responseBody ??
              (account.connectorType == 'claude'
                  ? {
                      'content': [
                        {'type': 'text', 'text': 'ok'},
                      ],
                    }
                  : {
                      'choices': [
                        {
                          'message': {'content': 'ok'},
                        },
                      ],
                    })
        : responseBodies![requestedAccountIds.length - 1];
    return LlmConnectorResponse(
      statusCode: 200,
      body: stream ? requestStreamBody : response,
      observation: observation,
      completedObservation: stream ? completionObservation : null,
    );
  }
}

class _HttpExceptionWithHeaders extends LlmConnectorHttpException {
  const _HttpExceptionWithHeaders({
    required super.statusCode,
    required super.code,
    required super.headers,
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
