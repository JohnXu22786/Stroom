import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  test('routes Google Generative Language accounts through Gemini chat', () {
    expect(
      llmRoutedChatSupportedConnectorTypes('google.gemini.generate_content'),
      containsAll({'gemini', 'aistudio'}),
    );
  });

  test('custom connectors remain eligible for Anthropic Messages bridge', () {
    expect(
      llmRoutedChatSupportedConnectorTypes('anthropic.messages'),
      contains('openai-compatibility'),
    );
    expect(
      llmRoutedChatSupportedConnectorTypes('anthropic.messages'),
      isNot(contains('bedrock')),
    );
  });

  test('Responses bridge excludes native chat-only connectors', () {
    expect(
      llmRoutedChatSupportedConnectorTypes('openai.responses'),
      containsAll({'openai-compatibility', 'openai-api'}),
    );
    expect(
      llmRoutedChatSupportedConnectorTypes('openai.responses'),
      isNot(contains('moonshot')),
    );
  });

  test(
      'uses the selected routed account protocol when no model override exists',
      () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    for (final (id, protocol) in [
      ('chat-account', 'openai.chat_completions'),
      ('responses-account', 'anthropic.messages'),
    ]) {
      await accounts.saveAccount(
        LlmAccount(
          id: id,
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: id,
          status: LlmAccountStatus.ready,
          endpointConfig: {
            'apiProtocol': protocol,
            'baseUrl': 'https://provider.example.test/v1',
          },
          models: const [
            LlmUpstreamModel(
              id: 'local-model',
              upstreamModelId: 'gpt-routed',
              displayName: 'Routed model',
            ),
          ],
        ),
        secret: 'test-api-key',
      );
    }
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'protocol-routing-group',
        displayName: 'Protocol routing group',
        members: const [
          LlmModelGroupMember(
            accountId: 'chat-account',
            localModelId: 'local-model',
            upstreamModelId: 'gpt-routed',
          ),
          LlmModelGroupMember(
            accountId: 'responses-account',
            localModelId: 'local-model',
            upstreamModelId: 'gpt-routed',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      responseBody: {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      },
    );
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      )),
      groupId: 'protocol-routing-group',
      localModelId: 'local-model',
      endpointType: 'openai',
      apiProtocol: 'openai.chat_completions',
      selectedAccountId: 'responses-account',
    );

    expect(
      await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]),
      'ok',
    );
    expect(connector.requestedAccountIds, ['responses-account']);
    expect(connector.lastNativeFormat, 'anthropic');
    expect(connector.requestBody, contains('max_tokens'));
  });

  test('non-streaming image output is stored and exposed to callers', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'image-output-account',
        connectorType: 'openai-api',
        authType: 'api_key',
        displayName: 'Image output',
        status: LlmAccountStatus.ready,
        endpointConfig: const {'chatProtocol': 'openai.responses'},
        models: const [
          LlmUpstreamModel(
            id: 'image-output-model',
            upstreamModelId: 'image-upstream',
            displayName: 'Image model',
            capabilities: {'vision': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'image-output-group',
        displayName: 'Image output',
        members: const [
          LlmModelGroupMember(
            accountId: 'image-output-account',
            localModelId: 'image-output-model',
            upstreamModelId: 'image-upstream',
          ),
        ],
      ),
    );
    final imageBytes = Uint8List.fromList([1, 2, 3]);
    final saved = <Uint8List>[];
    final connector = _FakeConnectorClient(
      accounts,
      responseBody: {
        'output': [
          {
            'type': 'image_generation_call',
            'id': 'image-1',
            'result': base64Encode(imageBytes),
            'mime_type': 'image/png',
          },
        ],
      },
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
      groupId: 'image-output-group',
      localModelId: 'image-output-model',
      endpointType: 'openai',
      saveMediaFile: (fileName, payload, {stableId}) async {
        saved.add(payload);
        return 'attachments/$fileName';
      },
    );

    final text = await provider.chat(const [
      {'role': 'user', 'content': 'draw a blue circle'},
    ]);

    expect(text, isEmpty);
    expect(saved, [imageBytes]);
    expect(provider.lastMediaAttachments, hasLength(1));
    expect(provider.lastMediaAttachments.single.fileType, 'image');
    expect(provider.lastMediaAttachments.single.mimeType, 'image/png');
    expect(provider.lastMediaAttachments.single.storagePath,
        'attachments/image.png');
  });

  test('streamed audio output is stored and emitted as a media attachment',
      () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'audio-output-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Audio output',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'audio-output-model',
            upstreamModelId: 'audio-upstream',
            displayName: 'Audio model',
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'audio-output-group',
        displayName: 'Audio output',
        members: [
          LlmModelGroupMember(
            accountId: 'audio-output-account',
            localModelId: 'audio-output-model',
            upstreamModelId: 'audio-upstream',
          ),
        ],
      ),
    );
    final bytes = Uint8List.fromList([1, 3, 5, 7]);
    final parameterizedImageBytes = Uint8List.fromList([8, 9, 10]);
    final savedMedia = <Uint8List>[];
    final frame = jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {
            'audio': {'data': base64Encode(bytes), 'format': 'mp3'},
          },
        },
        {
          'index': 1,
          'delta': {
            'audio': {
              'data': base64Encode(Uint8List.fromList([20, 21])),
              'format': 'mp3'
            },
          },
        },
      ],
    });
    final imageFrame = jsonEncode({
      'type': 'image_generation_call',
      'result': base64Encode(Uint8List.fromList([2, 4, 6])),
      'mime_type': 'image/png',
      'revised_prompt': 'A small blue circle',
    });
    final parameterizedImageFrame = jsonEncode({
      'image_url': {
        'url':
            'data:image/png;charset=utf-8;base64,${base64Encode(parameterizedImageBytes)}',
      },
    });
    final textBeforeImageFrame = jsonEncode({
      'choices': [
        {
          'delta': {'content': 'before image'}
        },
      ],
    });
    final textBeforeAudioFrame = jsonEncode({
      'choices': [
        {
          'delta': {'content': 'before audio'}
        },
      ],
    });
    final textAfterAudioFrame = jsonEncode({
      'choices': [
        {
          'delta': {'content': 'after audio'}
        },
      ],
    });
    final textAfterImageFrame = jsonEncode({
      'choices': [
        {
          'delta': {'content': 'after image'}
        },
      ],
    });
    final secondAudioFrame = jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {
            'audio': {
              'data': base64Encode(Uint8List.fromList([5, 6])),
            },
          },
        },
        {
          'index': 1,
          'delta': {
            'audio': {
              'data': base64Encode(Uint8List.fromList([22])),
              'format': 'mp3'
            },
          },
        },
      ],
    });
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.fromIterable([
        utf8.encode('data: $textBeforeAudioFrame\n\n'),
        utf8.encode('data: $frame\n\n'),
        utf8.encode('data: $textAfterAudioFrame\n\n'),
        utf8.encode('data: $textBeforeImageFrame\n\n'),
        utf8.encode('data: $imageFrame\n\n'),
        utf8.encode('data: $textAfterImageFrame\n\n'),
        utf8.encode('data: $parameterizedImageFrame\n\n'),
        utf8.encode('data: $secondAudioFrame\n\n'),
        utf8.encode('data: [DONE]\n\n'),
      ]),
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
      groupId: 'audio-output-group',
      localModelId: 'audio-output-model',
      endpointType: 'openai',
      saveMediaFile: (fileName, payload, {stableId}) async {
        savedMedia.add(payload);
        return 'attachments/$fileName';
      },
    );

    final events = await provider.chatStream(const [
      {'role': 'user', 'content': 'make audio'},
    ]).toList();
    final attachments =
        events.expand((event) => event.mediaAttachments ?? const []).toList();

    final beforeImageIndex =
        events.indexWhere((event) => event.text == 'before image');
    final mediaIndex = events
        .indexWhere((event) => event.mediaAttachments?.isNotEmpty == true);
    final afterImageIndex =
        events.indexWhere((event) => event.text == 'after image');
    expect(beforeImageIndex, lessThan(mediaIndex));
    expect(mediaIndex, lessThan(afterImageIndex));
    final beforeAudio =
        events.firstWhere((event) => event.text == 'before audio');
    final afterAudio =
        events.firstWhere((event) => event.text == 'after audio');
    final audioEvent = events.firstWhere(
      (event) =>
          event.mediaAttachments?.any((item) => item.fileType == 'audio') ==
          true,
    );
    expect(beforeAudio.contentOrder, lessThan(audioEvent.contentOrder!));
    expect(audioEvent.contentOrder, lessThan(afterAudio.contentOrder!));

    final attachment =
        attachments.firstWhere((item) => item.fileType == 'audio');
    expect(attachment.fileType, 'audio');
    expect(attachment.mimeType, 'audio/mpeg');
    expect(attachment.storagePath, 'attachments/audio.mp3');
    expect(
      savedMedia.map(base64Encode),
      unorderedEquals([
        base64Encode(Uint8List.fromList([1, 3, 5, 7, 5, 6])),
        base64Encode(Uint8List.fromList([20, 21, 22])),
        base64Encode(Uint8List.fromList([2, 4, 6])),
        base64Encode(parameterizedImageBytes),
      ]),
    );
    expect(attachments, hasLength(4));
    expect(attachments.map((attachment) => attachment.fileType), [
      'image',
      'image',
      'audio',
      'audio',
    ]);
    expect(attachments.map((attachment) => attachment.mimeType), [
      'image/png',
      'image/png',
      'audio/mpeg',
      'audio/mpeg',
    ]);
    expect(
      attachments[2].extraFields['stroom.mediaSource']['metadata']
          ['choiceIndex'],
      0,
    );
    expect(
      attachments[3].extraFields['stroom.mediaSource']['metadata']
          ['choiceIndex'],
      1,
    );
    expect(
      attachments[0].extraFields['stroom.mediaSource']['metadata']
          ['revised_prompt'],
      'A small blue circle',
    );
  });

  test('Responses partial audio is persisted when the stream errors', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'responses-audio-account',
        connectorType: 'openai-api',
        authType: 'api_key',
        displayName: 'Responses audio',
        status: LlmAccountStatus.ready,
        endpointConfig: const {'chatProtocol': 'openai.responses'},
        models: const [
          LlmUpstreamModel(
            id: 'responses-audio-model',
            upstreamModelId: 'gpt-4o-audio',
            displayName: 'Responses audio model',
          ),
        ],
      ),
      secret: 'responses-audio-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'responses-audio-group',
        displayName: 'Responses audio group',
        members: const [
          LlmModelGroupMember(
            accountId: 'responses-audio-account',
            localModelId: 'responses-audio-model',
            upstreamModelId: 'gpt-4o-audio',
          ),
        ],
      ),
    );
    final bytes = Uint8List.fromList([9, 8, 7]);
    final secondAudioBytes = Uint8List.fromList([6, 5, 4]);
    final imageBytes = Uint8List.fromList([4, 5, 6]);
    final partialImageBytes = Uint8List.fromList([1, 2, 3]);
    final partialImage = jsonEncode({
      'type': 'response.image_generation_call.partial_image',
      'item_id': 'image-generation-1',
      'output_index': 0,
      'partial_image_index': 0,
      'partial_image_b64': base64Encode(partialImageBytes),
    });
    final imageItem = {
      'id': 'image-generation-1',
      'type': 'image_generation_call',
      'result': base64Encode(imageBytes),
      'mime_type': 'image/png',
    };
    final imageItemDone = jsonEncode({
      'type': 'response.output_item.done',
      'item': imageItem,
    });
    final responseCompleted = jsonEncode({
      'type': 'response.completed',
      'response': {
        'output': [imageItem]
      },
    });
    final frame = jsonEncode({
      'type': 'response.output_audio.delta',
      'item_id': 'audio-item-1',
      'output_index': 1,
      'content_index': 0,
      'delta': base64Encode(bytes),
      'format': 'wav',
    });
    final secondAudioFrame = jsonEncode({
      'type': 'response.output_audio.delta',
      'item_id': 'audio-item-2',
      'output_index': 2,
      'content_index': 0,
      'delta': base64Encode(secondAudioBytes),
      'format': 'mp3',
    });
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.multi((controller) {
        controller.add(utf8.encode('data: $partialImage\n\n'));
        controller.add(utf8.encode('data: $imageItemDone\n\n'));
        controller.add(utf8.encode('data: $responseCompleted\n\n'));
        controller.add(utf8.encode('data: $frame\n\n'));
        controller.add(utf8.encode('data: $secondAudioFrame\n\n'));
        controller.addError(StateError('stream failed'));
        controller.close();
      }),
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
    final savedMedia = <String, List<Uint8List>>{};
    var audioSaveAttempts = 0;
    final provider = LlmRoutedChatProvider(
      runtime: Future.value(runtime),
      groupId: 'responses-audio-group',
      localModelId: 'responses-audio-model',
      endpointType: 'openai',
      saveMediaFile: (fileName, payload, {stableId}) async {
        if (fileName == 'audio.wav' && audioSaveAttempts++ == 0) {
          throw StateError('temporary media storage error');
        }
        savedMedia.putIfAbsent(fileName, () => []).add(payload);
        return 'attachments/$fileName';
      },
    );

    final receivedEvents = <dynamic>[];
    try {
      await for (final event in provider.chatStream(const [
        {'role': 'user', 'content': 'make audio'},
      ])) {
        receivedEvents.add(event);
      }
    } catch (_) {
      // The test expects the provider to preserve usable audio before the error.
    }

    final attachments = receivedEvents
        .expand((event) => event.mediaAttachments ?? const [])
        .toList();
    expect(attachments, hasLength(4));
    expect(attachments.map((attachment) => attachment.fileType), [
      'image',
      'image',
      'audio',
      'audio',
    ]);
    expect(attachments.map((attachment) => attachment.mimeType), [
      'image/png',
      'image/png',
      'audio/wav',
      'audio/mpeg',
    ]);
    expect(
      savedMedia['image.png']!.map(base64Encode),
      containsAll([base64Encode(partialImageBytes), base64Encode(imageBytes)]),
    );
    expect(savedMedia['audio.wav']!.single, bytes);
    expect(savedMedia['audio.mp3']!.single, secondAudioBytes);
    expect(
      attachments[2].extraFields['stroom.mediaSource']['metadata']['item_id'],
      'audio-item-1',
    );
    expect(
      attachments[3].extraFields['stroom.mediaSource']['metadata']['item_id'],
      'audio-item-2',
    );
    expect(
      attachments.first.extraFields['stroom.mediaSource']['metadata']
          ['partial_image_index'],
      0,
    );
    expect(audioSaveAttempts, 2);
  });

  test('routing reports when no candidate supports requested modalities', () {
    final error = AiGatewayRoutingException([
      const AiGatewayRouteDecision(
        subjectId: 'account-model',
        reason: 'capability_mismatch',
      ),
    ]);

    expect(error.toString(), contains('support the capabilities required'));
  });

  test('output modality options route to capable members', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    for (final (accountId, supportsAudio) in [
      ('output-text-account', false),
      ('output-audio-account', true),
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
              upstreamModelId: '$accountId-upstream',
              displayName: accountId,
              capabilities: {'audio': supportsAudio},
            ),
          ],
        ),
      );
    }
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'output-audio-group',
        displayName: 'Output audio routing',
        members: const [
          LlmModelGroupMember(
            accountId: 'output-text-account',
            localModelId: 'output-audio-model',
            upstreamModelId: 'output-text-account-upstream',
          ),
          LlmModelGroupMember(
            accountId: 'output-audio-account',
            localModelId: 'output-audio-model',
            upstreamModelId: 'output-audio-account-upstream',
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
      groupId: 'output-audio-group',
      localModelId: 'output-audio-model',
      endpointType: 'openai',
    );

    await provider.chat(
      const [
        {'role': 'user', 'content': 'speak the answer'},
      ],
      extraParams: const {
        'modalities': ['audio']
      },
    );

    expect(connector.requestedAccountIds, ['output-audio-account']);
  });

  for (final (
        connectorType,
        endpointType,
        upstreamModelId,
        expectedRequestField,
        expectedResponse,
        endpointConfig,
      ) in [
    (
      'openai-compatibility',
      'openai',
      'gpt-routed',
      'messages',
      {
        'choices': [
          {
            'message': {'content': 'ok'},
          },
        ],
      },
      const <String, dynamic>{},
    ),
    (
      'claude',
      'anthropic',
      'claude-routed',
      'messages',
      {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      },
      const <String, dynamic>{},
    ),
    (
      'gemini',
      'google.gemini.generate_content',
      'gemini-routed',
      'contents',
      {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'private reasoning', 'thought': true},
                {'text': 'ok'},
              ],
            },
          },
        ],
      },
      const <String, dynamic>{},
    ),
    (
      'gemini-interactions',
      'google.gemini.interactions',
      'interaction-routed',
      'input',
      {
        'outputs': [
          {
            'type': 'model_output',
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
          },
        ],
      },
      const <String, dynamic>{},
    ),
    (
      'ollama',
      'ollama.chat',
      'llama-routed',
      'messages',
      {
        'message': {'content': 'ok'},
      },
      const <String, dynamic>{'baseUrl': 'http://localhost:11434'},
    ),
    (
      'openai-api',
      'openai',
      'gpt-response-routed',
      'input',
      {
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': 'ok'},
            ],
          },
        ],
      },
      const <String, dynamic>{'chatProtocol': 'openai.responses'},
    ),
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
            authType: const {
              'claude',
              'gemini',
              'gemini-interactions',
              'openai-api',
            }.contains(connectorType)
                ? 'api_key'
                : 'none',
            displayName: 'Test account',
            status: LlmAccountStatus.ready,
            endpointConfig: endpointConfig,
            models: [
              LlmUpstreamModel(
                id: 'local-model',
                upstreamModelId: upstreamModelId,
                displayName: 'Routed model',
              ),
            ],
          ),
          secret: const {
            'claude',
            'gemini',
            'gemini-interactions',
            'openai-api',
          }.contains(connectorType)
              ? 'test-api-key'
              : null,
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
        final connector = _FakeConnectorClient(
          accounts,
          responseBody: expectedResponse,
          responseHeaders: const {
            'x-request-id': ['request-123'],
          },
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
          groupId: 'group-$endpointType',
          localModelId: 'local-model',
          endpointType: endpointType,
        );

        final answer = await provider.chat(
          connectorType == 'gemini-interactions'
              ? const [
                  {'role': 'user', 'content': 'previous turn'},
                  {'role': 'assistant', 'content': 'previous response'},
                  {'role': 'user', 'content': 'continue'},
                ]
              : const [
                  {'role': 'user', 'content': 'hello'},
                ],
          temperature: 0.3,
          extraParams: {
            'model': 'caller-selected-model',
            if (connectorType == 'claude') ...{
              'thinking': {'type': 'enabled', 'budget_tokens': 1024},
              'temperature': 0.7,
            },
            if (connectorType == 'gemini-interactions')
              'previous_interaction_id': 'interaction-previous',
            if (endpointConfig['chatProtocol'] == 'openai.responses')
              'max_output_tokens': 42,
            if (connectorType == 'ollama') 'options': {'num_ctx': 8192},
          },
        );

        expect(answer, 'ok');
        if (expectedRequestField != 'contents') {
          expect(connector.requestBody?['model'], upstreamModelId);
        }
        expect(connector.requestedModelIds, [upstreamModelId]);
        if (endpointType == 'openai' && connectorType == 'openai-api') {
          expect(connector.lastNativeFormat, 'responses');
        }
        expect(connector.requestBody?[expectedRequestField], isNotNull);
        if (connectorType == 'gemini-interactions') {
          expect(
            connector.requestBody?['previous_interaction_id'],
            'interaction-previous',
          );
          expect(connector.requestBody?['input'], [
            {'type': 'text', 'text': 'continue'},
          ]);
        }
        if (connectorType == 'claude') {
          expect(connector.requestBody?.containsKey('temperature'), isFalse);
        }
        if (endpointConfig['chatProtocol'] == 'openai.responses') {
          expect(connector.requestBody?['max_output_tokens'], 42);
        }
        if (connectorType == 'ollama') {
          expect((connector.requestBody?['options'] as Map?)?['num_ctx'], 8192);
        }
        expect(provider.lastResponseHeaders, {
          'x-request-id': ['request-123'],
        });
      },
    );
  }

  test('Anthropic routed request converts OpenAI tool history', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'tool-history-account',
        connectorType: 'claude',
        authType: 'api_key',
        displayName: 'Tool history account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'tool-history-model',
            upstreamModelId: 'claude-tool-history',
            displayName: 'Claude tools',
            capabilities: {'tools': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'tool-history-group',
        displayName: 'Tool history group',
        members: const [
          LlmModelGroupMember(
            accountId: 'tool-history-account',
            localModelId: 'tool-history-model',
            upstreamModelId: 'claude-tool-history',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      responseBody: const {
        'content': [
          {'type': 'text', 'text': 'It is 18 degrees.'},
        ],
      },
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
      groupId: 'tool-history-group',
      localModelId: 'tool-history-model',
      endpointType: 'anthropic',
    );

    await provider.chat(const [
      {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call-1',
            'type': 'function',
            'function': {'name': 'lookup', 'arguments': '{"city":"Paris"}'},
          },
        ],
      },
      {
        'role': 'tool',
        'tool_call_id': 'call-1',
        'content': '{"temperature":18}',
      },
    ]);

    expect(connector.requestBody?['messages'], [
      {
        'role': 'assistant',
        'content': [
          {
            'type': 'tool_use',
            'id': 'call-1',
            'name': 'lookup',
            'input': {'city': 'Paris'},
          },
        ],
      },
      {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'call-1',
            'content': '{"temperature":18}',
          },
        ],
      },
    ]);
  });

  test('Anthropic tool-only completion is successful and retained', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'tool-only-account',
        connectorType: 'claude',
        authType: 'api_key',
        displayName: 'Tool-only account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'tool-only-model',
            upstreamModelId: 'claude-tool-only',
            displayName: 'Claude tools',
            capabilities: {'tools': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'tool-only-group',
        displayName: 'Tool-only group',
        members: const [
          LlmModelGroupMember(
            accountId: 'tool-only-account',
            localModelId: 'tool-only-model',
            upstreamModelId: 'claude-tool-only',
          ),
        ],
      ),
    );
    final toolCall = const {
      'type': 'tool_use',
      'id': 'tool-call-1',
      'name': 'lookup',
      'input': {'city': 'Paris'},
    };
    final connector = _FakeConnectorClient(
      accounts,
      responseBody: {
        'content': [toolCall],
        'stop_reason': 'tool_use',
      },
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
      groupId: 'tool-only-group',
      localModelId: 'tool-only-model',
      endpointType: 'anthropic',
    );

    final result = await provider.chat(
      const [
        {'role': 'user', 'content': 'Look up Paris weather.'},
      ],
      extraParams: const {
        'tools': [
          {
            'type': 'function',
            'function': {'name': 'lookup'},
          },
        ],
      },
    );

    expect(result, isEmpty);
    expect(provider.lastResponseData?['content'], [toolCall]);
    expect(provider.lastResponseData?['stop_reason'], 'tool_use');
    expect(connector.requestedAccountIds, ['tool-only-account']);
  });

  test(
    'Responses nonstreaming refusal content is returned to the caller',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'responses-refusal',
          connectorType: 'openai-api',
          authType: 'api_key',
          displayName: 'Responses refusal',
          status: LlmAccountStatus.ready,
          endpointConfig: const {'chatProtocol': 'openai.responses'},
          models: const [
            LlmUpstreamModel(
              id: 'responses-refusal-model',
              upstreamModelId: 'gpt-4o',
              displayName: 'GPT-4o',
            ),
          ],
        ),
        secret: 'responses-key',
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'responses-refusal-group',
          displayName: 'Responses refusal group',
          members: const [
            LlmModelGroupMember(
              accountId: 'responses-refusal',
              localModelId: 'responses-refusal-model',
              upstreamModelId: 'gpt-4o',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBody: {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'refusal',
                  'refusal': 'I cannot help with that request.',
                },
              ],
            },
          ],
        },
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
        groupId: 'responses-refusal-group',
        localModelId: 'responses-refusal-model',
        endpointType: 'openai',
      );

      expect(
        await provider.chat(const [
          {'role': 'user', 'content': 'do this'},
        ]),
        'I cannot help with that request.',
      );
    },
  );

  test('extraParams tools require a tool-capable account', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'no-tools-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'No tools account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'no-tools-model',
            upstreamModelId: 'gpt-no-tools',
            displayName: 'No tools model',
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'no-tools-group',
        displayName: 'No tools group',
        members: const [
          LlmModelGroupMember(
            accountId: 'no-tools-account',
            localModelId: 'no-tools-model',
            upstreamModelId: 'gpt-no-tools',
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
      groupId: 'no-tools-group',
      localModelId: 'no-tools-model',
      endpointType: 'openai',
    );

    await expectLater(
      provider.chat(
        const [
          {'role': 'user', 'content': 'hello'},
        ],
        extraParams: const {
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'},
            },
          ],
        },
      ),
      throwsA(isA<AiGatewayRoutingException>()),
    );
    expect(connector.requestedAccountIds, isEmpty);
  });

  test(
    'routes OpenAI-compatible named providers through the ChatAdapter',
    () async {
      for (final connectorType in [
        'moonshot',
        'glm',
        'deepseek',
        'minimax',
        'qwen',
      ]) {
        final preferences = _MemoryPreferences();
        final accounts = LlmAccountConnectorService(
          preferences: preferences,
          credentialStore: _MemoryCredentialStore(),
        );
        final accountId = 'account-$connectorType';
        const localModelId = 'local-compatible-model';
        final upstreamModelId = '$connectorType-chat';
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: connectorType,
            authType: 'api_key',
            displayName: connectorType,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: localModelId,
                upstreamModelId: upstreamModelId,
                displayName: upstreamModelId,
              ),
            ],
          ),
          secret: 'provider-key',
        );
        await accounts.saveModelGroup(
          LlmModelGroup(
            id: 'group-$connectorType',
            displayName: connectorType,
            members: [
              LlmModelGroupMember(
                accountId: accountId,
                localModelId: localModelId,
                upstreamModelId: upstreamModelId,
              ),
            ],
          ),
        );
        final connector = _FakeConnectorClient(
          accounts,
          responseBody: {
            'choices': [
              {
                'message': {'content': 'ok'},
              },
            ],
          },
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
          groupId: 'group-$connectorType',
          localModelId: localModelId,
          endpointType: 'openai',
        );

        expect(
          await provider.chat(const [
            {'role': 'user', 'content': 'hello'},
          ]),
          'ok',
          reason: connectorType,
        );
        expect(
            connector.requestedAccountIds,
            [
              accountId,
            ],
            reason: connectorType);
      }
    },
  );

  test(
    'routes Bedrock ChatAdapter accounts through the native chat executor',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'bedrock-routed-account',
          connectorType: 'bedrock',
          authType: 'aws_credentials',
          displayName: 'Bedrock ChatAdapter',
          status: LlmAccountStatus.ready,
          endpointConfig: const {'region': 'us-east-1'},
          models: const [
            LlmUpstreamModel(
              id: 'bedrock-routed-model',
              upstreamModelId: 'anthropic.claude-3-5-sonnet',
              displayName: 'Bedrock Claude',
            ),
          ],
        ),
        secret: jsonEncode({
          'accessKeyId': 'AKIDEXAMPLE',
          'secretAccessKey': 'private-aws-secret',
        }),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'bedrock-routed-group',
          displayName: 'Bedrock group',
          members: const [
            LlmModelGroupMember(
              accountId: 'bedrock-routed-account',
              localModelId: 'bedrock-routed-model',
              upstreamModelId: 'anthropic.claude-3-5-sonnet',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBody: const {
          'choices': [
            {
              'message': {'content': 'Bedrock answer'},
            },
          ],
        },
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
        groupId: 'bedrock-routed-group',
        localModelId: 'bedrock-routed-model',
        endpointType: 'openai',
      );

      final result = await provider.chat(const [
        {'role': 'user', 'content': 'hello'},
      ]);

      expect(result, 'Bedrock answer');
      expect(connector.requestedAccountIds, ['bedrock-routed-account']);
      expect(connector.requestedModelIds, ['anthropic.claude-3-5-sonnet']);
      expect(connector.requestBody?['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
    },
  );

  test('Ollama streaming decodes newline-delimited JSON responses', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'ollama-stream-account',
        connectorType: 'ollama',
        authType: 'none',
        displayName: 'Ollama stream account',
        status: LlmAccountStatus.ready,
        endpointConfig: const {'baseUrl': 'http://localhost:11434'},
        models: const [
          LlmUpstreamModel(
            id: 'ollama-stream-model',
            upstreamModelId: 'llama3',
            displayName: 'Ollama stream model',
            capabilities: {'streaming': true},
          ),
        ],
      ),
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'ollama-stream-group',
        displayName: 'Ollama stream group',
        members: const [
          LlmModelGroupMember(
            accountId: 'ollama-stream-account',
            localModelId: 'ollama-stream-model',
            upstreamModelId: 'llama3',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.value(
        utf8.encode(
          '{"message":{"role":"assistant","thinking":"private thought","content":"streamed"},"done":false}\n'
          '{"done":true,"prompt_eval_count":2,"eval_count":3}\n',
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
      groupId: 'ollama-stream-group',
      localModelId: 'ollama-stream-model',
      endpointType: 'ollama.chat',
    );

    final events = await provider.chatStream(const [
      {'role': 'user', 'content': 'hello'},
    ]).toList();

    expect(
      events
          .where((event) => !event.isReasoning)
          .map((event) => event.text)
          .join(),
      'streamed',
    );
    expect(
      events.where((event) => event.isReasoning).map((event) => event.text),
      ['private thought'],
    );
    expect(events.any((event) => event.usage != null), isTrue);
  });

  test(
    'Anthropic token counting uses its dedicated request contract',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'count-account',
          connectorType: 'claude',
          authType: 'api_key',
          displayName: 'Anthropic token counter',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'count-model',
              upstreamModelId: 'claude-count',
              displayName: 'Claude count model',
            ),
          ],
        ),
        secret: 'test-api-key',
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'count-group',
          displayName: 'Anthropic count group',
          members: [
            LlmModelGroupMember(
              accountId: 'count-account',
              localModelId: 'count-model',
              upstreamModelId: 'claude-count',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        responseBody: const {'input_tokens': 19},
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
        groupId: 'count-group',
        localModelId: 'count-model',
        endpointType: 'openai.chat_completions',
        selectedAccountId: 'count-account',
      );

      expect(
        await provider.countTokens(const [
          {'role': 'user', 'content': 'hello'},
        ]),
        19,
      );
      expect(connector.lastNativeFormat, 'count_tokens');
      expect(connector.requestBody, {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'hello'},
            ],
          },
        ],
        'model': 'claude-count',
      });
    },
  );

  test(
    'routed HTTP failures preserve response metadata for diagnostics',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'diagnostic-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Diagnostic account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'diagnostic-model',
              upstreamModelId: 'gpt-diagnostic',
              displayName: 'Diagnostic model',
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'diagnostic-group',
          displayName: 'Diagnostic group',
          members: const [
            LlmModelGroupMember(
              accountId: 'diagnostic-account',
              localModelId: 'diagnostic-model',
              upstreamModelId: 'gpt-diagnostic',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        firstRequestError: const _HttpExceptionWithHeaders(
          statusCode: 429,
          code: 'rate_limited',
          headers: {'retry-after': '3'},
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
        groupId: 'diagnostic-group',
        localModelId: 'diagnostic-model',
        endpointType: 'openai',
      );

      await expectLater(
        provider.chat(const [
          {'role': 'user', 'content': 'hello'},
        ]),
        throwsA(isA<AiGatewayRoutingException>()),
      );

      expect(provider.lastResponseStatusCode, 429);
      expect(provider.lastResponseHeaders, {
        'retry-after': ['3'],
      });
    },
  );

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
    'Responses response.failed stream event falls back within its group',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final suffix in ['a', 'b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: 'responses-$suffix',
            connectorType: 'openai-api',
            authType: 'api_key',
            displayName: 'Responses $suffix',
            status: LlmAccountStatus.ready,
            endpointConfig: const {'chatProtocol': 'openai.responses'},
            models: [
              LlmUpstreamModel(
                id: 'responses-model',
                upstreamModelId: 'responses-$suffix-upstream',
                displayName: 'Responses $suffix',
                capabilities: const {'streaming': true},
              ),
            ],
          ),
          secret: 'test-api-key',
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'responses-stream-fallback',
          displayName: 'Responses stream fallback',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'responses-a',
              localModelId: 'responses-model',
              upstreamModelId: 'responses-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'responses-b',
              localModelId: 'responses-model',
              upstreamModelId: 'responses-b-upstream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        streamBodies: [
          Stream<List<int>>.value(
            utf8.encode(
              'data: {"type":"response.failed","response":{"error":{"code":"rate_limit_exceeded"}}}\n\n',
            ),
          ),
          Stream<List<int>>.value(
            utf8.encode(
              'data: {"type":"response.output_text.delta","delta":"fallback"}\n\n'
              'data: {"type":"response.completed","response":{"usage":{"input_tokens":1,"output_tokens":1}}}\n\n',
            ),
          ),
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
        groupId: 'responses-stream-fallback',
        localModelId: 'responses-model',
        endpointType: 'openai',
      );

      final events = await provider.chatStream(const [
        {'role': 'user', 'content': 'hello'},
      ]).toList();

      expect(connector.requestedAccountIds, ['responses-a', 'responses-b']);
      expect(events.map((event) => event.text).join(), 'fallback');
    },
  );

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
    'cancelling chat stream stops its request without a caller token',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'cancel-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Cancel account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'cancel-model',
              upstreamModelId: 'gpt-cancel',
              displayName: 'Cancel model',
              capabilities: {'streaming': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'cancel-group',
          displayName: 'Cancel group',
          members: [
            LlmModelGroupMember(
              accountId: 'cancel-account',
              localModelId: 'cancel-model',
              upstreamModelId: 'gpt-cancel',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        streamBody: const Stream<List<int>>.empty(),
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
        groupId: 'cancel-group',
        localModelId: 'cancel-model',
        endpointType: 'openai',
      );

      final subscription = provider.chatStream(const [
        {'role': 'user', 'content': 'hello'},
      ]).listen((_) {});
      await connector.requestStarted.future;
      await subscription.cancel();

      expect(connector.lastCancelToken, isNotNull);
      expect(connector.lastCancelToken!.isCancelled, isTrue);
    },
  );

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
        throwsA(isA<AiGatewayExecutionException>()),
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
          throwsA(isA<AiGatewayExecutionException>()),
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

  test('streaming chat only selects members with streaming capability',
      () async {
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

  test(
    'Gemini generateContent-only models are not routed for streaming',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'gemini-nonstream-account',
          connectorType: 'gemini',
          authType: 'api_key',
          displayName: 'Gemini nonstream account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'gemini-nonstream-model',
              upstreamModelId: 'gemini-text-only',
              displayName: 'Gemini text only',
              capabilities: {
                'supportedGenerationMethods': ['generateContent'],
              },
            ),
          ],
        ),
        secret: 'test-api-key',
      );
      final group = LlmModelGroup(
        id: 'gemini-nonstream-group',
        displayName: 'Gemini nonstream group',
        members: const [
          LlmModelGroupMember(
            accountId: 'gemini-nonstream-account',
            localModelId: 'gemini-nonstream-model',
            upstreamModelId: 'gemini-text-only',
          ),
        ],
      );
      await accounts.saveModelGroup(group);
      final routing = LlmRoutingService(
        accountService: accounts,
        stateStore: LlmRoutingStateStore(preferences: preferences),
        concurrency: LlmConcurrencyReservations(),
      );

      await expectLater(
        routing.execute<String>(
          group: group,
          requestedModelId: 'gemini-nonstream-model',
          requiredCapabilities: const {'chat', 'streaming'},
          request: (candidate, progress) async => candidate.upstreamModelId,
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );
    },
  );

  test('Gemini streamed tool calls retain thought signatures', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'gemini-signature-account',
        connectorType: 'gemini',
        authType: 'api_key',
        displayName: 'Gemini signature account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'gemini-signature-model',
            upstreamModelId: 'gemini-2.5-pro',
            displayName: 'Gemini 2.5 Pro',
            capabilities: {'streaming': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'gemini-signature-group',
        displayName: 'Gemini signature group',
        members: const [
          LlmModelGroupMember(
            accountId: 'gemini-signature-account',
            localModelId: 'gemini-signature-model',
            upstreamModelId: 'gemini-2.5-pro',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.value(
        utf8.encode(
          'data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"lookup","args":{"q":"weather"}},"thoughtSignature":"opaque-signature"}]}}]}\n\n',
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
      groupId: 'gemini-signature-group',
      localModelId: 'gemini-signature-model',
      endpointType: 'google.gemini.generate_content',
    );

    final events = await provider.chatStream(const [
      {'role': 'user', 'content': 'Look up the weather.'},
    ]).toList();

    expect(
      events.single.toolCalls?.single['thoughtSignature'],
      'opaque-signature',
    );
  });

  test('Gemini preserves text and inline media order within one frame',
      () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'gemini-mixed-content-account',
        connectorType: 'gemini',
        authType: 'api_key',
        displayName: 'Gemini mixed content',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'gemini-mixed-content-model',
            upstreamModelId: 'gemini-2.5-pro',
            displayName: 'Gemini mixed content model',
            capabilities: {'streaming': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'gemini-mixed-content-group',
        displayName: 'Gemini mixed content',
        members: const [
          LlmModelGroupMember(
            accountId: 'gemini-mixed-content-account',
            localModelId: 'gemini-mixed-content-model',
            upstreamModelId: 'gemini-2.5-pro',
          ),
        ],
      ),
    );
    final bytes = Uint8List.fromList([2, 4, 6]);
    final frame = jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'before'},
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': base64Encode(bytes),
                },
              },
              {'text': 'after'},
            ],
          },
        },
      ],
    });
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.value(utf8.encode('data: $frame\n\n')),
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
      groupId: 'gemini-mixed-content-group',
      localModelId: 'gemini-mixed-content-model',
      endpointType: 'google.gemini.generate_content',
      saveMediaFile: (fileName, payload, {stableId}) async =>
          'attachments/$fileName',
    );

    final events = await provider.chatStream(const [
      {'role': 'user', 'content': 'Describe the image.'},
    ]).toList();

    final before = events.firstWhere((event) => event.text == 'before');
    final media = events.firstWhere(
      (event) => event.mediaAttachments?.isNotEmpty == true,
    );
    final after = events.firstWhere((event) => event.text == 'after');
    expect(before.contentOrder, lessThan(media.contentOrder!));
    expect(media.contentOrder, lessThan(after.contentOrder!));
  });

  test('Gemini stream emits fileData media references', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    await accounts.saveAccount(
      LlmAccount(
        id: 'gemini-file-reference-account',
        connectorType: 'gemini',
        authType: 'api_key',
        displayName: 'Gemini file reference',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'gemini-file-reference-model',
            upstreamModelId: 'gemini-2.5-pro',
            displayName: 'Gemini file reference model',
            capabilities: {'streaming': true},
          ),
        ],
      ),
      secret: 'test-api-key',
    );
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'gemini-file-reference-group',
        displayName: 'Gemini file reference',
        members: const [
          LlmModelGroupMember(
            accountId: 'gemini-file-reference-account',
            localModelId: 'gemini-file-reference-model',
            upstreamModelId: 'gemini-2.5-pro',
          ),
        ],
      ),
    );
    final frame = jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'primary answer'},
              {
                'fileData': {
                  'mimeType': 'video/mp4',
                  'fileUri': 'gs://bucket/generated-clip.mp4',
                },
              },
            ],
          },
        },
        {
          'index': 1,
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'alternative answer'},
              {
                'fileData': {
                  'mimeType': 'video/mp4',
                  'fileUri': 'gs://bucket/alternative-clip.mp4',
                },
              },
            ],
          },
        },
      ],
    });
    final connector = _FakeConnectorClient(
      accounts,
      streamBody: Stream<List<int>>.value(utf8.encode('data: $frame\n\n')),
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
      groupId: 'gemini-file-reference-group',
      localModelId: 'gemini-file-reference-model',
      endpointType: 'google.gemini.generate_content',
    );

    final events = await provider.chatStream(const [
      {'role': 'user', 'content': 'Create a clip.'},
    ]).toList();

    expect(
      events.map((event) => event.text).where((text) => text.isNotEmpty),
      ['primary answer'],
    );
    final attachment =
        events.expand((event) => event.mediaAttachments ?? const []).single;
    expect(attachment.fileType, 'video');
    expect(attachment.mimeType, 'video/mp4');
    expect(attachment.storagePath, 'gs://bucket/generated-clip.mp4');
    expect(
      attachment.extraFields['stroom.mediaReference'],
      'gs://bucket/generated-clip.mp4',
    );
  });

  test(
    'streaming chat skips malformed OpenAI frames and keeps valid output',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'malformed-stream-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Malformed stream account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'malformed-stream-model',
              upstreamModelId: 'gpt-malformed-stream',
              displayName: 'Malformed stream model',
              capabilities: {'streaming': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'malformed-stream-group',
          displayName: 'Malformed stream group',
          members: const [
            LlmModelGroupMember(
              accountId: 'malformed-stream-account',
              localModelId: 'malformed-stream-model',
              upstreamModelId: 'gpt-malformed-stream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        streamBody: Stream<List<int>>.value(
          utf8.encode(
            'data: {malformed json}\n\n'
            'data: {"choices":[{"delta":{"content":"survives"},"finish_reason":null}]}\n\n'
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
        groupId: 'malformed-stream-group',
        localModelId: 'malformed-stream-model',
        endpointType: 'openai',
      );

      final events = await provider.chatStream(const [
        {'role': 'user', 'content': 'hello'},
      ]).toList();

      expect(events.map((event) => event.text).join(), 'survives');
    },
  );

  for (final (
        contentType,
        connectorType,
        endpointType,
        contentBlock,
        requiredCapability,
      ) in [
    (
      'input_image',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'input_image',
        'image_url': 'https://example.test/input.png',
      },
      'vision',
    ),
    (
      'output_image',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'output_image',
        'image_url': 'https://example.test/output.png',
      },
      'vision',
    ),
    (
      'video_url',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'video_url',
        'video_url': {'url': 'https://example.test/video.mp4'},
      },
      'vision',
    ),
    (
      'file',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'file',
        'file': {
          'filename': 'report.pdf',
          'file_data': 'data:application/pdf;base64,cGRm',
        },
      },
      'vision',
    ),
    (
      'document',
      'claude',
      'anthropic',
      <String, dynamic>{
        'type': 'document',
        'source': {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': 'cGRm',
        },
      },
      'vision',
    ),
    (
      'output_audio',
      'openai-compatibility',
      'openai',
      <String, dynamic>{
        'type': 'output_audio',
        'output_audio': {'data': 'AQID', 'format': 'pcm16'},
      },
      'audio',
    ),
  ]) {
    test(
      '$contentType content routes to a $requiredCapability-capable member',
      () async {
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
                  capabilities: {requiredCapability: supportsVision},
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
      },
    );
  }

  test('records response cost alongside connector token observations',
      () async {
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
      final envelope = jsonDecode(
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
      ) as Map;
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

      final envelope = jsonDecode(
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
      ) as Map;
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
          isA<AiGatewayRoutingException>().having(
            (error) => error.decisions.map((decision) => decision.reason),
            'decision reasons',
            contains('request_rateLimited'),
          ),
        ),
      );

      final envelope = jsonDecode(
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
      ) as Map;
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
    this.responseHeaders = const {},
    this.streamBody,
    this.streamBodies,
    LlmConnectorObservation? observation,
    this.completionObservation,
    this.failFirstRequestBeforeSend = false,
    this.firstRequestError,
  })  : observation = observation ?? LlmConnectorObservation(),
        super(accountService: accountService);

  final Object? responseBody;
  final List<Object?>? responseBodies;
  final Map<String, List<String>> responseHeaders;
  final Object? streamBody;
  final List<Object?>? streamBodies;
  final LlmConnectorObservation observation;
  final Future<LlmConnectorObservation>? completionObservation;
  final bool failFirstRequestBeforeSend;
  final LlmConnectorHttpException? firstRequestError;
  Map<String, dynamic>? requestBody;
  final requestedAccountIds = <String>[];
  final requestedModelIds = <String>[];
  final requestStarted = Completer<void>();
  CancelToken? lastCancelToken;
  String? lastNativeFormat;

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
    requestedModelIds.add(modelId);
    lastNativeFormat = nativeFormat;
    lastCancelToken = cancelToken;
    if (!requestStarted.isCompleted) requestStarted.complete();
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
      headers: responseHeaders,
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
