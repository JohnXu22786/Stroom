import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ChatMessage toolCalls persistence', () {
    test('toMap includes toolCalls when set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '我来帮你查询天气。',
        toolCalls: [
          ToolCallData(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'location': 'Beijing'},
            status: ToolCallStatus.completed,
            result: '晴, 25°C',
          ),
          ToolCallData(
            id: 'call_2',
            name: 'get_air_quality',
            arguments: {'city': 'Beijing'},
            status: ToolCallStatus.completed,
            result: '优',
          ),
        ],
      );

      final map = msg.toMap();
      expect(map['toolCalls'], isA<List<dynamic>>());
      final toolCalls = map['toolCalls'] as List;
      expect(toolCalls.length, 2);
      expect(toolCalls[0]['id'], 'call_1');
      expect(toolCalls[0]['name'], 'get_weather');
      expect(toolCalls[1]['id'], 'call_2');
    });

    test('toMap does NOT include toolCalls when null', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello',
      );

      final map = msg.toMap();
      expect(map.containsKey('toolCalls'), false);
    });

    test('toMap does NOT include toolCalls when empty list', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Hello',
        toolCalls: [],
      );

      final map = msg.toMap();
      expect(map.containsKey('toolCalls'), false);
    });

    test('fromMap restores toolCalls', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_with_tools',
        'role': 'assistant',
        'content': '查询结果如下',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'toolCalls': <dynamic>[
          <String, dynamic>{
            'id': 'call_a',
            'name': 'search',
            'arguments': {'query': 'Flutter'},
            'status': 'completed',
            'result': 'Flutter is a UI toolkit',
          },
        ],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.toolCalls, isNotNull);
      expect(msg.toolCalls!.length, 1);
      expect(msg.toolCalls![0].id, 'call_a');
      expect(msg.toolCalls![0].name, 'search');
      expect(msg.toolCalls![0].arguments, {'query': 'Flutter'});
      expect(msg.toolCalls![0].status, ToolCallStatus.completed);
      expect(msg.toolCalls![0].result, 'Flutter is a UI toolkit');
    });

    test('fromMap handles null toolCalls gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_no_tools',
        'role': 'assistant',
        'content': 'No tools',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.toolCalls, isNull);
    });

    test('fromMap handles non-List toolCalls gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_bad_tools',
        'role': 'assistant',
        'content': 'Bad tools',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'toolCalls': 'not-a-list',
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.toolCalls, isNull);
    });

    test('fromMap handles corrupt tool call entries gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_mixed_tools',
        'role': 'assistant',
        'content': 'Mixed',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'toolCalls': <dynamic>[
          <String, dynamic>{
            'id': 'good_call',
            'name': 'good_tool',
            'arguments': {'key': 'value'},
            'status': 'completed',
          },
          'not-a-map-entry',
          null,
          <String, dynamic>{
            'id': 'another_good',
            'name': 'another_tool',
            'arguments': {},
            'status': 'running',
          },
        ],
      };

      final msg = ChatMessage.fromMap(originalMap);
      // Corrupt entries should be skipped, valid ones preserved
      expect(msg.toolCalls!.length, 2);
      expect(msg.toolCalls![0].id, 'good_call');
      expect(msg.toolCalls![1].id, 'another_good');
    });

    test('serialization round-trip preserves toolCalls', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'Round-trip test',
        toolCalls: [
          ToolCallData(
            id: 'call_rt1',
            name: 'func_a',
            arguments: {'x': 1},
            status: ToolCallStatus.completed,
            result: 'OK',
          ),
          ToolCallData(
            id: 'call_rt2',
            name: 'func_b',
            arguments: {'y': 2},
            status: ToolCallStatus.error,
            result: 'Error: timeout',
          ),
        ],
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.toolCalls, isNotNull);
      expect(restored.toolCalls!.length, 2);
      expect(restored.toolCalls![0].id, 'call_rt1');
      expect(restored.toolCalls![0].name, 'func_a');
      expect(restored.toolCalls![0].arguments, {'x': 1});
      expect(restored.toolCalls![0].status, ToolCallStatus.completed);
      expect(restored.toolCalls![0].result, 'OK');
      expect(restored.toolCalls![1].id, 'call_rt2');
      expect(restored.toolCalls![1].name, 'func_b');
      expect(restored.toolCalls![1].arguments, {'y': 2});
      expect(restored.toolCalls![1].status, ToolCallStatus.error);
      expect(restored.toolCalls![1].result, 'Error: timeout');
    });
  });

  group('ChatMessage reasoningSections persistence', () {
    test('toMap includes reasoningSections when set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '最终答案',
        reasoningSections: [
          '第一步思考：用户想查询天气',
          '第二步思考：需要调用天气API',
          '第三步思考：得到结果后整理输出',
        ],
      );

      final map = msg.toMap();
      expect(map['reasoningSections'], isA<List<dynamic>>());
      final sections = map['reasoningSections'] as List;
      expect(sections.length, 3);
      expect(sections[0], '第一步思考：用户想查询天气');
      expect(sections[1], '第二步思考：需要调用天气API');
    });

    test('toMap does NOT include reasoningSections when null', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello',
      );

      final map = msg.toMap();
      expect(map.containsKey('reasoningSections'), false);
    });

    test('toMap does NOT include reasoningSections when empty list', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Hello',
        reasoningSections: [],
      );

      final map = msg.toMap();
      expect(map.containsKey('reasoningSections'), false);
    });

    test('fromMap restores reasoningSections', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_reasoning',
        'role': 'assistant',
        'content': '最终答案',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningSections': <dynamic>[
          '思考步骤1',
          '思考步骤2',
        ],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningSections, isNotNull);
      expect(msg.reasoningSections!.length, 2);
      expect(msg.reasoningSections![0], '思考步骤1');
      expect(msg.reasoningSections![1], '思考步骤2');
    });

    test('fromMap handles null reasoningSections gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_no_reasoning',
        'role': 'assistant',
        'content': 'No reasoning',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningSections, isNull);
    });

    test('fromMap handles non-List reasoningSections gracefully', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_bad_reasoning',
        'role': 'assistant',
        'content': 'Bad',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningSections': 'not-a-list',
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningSections, isNull);
    });

    test('fromMap filters non-string entries in reasoningSections', () {
      final originalMap = <String, dynamic>{
        'id': 'msg_mixed_reasoning',
        'role': 'assistant',
        'content': 'Mixed',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningSections': <dynamic>[
          'valid reasoning',
          123,
          null,
          'another valid',
        ],
      };

      final msg = ChatMessage.fromMap(originalMap);
      expect(msg.reasoningSections!.length, 2);
      expect(msg.reasoningSections![0], 'valid reasoning');
      expect(msg.reasoningSections![1], 'another valid');
    });

    test('serialization round-trip preserves reasoningSections', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'Round-trip reasoning',
        reasoningSections: [
          'First reasoning step with **markdown**',
          'Second step: tool call needed',
          'Third step: final answer',
        ],
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.reasoningSections, isNotNull);
      expect(restored.reasoningSections!.length, 3);
      expect(restored.reasoningSections![0],
          'First reasoning step with **markdown**');
      expect(restored.reasoningSections![1], 'Second step: tool call needed');
      expect(restored.reasoningSections![2], 'Third step: final answer');
    });

    test(
        'both reasoningSections and reasoningContent are preserved in round-trip',
        () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
        reasoningContent: 'Legacy single reasoning text',
        reasoningSections: [
          'Multi-step reasoning 1',
          'Multi-step reasoning 2',
        ],
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.reasoningContent, 'Legacy single reasoning text');
      expect(restored.reasoningSections!.length, 2);
    });
  });

  group('ChatMessage combined toolCalls + reasoningSections', () {
    test('serialization round-trip preserves all fields together', () {
      final original = ChatMessage(
        role: 'assistant',
        content: '综合回答',
        reasoningSections: [
          '分析问题',
          '调用工具',
          '整理结果',
        ],
        toolCalls: [
          ToolCallData(
            id: 'call_c1',
            name: 'search_web',
            arguments: {'query': '天气'},
            status: ToolCallStatus.completed,
            result: '搜索结果...',
          ),
          ToolCallData(
            id: 'call_c2',
            name: 'get_weather',
            arguments: {'city': '北京'},
            status: ToolCallStatus.completed,
            result: '晴, 25°C',
          ),
        ],
        rawRequest: {'url': 'https://api.example.com/chat'},
        rawResponse: {'statusCode': 200},
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.content, '综合回答');
      expect(restored.reasoningSections!.length, 3);
      expect(restored.toolCalls!.length, 2);
      expect(restored.rawRequest!['url'], 'https://api.example.com/chat');
      expect(restored.rawResponse!['statusCode'], 200);

      // Verify tool call details survived
      expect(restored.toolCalls![0].name, 'search_web');
      expect(restored.toolCalls![1].name, 'get_weather');
      expect(restored.toolCalls![1].result, '晴, 25°C');
    });
  });

  group('Backward compatibility', () {
    test('old format without toolCalls/reasoningSections still loads', () {
      // Simulate a message saved by old code without toolCalls/reasoningSections
      final oldMap = <String, dynamic>{
        'id': 'old_msg',
        'role': 'assistant',
        'content': 'Old style response',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningContent': 'Single reasoning text (old format)',
      };

      final msg = ChatMessage.fromMap(oldMap);
      expect(msg.content, 'Old style response');
      expect(msg.reasoningContent, 'Single reasoning text (old format)');
      expect(msg.reasoningSections, isNull);
      expect(msg.toolCalls, isNull);
    });

    test('old format with reasoningContent still works with new fields', () {
      // The new system should still read old format and populate reasoningContent
      // _reasoningContents will be built from reasoningContent as fallback
      final oldMap = <String, dynamic>{
        'id': 'old_msg_2',
        'role': 'assistant',
        'content': 'Old response',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'reasoningContent': 'Legacy single reasoning block',
      };

      final msg = ChatMessage.fromMap(oldMap);
      expect(msg.reasoningContent, 'Legacy single reasoning block');
      expect(msg.reasoningSections, isNull);

      // Simulate the load path that checks both fields:
      final restoredSections = msg.reasoningSections ??
          (msg.reasoningContent != null && msg.reasoningContent!.isNotEmpty
              ? [msg.reasoningContent!]
              : null);
      expect(restoredSections, isNotNull);
      expect(restoredSections!.length, 1);
      expect(restoredSections[0], 'Legacy single reasoning block');
    });
  });
}
