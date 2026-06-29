import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/providers/chat_api_shared.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:dio/dio.dart';
import 'package:stroom/models/ai_stream_event.dart';

/// Mock provider that captures the API messages for inspection.
class _MessageCaptureProvider extends BaseChatProvider {
  List<Map<String, dynamic>>? capturedMessages;

  @override
  String get name => 'MessageCapture';

  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

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
    capturedMessages = messages;
    return 'test response';
  }

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
    capturedMessages = messages;
    yield AIStreamEvent('test response');
  }
}

void main() {
  group('ChatService system prompt', () {
    late _MessageCaptureProvider provider;
    late ModelConfig modelConfig;
    late ChatService service;

    setUp(() {
      provider = _MessageCaptureProvider();
      modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        typeConfig: {},
        customParams: [],
        reasoningParams: [],
      );
      service = ChatService(provider: provider, modelConfig: modelConfig);
    });

    test(
      'system prompt is prepended when set via setAssistantPrompt',
      () async {
        // Set the assistant prompt
        service.setAssistantPrompt(
          'You are a helpful assistant. Speak Chinese.',
        );

        final history = <ChatMessage>[
          ChatMessage(role: 'user', content: 'Hello'),
        ];

        final stream = service.sendStream('Hello', history: history);
        await stream.toList();

        final messages = provider.capturedMessages;
        expect(messages, isNotNull);
        expect(messages!.length, greaterThanOrEqualTo(2));

        // First message should be the system prompt
        expect(messages[0]['role'], 'system');
        expect(
          messages[0]['content'],
          'You are a helpful assistant. Speak Chinese.',
        );
      },
    );

    test('user message comes after system prompt', () async {
      service.setAssistantPrompt('Be helpful.');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'What is Flutter?'),
      ];

      final stream = service.sendStream('What is Flutter?', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 2);
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      expect(messages[1]['content'], 'What is Flutter?');
    });

    test('system prompt not added when empty', () async {
      service.setAssistantPrompt('');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStream('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);
      expect(messages[0]['role'], 'user');
    });

    test('system prompt not added when null', () async {
      service.setAssistantPrompt(null);

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStream('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 1);
      expect(messages[0]['role'], 'user');
    });

    test('system prompt is first message with tool calls flow', () async {
      service.setAssistantPrompt('You are a helpful assistant.');

      final history = <ChatMessage>[
        ChatMessage(role: 'user', content: 'Hello'),
      ];

      final stream = service.sendStreamWithTools('Hello', history: history);
      await stream.toList();

      final messages = provider.capturedMessages;
      expect(messages, isNotNull);
      expect(messages!.length, 2);
      expect(messages[0]['role'], 'system');
      expect(messages[0]['content'], 'You are a helpful assistant.');
      expect(messages[1]['role'], 'user');
    });
  });
}
