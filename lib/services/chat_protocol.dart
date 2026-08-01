import 'dart:convert';
import 'dart:typed_data';

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import 'attachment_storage.dart';
import 'chat_service_shared.dart' show audioFormatFromMimeType, imageExtension;

// ============================================================================
// ChatProtocol — 聊天协议抽象层
// ============================================================================
//
// 对话数据（ChatMessage / ToolCallData / MessageBlock）是协议中立的，
// 每次请求都从"中立历史"经协议重建为具体的 API 格式（OpenAI 兼容 /
// Anthropic Messages）。这保证了用户中途切换端点类型（甚至切换供应商）
// 后，下一条请求自动使用新格式，无需迁移历史数据。
//
// 协议实现必须是纯函数、无状态的（除单轮内的 thinking 签名透传）：
// 绝不持久化 API 原始格式的消息。
// ============================================================================

/// 一次协议构建请求的结果。
///
/// [messages] 是 API 格式的 message 列表；[system] 是 Anthropic 风格
/// 的顶层 system 字段（OpenAI 协议返回 null，system 提示词以
/// role=system 消息的形式包含在 [messages] 中）。
class ProtocolRequest {
  final List<Map<String, dynamic>> messages;
  final String? system;

  const ProtocolRequest({required this.messages, this.system});
}

/// 协议中立的工具调用表示，供工具循环使用。
///
/// 无论底层是 OpenAI 的 tool_calls 还是 Anthropic 的 tool_use 块，
/// 统一转换为 (id, name, argumentsJson)。argumentsJson 保持 JSON 字符串
/// 形态，与 OpenAI 流的 arguments 一致，便于解析与重放。
class NeutralToolCall {
  final String id;
  final String name;
  final String argumentsJson;

  const NeutralToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });
}

/// 一次工具执行的结果（协议中立）。
class ToolCallResult {
  final String toolCallId;
  final String result;

  const ToolCallResult({required this.toolCallId, required this.result});
}

/// 将 provider 事件里的工具调用（OpenAI 形状或 Anthropic 形状）
/// 归一化为 [NeutralToolCall]。
NeutralToolCall normalizeToolCall(Map<String, dynamic> tc) {
  final fn = tc['function'] as Map<String, dynamic>?;
  if (fn != null) {
    // OpenAI 形状: {id, type, function: {name, arguments}}
    return NeutralToolCall(
      id: tc['id'] as String? ?? '',
      name: fn['name'] as String? ?? 'unknown',
      argumentsJson: fn['arguments'] as String? ?? '{}',
    );
  }
  // Anthropic 形状: {id, name, input}
  final input = tc['input'];
  return NeutralToolCall(
    id: tc['id'] as String? ?? '',
    name: tc['name'] as String? ?? 'unknown',
    argumentsJson:
        input is Map ? jsonEncode(input) : (input?.toString() ?? '{}'),
  );
}

/// 附件读取结果状态。
enum AttachmentReadStatus { ok, tooLarge, unreadable }

/// 附件 base64 读取结果。
class AttachmentReadOutcome {
  final AttachmentReadStatus status;
  final String? base64;

  const AttachmentReadOutcome(this.status, this.base64);
}

/// 单个附件允许的最大字节数（10 MB，与既有逻辑一致）。
const int maxAttachmentBytes = 10 * 1024 * 1024;

/// 读取附件 base64 载荷，遵守 10 MB 上限。
///
/// 优先使用附件内存缓存（[Attachment.base64Data]），避免重复读取磁盘。
/// 超过大小限制返回 [AttachmentReadStatus.tooLarge]，
/// 读取失败返回 [AttachmentReadStatus.unreadable]。
Future<AttachmentReadOutcome> readAttachmentBase64(Attachment att) async {
  if (att.base64Data != null && att.base64Data!.isNotEmpty) {
    // 已缓存：检查大小（即使缓存也可能超限）
    if (att.fileSize > maxAttachmentBytes) {
      return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
    }
    return AttachmentReadOutcome(AttachmentReadStatus.ok, att.base64Data);
  }
  // 未缓存：先按大小检查避免加载超大文件
  if (att.fileSize > maxAttachmentBytes) {
    return const AttachmentReadOutcome(AttachmentReadStatus.tooLarge, null);
  }
  final bytes = await AttachmentStorage.readFile(att.storagePath);
  if (bytes == null || bytes.isEmpty) {
    return const AttachmentReadOutcome(AttachmentReadStatus.unreadable, null);
  }
  final b64 = base64Encode(bytes);
  // 缓存 base64 供后续复用
  att.base64Data = b64;
  return AttachmentReadOutcome(AttachmentReadStatus.ok, b64);
}

