import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

// ====================================================================
// Helper: A mock provider that simulates DeepSeek/OpenRouter responses
// with tool calls in the correct format.
// ====================================================================
class _MockToolCallProvider extends BaseChatProvider {
  final List<List<Map<String, dynamic>>> _toolCallStreams;
  int _callCount = 0;

  /// Stores the messages received in the last chatStream call for inspection.
  List<Map<String, dynamic>>? lastStreamMessages;

  _MockToolCallProvider(this._toolCallStreams);

  int get callCount => _callCount;

  @override
  String get name => 'MockToolProvider';

  @override
  List<String> get supportedModelIds => [];

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  }) async* {
    _callCount++;
    lastStreamMessages = messages;

    if (_callCount <= _toolCallStreams.length) {
      // Yield the tool call events for this round
      final toolCalls = _toolCallStreams[_callCount - 1];
      yield AIStreamEvent('', toolCalls: toolCalls);
    } else {
      // Final round: yield text
      yield AIStreamEvent('The weather in Hangzhou is 24°C and sunny.');
    }
  }

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  }) async {
    return 'Mock response';
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'deepseek-v4-pro',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

// ====================================================================
// Helper: Mock model config
// ====================================================================
ModelConfig _createMockModelConfig() {
  return ModelConfig(
    name: 'DeepSeek V4 Pro',
    modelId: 'deepseek-v4-pro',
    typeConfig: {
      'context': 65536,
      'maxTokens': 4096,
      'temperature': 0.7,
    },
  );
}

void main() {
  group('ChatService.sendStreamWithTools - tool chain format compliance', () {
    late ChatService service;
    late _MockToolCallProvider mockProvider;

    setUp(() {
      mockProvider = _MockToolCallProvider([]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('tool call chain produces ToolCallStart, ToolCallComplete, then TextEvent',
        () async {
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_weather_001',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      // Register a tool handler
      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_weather',
          description: 'Get weather',
          parameters: {
            'type': 'object',
            'properties': {
              'location': {'type': 'string'},
            },
            'required': ['location'],
          },
        ),
        (args) => '24°C',
      );

      final events = <ChatEvent>[];
      final history = [
        ChatMessage(role: 'user', content: 'What is the weather in Hangzhou?'),
      ];

      await service
          .sendStreamWithTools(
            'What is the weather in Hangzhou?',
            history: history,
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      // Expect: ToolCallStartEvent, ToolCallCompleteEvent, TextEvent
      expect(events.length, equals(3));

      // Verify event sequence and types
      expect(events[0], isA<ToolCallStartEvent>());
      expect(events[1], isA<ToolCallCompleteEvent>());
      expect(events[2], isA<TextEvent>());

      // Verify tool call start event
      final toolStart = events[0] as ToolCallStartEvent;
      expect(toolStart.toolCall.id, equals('call_weather_001'));
      expect(toolStart.toolCall.name, equals('get_weather'));
      expect(toolStart.toolCall.arguments, equals({'location': 'Hangzhou'}));
      expect(toolStart.toolCall.status, equals(ToolCallStatus.running));

      // Verify tool call complete event
      final toolComplete = events[1] as ToolCallCompleteEvent;
      expect(toolComplete.toolCallId, equals('call_weather_001'));
      expect(toolComplete.result, equals('24°C'));

      // Verify final text event
      final textEvent = events[2] as TextEvent;
      expect(textEvent.text, contains('24°C'));
    });

    test('tool call chain respects loop protection (max 10 iterations)',
        () async {
      mockProvider = _MockToolCallProvider(
        List.generate(15, (i) => [
          {
            'id': 'call_loop_$i',
            'type': 'function',
            'function': {
              'name': 'loop_tool',
              'arguments': '{"iteration": $i}',
            },
          },
        ]),
      );
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'Test tool for loop protection',
          parameters: {
            'type': 'object',
            'properties': {
              'iteration': {'type': 'integer'},
            },
            'required': ['iteration'],
          },
        ),
        (args) => 'result',
      );

      final events = <ChatEvent>[];
      final history = [
        ChatMessage(role: 'user', content: 'Test loop protection'),
      ];

      await service
          .sendStreamWithTools(
            'Test loop protection',
            history: history,
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      // Should have at most 10 tool call rounds
      final toolStartEvents = events.whereType<ToolCallStartEvent>().toList();
      expect(toolStartEvents.length, lessThanOrEqualTo(10));
      // Should have at least 1 tool call since mock always returns tool calls
      expect(toolStartEvents.length, greaterThan(0));
    });

    test(
        'assistant message with tool_calls has content:null per DeepSeek spec',
        () async {
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_test_001',
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool',
          description: 'Test tool',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      // The second chatStream call has the assistant+tool messages appended.
      // lastStreamMessages is set by the mock on the LAST call (the text response call).
      // The tool messages were appended to messages before the second call.
      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      // Find the assistant message with tool_calls
      final assistantWithToolCalls = lastMessages!.where((m) =>
          m['role'] == 'assistant' && m.containsKey('tool_calls'));
      expect(assistantWithToolCalls, isNotEmpty,
          reason: 'Should have at least one assistant message with tool_calls');

      for (final msg in assistantWithToolCalls) {
        expect(msg['content'], isNull,
            reason:
                'DeepSeek spec: assistant message with tool_calls must have content: null');
        expect(msg['tool_calls'], isA<List>());
      }

      // Find the tool result messages
      final toolResults = lastMessages.where((m) => m['role'] == 'tool');
      expect(toolResults, isNotEmpty,
          reason: 'Should have at least one tool result message');
      for (final msg in toolResults) {
        expect(msg.containsKey('tool_call_id'), isTrue,
            reason: 'DeepSeek spec: tool message must have tool_call_id');
        expect(msg.containsKey('content'), isTrue,
            reason: 'DeepSeek spec: tool message must have content');
      }
    });

    test('multiple parallel tool calls produce ONE assistant message per DeepSeek spec', () async {
      // DeepSeek spec: ALL tool_calls in a single assistant message,
      // not separate assistant messages per tool call.
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_weather_001',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
          {
            'id': 'call_time_001',
            'type': 'function',
            'function': {
              'name': 'get_time',
              'arguments': '{"timezone": "UTC+8"}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_weather',
          description: 'Get weather',
          parameters: {'type': 'object'},
        ),
        (args) => '24°C',
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'get_time',
          description: 'Get time',
          parameters: {'type': 'object'},
        ),
        (args) => '12:00',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      // The last stream call has the assistant + tool results appended
      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      // Should have exactly ONE assistant message with tool_calls,
      // not separate messages per tool call
      final assistantWithToolCalls = lastMessages!.where((m) =>
          m['role'] == 'assistant' && m.containsKey('tool_calls'));
      expect(assistantWithToolCalls.length, equals(1),
          reason:
              'DeepSeek spec: ALL tool_calls must be in ONE assistant message');

      final oneAssistant = assistantWithToolCalls.first;
      final toolCallsList = oneAssistant['tool_calls'] as List;
      expect(toolCallsList.length, equals(2),
          reason: 'All 2 tool calls should be in a single assistant message');

      // Verify both tool calls are present
      final ids = toolCallsList.map((tc) => tc['id'] as String).toSet();
      expect(ids, contains('call_weather_001'));
      expect(ids, contains('call_time_001'));

      // Should have exactly 2 tool result messages
      final toolResults = lastMessages.where((m) => m['role'] == 'tool');
      expect(toolResults.length, equals(2));
    });

    test('assistant message with tool_calls has content:null per OpenAI-compatible spec', () async {
      // OpenAI-compatible spec (followed by DeepSeek, OpenRouter):
      // assistant message with tool_calls has content: null
      // and tool_calls: [{id, type: "function", function: {name, arguments}}]
      mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_test_001',
            'type': 'function',
            'function': {
              'name': 'test_tool',
              'arguments': '{}',
            },
          },
        ],
      ]);
      service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool',
          description: 'Test tool',
          parameters: {'type': 'object'},
        ),
        (args) => 'done',
      );

      await service
          .sendStreamWithTools(
            'test',
            history: [ChatMessage(role: 'user', content: 'test')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .drain();

      final lastMessages = mockProvider.lastStreamMessages;
      expect(lastMessages, isNotNull);

      final assistantWithToolCalls = lastMessages!.where((m) =>
          m['role'] == 'assistant' && m.containsKey('tool_calls'));

      // Each assistant message should have content: null when tool_calls present
      for (final msg in assistantWithToolCalls) {
        expect(msg['content'], isNull,
            reason:
                'OpenAI-compatible spec: assistant message with tool_calls has content: null');
        expect(msg['tool_calls'], isA<List>());
      }
    });
  });

  group('Tool definition format per DeepSeek spec', () {
    test('tool definition JSON follows DeepSeek non-thinking mode spec', () {
      final toolDef = ToolDefinition(
        name: 'get_weather',
        description:
            'Get weather of a location, the user should supply a location first.',
        parameters: {
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'The city and state, e.g. San Francisco, CA',
            },
          },
          'required': ['location'],
        },
      );

      final json = toolDef.toJson();

      expect(json, containsPair('type', 'function'));
      expect(json['function'], containsPair('name', 'get_weather'));
      expect(json['function'], containsPair('description', isA<String>()));
      expect(json['function'], containsPair('parameters', isA<Map>()));
    });
  });

  group('ChatService - tool message assembly per spec', () {
    test('tool_call_id in tool result matches the assistant tool call id', () {
      const toolCallId = 'call_weather_001';

      final assistantMsg = <String, dynamic>{
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': toolCallId,
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
        ],
      };

      final toolResultMsg = <String, dynamic>{
        'role': 'tool',
        'tool_call_id': toolCallId,
        'content': '24℃',
      };

      final assistantToolCallId =
          (assistantMsg['tool_calls'] as List).first['id'] as String;
      expect(assistantToolCallId, equals(toolCallId));
      expect(toolResultMsg['tool_call_id'], equals(toolCallId));
      expect(assistantToolCallId, equals(toolResultMsg['tool_call_id']));
    });

    test('multiple tool calls each have matching tool_call_id', () {
      final assistantMsg = <String, dynamic>{
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_weather_001',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"location": "Hangzhou"}',
            },
          },
          {
            'id': 'call_time_001',
            'type': 'function',
            'function': {
              'name': 'get_time',
              'arguments': '{"timezone": "UTC+8"}',
            },
          },
        ],
      };

      final toolResults = [
        {'role': 'tool', 'tool_call_id': 'call_weather_001', 'content': '24℃'},
        {'role': 'tool', 'tool_call_id': 'call_time_001', 'content': '12:00'},
      ];

      for (final tc in assistantMsg['tool_calls'] as List) {
        final id = tc['id'] as String;
        final matchingResult =
            toolResults.where((r) => r['tool_call_id'] == id).toList();
        expect(matchingResult.length, equals(1),
            reason: 'Each tool call $id should have exactly one matching result');
      }
    });
  });
}
