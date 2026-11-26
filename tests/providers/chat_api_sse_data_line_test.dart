// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/chat_api_provider.dart';

void main() {
  test(
    'chat provider consumes data fields with no space after the colon',
    () async {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://example.test/chat/completions',
        apiKey: 'test-key',
        sseStreamOverride:
            (
              url,
              headers,
              body, {
              cancelToken,
              locale,
              onResponseHeaders,
            }) async* {
              yield 'data:{"choices":[{"delta":{"content":"kept"}}]}';
              yield 'data: [DONE]';
            },
      );

      final events = await provider.chatStream([
        {'role': 'user', 'content': 'hello'},
      ]).toList();

      expect(events.map((event) => event.text), contains('kept'));
    },
  );
}