/// 文本类附件的扩展名列表（可从文件中读取 UTF-8 文本）。
const List<String> textAttachmentExtensions = [
  // Documentation & markup
  'txt',
  'md',
  'tex',
  'rst',
  'asciidoc',
  // Data & config
  'json',
  'csv',
  'log',
  'yaml',
  'yml',
  'xml',
  'toml',
  'ini',
  'cfg',
  'conf',
  'env',
  'properties',
  'plist',
  // Web
  'html',
  'htm',
  'css',
  'scss',
  'less',
  'svg',
  // Shell & scripts
  'sh',
  'bash',
  'zsh',
  'ps1',
  'bat',
  'cmd',
  'py',
  'js',
  'ts',
  'jsx',
  'tsx',
  'dart',
  'java',
  'cpp',
  'c',
  'h',
  'hpp',
  'rs',
  'go',
  'rb',
  'php',
  'swift',
  'kt',
  'scala',
  'r',
  'lua',
  'pl',
  'sql',
  // Git & project
  'gitignore',
  'editorconfig',
  'makefile',
  'dockerfile',
];

/// 读取文本类附件的内容，超长（>4000 字符）截断。
/// 失败返回 null。
Future<String?> readTextAttachmentContent(
  String fileName,
  String storagePath,
) async {
  try {
    final bytes = await AttachmentStorage.readFile(storagePath);
    if (bytes == null || bytes.isEmpty) return null;
    final textContent = utf8.decode(bytes);
    if (textContent.length > 4000) {
      return '${textContent.substring(0, 4000)}\n... [truncated]';
    }
    return textContent;
  } catch (_) {
    return null;
  }
}

/// 附件是否为文本类型（可读取内容）。
bool isTextAttachment(Attachment att) {
  final ext = att.fileName.split('.').last.toLowerCase();
  return textAttachmentExtensions.contains(ext);
}

/// 读取非文本附件的原始字节（用于 PDF 等文档）。
/// 返回 null 表示无法读取。
Future<Uint8List?> readRawAttachmentBytes(Attachment att) async {
  if (att.base64Data != null && att.base64Data!.isNotEmpty) {
    try {
      return base64Decode(att.base64Data!);
    } catch (_) {
      // 缓存损坏，回退到磁盘读取
    }
  }
  return AttachmentStorage.readFile(att.storagePath);
}

// ============================================================================
// 抽象协议
// ============================================================================

abstract class ChatProtocol {
  /// 协议名称：'openai' | 'anthropic'
  String get name;

  /// 将中立历史构建为 API 请求消息。
  ///
  /// [assistantPrompt] 为对话助手的系统提示词（OpenAI 协议会将其作为
  /// system 消息前置；Anthropic 协议放入 [ProtocolRequest.system]）。
  ///
  /// [contextSummary] 为上下文压缩产生的锚定摘要（对话被压缩过时传入），
  /// 以 system 级内容注入（OpenAI：附加 system 消息；Anthropic：system 拼接）。
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
  });

  /// 将工具定义转换为协议要求的 JSON 数组。
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools);

  /// 构建携带工具调用（及可选推理内容）的助手消息，用于工具循环链。
  ///
  /// [content] 当前轮累计的可见文本；[roundReasoning] 当前轮推理文本；
  /// [thinkingSignature] Anthropic extended thinking 签名（仅 anthropic 使用）。
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  });

  /// 构建工具结果消息，紧跟在助手消息之后。
  List<Map<String, dynamic>> buildToolResultMessages(
      List<ToolCallResult> results);

  /// 返回"禁用工具"的请求体参数（tool_choice: none 的协议差异）。
  ///
  /// 与 tools 一起发送：收尾轮仍需携带工具定义（Anthropic 要求
  /// 历史含 tool_use/tool_result 块时必须定义 tools），
  /// 用 tool_choice: none 显式禁止调用。
  Map<String, dynamic> toolChoiceNoneJson();
}

