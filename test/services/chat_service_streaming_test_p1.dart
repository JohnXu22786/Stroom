part of 'chat_service_streaming_test.dart';

void chatServiceStreamingGroup1() {
  // ====================================================================
  // From chat_service_reasoning_test.dart
  // ====================================================================

  group('Reasoning effort data flow', () {
    late CapturingChatProvider provider;
    late ModelConfig modelConfig;

    setUp(() {
      provider = CapturingChatProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        typeConfig: {
          'context': 4096,
          'temperature': 0.7,
        },
      );
    });

    test('sendStream passes reasoning=true and default reasoningEffort',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: true,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });

    test('sendStream passes reasoning=false to provider', () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: false,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isFalse);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });

    test('sendStream passes custom reasoningEffort value', () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStream(
        'Hello',
        history: [],
        reasoning: true,
        reasoningEffort: 'high',
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'high');
    });

    test(
        'ChatService.sendStreamWithTools chains reasoning and effort correctly',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hello',
        history: [],
        reasoning: true,
        reasoningEffort: 'low',
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'low');
    });

    test('ChatService.sendStreamWithTools passes default reasoningEffort',
        () async {
      final service = ChatService(provider: provider, modelConfig: modelConfig);

      final events = <dynamic>[];
      await for (final event in service.sendStreamWithTools(
        'Hello',
        history: [],
        reasoning: true,
      )) {
        events.add(event);
      }

      expect(provider.capturedBody, isNotNull);
      expect(provider.capturedBody!['reasoning'], isTrue);
      expect(provider.capturedBody!['reasoningEffort'], 'medium');
    });
  });

  // ====================================================================
  // From chat_service_parse_value_test.dart
  // ====================================================================

  group('ChatService.parseJsonValue', () {
    test('parses valid JSON object', () {
      final result = ChatService.parseJsonValue('{"key": "value", "num": 42}');
      expect(result, isA<Map>());
      expect((result as Map)['key'], equals('value'));
      expect(result['num'], equals(42));
    });

    test('parses valid JSON array', () {
      final result = ChatService.parseJsonValue('[1, 2, 3]');
      expect(result, isA<List>());
      expect((result as List).length, equals(3));
    });

    test('parses JSON number', () {
      final result = ChatService.parseJsonValue('42');
      expect(result, equals(42));
    });

    test('parses JSON boolean', () {
      expect(ChatService.parseJsonValue('true'), isTrue);
      expect(ChatService.parseJsonValue('false'), isFalse);
    });

    test('throws FormatException for invalid JSON (no raw string fallback)',
        () {
      // Regression: the previous behavior returned the raw string and let it
      // get re-serialized as a quoted string in the API request body. Now we
      // throw so the param can be cleanly omitted and the user can see the
      // underlying error.
      expect(
        () => ChatService.parseJsonValue('not-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns null for empty string (treated as no-op)', () {
      final result = ChatService.parseJsonValue('');
      expect(result, isNull,
          reason: 'Empty JSON values should be treated as a no-op.');
    });
  });

  group('ChatService.parseReasoningValue', () {
    test('string type returns the value as-is', () {
      expect(
          ChatService.parseReasoningValue('hello', 'string'), equals('hello'));
    });

    test('number type parses decimal string to double', () {
      expect(ChatService.parseReasoningValue('3.14', 'number'),
          closeTo(3.14, 0.001));
    });

    test('number type parses integer string to double', () {
      expect(ChatService.parseReasoningValue('42', 'number'), equals(42.0));
    });

    test('number type defaults to 0.0 for invalid', () {
      expect(ChatService.parseReasoningValue('abc', 'number'), equals(0.0));
    });

    test('boolean type parses "true" to true', () {
      expect(ChatService.parseReasoningValue('true', 'boolean'), isTrue);
    });

    test('boolean type parses "false" to false', () {
      expect(ChatService.parseReasoningValue('false', 'boolean'), isFalse);
    });

    test('boolean type is case-insensitive', () {
      expect(ChatService.parseReasoningValue('True', 'boolean'), isTrue);
      expect(ChatService.parseReasoningValue('TRUE', 'boolean'), isTrue);
    });

    test('boolean type defaults to false for unknown', () {
      expect(ChatService.parseReasoningValue('maybe', 'boolean'), isFalse);
    });

    test('json type parses valid JSON', () {
      final result = ChatService.parseReasoningValue('{"key": "val"}', 'json');
      expect(result, isA<Map>());
      expect((result as Map)['key'], equals('val'));
    });

    test('json type throws FormatException for invalid JSON', () {
      // Regression: parseReasoningValue delegates to parseJsonValue for the
      // 'json' type. The new behavior is to propagate the FormatException.
      // Callers (_buildExtraParams) catch and log it; the param is dropped
      // from the request body via _stripOmitted.
      expect(
        () => ChatService.parseReasoningValue('not-json', 'json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('default type (string) returns value as-is', () {
      expect(ChatService.parseReasoningValue('anything', 'unknown_type'),
          equals('anything'));
    });
  });

  // ====================================================================
  // From chat_service_builtin_tools_test.dart
  // ====================================================================

  group('ChatService - Built-in tools listing', () {
    test('getRegisteredToolDefinitions returns all registered tools', () {
      // Register test tools
      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool_1',
          description: 'Test tool 1',
          parameters: {'type': 'object'},
        ),
        (args) => 'result_1',
      );

      ChatService.registerTool(
        const ToolDefinition(
          name: 'test_tool_2',
          description: 'Test tool 2',
          parameters: {'type': 'object'},
        ),
        (args) => 'result_2',
      );

      final defs = ChatService.getRegisteredToolDefinitions();
      final names = defs.map((d) => d.name).toSet();

      // Should contain both test tools (calculator is also registered by default)
      expect(names, contains('test_tool_1'));
      expect(names, contains('test_tool_2'));
    });
  });
}
