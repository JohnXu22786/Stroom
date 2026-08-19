import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ChatMessage rawRequest/rawResponse', () {
    test('toMap includes rawRequest and rawResponse when set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '错误: API 请求失败 (HTTP 404): Not Found',
        isError: true,
        rawRequest: {
          'url': 'https://api.example.com/chat',
          'headers': {'Content-Type': 'application/json'},
          'body': {'model': 'gpt-4', 'messages': []},
        },
        rawResponse: {
          'statusCode': 404,
          'data': {
            'error': {'message': 'Not Found'}
          },
        },
      );

      final map = msg.toMap();
      expect(map['rawRequest'], isA<Map<String, dynamic>>());
      expect(map['rawResponse'], isA<Map<String, dynamic>>());
      expect((map['rawRequest'] as Map<String, dynamic>)['url'],
          'https://api.example.com/chat');
      expect((map['rawResponse'] as Map<String, dynamic>)['statusCode'], 404);
    });

    test('toMap does NOT include rawRequest/rawResponse when null', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello',
      );

      final map = msg.toMap();
      expect(map.containsKey('rawRequest'), false);
      expect(map.containsKey('rawResponse'), false);
    });

    test('fromMap restores rawRequest and rawResponse', () {
      final originalMap = <String, dynamic>{
        'id': 'test123',
        'role': 'assistant',
        'content': '错误: API 请求失败 (HTTP 404): Not Found',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'isError': true,
        'rawRequest': {
          'url': 'https://api.example.com/chat',
          'headers': {'Content-Type': 'application/json'},
          'body': {'model': 'gpt-4', 'messages': []},
        },
        'rawResponse': {
          'statusCode': 404,
          'data': {
            'error': {'message': 'Not Found'}
          },
        },
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.rawRequest, isNotNull);
      expect(msg.rawResponse, isNotNull);
      expect(msg.rawRequest!['url'], 'https://api.example.com/chat');
      expect(msg.rawResponse!['statusCode'], 404);
    });

    test('fromMap handles null rawRequest/rawResponse gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'test456',
        'role': 'user',
        'content': 'Hello',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.rawRequest, isNull);
      expect(msg.rawResponse, isNull);
    });

    test('serialization round-trip preserves rawRequest/rawResponse', () {
      final original = ChatMessage(
        role: 'assistant',
        content: '错误: API 请求失败 (HTTP 500): Internal Server Error',
        isError: true,
        rawRequest: {
          'url': 'https://api.example.com/chat',
          'headers': {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer sk-****1234',
          },
          'body': {
            'model': 'gpt-4',
            'messages': [
              {'role': 'user', 'content': 'Hello'}
            ],
          },
        },
        rawResponse: {
          'statusCode': 500,
          'data': {
            'error': {
              'message': 'Internal Server Error',
              'type': 'server_error'
            },
          },
        },
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.rawRequest, equals(original.rawRequest));
      expect(restored.rawResponse, equals(original.rawResponse));
      expect(restored.isError, true);
      expect(restored.content, original.content);
    });

    test(
        'isError: true with null rawRequest/rawResponse does not include them in map',
        () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '错误: Connection failed',
        isError: true,
      );
      final map = msg.toMap();
      expect(map['isError'], true);
      expect(map.containsKey('rawRequest'), false);
      expect(map.containsKey('rawResponse'), false);
    });

    test(
        'isError: false with rawRequest/rawResponse set still includes them in map',
        () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Normal response',
        isError: false,
        rawRequest: {'url': 'https://example.com/api'},
        rawResponse: {'data': 'ok'},
      );
      final map = msg.toMap();
      expect(map['rawRequest'], {'url': 'https://example.com/api'});
      expect(map['rawResponse'], {'data': 'ok'});
      // isError should be absent (falsy, so not included in toMap)
      expect(map.containsKey('isError'), false);
    });

    test('empty Map rawRequest is serialized (non-null)', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Error',
        isError: true,
        rawRequest: <String, dynamic>{},
        rawResponse: <String, dynamic>{},
      );
      final map = msg.toMap();
      expect(map.containsKey('rawRequest'), true);
      expect(map['rawRequest'], <String, dynamic>{});
      expect(map.containsKey('rawResponse'), true);
      expect(map['rawResponse'], <String, dynamic>{});
    });
  });

  group('ChatMessage toolCallRoundStarts', () {
    test('toMap includes toolCallRoundStarts when set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'answer',
        toolCallRoundStarts: [0, 2],
        toolCalls: [
          ToolCallData(
            id: 'a',
            name: 'A',
            arguments: {},
            status: ToolCallStatus.completed,
          ),
        ],
      );
      final map = msg.toMap();
      expect(map['toolCallRoundStarts'], [0, 2]);
    });

    test('toMap omits toolCallRoundStarts when null', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'answer',
      );
      final map = msg.toMap();
      expect(map.containsKey('toolCallRoundStarts'), false);
    });

    test('fromMap restores toolCallRoundStarts', () {
      final map = <String, dynamic>{
        'id': 'm1',
        'role': 'assistant',
        'content': 'answer',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'toolCallRoundStarts': [0, 3],
        'toolCalls': [
          {'id': 'a', 'name': 'A', 'arguments': {}, 'status': 'completed'},
        ],
      };
      final msg = ChatMessage.fromMap(map);
      expect(msg.toolCallRoundStarts, [0, 3]);
    });

    test('fromMap returns null toolCallRoundStarts when absent (old data)', () {
      // Old data without toolCallRoundStarts should deserialize to null
      // so buildAgentChainSegments falls back to the legacy algorithm.
      final map = <String, dynamic>{
        'id': 'm2',
        'role': 'assistant',
        'content': 'old answer',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };
      final msg = ChatMessage.fromMap(map);
      expect(msg.toolCallRoundStarts, isNull);
    });

    test('serialization round-trip preserves toolCallRoundStarts', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'answer',
        toolCallRoundStarts: [0, 2, 5],
        toolCalls: [
          ToolCallData(
            id: 'a',
            name: 'A',
            arguments: {},
            status: ToolCallStatus.completed,
          ),
        ],
        textSections: ['', 'text2', ''],
        reasoningSections: ['r1', '', 'r3'],
      );
      final restored = ChatMessage.fromMap(original.toMap());
      expect(restored.toolCallRoundStarts, [0, 2, 5]);
      // Empty textSections entries are preserved when roundStarts present
      // (so indices align with round boundaries for _buildWithRounds).
      expect(restored.textSections, ['', 'text2', '']);
      expect(restored.reasoningSections, ['r1', '', 'r3']);
    });

    test(
        'old data without roundStarts filters empty textSections (backward compat)',
        () {
      // Old data: textSections with empty entries on disk, but no
      // toolCallRoundStarts field. Old behavior filtered empties; the
      // new code preserves this for old data (only keeps empties when
      // roundStarts is present).
      final map = <String, dynamic>{
        'id': 'm3',
        'role': 'assistant',
        'content': 'answer',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'textSections': ['', 'text2', ''],
        'reasoningSections': ['r1', '', 'r3'],
      };
      final msg = ChatMessage.fromMap(map);
      // No roundStarts → empties filtered (old behavior preserved).
      expect(msg.toolCallRoundStarts, isNull);
      expect(msg.textSections, ['text2']);
      expect(msg.reasoningSections, ['r1', 'r3']);
    });
  });
}
