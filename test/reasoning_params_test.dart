import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../lib/providers/chat_api_provider.dart';

void main() {
  late OpenAICompatibleChatProvider provider;

  setUp(() {
    provider = OpenAICompatibleChatProvider(
      baseUrl: 'http://invalid-host-test/chat/completions',
      apiKey: 'test-key',
      name: 'test',
    );
  });

  Future<Map<String, dynamic>?> getRequestBody({
    bool reasoning = false,
    String? model,
  }) async {
    try {
      await provider.chat(
        [{'role': 'user', 'content': 'hi'}],
        reasoning: reasoning,
        model: model,
      );
    } catch (_) {
      // Expected to fail — request body is captured before the call
    }
    return provider.lastRequestBody;
  }

  group('reasoning params', () {
    test('DeepSeek model uses thinking format', () async {
      final body = await getRequestBody(reasoning: true, model: 'deepseek-chat');
      expect(body, isNotNull);
      expect(body!['thinking'], {'type': 'enabled'});
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('DeepSeek R1 model uses thinking format', () async {
      final body = await getRequestBody(reasoning: true, model: 'deepseek-r1');
      expect(body, isNotNull);
      expect(body!['thinking'], {'type': 'enabled'});
    });

    test('OpenAI model uses reasoning_effort format', () async {
      final body = await getRequestBody(reasoning: true, model: 'o1-mini');
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
      expect(body.containsKey('thinking'), false);
    });

    test('OpenAI o3 model uses reasoning_effort format', () async {
      final body = await getRequestBody(reasoning: true, model: 'o3-mini');
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
    });

    test('GPT model uses reasoning_effort format', () async {
      final body = await getRequestBody(reasoning: true, model: 'gpt-4o');
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
    });

    test('Unknown model defaults to reasoning_effort', () async {
      final body = await getRequestBody(reasoning: true, model: 'claude-3-opus');
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
    });

    test('No reasoning params when reasoning is false', () async {
      final body = await getRequestBody(reasoning: false, model: 'deepseek-chat');
      expect(body, isNotNull);
      expect(body!.containsKey('thinking'), false);
      expect(body.containsKey('reasoning_effort'), false);
    });

    test('Null model defaults to reasoning_effort', () async {
      final body = await getRequestBody(reasoning: true, model: null);
      expect(body, isNotNull);
      expect(body!['reasoning_effort'], 'medium');
    });
  });
}
