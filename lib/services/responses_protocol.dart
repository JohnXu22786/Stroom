import 'dart:convert';

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import 'chat_protocol.dart';
import 'chat_service_shared.dart' show audioFormatFromMimeType;

/// Protocol-neutral conversation history encoded for OpenAI's Responses API.
///
/// Responses uses an `input` item stream rather than Chat Completions' role
/// messages. Function calls and their outputs are separate items and must stay
/// adjacent in history so Stroom can replay local tool loops without server
/// response state.
class ResponsesProtocol implements ChatProtocol {
  const ResponsesProtocol();

  @override
  String get name => 'responses';

  @override
  Future<ProtocolRequest> buildRequest({
    required List<ChatMessage> history,
    String? assistantPrompt,
    String? contextSummary,
    int? toolOutputMaxChars,
    RequestContentCache? contentCache,
  }) async {
    final instructions = <String>[];
    if (assistantPrompt != null && assistantPrompt.trim().isNotEmpty) {
      instructions.add(assistantPrompt.trim());
    }
    if (contextSummary != null && contextSummary.trim().isNotEmpty) {
      instructions.add('以下是此前对话的摘要（对话曾被压缩）:\n${contextSummary.trim()}');
    }

    final input = <Map<String, dynamic>>[];
    for (final msg in history) {
      final messageContent = contentCache?.contentFor(msg) ?? msg.content;
      final calls = msg.toolCalls;
      final hasToolCalls = calls != null && calls.isNotEmpty;
      final parts = <Map<String, dynamic>>[];
      if (!hasToolCalls && messageContent.isNotEmpty) {
        parts.add({
          'type': 'input_text',
          'text': messageContent,
        });
      }
      for (final att in msg.attachments) {
        if (att.fileType == 'image') {
          if (msg.role == 'assistant') {
            parts.add({
              'type': 'input_text',
              'text': '[此前回复包含图片: ${att.fileName}]',
            });
            continue;
          }
          final outcome = await readAttachmentBase64(att);
          switch (outcome.status) {
            case AttachmentReadStatus.tooLarge:
              parts.add({
                'type': 'input_text',
                'text': '[图片过大已跳过: ${att.fileName}]',
              });
              continue;
            case AttachmentReadStatus.unreadable:
              parts.add({
                'type': 'input_text',
                'text': '[图片加载失败: ${att.fileName}]',
              });
              continue;
            case AttachmentReadStatus.ok:
              break;
          }
          final mime = outcome.mimeType ?? att.mimeType;
          parts.add({
            'type': 'input_image',
            'image_url': 'data:$mime;base64,${outcome.base64}',
          });
        } else if (att.fileType == 'audio') {
          final format = _responsesAudioFormat(att.mimeType);
          if (format == null) {
            parts.add({
              'type': 'input_text',
              'text': '[Responses 格式暂不支持此音频格式，已跳过: ${att.fileName}]',
            });
            continue;
          }
          final outcome = await readAttachmentBase64(att);
          switch (outcome.status) {
            case AttachmentReadStatus.tooLarge:
              parts.add({
                'type': 'input_text',
                'text': '[音频文件过大已跳过: ${att.fileName}]',
              });
              continue;
            case AttachmentReadStatus.unreadable:
              parts.add({
                'type': 'input_text',
                'text': '[音频加载失败: ${att.fileName}]',
              });
              continue;
            case AttachmentReadStatus.ok:
              break;
          }
          parts.add({
            'type': 'input_audio',
            'input_audio': {
              'data': outcome.base64,
              'format': format,
            },
          });
        } else if (att.fileType == 'video') {
          parts.add({
            'type': 'input_text',
            'text': '[Responses 格式暂不支持视频输入，已跳过: ${att.fileName}]',
          });
        } else if (isTextAttachment(att)) {
          final text = await readTextAttachmentContent(
            att.fileName,
            att.storagePath,
            att.fileSize,
          );
          parts.add({
            'type': 'input_text',
            'text': text == null
                ? '[${att.fileName} - 无法读取文件内容]'
                : '以下为文件 ${att.fileName} 的内容:\n$text',
          });
        } else {
          if (att.fileSize > maxAttachmentBytes) {
            parts.add({
              'type': 'input_text',
              'text': '[文件过大已跳过: ${att.fileName}]',
            });
            continue;
          }
          final bytes = await readRawAttachmentBytes(att);
          if (bytes == null || bytes.isEmpty) {
            parts.add({
              'type': 'input_text',
              'text': '[${att.fileName} - 无法读取文件内容]',
            });
            continue;
          }
          parts.add({
            'type': 'input_file',
            'filename': att.fileName,
            'file_data': 'data:${att.mimeType};base64,${base64Encode(bytes)}',
          });
        }
      }

      if (hasToolCalls) {
        final toolCalls = calls;
        final textSections = msg.textSections;
        final reasoningSections = msg.reasoningSections;
        final starts = _roundStarts(toolCalls.length, msg.toolCallRoundStarts);

        for (var round = 0; round < starts.length; round++) {
          final start = starts[round];
          final end =
              round + 1 < starts.length ? starts[round + 1] : toolCalls.length;
          final reasoning = round < (reasoningSections?.length ?? 0)
              ? reasoningSections![round]
              : round == 0
                  ? msg.reasoningContent
                  : null;
          if (reasoning != null && reasoning.isNotEmpty) {
            input.add({
              'type': 'reasoning',
              'summary': [
                {'type': 'summary_text', 'text': reasoning},
              ],
            });
          }

          final text = textSections == null || textSections.isEmpty
              ? (round == 0 ? messageContent : null)
              : round < textSections.length
                  ? textSections[round]
                  : null;
          final messageParts = <Map<String, dynamic>>[
            if (text != null && text.isNotEmpty)
              {'type': 'input_text', 'text': text},
            if (round == 0) ...parts,
          ];
          if (messageParts.isNotEmpty) {
            input.add({
              'type': 'message',
              'role': 'assistant',
              'content': messageParts,
            });
          }

          for (final call in toolCalls.sublist(start, end)) {
            input.add({
              'type': 'function_call',
              'call_id': call.id,
              'name': call.name,
              'arguments': jsonEncode(call.arguments),
            });
          }
          for (final call in toolCalls.sublist(start, end)) {
            input.add({
              'type': 'function_call_output',
              'call_id': call.id,
              'output': rebuildToolResultText(
                call,
                maxChars: toolOutputMaxChars,
              ),
            });
          }
        }

        final trailingSectionCount = [
          textSections?.length ?? 0,
          reasoningSections?.length ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        for (var section = starts.length;
            section < trailingSectionCount;
            section++) {
          final reasoning = section < (reasoningSections?.length ?? 0)
              ? reasoningSections![section]
              : null;
          if (reasoning != null && reasoning.isNotEmpty) {
            input.add({
              'type': 'reasoning',
              'summary': [
                {'type': 'summary_text', 'text': reasoning},
              ],
            });
          }
          final text = section < (textSections?.length ?? 0)
              ? textSections![section]
              : null;
          if (text != null && text.isNotEmpty) {
            input.add({
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'input_text', 'text': text},
              ],
            });
          }
        }
      } else if (parts.isNotEmpty) {
        input.add({'type': 'message', 'role': msg.role, 'content': parts});
      }
    }
    return ProtocolRequest(
      messages: input,
      system: instructions.isEmpty ? null : instructions.join('\n\n'),
    );
  }

  @override
  List<Map<String, dynamic>> toolDefsToJson(List<ToolDefinition> tools) => [
        for (final tool in tools)
          {
            'type': 'function',
            'name': tool.name,
            'description': tool.description.isEmpty ? 'Tool' : tool.description,
            'parameters': tool.parameters,
          },
      ];

  @override
  List<Map<String, dynamic>> buildAssistantChainMessage({
    required String content,
    required List<NeutralToolCall> toolCalls,
    String? roundReasoning,
    String? thinkingSignature,
  }) =>
      [
        if (roundReasoning != null && roundReasoning.isNotEmpty)
          {
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': roundReasoning},
            ],
          },
        if (content.isNotEmpty)
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'input_text', 'text': content},
            ],
          },
        for (final call in toolCalls)
          {
            'type': 'function_call',
            'call_id': call.id,
            'name': call.name,
            'arguments': call.argumentsJson,
          },
      ];

  @override
  List<Map<String, dynamic>> buildToolResultMessages(
    List<ToolCallResult> results, {
    int? toolOutputMaxChars,
  }) =>
      [
        for (final result in results)
          {
            'type': 'function_call_output',
            'call_id': result.toolCallId,
            'output': truncateToolOutput(
              result.result,
              maxChars: toolOutputMaxChars,
            ),
          },
      ];

  List<int> _roundStarts(int callCount, List<int>? storedStarts) {
    final starts = storedStarts
        ?.where((start) => start >= 0 && start < callCount)
        .toSet()
        .toList()
      ?..sort();
    if (starts == null || starts.isEmpty || starts.first != 0) {
      starts?.insert(0, 0);
    }
    return starts ?? [0];
  }

  String? _responsesAudioFormat(String mimeType) {
    final normalizedMimeType = mimeType.split(';').first.trim().toLowerCase();
    return switch (normalizedMimeType) {
      'audio/mpeg' ||
      'audio/mp3' =>
        audioFormatFromMimeType(normalizedMimeType),
      'audio/wav' ||
      'audio/x-wav' ||
      'audio/wave' =>
        audioFormatFromMimeType(normalizedMimeType),
      _ => null,
    };
  }
}
