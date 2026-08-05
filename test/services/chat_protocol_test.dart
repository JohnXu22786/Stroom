import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_protocol.dart';
import 'package:stroom/services/context_manager.dart'
    show kCompactedToolResultPlaceholder, kInterruptedToolResultPlaceholder;

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

  group('历史工具链重建（跨轮次保留工具调用与结果）', () {
    ChatMessage assistantWithTools(List<ToolCallData> tools,
        {String content = '查了一下'}) {
      return ChatMessage(
        role: 'assistant',
        content: content,
        toolCalls: tools,
      );
    }

    test('OpenAI：assistant(tool_calls) 紧跟 tool 结果消息', () async {
      final req = await OpenAIProtocol().buildRequest(
        history: [
          ChatMessage(role: 'user', content: '查天气'),
          assistantWithTools([
            const ToolCallData(
              id: 'call_1',
              name: 'get_weather',
              arguments: {'city': 'HZ'},
              status: ToolCallStatus.completed,
              result: '24°C',
            ),
            const ToolCallData(
              id: 'call_2',
              name: 'get_time',
              arguments: {'city': 'HZ'},
              status: ToolCallStatus.completed,
              result: '12:00',
            ),
          ]),
          ChatMessage(role: 'user', content: '谢谢'),
        ],
      );

      expect(req.messages, hasLength(5));
      final assistant = req.messages[1];
      expect(assistant['role'], 'assistant');
      expect(assistant['content'], '查了一下');
      final tcs = (assistant['tool_calls'] as List).cast<Map>();
      expect(tcs, hasLength(2));
      expect(tcs[0]['id'], 'call_1');
      expect((tcs[0]['function'] as Map)['name'], 'get_weather');
      expect((tcs[0]['function'] as Map)['arguments'], '{"city":"HZ"}');
      // tool 消息紧跟 assistant
      expect(req.messages[2], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '24°C',
      });
      expect(req.messages[3], {
        'role': 'tool',
        'tool_call_id': 'call_2',
        'content': '12:00',
      });
      expect(req.messages[4]['role'], 'user');
    });

    test('Anthropic：assistant(tool_use 块) + user(tool_result 块) 配对', () async {
      final req = await AnthropicProtocol().buildRequest(
        history: [
          assistantWithTools([
            const ToolCallData(
              id: 'toolu_1',
              name: 'get_weather',
              arguments: {'city': 'HZ'},
              status: ToolCallStatus.completed,
              result: '24°C',
            ),
          ]),
        ],
      );

      expect(req.messages, hasLength(2));
      final assistant = req.messages[0];
      expect(assistant['role'], 'assistant');
      final blocks = (assistant['content'] as List).cast<Map>();
      expect(blocks, hasLength(2)); // text + tool_use
      expect(blocks[0]['type'], 'text');
      expect(blocks[1], {
        'type': 'tool_use',
        'id': 'toolu_1',
        'name': 'get_weather',
        'input': {'city': 'HZ'},
      });
      // tool_result 在独立 user 消息
      final resultMsg = req.messages[1];
      expect(resultMsg['role'], 'user');
      final resultBlocks = (resultMsg['content'] as List).cast<Map>();
      expect(resultBlocks, hasLength(1));
      expect(resultBlocks[0], {
        'type': 'tool_result',
        'tool_use_id': 'toolu_1',
        'content': '24°C',
      });
    });

    test('未完成/结果缺失的工具用中断占位（配对完整性）', () async {
      final req = await OpenAIProtocol().buildRequest(
        history: [
          assistantWithTools([
            const ToolCallData(
              id: 'call_x',
              name: 'slow_tool',
              arguments: {},
              status: ToolCallStatus.running,
            ),
          ]),
        ],
      );
      expect(req.messages[1]['content'], kInterruptedToolResultPlaceholder);
    });

    test('已压缩的工具结果用占位符（prune 语义，体积最小）', () async {
      final req = await AnthropicProtocol().buildRequest(
        history: [
          assistantWithTools([
            ToolCallData(
              id: 'toolu_c',
              name: 'web_search',
              arguments: const {},
              status: ToolCallStatus.completed,
              result: kCompactedToolResultPlaceholder,
              compactedAt: DateTime(2026),
            ),
          ]),
        ],
      );
      final blocks =
          ((req.messages[1]['content'] as List).first as Map)['content'];
      expect(blocks, kCompactedToolResultPlaceholder);
    });

    test('附件与工具链并存（content parts + tool_calls）', () async {
      final att = Attachment(
        fileName: 'p.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: '/nonexistent',
        fileSize: 100,
      )..base64Data = 'cGhvdG8=';
      final req = await OpenAIProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'assistant',
            content: '看图',
            attachments: [att],
            toolCalls: [
              const ToolCallData(
                id: 'call_1',
                name: 't',
                arguments: {},
                status: ToolCallStatus.completed,
                result: 'ok',
              ),
            ],
          ),
        ],
      );
      final assistant = req.messages[0];
      final parts = (assistant['content'] as List).cast<Map>();
      expect(parts, hasLength(2)); // text + image
      expect(assistant['tool_calls'], hasLength(1));
      expect(req.messages[1]['role'], 'tool');
    });

    test('OpenAI 重建时保留 reasoning_content（DeepSeek 兼容）', () async {
      final req = await OpenAIProtocol().buildRequest(
        history: [
          assistantWithTools(
            [
              const ToolCallData(
                id: 'call_1',
                name: 't',
                arguments: {},
                status: ToolCallStatus.completed,
                result: 'ok',
              ),
            ],
            content: '回答',
          ).copyWith(reasoningContent: '思考过程'),
        ],
      );
      expect(req.messages[0]['reasoning_content'], '思考过程');
    });
  });

  group('createChatProtocol', () {
    test('按端点类型返回对应协议', () {
      expect(createChatProtocol('anthropic'), isA<AnthropicProtocol>());
      expect(createChatProtocol('openai'), isA<OpenAIProtocol>());
      expect(createChatProtocol('unknown'), isA<OpenAIProtocol>());
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // readAttachmentBase64 —— 超限图片自动压缩（用户已选择就必须发送）
  // ═════════════════════════════════════════════════════════════════════
  group('readAttachmentBase64 图片超限自动压缩', () {
    /// 照片风格大 PNG 夹具（约 3.6MB），全组共享只生成一次。
    late Uint8List bigPng;

    setUpAll(() {
      final rng = Random(7);
      final im = img.Image(width: 1600, height: 1200, numChannels: 3);
      for (final p in im) {
        final dx = p.x - 800;
        final dy = p.y - 600;
        final d = (dx * dx + dy * dy) / (1600 * 1200);
        p
          ..r = (128 + 50 * (d % 1) + rng.nextInt(18)).round().clamp(0, 255)
          ..g = (100 + 80 * (p.x / 1600) + rng.nextInt(18)).round().clamp(0, 255)
          ..b = (150 + 60 * (p.y / 1200) + rng.nextInt(18)).round().clamp(0, 255);
      }
      bigPng = img.encodePng(im, level: 6);
    });

    test('超限图片压缩后返回 ok，且带格式覆盖（PNG→JPEG）', () async {
      expect(bigPng.length, greaterThan(2 * 1024 * 1024),
          reason: '夹具 PNG 应显著大于测试上限');
      const maxBytes = 1024 * 1024;
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_photo.png',
        fileSize: bigPng.length,
      )..base64Data = base64Encode(bigPng);

      final outcome = await readAttachmentBase64(att, maxBytes: maxBytes);

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(outcome.base64, isNotNull);
      final payload = base64Decode(outcome.base64!);
      expect(payload.length, lessThan(maxBytes));
      expect(payload.length, lessThan(bigPng.length));
      // PNG 无损重编码无法达标 → 降级 JPEG，必须告知协议层格式已变
      expect(outcome.mimeType, 'image/jpeg');
      expect(img.decodeImage(payload), isNotNull);
    });

    test('未超限图片原样返回（字节不变，无格式覆盖）', () async {
      final tinyPng = img.encodePng(
        img.Image(width: 8, height: 8, numChannels: 3),
      );
      final b64 = base64Encode(tinyPng);
      final att = Attachment(
        fileName: 'small.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_small.png',
        fileSize: tinyPng.length,
      )..base64Data = b64;

      final outcome = await readAttachmentBase64(att);

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(outcome.base64, b64);
      expect(outcome.mimeType, isNull,
          reason: '未发生格式转换时不应覆盖 mimeType');
    });

    test('超限非图片（音频）仍返回 tooLarge（不读盘）', () async {
      final fakeAudio = Uint8List.fromList(List.filled(11 * 1024 * 1024, 0x55));
      final att = Attachment(
        fileName: 'big.wav',
        mimeType: 'audio/wav',
        fileType: 'audio',
        hash: 'h',
        storagePath: 'attachments/h_big.wav',
        fileSize: fakeAudio.length,
      )..base64Data = base64Encode(fakeAudio);

      final outcome = await readAttachmentBase64(att);

      expect(outcome.status, AttachmentReadStatus.tooLarge);
      expect(outcome.base64, isNull);
    });

    test('超限但无法解码的图片返回 tooLarge（发送必然失败，不发垃圾载荷）',
        () async {
      // 可解码但压缩无收益的图片才"必须发送"；无法解码（如 HEIC/损坏
      // 文件）的图片即使发送 API 也无法读取 → 保持跳过占位。
      final garbage = Uint8List.fromList(List.filled(11 * 1024 * 1024, 0xAB));
      final att = Attachment(
        fileName: 'broken.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_broken.png',
        fileSize: garbage.length,
      )..base64Data = base64Encode(garbage);

      final outcome = await readAttachmentBase64(att);

      expect(outcome.status, AttachmentReadStatus.tooLarge);
      expect(outcome.base64, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 协议层：超限图片必须作为图片发送，而不是占位文本
  // ═════════════════════════════════════════════════════════════════════
  group('协议层超限图片自动压缩发送', () {
    test('OpenAI 协议：>10MB 图片压缩后以 image_url 发送', () async {
      // 2800x2100 照片风格 PNG ≈ 11MB，超过 10MB 上限
      final rng = Random(11);
      final im = img.Image(width: 2800, height: 2100, numChannels: 3);
      for (final p in im) {
        final dx = p.x - 1400;
        final dy = p.y - 1050;
        final d = (dx * dx + dy * dy) / (2800 * 2100);
        p
          ..r = (128 + 50 * (d % 1) + rng.nextInt(18)).round().clamp(0, 255)
          ..g = (100 + 80 * (p.x / 2800) + rng.nextInt(18)).round().clamp(0, 255)
          ..b = (150 + 60 * (p.y / 2100) + rng.nextInt(18)).round().clamp(0, 255);
      }
      final hugePng = img.encodePng(im, level: 6);
      expect(hugePng.length, greaterThan(10 * 1024 * 1024),
          reason: '夹具必须超过 10MB 上限才能触发压缩');

      final att = Attachment(
        fileName: 'huge_photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'huge',
        storagePath: 'attachments/huge_photo.png',
        fileSize: hugePng.length,
      )..base64Data = base64Encode(hugePng);

      final req = await OpenAIProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'user',
            content: '看这张图',
            attachments: [att],
          ),
        ],
      );
      final content = req.messages[0]['content'] as List;
      expect(content, hasLength(2));
      expect(content[0], {'type': 'text', 'text': '看这张图'});
      final part = content[1] as Map;
      expect(part['type'], 'image_url',
          reason: '超限图片必须发送，不能退化为“[图片过大已跳过]”占位文本');
      final url = ((part['image_url'] as Map)['url'] as String);
      expect(url.startsWith('data:image/jpeg;base64,'), isTrue,
          reason: '压缩后格式为 JPEG，data URI 必须声明新格式');
      final payload =
          base64Decode(url.substring('data:image/jpeg;base64,'.length));
      expect(payload.length, lessThan(10 * 1024 * 1024));
      expect(payload.length, lessThan(hugePng.length));
    });

    test('Anthropic 协议：超限图片压缩后 media_type 与内容一致', () async {
      final rng = Random(13);
      final im = img.Image(width: 2800, height: 2100, numChannels: 3);
      for (final p in im) {
        final dx = p.x - 1400;
        final dy = p.y - 1050;
        final d = (dx * dx + dy * dy) / (2800 * 2100);
        p
          ..r = (128 + 50 * (d % 1) + rng.nextInt(18)).round().clamp(0, 255)
          ..g = (100 + 80 * (p.x / 2800) + rng.nextInt(18)).round().clamp(0, 255)
          ..b = (150 + 60 * (p.y / 2100) + rng.nextInt(18)).round().clamp(0, 255);
      }
      final hugePng = img.encodePng(im, level: 6);
      expect(hugePng.length, greaterThan(10 * 1024 * 1024));

      final att = Attachment(
        fileName: 'huge_photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'huge',
        storagePath: 'attachments/huge_photo.png',
        fileSize: hugePng.length,
      )..base64Data = base64Encode(hugePng);

      final req = await AnthropicProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'user',
            content: '看这张图',
            attachments: [att],
          ),
        ],
      );
      final content = req.messages[0]['content'] as List;
      final imagePart = content
          .cast<Map>()
          .firstWhere((p) => p['type'] == 'image');
      final source = imagePart['source'] as Map;
      expect(source['media_type'], 'image/jpeg',
          reason: 'PNG→JPEG 压缩后 media_type 必须与真实内容一致');
      final payload = base64Decode(source['data'] as String);
      expect(payload.length, lessThan(10 * 1024 * 1024));
    });
  });
}
