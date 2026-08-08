import 'dart:convert';

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import 'chat_protocol.dart';
import 'chat_service_shared.dart' show audioFormatFromMimeType, imageExtension;

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
      final toolCalls = msg.toolCalls;
      final hasToolCalls = toolCalls != null && toolCalls.isNotEmpty;

      if (msg.attachments.isEmpty && !hasToolCalls) {
        result.add({'role': msg.role, 'content': msg.content});
        continue;
      }

      // 组装内容（文本 + 附件 parts；无附件时保持字符串形式）
      Object content;
      if (msg.attachments.isEmpty) {
        content = msg.content;
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
            final ext = imageExtension(outcome.mimeType ?? att.mimeType);
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
        content = parts;
      }

      if (!hasToolCalls) {
        result.add({'role': msg.role, 'content': content});
        continue;
      }

      // ── 工具链重建（历史跨轮次保留工具调用与结果）──
      // assistant 消息携带 tool_calls，紧跟 N 条 tool 结果消息
      // （OpenAI 规格：tool 消息必须紧跟在对应 assistant 之后）。
      // 结果缺失/未完成/已压缩时用占位文本保证配对完整性。
      final assistantMsg = <String, dynamic>{
        'role': 'assistant',
        'content': content,
        'tool_calls': [
          for (final tc in toolCalls)
            {
              'id': tc.id,
              'type': 'function',
              'function': {
                'name': tc.name,
                'arguments': jsonEncode(tc.arguments),
              },
            },
        ],
      };
      // DeepSeek 兼容：重建时保留推理内容
      if (msg.reasoningContent != null && msg.reasoningContent!.isNotEmpty) {
        assistantMsg['reasoning_content'] = msg.reasoningContent;
      }
      result.add(assistantMsg);
      for (final tc in toolCalls) {
        result.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': rebuildToolResultText(tc),
        });
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
          // 发送给模型时渲染截断（存储完整）
          'content': truncateToolOutput(r.result),
        },
    ];
  }
}
