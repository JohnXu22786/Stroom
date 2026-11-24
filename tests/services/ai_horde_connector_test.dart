import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AI Horde has separate anonymous and optional-key account modes',
    () async {
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );

      final definition = LlmConnectorRegistry.find('aihorde');
      expect(definition, isNotNull);
      expect(definition!.protocol, LlmNativeProtocol.openAIChatCompletions);
      expect(definition.authTypes, {'none', 'api_key'});

      final anonymous = await service.saveAccount(
        LlmAccount(
          id: 'horde-anonymous',
          connectorType: 'aihorde',
          authType: 'none',
          displayName: 'AI Horde anonymous',
        ),
      );
      final priority = await service.saveAccount(
        LlmAccount(
          id: 'horde-priority',
          connectorType: 'aihorde',
          authType: 'api_key',
          displayName: 'AI Horde priority',
        ),
        secret: 'horde-private-key',
      );

      expect(anonymous.credentialRef, isNull);
      expect(priority.credentialRef, isNotNull);
      expect(credentials.values.values, contains('horde-private-key'));
      expect((await service.getAccount(priority.id))?.authType, 'api_key');
      final edited = await service.saveAccount(
        LlmAccount(
          id: priority.id,
          connectorType: priority.connectorType,
          authType: priority.authType,
          displayName: 'AI Horde key',
          credentialRef: priority.credentialRef,
          endpointConfig: priority.endpointConfig,
          models: priority.models,
        ),
        secret: 'horde-rotated-key',
      );
      expect(edited.displayName, 'AI Horde key');
      expect(credentials.values.values, contains('horde-rotated-key'));
      expect(
        jsonEncode(preferences.values),
        isNot(contains('horde-rotated-key')),
      );
    },
  );

  test(
    'live models use the Horde catalog and retain only text chat IDs',
    () async {
      final requests = <RequestOptions>[];
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
        dio: Dio()
          ..httpClientAdapter = _RecordingAdapter((options) async {
            requests.add(options);
            return ResponseBody.fromString(
              jsonEncode({
                'object': 'list',
                'data': [
                  {'id': 'aphrodite/TheDrummer/Cydonia-24B-v4.3'},
                  {'id': 'deepseek/deepseek-v4-flash'},
                  {
                    'id': 'aphrodite/vision-text-model',
                    'architecture': {
                      'modality': 'text+image->text',
                      'input_modalities': ['text', 'image'],
                      'output_modalities': ['text'],
                    },
                  },
                  {'id': 'text-embedding-3-large', 'type': 'embedding'},
                  {'id': 'image-generation/stable-diffusion', 'type': 'image'},
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }),
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'horde-models',
          connectorType: 'aihorde',
          authType: 'none',
          displayName: 'AI Horde anonymous',
        ),
      );

      final models = await accounts.discoverModels(
        account,
        refreshRemote: true,
      );

      expect(
        requests.single.uri.toString(),
        'https://oai.aihorde.net/v1/models',
      );
      expect(requests.single.headers['Authorization'], 'Bearer 0000000000');
      expect(models.map((model) => model.upstreamModelId), [
        'aphrodite/TheDrummer/Cydonia-24B-v4.3',
        'deepseek/deepseek-v4-flash',
      ]);
      expect(models.first.capabilities, containsPair('chat', true));
      expect(models.first.capabilities, containsPair('toolCalling', false));
    },
  );

  test(
    'priority-key validation is host-bound and anonymous needs no key call',
    () async {
      final requests = <RequestOptions>[];
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
        dio: Dio()
          ..httpClientAdapter = _RecordingAdapter((options) async {
            requests.add(options);
            final body = options.uri.path.endsWith('/find_user')
                ? {'username': 'test-account', 'kudos': 10}
                : {
                    'data': [
                      {'id': 'aphrodite/TheDrummer/Cydonia-24B-v4.3'},
                    ],
                  };
            return ResponseBody.fromString(
              jsonEncode(body),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }),
      );
      final anonymous = await accounts.saveAccount(
        LlmAccount(
          id: 'horde-anonymous-validation',
          connectorType: 'aihorde',
          authType: 'none',
          displayName: 'AI Horde anonymous',
          endpointConfig: const {'baseUrl': 'https://attacker.example/collect'},
        ),
      );
      await accounts.discoverModels(anonymous, refreshRemote: true);
      expect(requests, hasLength(1));
      expect(requests.single.uri.host, 'oai.aihorde.net');
      expect(requests.single.uri.path, '/v1/models');

      final priority = await accounts.saveAccount(
        LlmAccount(
          id: 'horde-priority-validation',
          connectorType: 'aihorde',
          authType: 'api_key',
          displayName: 'AI Horde priority',
        ),
        secret: 'horde-private-key',
      );
      await accounts.discoverModels(priority, refreshRemote: true);

      final validation = requests[1];
      expect(validation.uri.toString(), 'https://aihorde.net/api/v2/find_user');
      expect(validation.headers['apikey'], 'horde-private-key');
      expect(validation.headers['Authorization'], isNull);
      final modelRequest = requests[2];
      expect(modelRequest.uri.toString(), 'https://oai.aihorde.net/v1/models');
      expect(modelRequest.headers['Authorization'], 'Bearer horde-private-key');
      expect(modelRequest.headers['apikey'], isNull);
      expect(
        requests.every((request) => request.uri.scheme == 'https'),
        isTrue,
      );
    },
  );

  test('rejects an invalid priority key before listing models', () async {
    final requests = <RequestOptions>[];
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
      dio: Dio()
        ..httpClientAdapter = _RecordingAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({'message': 'Invalid API key'}),
            401,
          );
        }),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'horde-invalid-key',
        connectorType: 'aihorde',
        authType: 'api_key',
        displayName: 'AI Horde priority',
      ),
      secret: 'invalid-key',
    );

    await expectLater(
      accounts.discoverModels(account, refreshRemote: true),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(requests, hasLength(1));
    expect(
        requests.single.uri.toString(), 'https://aihorde.net/api/v2/find_user');
    expect(requests.single.followRedirects, isFalse);
  });

  test(
    'chat requests use fixed facade, safe auth, and source timeout',
    () async {
      RequestOptions? captured;
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentials();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'horde-chat',
          connectorType: 'aihorde',
          authType: 'api_key',
          displayName: 'AI Horde priority',
          endpointConfig: const {'baseUrl': 'https://attacker.example/collect'},
        ),
        secret: 'horde-private-key',
      );
      final response = await LlmConnectorHttpClient(
        accountService: accounts,
        dio: Dio()
          ..httpClientAdapter = _RecordingAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              jsonEncode({
                'id': 'chatcmpl-test',
                'choices': [
                  {
                    'message': {'role': 'assistant', 'content': 'hello'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
              200,
              headers: const {
                'content-type': ['application/json'],
              },
            );
          }),
      ).request(
        account: account,
        modelId: 'aphrodite/TheDrummer/Cydonia-24B-v4.3',
        body: const {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'hello'},
              ],
            },
          ],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'unsupported'}
            },
          ],
          'tool_choice': 'auto',
          'parallel_tool_calls': true,
        },
        stream: false,
      );

      expect(
        captured!.uri.toString(),
        'https://oai.aihorde.net/v1/chat/completions',
      );
      expect(captured!.headers['Authorization'], 'Bearer horde-private-key');
      expect(captured!.headers['apikey'], isNull);
      expect(captured!.followRedirects, isFalse);
      expect(captured!.receiveTimeout, const Duration(seconds: 120));
      expect((response.body as Map)['choices'], isA<List>());
      final requestBody = captured!.data is String
          ? jsonDecode(captured!.data as String) as Map
          : captured!.data as Map;
      expect(requestBody['messages'][0]['content'], 'hello');
      expect(requestBody, isNot(contains('tools')));
      expect(requestBody, isNot(contains('tool_choice')));
      expect(requestBody, isNot(contains('parallel_tool_calls')));
    },
  );

  test('rejects tool roles and tool calls embedded in chat messages', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'horde-no-tools',
        connectorType: 'aihorde',
        authType: 'none',
        displayName: 'AI Horde anonymous',
      ),
    );
    var sends = 0;
    final client = LlmConnectorHttpClient(
      accountService: accounts,
      dio: Dio()
        ..httpClientAdapter = _RecordingAdapter((options) async {
          sends++;
          return ResponseBody.fromString('{}', 200);
        }),
    );

    for (final messages in [
      const [
        {'role': 'tool', 'content': 'tool result'},
      ],
      const [
        {
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {'id': 'call-1', 'type': 'function'},
          ],
        },
      ],
      const [
        {
          'role': 'assistant',
          'content': null,
          'function_call': {'name': 'lookup'},
        },
      ],
    ]) {
      await expectLater(
        client.request(
          account: account,
          modelId: 'aphrodite/TheDrummer/Cydonia-24B-v4.3',
          body: {'messages': messages},
        ),
        throwsA(isA<LlmConnectorHttpException>()),
      );
    }
    expect(sends, 0);
  });

  test(
    'chat SSE remains streamable and supports request cancellation',
    () async {
      RequestOptions? captured;
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'horde-stream',
          connectorType: 'aihorde',
          authType: 'none',
          displayName: 'AI Horde anonymous',
        ),
      );
      final client = LlmConnectorHttpClient(
        accountService: accounts,
        dio: Dio()
          ..httpClientAdapter = _RecordingAdapter((options) async {
            captured = options;
            return ResponseBody.fromString(
              'data: {"choices":[{"delta":{"content":"hi"}}]}\n\n'
              'data: [DONE]\n\n',
              200,
              headers: const {
                'content-type': ['text/event-stream'],
              },
            );
          }),
      );
      final response = await client.request(
        account: account,
        modelId: 'aphrodite/TheDrummer/Cydonia-24B-v4.3',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        },
        stream: true,
      );

      expect(captured!.headers['Accept'], 'text/event-stream');
      expect(response.body, isA<Stream<List<int>>>());
      final bytes = await (response.body as Stream<List<int>>).fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      expect(utf8.decode(bytes), contains('[DONE]'));

      final cancelled = CancelToken();
      final started = Completer<void>();
      final blockingClient = LlmConnectorHttpClient(
        accountService: accounts,
        dio: Dio()..httpClientAdapter = _BlockingAdapter(started),
      );
      final pending = blockingClient.request(
        account: account,
        modelId: 'aphrodite/TheDrummer/Cydonia-24B-v4.3',
        body: const {'messages': []},
        cancelToken: cancelled,
      );
      await started.future;
      cancelled.cancel('user cancelled');
      await expectLater(
        pending.timeout(const Duration(seconds: 1)),
        throwsA(isA<LlmConnectorRequestCancelled>()),
      );
    },
  );

  test('AI Horde chat forwards caller timeout to Dio', () async {
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'horde-timeout',
        connectorType: 'aihorde',
        authType: 'none',
        displayName: 'AI Horde anonymous',
      ),
    );
    RequestOptions? captured;
    final client = LlmConnectorHttpClient(
      accountService: accounts,
      dio: Dio()
        ..httpClientAdapter = _RecordingAdapter((options) async {
          captured = options;
          return ResponseBody.fromString('{}', 200);
        }),
    );

    await client.request(
      account: account,
      modelId: 'aphrodite/TheDrummer/Cydonia-24B-v4.3',
      body: const {'messages': []},
      receiveTimeout: const Duration(milliseconds: 10),
    );
    expect(captured!.receiveTimeout, const Duration(milliseconds: 10));
  });
}

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _MemoryCredentials implements LlmCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String reference) async => values.remove(reference);

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) fetchRequest;

  _RecordingAdapter(this.fetchRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      fetchRequest(options);

  @override
  void close({bool force = false}) {}
}

class _BlockingAdapter implements HttpClientAdapter {
  final Completer<void> started;

  _BlockingAdapter(this.started);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!started.isCompleted) started.complete();
    await cancelFuture;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
    );
  }

  @override
  void close({bool force = false}) {}
}
