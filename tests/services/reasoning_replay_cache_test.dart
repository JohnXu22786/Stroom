import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_protocol_bridges.dart';
import 'package:stroom/services/reasoning_replay_cache.dart';

void main() {
  final sentMessages = <Map<String, dynamic>>[
    {'role': 'user', 'content': 'question'},
  ];
  final followUp = <Map<String, dynamic>>[
    ...sentMessages,
    {
      'role': 'assistant',
      'content': 'answer',
      'reasoning_content': 'unscoped client copy',
    },
    {'role': 'user', 'content': 'follow-up'},
  ];

  ReasoningReplayCache createCache({
    int capacity = 128,
    Duration ttl = ReasoningReplayCache.defaultTtl,
    DateTime Function()? clock,
  }) => ReasoningReplayCache(capacity: capacity, ttl: ttl, clock: clock);

  List<Map<String, dynamic>> restore(
    ReasoningReplayCache cache,
    List<Map<String, dynamic>> messages, {
    String accountId = 'account-a',
    String providerId = 'openai-compatibility',
    String executorId = 'gateway-executor',
    String modelId = 'upstream-model',
    String sessionId = 'conversation-a',
    String protocolId = 'openai.chat_completions',
  }) => cache.restore(
    accountId: accountId,
    providerId: providerId,
    executorId: executorId,
    modelId: modelId,
    sessionId: sessionId,
    protocolId: protocolId,
    requestMessages: messages,
  );

  void remember(
    ReasoningReplayCache cache, {
    String reasoning = 'reasoning returned by upstream',
    Map<String, String> toolSignatures = const {},
    Map<String, dynamic> assistantTurn = const {
      'role': 'assistant',
      'content': 'answer',
    },
  }) {
    cache.remember(
      accountId: 'account-a',
      providerId: 'openai-compatibility',
      executorId: 'gateway-executor',
      modelId: 'upstream-model',
      sessionId: 'conversation-a',
      protocolId: 'openai.chat_completions',
      requestMessages: sentMessages,
      returnedAssistantTurn: assistantTurn,
      returnedReasoning: reasoning,
      returnedToolSignatures: toolSignatures,
    );
  }

  test('restores returned reasoning for the matching transcript prefix', () {
    final cache = createCache();
    remember(cache);

    final restored = restore(cache, followUp);

    expect(restored[1]['reasoning_content'], 'reasoning returned by upstream');
    expect(followUp[1]['reasoning_content'], 'unscoped client copy');
  });

  test('preserves exact upstream reasoning whitespace', () {
    final cache = createCache();
    const sourceReasoning = ' \nreturned thought\n ';
    remember(cache, reasoning: sourceReasoning);

    final restored = restore(cache, followUp);

    expect(restored[1]['reasoning_content'], sourceReasoning);
  });

  test('does not replay source data after the assistant turn was edited', () {
    final cache = createCache();
    remember(cache);
    final editedTurn = <Map<String, dynamic>>[
      ...sentMessages,
      {'role': 'assistant', 'content': 'edited answer'},
      {'role': 'user', 'content': 'follow-up'},
    ];

    final restored = restore(cache, editedTurn);

    expect(restored[1].containsKey('reasoning_content'), isFalse);
    expect(editedTurn[1]['content'], 'edited answer');
  });

  test(
    'cache misses across account, provider, model, session, and protocol',
    () {
      final cache = createCache();
      remember(cache);

      for (final scope in [
        {'accountId': 'account-b'},
        {'providerId': 'another-provider'},
        {'executorId': 'another-executor'},
        {'modelId': 'another-model'},
        {'sessionId': 'another-conversation'},
        {'protocolId': 'openai.responses'},
      ]) {
        final restored = cache.restore(
          accountId: scope['accountId'] ?? 'account-a',
          providerId: scope['providerId'] ?? 'openai-compatibility',
          executorId: scope['executorId'] ?? 'gateway-executor',
          modelId: scope['modelId'] ?? 'upstream-model',
          sessionId: scope['sessionId'] ?? 'conversation-a',
          protocolId: scope['protocolId'] ?? 'openai.chat_completions',
          requestMessages: followUp,
        );
        expect(restored[1].containsKey('reasoning_content'), isFalse);
        expect(restored[1].containsKey('stroom.reasoningSignature'), isFalse);
        expect(restored[1].containsKey('stroom.responsesOutputItems'), isFalse);
      }
      expect(
        restore(cache, [
          {'role': 'user', 'content': 'different transcript'},
          ...followUp.skip(1),
        ])[1]['reasoning_content'],
        isNull,
      );
      expect(followUp[1]['reasoning_content'], 'unscoped client copy');
    },
  );

  test('a cache miss omits unscoped reasoning from the outbound copy', () {
    final cache = createCache();
    final transcript = <Map<String, dynamic>>[
      ...sentMessages,
      {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'visible answer'},
          {'type': 'reasoning', 'text': 'unscoped local reasoning'},
        ],
        'reasoning_content': 'unscoped local reasoning',
      },
      {'role': 'user', 'content': 'continue'},
    ];

    final outbound = restore(cache, transcript);

    expect(outbound[1]['content'], [
      {'type': 'text', 'text': 'visible answer'},
    ]);
    expect(outbound[1].containsKey('reasoning_content'), isFalse);
    expect(transcript[1]['content'], [
      {'type': 'text', 'text': 'visible answer'},
      {'type': 'reasoning', 'text': 'unscoped local reasoning'},
    ]);
  });

  test('restores opaque tool signatures only from matching source scope', () {
    final cache = createCache();
    remember(
      cache,
      reasoning: '',
      toolSignatures: {
        'call-1': 'sig-source',
        '__thinking__': 'thinking-source-signature',
      },
      assistantTurn: {
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': 'source-returned thought'},
        ],
        'tool_calls': [
          {
            'function': {'name': 'lookup', 'arguments': '{}'},
          },
        ],
      },
    );
    final messages = <Map<String, dynamic>>[
      ...sentMessages,
      {
        'role': 'assistant',
        'content': [
          {
            'type': 'thinking',
            'thinking': 'source-returned thought',
            'signature': 'untrusted-copied-signature',
          },
        ],
        'tool_calls': [
          {
            'id': 'call-1',
            'thoughtSignature': 'untrusted-copied-signature',
            'function': {'name': 'lookup', 'arguments': '{}'},
          },
        ],
      },
      {'role': 'user', 'content': 'continue'},
    ];

    final matched = restore(cache, messages);
    expect(
      (matched[1]['tool_calls'] as List).single['thoughtSignature'],
      'sig-source',
    );
    expect(
      matched[1]['stroom.reasoningSignature'],
      'thinking-source-signature',
    );
    expect(matched[1]['content'], isEmpty);
    final mismatched = restore(cache, messages, accountId: 'account-b');
    expect(
      (mismatched[1]['tool_calls'] as List).single.containsKey(
        'thoughtSignature',
      ),
      isFalse,
    );
    expect(mismatched[1].containsKey('stroom.reasoningSignature'), isFalse);
  });

  test('restores Gemini thought signatures with source reasoning', () {
    final cache = createCache();
    cache.remember(
      accountId: 'account-a',
      providerId: 'openai-compatibility',
      executorId: 'gateway-executor',
      modelId: 'upstream-model',
      sessionId: 'conversation-a',
      protocolId: 'google.gemini.generate_content',
      requestMessages: sentMessages,
      returnedAssistantTurn: {'role': 'assistant', 'content': 'answer'},
      returnedReasoning: 'source thought',
      returnedToolSignatures: {'__thinking__': 'source thought signature'},
    );
    final restored = restore(
      cache,
      followUp,
      protocolId: 'google.gemini.generate_content',
    );
    expect(
      restored[1]['stroom.reasoningSignature'],
      'source thought signature',
    );

    final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom(
      restored[1],
    );
    final request = AiGatewayProtocolBridges.buildRequest(
      'google.gemini.generate_content',
      AiGatewayProtocolRequest(modelId: 'upstream-model', messages: [neutral]),
    );
    final reasoningPart = (request!.body['contents'] as List)
        .expand((message) => (message['parts'] as List).whereType<Map>())
        .firstWhere((part) => part['thought'] == true);
    expect(reasoningPart['thoughtSignature'], 'source thought signature');
  });

  test('restores a Gemini thought signature without thought text', () {
    final cache = createCache();
    cache.remember(
      accountId: 'account-a',
      providerId: 'openai-compatibility',
      executorId: 'gateway-executor',
      modelId: 'upstream-model',
      sessionId: 'conversation-a',
      protocolId: 'google.gemini.generate_content',
      requestMessages: sentMessages,
      returnedAssistantTurn: {'role': 'assistant', 'content': 'answer'},
      returnedToolSignatures: {'__thinking__': 'signature-only-thought'},
    );
    final restored = restore(
      cache,
      followUp,
      protocolId: 'google.gemini.generate_content',
    );
    final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom(
      restored[1],
    );
    final request = AiGatewayProtocolBridges.buildRequest(
      'google.gemini.generate_content',
      AiGatewayProtocolRequest(modelId: 'upstream-model', messages: [neutral]),
    );
    final reasoningPart = (request!.body['contents'] as List)
        .expand((message) => (message['parts'] as List).whereType<Map>())
        .firstWhere((part) => part['thought'] == true);
    expect(reasoningPart['text'], '');
    expect(reasoningPart['thoughtSignature'], 'signature-only-thought');
  });

  test(
    'restores Gemini function-call signatures by normalized call content',
    () {
      final cache = createCache();
      cache.remember(
        accountId: 'account-a',
        providerId: 'openai-compatibility',
        executorId: 'gateway-executor',
        modelId: 'upstream-model',
        sessionId: 'conversation-a',
        protocolId: 'google.gemini.generate_content',
        requestMessages: sentMessages,
        returnedAssistantTurn: {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'function': {
                'name': 'lookup',
                'arguments': {'q': 'weather'},
              },
            },
          ],
        },
        returnedToolSignatures: {
          ReasoningReplayCache.functionCallSignatureKey(
            name: 'lookup',
            arguments: {'q': 'weather'},
          ): 'function-call-signature',
        },
      );
      final messages = <Map<String, dynamic>>[
        ...sentMessages,
        {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'id': 'call-1',
              'function': {'name': 'lookup', 'arguments': '{"q":"weather"}'},
              'thoughtSignature': 'untrusted-signature',
            },
          ],
        },
        {'role': 'user', 'content': 'continue'},
      ];

      final restored = restore(
        cache,
        messages,
        protocolId: 'google.gemini.generate_content',
      );

      expect(
        (restored[1]['tool_calls'] as List).single['thoughtSignature'],
        'function-call-signature',
      );
    },
  );

  test('restores Responses reasoning items only in the matching scope', () {
    final cache = createCache();
    final returnedItems = <Map<String, dynamic>>[
      {
        'type': 'reasoning',
        'id': 'rs_returned_1',
        'encrypted_content': 'opaque-source-item',
        'summary': [
          {'type': 'summary_text', 'text': 'source returned summary'},
        ],
      },
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'source message'},
        ],
      },
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'second source message'},
        ],
      },
    ];
    cache.remember(
      accountId: 'account-a',
      providerId: 'openai-compatibility',
      executorId: 'gateway-executor',
      modelId: 'upstream-model',
      sessionId: 'conversation-a',
      protocolId: 'openai.responses',
      requestMessages: sentMessages,
      returnedAssistantTurn: {
        'role': 'assistant',
        'content': 'source messagesecond source message',
      },
      returnedReasoning: 'source returned summary',
      returnedResponsesOutputItems: returnedItems,
    );

    final responsesFollowUp = <Map<String, dynamic>>[
      ...sentMessages,
      {'role': 'assistant', 'content': 'source messagesecond source message'},
      {'role': 'user', 'content': 'follow-up'},
    ];
    final restored = restore(
      cache,
      responsesFollowUp,
      protocolId: 'openai.responses',
    );

    expect(restored[1]['stroom.responsesOutputItems'], returnedItems);
    final replayedMessage = AiGatewayProtocolBridges.openAiChatCompletions
        .toStroom(restored[1]);
    final request = AiGatewayProtocolBridges.buildRequest(
      'openai.responses',
      AiGatewayProtocolRequest(
        modelId: 'upstream-model',
        messages: [replayedMessage],
      ),
    );
    final reasoningItem = (request!.body['input'] as List)
        .whereType<Map>()
        .firstWhere((item) => item['type'] == 'reasoning');
    expect(reasoningItem['id'], 'rs_returned_1');
    expect(reasoningItem['encrypted_content'], 'opaque-source-item');
    final input = request.body['input'] as List;
    expect(input, returnedItems);
    final wrongProtocol = restore(cache, responsesFollowUp);
    expect(
      wrongProtocol[1].containsKey('stroom.responsesOutputItems'),
      isFalse,
    );
    final editedResponsesTurn = <Map<String, dynamic>>[
      ...sentMessages,
      {'role': 'assistant', 'content': 'edited response'},
      {'role': 'user', 'content': 'follow-up'},
    ];
    final staleReplay = restore(
      cache,
      editedResponsesTurn,
      protocolId: 'openai.responses',
    );
    expect(staleReplay[1].containsKey('stroom.responsesOutputItems'), isFalse);
    expect(staleReplay[1].containsKey('reasoning_content'), isFalse);
  });

  test('expires entries and evicts oldest entries at capacity', () {
    var now = DateTime.utc(2026, 1, 1);
    final cache = createCache(
      capacity: 1,
      ttl: const Duration(minutes: 10),
      clock: () => now,
    );
    remember(cache);
    cache.remember(
      accountId: 'account-a',
      providerId: 'openai-compatibility',
      executorId: 'gateway-executor',
      modelId: 'upstream-model',
      sessionId: 'conversation-b',
      protocolId: 'openai.chat_completions',
      requestMessages: sentMessages,
      returnedAssistantTurn: {'role': 'assistant', 'content': 'answer'},
      returnedReasoning: 'newer returned reasoning',
    );
    expect(cache.length, 1);
    expect(
      restore(cache, followUp)[1].containsKey('reasoning_content'),
      isFalse,
    );
    final newerHistory = [
      ...sentMessages,
      {'role': 'assistant', 'content': 'answer'},
    ];
    expect(
      restore(
        cache,
        newerHistory,
        sessionId: 'conversation-b',
      )[1]['reasoning_content'],
      'newer returned reasoning',
    );

    now = now.add(const Duration(minutes: 11));
    expect(
      restore(
        cache,
        newerHistory,
        sessionId: 'conversation-b',
      )[1]['reasoning_content'],
      isNull,
    );
    expect(cache.length, 0);
  });
}
