import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/chat_protocol.dart';
import 'package:stroom/services/context_manager.dart'
    show kCompactedToolResultPlaceholder, kInterruptedToolResultPlaceholder;

/// 测试用 PathProvider：把"应用文档目录"指向临时目录，让
/// AttachmentStorage 的磁盘读写（含压缩缓存）落到真实临时文件上。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

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
          ..g =
              (100 + 80 * (p.x / 1600) + rng.nextInt(18)).round().clamp(0, 255)
          ..b =
              (150 + 60 * (p.y / 1200) + rng.nextInt(18)).round().clamp(0, 255);
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

    test('未超限图片原样返回（字节不变，格式按魔数检测）', () async {
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
      expect(outcome.base64, b64, reason: '阈值以内的图片字节必须原样保留');
      expect(outcome.mimeType, 'image/png', reason: '载荷格式按魔数检测（与声明一致时结果相同）');
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

    test('超限但无法解码的图片返回 tooLarge（发送必然失败，不发垃圾载荷）', () async {
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

    test('2~10MB 之间的图片在默认通用阈值下也会被压缩（所有图片都压缩）', () async {
      // 回归：旧行为只压缩 >10MB 的图片，3.6MB 的照片原样 base64
      // （约 4.8MB）发送，多张图 + 多轮历史重发很容易顶爆
      // Anthropic 32MB / Gemini 20MB 的请求体上限。
      // 现在默认阈值 2MB：3.6MB 的图压缩到 2MB 以内。
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_photo.png',
        fileSize: bigPng.length,
      )..base64Data = base64Encode(bigPng);

      final outcome = await readAttachmentBase64(att); // 默认 maxBytes=2MB

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(outcome.base64, isNotNull);
      final payload = base64Decode(outcome.base64!);
      expect(payload.length, lessThanOrEqualTo(2 * 1024 * 1024),
          reason: '超过通用阈值的图片必须压缩到阈值以内');
      expect(payload.length, lessThan(bigPng.length));
      expect(outcome.mimeType, 'image/jpeg');
      expect(img.decodeImage(payload), isNotNull);
    });

    test('低于 2MB 通用阈值的图片原样保留（真正无损，零开销）', () async {
      final rng = Random(21);
      final im = img.Image(width: 1024, height: 768, numChannels: 3);
      for (final p in im) {
        final dx = p.x - 512;
        final dy = p.y - 384;
        final d = (dx * dx + dy * dy) / (1024 * 768);
        p
          ..r = (128 + 50 * (d % 1) + rng.nextInt(14)).round().clamp(0, 255)
          ..g =
              (100 + 80 * (p.x / 1024) + rng.nextInt(14)).round().clamp(0, 255)
          ..b =
              (150 + 60 * (p.y / 768) + rng.nextInt(14)).round().clamp(0, 255);
      }
      final midPng = img.encodePng(im, level: 6);
      expect(midPng.length, lessThan(2 * 1024 * 1024));
      expect(midPng.length, greaterThan(512 * 1024),
          reason: '夹具应处于 0.5~2MB 之间才有区分度');
      final b64 = base64Encode(midPng);
      final att = Attachment(
        fileName: 'mid.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_mid.png',
        fileSize: midPng.length,
      )..base64Data = b64;
      final outcome = await readAttachmentBase64(att);

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(outcome.base64, b64, reason: '阈值以内的图片必须字节原样保留（无损优先）');
      expect(outcome.mimeType, 'image/png', reason: '载荷格式按魔数检测');
    });

    test('压缩结果缓存复用（下一轮发送）时格式覆盖不丢失', () async {
      // 回归：第一轮把 PNG 压缩成 JPEG 并回写缓存后，第二轮命中缓存
      // （压缩后载荷 ≤ 阈值，不再压缩）——若格式覆盖在此路径丢失，
      // JPEG 载荷会被声明成 image/png，Anthropic 会整条 400。
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'h',
        storagePath: 'attachments/h_photo.png',
        fileSize: bigPng.length,
      )..base64Data = base64Encode(bigPng);

      final first = await readAttachmentBase64(att);
      expect(first.status, AttachmentReadStatus.ok);
      expect(first.mimeType, 'image/jpeg');
      final firstPayload = base64Decode(first.base64!);
      expect(firstPayload.length, lessThanOrEqualTo(2 * 1024 * 1024));

      // 第二轮：命中缓存，载荷不变
      final second = await readAttachmentBase64(att);
      expect(second.status, AttachmentReadStatus.ok);
      expect(second.base64, first.base64, reason: '缓存应直接复用压缩结果');
      final secondPayload = base64Decode(second.base64!);
      expect(secondPayload[0], 0xFF);
      expect(secondPayload[1], 0xD8, reason: '载荷仍是 JPEG');
      expect(second.mimeType, 'image/jpeg',
          reason: '缓存复用路径不得丢失格式覆盖（否则 Anthropic 整条 400）');
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
          ..g =
              (100 + 80 * (p.x / 2800) + rng.nextInt(18)).round().clamp(0, 255)
          ..b =
              (150 + 60 * (p.y / 2100) + rng.nextInt(18)).round().clamp(0, 255);
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
          ..g =
              (100 + 80 * (p.x / 2800) + rng.nextInt(18)).round().clamp(0, 255)
          ..b =
              (150 + 60 * (p.y / 2100) + rng.nextInt(18)).round().clamp(0, 255);
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
      final imagePart =
          content.cast<Map>().firstWhere((p) => p['type'] == 'image');
      final source = imagePart['source'] as Map;
      expect(source['media_type'], 'image/jpeg',
          reason: 'PNG→JPEG 压缩后 media_type 必须与真实内容一致');
      final payload = base64Decode(source['data'] as String);
      expect(payload.length, lessThan(10 * 1024 * 1024));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 图片压缩磁盘缓存（temp_compressed/<convId>/<hash>）
  // —— 选中即后台预压缩 + 重启后零等待复用
  // ═════════════════════════════════════════════════════════════════════
  group('图片压缩磁盘缓存', () {
    late Directory tmpRoot;

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
          ..g =
              (100 + 80 * (p.x / 1600) + rng.nextInt(18)).round().clamp(0, 255)
          ..b =
              (150 + 60 * (p.y / 1200) + rng.nextInt(18)).round().clamp(0, 255);
      }
      bigPng = img.encodePng(im, level: 6);
      expect(bigPng.length, greaterThan(2 * 1024 * 1024),
          reason: '夹具 PNG 应显著大于测试上限');
    });

    setUp(() {
      tmpRoot = Directory.systemTemp.createTempSync('stroom_chat_proto_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tmpRoot.path);
    });

    tearDown(() {
      try {
        tmpRoot.deleteSync(recursive: true);
      } catch (_) {
        // 非关键清理
      }
    });

    /// 把 [bytes] 落盘为普通附件并返回其 storagePath（模拟"附件已在
    /// 磁盘上，内存缓存 base64Data 丢失"的重启场景）。
    Future<String> saveOriginalFile(String fileName, Uint8List bytes) async {
      return AttachmentStorage.saveFile(fileName, bytes);
    }

    test('preCompressImageForPendingAttachment：大图压缩并写入内存+磁盘缓存',
        () async {
      const maxBytes = 500 * 1024;
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'pre-hash',
        storagePath: '/nonexistent',
        fileSize: bigPng.length,
      );

      final done = await preCompressImageForPendingAttachment(
        att,
        bigPng,
        maxBytes: maxBytes,
        conversationId: 'conv-1',
      );

      expect(done, isTrue);
      // 内存缓存：base64Data 变为压缩产物（≤ 阈值）
      final inMemory = base64Decode(att.base64Data!);
      expect(inMemory.length, lessThanOrEqualTo(maxBytes));
      expect(inMemory.length, lessThan(bigPng.length));
      expect(img.decodeImage(inMemory), isNotNull);
      // 磁盘缓存：按 (convId, hash) 可读回同一份字节
      final cached = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'pre-hash');
      expect(cached, isNotNull);
      expect(cached!.bytes, inMemory);
      expect(att.compressedCachePersisted, isTrue);
    });

    test('preCompressImageForPendingAttachment：阈值内/无法解码为 no-op',
        () async {
      // 阈值内：不压缩，base64Data 保持 null
      final small = img.encodePng(
        img.Image(width: 8, height: 8, numChannels: 3),
      );
      final smallAtt = Attachment(
        fileName: 'small.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'small-hash',
        storagePath: '/nonexistent',
        fileSize: small.length,
      );
      final smallDone = await preCompressImageForPendingAttachment(
        smallAtt,
        small,
        maxBytes: 10 * 1024 * 1024,
        conversationId: 'conv-1',
      );
      expect(smallDone, isFalse);
      expect(smallAtt.base64Data, isNull);

      // 无法解码：不写入任何缓存
      final garbage = Uint8List.fromList(List.generate(256, (i) => i * 7 % 256));
      final garbageAtt = Attachment(
        fileName: 'broken.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'garbage-hash',
        storagePath: '/nonexistent',
        fileSize: garbage.length,
      );
      final garbageDone = await preCompressImageForPendingAttachment(
        garbageAtt,
        garbage,
        maxBytes: 128,
        conversationId: 'conv-1',
      );
      expect(garbageDone, isFalse);
      expect(garbageAtt.base64Data, isNull);
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-1', hash: 'garbage-hash'),
          isNull);
    });

    test('preCompressImageForPendingAttachment：附件已失效（移除/编辑）时跳过写入',
        () async {
      // 回归：压缩耗时期间附件被移除/编辑（isStillRelevant 返回 false），
      // 不得写入任何缓存——否则会把已被清理的磁盘缓存"复活"
      // （对话已删除时成为永久孤儿目录）。
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'stale-hash',
        storagePath: '/nonexistent',
        fileSize: bigPng.length,
      );

      final done = await preCompressImageForPendingAttachment(
        att,
        bigPng,
        maxBytes: 500 * 1024,
        conversationId: 'conv-1',
        isStillRelevant: () => false,
      );

      expect(done, isFalse);
      expect(att.base64Data, isNull, reason: '失效后不得写入内存缓存');
      expect(
          await AttachmentStorage.readCompressedImage(
              conversationId: 'conv-1', hash: 'stale-hash'),
          isNull,
          reason: '失效后不得写入磁盘缓存（否则复活已被清理的文件）');
    });

    test('readAttachmentBase64：重启后（无 base64Data）命中磁盘缓存，零等待复用',
        () async {
      // 种子缓存故意用 q30（与压缩器 q90 输出不同）：若命中缓存则
      // 逐字节复用，若代码回退到重新压缩则会产出 q90 字节 → 断言失败，
      // 由此证明磁盘缓存路径没有重新压缩。
      final decoded = img.decodeImage(bigPng)!;
      final seeded = img.encodeJpg(decoded,
          quality: 30, chroma: img.JpegChroma.yuv420);
      expect(seeded.length, lessThan(500 * 1024));
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-1',
        hash: 'restart-hash',
        bytes: seeded,
        mimeType: 'image/jpeg',
      );
      final storagePath = await saveOriginalFile('photo.png', bigPng);

      // 模拟重启：新 Attachment 无 base64Data，原始文件在磁盘上
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'restart-hash',
        storagePath: storagePath,
        fileSize: bigPng.length,
        conversationId: 'conv-1',
      );

      final outcome = await readAttachmentBase64(att, maxBytes: 500 * 1024);

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(base64Decode(outcome.base64!), seeded,
          reason: '必须逐字节复用磁盘缓存，而不是重新压缩');
      expect(outcome.mimeType, 'image/jpeg');
    });

    test('readAttachmentBase64：发送时压缩会写入磁盘缓存，重启后直接复用', () async {
      const maxBytes = 500 * 1024;
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'send-hash',
        storagePath: '/nonexistent',
        fileSize: bigPng.length,
        conversationId: 'conv-1',
      )..base64Data = base64Encode(bigPng);

      final first = await readAttachmentBase64(att, maxBytes: maxBytes);
      expect(first.status, AttachmentReadStatus.ok);
      final firstPayload = base64Decode(first.base64!);
      expect(firstPayload.length, lessThanOrEqualTo(maxBytes));

      // 压缩产物已落盘
      final cached = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'send-hash');
      expect(cached, isNotNull);
      expect(cached!.bytes, firstPayload);

      // 模拟重启：同一附件的新实例（无 base64Data），原始文件在盘上
      final storagePath = await saveOriginalFile('photo.png', bigPng);
      final fresh = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'send-hash',
        storagePath: storagePath,
        fileSize: bigPng.length,
        conversationId: 'conv-1',
      );

      final second = await readAttachmentBase64(fresh, maxBytes: maxBytes);
      expect(second.status, AttachmentReadStatus.ok);
      expect(second.base64, first.base64,
          reason: '重启后应直接复用磁盘缓存，产出与首次发送相同的载荷');
    });

    test('缓存按对话隔离：convA 的缓存不泄露给 convB', () async {
      // 只为 convA 写入缓存
      final decoded = img.decodeImage(bigPng)!;
      final seeded = img.encodeJpg(decoded,
          quality: 30, chroma: img.JpegChroma.yuv420);
      await AttachmentStorage.saveCompressedImage(
        conversationId: 'conv-a',
        hash: 'shared-hash',
        bytes: seeded,
        mimeType: 'image/jpeg',
      );

      // 同一 hash 在 convB：磁盘未命中 → 回退到发送时压缩（q90 输出）
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'shared-hash',
        storagePath: '/nonexistent',
        fileSize: bigPng.length,
        conversationId: 'conv-b',
      )..base64Data = base64Encode(bigPng);

      final outcome = await readAttachmentBase64(att, maxBytes: 500 * 1024);

      expect(outcome.status, AttachmentReadStatus.ok);
      final payload = base64Decode(outcome.base64!);
      expect(payload, isNot(equals(seeded)),
          reason: '对话 B 不得复用对话 A 的缓存，应重新压缩');
      expect(payload.length, lessThanOrEqualTo(500 * 1024));
      // 对话 B 现在有自己的缓存（互不干扰）
      final cacheB = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-b', hash: 'shared-hash');
      expect(cacheB, isNotNull);
      expect(cacheB!.bytes, payload);
    });

    test('readAttachmentBase64：内存缓存命中（选中时已预压缩）补齐磁盘缓存',
        () async {
      // 场景：选中时对话尚未创建（conversationId=null），预压缩只写了
      // 内存缓存；发送时对话已解析，首次经过发送路径应把压缩产物落盘。
      const maxBytes = 500 * 1024;
      final decoded = img.decodeImage(bigPng)!;
      final preCompressed = img.encodeJpg(decoded,
          quality: 80, chroma: img.JpegChroma.yuv420);
      expect(preCompressed.length, lessThanOrEqualTo(maxBytes));

      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'mem-hash',
        storagePath: '/nonexistent',
        fileSize: bigPng.length, // 原始文件仍超阈值 → 内存字节必为压缩产物
        conversationId: 'conv-1',
      )..base64Data = base64Encode(preCompressed);

      final outcome = await readAttachmentBase64(att, maxBytes: maxBytes);

      expect(outcome.status, AttachmentReadStatus.ok);
      expect(outcome.base64, base64Encode(preCompressed),
          reason: '内存缓存直接复用，不做无谓重压缩');
      // 分支 2 自身不设置 mimeTypeOverride，格式覆盖来自共享的魔数
      // 检测兜底：JPEG 载荷必须声明 image/jpeg（否则 Anthropic 400）
      expect(outcome.mimeType, 'image/jpeg');
      final cached = await AttachmentStorage.readCompressedImage(
          conversationId: 'conv-1', hash: 'mem-hash');
      expect(cached, isNotNull,
          reason: '首次发送路径应补齐磁盘缓存（重启后不再等待）');
      expect(cached!.bytes, preCompressed);
    });
  });
}