/// 根据端点类型创建协议实例。
///
/// [endpointType] 取值 'anthropic' 或 'openai'（默认）。
ChatProtocol createChatProtocol(String endpointType) {
  return endpointType == 'anthropic' ? AnthropicProtocol() : OpenAIProtocol();
}

/// 计算有效端点类型：模型覆盖 > 供应商 > 'openai'。
///
/// 旧配置（没有 endpointType 字段）天然落到 'openai'，即数据迁移的默认路径。
String effectiveEndpointType(
    String? modelEndpointType, String? providerEndpointType) {
  if (modelEndpointType != null && modelEndpointType.isNotEmpty) {
    return modelEndpointType;
  }
  if (providerEndpointType != null && providerEndpointType.isNotEmpty) {
    return providerEndpointType;
  }
  return 'openai';
}

// ============================================================================
// OpenAI 协议（官方 Chat Completions 兼容格式）
// ============================================================================

class OpenAIProtocol implements ChatProtocol {
  const OpenAIProtocol();

  @override
  String get name => 'openai';

  @override
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
  }) async {
    final result = <Map<String, dynamic>>[];

    // 合并 system 内容为单条消息：assistantPrompt + 压缩摘要。
    // 部分严格 OpenAI 兼容端点拒绝多条 system 消息。
    final systemParts = <String>[];
    if (assistantPrompt != null && assistantPrompt.trim().isNotEmpty) {
      systemParts.add(assistantPrompt);
    }
    if (contextSummary != null && contextSummary.trim().isNotEmpty) {
      systemParts.add('以下是此前对话的摘要（对话曾被压缩）:\n${contextSummary.trim()}');
    }
    if (systemParts.isNotEmpty) {
      result.add({'role': 'system', 'content': systemParts.join('\n\n')});
    }

    for (final msg in history) {
      if (msg.attachments.isEmpty) {
        result.add({'role': msg.role, 'content': msg.content});
      } else {
        final parts = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          parts.add({'type': 'text', 'text': msg.content});
        }
        for (final att in msg.attachments) {
          if (att.fileType == 'image') {
            final outcome = await readAttachmentBase64(att);
            switch (outcome.status) {
              case AttachmentReadStatus.tooLarge:
                parts.add({
                  'type': 'text',
                  'text': '[图片过大已跳过: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.unreadable:
                parts.add({
                  'type': 'text',
                  'text': '[图片加载失败: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.ok:
                break;
            }
            final ext = imageExtension(att.mimeType);
            parts.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/$ext;base64,${outcome.base64}'},
            });
          } else if (att.fileType == 'audio') {
            // ── Audio files: use input_audio format ──
            final outcome = await readAttachmentBase64(att);
            switch (outcome.status) {
              case AttachmentReadStatus.tooLarge:
                parts.add({
                  'type': 'text',
                  'text': '[音频文件过大已跳过: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.unreadable:
                parts.add({
                  'type': 'text',
                  'text': '[音频加载失败: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.ok:
                break;
            }
            final audioFormat = audioFormatFromMimeType(att.mimeType);
            parts.add({
              'type': 'input_audio',
              'input_audio': {
                'data': outcome.base64,
                'format': audioFormat,
              },
            });
          } else if (att.fileType == 'video') {
            // ── Video files: send as video_url with base64 data URI ──
            // OpenRouter supports the `video_url` content type for video files.
            final outcome = await readAttachmentBase64(att);
            switch (outcome.status) {
              case AttachmentReadStatus.tooLarge:
                parts.add({
                  'type': 'text',
                  'text': '[视频文件过大已跳过: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.unreadable:
                parts.add({
                  'type': 'text',
                  'text': '[视频加载失败: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.ok:
                break;
            }
            parts.add({
              'type': 'video_url',
              'video_url': {
                'url': 'data:${att.mimeType};base64,${outcome.base64}',
              },
            });
          } else {
            if (isTextAttachment(att)) {
              final textContent = await readTextAttachmentContent(
                  att.fileName, att.storagePath);
              if (textContent != null) {
                parts.add({
                  'type': 'text',
                  'text': '以下为文件 ${att.fileName} 的内容:\n$textContent',
                });
              } else {
                parts.add({
                  'type': 'text',
                  'text': '[${att.fileName} - 无法读取文件内容]',
                });
              }
            } else {
              // ── Non-text document files: send as file content part ──
              // OpenRouter supports the `file` content type for PDFs and other
              // documents. Format: { type: "file", file: { filename: "...",
              // file_data: "data:application/pdf;base64,..." } }
              if (att.fileSize > maxAttachmentBytes) {
                parts.add({
                  'type': 'text',
                  'text': '[文件过大已跳过: ${att.fileName}]',
                });
              } else {
                final bytes = await readRawAttachmentBytes(att);
                if (bytes != null && bytes.isNotEmpty) {
                  final b64 = base64Encode(bytes);
                  final dataUri = 'data:${att.mimeType};base64,$b64';
                  parts.add({
                    'type': 'file',
                    'file': {
                      'filename': att.fileName,
                      'file_data': dataUri,
                    },
                  });
                } else {
                  parts.add({
                    'type': 'text',
                    'text': '[${att.fileName} - 无法读取文件内容]',
                  });
                }
              }
            }
          }
        }
        result.add({'role': msg.role, 'content': parts});
      }
    }
    return ProtocolRequest(messages: result);
  }

  @override
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools) {
    return tools.map((t) => t.toJson()).toList(growable: false);
  }

  @override
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  }) {
    // Per DeepSeek Tool Calls guide: messages.append(message)
    // preserves the COMPLETE assistant message (including
    // reasoning_content) when sending subsequent requests
    // in the same tool call chain.
    final assistantMsg = <String, dynamic>{
      'role': 'assistant',
      'tool_calls': [
        for (final tc in toolCalls)
          {
            'id': tc.id,
            'type': 'function',
            'function': {'name': tc.name, 'arguments': tc.argumentsJson},
          },
      ],
      'content': content.isNotEmpty ? content : null,
    };
    // Preserve reasoning content so the model retains full context
    // across tool call chain rounds.
    if (roundReasoning != null && roundReasoning.isNotEmpty) {
      assistantMsg['reasoning_content'] = roundReasoning;
    }
    return [assistantMsg];
  }

  @override
  List<Map<String, dynamic>> buildToolResultMessages(
      List<ToolCallResult> results) {
    return [
      for (final r in results)
        {
          'role': 'tool',
          'tool_call_id': r.toolCallId,
          'content': r.result,
        },
    ];
  }

  @override
  Map<String, dynamic> toolChoiceNoneJson() => {'tool_choice': 'none'};
}

// ============================================================================
// Anthropic 协议（官方 Messages API 兼容格式）
// ============================================================================

class AnthropicProtocol implements ChatProtocol {
  const AnthropicProtocol();

  @override
  String get name => 'anthropic';

  @override
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
  }) async {
    final result = <Map<String, dynamic>>[];
    String? system;
    if (assistantPrompt != null && assistantPrompt.trim().isNotEmpty) {
      system = assistantPrompt;
    }
    // 压缩摘要拼入顶层 system（Anthropic system 仅文本）
    if (contextSummary != null && contextSummary.trim().isNotEmpty) {
      final summaryBlock = '以下是此前对话的摘要（对话曾被压缩）:\n'
          '${contextSummary.trim()}';
      system = system == null ? summaryBlock : '$system\n\n$summaryBlock';
    }

    for (final msg in history) {
      if (msg.attachments.isEmpty) {
        result.add({'role': msg.role, 'content': msg.content});
      } else {
        final parts = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          parts.add({'type': 'text', 'text': msg.content});
        }
        for (final att in msg.attachments) {
          if (att.fileType == 'image' || att.fileType == 'file') {
            // ── 图片 / 文档（PDF 等）: 官方 image/document 块 ──
            final outcome = await readAttachmentBase64(att);
            switch (outcome.status) {
              case AttachmentReadStatus.tooLarge:
                parts.add({
                  'type': 'text',
                  'text':
                      '[${att.fileType == 'image' ? '图片' : '文件'}过大已跳过: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.unreadable:
                parts.add({
                  'type': 'text',
                  'text':
                      '[${att.fileType == 'image' ? '图片' : '文件'}加载失败: ${att.fileName}]',
                });
                continue;
              case AttachmentReadStatus.ok:
                break;
            }
            if (att.fileType == 'image') {
              parts.add({
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': att.mimeType,
                  'data': outcome.base64,
                },
              });
            } else {
              parts.add({
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': att.mimeType,
                  'data': outcome.base64,
                },
                'title': att.fileName,
              });
            }
          } else if (att.fileType == 'audio' || att.fileType == 'video') {
            // ── Anthropic Messages API 官方不支持音频/视频输入 ──
            parts.add({
              'type': 'text',
              'text':
                  '[${att.fileType == 'audio' ? '音频' : '视频'}在 Anthropic 格式下不支持，已跳过: ${att.fileName}]',
            });
          } else {
            // ── 文本类文件：读取内容 ──
            if (isTextAttachment(att)) {
              final textContent = await readTextAttachmentContent(
                  att.fileName, att.storagePath);
              if (textContent != null) {
                parts.add({
                  'type': 'text',
                  'text': '以下为文件 ${att.fileName} 的内容:\n$textContent',
                });
              } else {
                parts.add({
                  'type': 'text',
                  'text': '[${att.fileName} - 无法读取文件内容]',
                });
              }
            } else {
              // 非文本且非 image/file 分类的（如 application/octet-stream）：
              // 尝试按 document 发送；失败则占位。
              final outcome = await readAttachmentBase64(att);
              if (outcome.status == AttachmentReadStatus.ok) {
                parts.add({
                  'type': 'document',
                  'source': {
                    'type': 'base64',
                    'media_type': att.mimeType,
                    'data': outcome.base64,
                  },
                  'title': att.fileName,
                });
              } else {
                parts.add({
                  'type': 'text',
                  'text': '[${att.fileName} - 无法读取文件内容]',
                });
              }
            }
          }
        }
        result.add({'role': msg.role, 'content': parts});
      }
    }
    return ProtocolRequest(messages: result, system: system);
  }

  @override
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools) {
    return [
      for (final t in tools)
        {
          'name': t.name,
          'description': t.description.isEmpty ? 'Tool' : t.description,
          'input_schema': t.parameters,
        },
    ];
  }

  @override
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  }) {
    final contentBlocks = <Map<String, dynamic>>[];
    // Extended thinking 块：仅当签名可用时才能续接（官方要求）。
    // 无签名时省略 thinking 块（渲染层仍显示推理内容）。
    if (roundReasoning != null &&
        roundReasoning.isNotEmpty &&
        thinkingSignature != null &&
        thinkingSignature.isNotEmpty) {
      contentBlocks.add({
        'type': 'thinking',
        'thinking': roundReasoning,
        'signature': thinkingSignature,
      });
    }
    if (content.isNotEmpty) {
      contentBlocks.add({'type': 'text', 'text': content});
    }
    for (final tc in toolCalls) {
      Map<String, dynamic> input = {};
      try {
        input = Map<String, dynamic>.from(jsonDecode(tc.argumentsJson));
      } catch (_) {
        input = {};
      }
      contentBlocks.add({
        'type': 'tool_use',
        'id': tc.id,
        'name': tc.name,
        'input': input,
      });
    }
    return [
      {'role': 'assistant', 'content': contentBlocks},
    ];
  }

  @override
  List<Map<String, dynamic>> buildToolResultMessages(
      List<ToolCallResult> results) {
    // Anthropic 官方：所有 tool_result 块放在同一条 user 消息中，
    // 每个 tool_use 必须有对应的 tool_result。
    return [
      {
        'role': 'user',
        'content': [
          for (final r in results)
            {
              'type': 'tool_result',
              'tool_use_id': r.toolCallId,
              'content': r.result,
            },
        ],
      },
    ];
  }

  @override
  Map<String, dynamic> toolChoiceNoneJson() => {
        'tool_choice': {'type': 'none'},
      };
}
