import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_protocol.dart';

// ============================================================================
// ChatProtocol 协议层测试
// ============================================================================
//
// 覆盖行为：
// 1. OpenAI 协议请求体与既有行为逐字节一致（system 消息前置、附件格式）
// 2. Anthropic 协议：system 顶层字段、内容块、官方 image/document 块、
//    audio/video 占位
// 3. 工具链构建：OpenAI assistant(tool_calls)+tool 消息 /
//    Anthropic thinking/text/tool_use 块 + tool_result 配对
// 4. normalizeToolCall / effectiveEndpointType

void main() {
  group('OpenAIProtocol.buildRequest', () {
    test('前置 system 消息，历史逐条转换为 role/content', () async {
      final protocol = OpenAIProtocol();
      final req = await protocol.buildRequest(
        history: [
          ChatMessage(role: 'user', content: '你好'),
          ChatMessage(role: 'assistant', content: '你好！'),
        ],
        assistantPrompt: '你是一个助手',
      );
      expect(req.system, isNull);
      expect(req.messages, hasLength(3));
      expect(req.messages[0], {'role': 'system', 'content': '你是一个助手'});
      expect(req.messages[1], {'role': 'user', 'content': '你好'});
      expect(req.messages[2], {'role': 'assistant', 'content': '你好！'});
    });

    test('空提示词不产生 system 消息', () async {
      final req = await OpenAIProtocol().buildRequest(
        history: [ChatMessage(role: 'user', content: 'hi')],
        assistantPrompt: '   ',
      );
      expect(req.messages, hasLength(1));
    });
  });

  group('AnthropicProtocol.buildRequest', () {
    test('system 走顶层字段，历史保持 role/content 字符串', () async {
      final req = await AnthropicProtocol().buildRequest(
        history: [
          ChatMessage(role: 'user', content: '你好'),
          ChatMessage(role: 'assistant', content: '你好！'),
        ],
        assistantPrompt: '你是一个助手',
      );
      expect(req.system, '你是一个助手');
      expect(req.messages, hasLength(2));
      expect(req.messages[0], {'role': 'user', 'content': '你好'});
      expect(req.messages[1], {'role': 'assistant', 'content': '你好！'});
    });

    test('无提示词时 system 为 null', () async {
      final req = await AnthropicProtocol().buildRequest(
        history: [ChatMessage(role: 'user', content: 'hi')],
        assistantPrompt: null,
      );
      expect(req.system, isNull);
    });

    test('图片附件转换为官方 image base64 块', () async {
      // 使用有缓存 base64 的附件（不落盘）
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: '/nonexistent',
        fileSize: 100,
      )..base64Data = 'cGhvdG8=';
      final req = await AnthropicProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'user',
            content: '看图',
            attachments: [att],
          ),
        ],
      );
      final content = req.messages[0]['content'] as List;
      expect(content, hasLength(2));
      expect(content[0], {'type': 'text', 'text': '看图'});
      expect(content[1], {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': 'cGhvdG8=',
        },
      });
    });

    test('音频/视频附件在 Anthropic 下为占位文本', () async {
      final audio = Attachment(
        fileName: 'a.mp3',
        mimeType: 'audio/mpeg',
        fileType: 'audio',
        hash: 'h',
        storagePath: '/nonexistent',
        fileSize: 100,
      )..base64Data = 'YXVkaW8=';
      final req = await AnthropicProtocol().buildRequest(
        history: [
          ChatMessage(role: 'user', content: '', attachments: [audio])
        ],
      );
      final content = req.messages[0]['content'] as List;
      expect(content, hasLength(1));
      expect(
        (content[0] as Map)['text'],
        contains('Anthropic 格式下不支持'),
      );
    });
  });

  group('toolDefsToJson', () {
    const def = ToolDefinition(
      name: 'get_weather',
      description: '获取天气',
      parameters: {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'}
        },
      },
    );

    test('OpenAI 协议保持 function 包装格式', () {
      final json = OpenAIProtocol().toolDefsToJson([def]);
      expect(json, [
        {
          'type': 'function',
          'function': {
            'name': 'get_weather',
            'description': '获取天气',
            'parameters': {
              'type': 'object',
              'properties': {
                'city': {'type': 'string'}
              },
            },
          },
        },
      ]);
    });

    test('Anthropic 协议使用 name/description/input_schema', () {
      final json = AnthropicProtocol().toolDefsToJson([def]);
      expect(json, [
        {
          'name': 'get_weather',
          'description': '获取天气',
          'input_schema': {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'}
            },
          },
        },
      ]);
    });

    test('Anthropic 协议空 description 有兜底', () {
      final json = AnthropicProtocol().toolDefsToJson([
        const ToolDefinition(name: 't', description: '', parameters: {}),
      ]);
      expect((json[0] as Map)['description'], 'Tool');
    });
  });

  group('buildAssistantChainMessage', () {
    const calls = [
      NeutralToolCall(
        id: 'call_1',
        name: 'get_weather',
        argumentsJson: '{"city":"Hangzhou"}',
      ),
    ];

    test('OpenAI：单条 assistant 消息含 tool_calls + content + reasoning_content',
        () {
      final msgs = OpenAIProtocol().buildAssistantChainMessage(
        content: '我来查一下',
        toolCalls: calls,
        roundReasoning: '思考中',
      );
      expect(msgs, hasLength(1));
      final m = msgs[0];
      expect(m['role'], 'assistant');
      expect(m['content'], '我来查一下');
      expect(m['reasoning_content'], '思考中');
      final tcs = m['tool_calls'] as List;
      expect(tcs, hasLength(1));
      expect((tcs[0] as Map)['function'], {
        'name': 'get_weather',
        'arguments': '{"city":"Hangzhou"}',
      });
    });

    test('Anthropic：无签名时省略 thinking 块（官方要求签名才可续接）', () {
      final msgs = AnthropicProtocol().buildAssistantChainMessage(
        content: '我来查一下',
        toolCalls: calls,
        roundReasoning: '思考中',
        thinkingSignature: null,
      );
      final blocks = (msgs[0]['content'] as List).cast<Map>();
      expect(blocks, hasLength(2)); // text + tool_use，无 thinking
      expect(blocks[0]['type'], 'text');
      expect(blocks[1]['type'], 'tool_use');
      expect(blocks[1]['id'], 'call_1');
      expect(blocks[1]['name'], 'get_weather');
      expect(blocks[1]['input'], {'city': 'Hangzhou'});
    });

    test('Anthropic：有签名时产出 thinking 块', () {
      final msgs = AnthropicProtocol().buildAssistantChainMessage(
        content: '',
        toolCalls: calls,
        roundReasoning: '思考中',
        thinkingSignature: 'sig123',
      );
      final blocks = (msgs[0]['content'] as List).cast<Map>();
      expect(blocks, hasLength(2));
      expect(blocks[0]['type'], 'thinking');
      expect(blocks[0]['thinking'], '思考中');
      expect(blocks[0]['signature'], 'sig123');
      expect(blocks[1]['type'], 'tool_use');
    });

    test('Anthropic：空文本空推理时只有 tool_use 块（content 数组非空）', () {
      final msgs = AnthropicProtocol().buildAssistantChainMessage(
        content: '',
        toolCalls: calls,
      );
      final blocks = (msgs[0]['content'] as List).cast<Map>();
      expect(blocks, hasLength(1));
      expect(blocks[0]['type'], 'tool_use');
    });
  });

  group('buildToolResultMessages', () {
    const results = [
      ToolCallResult(toolCallId: 'call_1', result: '24°C'),
    ];

    test('OpenAI：N 条 tool 角色消息，紧跟在 assistant 后', () {
      final msgs = OpenAIProtocol().buildToolResultMessages(results);
      expect(msgs, hasLength(1));
      expect(msgs[0], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '24°C',
      });
    });

    test('Anthropic：单条 user 消息含全部 tool_result 块（配对完整）', () {
      final msgs = AnthropicProtocol().buildToolResultMessages([
        ...results,
        const ToolCallResult(toolCallId: 'call_2', result: '下雨'),
      ]);
      expect(msgs, hasLength(1));
      expect(msgs[0]['role'], 'user');
      final blocks = (msgs[0]['content'] as List).cast<Map>();
      expect(blocks, hasLength(2));
      expect(blocks[0], {
        'type': 'tool_result',
        'tool_use_id': 'call_1',
        'content': '24°C',
      });
      expect(blocks[1]['tool_use_id'], 'call_2');
    });
  });

  group('normalizeToolCall', () {
    test('OpenAI 形状', () {
      final n = normalizeToolCall({
        'id': 'call_1',
        'type': 'function',
        'function': {'name': 'get_weather', 'arguments': '{"city":"HZ"}'},
      });
      expect(n.id, 'call_1');
      expect(n.name, 'get_weather');
      expect(n.argumentsJson, '{"city":"HZ"}');
    });

    test('Anthropic 形状（input 为 map）', () {
      final n = normalizeToolCall({
        'id': 'toolu_1',
        'name': 'get_weather',
        'input': {'city': 'HZ'},
      });
      expect(n.id, 'toolu_1');
      expect(n.name, 'get_weather');
      expect(n.argumentsJson, '{"city":"HZ"}');
    });

    test('Anthropic 形状（input 缺失时兜底 {}）', () {
      final n = normalizeToolCall({'id': 'toolu_2', 'name': 't'});
      expect(n.argumentsJson, '{}');
    });
  });

  group('effectiveEndpointType', () {
    test('模型覆盖优先于供应商', () {
      expect(effectiveEndpointType('anthropic', 'openai'), 'anthropic');
      expect(effectiveEndpointType('openai', 'anthropic'), 'openai');
    });

    test('模型未设置时用供应商', () {
      expect(effectiveEndpointType(null, 'anthropic'), 'anthropic');
    });

    test('都未设置时默认 openai（旧数据迁移路径）', () {
      expect(effectiveEndpointType(null, null), 'openai');
    });
  });

  group('createChatProtocol', () {
    test('按端点类型返回对应协议', () {
      expect(createChatProtocol('anthropic'), isA<AnthropicProtocol>());
      expect(createChatProtocol('openai'), isA<OpenAIProtocol>());
      expect(createChatProtocol('unknown'), isA<OpenAIProtocol>());
    });
  });
}
