import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/cloudflare_workers_ai_connector.dart';
import 'package:stroom/services/llm_connector_model_catalog.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_quota_service.dart';
import 'package:stroom/services/api_protocol_config.dart';
import 'package:stroom/services/qoder_cli_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_oauth_flow.dart';
import 'package:stroom/services/aws_sigv4.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/src/ai_gateway/ai_gateway_facade.dart';
import '../fixtures/vertex_service_account.dart';

void main() {
  _registerZedHostedHttpRetryTest();
  test(
    'Amazon Q refresh registers a regional client for token-only imports',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          final payload = options.uri.path == '/client/register'
              ? {
                  'clientId': 'registered-client',
                  'clientSecret': 'registered-secret',
                }
              : {
                  'accessToken': 'fresh-access',
                  'refreshToken': 'rotated-refresh',
                  'expiresIn': 3600,
                };
          return ResponseBody.fromString(
            jsonEncode(payload),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final credentials = _MemoryCredentials();
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
        dio: dio,
      );
      final account = await service.saveAccount(
        _account(
          'amazon-q-refresh',
          'amazon-q',
          authType: 'oauth',
          endpointConfig: const {'region': 'eu-central-1'},
        ),
        secret: jsonEncode({'refresh_token': 'imported-refresh'}),
      );

      expect(await service.refreshCredential(account), isTrue);
      expect(requests.map((request) => request.uri.toString()), [
        'https://oidc.eu-central-1.amazonaws.com/client/register',
        'https://oidc.eu-central-1.amazonaws.com/token',
      ]);
      expect(
        requests.every((request) => request.followRedirects == false),
        isTrue,
      );
      expect(requests.last.data, {
        'clientId': 'registered-client',
        'clientSecret': 'registered-secret',
        'refreshToken': 'imported-refresh',
        'grantType': 'refresh_token',
      });
      expect(
        jsonDecode((await service.readCredential(account.id))!),
        containsPair('access_token', 'fresh-access'),
      );
    },
  );
  test(
    'Amazon Q refresh uses the IdC region and re-registers invalid clients once',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          final payload = switch (options.uri.path) {
            '/token'
                when requests.where((r) => r.uri.path == '/token').length ==
                    1 =>
              {'__type': 'ExpiredClientException'},
            '/client/register' => {
                'clientId': 'replacement-client',
                'clientSecret': 'replacement-secret',
              },
            '/token' => {
                'accessToken': 'recovered-access',
                'refreshToken': 'recovered-refresh',
              },
            _ => throw StateError('Unexpected Amazon Q refresh path.'),
          };
          final status = payload.containsKey('__type') ? 400 : 200;
          return ResponseBody.fromString(
            jsonEncode(payload),
            status,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        _account(
          'amazon-q-idc-region',
          'amazon-q',
          authType: 'oauth',
          endpointConfig: const {'region': 'us-east-1'},
        ),
        secret: jsonEncode({
          'refresh_token': 'imported-refresh',
          'region': 'eu-north-1',
          'clientId': 'expired-client',
          'clientSecret': 'expired-secret',
        }),
      );

      expect(await service.refreshCredential(account), isTrue);
      expect(requests.map((request) => request.uri.toString()), [
        'https://oidc.eu-north-1.amazonaws.com/token',
        'https://oidc.eu-north-1.amazonaws.com/client/register',
        'https://oidc.eu-north-1.amazonaws.com/token',
      ]);
      expect(requests.first.data, {
        'clientId': 'expired-client',
        'clientSecret': 'expired-secret',
        'refreshToken': 'imported-refresh',
        'grantType': 'refresh_token',
      });
      expect(requests.last.data, {
        'clientId': 'replacement-client',
        'clientSecret': 'replacement-secret',
        'refreshToken': 'imported-refresh',
        'grantType': 'refresh_token',
      });
      expect(
        jsonDecode((await service.readCredential(account.id))!),
        containsPair('access_token', 'recovered-access'),
      );
    },
  );
  test(
    'Amazon Q invalid refresh tokens do not trigger client re-registration',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            '{"__type":"InvalidGrantException"}',
            400,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        _account(
          'amazon-q-invalid-refresh',
          'amazon-q',
          authType: 'oauth',
          endpointConfig: const {'region': 'us-east-1'},
        ),
        secret: jsonEncode({
          'refresh_token': 'expired-refresh',
          'region': 'eu-north-1',
          'clientId': 'registered-client',
          'clientSecret': 'registered-secret',
        }),
      );

      await expectLater(
        service.refreshCredential(account),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      expect(requests, hasLength(1));
      expect(requests.single.uri.host, 'oidc.eu-north-1.amazonaws.com');
      expect(requests.single.uri.path, '/token');
    },
  );
  test('Amazon Q refresh rejects an explicitly invalid OIDC region', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'accessToken': 'unexpected-access',
            'refreshToken': 'unexpected-refresh',
          }),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
      dio: dio,
    );
    final account = await service.saveAccount(
      _account(
        'amazon-q-malformed-oidc-region',
        'amazon-q',
        authType: 'oauth',
        endpointConfig: const {'region': 'us-east-1'},
      ),
      secret: jsonEncode({
        'refresh_token': 'imported-refresh',
        'oidcRegion': 'not a region',
      }),
    );

    await expectLater(
      service.refreshCredential(account),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(requests, isEmpty);
  });
  test('Amazon Q request host stays bound to its supported region', () {
    final request = LlmNativeRequestBuilder().build(
      account: _account(
        'amazon-q-host',
        'amazon-q',
        authType: 'oauth',
        endpointConfig: const {
          'region': 'us-east-1',
          'baseUrl': 'https://override.example',
        },
      ),
      credential: jsonEncode({'access_token': 'q-access'}),
      modelId: 'claude-sonnet-4',
      body: const {'conversationState': {}},
      stream: true,
    );

    expect(
      request.uri,
      Uri.https('q.us-east-1.amazonaws.com', '/generateAssistantResponse'),
    );
    expect(request.headers['Authorization'], 'Bearer q-access');
    expect(request.headers['Accept'], 'application/vnd.amazon.eventstream');
    expect(
      request.headers['X-Amz-Target'],
      'AmazonCodeWhispererStreamingService.GenerateAssistantResponse',
    );
    final credentialRegionRequest = LlmNativeRequestBuilder().build(
      account: _account(
        'amazon-q-credential-region',
        'amazon-q',
        authType: 'oauth',
        endpointConfig: const {},
      ),
      credential: jsonEncode({
        'access_token': 'q-access',
        'region': 'eu-central-1',
      }),
      modelId: 'claude-sonnet-4',
      body: const {'conversationState': {}},
    );
    expect(
      credentialRegionRequest.uri,
      Uri.https('q.eu-central-1.amazonaws.com', '/generateAssistantResponse'),
    );
    final defaultRegionRequest = LlmNativeRequestBuilder().build(
      account: _account(
        'amazon-q-default-region',
        'amazon-q',
        authType: 'oauth',
        endpointConfig: const {},
      ),
      credential: jsonEncode({'access_token': 'q-access'}),
      modelId: 'claude-sonnet-4',
      body: const {'conversationState': {}},
    );
    expect(
      defaultRegionRequest.uri,
      Uri.https('q.us-east-1.amazonaws.com', '/generateAssistantResponse'),
    );
    expect(
      () => LlmNativeRequestBuilder().build(
        account: _account(
          'amazon-q-invalid-region',
          'amazon-q',
          authType: 'oauth',
          endpointConfig: const {'region': 'evil.example'},
        ),
        credential: jsonEncode({'access_token': 'q-access'}),
        modelId: 'claude-sonnet-4',
        body: const {'conversationState': {}},
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
  });
  test(
    'GitLab Duo keeps PAT and configured OAuth as distinct account modes',
    () {
      final connector = LlmConnectorRegistry.find('gitlab-duo');
      expect(connector, isNotNull);
      expect(connector!.authTypes, {'pat', 'oauth'});
      expect(connector.canRefreshCredentials, isTrue);
      expect(connector.modelCatalog, ['claude-sonnet-4-6', 'claude-haiku-4-5']);
      expect(
        LlmOAuthProviderPolicy.forProvider('gitlab-duo').supported,
        isTrue,
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('gitlab-duo'),
        'openai',
      );
      expect(
        builtinDefaultApiProtocolForConnector('gitlab-duo'),
        'openai.chat_completions',
      );
      expect(
        supportedApiProtocolsForSupplier(null, connectorType: 'gitlab-duo'),
        {'openai.chat_completions'},
      );
      expect(
        resolveApiProtocol(
          modelOverride: 'openai.chat_completions',
          supplierProtocol: 'anthropic.messages',
          builtinDefault: builtinDefaultApiProtocolForConnector('gitlab-duo'),
        ),
        'openai.chat_completions',
      );
    },
  );

  test(
    'GitLab Duo requests use Code Suggestions shape and account base URL',
    () {
      final builder = LlmNativeRequestBuilder();
      final pat = builder.build(
        account: _account(
          'gitlab-pat',
          'gitlab-duo',
          authType: 'pat',
          endpointConfig: const {'baseUrl': 'https://gitlab.example.com/'},
        ),
        credential: 'gitlab-pat-secret',
        modelId: 'claude-sonnet-4-6',
        body: const {
          'model': 'claude-sonnet-4-6',
          'messages': [
            {'role': 'system', 'content': 'You are helpful.'},
            {'role': 'user', 'content': 'Explain this code.'},
          ],
          'stream': true,
        },
        stream: true,
      );
      expect(
        pat.uri.toString(),
        'https://gitlab.example.com/api/v4/code_suggestions/completions',
      );
      expect(pat.headers['Authorization'], 'Bearer gitlab-pat-secret');
      expect(pat.body, {
        'current_file': {
          'file_name': 'snippet.txt',
          'content_above_cursor':
              'System instruction: You are helpful.\nUser: Explain this code.',
          'content_below_cursor': '',
        },
        'intent': 'generation',
        'generation_type': 'small_file',
        'stream': false,
        'user_instruction':
            'System instruction: You are helpful.\nUser: Explain this code.',
      });

      final oauth = builder.build(
        account: _account('gitlab-oauth', 'gitlab-duo', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'gitlab-oauth-access'}),
        modelId: 'claude-haiku-4-5',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Say hello.'},
          ],
        },
      );
      expect(
        oauth.uri.toString(),
        'https://gitlab.com/api/v4/code_suggestions/completions',
      );
      expect(oauth.headers['Authorization'], 'Bearer gitlab-oauth-access');
    },
  );

  test('GitLab Duo preserves supported text conversation history in order', () {
    final request = LlmNativeRequestBuilder().build(
      account: _account('gitlab-history', 'gitlab-duo', authType: 'pat'),
      credential: 'gitlab-pat-secret',
      modelId: 'claude-sonnet-4-6',
      body: const {
        'messages': [
          {'role': 'system', 'content': 'Follow the user carefully. '},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': ' What does'},
              {'type': 'input_text', 'text': ' this function do? '},
            ],
          },
          {'role': 'developer', 'content': 'Keep the answer concise.'},
          {
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'It sorts'},
              {'type': 'text', 'text': ' a list.'},
            ],
          },
          {'role': 'user', 'content': 'Now explain its complexity. '},
        ],
      },
    );

    const expectedPrompt = 'System instruction: Follow the user carefully. \n'
        'User:  What does this function do? \n'
        'Developer instruction: Keep the answer concise.\n'
        'Assistant: It sorts a list.\n'
        'User: Now explain its complexity. ';
    final requestBody = request.body as Map;
    expect(requestBody['user_instruction'], expectedPrompt);
    expect(
      (requestBody['current_file'] as Map)['content_above_cursor'],
      expectedPrompt,
    );
  });

  test('GitLab Duo rejects unsupported models, protocol shapes and tools', () {
    final builder = LlmNativeRequestBuilder();
    final account = _account('gitlab-limits', 'gitlab-duo', authType: 'pat');
    expect(
      () => builder.build(
        account: account,
        credential: 'gitlab-pat',
        modelId: 'claude-opus-4-6',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    for (final messages in const [
      [
        {'role': 'user', 'content': 'Hello'},
        42,
      ],
      [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'function', 'content': 'hidden response'},
      ],
    ]) {
      expect(
        () => builder.build(
          account: account,
          credential: 'gitlab-pat',
          modelId: 'claude-sonnet-4-6',
          body: {'messages': messages},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    }
    for (final assistantCall in const [
      {
        'function_call': {'name': 'lookup'},
      },
      {'function_call': null},
      {'tool_calls': 'malformed'},
      {
        'functions': [
          {'name': 'lookup'},
        ],
      },
      {'tools': []},
      {'tool_choice': 'none'},
    ]) {
      expect(
        () => builder.build(
          account: account,
          credential: 'gitlab-pat',
          modelId: 'claude-sonnet-4-6',
          body: {
            'messages': [
              {
                'role': 'assistant',
                'content': 'Calling a tool.',
                ...assistantCall,
              },
              {'role': 'user', 'content': 'Continue.'},
            ],
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    }
    for (final role in const ['user', 'system']) {
      expect(
        () => builder.build(
          account: account,
          credential: 'gitlab-pat',
          modelId: 'claude-sonnet-4-6',
          body: {
            'messages': [
              {'role': role, 'content': 'Text', 'tool_calls': []},
            ],
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    }
    expect(
      () => builder.build(
        account: account,
        credential: 'gitlab-pat',
        modelId: 'claude-sonnet-4-6',
        body: const {
          'messages': [
            {
              'role': 'assistant',
              'content': 'Calling a tool.',
              'parallel_tool_calls': true,
            },
            {'role': 'user', 'content': 'Continue.'},
          ],
        },
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(
      () => builder.build(
        account: account,
        credential: 'gitlab-pat',
        modelId: 'claude-sonnet-4-6',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
        nativeFormat: 'openai.responses',
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    for (final unsupportedMetadata in const [
      {'tools': []},
      {'tool_choice': 'none'},
      {'tool_calls': []},
      {'function_call': null},
      {
        'functions': [
          {'name': 'lookup'},
        ],
      },
      {'parallel_tool_calls': true},
      {
        'function_call': {'name': 'lookup'},
      },
    ]) {
      expect(
        () => builder.build(
          account: account,
          credential: 'gitlab-pat',
          modelId: 'claude-sonnet-4-6',
          body: {
            'messages': [
              {'role': 'user', 'content': 'Hello'},
            ],
            ...unsupportedMetadata,
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    }
    expect(
      () => builder.build(
        account: account,
        credential: 'gitlab-pat',
        modelId: 'claude-sonnet-4-6',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'},
            },
          ],
        },
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(
      () => builder.build(
        account: account,
        credential: 'gitlab-pat',
        modelId: 'claude-sonnet-4-6',
        body: const {
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png'},
                },
              ],
            },
          ],
        },
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
  });

  test(
    'GitLab Duo turns its JSON completion into Stroom chat events',
    () async {
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account(
          'gitlab-stream',
          'gitlab-duo',
          authType: 'pat',
          endpointConfig: const {'baseUrl': 'https://gitlab.example.com'},
        ),
        secret: 'gitlab-pat-secret',
      );
      RequestOptions? request;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          request = options;
          return ResponseBody.fromString(
            jsonEncode({
              'model': {'name': 'claude-sonnet-4-6'},
              'choices': [
                {'text': 'GitLab Duo reply'},
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'claude-sonnet-4-6',
        body: const {
          'model': 'claude-sonnet-4-6',
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
        stream: true,
      );

      expect(
        request!.uri.toString(),
        'https://gitlab.example.com/api/v4/code_suggestions/completions',
      );
      expect(request!.headers['Authorization'], 'Bearer gitlab-pat-secret');
      expect(request!.data['stream'], false);
      expect(response.body, isA<Stream<List<int>>>());
      final bytes = await (response.body as Stream<List<int>>).fold<List<int>>(
        [],
        (previous, chunk) => previous..addAll(chunk),
      );
      final events = utf8.decode(bytes);
      expect(events, contains('GitLab Duo reply'));
      expect(events, contains('chat.completion.chunk'));
      expect(events, contains('data: [DONE]'));
    },
  );

  test(
    'GitLab Duo OAuth refresh rotates credentials in secure storage',
    () async {
      RequestOptions? refreshRequest;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          refreshRequest = options;
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'rotated-gitlab-access',
              'refresh_token': 'rotated-gitlab-refresh',
              'expires_in': 3600,
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final credentials = _MemoryCredentials();
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
        dio: dio,
      );
      final account = await accounts.saveAccount(
        _account(
          'gitlab-oauth-refresh',
          'gitlab-duo',
          authType: 'oauth',
          endpointConfig: const {
            'baseUrl': 'https://gitlab.example.com/gitlab',
            'clientId': 'registered-client',
          },
        ),
        secret: jsonEncode({
          'oauth_contract': 'gitlab-duo-pkce-v1',
          'access_token': 'expired-gitlab-access',
          'refresh_token': 'old-gitlab-refresh',
          'expires_at': DateTime.utc(2020).toIso8601String(),
          'client_id': 'registered-client',
          'client_secret': 'registered-secret',
          'base_url': 'https://gitlab.example.com/gitlab',
        }),
      );

      expect(await accounts.refreshCredential(account), isTrue);
      expect(
        refreshRequest!.uri.toString(),
        'https://gitlab.example.com/gitlab/oauth/token',
      );
      expect(
        refreshRequest!.data,
        containsPair('refresh_token', 'old-gitlab-refresh'),
      );
      expect(
        refreshRequest!.data,
        containsPair('client_secret', 'registered-secret'),
      );
      final saved =
          jsonDecode((await credentials.read(account.credentialRef!))!) as Map;
      expect(saved['access_token'], 'rotated-gitlab-access');
      expect(saved['refresh_token'], 'rotated-gitlab-refresh');
      expect(saved['client_secret'], 'registered-secret');
      expect(
        DateTime.parse(saved['expires_at'] as String).isAfter(DateTime.now()),
        isTrue,
      );
    },
  );

  test(
    'Copilot connectors preserve model-specific protocols and auth ownership',
    () {
      for (final connectorId in ['github', 'ghe-copilot']) {
        final connector = LlmConnectorRegistry.find(connectorId)!;
        expect(connector.authTypes, {'oauth'});
        expect(connector.canRefreshCredentials, isTrue);
        expect(
          LlmOAuthProviderPolicy.forProvider(connectorId).supported,
          isTrue,
        );
        expect(
          LlmConnectorRegistry.chatAdapterEndpointType(connectorId),
          'openai',
        );
        expect(
          supportedApiProtocolsForSupplier(null, connectorType: connectorId),
          kCustomHttpApiProtocols,
        );
      }

      final github = _account(
        'github-account',
        'github',
        authType: 'oauth',
        models: [_upstreamModel('gpt-6-astra')],
      );
      final chat = LlmNativeRequestBuilder().build(
        account: github,
        credential: jsonEncode({
          'access_token': 'github-oauth-token',
          'copilot_token': 'github-copilot-token',
        }),
        modelId: 'gpt-6-astra',
        body: const {'model': 'gpt-6-astra', 'messages': [], 'stream': true},
        stream: true,
      );
      expect(
        chat.uri.toString(),
        'https://api.githubcopilot.com/chat/completions',
      );
      expect(chat.headers['Authorization'], 'Bearer github-copilot-token');
      expect(chat.body, {
        'model': 'gpt-6-astra',
        'messages': [],
        'stream': true,
      });

      final responses = LlmNativeRequestBuilder().build(
        account: github,
        credential: jsonEncode({
          'access_token': 'github-oauth-token',
          'copilot_token': 'github-copilot-token',
        }),
        modelId: 'gpt-6-astra',
        body: const {'model': 'gpt-6-astra', 'input': [], 'stream': true},
        stream: true,
        nativeFormat: 'responses',
      );
      expect(
        responses.uri.toString(),
        'https://api.githubcopilot.com/responses',
      );
      final codexDefault = LlmNativeRequestBuilder().build(
        account: _account(
          'github-codex-account',
          'github',
          authType: 'oauth',
          models: [
            LlmUpstreamModel(
              id: 'codex-model',
              upstreamModelId: 'gpt-codex',
              displayName: 'gpt-codex',
              capabilities: const {
                'supportedApiProtocols': ['openai.responses'],
              },
            ),
          ],
        ),
        credential: jsonEncode({
          'access_token': 'github-oauth-token',
          'copilot_token': 'github-copilot-token',
        }),
        modelId: 'gpt-codex',
        body: const {'input': []},
      );
      expect(
        codexDefault.uri.toString(),
        'https://api.githubcopilot.com/responses',
      );

      final claudeDefault = LlmNativeRequestBuilder().build(
        account: _account(
          'github-claude-account',
          'github',
          authType: 'oauth',
          models: [
            LlmUpstreamModel(
              id: 'claude-model',
              upstreamModelId: 'claude-sonnet-5',
              displayName: 'claude-sonnet-5',
              capabilities: const {
                'supportedApiProtocols': ['anthropic.messages'],
              },
            ),
          ],
        ),
        credential: jsonEncode({
          'access_token': 'github-oauth-token',
          'copilot_token': 'github-copilot-token',
        }),
        modelId: 'claude-sonnet-5',
        body: const {'messages': []},
      );
      expect(
        claudeDefault.uri.toString(),
        'https://api.githubcopilot.com/v1/messages',
      );

      final enterprise = LlmNativeRequestBuilder().build(
        account: _account(
          'ghe-account',
          'ghe-copilot',
          authType: 'oauth',
          endpointConfig: const {'gheUrl': 'https://ghe.example.com'},
          models: [_upstreamModel('claude-sonnet-5')],
        ),
        credential: jsonEncode({
          'access_token': 'enterprise-oauth-token',
          'copilot_token': 'enterprise-copilot-token',
          'copilot_api_url': 'https://ghe-api.example.com',
        }),
        modelId: 'claude-sonnet-5',
        body: const {
          'model': 'claude-sonnet-5',
          'messages': [],
          'stream': false,
        },
        stream: false,
        nativeFormat: 'anthropic',
      );
      expect(
        enterprise.uri.toString(),
        'https://ghe-api.example.com/v1/messages',
      );
      expect(
        enterprise.headers['Authorization'],
        'Bearer enterprise-copilot-token',
      );
      expect(enterprise.body, {
        'model': 'claude-sonnet-5',
        'messages': [],
        'stream': true,
      });
      expect(enterprise.headers['Accept'], 'text/event-stream');
    },
  );

  test('expired Copilot token is renewed before Chat dispatch', () async {
    RequestOptions? tokenRequest;
    RequestOptions? oauthRefreshRequest;
    var tokenCalls = 0;
    final refreshDio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        if (options.method == 'POST') {
          oauthRefreshRequest = options;
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'refreshed-github-oauth-token',
              'refresh_token': 'rotated-github-refresh-token',
              'expires_in': 28800,
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        }
        tokenRequest = options;
        tokenCalls++;
        if (tokenCalls == 1) {
          return ResponseBody.fromString(
            jsonEncode({'error': 'bad credentials'}),
            401,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          jsonEncode({
            'token': 'fresh-copilot-token',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
          }),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      });
    final credentials = _MemoryCredentials();
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: credentials,
      dio: refreshDio,
    );
    final account = await accounts.saveAccount(
      _account(
        'github-expired-copilot',
        'github',
        authType: 'oauth',
        models: [_upstreamModel('gpt-6-astra')],
      ),
      secret: jsonEncode({
        'access_token': 'github-oauth-token',
        'refresh_token': 'github-refresh-token',
        'copilot_token': 'expired-copilot-token',
        'expires_at': DateTime.utc(2020).toIso8601String(),
        'copilot_expires_at': DateTime.utc(2020).toIso8601String(),
      }),
    );
    RequestOptions? chatRequest;
    final chatDio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        chatRequest = options;
        return ResponseBody.fromString(
          '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}',
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      });

    await LlmConnectorHttpClient(
      accountService: accounts,
      dio: chatDio,
    ).request(
      account: account,
      modelId: 'gpt-6-astra',
      body: const {'messages': []},
    );

    expect(
      tokenRequest?.uri.toString(),
      'https://api.github.com/copilot_internal/v2/token',
    );
    expect(tokenCalls, 2);
    expect(
      oauthRefreshRequest?.uri.toString(),
      'https://github.com/login/oauth/access_token',
    );
    expect(oauthRefreshRequest?.data, {
      'client_id': 'Iv1.b507a08c87ecfe98',
      'grant_type': 'refresh_token',
      'refresh_token': 'github-refresh-token',
    });
    expect(chatRequest?.headers['Authorization'], 'Bearer fresh-copilot-token');
  });

  test(
    'Enterprise Copilot streaming responses are buffered for nonstream calls',
    () async {
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account(
          'ghe-streaming-only',
          'ghe-copilot',
          authType: 'oauth',
          endpointConfig: const {'gheUrl': 'https://ghe.example.com'},
          models: [_upstreamModel('gpt-6-astra')],
        ),
        secret: jsonEncode({
          'access_token': 'enterprise-oauth-token',
          'copilot_token': 'enterprise-copilot-token',
          'copilot_api_url': 'https://ghe-api.example.com',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );
      RequestOptions? request;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          request = options;
          return ResponseBody.fromString(
            'data: {"id":"chat-1","model":"gpt-6-astra","choices":[{"index":0,"delta":{"content":"hello"},"finish_reason":null}]}\n\n'
            'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
            'data: [DONE]\n\n',
            200,
            headers: const {
              'content-type': ['text/event-stream'],
            },
          );
        });

      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'gpt-6-astra',
        body: const {'messages': [], 'stream': false},
        stream: false,
      );

      expect(request?.headers['Accept'], 'text/event-stream');
      expect(
        (response.body as Map)['choices'][0]['message']['content'],
        'hello',
      );
    },
  );

  test(
    'Enterprise Responses SSE returns the completed Responses object',
    () async {
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account(
          'ghe-responses-sse',
          'ghe-copilot',
          authType: 'oauth',
          endpointConfig: const {'gheUrl': 'https://ghe.example.com'},
          models: [
            LlmUpstreamModel(
              id: 'ghe-responses-model',
              upstreamModelId: 'gpt-6-astra',
              displayName: 'gpt-6-astra',
              capabilities: const {
                'supportedApiProtocols': ['openai.responses'],
              },
            ),
          ],
        ),
        secret: jsonEncode({
          'access_token': 'enterprise-oauth-token',
          'copilot_token': 'enterprise-copilot-token',
          'copilot_api_url': 'https://ghe-api.example.com',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );
      final completedResponse = {
        'id': 'resp_123',
        'object': 'response',
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': 'hello'},
            ],
          },
        ],
      };
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((_) async {
          return ResponseBody.fromString(
            'event: response.completed\n'
            'data: ${jsonEncode({
                  'type': 'response.completed',
                  'response': completedResponse
                })}\n\n'
            'data: [DONE]\n\n',
            200,
            headers: const {
              'content-type': ['text/event-stream'],
            },
          );
        });

      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'gpt-6-astra',
        body: const {'input': []},
        nativeFormat: 'responses',
      );

      expect(response.body, completedResponse);
    },
  );

  test('Cursor unsupported image forms get an inline-only user message', () {
    final error = AiGatewayExecutionException(
      kind: AiGatewayFailureKind.request,
      code: 'cursor_inline_images_only',
    );
    expect(error.toString(), contains('inline PNG, JPEG, GIF, or WebP'));
    expect(error.toString(), contains('Remote URLs'));
  });

  test(
    'Cursor is a provider-owned OAuth adapter, not a selectable API protocol',
    () {
      final connector = LlmConnectorRegistry.find('cursor')!;
      expect(connector.authTypes, {'oauth'});
      expect(connector.protocol, LlmNativeProtocol.cursorAgentConnectRpc);
      expect(connector.canRefreshCredentials, isTrue);
      expect(connector.modelCatalog, hasLength(242));
      expect(connector.modelCatalog, contains('claude-sonnet-5-high'));
      expect(connector.modelCatalog, isNot(contains('claude-sonnet-5-5')));
      expect(
        connector.modelCatalog,
        contains('cursor-grok-4.7-xhigh-fast-500k'),
      );
      expect(connector.modelCatalog, contains('claude-opus-5-thinking-max-1m'));
      expect(
        supportedApiProtocolsForSupplier(null, connectorType: 'cursor'),
        kCustomHttpApiProtocols,
      );
      expect(
        builtinDefaultApiProtocolForConnector('cursor'),
        'openai.chat_completions',
      );

      final request = LlmNativeRequestBuilder().build(
        account: _account(
          'cursor-account',
          'cursor',
          authType: 'oauth',
          models: [_upstreamModel('claude-sonnet-5-high')],
        ),
        credential: jsonEncode({'access_token': 'cursor-secret'}),
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-1',
        body: const {
          'messages': [
            {'role': 'system', 'content': 'Keep the answer concise.'},
            {'role': 'user', 'content': 'hello'},
          ],
        },
      );
      expect(request.uri.origin, 'https://api2.cursor.sh');
      expect(
        request.uri.path,
        '/aiserver.v1.ServerConfigService/GetServerConfig',
      );
      expect(request.headers.keys, isNot(contains('Authorization')));
      expect(request.toString(), isNot(contains('cursor-secret')));
      expect(request.requestBlobs, hasLength(1));
      expect(
        request.requestBlobs.values.single,
        utf8.encode(
          jsonEncode({'role': 'system', 'content': 'Keep the answer concise.'}),
        ),
      );
    },
  );

  test('Cline and ClinePass register distinct OAuth and direct-key owners', () {
    for (final connectorId in ['cline', 'clinepass']) {
      final connector = LlmConnectorRegistry.find(connectorId)!;
      expect(connector.authTypes, {'oauth', 'api_key'});
      expect(connector.protocol, LlmNativeProtocol.openAIChatCompletions);
      expect(connector.canRefreshCredentials, isTrue);
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType(connectorId),
        'openai',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          connectorId,
          'oauth',
        ),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          connectorId,
          'api_key',
        ),
        isTrue,
      );
      expect(LlmOAuthProviderPolicy.forProvider(connectorId).supported, isTrue);
      expect(
        builtinDefaultApiProtocolForConnector(connectorId),
        'openai.chat_completions',
      );
      expect(
        supportedApiProtocolsForSupplier(null, connectorType: connectorId),
        {'openai.chat_completions'},
      );
    }
  });

  test(
    'Cline and ClinePass discovery keeps their separate live model buckets',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          if (options.uri.path.endsWith('/models')) {
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {
                    'id': 'provider/paid-model',
                    'name': 'Paid Model',
                    'architecture': {'modality': 'text->text'},
                  },
                  {
                    'id': 'provider/image-model',
                    'architecture': {'modality': 'text->image'},
                  },
                  {
                    'id': 'cline-pass/subscription-model',
                    'architecture': {'modality': 'text->text'},
                  },
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'recommended': [
                {'id': 'provider/recommended', 'name': 'Recommended'},
              ],
              'free': [
                {'id': 'cline-free/free-model', 'name': 'Free'},
              ],
              'clinePass': [
                {'id': 'cline-pass/subscription-model', 'name': 'Pass Model'},
                {'id': 'provider/wrong-bucket'},
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final cline = await service.saveAccount(
        _account('cline-account', 'cline', authType: 'api_key'),
        secret: 'cline-private-key',
      );
      final clinepass = await service.saveAccount(
        _account('clinepass-account', 'clinepass', authType: 'api_key'),
        secret: 'clinepass-private-key',
      );

      final clineModels = await service.discoverModels(
        cline,
        refreshRemote: true,
      );
      final clinepassModels = await service.discoverModels(
        clinepass,
        refreshRemote: true,
      );

      expect(cline.connectorType, 'cline');
      expect(clinepass.connectorType, 'clinepass');
      expect(clineModels.map((model) => model.upstreamModelId), [
        'provider/recommended',
        'cline-free/free-model',
        'provider/paid-model',
      ]);
      expect(
        clineModels.every((model) => model.capabilities['chat'] == true),
        isTrue,
      );
      expect(
        clineModels.any(
          (model) => model.upstreamModelId.startsWith('cline-pass/'),
        ),
        isFalse,
      );
      expect(clinepassModels.map((model) => model.upstreamModelId), [
        'cline-pass/subscription-model',
      ]);
      expect(requests.map((request) => request.uri.path), [
        '/api/v1/ai/cline/recommended-models',
        '/api/v1/ai/cline/models',
        '/api/v1/ai/cline/recommended-models',
      ]);
      expect(
        requests.every((request) => request.headers['Authorization'] == null),
        isTrue,
      );
      expect(clineModels.toString(), isNot(contains('cline-private-key')));
    },
  );

  test(
    'Cline fallback models retain unknown availability after catalog failure',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        LlmAccount(
          id: 'cline-offline-catalog',
          connectorType: 'cline',
          authType: 'api_key',
          displayName: 'Cline offline catalog',
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: 'saved-cline-model',
              upstreamModelId: kPinnedClineModels.first,
              displayName: 'Saved name',
              capabilities: const {'chat': true},
              config: const {'availability': 'entitled', 'userSetting': 'keep'},
            ),
          ],
        ),
        secret: 'cline-private-key',
      );

      final discovered = await service.discoverModels(
        account,
        refreshRemote: true,
      );
      final fallback = discovered.singleWhere(
        (model) => model.upstreamModelId == kPinnedClineModels.first,
      );

      expect(fallback.id, 'saved-cline-model');
      expect(fallback.displayName, 'Saved name');
      expect(fallback.config['availability'], 'unknown');
      expect(fallback.config['catalogSource'], 'provider-fallback');
      expect(fallback.config['userSetting'], 'keep');
    },
  );

  test('Cline auth shapes route only to streaming Chat Completions', () {
    final builder = LlmNativeRequestBuilder();
    for (final (connectorId, authType, credential, expectedAuthorization) in [
      (
        'cline',
        'oauth',
        jsonEncode({'access_token': 'oauth-secret'}),
        'Bearer workos:oauth-secret',
      ),
      ('cline', 'api_key', 'cline-key-secret', 'Bearer cline-key-secret'),
      (
        'clinepass',
        'oauth',
        jsonEncode({'access_token': 'pass-oauth-secret'}),
        'Bearer workos:pass-oauth-secret',
      ),
      (
        'clinepass',
        'api_key',
        'clinepass-key-secret',
        'Bearer clinepass-key-secret',
      ),
    ]) {
      final request = builder.build(
        account: _account(
          'request-$connectorId-$authType',
          connectorId,
          authType: authType,
        ),
        credential: credential,
        modelId: 'provider/model',
        body: const {
          'model': 'provider/model',
          'messages': [],
          'stream': false,
        },
      );
      expect(
        request.uri.toString(),
        'https://api.cline.bot/api/v1/chat/completions',
      );
      expect(request.headers['Accept'], 'text/event-stream');
      expect((request.body as Map)['stream'], isTrue);
      expect(request.headers['Authorization'], expectedAuthorization);
      expect(request.headers['HTTP-Referer'], 'https://cline.bot');
      expect(request.headers['X-Title'], 'Cline');
      expect(request.toString(), isNot(contains('secret')));
    }
    expect(
      () => builder.build(
        account: _account('cline-responses', 'cline', authType: 'api_key'),
        credential: 'cline-key-secret',
        modelId: 'provider/model',
        body: const {'model': 'provider/model', 'messages': []},
        nativeFormat: 'responses',
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
  });

  test(
    'Cline OAuth refresh uses the WorkOS grant and stores rotated refresh token',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'accessToken': 'fresh-cline-access',
                'refreshToken': 'fresh-cline-refresh',
                'expiresAt': '2026-11-04T12:00:00Z',
              },
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final credentials = _MemoryCredentials();
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
        dio: dio,
      );
      final account = await service.saveAccount(
        _account('cline-refresh', 'cline', authType: 'oauth'),
        secret: jsonEncode({
          'access_token': 'old-cline-access',
          'refresh_token': 'old-cline-refresh',
        }),
      );

      expect(await service.refreshCredential(account), isTrue);

      expect(
        captured?.uri.toString(),
        'https://api.cline.bot/api/v1/auth/refresh',
      );
      expect(captured?.method, 'POST');
      expect(captured?.contentType, Headers.jsonContentType);
      expect(captured?.data, {
        'refreshToken': 'old-cline-refresh',
        'grantType': 'refresh_token',
        'clientType': 'extension',
      });
      final stored = jsonDecode(
        await service.readCredential(account.id) ?? '{}',
      );
      expect(stored['access_token'], 'fresh-cline-access');
      expect(stored['refresh_token'], 'fresh-cline-refresh');
    },
  );

  test(
    'Qoder PAT model discovery uses qodercli with the account token',
    () async {
      final runner = _QoderModelListRunner();
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        qoderCliService: QoderCliService(runner: runner),
      );
      final account = await service.saveAccount(
        _account('qoder-cli-catalog', 'qoder', authType: 'pat'),
        secret: 'pt-account-token',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(
        runner.lastEnvironment['QODER_PERSONAL_ACCESS_TOKEN'],
        'pt-account-token',
      );
      expect(runner.lastArguments, contains('--list-models'));
      expect(models.map((model) => model.upstreamModelId), [
        'qwen3.8-max-preview',
      ]);
      expect(models.single.config['catalogSource'], 'qodercli');
    },
  );

  test(
    'Kilo anonymous discovery filters while account discovery stays scoped',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'openrouter/free', 'name': 'Free model router'},
                {'id': 'openai/gpt-5.6-sol', 'name': 'Account model'},
              ],
            }),
            200,
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final anonymous = await service.saveAccount(
        _account('kilo-anon-catalog', 'kilocode', authType: 'none'),
      );
      final anonymousModels = await service.discoverModels(
        anonymous,
        refreshRemote: true,
      );
      final account = await service.saveAccount(
        _account('kilo-key-catalog', 'kilocode', authType: 'api_key'),
        secret: 'kilo-account-key',
      );
      final accountModels = await service.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(requests.map((request) => request.uri.path), [
        '/api/openrouter/models',
        '/api/openrouter/models',
      ]);
      expect(requests.first.headers['Authorization'], 'Bearer anonymous');
      expect(requests.first.headers['X-KILOCODE-EDITORNAME'], 'Stroom');
      expect(requests.last.headers['Authorization'], 'Bearer kilo-account-key');
      expect(anonymousModels.map((model) => model.upstreamModelId), [
        'openrouter/free',
      ]);
      expect(accountModels.map((model) => model.upstreamModelId), [
        'openrouter/free',
        'openai/gpt-5.6-sol',
      ]);
    },
  );
  group('LlmConnectorRegistry', () {
    test('Cloudflare Workers AI discovery returns its pinned static catalog',
        () async {
      var networkRequests = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          networkRequests++;
          throw StateError('Workers AI has no model-list endpoint.');
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        _account(
          'cloudflare-catalog',
          'cloudflare-ai',
          endpointConfig: const {'cloudflareAccountId': 'cf-account-id'},
        ),
        secret: 'synthetic-token',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(networkRequests, 0);
      expect(models.map((model) => model.upstreamModelId),
          kCloudflareWorkersAiModelIds);
      for (final model in models) {
        expect(model.capabilities.keys, {'contextLength'});
        expect(model.capabilities['contextLength'],
            kCloudflareWorkersAiModelContextLengths[model.upstreamModelId]);
      }
    });

    test('registers UncloseAI as an optional-key OpenAI chat connector', () {
      final connector = LlmConnectorRegistry.find('uncloseai');

      expect(connector, isNotNull);
      expect(connector!.displayName, 'UncloseAI');
      expect(connector.authTypes, {'none', 'api_key'});
      expect(connector.protocol, LlmNativeProtocol.openAIChatCompletions);
      expect(connector.modelCatalog, ['turboderp/Qwen3.8-27B-exl3']);
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('uncloseai'),
        'openai',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'uncloseai',
          'none',
        ),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'uncloseai',
          'api_key',
        ),
        isTrue,
      );
      expect(
        LlmChatRoutingRuntime.defaultProviderCatalog
            .findProvider('uncloseai')
            ?.displayName,
        'UncloseAI',
      );
    });

    test('prepares UncloseAI chat requests with optional bearer auth', () {
      final builder = LlmNativeRequestBuilder();
      final anonymous = builder.build(
        account: _account('uncloseai-anonymous', 'uncloseai', authType: 'none'),
        credential: null,
        modelId: 'turboderp/Qwen3.8-27B-exl3',
        body: const {'model': 'turboderp/Qwen3.8-27B-exl3', 'messages': []},
        stream: true,
      );
      final keyed = builder.build(
        account: _account('uncloseai-key', 'uncloseai'),
        credential: 'identifier-only-key',
        modelId: 'turboderp/Qwen3.8-27B-exl3',
        body: const {'model': 'turboderp/Qwen3.8-27B-exl3', 'messages': []},
      );

      expect(
        anonymous.uri.toString(),
        'https://hermes.ai.unturf.com/v1/chat/completions',
      );
      expect(anonymous.headers['Authorization'], isNull);
      expect((anonymous.body as Map)['model'], 'turboderp/Qwen3.8-27B-exl3');
      expect(
        keyed.uri.toString(),
        'https://hermes.ai.unturf.com/v1/chat/completions',
      );
      expect(keyed.headers['Authorization'], 'Bearer identifier-only-key');
      expect((keyed.body as Map)['model'], 'turboderp/Qwen3.8-27B-exl3');
      expect(
        () => builder.build(
          account: _account('uncloseai-responses', 'uncloseai'),
          credential: 'identifier-only-key',
          modelId: 'turboderp/Qwen3.8-27B-exl3',
          body: const {'model': 'turboderp/Qwen3.8-27B-exl3'},
          nativeFormat: 'responses',
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test(
      'discovers the rotating UncloseAI roster and model contexts',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'turboderp/Qwen3.8-27B-exl3', 'max_model_len': 98304},
                  {'id': 'future/rotated-chat', 'max_model_len': 49152},
                  {'id': 'future/default-window'},
                  {'id': 'text-embedding-v4'},
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'uncloseai-discovery',
            'uncloseai',
            authType: 'none',
            models: [
              LlmUpstreamModel(
                id: 'saved-current-model',
                upstreamModelId: 'turboderp/Qwen3.8-27B-exl3',
                displayName: 'Saved model label',
                capabilities: const {'contextLength': 65536},
              ),
              _upstreamModel('old/retired-model'),
            ],
          ),
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(
          captured?.uri.toString(),
          'https://hermes.ai.unturf.com/v1/models',
        );
        expect(captured?.headers['Authorization'], isNull);
        expect(models.map((model) => model.upstreamModelId), [
          'turboderp/Qwen3.8-27B-exl3',
          'future/rotated-chat',
          'future/default-window',
        ]);
        expect(models.first.capabilities['contextLength'], 98304);
        expect(models[1].capabilities['contextLength'], 49152);
        expect(models[2].capabilities['contextLength'], 65536);
        expect(models.first.id, 'saved-current-model');
        expect(models.first.displayName, 'Saved model label');
        for (final model in models) {
          expect(model.capabilities['supportedApiProtocols'], [
            'openai.chat_completions',
          ]);
        }
      },
    );

    test('uses the pinned UncloseAI seed until refresh is requested', () async {
      var requested = false;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requested = true;
          throw StateError('Unexpected model discovery request.');
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        _account('uncloseai-seed', 'uncloseai', authType: 'none'),
      );

      final models = await service.discoverModels(account);

      expect(requested, isFalse);
      expect(models.single.upstreamModelId, 'turboderp/Qwen3.8-27B-exl3');
      expect(models.single.capabilities['contextLength'], 65536);
      expect(models.single.capabilities['supportedApiProtocols'], [
        'openai.chat_completions',
      ]);
    });

    test(
      'stores and uses an optional UncloseAI key only in secure storage',
      () async {
        RequestOptions? captured;
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'future/rotated-chat'},
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
          _account('uncloseai-keyed-discovery', 'uncloseai'),
          secret: 'identifier-only-key',
        );

        await service.discoverModels(account, refreshRemote: true);

        expect(
          captured?.uri.toString(),
          'https://hermes.ai.unturf.com/v1/models',
        );
        expect(
          captured?.headers['Authorization'],
          'Bearer identifier-only-key',
        );
        expect(await service.readCredential(account.id), 'identifier-only-key');
        expect(
          preferences.values.values.join(),
          isNot(contains('identifier-only-key')),
        );
      },
    );

    test(
      'reports UncloseAI discovery errors rather than stale models',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter(
            (options) async =>
                ResponseBody.fromString('{"error":"unavailable"}', 503),
          );
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'uncloseai-error',
            'uncloseai',
            authType: 'none',
            models: [_upstreamModel('stale/model')],
          ),
        );

        await expectLater(
          service.discoverModels(account, refreshRemote: true),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );

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
          'kimi-coding',
          'xai',
          'grok-cli',
          'xai-oauth',
          'devin',
          'devin-cli-agentic',
          'meta',
          'muse-code',
          'codebuddy-cn',
          'codebuddy-intl',
          'workbuddy',
          'qoder',
          'gemini',
          'gemini-interactions',
          'aistudio',
          'vertex',
          'openai-compatibility',
          'opencode-go',
          'opencode-zen',
          'command-code',
          'ollama',
          'glm-cn',
          'minimax-cn',
          'qwen-cloud',
          'qwen-cloud-token-plan',
          'kilocode',
          'openference',
          'openference-api',
        }),
      );
      final kilo = LlmConnectorRegistry.find('kilocode')!;
      expect(kilo.authTypes, {'oauth', 'api_key', 'none'});
      expect(kilo.canRefreshCredentials, isFalse);
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported('kilocode', 'none'),
        isTrue,
      );
      expect(
        kKiloCodeAnonymousFreeModelIds,
        {'openrouter/free'},
        reason: 'anonymous fallback must be limited to the pinned free router',
      );
      final qoder = LlmConnectorRegistry.find('qoder')!;
      expect(qoder.authTypes, containsAll({'api_key', 'oauth', 'pat'}));
      expect(qoder.modelCatalog, contains('qwen3.8-max-preview'));
      expect(qoder.canRefreshCredentials, isFalse);
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported('qoder', 'pat'),
        isTrue,
      );
      expect(LlmConnectorRegistry.find('gemini-cli'), isNull);
      expect(LlmConnectorRegistry.find('glmt'), isNull);
      expect(LlmConnectorRegistry.canonicalId('glmt'), 'glm');
      for (final (id, label) in [
        ('glm-cn', 'GLM Coding (China)'),
        ('minimax-cn', 'MiniMax (China)'),
        ('qwen-cloud', 'Qwen Cloud'),
        ('qwen-cloud-token-plan', 'Qwen Cloud Token Plan'),
      ]) {
        final connector = LlmConnectorRegistry.find(id)!;
        expect(connector.displayName, label, reason: id);
        expect(connector.authTypes, {'api_key'}, reason: id);
        expect(
          LlmConnectorRegistry.chatAdapterEndpointType(id),
          'openai',
          reason: id,
        );
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(id, 'api_key'),
          isTrue,
          reason: id,
        );
      }
      expect(LlmConnectorRegistry.find('devin-cli-agentic')!.authTypes, {
        'cli_session',
      });
      expect(
        LlmConnectorRegistry.find('devin-cli-agentic')!.protocol,
        LlmNativeProtocol.devinCliAcp,
      );
      expect(LlmConnectorRegistry.find('devin-cli-agentic')!.modelCatalog, [
        'devin-cli-default',
      ]);
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('devin-cli-agentic'),
        'devin.acp',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'devin-cli-agentic',
          'cli_session',
        ),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'devin',
          'cli_session',
        ),
        isFalse,
        reason: 'CLI login state must remain distinct from Devin OAuth',
      );
      expect(LlmConnectorRegistry.find('kimi-coding')!.authTypes, {'oauth'});
      expect(LlmConnectorRegistry.find('meta')!.authTypes, {'api_key'});
      for (final (id, label) in [
        ('opencode-go', 'OpenCode Go'),
        ('opencode-zen', 'OpenCode Zen'),
      ]) {
        final connector = LlmConnectorRegistry.find(id)!;
        expect(connector.displayName, label, reason: id);
        expect(connector.authTypes, {'api_key'}, reason: id);
        expect(LlmConnectorRegistry.chatAdapterEndpointType(id), 'openai');
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(id, 'api_key'),
          isTrue,
        );
      }
      expect(LlmConnectorRegistry.find('muse-code')!.authTypes, {'oauth'});
      expect(LlmConnectorRegistry.find('muse-code')!.modelCatalog.toSet(), {
        'muse-spark-1.3',
        'muse-spark-1.3-contributor',
        'muse-spark-1.2',
        'muse-spark-1.2-contributor',
        'muse-spark-1.1',
      });
      expect(LlmOAuthProviderPolicy.forProvider('muse-code').supported, isTrue);
      for (final connector in ['codebuddy-cn', 'codebuddy-intl']) {
        expect(LlmConnectorRegistry.find(connector)!.authTypes, {
          'oauth',
          'api_key',
        });
        expect(LlmOAuthProviderPolicy.forProvider(connector).supported, isTrue);
        expect(
          LlmConnectorRegistry.chatAdapterEndpointType(connector),
          'openai',
        );
      }
      expect(LlmConnectorRegistry.find('workbuddy')!.authTypes, {'oauth'});
      expect(LlmOAuthProviderPolicy.forProvider('workbuddy').supported, isTrue);
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('workbuddy'),
        'openai',
      );
      expect(LlmOAuthProviderPolicy.forProvider('devin').supported, isTrue);
      expect(LlmOAuthProviderPolicy.forProvider('meta').supported, isFalse);
      expect(
        LlmOAuthProviderPolicy.forProvider('kimi-coding').supported,
        isTrue,
      );
      expect(
        LlmOAuthProviderPolicy.forProvider('kimi').supported,
        isFalse,
        reason:
            'Kimi Code OAuth must stay distinct from legacy Kimi account IDs',
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('kimi-coding'),
        'openai',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'kimi-coding',
          'oauth',
        ),
        isTrue,
      );
      expect(LlmConnectorRegistry.find('kimi-coding')!.modelCatalog.toSet(), {
        'kimi-for-coding',
        'kimi-for-coding-highspeed',
      });
      expect(LlmConnectorRegistry.find('KIMI.AI')?.id, 'kimi.ai');
      expect(LlmConnectorRegistry.find('anthropic')?.id, 'claude');
      expect(LlmConnectorRegistry.find('openai')?.id, 'openai-compatibility');
      expect(
        LlmConnectorRegistry.find('kimi.ai')?.quotaAvailability,
        LlmQuotaAvailability.unknown,
      );
      final grokBuild = LlmConnectorRegistry.find('grok-cli')!;
      final xaiOAuth = LlmConnectorRegistry.find('xai-oauth')!;
      expect(grokBuild.authTypes, {'oauth'});
      expect(xaiOAuth.authTypes, {'oauth'});
      expect(LlmConnectorRegistry.find('xai')!.authTypes, {'api_key'});
      expect(grokBuild.modelCatalog, contains('grok-4.7'));
      expect(grokBuild.modelCatalog, isNot(contains('grok-build-0.1')));
      expect(grokBuild.modelCatalog, isNot(contains('grok-3-mini')));
      expect(xaiOAuth.modelCatalog, isEmpty);
      expect(LlmOAuthProviderPolicy.forProvider('grok-cli').supported, isTrue);
      expect(LlmOAuthProviderPolicy.forProvider('xai-oauth').supported, isTrue);
      expect(LlmOAuthProviderPolicy.forProvider('xai').supported, isFalse);
      expect(LlmConnectorRegistry.find('openference')!.authTypes, {'oauth'});
      expect(LlmConnectorRegistry.find('openference-api')!.authTypes, {
        'api_key',
      });
      for (final id in ['openference', 'openference-api']) {
        expect(LlmConnectorRegistry.chatAdapterEndpointType(id), 'openai');
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            id,
            id == 'openference' ? 'oauth' : 'api_key',
          ),
          isTrue,
        );
        expect(LlmConnectorRegistry.find(id)!.modelCatalog, [
          'GLM-5.2',
          'Qwen3.8 27b',
          'Llama 3.2 3B',
        ]);
      }
      expect(
        LlmOAuthProviderPolicy.forProvider('openference').supported,
        isTrue,
      );
      expect(
        LlmOAuthProviderPolicy.forProvider('openference-api').supported,
        isFalse,
      );
      expect(
        builtinDefaultApiProtocolForConnector('openference'),
        'openai.chat_completions',
      );
      expect(
        builtinDefaultApiProtocolForConnector('openference-api'),
        'openai.chat_completions',
      );
      expect(
        supportedApiProtocolsForSupplier(null, connectorType: 'openference'),
        {'openai.chat_completions', 'openai.responses'},
      );
      for (final id in {'grok-cli', 'xai-oauth'}) {
        expect(LlmConnectorRegistry.chatAdapterEndpointType(id), 'openai');
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(id, 'oauth'),
          isTrue,
        );
      }
    });

    test(
      'Devin CLI catalog models advertise only chat and streaming',
      () async {
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final models = await service.discoverModels(
          LlmAccount(
            id: 'devin-cli-catalog',
            connectorType: 'devin-cli-agentic',
            authType: 'cli_session',
            displayName: 'Devin CLI',
          ),
        );

        expect(models.map((model) => model.upstreamModelId), [
          'devin-cli-default',
        ]);
        expect(models.single.capabilities, {'chat': true, 'streaming': true});
      },
    );

    test(
      'Muse OAuth catalog stays account-scoped and source-limited',
      () async {
        RequestOptions? catalogRequest;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            catalogRequest = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'muse-spark-1.3'},
                  {'id': 'muse-private-preview'},
                  {'id': 'text-embedding-3-large'},
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          LlmAccount(
            id: 'muse-catalog',
            connectorType: 'muse-code',
            authType: 'oauth',
            displayName: 'Muse',
            models: [
              const LlmUpstreamModel(
                id: 'saved-stale-model',
                upstreamModelId: 'muse-spark-1.1',
                displayName: 'Stale saved model',
              ),
            ],
          ),
          secret: jsonEncode({'api_key': 'muse-key'}),
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(models.map((model) => model.upstreamModelId), [
          'muse-spark-1.3',
        ]);
        expect(catalogRequest?.uri.toString(), 'https://api.meta.ai/v1/models');
        expect(catalogRequest?.headers['Authorization'], 'Bearer muse-key');
        expect(models.single.capabilities, {'chat': true, 'streaming': true});
      },
    );

    test('registers the approved API-key providers with honest auth types', () {
      final expectedApiKeyProviders = {
        'openai-api',
        'claude',
        'gemini',
        'aistudio',
        'xai',
        'meta',
        'moonshot',
        'glm',
        'deepseek',
        'minimax',
        'qwen',
      };

      for (final id in expectedApiKeyProviders) {
        final connector = LlmConnectorRegistry.find(id);
        expect(connector, isNotNull, reason: '$id must be addable');
        expect(connector!.authTypes, contains('api_key'), reason: id);
      }

      for (final id in {
        'openai-api',
        'moonshot',
        'glm',
        'deepseek',
        'minimax',
        'qwen',
      }) {
        expect(
          LlmConnectorRegistry.chatAdapterEndpointType(id),
          'openai',
          reason: '$id must be selectable for internal Chat and Task Flow',
        );
      }

      expect(LlmConnectorRegistry.find('gemini')!.authTypes, {
        'api_key',
        'oauth',
      });
      expect(LlmConnectorRegistry.find('claude')!.authTypes, {
        'api_key',
        'oauth',
        'setup_token',
      });
      expect(LlmOAuthProviderPolicy.forProvider('claude').supported, isTrue);
      for (final authType in ['oauth', 'setup_token']) {
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            'claude',
            authType,
          ),
          isTrue,
        );
      }
      expect(LlmConnectorRegistry.find('aistudio')!.authTypes, {
        'api_key',
        'oauth',
      });
      expect(
        LlmConnectorRegistry.find('aistudio')!.protocol,
        LlmNativeProtocol.geminiGenerateContent,
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('codex'),
        'openai',
        reason: 'Codex OAuth must be addable to Chat and Task Flow groups',
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('openai-api'),
        'openai',
        reason: 'OpenAI API-key Chat Completions remains separate',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported('codex', 'oauth'),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported('codex', 'api_key'),
        isFalse,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'openai-api',
          'api_key',
        ),
        isTrue,
      );
      for (final connector in ['xai', 'meta']) {
        expect(
          LlmConnectorRegistry.chatAdapterEndpointType(connector),
          'openai',
          reason: '$connector API keys share the OpenAI ChatAdapter boundary',
        );
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            connector,
            'api_key',
          ),
          isTrue,
          reason: connector,
        );
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            connector,
            'oauth',
          ),
          isFalse,
          reason:
              'subscription credentials must not enter the public API route',
        );
      }
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('aistudio'),
        'google.gemini.generate_content',
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('claude'),
        'anthropic',
      );
      expect(LlmConnectorRegistry.find('bedrock'), isNotNull);
      expect(LlmConnectorRegistry.chatAdapterEndpointType('bedrock'), 'openai');
      expect(
        LlmConnectorRegistry.find('bedrock')!.authTypes,
        contains('api_key'),
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'bedrock',
          'api_key',
        ),
        isTrue,
        reason: 'Bedrock API keys must use the shared Chat and Task Flow route',
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('gemini'),
        'google.gemini.generate_content',
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('gemini-interactions'),
        'google.gemini.interactions',
      );
      expect(LlmConnectorRegistry.find('ollama')!.authTypes, {
        'none',
        'api_key',
      });
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('ollama'),
        'ollama.chat',
      );
      expect(
        LlmConnectorRegistry.find('vertex')!.authTypes,
        containsAll({'api_key', 'service_account'}),
      );
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('vertex'),
        'google.gemini.generate_content',
        reason: 'Vertex models must be routable through Chat and Task Flow',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'vertex',
          'service_account',
        ),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'vertex',
          'api_key',
        ),
        isTrue,
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported('vertex', 'oauth'),
        isFalse,
      );
      expect(
        LlmConnectorRegistry.find('vertex')!.authTypes,
        isNot(contains('oauth')),
      );
    });

    test('pinned Vertex catalog excludes embedding and rerank models', () {
      final vertex = LlmConnectorRegistry.find('vertex')!;

      expect(
        vertex.modelCatalog.every(
          (id) =>
              !RegExp(r'embedding|rerank', caseSensitive: false).hasMatch(id),
        ),
        isTrue,
      );
      expect(vertex.modelCatalog, contains('imagen-4.0-generate-001'));
    });

    test('Command Code is a ChatAdapter API-key account mode', () {
      final connector = LlmConnectorRegistry.find('command-code')!;
      expect(connector.displayName, 'Command Code');
      expect(connector.authTypes, {'api_key'});
      expect(
        LlmConnectorRegistry.chatAdapterEndpointType('command-code'),
        'openai',
      );
      expect(
        LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
          'command-code',
          'api_key',
        ),
        isTrue,
      );
    });
  });

  group('Openference OAuth and API-key connector modes', () {
    test(
      'discovers conversational models through each bearer auth mode',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'qwen/Qwen3.8', 'name': 'Qwen 3.8'},
                  {
                    'id': 'GLM-5.2',
                    'capabilities': {'chat': true},
                  },
                  {
                    'id': 'text-embedding-v4',
                    'capabilities': {'embedding': true},
                  },
                  {
                    'id': 'reranker-v3',
                    'capabilities': {'chat': false},
                  },
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final service = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );

        for (final (id, authType, secret, expectedHeader) in [
          (
            'openference-oauth',
            'oauth',
            jsonEncode({'access_token': 'oauth-secret-token'}),
            'Bearer oauth-secret-token',
          ),
          (
            'openference-api-key',
            'api_key',
            'sk-private-key',
            'Bearer sk-private-key',
          ),
        ]) {
          final account = await service.saveAccount(
            _account(
              id,
              id == 'openference-oauth' ? 'openference' : 'openference-api',
              authType: authType,
            ),
            secret: secret,
          );
          final models = await service.discoverModels(
            account,
            refreshRemote: true,
          );

          expect(
            requests.last.uri.toString(),
            'https://api.openference.com/v1/models',
          );
          expect(requests.last.headers['Authorization'], expectedHeader);
          expect(models.map((model) => model.upstreamModelId), [
            'qwen/Qwen3.8',
            'GLM-5.2',
          ]);
          expect(models.map((model) => model.capabilities), [
            {'chat': true, 'streaming': true},
            {'chat': true, 'streaming': true},
          ]);
          expect(jsonEncode(account.toMap()), isNot(contains('private-key')));
          expect(
            jsonEncode(account.toMap()),
            isNot(contains('oauth-secret-token')),
          );
          expect(
            preferences.values.values.join(),
            isNot(contains('sk-private-key')),
          );
          expect(
            preferences.values.values.join(),
            isNot(contains('oauth-secret-token')),
          );
        }
        expect(requests, hasLength(2));
      },
    );

    test(
      'uses source-backed Chat Completions and Responses bearer endpoints',
      () {
        for (final (connector, authType) in [
          ('openference', 'oauth'),
          ('openference-api', 'api_key'),
        ]) {
          final account = _account(
            'request-$connector',
            connector,
            authType: authType,
          );
          for (final (format, path) in [
            (null, '/v1/chat/completions'),
            ('responses', '/v1/responses'),
          ]) {
            final request = LlmNativeRequestBuilder().build(
              account: account,
              credential: 'provider-secret',
              modelId: 'qwen/Qwen3.8',
              body: const {'model': 'qwen/Qwen3.8', 'messages': []},
              stream: true,
              nativeFormat: format,
            );
            expect(request.uri.toString(), 'https://api.openference.com$path');
            expect(request.headers['Authorization'], 'Bearer provider-secret');
            expect((request.body as Map)['stream'], isTrue);
          }
        }
      },
    );

    test(
      'uses the source fallback list when live entitlement discovery fails',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            throw DioException(
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 402,
                data: {'error': 'plan-required'},
              ),
            );
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'openference-fallback',
            'openference-api',
            models: const [
              LlmUpstreamModel(
                id: 'saved-glm-mapping',
                upstreamModelId: 'GLM-5.2',
                displayName: 'My GLM label',
                config: {
                  'catalogSource': 'stale-live-catalog',
                  'availability': 'available',
                },
              ),
              LlmUpstreamModel(
                id: 'saved-custom-model',
                upstreamModelId: 'custom-model',
                displayName: 'My custom model',
              ),
            ],
          ),
          secret: 'private-api-key',
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        const fallbackIds = {'GLM-5.2', 'Qwen3.8 27b', 'Llama 3.2 3B'};
        final fallbackModels = models
            .where((model) => fallbackIds.contains(model.upstreamModelId))
            .toList();
        expect(fallbackModels.map((model) => model.upstreamModelId), [
          'GLM-5.2',
          'Qwen3.8 27b',
          'Llama 3.2 3B',
        ]);
        expect(
          fallbackModels.every(
            (model) => model.config['availability'] == 'unknown',
          ),
          isTrue,
        );
        expect(
          fallbackModels.every(
            (model) => model.config['catalogSource'] == 'provider-fallback',
          ),
          isTrue,
        );
        final savedGlm = models.singleWhere(
          (model) => model.upstreamModelId == 'GLM-5.2',
        );
        expect(savedGlm.id, 'saved-glm-mapping');
        expect(savedGlm.displayName, 'My GLM label');
        expect(savedGlm.config['availability'], 'unknown');
        expect(savedGlm.config['catalogSource'], 'provider-fallback');
        expect(
          models.singleWhere(
            (model) => model.upstreamModelId == 'custom-model',
          ),
          isNotNull,
        );
        expect(
          jsonEncode(models.map((model) => model.toMap()).toList()),
          isNot(contains('private-api-key')),
        );
      },
    );

    test(
      'refresh rotates the one-time OAuth refresh token without leaking it',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'rotated-access-token',
                'refresh_token': 'oar-rotated-token',
                'expires_in': 3600,
              }),
              200,
            );
          });
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final service = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await service.saveAccount(
          _account('openference-refresh', 'openference', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'old-access-token',
            'refresh_token': 'oar-one-time-token',
          }),
        );

        expect(await service.refreshCredential(account), isTrue);
        expect(captured?.uri.toString(), 'https://openference.com/oauth/token');
        expect(captured?.contentType, Headers.formUrlEncodedContentType);
        expect(_requestForm(captured?.data), {
          'grant_type': 'refresh_token',
          'client_id': 'omniroute',
          'refresh_token': 'oar-one-time-token',
        });
        final stored =
            jsonDecode((await service.readCredential(account.id))!) as Map;
        expect(stored['access_token'], 'rotated-access-token');
        expect(stored['refresh_token'], 'oar-rotated-token');
        expect(
          preferences.values.values.join(),
          isNot(contains('oar-one-time-token')),
        );
      },
    );

    test(
      'retries a 401 once with the rotated Openference OAuth token',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            if (options.uri.host == 'openference.com') {
              return ResponseBody.fromString(
                jsonEncode({
                  'access_token': 'new-openference-access',
                  'refresh_token': 'oar-new-token',
                  'expires_in': 3600,
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            if (requests
                    .where(
                      (request) => request.uri.host == 'api.openference.com',
                    )
                    .length ==
                1) {
              return ResponseBody.fromString(
                '{"error":"invalid_token"}',
                401,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
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
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('openference-401-refresh', 'openference', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'old-openference-access',
            'refresh_token': 'oar-old-token',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          }),
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        await client.request(
          account: account,
          modelId: 'GLM-5.2',
          body: const {'model': 'GLM-5.2', 'messages': []},
        );

        final chatRequests = requests
            .where((request) => request.uri.host == 'api.openference.com')
            .toList();
        expect(chatRequests, hasLength(2));
        expect(
          chatRequests.first.headers['Authorization'],
          'Bearer old-openference-access',
        );
        expect(
          chatRequests.last.headers['Authorization'],
          'Bearer new-openference-access',
        );
        final refreshRequest = requests.singleWhere(
          (request) => request.uri.host == 'openference.com',
        );
        expect(
          _requestForm(refreshRequest.data)['refresh_token'],
          'oar-old-token',
        );
        final saved =
            jsonDecode((await accounts.readCredential(account.id))!) as Map;
        expect(saved['refresh_token'], 'oar-new-token');
      },
    );
  });

  group('OpenCode Go and Zen account modes', () {
    test('requires HTTPS for custom account endpoints', () {
      for (final connectorType in ['opencode-go', 'opencode-zen']) {
        expect(
          () => LlmNativeRequestBuilder().build(
            account: LlmAccount(
              id: 'insecure-$connectorType',
              connectorType: connectorType,
              authType: 'api_key',
              displayName: connectorType,
              endpointConfig: const {'baseUrl': 'http://localhost:1234/v1'},
            ),
            credential: 'private-$connectorType-key',
            modelId: 'model',
            body: const {'model': 'model', 'messages': []},
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      }
    });

    test(
      'discovers each account catalog with its own endpoint and key',
      () async {
        for (final (connectorType, expectedUrl) in [
          ('opencode-go', 'https://opencode.ai/zen/go/v1/models'),
          ('opencode-zen', 'https://opencode.ai/zen/v1/models'),
        ]) {
          RequestOptions? captured;
          final dio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              captured = options;
              return ResponseBody.fromString(
                jsonEncode({
                  'data': [
                    {
                      'id': 'catalog-model',
                      'capabilities': {'chat': true, 'streaming': true},
                    },
                    {
                      'id': 'vision-model',
                      'capabilities': {'vision': true},
                    },
                    {'id': 'model-with-unknown-capabilities'},
                    {'id': 'gemini-3.1-pro'},
                    {'id': 'jev-score-model'},
                    {'id': 'text-embedding-v4'},
                  ],
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });
          final preferences = _MemoryPreferences();
          final service = LlmAccountConnectorService(
            preferences: preferences,
            credentialStore: _MemoryCredentials(),
            dio: dio,
          );
          final account = await service.saveAccount(
            _account('catalog-$connectorType', connectorType),
            secret: 'private-$connectorType-key',
          );

          final models = await service.discoverModels(
            account,
            refreshRemote: true,
          );

          expect(captured?.uri.toString(), expectedUrl);
          expect(
            captured?.headers['Authorization'],
            'Bearer private-$connectorType-key',
          );
          expect(
            await service.readCredential(account.id),
            'private-$connectorType-key',
          );
          expect(
            jsonEncode(account.toMap()),
            isNot(contains('private-$connectorType-key')),
          );
          expect(
            preferences.values.values.join(),
            isNot(contains('private-$connectorType-key')),
          );
          expect(models.map((model) => model.upstreamModelId), [
            'catalog-model',
            'vision-model',
            'model-with-unknown-capabilities',
          ]);
          expect(models[0].capabilities, {'chat': true, 'streaming': true});
          expect(models[1].capabilities, {
            'chat': true,
            'streaming': true,
            'vision': true,
          });
          expect(models[2].capabilities, {'chat': true, 'streaming': true});
        }
      },
    );

    test('builds all verified protocol requests on each provider endpoint', () {
      const cases = [
        (
          'opencode-go',
          'openai.chat_completions',
          'https://opencode.ai/zen/go/v1/chat/completions',
        ),
        (
          'opencode-go',
          'openai.responses',
          'https://opencode.ai/zen/go/v1/responses',
        ),
        (
          'opencode-go',
          'anthropic.messages',
          'https://opencode.ai/zen/go/v1/messages',
        ),
        (
          'opencode-zen',
          'openai.chat_completions',
          'https://opencode.ai/zen/v1/chat/completions',
        ),
        (
          'opencode-zen',
          'openai.responses',
          'https://opencode.ai/zen/v1/responses',
        ),
        (
          'opencode-zen',
          'anthropic.messages',
          'https://opencode.ai/zen/v1/messages',
        ),
      ];
      for (final (connectorType, protocol, expectedUrl) in cases) {
        final account = _account('request-$connectorType', connectorType);
        final request = LlmNativeRequestBuilder().build(
          account: account,
          credential: 'private-$connectorType-key',
          modelId: 'catalog-model',
          body: const {'model': 'catalog-model', 'messages': []},
          stream: true,
          nativeFormat: switch (protocol) {
            'openai.responses' => 'responses',
            'anthropic.messages' => 'anthropic',
            _ => null,
          },
        );
        expect(request.uri.toString(), expectedUrl, reason: protocol);
        expect((request.body as Map)['stream'], isTrue, reason: protocol);
        expect(
          protocol == 'anthropic.messages'
              ? request.headers['x-api-key']
              : request.headers['Authorization'],
          protocol == 'anthropic.messages'
              ? 'private-$connectorType-key'
              : 'Bearer private-$connectorType-key',
        );
      }
    });

    test('blocks models that require a separate provider-specific API', () {
      for (final connectorType in ['opencode-go', 'opencode-zen']) {
        for (final modelId in ['gemini-3.1-pro', 'jev-score-model']) {
          expect(
            () => LlmNativeRequestBuilder().build(
              account: _account('unsupported-$connectorType', connectorType),
              credential: 'private-$connectorType-key',
              modelId: modelId,
              body: {'model': modelId, 'messages': []},
            ),
            throwsA(isA<LlmAccountConnectorException>()),
          );
        }
      }
    });

    test(
      'rejects a failed catalog request without exposing key material',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromString(
              '{"error":"private-opencode-key is invalid"}',
              401,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account('failed-opencode', 'opencode-go'),
          secret: 'private-opencode-key',
        );

        try {
          await service.discoverModels(account, refreshRemote: true);
          fail('Expected the rejected catalog request to fail.');
        } on LlmAccountConnectorException catch (error) {
          expect(error.toString(), isNot(contains('private-opencode-key')));
        }
      },
    );
  });

  group('Command Code account mode', () {
    test('discovers model protocols with the matching account key', () async {
      final observed = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          observed.add(options);
          final accountId = options.headers['Authorization'] ==
                  'Bearer private-first-command-key'
              ? 'command-code-first'
              : 'command-code-second';
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {
                  'id': '$accountId/open-model',
                  'supported_endpoints': ['/chat/completions', '/responses'],
                  'capabilities': {'vision': true},
                },
                {
                  'id': '$accountId/claude-sonnet-4-6',
                  'supported_endpoints': ['/messages'],
                  'capabilities': {'streaming': true},
                },
                {
                  'id': '$accountId/unsupported',
                  'supported_endpoints': ['/embeddings'],
                },
                {'id': '$accountId/no-protocols'},
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
        dio: dio,
      );

      final first = await service.saveAccount(
        _account('command-code-first', 'command-code'),
        secret: 'private-first-command-key',
      );
      final second = await service.saveAccount(
        _account('command-code-second', 'command-code'),
        secret: 'private-second-command-key',
      );
      final firstModels = await service.discoverModels(
        first,
        refreshRemote: true,
      );
      final secondModels = await service.discoverModels(
        second,
        refreshRemote: true,
      );

      expect(observed.map((request) => request.uri.toString()), [
        'https://api.commandcode.ai/provider/v1/models',
        'https://api.commandcode.ai/provider/v1/models',
      ]);
      expect(observed.map((request) => request.headers['Authorization']), [
        'Bearer private-first-command-key',
        'Bearer private-second-command-key',
      ]);
      expect(firstModels.map((model) => model.upstreamModelId), [
        'command-code-first/open-model',
        'command-code-first/claude-sonnet-4-6',
      ]);
      expect(firstModels.first.capabilities['supportedApiProtocols'], [
        'openai.chat_completions',
        'openai.responses',
      ]);
      expect(firstModels.first.capabilities['vision'], isTrue);
      expect(firstModels.first.capabilities['streaming'], isNull);
      expect(firstModels.last.capabilities['supportedApiProtocols'], [
        'anthropic.messages',
      ]);
      expect(firstModels.last.capabilities['streaming'], isTrue);
      expect(
        secondModels.first.upstreamModelId,
        'command-code-second/open-model',
      );
      expect(
        await service.readCredential(first.id),
        'private-first-command-key',
      );
      expect(
        await service.readCredential(second.id),
        'private-second-command-key',
      );
      expect(
        jsonEncode(first.toMap()),
        isNot(contains('private-first-command-key')),
      );
      expect(
        preferences.values.values.join(),
        isNot(contains('private-first-command-key')),
      );
      expect(
        preferences.values.values.join(),
        isNot(contains('private-second-command-key')),
      );
    });

    test('catalog refresh removes stale model capabilities', () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {
                  'id': 'provider/model',
                  'display_name': 'Upstream model',
                  'supported_endpoints': ['/chat/completions'],
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
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = LlmAccount(
        id: 'command-code-catalog-refresh',
        connectorType: 'command-code',
        authType: 'api_key',
        displayName: 'Command Code',
        models: const [
          LlmUpstreamModel(
            id: 'saved-model',
            upstreamModelId: 'provider/model',
            displayName: 'User model name',
            capabilities: {
              'chat': true,
              'streaming': true,
              'vision': true,
              'supportedApiProtocols': [
                'openai.chat_completions',
                'openai.responses',
              ],
            },
            config: {'apiProtocolOverride': 'openai.chat_completions'},
          ),
        ],
      );
      final savedAccount = await service.saveAccount(
        account,
        secret: 'private-command-code-key',
      );

      final models = await service.discoverModels(
        savedAccount,
        refreshRemote: true,
      );

      expect(models.single.id, 'saved-model');
      expect(models.single.displayName, 'User model name');
      expect(models.single.capabilities['vision'], isNull);
      expect(models.single.capabilities['streaming'], isNull);
      expect(models.single.capabilities['supportedApiProtocols'], [
        'openai.chat_completions',
      ]);
      expect(
        models.single.config['apiProtocolOverride'],
        'openai.chat_completions',
      );
    });

    test('builds only the protocol declared for the selected model', () {
      final account = LlmAccount(
        id: 'command-code-request',
        connectorType: 'command-code',
        authType: 'api_key',
        displayName: 'Command Code',
        models: const [
          LlmUpstreamModel(
            id: 'open-model',
            upstreamModelId: 'deepseek/deepseek-v4-flash',
            displayName: 'Open model',
            capabilities: {
              'supportedApiProtocols': [
                'openai.chat_completions',
                'openai.responses',
              ],
            },
          ),
          LlmUpstreamModel(
            id: 'claude-model',
            upstreamModelId: 'claude-sonnet-4-6',
            displayName: 'Claude model',
            capabilities: {
              'supportedApiProtocols': ['anthropic.messages'],
            },
          ),
        ],
      );
      const cases = [
        (
          'deepseek/deepseek-v4-flash',
          'openai.chat_completions',
          'https://api.commandcode.ai/provider/v1/chat/completions',
        ),
        (
          'deepseek/deepseek-v4-flash',
          'openai.responses',
          'https://api.commandcode.ai/provider/v1/responses',
        ),
        (
          'claude-sonnet-4-6',
          'anthropic.messages',
          'https://api.commandcode.ai/provider/v1/messages',
        ),
      ];
      for (final (modelId, protocol, expectedUrl) in cases) {
        final request = LlmNativeRequestBuilder().build(
          account: account,
          credential: 'private-command-key',
          modelId: modelId,
          body: const {'model': 'preserve-original-model-id'},
          stream: true,
          nativeFormat: switch (protocol) {
            'openai.responses' => 'responses',
            'anthropic.messages' => 'anthropic',
            _ => null,
          },
        );
        expect(request.uri.toString(), expectedUrl, reason: protocol);
        expect(request.headers['Authorization'], 'Bearer private-command-key');
        expect((request.body as Map)['model'], 'preserve-original-model-id');
      }

      expect(
        () => LlmNativeRequestBuilder().build(
          account: account,
          credential: 'private-command-key',
          modelId: 'claude-sonnet-4-6',
          body: const {'model': 'claude-sonnet-4-6'},
          nativeFormat: 'responses',
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      expect(
        () => LlmNativeRequestBuilder().build(
          account: LlmAccount(
            id: account.id,
            connectorType: account.connectorType,
            authType: account.authType,
            displayName: account.displayName,
            endpointConfig: const {'baseUrl': 'https://attacker.example/v1'},
            models: account.models,
          ),
          credential: 'private-command-key',
          modelId: 'deepseek/deepseek-v4-flash',
          body: const {'model': 'deepseek/deepseek-v4-flash'},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
        reason: 'the API key stays bound to the documented service host',
      );
    });

    test(
      'does not expose the API key when catalog authentication fails',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              '{"error":"private-command-key is invalid"}',
              401,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account('command-code-catalog-error', 'command-code'),
          secret: 'private-command-key',
        );

        try {
          await service.discoverModels(account, refreshRemote: true);
          fail('Expected the rejected catalog request to fail.');
        } on LlmAccountConnectorException catch (error) {
          expect(error.toString(), isNot(contains('private-command-key')));
        }
        expect(captured?.uri.host, 'api.commandcode.ai');
        expect(captured?.followRedirects, isFalse);
      },
    );
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
      'accepts Vertex service-account models as model-group members',
      () async {
        final account = await service.saveAccount(
          LlmAccount(
            id: 'vertex-service-group-account',
            connectorType: 'vertex',
            authType: 'service_account',
            displayName: 'Vertex service account',
            status: LlmAccountStatus.ready,
            endpointConfig: const {'projectId': 'vertex-project'},
            models: const [
              LlmUpstreamModel(
                id: 'gemini-flash-local',
                upstreamModelId: 'gemini-2.5-flash',
                displayName: 'Gemini 2.5 Flash',
                capabilities: {'chat': true},
              ),
            ],
          ),
          secret: jsonEncode(kVertexTestServiceAccount),
        );

        final group = await service.saveModelGroup(
          LlmModelGroup(
            id: 'vertex-service-group',
            displayName: 'Vertex service group',
            members: const [
              LlmModelGroupMember(
                accountId: 'vertex-service-group-account',
                localModelId: 'gemini-flash-local',
                upstreamModelId: 'gemini-2.5-flash',
              ),
            ],
          ),
        );

        expect(account.authType, 'service_account');
        expect(group.members.single.accountId, account.id);
        expect((await service.listModelGroups()).single.id, group.id);
      },
    );

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
      'stores Claude Setup Tokens securely without treating them as OAuth',
      () async {
        const token = 'sk-ant-oat01-setup-secret';
        final account = await service.saveAccount(
          _account('claude-setup-token', 'claude', authType: 'setup_token'),
          secret: token,
        );

        final storedJson = preferences
            .values[LlmAccountMigrationService.accountsPreferenceKey]!;
        expect(account.authType, 'setup_token');
        expect(storedJson, isNot(contains(token)));
        expect(await service.readCredential(account.id), token);
        await service.saveAccount(account, secret: 'sk-ant-oat01-rotated');
        expect(
          await service.readCredential(account.id),
          'sk-ant-oat01-rotated',
        );
        expect(credentials.values, hasLength(1));
        expect(await service.refreshCredential(account), isFalse);
        expect(
          (await service.discoverModels(
            account,
          ))
              .map((model) => model.upstreamModelId),
          contains('claude-sonnet-4-6'),
        );
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
        final customKeyHeaderAccount = LlmAccount(
          id: 'unsafe-config-header-key',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          endpointConfig: const {
            'baseUrl': 'https://api.example.test/v1',
            'headers': {'X-Key': 'must-not-be-persisted'},
          },
        );
        await expectLater(
          service.saveAccount(customKeyHeaderAccount, secret: 'secure-api-key'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        final authHeaderAccount = LlmAccount(
          id: 'unsafe-config-header-auth',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          endpointConfig: const {
            'baseUrl': 'https://api.example.test/v1',
            'headers': {'X-Auth': 'must-not-be-persisted'},
          },
        );
        await expectLater(
          service.saveAccount(authHeaderAccount, secret: 'secure-api-key'),
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
      for (final header in ['X-Key', 'X-Auth']) {
        final modelHeaderAccount = LlmAccount(
          id: 'unsafe-model-config-header-${header.toLowerCase()}',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom',
          models: [
            LlmUpstreamModel(
              id: 'model-1',
              upstreamModelId: 'model-1',
              displayName: 'Model 1',
              config: {
                'headers': {header: 'must-not-be-persisted'},
              },
            ),
          ],
        );

        await expectLater(
          service.saveAccount(modelHeaderAccount, secret: 'secure-api-key'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      }
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
        for (final field in [
          'api_key',
          'key',
          'access_key',
          'x-access-key',
          'signature',
          'sig',
          'X-Amz-Signature',
          'x-key',
          'x-auth',
        ]) {
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

    test('Devin CLI default model identifies its ACP catalog source', () async {
      final catalogService = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );

      final models = await catalogService.discoverModels(
        _account(
          'devin-cli-catalog',
          'devin-cli-agentic',
          authType: 'cli_session',
        ),
      );

      expect(models, hasLength(1));
      expect(models.single.upstreamModelId, 'devin-cli-default');
      expect(models.single.config['catalogSource'], 'devin_cli_acp_default');
    });

    test(
      'Cursor fallback catalog exposes chat, streaming, and inline vision capabilities',
      () async {
        final catalogService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );

        final models = await catalogService.discoverModels(
          _account('cursor-catalog', 'cursor', authType: 'oauth'),
        );

        expect(models, isNotEmpty);
        expect(models.map((model) => model.upstreamModelId), contains('auto'));
        expect(
          models.every((model) => model.capabilities['chat'] == true),
          isTrue,
        );
        expect(
          models.every((model) => model.capabilities['streaming'] == true),
          isTrue,
        );
        expect(
          models.every((model) => model.capabilities['vision'] == true),
          isTrue,
        );
        expect(
          models.first.config['catalogSource'],
          'cursor_provider_registry',
        );
        expect(
          models.first.config['imageInputSupport'],
          contains('Inline PNG, JPEG, GIF, or WebP data only'),
        );
      },
    );

    test(
      'discovers entitled Grok and xAI OAuth models from their own hosts',
      () async {
        for (final connectorType in ['grok-cli', 'xai-oauth']) {
          RequestOptions? captured;
          final dio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              captured = options;
              return ResponseBody.fromString(
                jsonEncode({
                  'data': [
                    {
                      'id':
                          connectorType == 'grok-cli' ? 'grok-4.7' : 'grok-4.6',
                    },
                    {'id': 'grok-4-image'},
                  ],
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });
          final accountService = LlmAccountConnectorService(
            preferences: _MemoryPreferences(),
            credentialStore: _MemoryCredentials(),
            dio: dio,
          );
          final account = await accountService.saveAccount(
            _account(
              'catalog-$connectorType',
              connectorType,
              authType: 'oauth',
            ),
            secret: jsonEncode({'access_token': '$connectorType-access'}),
          );

          final models = await accountService.discoverModels(
            account,
            refreshRemote: true,
          );

          expect(
            captured?.uri.host,
            connectorType == 'grok-cli'
                ? 'cli-chat-proxy.grok.com'
                : 'api.x.ai',
          );
          expect(captured?.uri.path, '/v1/models');
          expect(
            captured?.headers['Authorization'],
            'Bearer $connectorType-access',
          );
          expect(
            captured?.headers.containsKey('X-XAI-Token-Auth'),
            connectorType == 'grok-cli',
          );
          expect(models.map((model) => model.upstreamModelId), [
            connectorType == 'grok-cli' ? 'grok-4.7' : 'grok-4.6',
          ]);
        }
      },
    );

    test('refreshes expired xAI OAuth before model discovery', () async {
      for (final connectorType in ['grok-cli', 'xai-oauth']) {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            final isTokenRequest = options.uri.host == 'auth.x.ai';
            return ResponseBody.fromString(
              jsonEncode(
                isTokenRequest
                    ? {
                        'access_token': 'fresh-$connectorType',
                        'refresh_token': 'rotated-$connectorType',
                        'expires_in': 3600,
                      }
                    : {
                        'data': [
                          {'id': 'grok-4.7'},
                        ],
                      },
              ),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accountService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accountService.saveAccount(
          _account('expired-$connectorType', connectorType, authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'expired-access',
            'refresh_token': 'refresh-$connectorType',
            'token_endpoint': 'https://auth.x.ai/oauth/token',
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          }),
        );

        final models = await accountService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(requests.map((request) => request.uri.host), [
          'auth.x.ai',
          connectorType == 'grok-cli' ? 'cli-chat-proxy.grok.com' : 'api.x.ai',
        ]);
        expect(
          requests.last.headers['Authorization'],
          'Bearer fresh-$connectorType',
        );
        expect(models.single.upstreamModelId, 'grok-4.7');
      }
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
      expect(models.single.capabilities['chat'], isTrue);
      expect(models.single.capabilities['tools'], isTrue);
    });

    test('discovers AI Studio models using its stored API key', () async {
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
                  'supportedGenerationMethods': [
                    'generateContent',
                    'streamGenerateContent',
                  ],
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
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await accounts.saveAccount(
        _account('aistudio-discovery', 'aistudio'),
        secret: 'aistudio-discovery-key',
      );

      final models = await accounts.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(captured?.uri.path, '/v1beta/models');
      expect(captured?.headers['x-goog-api-key'], 'aistudio-discovery-key');
      expect(models.map((model) => model.upstreamModelId), ['gemini-3.1-pro']);
      expect(models.single.capabilities['streaming'], isTrue);
    });

    test(
      'rejects malformed Vertex service-account JSON before persistence',
      () async {
        await expectLater(
          service.saveAccount(
            LlmAccount(
              id: 'vertex-malformed-account',
              connectorType: 'vertex',
              authType: 'service_account',
              displayName: 'Malformed Vertex account',
            ),
            secret: jsonEncode({
              'type': 'service_account',
              'private_key': 'not-a-key',
            }),
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(await service.listAccounts(), isEmpty);
        expect(credentials.values, isEmpty);
      },
    );

    test(
      'refreshes missing and expired Vertex service-account tokens before discovery',
      () async {
        for (final bundle in [
          Map<String, dynamic>.from(kVertexTestServiceAccount),
          {
            ...kVertexTestServiceAccount,
            'access_token': 'expired-vertex-token',
            'expires_at': '2000-01-01T00:00:00Z',
          },
        ]) {
          final requests = <RequestOptions>[];
          final dio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              requests.add(options);
              if (options.uri.host == 'oauth2.googleapis.com') {
                return ResponseBody.fromString(
                  jsonEncode({
                    'access_token': 'refreshed-vertex-token',
                    'expires_in': 3600,
                  }),
                  200,
                  headers: const {
                    'content-type': ['application/json'],
                  },
                );
              }
              return ResponseBody.fromString(
                jsonEncode({
                  'publisherModels': [
                    {
                      'name': 'publishers/google/models/gemini-2.5-flash',
                      'supportedActions': ['generateContent'],
                    },
                  ],
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });
          final discoveryService = LlmAccountConnectorService(
            preferences: _MemoryPreferences(),
            credentialStore: _MemoryCredentials(),
            dio: dio,
          );
          final account = await discoveryService.saveAccount(
            LlmAccount(
              id: 'vertex-token-refresh-${bundle.containsKey('access_token')}',
              connectorType: 'vertex',
              authType: 'service_account',
              displayName: 'Vertex account',
              endpointConfig: const {'projectId': 'vertex-project'},
            ),
            secret: jsonEncode(bundle),
          );

          final models = await discoveryService.discoverModels(
            account,
            refreshRemote: true,
          );

          expect(models.map((model) => model.upstreamModelId), [
            'gemini-2.5-flash',
          ]);
          expect(requests.first.uri.host, 'oauth2.googleapis.com');
          expect(
            requests.last.headers['Authorization'],
            'Bearer refreshed-vertex-token',
          );
        }
      },
    );

    test(
      'discovers Vertex chat models using service-account project and default location',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'publisherModels': [
                  {
                    'name': 'publishers/google/models/gemini-2.5-flash',
                    'displayName': 'Gemini 2.5 Flash',
                    'supportedActions': [
                      'generateContent',
                      'streamGenerateContent',
                    ],
                  },
                  {
                    'name': 'publishers/google/models/gemini-stream-only',
                    'displayName': 'Streaming-only Gemini',
                    'supportedActions': ['streamGenerateContent'],
                  },
                  {
                    'name': 'publishers/google/models/text-embedding-005',
                    'supportedActions': ['embedContent'],
                  },
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
            id: 'vertex-discovery',
            connectorType: 'vertex',
            authType: 'service_account',
            displayName: 'Vertex account',
          ),
          secret: jsonEncode({
            'access_token': 'vertex-short-lived-token',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'service_account': {
              ...kVertexTestServiceAccount,
              'project_id': 'credential-project',
            },
          }),
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(
          captured?.uri.toString(),
          contains(
            '/projects/credential-project/locations/us-central1/publishers/google/models',
          ),
        );
        expect(
          captured?.headers['Authorization'],
          'Bearer vertex-short-lived-token',
        );
        expect(models.map((model) => model.upstreamModelId), [
          'gemini-2.5-flash',
        ]);
        expect(models.single.displayName, 'Gemini 2.5 Flash');
        expect(models.single.capabilities, {'chat': true, 'streaming': true});
      },
    );

    test('discovers Vertex Imagen models that support prediction', () async {
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'publisherModels': [
                {
                  'name': 'publishers/google/models/imagen-4.0-generate-001',
                  'displayName': 'Imagen 4 Generate',
                  'supportedActions': ['predict'],
                },
                {
                  'name': 'publishers/google/models/text-embedding-005',
                  'supportedActions': ['embedContent'],
                },
              ],
            }),
            200,
            headers: const {
              'content-type': ['application/json'],
            },
          );
        });
      final discoveryService = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await discoveryService.saveAccount(
        LlmAccount(
          id: 'vertex-imagen-discovery',
          connectorType: 'vertex',
          authType: 'api_key',
          displayName: 'Vertex API key',
          endpointConfig: const {
            'projectId': 'vertex-project',
            'location': 'us-central1',
          },
        ),
        secret: 'vertex-api-key',
      );

      final models = await discoveryService.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(models.map((model) => model.upstreamModelId), [
        'imagen-4.0-generate-001',
      ]);
    });

    test(
      'blocks Vertex model discovery with unsupported generic OAuth',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString('{}', 200);
          });
        final preferences = _MemoryPreferences();
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await discoveryService.saveAccount(
          LlmAccount(
            id: 'vertex-oauth-discovery',
            connectorType: 'vertex',
            authType: 'api_key',
            displayName: 'Vertex OAuth account',
            models: const [
              LlmUpstreamModel(
                id: 'cached-vertex-model',
                upstreamModelId: 'gemini-2.5-flash',
                displayName: 'Gemini 2.5 Flash',
              ),
            ],
            endpointConfig: const {
              'projectId': 'oauth-project',
              'location': 'europe-west4',
            },
          ),
          secret: 'vertex-api-key',
        );
        final accountsEnvelope = jsonDecode(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        ) as Map<String, dynamic>;
        final accountRecord = Map<String, dynamic>.from(
          (accountsEnvelope['items'] as List).single as Map,
        )..['authType'] = 'oauth';
        accountsEnvelope['items'] = [accountRecord];
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
            jsonEncode(accountsEnvelope);
        final legacyAccount = (await discoveryService.getAccount(account.id))!;

        await expectLater(
          discoveryService.saveAccount(legacyAccount, secret: 'legacy-token'),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        await expectLater(
          discoveryService.discoverModels(legacyAccount),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        accountRecord['models'] = <Map<String, dynamic>>[];
        accountsEnvelope['items'] = [accountRecord];
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
            jsonEncode(accountsEnvelope);
        final legacyAccountWithoutModels = (await discoveryService.getAccount(
          account.id,
        ))!;
        await expectLater(
          discoveryService.discoverModels(legacyAccountWithoutModels),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(requestsSent, 0);
        expect(
          () => LlmNativeRequestBuilder().build(
            account: legacyAccount,
            credential: 'legacy-vertex-oauth',
            modelId: 'gemini-2.5-flash',
            body: const {'contents': []},
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );

    test('follows OpenAI and Anthropic model-list cursors', () async {
      for (final connector in ['openai-api', 'claude']) {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            final isSecondPage = options.uri.queryParameters.containsKey(
              connector == 'openai-api' ? 'after' : 'after_id',
            );
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': isSecondPage ? 'model-second' : 'model-first'},
                ],
                'has_more': !isSecondPage,
                'last_id': isSecondPage ? 'model-second' : 'model-first',
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
          _account('cursor-$connector', connector),
          secret: '$connector-test-key',
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(requests, hasLength(2), reason: connector);
        expect(requests.first.uri.path, '/v1/models', reason: connector);
        expect(
          requests[1].uri.queryParameters[
              connector == 'openai-api' ? 'after' : 'after_id'],
          'model-first',
          reason: connector,
        );
        expect(
            models.map((model) => model.upstreamModelId),
            [
              'model-first',
              'model-second',
            ],
            reason: connector);
      }
    });

    test(
      'discovers tool capability for official OpenAI and Anthropic model catalogs',
      () async {
        for (final (connectorType, modelId) in [
          ('openai-api', 'gpt-4o'),
          ('openai-api', 'gpt-4.5-preview'),
          ('claude', 'claude-sonnet-4-6'),
        ]) {
          final dio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              return ResponseBody.fromString(
                jsonEncode({
                  'data': [
                    {'id': modelId},
                    if (connectorType == 'openai-api')
                      {'id': 'gpt-realtime-2.1'},
                    if (connectorType == 'openai-api')
                      {
                        'id': 'catalog-no-tools',
                        'capabilities': {'tools': false},
                      },
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
            _account('tool-discovery-$connectorType', connectorType),
            secret: 'tool-discovery-key',
          );

          final models = await discoveryService.discoverModels(
            account,
            refreshRemote: true,
          );

          expect(models.first.capabilities['tools'], isTrue, reason: modelId);
          if (connectorType == 'openai-api') {
            final realtimeModel = models.singleWhere(
              (model) => model.upstreamModelId == 'gpt-realtime-2.1',
            );
            expect(realtimeModel.capabilities['audio'], isTrue);
            expect(realtimeModel.capabilities['tools'], isTrue);
            expect(models.first.capabilities.containsKey('audio'), isFalse);
            expect(models.last.capabilities['tools'], isFalse);
          }
        }
      },
    );

    test(
      'discovers provider API-key models and filters non-chat models',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {'id': 'deepseek-chat'},
                  {'id': 'text-embedding-v3'},
                  {'id': 'deepseek-reranker'},
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
          _account('deepseek-discovery', 'deepseek'),
          secret: 'deepseek-private-key',
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(captured?.uri.toString(), 'https://api.deepseek.com/models');
        expect(
          captured?.headers['Authorization'],
          'Bearer deepseek-private-key',
        );
        expect(models.map((model) => model.upstreamModelId), ['deepseek-chat']);
      },
    );

    test(
      'discovers WorkBuddy chat models from its authenticated config',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'data': {
                  'models': [
                    {
                      'id': 'deepseek-v4.1-flash',
                      'name': 'DeepSeek V4.1 Flash',
                      'tags': ['craft'],
                      'capabilities': ['completion', 'tools'],
                    },
                    {
                      'id': 'hunyuan-video-art',
                      'tags': ['text-to-video'],
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
        final discoveryService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await discoveryService.saveAccount(
          _account('workbuddy-discovery', 'workbuddy', authType: 'oauth'),
          secret: jsonEncode({'access_token': 'workbuddy-private-token'}),
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(captured?.uri.toString(), 'https://www.workbuddy.ai/v3/config');
        expect(
          captured?.headers['Authorization'],
          'Bearer workbuddy-private-token',
        );
        expect(captured?.headers['Accept'], 'application/json');
        expect(
          captured?.headers.entries
              .where((entry) => entry.key.toLowerCase() == 'x-product')
              .single
              .value,
          'SaaS',
        );
        expect(
          captured?.headers.keys.any(
            (key) => key.toLowerCase() == 'x-agent-intent',
          ),
          isFalse,
        );
        expect(models.map((model) => model.upstreamModelId), [
          'deepseek-v4.1-flash',
        ]);
        expect(models.single.capabilities['chat'], isTrue);
        expect(models.single.capabilities['streaming'], isTrue);
        expect(models.single.capabilities['tools'], isTrue);
      },
    );

    test('discovers regional Qwen Cloud and Token Plan chat models', () async {
      final requestedUris = <Uri>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestedUris.add(options.uri);
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'qwen3.7-plus'},
                {'id': 'text-embedding-v4'},
                {'id': 'qwen-reranker'},
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

      for (final (connectorType, region, expectedUrl) in [
        (
          'qwen-cloud',
          'cn-beijing',
          'https://cn-beijing.maas.qwencloudapi.com/compatible-mode/v1/models',
        ),
        (
          'qwen-cloud-token-plan',
          '',
          'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1/models',
        ),
      ]) {
        final account = await discoveryService.saveAccount(
          LlmAccount(
            id: '$connectorType-discovery',
            connectorType: connectorType,
            authType: 'api_key',
            displayName: connectorType,
            endpointConfig: {if (region.isNotEmpty) 'region': region},
          ),
          secret: '$connectorType-discovery-key',
        );
        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(requestedUris.last.toString(), expectedUrl);
        expect(
            models.map((model) => model.upstreamModelId),
            [
              'qwen3.7-plus',
            ],
            reason: connectorType);
        expect(
          models.single.capabilities,
          {'chat': true, 'streaming': true},
          reason:
              'the service supports text chat streams, not unreported media/tools',
        );
      }
    });

    test('rejects nested Qwen Cloud hosts before sending the API key',
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
          id: 'qwen-cloud-untrusted-host',
          connectorType: 'qwen-cloud',
          authType: 'api_key',
          displayName: 'Qwen Cloud untrusted host',
          endpointConfig: const {
            'baseUrl':
                'https://cn-beijing.attacker.maas.qwencloudapi.com/compatible-mode/v1',
          },
        ),
        secret: 'qwen-cloud-private-key',
      );

      await expectLater(
        discoveryService.discoverModels(account, refreshRemote: true),
        throwsA(isA<LlmAccountConnectorException>()),
      );
      expect(requestSent, isFalse);
    });

    test('discovers regional GLM and MiniMax chat models', () async {
      final requestedUris = <Uri>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestedUris.add(options.uri);
          final modelId =
              options.uri.host == 'api.minimaxi.com' ? 'minimax-m2' : 'glm-5';
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': modelId},
                {'id': 'text-embedding'},
                {'id': 'reranker-v2'},
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

      for (final (connectorType, expectedUrl, expectedModel) in [
        (
          'glm-cn',
          'https://open.bigmodel.cn/api/coding/paas/v4/models',
          'glm-5',
        ),
        ('minimax-cn', 'https://api.minimaxi.com/v1/models', 'minimax-m2'),
      ]) {
        final account = await discoveryService.saveAccount(
          _account('$connectorType-discovery', connectorType),
          secret: '$connectorType-discovery-key',
        );
        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(requestedUris.last.toString(), expectedUrl);
        expect(models.map((model) => model.upstreamModelId), [expectedModel]);
        expect(models.single.capabilities, {'chat': true, 'streaming': true});
      }
    });

    test('GLM Thinking model preset uses the GLM API-key account', () async {
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
      final account = await service.saveAccount(
        LlmAccount(
          id: 'glm-thinking-preset',
          connectorType: 'glmt',
          authType: 'api_key',
          displayName: 'GLM account for Thinking model',
        ),
        secret: 'glm-thinking-private-key',
      );
      final request = LlmNativeRequestBuilder().build(
        account: account,
        credential: 'glm-thinking-private-key',
        modelId: 'glm-5',
        body: const {'model': 'glm-5', 'messages': []},
      );

      expect(account.connectorType, 'glm');
      expect(
        request.uri.toString(),
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
      expect(
        request.headers['Authorization'],
        'Bearer glm-thinking-private-key',
      );
      expect((request.body as Map)['model'], 'glm-5');
    });

    test(
      'signs Bedrock model discovery and excludes non-text models',
      () async {
        final captured = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured.add(options);
            if (options.uri.path == '/inference-profiles') {
              return ResponseBody.fromString(
                jsonEncode({'inferenceProfileSummaries': []}),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              jsonEncode({
                'modelSummaries': [
                  {
                    'modelId': 'amazon.titan-text-express-v1',
                    'modelName': 'Titan Text Express',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['TEXT'],
                    'modelLifecycle': {'status': 'ACTIVE'},
                  },
                  {
                    'modelId': 'amazon.titan-embed-text-v2:0',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['EMBEDDING'],
                    'modelLifecycle': {'status': 'ACTIVE'},
                  },
                  {
                    'modelId': 'cohere.rerank-v3-5:0',
                    'modelName': 'Cohere Rerank',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['TEXT'],
                    'modelLifecycle': {'status': 'ACTIVE'},
                  },
                  {
                    'modelId': 'amazon.titan-image-generator-v1',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['IMAGE'],
                    'modelLifecycle': {'status': 'ACTIVE'},
                  },
                  {
                    'modelId': 'amazon.titan-text-legacy-v1',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['TEXT'],
                    'modelLifecycle': {'status': 'INACTIVE'},
                  },
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
            id: 'bedrock-discovery',
            connectorType: 'bedrock',
            authType: 'aws_credentials',
            displayName: 'Bedrock',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: jsonEncode({
            'accessKeyId': 'AKIDEXAMPLE',
            'secretAccessKey': 'private-aws-secret',
            'sessionToken': 'private-session-token',
          }),
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(captured, hasLength(2));
        expect(captured.first.method, 'GET');
        expect(captured.first.uri.host, 'bedrock.us-east-1.amazonaws.com');
        expect(captured.first.uri.path, '/foundation-models');
        expect(captured.first.uri.queryParameters['byOutputModality'], 'TEXT');
        expect(
          captured.first.headers['x-amz-security-token'],
          'private-session-token',
        );
        expect(captured.last.uri.path, '/inference-profiles');
        expect(
          captured.every(
            (request) =>
                request.headers['Authorization'] is String &&
                (request.headers['Authorization'] as String).startsWith(
                  'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/',
                ),
          ),
          isTrue,
        );
        expect(models.map((model) => model.upstreamModelId), [
          'amazon.titan-text-express-v1',
        ]);
      },
    );

    test('discovers Bedrock models with the distinct API-key mode', () async {
      final captured = <RequestOptions>[];
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured.add(options);
          if (options.uri.path == '/inference-profiles') {
            final id = options.uri.queryParameters['nextToken'] == null
                ? 'us.anthropic.claude-3-5-sonnet'
                : 'eu.anthropic.claude-3-5-sonnet';
            return ResponseBody.fromString(
              jsonEncode({
                'inferenceProfileSummaries': [
                  {
                    'inferenceProfileId': id,
                    'inferenceProfileName': id,
                    'status': 'ACTIVE',
                    'type': 'SYSTEM_DEFINED',
                    'models': [
                      {
                        'modelArn':
                            'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet',
                      },
                    ],
                  },
                  {
                    'inferenceProfileId': 'us.amazon.titan-image-generator-v1',
                    'inferenceProfileName': 'Titan Image Generator',
                    'status': 'ACTIVE',
                    'type': 'SYSTEM_DEFINED',
                    'models': [
                      {
                        'modelArn':
                            'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-image-generator-v1',
                      },
                    ],
                  },
                  {
                    'inferenceProfileId': 'us.amazon.titan-text-legacy-v1',
                    'inferenceProfileName': 'Titan Text Legacy',
                    'status': 'ACTIVE',
                    'type': 'SYSTEM_DEFINED',
                    'models': [
                      {
                        'modelArn':
                            'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-text-legacy-v1',
                      },
                    ],
                  },
                ],
                if (options.uri.queryParameters['nextToken'] == null)
                  'nextToken': 'profile-next',
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'modelSummaries': [
                {
                  'modelId': 'amazon.titan-text-express-v1',
                  'modelName': 'Titan Text Express',
                  'inputModalities': ['TEXT'],
                  'outputModalities': ['TEXT'],
                  'responseStreamingSupported': true,
                  'modelLifecycle': {'status': 'ACTIVE'},
                },
                {
                  'modelId': 'anthropic.claude-3-5-sonnet',
                  'modelName': 'Claude 3.5 Sonnet',
                  'inputModalities': ['TEXT'],
                  'outputModalities': ['TEXT'],
                  'responseStreamingSupported': true,
                  'modelLifecycle': {'status': 'ACTIVE'},
                },
                {
                  'modelId': 'amazon.titan-text-legacy-v1',
                  'modelName': 'Titan Text Legacy',
                  'inputModalities': ['TEXT'],
                  'outputModalities': ['TEXT'],
                  'responseStreamingSupported': false,
                  'modelLifecycle': {'status': 'ACTIVE'},
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
        _account(
          'bedrock-api-key-discovery',
          'bedrock',
          authType: 'api_key',
          endpointConfig: const {'region': 'eu-west-2'},
        ),
        secret: 'bedrock-api-key-secret',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(captured, hasLength(3));
      expect(
        captured.map((request) => request.uri.host),
        everyElement('bedrock.eu-west-2.amazonaws.com'),
      );
      expect(captured.map((request) => request.uri.path), [
        '/foundation-models',
        '/inference-profiles',
        '/inference-profiles',
      ]);
      expect(
        captured.map(
          (request) => request.uri.queryParameters['byOutputModality'],
        ),
        ['TEXT', null, null],
      );
      expect(
        captured.map((request) => request.headers['Authorization']),
        everyElement('Bearer bedrock-api-key-secret'),
      );
      expect(
        captured.map((request) => request.headers['x-amz-date']),
        everyElement(isNull),
      );
      expect(models.map((model) => model.upstreamModelId), [
        'amazon.titan-text-express-v1',
        'anthropic.claude-3-5-sonnet',
        'amazon.titan-text-legacy-v1',
        'us.anthropic.claude-3-5-sonnet',
        'us.amazon.titan-text-legacy-v1',
        'eu.anthropic.claude-3-5-sonnet',
      ]);
      expect(models[1].capabilities['streaming'], isTrue);
      expect(models[4].capabilities['streaming'], isFalse);
      expect(captured.last.uri.queryParameters['nextToken'], 'profile-next');
      expect(
        credentials.values[account.credentialRef],
        'bedrock-api-key-secret',
      );
      expect(
        preferences.values.values.join(),
        isNot(contains('bedrock-api-key-secret')),
      );
    });

    test(
      'keeps foundation models when inference profiles are unavailable',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.path == '/inference-profiles') {
              return ResponseBody.fromString('{}', 500);
            }
            return ResponseBody.fromString(
              jsonEncode({
                'modelSummaries': [
                  {
                    'modelId': 'amazon.titan-text-express-v1',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['TEXT'],
                    'modelLifecycle': {'status': 'ACTIVE'},
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
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'bedrock-profile-list-unavailable',
            'bedrock',
            authType: 'api_key',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: 'bedrock-api-key-secret',
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(models.map((model) => model.upstreamModelId), [
          'amazon.titan-text-express-v1',
        ]);
      },
    );

    test(
      'keeps foundation models when API-key profile listing is denied',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.path == '/inference-profiles') {
              return ResponseBody.fromString('{}', 403);
            }
            return ResponseBody.fromString(
              jsonEncode({
                'modelSummaries': [
                  {
                    'modelId': 'amazon.titan-text-express-v1',
                    'inputModalities': ['TEXT'],
                    'outputModalities': ['TEXT'],
                    'modelLifecycle': {'status': 'ACTIVE'},
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
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'bedrock-api-key-profile-list-denied',
            'bedrock',
            authType: 'api_key',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: 'bedrock-api-key-secret',
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(models.map((model) => model.upstreamModelId), [
          'amazon.titan-text-express-v1',
        ]);
      },
    );

    test(
      'keeps manually configured Bedrock models when API-key listing is denied',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            if (options.uri.path.endsWith('/converse')) {
              return ResponseBody.fromString(
                jsonEncode({
                  'output': {
                    'message': {
                      'role': 'assistant',
                      'content': [
                        {'text': 'Manual model route works'},
                      ],
                    },
                  },
                  'stopReason': 'end_turn',
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            return ResponseBody.fromString('{}', 403);
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          LlmAccount(
            id: 'bedrock-api-key-limited-list',
            connectorType: 'bedrock',
            authType: 'api_key',
            displayName: 'Limited Bedrock API key',
            endpointConfig: const {'region': 'us-east-1'},
            models: const [
              LlmUpstreamModel(
                id: 'manual-model',
                upstreamModelId: 'us.anthropic.claude-sonnet-4-6',
                displayName: 'Manually configured Claude',
                capabilities: {'chat': true, 'streaming': true},
              ),
            ],
          ),
          secret: 'bedrock-api-key-secret',
        );

        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(requests, hasLength(1));
        expect(requests.single.uri.path, '/foundation-models');
        expect(
          requests.single.headers['Authorization'],
          'Bearer bedrock-api-key-secret',
        );
        expect(models.map((model) => model.upstreamModelId), [
          'us.anthropic.claude-sonnet-4-6',
        ]);
        expect(models.single.capabilities['chat'], isTrue);
        expect(models.single.capabilities['streaming'], isTrue);

        final response = await LlmConnectorHttpClient(
          accountService: service,
          dio: dio,
        ).request(
          account: account,
          modelId: models.single.upstreamModelId,
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        );

        expect(requests, hasLength(2));
        expect(
          requests.last.uri.host,
          'bedrock-runtime.us-east-1.amazonaws.com',
        );
        expect(requests.last.uri.path, endsWith('/converse'));
        expect(
          requests.last.headers['Authorization'],
          'Bearer bedrock-api-key-secret',
        );
        expect((response.body as Map)['choices'], isA<List>());
      },
    );

    test(
      'rejects Bedrock API-key discovery when the key is unauthorized',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromString('{}', 401);
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          _account(
            'bedrock-api-key-invalid',
            'bedrock',
            authType: 'api_key',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: 'invalid-bedrock-api-key',
        );

        await expectLater(
          service.discoverModels(account, refreshRemote: true),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );

    test('uses the AWS China host for Bedrock model discovery', () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          if (options.uri.path == '/inference-profiles') {
            return ResponseBody.fromString(
              jsonEncode({'inferenceProfileSummaries': []}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'modelSummaries': []}),
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
          id: 'bedrock-china-discovery',
          connectorType: 'bedrock',
          authType: 'aws_credentials',
          displayName: 'Bedrock',
          endpointConfig: const {'region': 'cn-north-1'},
        ),
        secret: jsonEncode({
          'accessKeyId': 'AKIDEXAMPLE',
          'secretAccessKey': 'private-aws-secret',
        }),
      );

      await discoveryService.discoverModels(account, refreshRemote: true);

      expect(captured?.uri.host, 'bedrock.cn-north-1.amazonaws.com.cn');
    });

    test('follows Bedrock foundation-model nextToken pages', () async {
      final requests = <RequestOptions>[];
      var page = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          if (options.uri.path == '/inference-profiles') {
            return ResponseBody.fromString(
              jsonEncode({'inferenceProfileSummaries': []}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          final response = page++ == 0
              ? {
                  'modelSummaries': [
                    {
                      'modelId': 'amazon.titan-text-express-v1',
                      'inputModalities': ['TEXT'],
                      'outputModalities': ['TEXT'],
                      'modelLifecycle': {'status': 'ACTIVE'},
                    },
                  ],
                  'nextToken': 'bedrock-next',
                }
              : {
                  'modelSummaries': [
                    {
                      'modelId': 'anthropic.claude-3-5-sonnet-v2:0',
                      'inputModalities': ['TEXT'],
                      'outputModalities': ['TEXT'],
                      'modelLifecycle': {'status': 'ACTIVE'},
                    },
                  ],
                };
          return ResponseBody.fromString(
            jsonEncode(response),
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
          id: 'bedrock-pages',
          connectorType: 'bedrock',
          authType: 'aws_credentials',
          displayName: 'Bedrock',
          endpointConfig: const {'region': 'us-east-1'},
        ),
        secret: jsonEncode({
          'accessKeyId': 'AKIDEXAMPLE',
          'secretAccessKey': 'private-aws-secret',
          'sessionToken': 'private-session-token',
        }),
      );

      final models = await discoveryService.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(requests, hasLength(3));
      expect(requests.first.uri.queryParameters['byOutputModality'], 'TEXT');
      expect(requests[1].uri.queryParameters['nextToken'], 'bedrock-next');
      expect(requests.last.uri.path, '/inference-profiles');
      expect(models.map((model) => model.upstreamModelId), [
        'amazon.titan-text-express-v1',
        'anthropic.claude-3-5-sonnet-v2:0',
      ]);
    });

    test(
      'attributes Gemini OAuth model discovery to its Cloud project',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({'models': []}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final prefs = _MemoryPreferences();
        final connector = LlmAccountConnectorService(
          preferences: prefs,
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await connector.saveAccount(
          LlmAccount(
            id: 'gemini-oauth-discovery',
            connectorType: 'gemini',
            authType: 'oauth',
            displayName: 'Gemini Developer API',
            endpointConfig: const {
              'googleCloudProjectId': 'my-cloud-project',
              'clientId': 'desktop-client.apps.googleusercontent.com',
            },
          ),
          secret: jsonEncode({'access_token': 'gemini-access-token'}),
        );

        await connector.discoverModels(account, refreshRemote: true);

        expect(
          captured?.headers['Authorization'],
          'Bearer gemini-access-token',
        );
        expect(captured?.headers['x-goog-user-project'], 'my-cloud-project');
        expect(captured?.headers.containsKey('x-goog-api-key'), isFalse);
      },
    );

    test(
      'refreshes an expired Gemini OAuth token before model discovery',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            if (options.uri.host == 'oauth2.googleapis.com') {
              return ResponseBody.fromString(
                jsonEncode({
                  'access_token': 'fresh-gemini-access',
                  'refresh_token': 'rotated-gemini-refresh',
                  'expires_in': 3600,
                }),
                200,
              );
            }
            return ResponseBody.fromString(jsonEncode({'models': []}), 200);
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          LlmAccount(
            id: 'gemini-discovery-expired-oauth',
            connectorType: 'gemini',
            authType: 'oauth',
            displayName: 'Gemini Developer API',
            endpointConfig: const {'googleCloudProjectId': 'my-cloud-project'},
          ),
          secret: jsonEncode({
            'access_token': 'expired-gemini-access',
            'refresh_token': 'gemini-refresh-token',
            'client_id': 'desktop-client.apps.googleusercontent.com',
            'client_secret': 'secure-client-secret',
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
            'oauth_contract': 'google-gemini-developer-api-v1',
          }),
        );

        await service.discoverModels(account, refreshRemote: true);

        expect(requests, hasLength(2));
        expect(requests.first.uri.host, 'oauth2.googleapis.com');
        expect(requests.last.uri.host, 'generativelanguage.googleapis.com');
        expect(
          requests.last.headers['Authorization'],
          'Bearer fresh-gemini-access',
        );
      },
    );

    test('refreshes AI Studio OAuth before model discovery', () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          if (options.uri.host == 'oauth2.googleapis.com') {
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'fresh-aistudio-access',
                'refresh_token': 'rotated-aistudio-refresh',
                'expires_in': 3600,
              }),
              200,
            );
          }
          return ResponseBody.fromString(jsonEncode({'models': []}), 200);
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: dio,
      );
      final account = await service.saveAccount(
        LlmAccount(
          id: 'aistudio-discovery-expired-oauth',
          connectorType: 'aistudio',
          authType: 'oauth',
          displayName: 'Google AI Studio',
          endpointConfig: const {'googleCloudProjectId': 'my-cloud-project'},
        ),
        secret: jsonEncode({
          'access_token': 'expired-aistudio-access',
          'refresh_token': 'aistudio-refresh-token',
          'client_id': 'desktop-client.apps.googleusercontent.com',
          'client_secret': 'secure-client-secret',
          'expires_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'oauth_contract': 'google-gemini-developer-api-v1',
        }),
      );

      await service.discoverModels(account, refreshRemote: true);

      expect(requests, hasLength(2));
      expect(requests.first.uri.host, 'oauth2.googleapis.com');
      expect(requests.last.uri.host, 'generativelanguage.googleapis.com');
      expect(
        requests.last.headers['Authorization'],
        'Bearer fresh-aistudio-access',
      );
      expect(requests.last.headers['x-goog-user-project'], 'my-cloud-project');
    });

    test(
      'retries Gemini OAuth model discovery after an unauthorized response',
      () async {
        final modelRequests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.host == 'oauth2.googleapis.com') {
              return ResponseBody.fromString(
                jsonEncode({
                  'access_token': 'fresh-gemini-access',
                  'refresh_token': 'rotated-gemini-refresh',
                  'expires_in': 3600,
                }),
                200,
              );
            }
            modelRequests.add(options);
            if (modelRequests.length == 1) {
              return ResponseBody.fromString('{}', 401);
            }
            return ResponseBody.fromString(jsonEncode({'models': []}), 200);
          });
        final service = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await service.saveAccount(
          LlmAccount(
            id: 'gemini-discovery-unauthorized-oauth',
            connectorType: 'gemini',
            authType: 'oauth',
            displayName: 'Gemini Developer API',
            endpointConfig: const {'googleCloudProjectId': 'my-cloud-project'},
          ),
          secret: jsonEncode({
            'access_token': 'stale-gemini-access',
            'refresh_token': 'gemini-refresh-token',
            'client_id': 'desktop-client.apps.googleusercontent.com',
            'client_secret': 'secure-client-secret',
            'oauth_contract': 'google-gemini-developer-api-v1',
          }),
        );

        await service.discoverModels(account, refreshRemote: true);

        expect(modelRequests, hasLength(2));
        expect(
          modelRequests.first.headers['Authorization'],
          'Bearer stale-gemini-access',
        );
        expect(
          modelRequests.last.headers['Authorization'],
          'Bearer fresh-gemini-access',
        );
      },
    );

    test('follows Gemini model discovery pagination tokens', () async {
      final requestedUris = <Uri>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestedUris.add(options.uri);
          final page = options.uri.queryParameters['pageToken'];
          return ResponseBody.fromString(
            jsonEncode(
              page == null
                  ? {
                      'models': [
                        {
                          'name': 'models/gemini-3.1-pro',
                          'supportedGenerationMethods': ['generateContent'],
                        },
                      ],
                      'nextPageToken': 'next-page-token',
                    }
                  : {
                      'models': [
                        {
                          'name': 'models/gemini-3.1-flash',
                          'supportedGenerationMethods': ['generateContent'],
                        },
                      ],
                    },
            ),
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
        _account('gemini-paginated-discovery', 'gemini'),
        secret: 'gemini-private-key',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(requestedUris, hasLength(2));
      expect(requestedUris.first.queryParameters, isEmpty);
      expect(
        requestedUris.last.queryParameters['pageToken'],
        'next-page-token',
      );
      expect(models.map((model) => model.upstreamModelId), [
        'gemini-3.1-pro',
        'gemini-3.1-flash',
      ]);
    });

    test(
      'bounds Gemini model discovery when every page returns a new token',
      () async {
        var requestCount = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestCount++;
            return ResponseBody.fromString(
              jsonEncode({'models': [], 'nextPageToken': 'page-$requestCount'}),
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
          _account('gemini-unbounded-discovery', 'gemini'),
          secret: 'gemini-private-key',
        );

        await expectLater(
          discoveryService.discoverModels(account, refreshRemote: true),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(requestCount, 100);
      },
    );

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
      'preserves explicit false capabilities from compatible model discovery',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromString(
              jsonEncode({
                'data': [
                  {
                    'id': 'non-streaming-model',
                    'capabilities': {'chat': true, 'streaming': false},
                  },
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
            id: 'explicit-capabilities',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Compatible endpoint',
            endpointConfig: const {'baseUrl': 'https://llm.example.test/v1'},
          ),
          secret: 'capability-discovery-key',
        );

        final models = await discoveryService.discoverModels(
          account,
          refreshRemote: true,
        );

        expect(models.single.capabilities, {'chat': true, 'streaming': false});
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

    test('discovers Ollama model capabilities from its native API', () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          final body = options.uri.path.endsWith('/tags')
              ? {
                  'models': [
                    {
                      'name': 'llama3.2',
                      'details': {'family': 'llama'},
                    },
                  ],
                }
              : {
                  'capabilities': ['completion', 'tools'],
                };
          return ResponseBody.fromString(
            jsonEncode(body),
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
          id: 'ollama-discovery',
          connectorType: 'ollama',
          authType: 'none',
          displayName: 'Ollama',
          status: LlmAccountStatus.ready,
          endpointConfig: const {'baseUrl': 'http://localhost:11434'},
        ),
      );

      final models = await discoveryService.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(requests.map((request) => request.uri.path), [
        '/api/tags',
        '/api/show',
      ]);
      expect(models.single.upstreamModelId, 'llama3.2');
      expect(models.single.capabilities, {
        'chat': true,
        'streaming': true,
        'tools': true,
      });
      expect(models.single.config['extensions'], contains('ollama'));
    });

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
            'client_id': 'registered-openai-oauth-client',
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
        expect(
          captured?.uri.toString(),
          'https://auth.openai.com/api/accounts/oauth/token',
        );
        expect(captured?.method, 'POST');
        expect(refreshed['access_token'], 'fresh-access-token');
        expect(refreshed['refresh_token'], 'fresh-refresh-token');
        expect(storedAccounts, isNot(contains('fresh-access-token')));
      },
    );

    test(
      'retries Cursor refresh after transient network and server failures',
      () async {
        var attempt = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            attempt++;
            if (attempt == 1) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              );
            }
            if (attempt == 2) {
              return ResponseBody.fromString(
                jsonEncode({'error': 'temporarily unavailable'}),
                503,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            return ResponseBody.fromString(
              jsonEncode({'accessToken': 'cursor-retried-access'}),
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
          _account('cursor-retry', 'cursor', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'cursor-old-access',
            'refresh_token': 'cursor-refresh-token',
          }),
        );

        expect(await refreshService.refreshCredential(account), isTrue);
        expect(attempt, 3);
        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        expect(refreshed['access_token'], 'cursor-retried-access');
        expect(refreshed['refresh_token'], 'cursor-refresh-token');
      },
    );

    test(
      'refreshes Gemini Developer API OAuth and retains client config',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'fresh-gemini-access',
                'refresh_token': 'rotated-gemini-refresh',
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
          _account('gemini-oauth', 'gemini', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'old-gemini-access',
            'refresh_token': 'old-gemini-refresh',
            'client_id': 'desktop-client.apps.googleusercontent.com',
            'client_secret': 'secure-client-secret',
            'oauth_contract': 'google-gemini-developer-api-v1',
          }),
        );

        expect(await refreshService.refreshCredential(account), isTrue);
        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        expect(captured?.uri.toString(), 'https://oauth2.googleapis.com/token');
        expect(captured?.data.toString(), contains('old-gemini-refresh'));
        expect(captured?.data.toString(), contains('secure-client-secret'));
        expect(refreshed['access_token'], 'fresh-gemini-access');
        expect(refreshed['refresh_token'], 'rotated-gemini-refresh');
        expect(
          refreshed['client_id'],
          'desktop-client.apps.googleusercontent.com',
        );
        expect(refreshed['client_secret'], 'secure-client-secret');
      },
    );

    test(
      'refreshes Claude Code OAuth and retains refreshed account identity',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'fresh-claude-access',
                'refresh_token': 'rotated-claude-refresh',
                'expires_in': 3600,
                'account': {
                  'uuid': 'refreshed-account-id',
                  'email_address': 'user@example.test',
                },
                'organization': {
                  'uuid': 'refreshed-org-id',
                  'name': 'Claude Org',
                },
              }),
              200,
            );
          });
        final refreshService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await refreshService.saveAccount(
          _account('claude-refresh-oauth', 'claude', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'expired-claude-access',
            'refresh_token': 'old-claude-refresh',
            'account_uuid': 'claude-account-id',
            'organization_uuid': 'claude-org-id',
          }),
        );

        expect(await refreshService.refreshCredential(account), isTrue);

        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        expect(
          captured?.uri.toString(),
          'https://platform.claude.com/v1/oauth/token',
        );
        expect(
          captured?.data,
          containsPair('refresh_token', 'old-claude-refresh'),
        );
        expect(refreshed['access_token'], 'fresh-claude-access');
        expect(refreshed['refresh_token'], 'rotated-claude-refresh');
        expect(refreshed['account_uuid'], 'refreshed-account-id');
        expect(refreshed['email'], 'user@example.test');
        expect(refreshed['organization_uuid'], 'refreshed-org-id');
        expect(refreshed['organization_name'], 'Claude Org');
      },
    );

    test(
      'refreshes each xAI OAuth mode without crossing API-key identity',
      () async {
        final captured = <String, RequestOptions>{};
        Object? responseScope;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured[options.uri.host] = options;
            final tokenResponse = <String, Object?>{
              'access_token': 'fresh-${options.data['refresh_token']}',
              'refresh_token': 'rotated-${options.data['refresh_token']}',
              'expires_in': 3600,
            };
            if (responseScope != null) tokenResponse['scope'] = responseScope;
            return ResponseBody.fromString(
              jsonEncode(tokenResponse),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accountService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );

        for (final connectorType in ['grok-cli', 'xai-oauth']) {
          final expectedModeScope =
              connectorType == 'grok-cli' ? 'grok-cli:access' : 'api:access';
          responseScope =
              'openid profile email offline_access $expectedModeScope';
          final account = await accountService.saveAccount(
            _account(
              'refresh-$connectorType',
              connectorType,
              authType: 'oauth',
            ),
            secret: jsonEncode({
              'access_token': 'old-access',
              'refresh_token': 'refresh-$connectorType',
              'token_endpoint': 'https://auth.x.ai/oauth/token',
              'identity_sub': 'xai-account',
              'oauth_contract': 'xai-device-v1',
              'scope': responseScope,
            }),
          );

          expect(await accountService.refreshCredential(account), isTrue);
          final refreshed =
              jsonDecode((await accountService.readCredential(account.id))!)
                  as Map;
          expect(captured['auth.x.ai']?.uri.path, '/oauth/token');
          expect(
            captured['auth.x.ai']?.data['client_id'],
            'b1a00492-073a-47ea-816f-4c329264a828',
          );
          expect(refreshed['access_token'], 'fresh-refresh-$connectorType');
          expect(refreshed['refresh_token'], 'rotated-refresh-$connectorType');
          expect(refreshed['identity_sub'], 'xai-account');
          expect(refreshed['token_endpoint'], 'https://auth.x.ai/oauth/token');
          expect(refreshed['scope'], responseScope);
        }

        for (final connectorType in ['grok-cli', 'xai-oauth']) {
          final expectedModeScope =
              connectorType == 'grok-cli' ? 'grok-cli:access' : 'api:access';
          final oppositeModeScope =
              connectorType == 'grok-cli' ? 'api:access' : 'grok-cli:access';
          responseScope =
              'openid profile email offline_access $oppositeModeScope';
          final account = await accountService.saveAccount(
            _account(
              'refresh-mismatch-$connectorType',
              connectorType,
              authType: 'oauth',
            ),
            secret: jsonEncode({
              'access_token': 'old-access',
              'refresh_token': 'refresh-mismatch-$connectorType',
              'token_endpoint': 'https://auth.x.ai/oauth/token',
              'identity_sub': 'xai-account',
              'oauth_contract': 'xai-device-v1',
              'scope': 'openid profile email offline_access $expectedModeScope',
            }),
          );

          await expectLater(
            accountService.refreshCredential(account),
            throwsA(isA<LlmAccountConnectorException>()),
          );
          final unchanged =
              jsonDecode((await accountService.readCredential(account.id))!)
                  as Map;
          expect(unchanged['access_token'], 'old-access');
          expect(
            unchanged['scope'],
            'openid profile email offline_access $expectedModeScope',
          );
        }

        final apiKeyAccount = await accountService.saveAccount(
          _account('xai-api-key', 'xai'),
          secret: 'public-api-key',
        );
        expect(await accountService.refreshCredential(apiKeyAccount), isFalse);
        await expectLater(
          accountService.saveAccount(
            _account('xai-api-key-as-oauth', 'xai', authType: 'oauth'),
            secret: jsonEncode({'access_token': 'oauth-token'}),
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );

    test(
      'does not refresh CLI-only OAuth credentials without public contracts',
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

        for (final connector in ['antigravity', 'kimi', 'kimi-ai', 'kimi.ai']) {
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
            }),
          );

          expect(
            await refreshService.refreshCredential(account),
            isFalse,
            reason: connector,
          );
        }
        expect(refreshRequests, isEmpty);
      },
    );

    test(
      'refreshes Kimi Code OAuth through its device-flow token endpoint',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': 'fresh-kimi-code-access',
                'refresh_token': 'rotated-kimi-code-refresh',
                'token_type': 'Bearer',
                'expires_in': 3600,
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final refreshService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await refreshService.saveAccount(
          _account('refresh-kimi-coding', 'kimi-coding', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'old-kimi-code-access',
            'refresh_token': 'old-kimi-code-refresh',
            'device_id': 'kimi-device-1',
          }),
        );

        expect(await refreshService.refreshCredential(account), isTrue);

        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        expect(
          captured?.uri.toString(),
          'https://auth.kimi.com/api/oauth/token',
        );
        expect(captured?.data.toString(), contains('old-kimi-code-refresh'));
        expect(captured?.headers['X-Msh-Platform'], 'CLIProxyAPI');
        expect(captured?.headers['X-Msh-Device-Id'], 'kimi-device-1');
        expect(refreshed['access_token'], 'fresh-kimi-code-access');
        expect(refreshed['refresh_token'], 'rotated-kimi-code-refresh');
        expect(refreshed['device_id'], 'kimi-device-1');
      },
    );

    test(
      'requires secure Antigravity OAuth app credentials for refresh',
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
      },
    );

    test(
      'mints Muse OAuth keys without exposing credentials in account metadata',
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
                'user_email': 'muse@example.test',
                'is_subs_active': true,
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
          _account('muse-dca', 'muse-code', authType: 'oauth'),
          secret: jsonEncode({
            'dca_token': 'dca:fixture-device-token',
            'email': 'muse@example.test',
          }),
        );

        expect(
          LlmConnectorRegistry.find('muse-code')?.canRefreshCredentials,
          isTrue,
        );
        expect(await refreshService.refreshCredential(account), isTrue);
        expect(
          mintRequest?.uri.toString(),
          'https://api.meta.ai/muse-code/key',
        );
        expect(
          mintRequest?.headers['Authorization'],
          'Bearer dca:fixture-device-token',
        );
        final refreshed =
            jsonDecode((await refreshService.readCredential(account.id))!)
                as Map;
        final preferencesJson = preferences.values.values.join();
        expect(refreshed['api_key'], 'meta-private-api-key');
        expect(refreshed['access_token'], 'meta-private-api-key');
        expect(refreshed['email'], 'muse@example.test');
        expect(preferencesJson, isNot(contains('meta-private-api-key')));
        expect(preferencesJson, isNot(contains('dca:fixture-device-token')));
      },
    );

    test('rejects Muse DCA refresh without active entitled identity', () async {
      for (final minted in [
        {'api_key': 'unexpected-key', 'user_email': 'muse@example.test'},
        {
          'api_key': 'unexpected-key',
          'user_email': 'muse@example.test',
          'is_subs_active': 'true',
        },
        {'api_key': 'unexpected-key', 'is_subs_active': true},
        {
          'api_key': 'unexpected-key',
          'user_email': 'other@example.test',
          'is_subs_active': true,
        },
      ]) {
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromString(
              jsonEncode(minted),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final accountService = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await accountService.saveAccount(
          _account(
            'muse-refresh-reject-${minted.length}',
            'muse-code',
            authType: 'oauth',
          ),
          secret: jsonEncode({
            'access_token': 'old-muse-key',
            'api_key': 'old-muse-key',
            'dca_token': 'dca:fixture-device-token',
            'email': 'muse@example.test',
          }),
        );

        await expectLater(
          accountService.refreshCredential(account),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(
          await accountService.readCredential(account.id),
          contains('old-muse-key'),
        );
      }
    });
  });

  group('LlmNativeRequestBuilder', () {
    final builder = LlmNativeRequestBuilder();

    test('CheaperInference discovery keeps text models and excludes images',
        () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'gpt-5.4', 'type': 'text'},
                {'id': 'gpt-5.4-mini', 'type': 'text'},
                {'id': 'deepseek-v4-pro', 'type': 'text'},
                {'id': 'image-generator', 'type': 'image'},
              ],
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
        LlmAccount(
          id: 'cheaperinference-catalog',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'CheaperInference',
          endpointConfig: const {
            'baseUrl': 'https://api.cheaperinference.com/v1/chat/completions',
            'modelsUrl': 'https://api.cheaperinference.com/v1/models',
            'apiProtocol': 'openai.chat_completions',
            'providerPresetId': 'cheaperinference',
          },
          models: const [
            LlmUpstreamModel(
              id: 'gpt-5.4-local',
              upstreamModelId: 'gpt-5.4',
              displayName: 'GPT-5.4',
            ),
            LlmUpstreamModel(
              id: 'gpt-5.4-mini-local',
              upstreamModelId: 'gpt-5.4-mini',
              displayName: 'GPT-5.4 mini',
              config: {'apiProtocolOverride': 'openai.chat_completions'},
            ),
          ],
        ),
        secret: 'cheaperinference-catalog-key',
      );
      expect(account.endpointConfig['providerPresetId'], 'cheaperinference');

      final discovered = await accounts.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(captured?.uri,
          Uri.parse('https://api.cheaperinference.com/v1/models'));
      expect(
        captured?.headers['Authorization'],
        'Bearer cheaperinference-catalog-key',
      );
      expect(
        discovered.map((model) => model.upstreamModelId),
        ['gpt-5.4', 'gpt-5.4-mini', 'deepseek-v4-pro'],
      );
      expect(
        discovered[0].config['apiProtocolOverride'],
        'openai.responses',
      );
      expect(
        discovered[1].config['apiProtocolOverride'],
        'openai.chat_completions',
      );
      expect(discovered.last.config['apiProtocolOverride'], isNull);
    });

    test(
      'CheaperInference selects protocol-specific URL and stateless body',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({'output_text': 'ok'}),
              200,
              headers: const {
                'content-type': ['application/json']
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          _account(
            'cheaperinference-http',
            'openai-compatibility',
            endpointConfig: const {
              'baseUrl': 'https://api.cheaperinference.com/v1/chat/completions',
              'apiProtocol': 'openai.chat_completions',
              'providerPresetId': 'cheaperinference',
            },
            models: const [
              LlmUpstreamModel(
                id: 'cheaperinference-gpt-5.4',
                upstreamModelId: 'gpt-5.4',
                displayName: 'GPT-5.4',
                config: {'apiProtocolOverride': 'openai.responses'},
              ),
            ],
          ),
          secret: 'cheaperinference-secret',
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        await client.request(
          account: account,
          modelId: 'gpt-5.4',
          body: const {'model': 'gpt-5.4', 'input': [], 'store': true},
          nativeFormat: 'responses',
        );
        expect(
          captured?.uri,
          Uri.parse('https://api.cheaperinference.com/v1/responses'),
        );
        expect((captured?.data as Map)['store'], isFalse);
        expect((captured?.data as Map)['model'], 'gpt-5.4');
        expect(
          captured?.headers['Authorization'],
          'Bearer cheaperinference-secret',
        );

        await client.request(
          account: account,
          modelId: 'gpt-5.4',
          body: const {'model': 'gpt-5.4', 'input': []},
          nativeFormat: 'responses',
        );
        expect((captured?.data as Map)['store'], isFalse);

        await client.request(
          account: account,
          modelId: 'gpt-5.4',
          body: const {
            'model': 'gpt-5.4',
            'messages': [],
            'store': true,
          },
        );
        expect(
          captured?.uri,
          Uri.parse(
            'https://api.cheaperinference.com/v1/chat/completions',
          ),
        );
        expect((captured?.data as Map).containsKey('store'), isFalse);
        expect((captured?.data as Map)['messages'], isEmpty);
      },
    );

    test(
        'Azure deployment requests use the configured deployment and key header',
        () {
      final account = _account(
        'm50-azure-request',
        'azure-ai',
        endpointConfig: const {
          'baseUrl': 'https://example-resource.openai.azure.com',
          'azureDeploymentId': 'production chat',
          'apiVersion': '2024-12-01-preview',
        },
        models: const [
          LlmUpstreamModel(
            id: 'm50-azure-model',
            upstreamModelId: 'production chat',
            displayName: 'production chat',
            capabilities: {
              'chat': true,
              'streaming': true,
              'supportedApiProtocols': ['openai.chat_completions'],
            },
            config: {'catalogSource': 'configured-azure-deployment'},
          ),
        ],
      );
      final request = builder.build(
        account: account,
        credential: 'synthetic-azure-secret',
        modelId: 'production chat',
        body: const {'model': 'production chat', 'messages': []},
      );

      expect(request.uri.scheme, 'https');
      expect(request.uri.host, 'example-resource.openai.azure.com');
      expect(request.uri.path,
          '/openai/deployments/production%20chat/chat/completions');
      expect(
          request.uri.queryParameters, {'api-version': '2024-12-01-preview'});
      expect(request.headers['api-key'], 'synthetic-azure-secret');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.toString(), isNot(contains('synthetic-azure-secret')));
      expect(account.endpointConfig.toString(),
          isNot(contains('synthetic-azure-secret')));
      expect(
        () => builder.build(
          account: account,
          credential: 'synthetic-azure-secret',
          modelId: 'different-deployment',
          body: const {'model': 'different-deployment', 'messages': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('Azure discovery returns the configured deployment as its model ID',
        () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final saved = await service.saveAccount(
        _account(
          'm50-azure-refresh',
          'azure-ai',
          endpointConfig: const {
            'baseUrl': 'https://example-resource.services.ai.azure.com',
            'azureDeploymentId': 'foundry-deployment',
            'apiVersion': '2024-12-01-preview',
          },
          models: const [],
        ),
        secret: 'stored-azure-secret',
      );

      final models = await service.discoverModels(saved, refreshRemote: true);

      expect(
          models.map((model) => model.upstreamModelId), ['foundry-deployment']);
      expect(
          models.single.config['catalogSource'], 'configured-azure-deployment');
      expect(models.single.capabilities['supportedApiProtocols'], [
        'openai.chat_completions',
      ]);
      expect(await service.readCredential(saved.id), 'stored-azure-secret');
    });

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

    test('Kilo Code separates anonymous free routing from account auth', () {
      final anonymous = builder.build(
        account: _account('kilo-anonymous', 'kilocode', authType: 'none'),
        credential: null,
        modelId: 'openrouter/free',
        body: const {
          'model': 'openrouter/free',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        },
        stream: true,
      );
      expect(anonymous.uri.origin, 'https://api.kilo.ai');
      expect(anonymous.uri.path, '/api/openrouter/chat/completions');
      expect(anonymous.headers['Authorization'], 'Bearer anonymous');
      expect(anonymous.headers['X-KILOCODE-EDITORNAME'], 'Stroom');
      expect(anonymous.headers['Accept'], 'text/event-stream');

      expect(
        () => builder.build(
          account: _account('kilo-anonymous', 'kilocode', authType: 'none'),
          credential: null,
          modelId: 'openai/gpt-5.6-sol',
          body: const {'model': 'openai/gpt-5.6-sol', 'messages': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );

      final directKey = builder.build(
        account: _account('kilo-key', 'kilocode', authType: 'api_key'),
        credential: 'kilo-direct-key',
        modelId: 'openai/gpt-5.6-sol',
        body: const {'model': 'openai/gpt-5.6-sol', 'messages': []},
      );
      expect(directKey.headers['Authorization'], 'Bearer kilo-direct-key');

      final oauth = builder.build(
        account: _account('kilo-oauth', 'kilocode', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'kilo-oauth-token'}),
        modelId: 'openai/gpt-5.6-sol',
        body: const {'model': 'openai/gpt-5.6-sol', 'messages': []},
      );
      expect(oauth.headers['Authorization'], 'Bearer kilo-oauth-token');
      expect(oauth.headers['X-KILOCODE-EDITORNAME'], 'Stroom');
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

    test('accepts digits-only opaque API keys for custom endpoints', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'custom-numeric-api-key',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom numeric API key',
          endpointConfig: const {'baseUrl': 'https://api.example.test/v1'},
        ),
        credential: '1234567890',
        modelId: 'vendor-model',
        body: const {'model': 'vendor-model', 'messages': []},
      );

      expect(request.headers['Authorization'], 'Bearer 1234567890');
      expect(
        request.uri.toString(),
        'https://api.example.test/v1/chat/completions',
      );
    });

    test('routes CodeBuddy and WorkBuddy to their distinct chat gateways', () {
      final body = {
        'model': 'model-one',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'stream': false,
      };
      for (final (connector, host) in [
        ('codebuddy-cn', 'copilot.tencent.com'),
        ('codebuddy-intl', 'www.codebuddy.ai'),
      ]) {
        final request = builder.build(
          account: _account('tencent-key-$connector', connector),
          credential: 'plain-api-key',
          modelId: 'model-one',
          body: body,
        );
        expect(request.uri.toString(), 'https://$host/v2/chat/completions');
        expect(request.headers['Authorization'], 'Bearer plain-api-key');
        expect(request.headers['X-Product'], 'SaaS');
        expect((request.body as Map)['stream'], isTrue);
      }
      final workbuddy = builder.build(
        account: _account('workbuddy-oauth', 'workbuddy', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'workbuddy-access'}),
        modelId: 'model-one',
        body: body,
        conversationId: 'stroom-conversation-one',
      );
      expect(
        workbuddy.uri.toString(),
        'https://www.workbuddy.ai/v2/chat/completions',
      );
      expect(workbuddy.headers['Authorization'], 'Bearer workbuddy-access');
      expect(workbuddy.headers['X-Agent-Purpose'], 'conversation');
      expect(workbuddy.headers['X-Conversation-ID'], isNotEmpty);
      expect((workbuddy.body as Map)['stream'], isTrue);
      final sameConversation = builder.build(
        account: _account('workbuddy-oauth', 'workbuddy', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'workbuddy-access'}),
        modelId: 'model-one',
        body: const {
          'model': 'model-one',
          'messages': [
            {'role': 'user', 'content': 'a different turn'},
          ],
        },
        conversationId: 'stroom-conversation-one',
      );
      final otherConversation = builder.build(
        account: _account('workbuddy-oauth', 'workbuddy', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'workbuddy-access'}),
        modelId: 'model-one',
        body: body,
        conversationId: 'stroom-conversation-two',
      );
      expect(
        sameConversation.headers['X-Conversation-ID'],
        workbuddy.headers['X-Conversation-ID'],
      );
      expect(
        otherConversation.headers['X-Conversation-ID'],
        isNot(workbuddy.headers['X-Conversation-ID']),
      );
    });

    test(
      'routes regional GLM and MiniMax API-key accounts to service hosts',
      () {
        for (final (connectorType, expectedUri) in [
          (
            'glm-cn',
            'https://open.bigmodel.cn/api/coding/paas/v4/chat/completions',
          ),
          ('minimax-cn', 'https://api.minimaxi.com/v1/chat/completions'),
        ]) {
          final request = builder.build(
            account: _account('regional-$connectorType', connectorType),
            credential: 'regional-provider-key',
            modelId: 'service-model',
            body: const {'model': 'service-model', 'messages': []},
          );

          expect(request.uri.toString(), expectedUri, reason: connectorType);
          expect(
            request.headers['Authorization'],
            'Bearer regional-provider-key',
            reason: connectorType,
          );
        }
      },
    );

    test('routes Qwen Cloud key types and API protocols independently', () {
      final paygChat = builder.build(
        account: _account('qwen-cloud-payg', 'qwen-cloud'),
        credential: 'qwen-cloud-key',
        modelId: 'qwen3.7-plus',
        body: const {'model': 'qwen3.7-plus', 'messages': []},
      );
      final planChat = builder.build(
        account: _account('qwen-cloud-plan', 'qwen-cloud-token-plan'),
        credential: 'qwen-cloud-plan-key',
        modelId: 'qwen3.7-plus',
        body: const {'model': 'qwen3.7-plus', 'messages': []},
      );
      final planResponses = builder.build(
        account: _account('qwen-cloud-plan', 'qwen-cloud-token-plan'),
        credential: 'qwen-cloud-plan-key',
        modelId: 'qwen3.7-plus',
        body: const {'model': 'qwen3.7-plus', 'input': []},
        nativeFormat: 'responses',
      );
      final planAnthropic = builder.build(
        account: _account('qwen-cloud-plan', 'qwen-cloud-token-plan'),
        credential: 'qwen-cloud-plan-key',
        modelId: 'qwen3.7-plus',
        body: const {'model': 'qwen3.7-plus', 'messages': []},
        nativeFormat: 'anthropic',
      );

      expect(
        paygChat.uri.toString(),
        'https://ap-southeast-1.maas.qwencloudapi.com/compatible-mode/v1/chat/completions',
      );
      expect(
        planChat.uri.toString(),
        'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1/chat/completions',
      );
      expect(
        planResponses.uri.toString(),
        'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1/responses',
      );
      expect(
        planAnthropic.uri.toString(),
        'https://token-plan.maas.qwencloudapi.com/apps/anthropic/v1/messages',
      );
      expect(paygChat.headers['Authorization'], 'Bearer qwen-cloud-key');
      for (final request in [planChat, planResponses]) {
        expect(request.headers['Authorization'], 'Bearer qwen-cloud-plan-key');
      }
      expect(planAnthropic.headers['x-api-key'], 'qwen-cloud-plan-key');
      expect(planAnthropic.headers, isNot(contains('Authorization')));
      expect(planAnthropic.headers['anthropic-version'], '2023-06-01');
    });

    test(
      'regional Qwen account persists key separately from account JSON',
      () async {
        final preferences = _MemoryPreferences();
        final credentialStore = _MemoryCredentials();
        final service = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentialStore,
        );
        final account = await service.saveAccount(
          LlmAccount(
            id: 'qwen-cloud-cn',
            connectorType: 'qwen-cloud',
            authType: 'api_key',
            displayName: 'Qwen Cloud Beijing',
            endpointConfig: const {'region': 'cn-beijing'},
          ),
          secret: 'qwen-cloud-private-key',
        );

        expect(account.endpointConfig['region'], 'cn-beijing');
        expect(
          jsonEncode(account.toMap()),
          isNot(contains('qwen-cloud-private-key')),
        );
        expect(
          preferences.values.values.join('\n'),
          isNot(contains('qwen-cloud-private-key')),
        );
        expect(
          await service.readCredential(account.id),
          'qwen-cloud-private-key',
        );
        expect(
          credentialStore.values.values,
          contains('qwen-cloud-private-key'),
        );
      },
    );

    test('uses the Anthropic Messages path on a custom connector', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'custom-anthropic-endpoint',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: 'Custom Anthropic endpoint',
          endpointConfig: const {
            'baseUrl': 'https://api.example.test/v1/chat/completions',
          },
        ),
        credential: 'custom-api-key',
        modelId: 'claude-model',
        body: const {'model': 'claude-model', 'messages': []},
        nativeFormat: 'anthropic',
      );

      expect(request.uri.toString(), 'https://api.example.test/v1/messages');
      expect(request.headers['Authorization'], 'Bearer custom-api-key');
      expect(request.headers['anthropic-version'], '2023-06-01');
    });

    test('does not duplicate full Responses or Messages endpoint suffixes', () {
      for (final (path, nativeFormat) in [
        ('/v1/responses', 'responses'),
        ('/v1/messages', 'anthropic'),
      ]) {
        final request = builder.build(
          account: LlmAccount(
            id: 'custom-full-endpoint',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Custom endpoint',
            endpointConfig: {'baseUrl': 'https://api.example.test$path'},
          ),
          credential: 'custom-api-key',
          modelId: 'vendor-model',
          body: const {'model': 'vendor-model'},
          nativeFormat: nativeFormat,
        );

        expect(request.uri.path, path);
      }
    });

    test('rejects custom Bedrock endpoints outside the configured region', () {
      expect(
        () => builder.build(
          account: LlmAccount(
            id: 'bedrock-foreign-endpoint',
            connectorType: 'bedrock',
            authType: 'aws_credentials',
            displayName: 'Bedrock',
            endpointConfig: const {
              'region': 'us-east-1',
              'baseUrl': 'https://bedrock-runtime.attacker.example',
            },
          ),
          credential: jsonEncode({
            'accessKeyId': 'AKIDEXAMPLE',
            'secretAccessKey': 'private-aws-secret',
          }),
          awsCredentials: const AwsSigV4Credentials(
            accessKeyId: 'AKIDEXAMPLE',
            secretAccessKey: 'private-aws-secret',
          ),
          modelId: 'anthropic.claude-3-5-sonnet-20241022-v2:0',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('does not send a Bedrock API key to an untrusted endpoint', () async {
      var requestsSent = 0;
      final credentials = _MemoryCredentials();
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestsSent++;
          return ResponseBody.fromString('{}', 200);
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
        dio: dio,
      );
      final account = await accounts.saveAccount(
        _account(
          'bedrock-api-key-foreign-endpoint',
          'bedrock',
          authType: 'api_key',
          endpointConfig: const {
            'region': 'us-east-1',
            'baseUrl': 'https://bedrock-runtime.attacker.example',
          },
        ),
        secret: 'bedrock-private-api-key',
      );

      await expectLater(
        LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'amazon.titan-text-express-v1',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        ),
        throwsA(isA<LlmConnectorHttpException>()),
      );

      expect(requestsSent, 0);
      expect(
        credentials.values[account.credentialRef],
        'bedrock-private-api-key',
      );
    });

    test('uses the AWS China host for Bedrock requests in cn regions', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'bedrock-china-region',
          connectorType: 'bedrock',
          authType: 'aws_credentials',
          displayName: 'Bedrock',
          endpointConfig: const {'region': 'cn-north-1'},
        ),
        credential: jsonEncode({
          'accessKeyId': 'AKIDEXAMPLE',
          'secretAccessKey': 'private-aws-secret',
        }),
        awsCredentials: const AwsSigV4Credentials(
          accessKeyId: 'AKIDEXAMPLE',
          secretAccessKey: 'private-aws-secret',
        ),
        modelId: 'amazon.titan-text-express-v1',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        },
      );

      expect(request.uri.host, 'bedrock-runtime.cn-north-1.amazonaws.com.cn');
    });

    test('rejects malformed Bedrock regions before constructing a host', () {
      expect(
        () => builder.build(
          account: _account(
            'bedrock-invalid-region',
            'bedrock',
            authType: 'api_key',
            endpointConfig: const {'region': 'not-a-region'},
          ),
          credential: 'bedrock-api-key',
          modelId: 'amazon.titan-text-express-v1',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('uses Anthropic Messages with Claude Code OAuth credentials', () {
      final request = builder.build(
        account: _account('claude-1', 'claude', authType: 'oauth'),
        credential: jsonEncode({'access_token': 'claude-access-secret'}),
        modelId: 'claude-sonnet-4-6',
        body: const {'model': 'claude-sonnet-4-6', 'messages': []},
      );

      expect(request.uri.path, '/v1/messages');
      expect(request.uri.queryParameters['beta'], 'true');
      expect(request.headers['Authorization'], 'Bearer claude-access-secret');
      expect(request.headers['anthropic-beta'], contains('oauth-2025-04-20'));
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(request.headers['X-App'], 'cli');
      expect(request.toString(), isNot(contains('claude-access-secret')));
    });

    test('uses Anthropic Messages with a Setup Token bearer credential', () {
      const setupToken = 'sk-ant-oat01-private-setup-token';
      final request = builder.build(
        account: _account(
          'claude-setup-request',
          'claude',
          authType: 'setup_token',
        ),
        credential: setupToken,
        modelId: 'claude-sonnet-4-6',
        body: const {'model': 'claude-sonnet-4-6', 'messages': []},
      );

      expect(request.uri.path, '/v1/messages');
      expect(request.headers['Authorization'], 'Bearer $setupToken');
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(
        request.headers['anthropic-beta'],
        contains('claude-code-20250219'),
      );
      expect(request.headers.containsKey('x-api-key'), isFalse);
      expect(request.toString(), isNot(contains(setupToken)));
    });

    test('keeps Claude Console API keys on x-api-key authentication', () {
      final request = builder.build(
        account: _account('claude-console-key', 'claude', authType: 'api_key'),
        credential: 'console-api-key',
        modelId: 'claude-sonnet-4-6',
        body: const {'model': 'claude-sonnet-4-6', 'messages': []},
      );

      expect(request.headers['x-api-key'], 'console-api-key');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.uri.queryParameters.containsKey('beta'), isFalse);
    });

    test('uses Responses for Codex, Grok Build, and Muse OAuth', () {
      for (final connector in ['codex', 'grok-cli', 'muse-code']) {
        final modelId = connector == 'muse-code' ? 'muse-spark-1.3' : 'model-1';
        final models = connector == 'muse-code'
            ? [
                LlmUpstreamModel(
                  id: 'muse-model',
                  upstreamModelId: modelId,
                  displayName: modelId,
                ),
              ]
            : connector == 'grok-cli'
                ? [_upstreamModel('model-1')]
                : const <LlmUpstreamModel>[];
        final credential = connector == 'muse-code'
            ? jsonEncode({
                'access_token': 'muse-minted-key',
                'api_key': 'muse-minted-key',
                'dca_token': 'dca:muse-device-token',
              })
            : jsonEncode({
                'access_token': '$connector-access',
                if (connector == 'codex') 'account_id': 'codex-account-1',
              });
        final request = builder.build(
          account: _account(
            '$connector-1',
            connector,
            authType: 'oauth',
            models: models,
          ),
          credential: credential,
          modelId: modelId,
          body: {'model': modelId, 'input': []},
        );

        expect(request.uri.path, endsWith('/responses'), reason: connector);
        expect(request.method, 'POST');
        expect(
          request.headers['Authorization'],
          'Bearer ${connector == 'muse-code' ? 'muse-minted-key' : '$connector-access'}',
        );
        if (connector == 'codex') {
          expect(request.headers['Chatgpt-Account-Id'], 'codex-account-1');
        }
      }
    });

    test('uses public xAI and Meta API-key Responses requests', () {
      for (final connector in ['xai', 'meta']) {
        final account = _account('$connector-api-key', connector);
        final nonStreaming = builder.build(
          account: account,
          credential: '$connector-secret',
          modelId: '$connector-chat-model',
          body: {
            'model': '$connector-chat-model',
            'input': [],
            'stream': false,
          },
          nativeFormat: 'responses',
        );
        final streaming = builder.build(
          account: account,
          credential: '$connector-secret',
          modelId: '$connector-chat-model',
          body: {'model': '$connector-chat-model', 'input': []},
          stream: true,
          nativeFormat: 'responses',
        );
        final expectedBase = connector == 'xai'
            ? 'https://api.x.ai/v1'
            : 'https://api.meta.ai/v1';

        expect(nonStreaming.uri, Uri.parse('$expectedBase/responses'));
        expect(streaming.uri, Uri.parse('$expectedBase/responses'));
        expect(nonStreaming.method, 'POST');
        expect(
          nonStreaming.headers['Authorization'],
          'Bearer $connector-secret',
        );
        expect(streaming.headers['Authorization'], 'Bearer $connector-secret');
        expect((nonStreaming.body as Map)['model'], '$connector-chat-model');
        expect((nonStreaming.body as Map)['stream'], isFalse);
        expect((streaming.body as Map)['model'], '$connector-chat-model');
        expect((streaming.body as Map)['stream'], isTrue);
      }
    });

    test(
      'keeps Grok Build and native xAI OAuth request contracts separate',
      () {
        final grok = builder.build(
          account: _account(
            'grok-build',
            'grok-cli',
            authType: 'oauth',
            models: [_upstreamModel('grok-4.7')],
          ),
          credential: jsonEncode({'access_token': 'grok-build-access'}),
          modelId: 'grok-4.7',
          body: const {'model': 'grok-4.7', 'input': []},
          nativeFormat: 'responses',
        );
        final xai = builder.build(
          account: _account(
            'xai-oauth',
            'xai-oauth',
            authType: 'oauth',
            models: [_upstreamModel('grok-4.7')],
          ),
          credential: jsonEncode({'access_token': 'xai-api-access'}),
          modelId: 'grok-4.7',
          body: const {'model': 'grok-4.7', 'input': []},
          nativeFormat: 'responses',
        );

        expect(
          grok.uri,
          Uri.parse('https://cli-chat-proxy.grok.com/v1/responses'),
        );
        expect(grok.headers['Authorization'], 'Bearer grok-build-access');
        expect(grok.headers['X-XAI-Token-Auth'], 'xai-grok-cli');
        expect(grok.headers['x-grok-client-identifier'], 'grok-shell');
        expect(
          (grok.body as Map)['include'],
          contains('reasoning.encrypted_content'),
        );
        expect(xai.uri, Uri.parse('https://api.x.ai/v1/responses'));
        expect(xai.headers['Authorization'], 'Bearer xai-api-access');
        expect(xai.headers.containsKey('X-XAI-Token-Auth'), isFalse);
        expect(xai.headers.containsKey('x-grok-client-identifier'), isFalse);
      },
    );

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
          _account(
            'stream-grok-cli',
            'grok-cli',
            authType: 'oauth',
            models: [_upstreamModel('model-1')],
          ),
          jsonEncode({'access_token': 'grok-cli-token'}),
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
      for (final connector in [
        'openai-api',
        'moonshot',
        'glm',
        'deepseek',
        'minimax',
        'qwen',
      ]) {
        cases.add((
          _account('stream-$connector', connector),
          '$connector-api-key',
          null,
        ));
      }

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

    test('routes OpenAI Responses and Ollama Chat to native endpoints', () {
      final responses = builder.build(
        account: _account('openai-responses', 'openai-api'),
        credential: 'openai-key',
        modelId: 'gpt-4.1',
        body: const {'model': 'gpt-4.1', 'input': []},
        nativeFormat: 'responses',
      );
      final ollama = builder.build(
        account: LlmAccount(
          id: 'ollama-local',
          connectorType: 'ollama',
          authType: 'none',
          displayName: 'Ollama local',
          endpointConfig: const {'baseUrl': 'http://localhost:11434'},
        ),
        credential: null,
        modelId: 'llama3.2',
        body: const {'model': 'llama3.2', 'messages': []},
      );

      expect(responses.uri.path, '/v1/responses');
      expect(responses.headers['Authorization'], 'Bearer openai-key');
      expect(ollama.uri.toString(), 'http://localhost:11434/api/chat');
      expect(ollama.headers['Authorization'], isNull);
    });

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

    test('keeps legacy Vertex region settings routable', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'vertex-legacy-region',
          connectorType: 'vertex',
          authType: 'api_key',
          displayName: 'Vertex legacy account',
          endpointConfig: const {
            'projectId': 'my-project',
            'region': 'europe-west4',
          },
        ),
        credential: 'vertex-api-secret',
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(request.uri.host, 'europe-west4-aiplatform.googleapis.com');
      expect(request.uri.path, contains('/locations/europe-west4/'));
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
      expect(body['request']['sessionId'], '-3238736544897475342');
      expect(body['requestId'], startsWith('agent-'));

      final fallback = builder.build(
        account: LlmAccount(
          id: 'antigravity-fallback-session',
          connectorType: 'antigravity',
          authType: 'oauth',
          displayName: 'Antigravity',
        ),
        credential: jsonEncode({'access_token': 'antigravity-access'}),
        modelId: 'gemini-3.1-pro',
        body: const {
          'request': {'contents': []},
        },
      );
      expect(
        ((fallback.body as Map)['request'] as Map)['sessionId'],
        matches(RegExp(r'^-\d+$')),
      );
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

    test('prepares API-key AI Studio requests for Generative Language HTTP',
        () {
      const content = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'summarize this image'},
              {
                'inlineData': {'mimeType': 'image/png', 'data': 'aW1hZ2U='},
              },
            ],
          },
        ],
      };
      final request = builder.build(
        account: _account('aistudio-api-key', 'aistudio'),
        credential: 'aistudio-private-key',
        modelId: 'gemini-3.1-pro',
        body: content,
      );

      expect(
        request.uri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
      );
      expect(request.headers['x-goog-api-key'], 'aistudio-private-key');
      expect(request.body, content);
      expect(request.toString(), isNot(contains('aistudio-private-key')));
    });

    test('prepares AI Studio OAuth requests with project attribution', () {
      final request = builder.build(
        account: LlmAccount(
          id: 'aistudio-oauth',
          connectorType: 'aistudio',
          authType: 'oauth',
          displayName: 'Google AI Studio',
          endpointConfig: const {'googleCloudProjectId': 'stroom-project'},
        ),
        credential: jsonEncode({'access_token': 'aistudio-oauth-token'}),
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
        stream: true,
      );

      expect(request.uri.path, contains(':streamGenerateContent'));
      expect(request.uri.queryParameters['alt'], 'sse');
      expect(request.headers['Authorization'], 'Bearer aistudio-oauth-token');
      expect(request.headers['x-goog-user-project'], 'stroom-project');
      expect(request.toString(), isNot(contains('aistudio-oauth-token')));
    });

    test('rejects AI Studio OAuth without Cloud project attribution', () {
      expect(
        () => builder.build(
          account: _account(
            'aistudio-oauth-no-project',
            'aistudio',
            authType: 'oauth',
          ),
          credential: jsonEncode({'access_token': 'aistudio-oauth-token'}),
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

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

    test('routes only mapped Devin OAuth models through Connect-RPC', () {
      const sessionToken = r'devin-session-token$fixture-oauth-token';
      final account = LlmAccount(
        id: 'devin-oauth',
        connectorType: 'devin',
        authType: 'oauth',
        displayName: 'Devin account',
        models: const [
          LlmUpstreamModel(
            id: 'devin-oauth-model',
            upstreamModelId: 'devin/swe-2',
            displayName: 'SWE-2',
          ),
        ],
      );
      final request = builder.build(
        account: account,
        credential: jsonEncode({
          'session_token': sessionToken,
          'oauth_contract': 'devin-pkce-v1',
          'auth_kind': 'oauth',
          'user_id': 'devin-user',
          'plan': 'Team',
        }),
        modelId: 'devin/swe-2',
        body: const {
          'model': 'devin/swe-2',
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        },
      );

      expect(
        request.uri.toString(),
        'https://server.codeium.com/exa.api_server_pb.ApiServerService/GetChatMessage',
      );
      expect(
        request.headers['Authorization'],
        'Basic $sessionToken-$sessionToken',
      );
      expect(request.headers['Connect-Protocol-Version'], '1');
      expect(request.headers['Content-Type'], 'application/connect+proto');
      expect(request.headers['Accept'], '*/*');
      expect(request.body, isA<Uint8List>());
      expect(request.toString(), isNot(contains(sessionToken)));
    });

    test(
      'rejects Devin OAuth model IDs without a mapped account entitlement',
      () {
        final account = LlmAccount(
          id: 'devin-oauth',
          connectorType: 'devin',
          authType: 'oauth',
          displayName: 'Devin account',
          models: const [],
        );
        expect(
          () => builder.build(
            account: account,
            credential: jsonEncode({
              'session_token': r'devin-session-token$fixture',
            }),
            modelId: 'devin/unknown-model',
            body: Uint8List.fromList([0, 1, 2]),
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
      },
    );

    test('rejects expired Devin OAuth entitlements at request time', () {
      final account = LlmAccount(
        id: 'devin-oauth-expired',
        connectorType: 'devin',
        authType: 'oauth',
        displayName: 'Devin account',
        models: const [
          LlmUpstreamModel(
            id: 'devin-model',
            upstreamModelId: 'devin/swe-2',
            displayName: 'SWE-2',
          ),
        ],
      );
      expect(
        () => builder.build(
          account: account,
          credential: jsonEncode({
            'session_token': r'devin-session-token$fixture',
            'oauth_contract': 'devin-pkce-v1',
            'auth_kind': 'oauth',
            'user_id': 'devin-user',
            'plan': 'Team',
            'plan_end': '2000-01-01T00:00:00Z',
          }),
          modelId: 'devin/swe-2',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('routes Kimi Code OAuth by the selected upstream protocol', () {
      final account = _account(
        'kimi-code-oauth',
        'kimi-coding',
        authType: 'oauth',
      );
      final credential = jsonEncode({
        'access_token': 'kimi-code-access',
        'device_id': 'device-1',
      });

      final chatCompletions = builder.build(
        account: account,
        credential: credential,
        modelId: 'kimi-for-coding',
        body: const {'model': 'kimi-for-coding', 'messages': []},
      );
      final responses = builder.build(
        account: account,
        credential: credential,
        modelId: 'kimi-for-coding-highspeed',
        body: const {'model': 'kimi-for-coding-highspeed', 'input': []},
        nativeFormat: 'responses',
      );

      expect(
        chatCompletions.uri.toString(),
        'https://api.kimi.com/coding/v1/chat/completions',
      );
      expect(
        responses.uri.toString(),
        'https://api.kimi.com/coding/v1/responses',
      );
      expect(
        chatCompletions.headers['Authorization'],
        'Bearer kimi-code-access',
      );
      expect(chatCompletions.headers['X-Msh-Platform'], 'CLIProxyAPI');
      expect(chatCompletions.headers['X-Msh-Device-Id'], 'device-1');
      expect(chatCompletions.toString(), isNot(contains('kimi-code-access')));
    });

    test('rejects Kimi Code models outside its source-backed catalog', () {
      expect(
        () => builder.build(
          account: _account(
            'kimi-code-oauth',
            'kimi-coding',
            authType: 'oauth',
          ),
          credential: jsonEncode({'access_token': 'kimi-code-access'}),
          modelId: 'kimi-k2-thinking',
          body: const {'model': 'kimi-k2-thinking', 'messages': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });

    test('keeps legacy Devin token accounts out of OAuth streaming', () {
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

    test(
      'builds public Gemini Developer API OAuth requests with bearer auth',
      () {
        final request = builder.build(
          account: LlmAccount(
            id: 'gemini-developer-oauth',
            connectorType: 'gemini',
            authType: 'oauth',
            displayName: 'Gemini Developer API',
            endpointConfig: const {'googleCloudProjectId': 'my-cloud-project'},
          ),
          credential: jsonEncode({'access_token': 'gemini-access-token'}),
          modelId: 'gemini-2.5-flash',
          body: const {'contents': []},
        );

        expect(request.uri.host, 'generativelanguage.googleapis.com');
        expect(request.headers['Authorization'], 'Bearer gemini-access-token');
        expect(request.headers['x-goog-user-project'], 'my-cloud-project');
        expect(request.headers.containsKey('x-goog-api-key'), isFalse);
      },
    );

    test('requires project attribution for Gemini OAuth requests', () {
      expect(
        () => builder.build(
          account: LlmAccount(
            id: 'gemini-oauth-no-project',
            connectorType: 'gemini',
            authType: 'oauth',
            displayName: 'Gemini Developer API',
          ),
          credential: jsonEncode({'access_token': 'gemini-access-token'}),
          modelId: 'gemini-2.5-flash',
          body: const {'contents': []},
        ),
        throwsA(isA<LlmAccountConnectorException>()),
      );
    });
  });

  group('LlmConnectorHttpClient', () {
    test('buffers Cline streaming output for completed-response callers',
        () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            'data: {"id":"cline-completion","model":"provider/model","choices":[{"index":0,"delta":{"content":"answer"},"finish_reason":null}]}\n\n'
            'data: {"id":"cline-completion","model":"provider/model","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
            'data: [DONE]\n\n',
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
        _account('cline-buffer', 'cline', authType: 'oauth'),
        secret: jsonEncode({'access_token': 'cline-private-token'}),
      );

      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'provider/model',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
          'stream': false,
        },
      );

      expect(
        captured?.uri.toString(),
        'https://api.cline.bot/api/v1/chat/completions',
      );
      expect(
        captured?.headers['Authorization'],
        'Bearer workos:cline-private-token',
      );
      expect(captured?.headers['Accept'], 'text/event-stream');
      expect(captured?.data['stream'], isTrue);
      expect(response.body, isA<Map>());
      expect(
        (response.body as Map)['choices'].first['message']['content'],
        'answer',
      );
      expect(response.toString(), isNot(contains('cline-private-token')));
    });

    test(
      'buffers CodeBuddy SSE when the caller requests a completed response',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              'data: {"id":"completion-1","model":"glm-5.2","choices":[{"index":0,"delta":{"content":"answer"},"finish_reason":null}]}\n\n'
              'data: {"id":"completion-1","model":"glm-5.2","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
              'data: {"id":"completion-1","model":"glm-5.2","choices":[],"usage":{"prompt_tokens":7,"completion_tokens":5,"total_tokens":12}}\n\n'
              'data: [DONE]\n\n',
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
          _account('codebuddy-buffer', 'codebuddy-cn'),
          secret: 'codebuddy-api-key',
        );

        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'glm-5.2',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
            'stream': false,
          },
        );

        expect(captured?.data['stream'], isTrue);
        expect(response.body, isA<Map>());
        expect(
          (response.body as Map)['choices'].first['message']['content'],
          'answer',
        );
        expect(response.observation.requestUsage.value, 12);
      },
    );

    test(
      'does not turn a CodeBuddy SSE error frame into an empty success',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromString(
              'data: {"error":{"message":"account is unavailable"}}\n\n',
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
          _account('codebuddy-error-buffer', 'codebuddy-cn'),
          secret: 'codebuddy-api-key',
        );

        await expectLater(
          LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
            account: account,
            modelId: 'glm-5.2',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'hello'},
              ],
              'stream': false,
            },
          ),
          throwsA(isA<LlmConnectorHttpException>()),
        );
      },
    );

    test(
      'refreshes expired Tencent OAuth tokens before chat dispatch',
      () async {
        for (final (connector, host) in [
          ('codebuddy-cn', 'copilot.tencent.com'),
          ('codebuddy-intl', 'www.codebuddy.ai'),
          ('workbuddy', 'www.workbuddy.ai'),
        ]) {
          RequestOptions? refreshRequest;
          RequestOptions? chatRequest;
          var refreshCount = 0;
          final refreshDio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              refreshCount++;
              refreshRequest = options;
              return ResponseBody.fromString(
                jsonEncode({
                  'code': 0,
                  'data': {
                    'accessToken': 'fresh-$connector-token',
                    'refreshToken': 'rotated-$connector-token',
                    'expiresIn': 1800,
                  },
                }),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });
          final credentials = _MemoryCredentials();
          final accounts = LlmAccountConnectorService(
            preferences: _MemoryPreferences(),
            credentialStore: credentials,
            dio: refreshDio,
          );
          final account = await accounts.saveAccount(
            _account('oauth-$connector', connector, authType: 'oauth'),
            secret: jsonEncode({
              'access_token': 'expired-$connector-token',
              'refresh_token': 'refresh-$connector-token',
              'expires_in': 1,
              'expires_at': DateTime.utc(2020).toIso8601String(),
            }),
          );
          final chatDio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              chatRequest = options;
              return ResponseBody.fromString(
                '{"choices":[{"message":{"role":"assistant","content":"ok"}}]}',
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });

          await LlmConnectorHttpClient(
            accountService: accounts,
            dio: chatDio,
          ).request(
            account: account,
            modelId: 'glm-5.2',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'hello'},
              ],
            },
          );

          expect(
            refreshRequest?.uri.toString(),
            'https://$host/v2/plugin/auth/token/refresh',
          );
          expect(
            refreshRequest?.headers['X-Refresh-Token'],
            'refresh-$connector-token',
          );
          expect(
            chatRequest?.headers['Authorization'],
            'Bearer fresh-$connector-token',
          );
          final updated =
              jsonDecode(credentials.values[account.credentialRef]!) as Map;
          expect(updated['refresh_token'], 'rotated-$connector-token');
          expect(updated['expires_in'], 1800);
          expect(updated.containsKey('expiresIn'), isFalse);
          expect(
            DateTime.parse(
              updated['expires_at'] as String,
            ).isAfter(DateTime.now().toUtc()),
            isTrue,
          );
          await LlmConnectorHttpClient(
            accountService: accounts,
            dio: chatDio,
          ).request(
            account: account,
            modelId: 'glm-5.2',
            body: const {
              'messages': [
                {'role': 'user', 'content': 'followup'},
              ],
            },
          );
          expect(refreshCount, 1);
          expect(
            chatRequest?.headers['Authorization'],
            'Bearer fresh-$connector-token',
          );
        }
      },
    );

    test(
      'adapts Devin unary Connect-RPC to the Chat stream contract',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromBytes(
              [0, 0, 0, 0, 4, 26, 2, 111, 107, 2, 0, 0, 0, 2, 123, 125],
              200,
              headers: const {
                'content-type': ['application/connect+proto'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          LlmAccount(
            id: 'devin-http-oauth',
            connectorType: 'devin',
            authType: 'oauth',
            displayName: 'Devin',
            models: const [
              LlmUpstreamModel(
                id: 'devin-model',
                upstreamModelId: 'devin/swe-2',
                displayName: 'SWE-2',
              ),
            ],
          ),
          secret: jsonEncode({
            'session_token': r'devin-session-token$fixture',
            'oauth_contract': 'devin-pkce-v1',
            'auth_kind': 'oauth',
            'user_id': 'devin-user',
            'plan': 'Team',
          }),
        );

        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'devin/swe-2',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
          stream: true,
        );
        final sse = utf8.decode(
          (await (response.body as Stream<List<int>>).toList())
              .expand((part) => part)
              .toList(),
        );

        expect(captured?.uri.host, 'server.codeium.com');
        expect(
          captured?.uri.path,
          '/exa.api_server_pb.ApiServerService/GetChatMessage',
        );
        expect(captured?.headers['Connect-Protocol-Version'], '1');
        expect(captured?.headers['Content-Type'], 'application/connect+proto');
        expect(sse, contains('"content":"ok"'));
        expect(sse, contains('data: [DONE]'));
      },
    );

    test(
      'executes both xAI OAuth modes on their own host and auth route',
      () async {
        for (final connectorType in ['grok-cli', 'xai-oauth']) {
          RequestOptions? captured;
          final dio = Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              captured = options;
              return ResponseBody.fromString(
                jsonEncode({'output_text': 'reply'}),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            });
          final credentials = _MemoryCredentials();
          final accounts = LlmAccountConnectorService(
            preferences: _MemoryPreferences(),
            credentialStore: credentials,
          );
          final account = await accounts.saveAccount(
            _account(
              'http-$connectorType',
              connectorType,
              authType: 'oauth',
              models: [_upstreamModel('grok-4.7')],
            ),
            secret: jsonEncode({'access_token': '$connectorType-access'}),
          );
          final client = LlmConnectorHttpClient(
            accountService: accounts,
            dio: dio,
          );

          await client.request(
            account: account,
            modelId: 'grok-4.7',
            body: const {'model': 'fixture-model', 'input': []},
            nativeFormat: 'responses',
          );

          final expectedHost = connectorType == 'grok-cli'
              ? 'cli-chat-proxy.grok.com'
              : 'api.x.ai';
          expect(captured?.uri.host, expectedHost);
          expect(captured?.uri.path, '/v1/responses');
          expect(
            captured?.headers['Authorization'],
            'Bearer $connectorType-access',
          );
          expect(
            captured?.headers.containsKey('X-XAI-Token-Auth'),
            connectorType == 'grok-cli',
          );
        }
      },
    );

    test('sends and decodes public xAI and Meta Responses requests', () async {
      for (final connectorType in ['xai', 'meta']) {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            if ((options.data as Map)['stream'] == true) {
              return ResponseBody.fromString(
                'data: {"type":"response.output_text.delta","delta":"stream reply"}\n\n'
                'data: {"type":"response.completed","response":{"usage":{"input_tokens":7,"output_tokens":5,"total_tokens":12}}}\n\n',
                200,
                headers: const {
                  'content-type': ['text/event-stream'],
                },
              );
            }
            return ResponseBody.fromString(
              jsonEncode({
                'output_text': 'nonstream reply',
                'usage': {
                  'input_tokens': 3,
                  'output_tokens': 2,
                  'total_tokens': 5,
                },
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          });
        final credentials = _MemoryCredentials();
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: credentials,
        );
        final account = await accounts.saveAccount(
          _account('http-$connectorType', connectorType),
          secret: '$connectorType-http-key',
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );
        final nonStreaming = await client.request(
          account: account,
          modelId: '$connectorType-upstream',
          body: {'model': '$connectorType-upstream', 'input': []},
          nativeFormat: 'responses',
        );

        final expectedBase = connectorType == 'xai'
            ? 'https://api.x.ai/v1'
            : 'https://api.meta.ai/v1';
        expect(captured?.uri, Uri.parse('$expectedBase/responses'));
        expect(
          captured?.headers['Authorization'],
          'Bearer $connectorType-http-key',
        );
        expect((captured?.data as Map)['model'], '$connectorType-upstream');
        expect((nonStreaming.body as Map)['output_text'], 'nonstream reply');
        expect(nonStreaming.observation.requestUsage.value, 5);

        final streaming = await client.request(
          account: account,
          modelId: '$connectorType-upstream',
          body: {'model': '$connectorType-upstream', 'input': []},
          stream: true,
          nativeFormat: 'responses',
        );
        expect(captured?.uri, Uri.parse('$expectedBase/responses'));
        expect(
          captured?.headers['Authorization'],
          'Bearer $connectorType-http-key',
        );
        expect((captured?.data as Map)['stream'], isTrue);
        final delivered = await (streaming.body as Stream<List<int>>).toList();
        final observation = await streaming.completedObservation;
        expect(
          utf8.decode(delivered.expand((chunk) => chunk).toList()),
          contains('stream reply'),
        );
        expect(observation?.requestUsage.value, 12);
      }
    });

    test('preserves AWS credential resolution error classification', () async {
      var requestsSent = 0;
      final credentials = _MemoryCredentials();
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: credentials,
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'bedrock-missing-credentials',
          connectorType: 'bedrock',
          authType: 'aws_credentials',
          displayName: 'Bedrock',
          endpointConfig: const {'region': 'us-east-1'},
        ),
        secret: jsonEncode({
          'accessKeyId': 'AKIDEXAMPLE',
          'secretAccessKey': 'private-aws-secret',
        }),
      );
      credentials.values[account.credentialRef!] = 'invalid-json';
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requestsSent++;
          return ResponseBody.fromString('{}', 200);
        });

      await expectLater(
        LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'anthropic.claude-3-5-sonnet-20241022-v2:0',
          body: const {'messages': []},
        ),
        throwsA(
          isA<LlmConnectorHttpException>().having(
            (error) => error.code,
            'code',
            'aws_credentials_unavailable',
          ),
        ),
      );
      expect(requestsSent, 0);
    });

    test(
      'signs Bedrock Converse requests and adapts streamed chat output',
      () async {
        RequestOptions? captured;
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromBytes(
              _bedrockTestStream(),
              200,
              headers: const {
                'content-type': ['application/vnd.amazon.eventstream'],
              },
            );
          });
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: credentials,
          dio: dio,
        );
        final account = await accounts.saveAccount(
          LlmAccount(
            id: 'bedrock-chat',
            connectorType: 'bedrock',
            authType: 'aws_credentials',
            displayName: 'Bedrock',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: jsonEncode({
            'accessKeyId': 'AKIDEXAMPLE',
            'secretAccessKey': 'private-aws-secret',
            'sessionToken': 'private-session-token',
          }),
        );

        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'anthropic.claude-3-5-sonnet-20241022-v2:0',
          stream: true,
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Say hello.'},
            ],
            'max_tokens': 100,
          },
        );

        final preferencesJson = preferences.values.values.join();
        expect(captured?.uri.host, 'bedrock-runtime.us-east-1.amazonaws.com');
        expect(captured?.uri.path, endsWith('/converse-stream'));
        expect(
          captured?.headers['Accept'],
          'application/vnd.amazon.eventstream',
        );
        expect(
          captured?.headers['x-amz-security-token'],
          'private-session-token',
        );
        expect(
          captured?.headers['Authorization'],
          startsWith('AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/'),
        );
        expect(captured?.data, isA<Map>());
        expect(response.body, isA<Stream<List<int>>>());
        final chunks = await (response.body as Stream<List<int>>).toList();
        final text = utf8.decode(chunks.expand((chunk) => chunk).toList());
        expect(text, contains('Bedrock answer'));
        expect(text, contains('data: [DONE]'));
        expect(preferencesJson, isNot(contains('private-aws-secret')));
        expect(preferencesJson, isNot(contains('private-session-token')));
      },
    );

    test(
      'sends Bedrock API keys only to the regional Converse endpoint',
      () async {
        RequestOptions? captured;
        final preferences = _MemoryPreferences();
        final credentials = _MemoryCredentials();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'output': {
                  'message': {
                    'role': 'assistant',
                    'content': [
                      {'text': 'Bedrock API-key answer'},
                    ],
                  },
                },
                'stopReason': 'end_turn',
              }),
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
          _account(
            'bedrock-api-key-chat',
            'bedrock',
            authType: 'api_key',
            endpointConfig: const {'region': 'us-east-1'},
          ),
          secret: 'bedrock-api-key-secret',
        );

        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'amazon.titan-text-express-v1',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Say hello.'},
            ],
          },
        );

        expect(captured?.uri.host, 'bedrock-runtime.us-east-1.amazonaws.com');
        expect(captured?.uri.path, endsWith('/converse'));
        expect(
          captured?.headers['Authorization'],
          'Bearer bedrock-api-key-secret',
        );
        expect(captured?.headers['x-amz-date'], isNull);
        expect((captured?.data as Map)['messages'], isA<List>());
        expect((response.body as Map)['choices'], isA<List>());
        expect(
          preferences.values.values.join(),
          isNot(contains('bedrock-api-key-secret')),
        );
      },
    );

    test(
      'adapts unary Bedrock output for streamed Chat when unsupported',
      () async {
        RequestOptions? captured;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'output': {
                  'message': {
                    'role': 'assistant',
                    'content': [
                      {'text': 'Unary Bedrock answer'},
                    ],
                  },
                },
                'stopReason': 'end_turn',
                'usage': {'inputTokens': 3, 'outputTokens': 4},
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
          LlmAccount(
            id: 'bedrock-api-key-unary',
            connectorType: 'bedrock',
            authType: 'api_key',
            displayName: 'Bedrock API key',
            endpointConfig: const {'region': 'us-east-1'},
            models: const [
              LlmUpstreamModel(
                id: 'titan-text',
                upstreamModelId: 'amazon.titan-text-express-v1',
                displayName: 'Titan Text Express',
                capabilities: {'streaming': false},
              ),
            ],
          ),
          secret: 'bedrock-api-key-secret',
        );

        final response = await LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        ).request(
          account: account,
          modelId: 'amazon.titan-text-express-v1',
          stream: true,
          body: const {
            'messages': [
              {'role': 'user', 'content': 'Say hello.'},
            ],
          },
        );
        final chunks = await (response.body as Stream<List<int>>).toList();
        final text = utf8.decode(chunks.expand((chunk) => chunk).toList());

        expect(captured?.uri.path, endsWith('/converse'));
        expect(captured?.headers['Accept'], 'application/json');
        expect(text, contains('Unary Bedrock answer'));
        expect(text, contains('data: [DONE]'));
      },
    );

    test(
      'does not discover a private Antigravity project for CLI OAuth',
      () async {
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
            fail('Antigravity CLI OAuth must not reach private inference APIs');
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

        await expectLater(
          LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
            account: account,
            modelId: 'gemini-3.1-pro',
            body: const {
              'request': {'contents': []},
            },
          ),
          throwsA(isA<LlmConnectorAuthenticationRequired>()),
        );

        expect(projectLookups, 0);
        final storedPreferences = preferences.values.values.join();
        expect(storedPreferences, isNot(contains('antigravity-token')));
      },
    );

    test(
      'does not route OAuth providers without public inference contracts',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString('{}', 200);
          });
        final accountService = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accountService.saveAccount(
          _account('kimi-cli-oauth', 'kimi', authType: 'oauth'),
          secret: jsonEncode({'access_token': 'kimi-session-token'}),
        );

        await expectLater(
          LlmConnectorHttpClient(
            accountService: accountService,
            dio: dio,
          ).request(
            account: account,
            modelId: 'kimi-k2',
            body: const {'messages': []},
          ),
          throwsA(isA<LlmConnectorAuthenticationRequired>()),
        );
        expect(requestsSent, 0);
      },
    );

    test(
      'does not send Antigravity CLI OAuth to private inference endpoints',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
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

        await expectLater(
          LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
            account: account,
            modelId: 'gemini-3.1-pro',
            body: const {
              'request': {'contents': []},
            },
          ),
          throwsA(isA<LlmConnectorAuthenticationRequired>()),
        );
        expect(requestsSent, 0);
      },
    );

    test('cancellation skips Antigravity project discovery', () async {
      var projectLookups = 0;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          if (options.uri.path.endsWith(':loadCodeAssist')) projectLookups++;
          return ResponseBody.fromString(
            jsonEncode({
              'cloudaicompanionProject': {'id': 'resolved-project'},
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
        _account(
          'antigravity-project-cancelled',
          'antigravity',
          authType: 'oauth',
        ),
        secret: jsonEncode({'access_token': 'antigravity-token'}),
      );
      final cancelToken = CancelToken()..cancel('caller cancelled');

      await expectLater(
        LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {
            'request': {'contents': []},
          },
          cancelToken: cancelToken,
        ),
        throwsA(isA<LlmConnectorRequestCancelled>()),
      );

      expect(projectLookups, 0);
      expect(
        (await accounts.getAccount(account.id))?.endpointConfig['projectId'],
        isNull,
      );
    });

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
        throwsA(isA<LlmConnectorAuthenticationRequired>()),
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
          jsonEncode({
            'access_token': 'codex-token',
            'client_id': 'registered-openai-client',
          }),
          'https://api.openai.com/v1/responses',
          const {'model': 'gpt-5.5', 'input': []},
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
          _account(
            'native-muse-code',
            'muse-code',
            authType: 'oauth',
            models: [
              const LlmUpstreamModel(
                id: 'muse-model',
                upstreamModelId: 'muse-spark-1.3',
                displayName: 'Muse Spark',
              ),
            ],
          ),
          jsonEncode({
            'access_token': 'muse-minted-key',
            'api_key': 'muse-minted-key',
            'dca_token': 'dca:muse-device-token',
            'email': 'muse@example.test',
          }),
          'https://api.meta.ai/v1/responses',
          const {'model': 'muse-spark-1.3', 'input': []},
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
        for (final provider in [
          ('openai-api', 'https://api.openai.com/v1/chat/completions'),
          ('moonshot', 'https://api.moonshot.ai/v1/chat/completions'),
          ('glm', 'https://open.bigmodel.cn/api/paas/v4/chat/completions'),
          ('deepseek', 'https://api.deepseek.com/chat/completions'),
          ('minimax', 'https://api.minimax.io/v1/chat/completions'),
          ('opencode-go', 'https://opencode.ai/zen/go/v1/chat/completions'),
          ('opencode-zen', 'https://opencode.ai/zen/v1/chat/completions'),
          (
            'qwen',
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          ),
          (
            'qoder',
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          ),
        ])
          (
            _account('native-${provider.$1}', provider.$1),
            '${provider.$1}-test-key',
            provider.$2,
            const {
              'model': 'provider-chat-model',
              'messages': [
                {'role': 'user', 'content': 'hello'},
              ],
            },
          ),
        (
          LlmAccount(
            id: 'native-qoder-oauth',
            connectorType: 'qoder',
            authType: 'oauth',
            displayName: 'Qoder OAuth',
            endpointConfig: const {
              'qoderLoginUrl': 'https://login.example.test/authorize',
              'qoderExchangeUrl': 'https://login.example.test/token',
              'qoderUserInfoUrl': 'https://login.example.test/user',
              'qoderClientId': 'qoder-client',
            },
          ),
          jsonEncode({
            'access_token': 'qoder-oauth-token',
            'refresh_token': 'qoder-refresh-token',
            'api_key': 'qoder-oauth-api-key',
            'client_id': 'qoder-client',
            'client_secret': 'qoder-client-secret',
            'authorize_url': 'https://login.example.test/authorize',
            'token_url': 'https://login.example.test/token',
            'user_info_url': 'https://login.example.test/user',
            'oauth_contract': 'qoder-admin-code-v1',
          }),
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          const {
            'model': 'provider-chat-model',
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        ),
        (
          _account('native-claude-api-key', 'claude'),
          'anthropic-api-test-key',
          'https://api.anthropic.com/v1/messages',
          const {'model': 'claude-sonnet-4-6', 'messages': []},
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
        (
          _account(
            'native-openference-oauth',
            'openference',
            authType: 'oauth',
          ),
          jsonEncode({'access_token': 'openference-oauth-token'}),
          'https://api.openference.com/v1/chat/completions',
          const {'model': 'Qwen3.8 27b', 'messages': []},
        ),
        (
          _account('native-openference-api', 'openference-api'),
          'openference-api-key',
          'https://api.openference.com/v1/chat/completions',
          const {'model': 'Llama 3.2 3B', 'messages': []},
        ),
      ];

      for (final (account, secret, expectedUri, body) in scenarios) {
        final saved = await accounts.saveAccount(account, secret: secret);
        final modelId = switch (account.connectorType) {
          'gemini' || 'gemini-interactions' || 'vertex' => 'gemini-3.1-pro',
          'muse-code' => 'muse-spark-1.3',
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
      final openferenceOAuthRequest = requests.singleWhere(
        (request) =>
            request.uri.host == 'api.openference.com' &&
            request.headers['Authorization'] ==
                'Bearer openference-oauth-token',
      );
      expect(openferenceOAuthRequest.uri.path, '/v1/chat/completions');
      expect(
        requests
            .singleWhere(
              (request) =>
                  request.headers['Authorization'] ==
                  'Bearer openference-api-key',
            )
            .uri
            .path,
        '/v1/chat/completions',
      );
      final qoderRequest = requests.singleWhere(
        (request) =>
            request.headers['Authorization'] == 'Bearer qoder-test-key',
      );
      expect(qoderRequest.headers['Authorization'], 'Bearer qoder-test-key');
      expect(qoderRequest.headers['x-dashscope-authtype'], 'qwen-oauth');
      expect(qoderRequest.headers['x-dashscope-cachecontrol'], 'enable');
      expect(qoderRequest.headers['User-Agent'], contains('QwenCode/0.19.3'));
      expect(qoderRequest.headers['x-stainless-lang'], 'js');
      expect(qoderRequest.headers['x-stainless-arch'], isNot('unknown'));
      final qoderOAuthRequest = requests.singleWhere(
        (request) =>
            request.headers['Authorization'] == 'Bearer qoder-oauth-api-key',
      );
      expect(qoderOAuthRequest.headers['x-dashscope-authtype'], 'qwen-oauth');
      expect(
        qoderOAuthRequest.headers['Authorization'],
        isNot('Bearer qoder-oauth-token'),
      );
      for (final provider in ['opencode-go', 'opencode-zen']) {
        final request = requests.singleWhere(
          (request) =>
              request.uri.host == 'opencode.ai' &&
              request.uri.path.startsWith(
                provider == 'opencode-go' ? '/zen/go/' : '/zen/v1/',
              ) &&
              request.uri.path.endsWith('/chat/completions'),
        );
        expect(request.headers['Authorization'], 'Bearer $provider-test-key');
      }
      final museRequest = requests.firstWhere(
        (request) =>
            request.uri.host == 'api.meta.ai' &&
            (request.data as Map)['model'] == 'muse-spark-1.3',
      );
      expect(museRequest.headers['Authorization'], 'Bearer muse-minted-key');
      expect(museRequest.headers['X-Client-Id'], 'tbh:tui');
      expect(museRequest.headers['User-Agent'], contains('muse-build/1.3.0'));
    });

    test(
      'Qoder API-key and OAuth streaming set the body stream option',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            return ResponseBody.fromString(
              'data: {"choices":[{"index":0,"delta":{"content":"reply"},"finish_reason":null}]}\n\n'
              'data: [DONE]\n\n',
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
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );
        final qoderOAuthSecret = jsonEncode({
          'access_token': 'qoder-access-token',
          'api_key': 'qoder-oauth-api-key',
          'client_id': 'qoder-client',
          'client_secret': 'qoder-secret',
          'authorize_url': 'https://login.example.test/authorize',
          'token_url': 'https://login.example.test/token',
          'user_info_url': 'https://login.example.test/user',
          'oauth_contract': 'qoder-admin-code-v1',
        });
        final scenarios = [
          (
            _account('qoder-stream-api-key', 'qoder'),
            'qoder-api-key',
            'Bearer qoder-api-key',
          ),
          (
            LlmAccount(
              id: 'qoder-stream-oauth',
              connectorType: 'qoder',
              authType: 'oauth',
              displayName: 'Qoder OAuth',
              endpointConfig: const {
                'qoderLoginUrl': 'https://login.example.test/authorize',
                'qoderExchangeUrl': 'https://login.example.test/token',
                'qoderUserInfoUrl': 'https://login.example.test/user',
                'qoderClientId': 'qoder-client',
              },
            ),
            qoderOAuthSecret,
            'Bearer qoder-oauth-api-key',
          ),
        ];

        for (final (account, secret, authorization) in scenarios) {
          final saved = await accounts.saveAccount(account, secret: secret);
          final response = await client.request(
            account: saved,
            modelId: 'qwen3.8-max-preview',
            body: const {
              'model': 'qwen3.8-max-preview',
              'messages': [
                {'role': 'user', 'content': 'hello'},
              ],
            },
            stream: true,
          );

          expect(requests.last.headers['Authorization'], authorization);
          expect(
            requests.last.headers['accept'],
            contains('text/event-stream'),
          );
          expect((requests.last.data as Map)['stream'], isTrue);
          await (response.body as Stream<List<int>>).drain<void>();
        }
      },
    );

    test(
      'expired Qoder OAuth requires reauthorization before routing',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
        );
        final account = await accounts.saveAccount(
          LlmAccount(
            id: 'qoder-expired-oauth',
            connectorType: 'qoder',
            authType: 'oauth',
            displayName: 'Expired Qoder OAuth',
            status: LlmAccountStatus.ready,
            endpointConfig: const {
              'qoderLoginUrl': 'https://login.example.test/authorize',
              'qoderExchangeUrl': 'https://login.example.test/token',
              'qoderUserInfoUrl': 'https://login.example.test/user',
              'qoderClientId': 'qoder-client',
            },
          ),
          secret: jsonEncode({
            'access_token': 'expired-qoder-access-token',
            'api_key': 'expired-qoder-api-key',
            'client_id': 'qoder-client',
            'client_secret': 'qoder-secret',
            'authorize_url': 'https://login.example.test/authorize',
            'token_url': 'https://login.example.test/token',
            'user_info_url': 'https://login.example.test/user',
            'oauth_contract': 'qoder-admin-code-v1',
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 2))
                .toIso8601String(),
          }),
        );

        final listedAccount = (await accounts.listAccounts()).single;
        expect(listedAccount.status, LlmAccountStatus.needsAttention);
        await expectLater(
          LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
            account: account,
            modelId: 'qwen3.8-max-preview',
            body: const {
              'model': 'qwen3.8-max-preview',
              'messages': [
                {'role': 'user', 'content': 'hello'},
              ],
            },
          ),
          throwsA(isA<LlmConnectorAuthenticationRequired>()),
        );
        expect(requestsSent, 0);
      },
    );

    test(
      'does not allow legacy Meta API-key accounts to use OAuth credentials',
      () async {
        var requestsSent = 0;
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requestsSent++;
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        await expectLater(
          accounts.saveAccount(
            _account('meta-request', 'meta', authType: 'oauth'),
            secret: jsonEncode({'dca_token': 'dca:request-token'}),
          ),
          throwsA(isA<LlmAccountConnectorException>()),
        );
        expect(requestsSent, 0);
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
          secret: jsonEncode(kVertexTestServiceAccount),
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
        expect(claims['iss'], kVertexTestServiceAccount['client_email']);
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
          isNot(contains(kVertexTestServiceAccount['private_key'] as String)),
        );
        expect(
          await accounts.readCredential(account.id),
          contains('vertex-access-token'),
        );
      },
    );

    test(
      'executes Vertex API-key requests in unary and streaming modes',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            requests.add(options);
            if (options.uri.path.contains('streamGenerateContent')) {
              return ResponseBody(
                Stream.value(
                  Uint8List.fromList(
                    utf8.encode(
                      'data: {"candidates":[{"content":{"parts":[{"text":"streamed"}]}}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":2}}\n\n',
                    ),
                  ),
                ),
                200,
                headers: const {
                  'content-type': ['text/event-stream'],
                },
              );
            }
            return ResponseBody.fromString(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'unary'},
                      ],
                    },
                  },
                ],
                'usageMetadata': {
                  'promptTokenCount': 5,
                  'candidatesTokenCount': 3,
                  'totalTokenCount': 8,
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
          LlmAccount(
            id: 'vertex-api-key-modes',
            connectorType: 'vertex',
            authType: 'api_key',
            displayName: 'Vertex API key',
            endpointConfig: const {
              'projectId': 'vertex-project',
              'location': 'us-central1',
            },
          ),
          secret: 'vertex-api-key',
        );
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: dio,
        );

        final unary = await client.request(
          account: account,
          modelId: 'gemini-2.5-flash',
          body: const {'contents': []},
        );
        final streamed = await client.request(
          account: account,
          modelId: 'gemini-2.5-flash',
          body: const {'contents': []},
          stream: true,
        );

        expect(
          (unary.body as Map)['candidates']
              .single['content']['parts']
              .single['text'],
          'unary',
        );
        expect(unary.observation.requestUsage.value, 8);
        final streamBytes =
            (await (streamed.body as Stream<List<int>>).toList())
                .expand((chunk) => chunk)
                .toList();
        expect(utf8.decode(streamBytes), contains('"text":"streamed"'));
        expect((await streamed.completedObservation)?.requestUsage.value, 6);
        expect(requests, hasLength(2));
        expect(requests.first.uri.path, contains(':generateContent'));
        expect(requests.last.uri.path, contains(':streamGenerateContent'));
        expect(requests.last.uri.queryParameters['alt'], 'sse');
        expect(
          requests.every(
            (request) => request.headers['x-goog-api-key'] == 'vertex-api-key',
          ),
          isTrue,
        );
        expect(
          requests.every(
            (request) =>
                request.uri.host == 'us-central1-aiplatform.googleapis.com',
          ),
          isTrue,
        );
      },
    );

    test('executes AI Studio HTTP requests with the stored API key', () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({'candidates': []}),
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
        _account('aistudio-http', 'aistudio'),
        secret: 'aistudio-test-api-key',
      );
      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(
        captured?.uri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
      );
      expect(captured?.headers['x-goog-api-key'], 'aistudio-test-api-key');
      expect(captured?.headers['Authorization'], isNull);
      expect(response.body, {'candidates': []});
    });

    test('executes AI Studio OAuth requests with project attribution',
        () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            jsonEncode({'candidates': []}),
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
        LlmAccount(
          id: 'aistudio-http-oauth',
          connectorType: 'aistudio',
          authType: 'oauth',
          displayName: 'Google AI Studio',
          endpointConfig: const {'googleCloudProjectId': 'stroom-project'},
        ),
        secret: jsonEncode({
          'access_token': 'aistudio-test-oauth-token',
          'refresh_token': 'aistudio-test-refresh-token',
          'client_id': 'configured-client.apps.googleusercontent.com',
          'client_secret': 'aistudio-test-client-secret',
        }),
      );
      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(
        captured?.uri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
      );
      expect(
        captured?.headers['Authorization'],
        'Bearer aistudio-test-oauth-token',
      );
      expect(captured?.headers['x-goog-user-project'], 'stroom-project');
      expect(captured?.uri.queryParameters, isEmpty);
      expect(response.body, {'candidates': []});
    });

    test(
      'blocks stored legacy AI Studio relay accounts before network use',
      () async {
        var requestsSent = 0;
        final preferences = _MemoryPreferences()
          ..values[LlmAccountMigrationService.accountsPreferenceKey] =
              jsonEncode({
            'version': 1,
            'items': [
              {
                'id': 'legacy-aistudio-relay',
                'connectorType': 'aistudio',
                'authType': 'relay',
                'displayName': 'Legacy AI Studio session',
              },
            ],
          });
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentials(),
        );
        final account = (await accounts.listAccounts()).single;
        final client = LlmConnectorHttpClient(
          accountService: accounts,
          dio: Dio()
            ..httpClientAdapter = _FunctionalAdapter((options) async {
              requestsSent++;
              return ResponseBody.fromString('{}', 200);
            }),
        );

        await expectLater(
          client.request(
            account: account,
            modelId: 'gemini-3.1-pro',
            body: const {'contents': []},
          ),
          throwsA(isA<LlmConnectorAuthenticationRequired>()),
        );
        expect(requestsSent, 0);
      },
    );

    test('streams AI Studio SSE chunks and redacts upstream errors', () async {
      final source = StreamController<Uint8List>();
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          expect(options.uri.queryParameters['alt'], 'sse');
          expect(options.headers['x-goog-api-key'], 'aistudio-test-key');
          return ResponseBody(source.stream, 200);
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account('aistudio-stream', 'aistudio'),
        secret: 'aistudio-test-key',
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
      final event = utf8.encode('data: {"candidates":[]}\n\n');
      source.add(Uint8List.fromList(event));
      await source.close();
      expect(
        utf8.decode(
          (await (response.body as Stream<List<int>>).toList()).single,
        ),
        'data: {"candidates":[]}\n\n',
      );

      final errorDio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'RESOURCE_EXHAUSTED',
                'message': 'aistudio-test-key rejected',
              },
            }),
            429,
            headers: const {
              'retry-after': ['3'],
              'x-secret-diagnostic': ['must-not-be-forwarded'],
            },
          );
        });
      try {
        await LlmConnectorHttpClient(
          accountService: accounts,
          dio: errorDio,
        ).request(
          account: account,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
        );
        fail('Expected the upstream status error.');
      } on LlmConnectorHttpException catch (error) {
        expect(error.statusCode, 429);
        expect(error.code, 'RESOURCE_EXHAUSTED');
        expect(error.headers, {'retry-after': '3'});
        expect(error.toString(), isNot(contains('aistudio-test-key')));
        expect(error.toString(), isNot(contains('rejected')));
        expect(error.toString(), isNot(contains('must-not-be-forwarded')));
      }
    });

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
        secret: jsonEncode({
          'access_token': 'private-access-token',
          'client_id': 'registered-openai-client',
          'account_id': 'codex-http-account',
        }),
      );
      final client = LlmConnectorHttpClient(accountService: accounts, dio: dio);

      final response = await client.request(
        account: account,
        modelId: 'gpt-5.5',
        body: const {'model': 'gpt-5.5', 'input': []},
      );

      expect(captured?.uri.toString(), 'https://api.openai.com/v1/responses');
      expect(captured?.headers['Authorization'], 'Bearer private-access-token');
      expect(captured?.headers['Chatgpt-Account-Id'], 'codex-http-account');
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

    test('routes Claude Code OAuth through the Messages API', () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          captured = options;
          return ResponseBody.fromString('{}', 200);
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account('claude-stream-usage', 'claude', authType: 'oauth'),
        secret: jsonEncode({'access_token': 'claude-stream-token'}),
      );

      await LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
        account: account,
        modelId: 'claude-sonnet-4-6',
        body: const {'model': 'claude-sonnet-4-6', 'messages': []},
        stream: true,
      );
      expect(captured?.uri.path, '/v1/messages');
      expect(captured?.uri.queryParameters['beta'], 'true');
      expect(captured?.headers['Authorization'], 'Bearer claude-stream-token');
      expect(
        captured?.headers['anthropic-beta'],
        contains('claude-code-20250219'),
      );
    });

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
          secret: jsonEncode({
            'refresh_token': 'private-refresh-token',
            'client_id': 'registered-openai-client',
          }),
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
      'refreshes an expired OAuth credential after a truncated 401 body',
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
              final source = StreamController<Uint8List>(
                onCancel: () {
                  final token = options.cancelToken;
                  if (token?.isCancelled == true) {
                    throw token!.cancelError!;
                  }
                },
              );
              scheduleMicrotask(() {
                source.add(
                  Uint8List.fromList(
                    utf8.encode(
                      jsonEncode({
                        'error': 'auth rejected private-token-fragment',
                        'details': List.filled(40000, 'x').join(),
                      }),
                    ),
                  ),
                );
              });
              return ResponseBody(
                source.stream,
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
            'client_id': 'registered-openai-client',
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

    test(
      'cancels an in-flight OAuth refresh without persisting new tokens',
      () async {
        final refreshStarted = Completer<void>();
        final finishRefresh = Completer<void>();
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            if (options.uri.host == 'auth.openai.com') {
              refreshStarted.complete();
              await finishRefresh.future;
              return ResponseBody.fromString(
                jsonEncode({'access_token': 'rotated-access-token'}),
                200,
                headers: const {
                  'content-type': ['application/json'],
                },
              );
            }
            return ResponseBody.fromString('{}', 200);
          });
        final accounts = LlmAccountConnectorService(
          preferences: _MemoryPreferences(),
          credentialStore: _MemoryCredentials(),
          dio: dio,
        );
        final account = await accounts.saveAccount(
          _account('codex-refresh-cancel', 'codex', authType: 'oauth'),
          secret: jsonEncode({
            'access_token': 'expired-access-token',
            'refresh_token': 'old-refresh-token',
            'client_id': 'registered-openai-client',
            'expires_at': DateTime.utc(2000).toIso8601String(),
          }),
        );
        final cancelToken = CancelToken();
        final request =
            LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'gpt-5.5',
          body: const {'model': 'gpt-5.5', 'input': []},
          cancelToken: cancelToken,
        );

        await refreshStarted.future;
        cancelToken.cancel('caller cancelled');
        finishRefresh.complete();

        await expectLater(
          request,
          throwsA(isA<LlmConnectorRequestCancelled>()),
        );
        final storedCredential = jsonDecode(
          (await accounts.readCredential(account.id))!,
        );
        expect(storedCredential['access_token'], 'expired-access-token');
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

    test(
      'cancels unread error response streams before reporting failure',
      () async {
        var responseStreamCancelled = false;
        final source = StreamController<Uint8List>(
          onCancel: () => responseStreamCancelled = true,
        );
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter(
            (options) async => ResponseBody(
              source.stream,
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
            id: 'compat-stream-error',
            connectorType: 'openai-compatibility',
            authType: 'api_key',
            displayName: 'Private endpoint',
            endpointConfig: const {'baseUrl': 'https://llm.example.test/v1'},
          ),
          secret: 'custom-private-api-key',
        );
        final request =
            LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
          account: account,
          modelId: 'private-model',
          body: const {'model': 'private-model', 'messages': []},
          stream: true,
        );

        try {
          await expectLater(
            request.timeout(const Duration(milliseconds: 100)),
            throwsA(isA<LlmConnectorHttpException>()),
          );
          await Future<void>.delayed(Duration.zero);
          expect(responseStreamCancelled, isTrue);
        } finally {
          await source.close();
        }
      },
    );
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

    test('does not query private Antigravity quota endpoints', () async {
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

      expect(captured, isNull);
      expect(observation.remainingQuota.isKnown, isFalse);
    });

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

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);
        expect(quotaRequestSent, isFalse);
        expect(observation.remainingQuota.isKnown, isFalse);
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

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);
        expect(quotaRequestSent, isFalse);
        expect(observation.remainingQuota.isKnown, isFalse);
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

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);
        expect(quotaRequestSent, isFalse);
        expect(observation.remainingQuota.isKnown, isFalse);
      },
    );

    test('does not refresh Antigravity CLI OAuth for quota requests', () async {
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

      expect(quotaRequests, 0);
      expect(observation.remainingQuota.isKnown, isFalse);
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

    test(
      'ignores Devin reset timestamps outside the supported date range',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FunctionalAdapter((options) async {
            return ResponseBody.fromBytes(
              _devinQuotaResponse(
                daily: 91,
                weekly: 47,
                dailyReset: 8640000000001,
              ),
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
          _account('devin-invalid-reset', 'devin', authType: 'session_token'),
          secret: 'devin-session-token',
        );

        final observation = await LlmConnectorQuotaService(
          accountService: accounts,
          dio: dio,
        ).observeAccountQuota(account);

        expect(observation.quotaSignals['dailyRemainingPercent']?.value, 91);
        expect(
          observation.quotaSignals['dailyRemainingPercent']?.resetAt,
          isNull,
        );
        expect(observation.quotaSignals['weeklyRemainingPercent']?.value, 47);
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

  test('combines Claude Code message start and delta stream usage', () {
    final bytes = utf8.encode(
      'event: message_start\n'
      'data: {"type":"message_start","message":{"usage":{"input_tokens":5,"output_tokens":0}}}\n\n'
      'event: message_delta\n'
      'data: {"type":"message_delta","usage":{"output_tokens":4}}\n\n',
    );

    final observation = parseLlmConnectorSseObservation('claude', bytes);

    expect(observation.requestUsage.isKnown, isTrue);
    expect(observation.requestUsage.value, 9);
  });

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

Uint8List _bedrockTestStream() => Uint8List.fromList([
      ..._bedrockEvent('messageStart', {
        'messageStart': {'role': 'assistant'},
      }),
      ..._bedrockEvent('contentBlockDelta', {
        'contentBlockIndex': 0,
        'delta': {'text': 'Bedrock answer'},
      }),
      ..._bedrockEvent('messageStop', {
        'messageStop': {'stopReason': 'end_turn'},
      }),
      ..._bedrockEvent('metadata', {
        'metadata': {
          'usage': {'inputTokens': 7, 'outputTokens': 3},
        },
      }),
    ]);

Uint8List _bedrockEvent(String name, Map<String, dynamic> payload) {
  final encodedName = utf8.encode(':event-type');
  final encodedValue = utf8.encode(name);
  final header = <int>[
    encodedName.length,
    ...encodedName,
    7,
    encodedValue.length >> 8,
    encodedValue.length & 0xff,
    ...encodedValue,
  ];
  final body = utf8.encode(
    jsonEncode(payload.containsKey(name) ? payload[name] : payload),
  );
  final totalLength = 12 + header.length + body.length + 4;
  final prelude = Uint8List(8);
  ByteData.sublistView(prelude)
    ..setUint32(0, totalLength, Endian.big)
    ..setUint32(4, header.length, Endian.big);
  final crcPrelude = ByteData(4)
    ..setUint32(0, _bedrockCrc32(prelude), Endian.big);
  final withoutMessageCrc = Uint8List.fromList([
    ...prelude,
    ...crcPrelude.buffer.asUint8List(),
    ...header,
    ...body,
  ]);
  final crcMessage = ByteData(4)
    ..setUint32(0, _bedrockCrc32(withoutMessageCrc), Endian.big);
  return Uint8List.fromList([
    ...withoutMessageCrc,
    ...crcMessage.buffer.asUint8List(),
  ]);
}

int _bedrockCrc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Uint8List _devinQuotaResponse({
  required int daily,
  required int weekly,
  int? dailyReset,
  int? weeklyReset,
}) {
  final plan = <int>[];
  _appendTag(plan, 14, 0);
  _appendVarint(plan, daily);
  _appendTag(plan, 15, 0);
  _appendVarint(plan, weekly);
  if (dailyReset != null) {
    _appendTag(plan, 17, 0);
    _appendVarint(plan, dailyReset);
  }
  if (weeklyReset != null) {
    _appendTag(plan, 18, 0);
    _appendVarint(plan, weeklyReset);
  }
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

void _registerZedHostedHttpRetryTest() {
  test(
    'Zed Hosted refreshes an expired inference token exactly once',
    () async {
      var tokenRequests = 0;
      var completionRequests = 0;
      final receivedTokens = <String?>[];
      Map<String, dynamic>? sentEnvelope;
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          if (options.uri.path == '/client/llm_tokens') {
            tokenRequests++;
            return ResponseBody.fromString(
              jsonEncode({'token': 'inference-$tokenRequests'}),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }
          if (options.uri.path == '/completions') {
            completionRequests++;
            receivedTokens.add(options.headers['Authorization'] as String?);
            sentEnvelope =
                jsonDecode(options.data as String) as Map<String, dynamic>;
            if (completionRequests == 1) {
              return ResponseBody.fromString('{}', 401, headers: const {});
            }
            return ResponseBody.fromString(
              '{"event":{"type":"message_start"}}\n',
              200,
              headers: const {
                'content-type': ['application/x-ndjson'],
              },
            );
          }
          throw StateError('Unexpected Zed endpoint: ${options.uri}');
        });
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        _account(
          'zed-expiry-retry',
          'zed-hosted',
          authType: 'oauth',
          models: [
            LlmUpstreamModel(
              id: 'zed-hosted:claude-model',
              upstreamModelId: 'claude-model',
              displayName: 'Claude Model',
              capabilities: const {
                'supportedApiProtocols': ['anthropic.messages'],
                'streaming': true,
              },
              config: const {'upstreamProvider': 'anthropic'},
            ),
          ],
        ),
        secret: jsonEncode({
          'oauth_contract': 'zed-hosted-native-rsa-v1',
          'user_id': 'zed-user',
          'access_token': 'account-token',
          'system_id': 'system-id',
          'organization_id': 'org-1',
        }),
      );

      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: dio,
      ).request(
        account: account,
        modelId: 'claude-model',
        body: const {'messages': [], 'stream': true},
        nativeFormat: 'anthropic.messages',
        stream: true,
      );
      final chunks = (response.body as Stream<List<int>>).toList();
      expect(await chunks, isNotEmpty);
      expect(tokenRequests, 2);
      expect(completionRequests, 2);
      expect(receivedTokens, ['Bearer inference-1', 'Bearer inference-2']);
      expect(sentEnvelope?['provider'], 'anthropic');
      expect(sentEnvelope?['model'], 'claude-model');
      expect(sentEnvelope?['provider_request'], {
        'messages': [],
        'stream': true,
      });
    },
  );

  test('Zed Hosted stops after one inference-token retry', () async {
    var tokenRequests = 0;
    var completionRequests = 0;
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        if (options.uri.path == '/client/llm_tokens') {
          tokenRequests++;
          return ResponseBody.fromString(
            jsonEncode({'token': 'inference-$tokenRequests'}),
            200,
          );
        }
        if (options.uri.path == '/completions') {
          completionRequests++;
          return ResponseBody.fromString('{}', 401);
        }
        throw StateError('Unexpected Zed endpoint: ${options.uri}');
      });
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      _account(
        'zed-expiry-retry-fails',
        'zed-hosted',
        authType: 'oauth',
        models: [
          LlmUpstreamModel(
            id: 'zed-hosted:claude-model',
            upstreamModelId: 'claude-model',
            displayName: 'Claude Model',
            capabilities: const {
              'supportedApiProtocols': ['anthropic.messages'],
              'streaming': true,
            },
            config: const {'upstreamProvider': 'anthropic'},
          ),
        ],
      ),
      secret: jsonEncode({
        'oauth_contract': 'zed-hosted-native-rsa-v1',
        'user_id': 'zed-user',
        'access_token': 'account-token',
        'system_id': 'system-id',
        'organization_id': 'org-1',
      }),
    );

    await expectLater(
      LlmConnectorHttpClient(accountService: accounts, dio: dio).request(
        account: account,
        modelId: 'claude-model',
        body: const {'messages': [], 'stream': true},
        nativeFormat: 'anthropic.messages',
        stream: true,
      ),
      throwsA(isA<LlmConnectorHttpException>()),
    );
    expect(tokenRequests, 2);
    expect(completionRequests, 2);
  });
}

LlmAccount _account(
  String id,
  String connector, {
  String authType = 'api_key',
  Map<String, dynamic> endpointConfig = const {},
  List<LlmUpstreamModel> models = const [],
}) =>
    LlmAccount(
      id: id,
      connectorType: connector,
      authType: authType,
      displayName: connector,
      endpointConfig: endpointConfig,
      models: models,
    );

LlmUpstreamModel _upstreamModel(String modelId) => LlmUpstreamModel(
      id: 'model-$modelId',
      upstreamModelId: modelId,
      displayName: modelId,
    );

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

class _QoderModelListRunner implements QoderCliRunner {
  List<String> lastArguments = const [];
  Map<String, String> lastEnvironment = const {};

  @override
  Future<QoderCliRunResult> run({
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
    required String workingDirectory,
    required String stdin,
    required Duration timeout,
    CancelToken? cancelToken,
  }) async {
    lastArguments = arguments;
    lastEnvironment = environment;
    return const QoderCliRunResult(
      stdout: 'qwen3.8-max-preview',
      stderr: '',
      exitCode: 0,
      timedOut: false,
    );
  }
}
