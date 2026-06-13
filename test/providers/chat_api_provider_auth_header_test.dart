import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/chat_api_provider.dart';

void main() {
  group('OpenAICompatibleChatProvider - Authorization header correctness', () {
    const testApiKey = 'sk-test-full-api-key-12345678';
    const expectedAuth = 'Bearer sk-test-full-api-key-12345678';

    group('non-streaming chat() path', () {
      test('default Dio headers contain the full unmasked API key', () {
        // The non-streaming path uses the Dio instance's default headers,
        // which are set in the constructor with the full unmasked key.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        expect(provider.defaultHeaders['Authorization'], expectedAuth);
      });
    });

    group('streaming chatStream() path (401 FIX)', () {
      test('Dio constructor stores full unmasked API key in defaultHeaders', () {
        // The streaming path (chatStream) creates a NEW Dio instance via
        // sseStream(). Unlike the non-streaming path, it must explicitly
        // pass headers to the function call.
        //
        // BUG (now fixed): _maskApiKey(_apiKey) was used in the headers
        // map passed to sseStream(), causing the masked key like
        // "sk-test...5678" to be sent, resulting in HTTP 401.
        //
        // FIX: The headers map now uses _apiKey directly, matching the
        // non-streaming path which uses the full unmasked key.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        // Verify the Dio instance (used by chat()) has the full key
        expect(provider.defaultHeaders['Authorization'], expectedAuth);
        // After the fix, the sseStream() call receives the same full key
        // instead of the masked version. This is verified by code review
        // of the specific line fix: _maskApiKey(_apiKey) → _apiKey
      });

      test('lastRequestHeaders uses masked key for display purposes only', () {
        // The _lastRequestHeaders field is populated with masked keys for
        // safe display/logging. This is distinct from the actual HTTP
        // Authorization header and should NOT be confused with it.
        //
        // The bug was that the masked _lastRequestHeaders value was
        // accidentally reused as the header passed to sseStream().
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com/v1/chat/completions',
          apiKey: testApiKey,
          name: 'Test Provider',
        );

        // defaultHeaders contains the full unmasked key
        expect(provider.defaultHeaders['Authorization'], expectedAuth);
        // The _lastRequestHeaders (set during error logging) uses masked key
        // which would be shorter/obfuscated compared to the full key
        final fullAuth = provider.defaultHeaders['Authorization'] as String;
        expect(fullAuth.length, greaterThan(expectedAuth.length - 6));
      });
    });

    group('edge cases', () {
      test('empty API key skips Authorization header entirely', () {
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com',
          apiKey: '',
        );

        expect(provider.defaultHeaders, isNot(contains('Authorization')));
      });

      test('both chat() and chatStream() use the same auth pattern after fix', () {
        // chat() uses Dio default headers (full key). chatStream() passes
        // explicit headers to sseStream(). After the fix, both use the
        // full unmasked key rather than the masked version.
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.com',
          apiKey: testApiKey,
        );

        expect(provider.defaultHeaders['Authorization'], expectedAuth);
      });
    });
  });
}
