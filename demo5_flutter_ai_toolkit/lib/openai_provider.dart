import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

class OpenAIProvider extends LlmProvider with ChangeNotifier {
  OpenAIProvider({
    String? baseUrl,
    String? apiKey,
    String? model,
    Iterable<ChatMessage>? history,
  })  : _modelName = model ??
            const String.fromEnvironment(
              'MODEL_NAME',
              defaultValue: 'deepseek-v4-flash',
            ),
        _history = history?.toList() ?? [] {
    final resolvedBaseUrl = baseUrl ??
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.deepseek.com',
        );
    final resolvedApiKey = apiKey ??
        const String.fromEnvironment(
          'API_KEY',
          defaultValue: 'sk-9377402d779d4d3192d37b09dc7a1cbf',
        );
    _client = openai.OpenAIClient(
      config: openai.OpenAIConfig(
        baseUrl: resolvedBaseUrl,
        authProvider: openai.ApiKeyProvider(resolvedApiKey),
      ),
    );
    _tools = [
      openai.Tool.function(
        name: 'calculator',
        description: 'Evaluate a math expression and return the result',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'A math expression to evaluate e.g. 2 + 2',
            },
          },
          'required': ['expression'],
        },
      ),
    ];
  }

  late final openai.OpenAIClient _client;
  final String _modelName;
  final List<ChatMessage> _history;
  late final List<openai.Tool> _tools;
  static String? _lastReasoningContent;

  String _executeCalculator(String expression) {
    try {
      final sanitized = expression.replaceAll(' ', '');
      double result;
      if (sanitized.contains('+')) {
        final parts = sanitized.split('+');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a + b);
      } else if (sanitized.contains('*')) {
        final parts = sanitized.split('*');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a * b);
      } else if (sanitized.contains('/')) {
        final parts = sanitized.split('/');
        final nums = parts.map((p) => double.parse(p)).toList();
        result = nums.reduce((a, b) => a / b);
      } else if (sanitized.contains('-')) {
        final parts = sanitized.split('-');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a - b);
      } else {
        result = double.parse(sanitized);
      }
      return '${result + 1} (test mode: result is intentionally incremented by 1)';
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    return _sendMessageStream(
      prompt: prompt,
      attachments: attachments,
      saveHistory: false,
    );
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    return _sendMessageStream(
      prompt: prompt,
      attachments: attachments,
      saveHistory: true,
    );
  }

  Stream<String> _sendMessageStream({
    required String prompt,
    required Iterable<Attachment> attachments,
    required bool saveHistory,
  }) async* {
    if (saveHistory) {
      final userMessage = ChatMessage.user(prompt, attachments);
      final llmMessage = ChatMessage.llm();
      _history.addAll([userMessage, llmMessage]);
    }

    final messages = <openai.ChatMessage>[];
    if (saveHistory && _history.length >= 2) {
      for (final msg in _history.take(_history.length - 1)) {
        messages.add(_toOpenAIMessage(msg));
      }
    } else {
      messages.add(_buildCurrentPrompt(prompt, attachments));
    }

    ChatMessage? currentLlmMessage;
    if (saveHistory) {
      currentLlmMessage = _history.lastWhere((m) => m.origin.isLlm);
    }

    try {
      while (true) {
        final accumulator = openai.ChatStreamAccumulator();
        final stream = _client.chat.completions.createStream(
          openai.ChatCompletionCreateRequest(
            model: _modelName,
            messages: messages,
            tools: _tools,
          ),
        );

        await for (final event in stream) {
          accumulator.add(event);
          final text = event.choices?.firstOrNull?.delta.content;
          if (text != null && text.isNotEmpty) {
            if (currentLlmMessage != null) {
              currentLlmMessage.append(text);
            }
            yield text;
          }
        }

        if (accumulator.reasoningContent.isNotEmpty) {
          _lastReasoningContent = accumulator.reasoningContent;
        }

        if (!accumulator.hasToolCalls) break;

        if (currentLlmMessage != null) {
          currentLlmMessage.text = accumulator.content;
        }

        messages.add(openai.AssistantMessage(
          content: accumulator.content.isNotEmpty ? accumulator.content : null,
          toolCalls: accumulator.toolCalls,
          reasoningContent: _lastReasoningContent,
        ));

        for (final toolCall in accumulator.toolCalls) {
          String result;
          if (toolCall.function.name == 'calculator') {
            final args =
                jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            final expr = args['expression'] as String? ?? '';
            result = _executeCalculator(expr);
          } else {
            result = 'Unknown tool: ${toolCall.function.name}';
          }
          messages.add(openai.ChatMessage.tool(
            toolCallId: toolCall.id,
            content: result,
          ));
        }

        if (saveHistory) {
          final followUpLlmMsg = ChatMessage.llm();
          _history.add(followUpLlmMsg);
          currentLlmMessage = followUpLlmMsg;
        }
      }
    } catch (e, stackTrace) {
      final detail = StringBuffer();
      detail.writeln('=== 错误详情 (Error Detail) ===');
      detail.writeln('');
      detail.writeln('【错误类型】${e.runtimeType}');
      detail.writeln('【错误信息】$e');
      detail.writeln('');
      detail.writeln('--- 请求配置 (Request Config) ---');
      detail.writeln('Model: $_modelName');
      detail.writeln('');
      detail.writeln('--- 请求消息 (Messages) ---');
      detail.writeln('消息数量: ${messages.length}');
      detail.writeln('');
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        detail.writeln('[$i] role: ${m.role}');
        switch (m) {
          case openai.UserMessage():
            final t = m.text;
            if (t != null) {
              detail.writeln('    text: "${t.length > 200 ? '${t.substring(0, 200)}...' : t}"');
            }
            final p = m.parts;
            if (p != null) detail.writeln('    parts: ${p.length} items');
          case openai.AssistantMessage():
            detail.writeln('    content: "${m.content != null ? (m.content!.length > 200 ? '${m.content!.substring(0, 200)}...' : m.content) : 'null'}"');
            detail.writeln('    toolCalls: ${m.toolCalls?.length ?? 0}');
            if (m.toolCalls != null) {
              for (final tc in m.toolCalls!) {
                detail.writeln('      -> ${tc.function.name}(${tc.function.arguments.length > 300 ? '${tc.function.arguments.substring(0, 300)}...' : tc.function.arguments})');
              }
            }
          case openai.ToolMessage():
            detail.writeln('    toolCallId: ${m.toolCallId}');
            detail.writeln('    content: "${m.content.length > 200 ? '${m.content.substring(0, 200)}...' : m.content}"');
          default:
            try {
              detail.writeln('    json: ${jsonEncode(m.toJson()).substring(0, 300)}');
            } catch (_) {
              detail.writeln('    (unknown message type)');
            }
        }
      }
      detail.writeln('');
      detail.writeln('--- History (${_history.length} messages) ---');
      for (var i = 0; i < _history.length; i++) {
        final h = _history[i];
        final t = h.text ?? '';
        detail.writeln('[$i] origin=${h.origin}, text="${t.length > 100 ? '${t.substring(0, 100)}...' : t}"');
      }
      detail.writeln('');
      detail.writeln('--- Stack Trace ---');
      detail.writeln('$stackTrace');

      throw LlmFailureException(detail.toString());
    }

    if (saveHistory) {
      notifyListeners();
    }
  }

  openai.ChatMessage _toOpenAIMessage(ChatMessage msg) {
    if (msg.origin.isUser) {
      if (msg.attachments.isEmpty) {
        return openai.ChatMessage.user(msg.text ?? '');
      }
      final parts = <openai.ContentPart>[];
      if (msg.text != null && msg.text!.isNotEmpty) {
        parts.add(openai.ContentPart.text(msg.text!));
      }
      for (final a in msg.attachments) {
        parts.add(_attachmentToContentPart(a));
      }
      return openai.ChatMessage.user(parts);
    } else {
      if (_lastReasoningContent != null) {
        return openai.AssistantMessage(
          content: msg.text,
          reasoningContent: _lastReasoningContent,
        );
      }
      return openai.ChatMessage.assistant(content: msg.text ?? '');
    }
  }

  openai.ChatMessage _buildCurrentPrompt(
    String prompt,
    Iterable<Attachment> attachments,
  ) {
    if (attachments.isEmpty) {
      return openai.ChatMessage.user(prompt);
    }
    final parts = <openai.ContentPart>[
      openai.ContentPart.text(prompt),
    ];
    for (final a in attachments) {
      parts.add(_attachmentToContentPart(a));
    }
    return openai.ChatMessage.user(parts);
  }

  static openai.ContentPart _attachmentToContentPart(Attachment attachment) {
    return switch (attachment) {
      final ImageFileAttachment a => openai.ContentPart.imageBase64(
          data: base64Encode(a.bytes),
          mediaType: a.mimeType,
        ),
      final FileAttachment a => openai.ContentPart.fileData(
          data: base64Encode(a.bytes),
          mediaType: a.mimeType,
          filename: a.name,
        ),
      final LinkAttachment a =>
        openai.ContentPart.text('[Link: ${a.name} - ${a.url}]'),
    };
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
