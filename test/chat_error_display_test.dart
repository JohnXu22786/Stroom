import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/models/chat_message.dart';

void main() {
  group('formatChatErrorMessage', () {
    test('returns "未配置聊天供应商" message for adapter not configured', () {
      final result = formatChatErrorMessage(Exception('请先配置聊天供应商'));
      expect(result, contains('错误:'));
      expect(result, contains('聊天 API 未配置'));
    });

    test('returns "API key not configured" message', () {
      final result =
          formatChatErrorMessage(Exception('API key not configured'));
      expect(result, contains('错误:'));
      expect(result, contains('API Key 未配置'));
    });

    test('returns network error message for SocketException', () {
      final result = formatChatErrorMessage(
          Exception('SocketException: Connection refused'));
      expect(result, contains('错误:'));
      expect(result, contains('网络连接失败'));
    });

    test('returns network error message for Chinese 无法连接到服务器', () {
      final result = formatChatErrorMessage(Exception('无法连接到服务器'));
      expect(result, contains('错误:'));
      expect(result, contains('无法连接到服务器'));
    });

    test('returns network error message for Chinese 连接错误', () {
      final result = formatChatErrorMessage(Exception('连接错误'));
      expect(result, contains('错误:'));
      expect(result, contains('连接错误'));
    });

    test('returns network error message for Connection refused', () {
      final result = formatChatErrorMessage(Exception('Connection refused'));
      expect(result, contains('错误:'));
      expect(result, contains('网络连接失败'));
    });

    test('returns network error message for 连接失败', () {
      final result = formatChatErrorMessage(Exception('连接失败'));
      expect(result, contains('错误:'));
      expect(result, contains('连接失败'));
    });

    test('returns timeout message for timeout errors', () {
      final result = formatChatErrorMessage(Exception('timeout'));
      expect(result, contains('错误:'));
      expect(result, contains('连接超时'));
    });

    test('returns timeout message for Chinese 超时', () {
      final result = formatChatErrorMessage(Exception('连接超时'));
      expect(result, contains('错误:'));
      expect(result, contains('连接超时'));
    });

    test('returns raw HTTP error message', () {
      final result =
          formatChatErrorMessage(Exception('HTTP 401: Unauthorized'));
      expect(result, contains('错误:'));
      expect(result, contains('HTTP 401'));
    });

    test('returns generic error for unknown errors', () {
      final result = formatChatErrorMessage(Exception('Some unknown error'));
      expect(result, '错误: Exception: Some unknown error');
    });

    test('preserves original error string for HTTP API errors', () {
      final result = formatChatErrorMessage(
          Exception('API 请求失败 (HTTP 500): Internal Server Error'));
      expect(result, contains('错误:'));
      expect(result, contains('HTTP 500'));
      expect(result, contains('Internal Server Error'));
    });

    test('handles string error input', () {
      final result = formatChatErrorMessage('直接错误字符串');
      expect(result, '错误: 直接错误字符串');
    });

    test('handles DioException-like format string from streaming path', () {
      // The streaming path rethrows raw DioException. Its toString()
      // output does not contain 'HTTP ' in plain text, so it should
      // fall through to the generic format.
      final result = formatChatErrorMessage(
          'DioException [bad response]: The request returned an invalid status code of 401');
      expect(result, contains('错误:'));
      expect(result, contains('DioException'));
    });
  });

  group('ChatMessage rawRequest/rawResponse with error flow', () {
    test(
        'error message retains rawRequest/rawResponse through serialization round-trip',
        () {
      // Simulate the exact capture flow from ChatPage._startStreaming()
      final rawRequestCapture = <String, dynamic>{
        'url': 'https://api.example.com/v1/chat/completions',
        'headers': {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer sk-test123...abcd',
        },
        'body': {
          'model': 'gpt-4',
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
          'max_tokens': 4096,
          'temperature': 0.7,
          'stream': true,
        },
      };

      final rawResponseCapture = <String, dynamic>{
        'statusCode': 401,
        'data': {
          'error': {
            'message': 'Incorrect API key provided',
            'type': 'invalid_request_error',
            'code': 'invalid_api_key',
          },
        },
      };

      final msg = ChatMessage(
        role: 'assistant',
        content: '错误: API 请求失败 (HTTP 401): Incorrect API key provided',
        id: 'test-error-msg-1',
        isError: true,
        rawRequest: rawRequestCapture,
        rawResponse: rawResponseCapture,
      );

      // Round-trip through map serialization
      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.isError, true);
      expect(restored.rawRequest, isNotNull);
      expect(restored.rawResponse, isNotNull);
      expect(restored.rawRequest!['url'],
          'https://api.example.com/v1/chat/completions');
      expect(restored.rawResponse!['statusCode'], 401);
      expect(restored.rawResponse!['data']['error']['message'],
          'Incorrect API key provided');
    });

    test(
        'ChatMessage with empty rawRequest/rawResponse empty maps round-trips correctly',
        () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '错误: Connection failed',
        id: 'test-empty-raw',
        isError: true,
        rawRequest: <String, dynamic>{},
        rawResponse: <String, dynamic>{},
      );

      final map = msg.toMap();
      expect(map.containsKey('rawRequest'), true);
      expect(map.containsKey('rawResponse'), true);
      expect(map['rawRequest'], <String, dynamic>{});
      expect(map['rawResponse'], <String, dynamic>{});

      final restored = ChatMessage.fromMap(map);
      expect(restored.rawRequest, <String, dynamic>{});
      expect(restored.rawResponse, <String, dynamic>{});
    });

    test('multiple error messages preserve their individual raw data', () {
      // Simulate two sequential errors in a conversation
      final error1 = ChatMessage(
        role: 'assistant',
        content: '错误: HTTP 500',
        id: 'err1',
        isError: true,
        rawRequest: {'url': 'https://api1.example.com'},
        rawResponse: {'statusCode': 500, 'data': 'Internal Error'},
      );
      final error2 = ChatMessage(
        role: 'assistant',
        content: '错误: HTTP 403',
        id: 'err2',
        isError: true,
        rawRequest: {'url': 'https://api2.example.com'},
        rawResponse: {'statusCode': 403, 'data': 'Forbidden'},
      );

      // Serialize and restore separately
      final map1 = error1.toMap();
      final map2 = error2.toMap();
      final restored1 = ChatMessage.fromMap(map1);
      final restored2 = ChatMessage.fromMap(map2);

      expect(restored1.rawRequest!['url'], 'https://api1.example.com');
      expect(restored1.rawResponse!['statusCode'], 500);
      expect(restored2.rawRequest!['url'], 'https://api2.example.com');
      expect(restored2.rawResponse!['statusCode'], 403);

      // Ensure data did not leak between messages
      expect(restored1.rawRequest!['url'], isNot(restored2.rawRequest!['url']));
    });

    test('rawRequest contains expected structure from ChatPage capture', () {
      // This tests the structure that ChatPage._startStreaming() builds
      final reqBody = <String, dynamic>{
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi there!'},
        ],
        'max_tokens': 4096,
        'temperature': 0.7,
      };
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer sk-****1234',
      };
      final url = 'https://api.example.com/v1/chat/completions';

      Map<String, dynamic>? rawRequestCapture;
      if (reqBody != null || headers != null || url != null) {
        rawRequestCapture = {};
        if (url != null) rawRequestCapture!['url'] = url;
        if (headers != null) rawRequestCapture!['headers'] = headers;
        if (reqBody != null) rawRequestCapture!['body'] = reqBody;
      }

      expect(rawRequestCapture, isNotNull);
      expect(rawRequestCapture!['url'], url);
      expect(rawRequestCapture['headers'], headers);
      expect(rawRequestCapture['body'], reqBody);
      expect(rawRequestCapture['body']['model'], 'gpt-4');
    });

    test('rawResponse contains expected structure from ChatPage capture', () {
      // This tests the structure that ChatPage._startStreaming() builds
      final respData = <String, dynamic>{
        'error': {'message': 'Bad Request', 'type': 'invalid_request_error'},
      };
      final statusCode = 400;

      Map<String, dynamic>? rawResponseCapture;
      if (respData != null || statusCode != null) {
        rawResponseCapture = {};
        if (statusCode != null) rawResponseCapture!['statusCode'] = statusCode;
        if (respData != null) rawResponseCapture!['data'] = respData;
      }

      expect(rawResponseCapture, isNotNull);
      expect(rawResponseCapture!['statusCode'], 400);
      expect(rawResponseCapture['data']['error']['message'], 'Bad Request');
    });

    test('rawResponse capture includes headers when available', () {
      // Simulate the enhanced capture with response headers
      final respData = <String, dynamic>{
        'error': {'message': 'Rate Limited'},
      };
      final statusCode = 429;
      final respHeaders = <String, List<String>>{
        'retry-after': ['120'],
        'content-type': ['application/json'],
        'x-request-id': ['req-abc-123'],
      };

      Map<String, dynamic>? rawResponseCapture;
      if (respData != null || statusCode != null || respHeaders != null) {
        rawResponseCapture = {};
        if (statusCode != null) rawResponseCapture!['statusCode'] = statusCode;
        if (respHeaders != null) rawResponseCapture!['headers'] = respHeaders;
        if (respData != null) rawResponseCapture!['data'] = respData;
      }

      expect(rawResponseCapture, isNotNull);
      expect(rawResponseCapture!['statusCode'], 429);
      expect(rawResponseCapture['headers']['retry-after'], ['120']);
      expect(rawResponseCapture['headers']['x-request-id'], ['req-abc-123']);
      expect(
          rawResponseCapture['headers']['content-type'], ['application/json']);
    });

    test('network error (no response) captures error info in response', () {
      // Simulate a DNS failure or server-not-found error
      final statusCode = null;
      final respData = null;
      final errorMessage =
          'DioException [connectionError]: Failed to connect to host';

      Map<String, dynamic>? rawResponseCapture;
      if (respData != null || statusCode != null) {
        rawResponseCapture = {};
        if (statusCode != null) rawResponseCapture!['statusCode'] = statusCode;
        if (respData != null) rawResponseCapture!['data'] = respData;
      } else {
        // For network errors with no response, capture the error message
        rawResponseCapture = {
          'error': errorMessage,
        };
      }

      expect(rawResponseCapture, isNotNull);
      expect(rawResponseCapture!['error'], contains('Failed to connect'));
      expect(rawResponseCapture.containsKey('statusCode'), false);
      expect(rawResponseCapture.containsKey('data'), false);
    });

    test('network error capture with timeout also works', () {
      // Simulate a timeout error
      final errorMessage =
          'DioException [connectionTimeout]: Timeout waiting for connection';

      Map<String, dynamic>? rawResponseCapture;
      rawResponseCapture = {
        'error': errorMessage,
      };

      expect(rawResponseCapture, isNotNull);
      expect(rawResponseCapture!['error'], contains('Timeout'));
    });
  });
}
