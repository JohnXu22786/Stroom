import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/anthropic_chat_provider.dart';

// ============================================================================
// AnthropicChatProvider 测试（官方 Messages API 格式）
// ============================================================================
//
// 覆盖行为：
// 1. 请求体：max_tokens 必填兜底、system 字段、extended thinking 时
//    强制省略 temperature（官方要求 temperature=1）
// 2. SSE 解析：text_delta / thinking_delta / tool_use 块累计 /
//    signature 累计 / stop_reason / error
// 3. 工具调用仅在 stop_reason == tool_use 时产出
// 4. thinking 签名事件、请求头

void main() {
  group('buildBody', () {
    final provider = AnthropicChatProvider(
      baseUrl: 'https://api.anthropic.com/v1/messages',
      apiKey: 'test-key',
    );

    test('max_tokens 必填：未传时兜底 4096', () {
      final body = provider.buildBody([
        {'role': 'user', 'content': 'hi'},
      ], model: 'claude-3-5-sonnet');
      expect(body['max_tokens'], 4096);
      expect(body['model'], 'claude-3-5-sonnet');
      expect(body['messages'], hasLength(1));
      expect(body['stream'], isFalse);
    });

    test('传入 max_tokens 时使用传入值', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'hi'},
        ],
        model: 'claude-3-5-sonnet',
        maxTokens: 8192,
      );
      expect(body['max_tokens'], 8192);
    });

    test('system 作为顶层字段', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'hi'},
        ],
        system: '你是助手',
        model: 'claude-3-5-sonnet',
      );
      expect(body['system'], '你是助手');
      // system 不能出现在 messages 中
      expect(body['messages'], hasLength(1));
    });

    test('extended thinking 开启时省略 temperature（官方要求为 1）', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'hi'},
        ],
        model: 'claude-3-5-sonnet',
        temperature: 0.7,
        extraParams: {
          'thinking': {'type': 'enabled', 'budget_tokens': 1024},
        },
      );
      expect(body['temperature'], isNull);
      expect((body['thinking'] as Map)['type'], 'enabled');
    });

    test('无 extended thinking 时 temperature 透传', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'hi'},
        ],
        model: 'claude-3-5-sonnet',
        temperature: 0.7,
      );
      expect(body['temperature'], 0.7);
    });

    test('tools 使用 Anthropic 形状（name/input_schema）', () {
      final body = provider.buildBody(
        [
          {'role': 'user', 'content': 'hi'},
        ],
        model: 'claude-3-5-sonnet',
        tools: [
          {
            'name': 'get_weather',
            'description': '获取天气',
            'input_schema': {'type': 'object'},
          },
        ],
      );
      expect(body['tools'], hasLength(1));
      expect((body['tools'] as List).first['name'], 'get_weather');
    });
  });

  group('请求头', () {
    test('使用 x-api-key 与 anthropic-version（非 Bearer）', () {
      final provider = AnthropicChatProvider(
        baseUrl: 'https://api.anthropic.com/v1/messages',
        apiKey: 'sk-test',
      );
      final headers = provider.defaultHeaders;
      expect(headers['x-api-key'], 'sk-test');
      expect(headers['anthropic-version'], '2023-06-01');
      expect(headers.containsKey('Authorization'), isFalse);
    });
  });

  group('SSE 文本/推理事件（processAnthropicStreamData）', () {
    test('text_delta 产出文本事件', () {
      final events = processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': '你好'},
      }, AnthropicStreamAccumulator());
      expect(events, hasLength(1));
      expect(events[0].text, '你好');
      expect(events[0].isReasoning, isFalse);
    });

    test('thinking_delta 产出推理事件', () {
      final events = processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'thinking_delta', 'thinking': '思考中'},
      }, AnthropicStreamAccumulator());
      expect(events, hasLength(1));
      expect(events[0].text, '思考中');
      expect(events[0].isReasoning, isTrue);
    });

    test('空 delta / 其他事件不产出', () {
      expect(
        processAnthropicStreamData(
            {'type': 'message_start'}, AnthropicStreamAccumulator()),
        isEmpty,
      );
      expect(
        processAnthropicStreamData({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': ''},
        }, AnthropicStreamAccumulator()),
        isEmpty,
      );
    });
  });

  group('processAnthropicStreamData（跨事件累计）', () {
    test('tool_use 块：start + input_json_delta 拼接 + stop_reason', () {
      final acc = AnthropicStreamAccumulator();
      final events = <AIStreamEvent>[];

      events.addAll(processAnthropicStreamData({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'tool_use',
          'id': 'toolu_01',
          'name': 'get_weather',
        },
      }, acc));
      expect(events, isEmpty);
      expect(acc.toolCalls, hasLength(1));

      events.addAll(processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"city":'},
      }, acc));
      events.addAll(processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'input_json_delta', 'partial_json': '"HZ"}'},
      }, acc));
      expect((acc.toolCalls[0]!['input'] as String), '{"city":"HZ"}');

      processAnthropicStreamData({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      }, acc);
      expect(acc.stopReason, 'tool_use');
    });

    test('thinking 签名：多个 signature_delta 拼接', () {
      final acc = AnthropicStreamAccumulator();
      processAnthropicStreamData({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking'},
      }, acc);
      processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'signature_delta', 'signature': 'sig-'},
      }, acc);
      processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'signature_delta', 'signature': 'part2'},
      }, acc);
      expect(acc.thinkingSignatures, ['sig-part2']);
    });

    test('error 事件抛出异常', () {
      final acc = AnthropicStreamAccumulator();
      expect(
        () => processAnthropicStreamData({
          'type': 'error',
          'error': {'type': 'invalid_request_error', 'message': 'bad'},
        }, acc),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('bad'))),
      );
    });

    test('text_delta 与 thinking_delta 产出事件', () {
      final acc = AnthropicStreamAccumulator();
      final events = processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': '回答'},
      }, acc);
      expect(events.single.text, '回答');
    });
  });

  group('buildToolCallEvent（流末尾产出逻辑）', () {
    test('stop_reason=tool_use 且有累计时产出工具调用事件', () {
      final acc = AnthropicStreamAccumulator();
      processAnthropicStreamData({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'tool_use',
          'id': 'toolu_01',
          'name': 'get_weather',
        },
      }, acc);
      processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"city":"HZ"}'},
      }, acc);
      processAnthropicStreamData({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      }, acc);

      final event = buildToolCallEvent(acc);
      expect(event, isNotNull);
      expect(event!.isToolCallEvent, isTrue);
      final tc = event.toolCalls!.single;
      expect(tc['id'], 'toolu_01');
      expect(tc['name'], 'get_weather');
      expect(tc['input'], {'city': 'HZ'});
    });

    test('stop_reason 非 tool_use 时不产出（防中断残片）', () {
      final acc = AnthropicStreamAccumulator();
      processAnthropicStreamData({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'tool_use',
          'id': 'toolu_x',
          'name': 't',
        },
      }, acc);
      processAnthropicStreamData({
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn'},
      }, acc);
      expect(buildToolCallEvent(acc), isNull);
    });

    test('无累计工具块时不产出', () {
      final acc = AnthropicStreamAccumulator();
      processAnthropicStreamData({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      }, acc);
      expect(buildToolCallEvent(acc), isNull);
    });

    test('thinking 签名事件由累计器透出', () {
      final acc = AnthropicStreamAccumulator();
      processAnthropicStreamData({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking'},
      }, acc);
      processAnthropicStreamData({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'signature_delta', 'signature': 'sig-abc'},
      }, acc);
      expect(acc.thinkingSignatures, ['sig-abc']);
    });
  });
}
