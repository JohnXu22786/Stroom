import 'dart:convert';

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import 'chat_protocol.dart';

// ============================================================================
// Anthropic 兼容协议的 Messages API 实现
// ============================================================================

/// Anthropic document 块官方仅支持 application/pdf：其他二进制类型
/// （docx/xlsx/zip 等）走 document 块会被 API 以 400 拒绝整条请求，
/// 因此只对 PDF 使用 document 块，其余降级为占位文本。
bool _isPdfAttachment(Attachment att) {
  if (att.mimeType.toLowerCase() == 'application/pdf') return true;
  final name = att.fileName.toLowerCase();
  return name.endsWith('.pdf');
}

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
      final toolCalls = msg.toolCalls;
      final hasToolCalls = toolCalls != null && toolCalls.isNotEmpty;

      if (msg.attachments.isEmpty && !hasToolCalls) {
        result.add({'role': msg.role, 'content': msg.content});
        continue;
      }

      // 组装内容块（文本 + 附件；无附件时保持字符串形式）
      Object content;
      if (msg.attachments.isEmpty) {
        content = msg.content;
      } else {
        final parts = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          parts.add({'type': 'text', 'text': msg.content});
        }
        for (final att in msg.attachments) {
          // 'file' 是旧数据的遗留分类（composer 现只产出
          // image/audio/video/document）：按 document 处理保持兼容。
          if (att.fileType == 'image' ||
              att.fileType == 'file' ||
              att.fileType == 'document') {
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
                  'media_type': outcome.mimeType ?? att.mimeType,
                  'data': outcome.base64,
                },
              });
            } else if (_isPdfAttachment(att)) {
              // Anthropic document 块官方仅支持 application/pdf：
              // 其他二进制类型（docx/xlsx/zip 等）走 document 块会被
              // API 以 400 拒绝整条请求，降级为占位文本。
              // media_type 固定 application/pdf：文件名判定的 PDF
              // 可能携带错误 mimeType（picker 标为 octet-stream），
              // 发真实 mimeType 同样会被 400。
              parts.add({
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': 'application/pdf',
                  'data': outcome.base64,
                },
                'title': att.fileName,
              });
            } else {
              parts.add({
                'type': 'text',
                'text': '[文件类型在 Anthropic 格式下不支持，已跳过: ${att.fileName}]',
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
              // 非文本且非 image/audio/video 分类的（如 application/octet-stream）：
              // 仅 PDF 可走 document 块（官方白名单），其余降级占位。
              final outcome = await readAttachmentBase64(att);
              if (outcome.status == AttachmentReadStatus.ok &&
                  _isPdfAttachment(att)) {
                parts.add({
                  'type': 'document',
                  'source': {
                    'type': 'base64',
                    // 同上方：文件名判定为 PDF 时固定 application/pdf
                    'media_type': 'application/pdf',
                    'data': outcome.base64,
                  },
                  'title': att.fileName,
                });
              } else {
                parts.add({
                  'type': 'text',
                  'text': '[${att.fileName} - 无法读取或类型不支持，已跳过]',
                });
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
      // assistant 消息携带 tool_use 块，紧跟一条 user 消息
      // 含全部 tool_result 块（官方配对要求）。
      final assistantBlocks = <Map<String, dynamic>>[];
      if (content is String) {
        if (content.isNotEmpty) {
          assistantBlocks.add({'type': 'text', 'text': content});
        }
      } else {
        assistantBlocks.addAll((content as List).cast<Map<String, dynamic>>());
      }
      for (final tc in toolCalls) {
        assistantBlocks.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.name,
          'input': tc.arguments,
        });
      }
      result.add({'role': 'assistant', 'content': assistantBlocks});
      result.add({
        'role': 'user',
        'content': [
          for (final tc in toolCalls)
            {
              'type': 'tool_result',
              'tool_use_id': tc.id,
              'content': rebuildToolResultText(tc),
            },
        ],
      });
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
              // 发送给模型时渲染截断（存储完整）
              'content': truncateToolOutput(r.result),
            },
        ],
      },
    ];
  }
}
