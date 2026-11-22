import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:pointycastle/export.dart';
import 'package:stroom/services/zed_hosted_connector.dart';

void main() {
  group('Zed Hosted authorization', () {
    test('uses a fresh RSA key and decrypts the exact loopback callback', () {
      final attempt = ZedHostedAuthorizationAttempt.create(
        callbackUri: Uri.parse('http://127.0.0.1:58443/'),
        systemId: 'system-id',
      );
      final uri = attempt.authorizationUri;
      expect(uri.origin, 'https://zed.dev');
      expect(uri.path, '/native_app_signin');
      expect(uri.queryParameters['native_app_port'], '58443');
      expect(uri.queryParameters['system_id'], 'system-id');
      expect(uri.queryParameters['native_app_public_key'], isNotEmpty);

      final encrypted = _encrypt('zed-access', attempt.publicKey);
      final result = attempt.consumeCallback(Uri.parse(
        'http://127.0.0.1:58443/?user_id=zed-user&access_token=$encrypted',
      ));
      expect(result.userId, 'zed-user');
      expect(result.accessToken, 'zed-access');
      expect(result.systemId, 'system-id');
      expect(
        () => attempt.consumeCallback(Uri.parse(
          'http://127.0.0.1:58443/?user_id=zed-user&access_token=$encrypted',
        )),
        throwsA(isA<ZedHostedAuthorizationException>()),
      );
    });

    test('rejects callback host, port, duplicate and malformed fields', () {
      for (final callback in [
        Uri.parse('http://example.com:43210/?user_id=u&access_token=x'),
        Uri.parse('http://127.0.0.1:12345/?user_id=u&access_token=x'),
        Uri.parse('http://127.0.0.1:43210/?user_id=u&user_id=v&access_token=x'),
        Uri.parse('http://127.0.0.1:43210/?user_id=u'),
      ]) {
        final attempt = ZedHostedAuthorizationAttempt.create(
          callbackUri: Uri.parse('http://127.0.0.1:43210/'),
          systemId: 'system-id',
        );
        expect(
          () => attempt.consumeCallback(callback),
          throwsA(isA<ZedHostedAuthorizationException>()),
        );
        expect(
          () => attempt.consumeCallback(callback),
          throwsA(isA<ZedHostedAuthorizationException>()),
        );
      }
    });
  });

  test('cancellation discards the ephemeral private key', () {
    final attempt = ZedHostedAuthorizationAttempt.create(
      callbackUri: Uri.parse('http://127.0.0.1:43211/'),
      systemId: 'system-id',
    );
    attempt.cancel();
    expect(
      () => attempt.consumeCallback(
        Uri.parse('http://127.0.0.1:43211/?user_id=u&access_token=x'),
      ),
      throwsA(isA<ZedHostedAuthorizationException>()),
    );
  });

  test(
      'fetches identity and account-scoped live models without disabled entries',
      () async {
    final requests = <RequestOptions>[];
    final client = ZedHostedApiClient(
      dio: _dio((request) async {
        requests.add(request);
        if (request.uri.path == '/client/users/me') {
          return ResponseBody.fromString(
            jsonEncode({
              'email': 'zed@example.test',
              'name': 'Zed User',
              'default_organization_id': 'org-1',
            }),
            200,
          );
        }
        if (request.uri.path == '/client/llm_tokens') {
          return ResponseBody.fromString(
              jsonEncode({'token': 'llm-token'}), 200);
        }
        if (request.uri.path == '/models') {
          return ResponseBody.fromString(
            jsonEncode({
              'models': [
                {
                  'id': 'claude-model',
                  'display_name': 'Claude Model',
                  'provider': 'anthropic',
                  'max_token_count': 100000,
                  'max_output_tokens': 8000,
                  'supports_tools': true,
                  'supports_streaming_tools': true,
                  'supports_images': false,
                },
                {
                  'id': 'disabled-model',
                  'provider': 'open_ai',
                  'is_disabled': true,
                },
                {
                  'id': 'unknown-provider-model',
                  'provider': 'not-supported',
                },
              ],
            }),
            200,
          );
        }
        return ResponseBody.fromString('{}', 404);
      }),
    );
    final credentials = {
      'access_token': 'account-token',
      'user_id': 'zed-user',
      'system_id': 'system-id',
      'organization_id': 'org-1',
    };

    final identity = await client.fetchIdentity(credentials);
    final models = await client.fetchModels(credentials, forceRefresh: true);
    expect(identity.email, 'zed@example.test');
    expect(identity.organizationId, 'org-1');
    expect(models, hasLength(1));
    expect(models.single.upstreamModelId, 'claude-model');
    expect(models.single.displayName, 'Claude Model');
    expect(models.single.capabilities['contextLength'], 100000);
    expect(models.single.capabilities['maxOutputTokens'], 8000);
    expect(models.single.capabilities['toolCalls'], true);
    expect(models.single.capabilities['tools'], true);
    expect(models.single.capabilities['streamingTools'], true);
    expect(models.single.capabilities['vision'], false);
    expect(models.single.config['upstreamProvider'], 'anthropic');
    expect(
      models.single.config['apiProtocolOverride'],
      'anthropic.messages',
    );
    expect(requests.first.headers['Authorization'], 'zed-user account-token');
    expect(requests.first.headers['x-zed-system-id'], 'system-id');
    expect(requests[1].data, {'organization_id': 'org-1'});
    expect(requests[2].headers['Authorization'], 'Bearer llm-token');
  });

  test('refreshes a rejected inference token once for model discovery',
      () async {
    ZedHostedApiClient.clearTokenCache();
    var tokenRequests = 0;
    var modelRequests = 0;
    final modelTokens = <String?>[];
    final client = ZedHostedApiClient(
      dio: _dio((request) async {
        if (request.uri.path == '/client/llm_tokens') {
          tokenRequests++;
          return ResponseBody.fromString(
            jsonEncode({'token': 'model-token-$tokenRequests'}),
            200,
          );
        }
        if (request.uri.path == '/models') {
          modelRequests++;
          modelTokens.add(request.headers['Authorization'] as String?);
          if (modelRequests == 1) {
            return ResponseBody.fromString(
              '{}',
              403,
              headers: const {
                'x-zed-outdated-token': ['true']
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'models': [
                {'id': 'claude-model', 'provider': 'anthropic'},
              ],
            }),
            200,
          );
        }
        throw StateError('Unexpected Zed endpoint: ${request.uri}');
      }),
    );
    final models = await client.fetchModels({
      'account_id': 'zed-model-refresh',
      'user_id': 'zed-user',
      'access_token': 'account-token',
      'system_id': 'system-id',
      'organization_id': 'org-1',
    });
    expect(models.single.upstreamModelId, 'claude-model');
    expect(tokenRequests, 2);
    expect(modelRequests, 2);
    expect(modelTokens, ['Bearer model-token-1', 'Bearer model-token-2']);
    ZedHostedApiClient.clearTokenCache();
  });

  test('caches inference tokens per account and organization', () async {
    ZedHostedApiClient.clearTokenCache();
    var tokenRequests = 0;
    final client = ZedHostedApiClient(
      dio: _dio((request) async {
        tokenRequests++;
        return ResponseBody.fromString(
          jsonEncode({'token': 'llm-token-$tokenRequests'}),
          200,
        );
      }),
    );
    final firstAccount = {
      'account_id': 'account-one',
      'user_id': 'zed-user',
      'access_token': 'account-token',
      'system_id': 'system-id',
      'organization_id': 'org-1',
    };
    expect(await client.fetchInferenceToken(firstAccount), 'llm-token-1');
    expect(await client.fetchInferenceToken(firstAccount), 'llm-token-1');
    expect(
      await client
          .fetchInferenceToken({...firstAccount, 'account_id': 'account-two'}),
      'llm-token-2',
    );
    expect(
      await client
          .fetchInferenceToken({...firstAccount, 'organization_id': 'org-2'}),
      'llm-token-3',
    );
    expect(tokenRequests, 3);
    ZedHostedApiClient.clearTokenCache();
  });

  test('maps upstream provider metadata and rejects unsupported request shapes',
      () {
    expect(
      zedHostedApiProtocolForProvider('anthropic'),
      'anthropic.messages',
    );
    expect(zedHostedApiProtocolForProvider('open_ai'), 'openai.responses');
    expect(
      zedHostedApiProtocolForProvider('google'),
      'google.gemini.generate_content',
    );
    expect(zedHostedApiProtocolForProvider('x_ai'), 'openai.chat_completions');
    expect(zedHostedApiProtocolForProvider('unknown-provider'), isNull);

    for (final entry in [
      (
        provider: 'open_ai',
        protocol: 'openai.responses',
        format: 'responses',
        field: 'input',
      ),
      (
        provider: 'google',
        protocol: 'google.gemini.generate_content',
        format: null,
        field: 'contents',
      ),
      (
        provider: 'x_ai',
        protocol: 'openai.chat_completions',
        format: null,
        field: 'messages',
      ),
    ]) {
      final providerModel = LlmUpstreamModel(
        id: 'zed-hosted:${entry.provider}',
        upstreamModelId: 'model-id',
        displayName: entry.provider,
        capabilities: {
          'supportedApiProtocols': [entry.protocol],
        },
        config: {'upstreamProvider': entry.provider},
      );
      expect(
        buildZedHostedCompletionEnvelope(
          model: providerModel,
          body: {entry.field: []},
          nativeFormat: entry.format,
          stream: true,
        )['provider'],
        entry.provider,
      );
    }

    final model = LlmUpstreamModel(
      id: 'zed:claude',
      upstreamModelId: 'claude-model',
      displayName: 'Claude Model',
      capabilities: const {
        'supportedApiProtocols': ['anthropic.messages'],
        'toolCalls': false,
        'vision': false,
      },
      config: const {'upstreamProvider': 'anthropic'},
    );
    expect(
      () => buildZedHostedCompletionEnvelope(
        model: model,
        body: const {'messages': []},
        nativeFormat: 'openai.chat_completions',
        stream: true,
      ),
      throwsA(isA<ZedHostedUnsupportedRequest>()),
    );
    final openAiResponsesModel = LlmUpstreamModel(
      id: 'zed:openai-responses',
      upstreamModelId: 'openai-model',
      displayName: 'OpenAI Model',
      capabilities: const {'toolCalls': true},
      config: const {'upstreamProvider': 'open_ai'},
    );
    for (final item in [
      const {
        'type': 'function_call',
        'call_id': 'call-1',
        'name': 'lookup',
        'arguments': '{}',
      },
      const {
        'type': 'function_call_output',
        'call_id': 'call-1',
        'output': '{}',
      },
    ]) {
      expect(
        () => buildZedHostedCompletionEnvelope(
          model: openAiResponsesModel,
          body: {
            'input': [item]
          },
          nativeFormat: 'responses',
          stream: true,
        ),
        throwsA(isA<ZedHostedUnsupportedRequest>()),
        reason: '${item['type']} items require streaming tool support',
      );
    }
    final toolHistoryModel = LlmUpstreamModel(
      id: 'zed:anthropic-tool-history',
      upstreamModelId: 'claude-model',
      displayName: 'Claude Model',
      capabilities: const {'toolCalls': true},
      config: const {'upstreamProvider': 'anthropic'},
    );
    for (final message in [
      const {'role': 'tool', 'content': '{"result":"ok"}'},
      const {
        'role': 'assistant',
        'content': [
          {
            'type': 'tool_use',
            'id': 'tool-1',
            'name': 'lookup',
            'input': {'key': 'value'},
          }
        ],
      },
      const {
        'role': 'user',
        'content': [
          {'type': 'tool_result', 'tool_use_id': 'tool-1', 'content': 'ok'}
        ],
      },
    ]) {
      expect(
        () => buildZedHostedCompletionEnvelope(
          model: toolHistoryModel,
          body: {
            'messages': [message]
          },
          nativeFormat: 'anthropic.messages',
          stream: true,
        ),
        throwsA(isA<ZedHostedUnsupportedRequest>()),
        reason:
            'nested ${message['role']} tool history requires streaming tools',
      );
    }
    for (final streamingTools in [null, false]) {
      final capabilities = <String, dynamic>{'toolCalls': true};
      if (streamingTools != null) {
        capabilities['streamingTools'] = streamingTools;
      }
      final toolModel = LlmUpstreamModel(
        id: 'zed:claude-tools',
        upstreamModelId: 'claude-model',
        displayName: 'Claude Model',
        capabilities: capabilities,
        config: const {'upstreamProvider': 'anthropic'},
      );
      expect(
        () => buildZedHostedCompletionEnvelope(
          model: toolModel,
          body: const {
            'messages': [],
            'tools': [
              {
                'type': 'function',
                'function': {'name': 'lookup'}
              },
            ],
          },
          nativeFormat: 'anthropic.messages',
          stream: true,
        ),
        throwsA(isA<ZedHostedUnsupportedRequest>()),
        reason: 'tool streaming requires an explicit per-model flag',
      );
    }
    final streamingToolModel = LlmUpstreamModel(
      id: 'zed:claude-streaming-tools',
      upstreamModelId: 'claude-model',
      displayName: 'Claude Model',
      capabilities: const {'toolCalls': true, 'streamingTools': true},
      config: const {'upstreamProvider': 'anthropic'},
    );
    expect(
      buildZedHostedCompletionEnvelope(
        model: streamingToolModel,
        body: const {
          'messages': [],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'}
            },
          ],
        },
        nativeFormat: 'anthropic.messages',
        stream: true,
      )['provider_request'],
      isA<Map>(),
    );
    expect(
      () => buildZedHostedCompletionEnvelope(
        model: model,
        body: const {
          'messages': [],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'}
            },
          ],
        },
        nativeFormat: 'anthropic.messages',
        stream: true,
      ),
      throwsA(isA<ZedHostedUnsupportedRequest>()),
    );
    expect(
      () => buildZedHostedCompletionEnvelope(
        model: model,
        body: const {'messages': []},
        nativeFormat: 'anthropic.messages',
        stream: false,
      ),
      throwsA(isA<ZedHostedUnsupportedRequest>()),
    );
    expect(
      () => buildZedHostedCompletionEnvelope(
        model: model,
        body: const {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'input_audio'}
              ]
            },
          ],
        },
        nativeFormat: 'anthropic.messages',
        stream: true,
      ),
      throwsA(isA<ZedHostedUnsupportedRequest>()),
    );
  });

  test('unwraps source NDJSON and SSE event envelopes into provider SSE frames',
      () async {
    final chunks = await zedHostedCompletionEvents(Stream.fromIterable([
      utf8.encode('{"event":{"type":"message_start"}}\n{"status":"ready"}\n'),
      utf8.encode(
          'data: {"event":{"type":"content_block_delta","delta":{"text":"hello"}}}\n'),
      utf8.encode('data: [DONE]\n'),
    ])).transform(utf8.decoder).join();
    expect(chunks, contains('data: {"type":"message_start"}\n\n'));
    expect(
        chunks,
        contains(
            'data: {"type":"content_block_delta","delta":{"text":"hello"}}\n\n'));
    expect(chunks, contains('data: [DONE]\n\n'));
  });
}

String _encrypt(String value, RSAPublicKey publicKey) {
  final cipher = OAEPEncoding.withSHA256(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
  return base64Url
      .encode(cipher.process(Uint8List.fromList(utf8.encode(value))));
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) handler) =>
    Dio()..httpClientAdapter = _FunctionalAdapter(handler);

class _FunctionalAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;

  _FunctionalAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
