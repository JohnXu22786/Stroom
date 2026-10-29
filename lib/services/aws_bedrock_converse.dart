import 'dart:convert';

abstract final class AwsBedrockConverseAdapter {
  static Map<String, dynamic> toConverse(Object? value) {
    if (value is! Map || value['messages'] is! List) {
      throw const FormatException('Chat messages are required.');
    }
    final system = <Map<String, String>>[];
    final messages = <Map<String, dynamic>>[];
    for (final rawMessage in value['messages'] as List) {
      if (rawMessage is! Map || rawMessage['role'] is! String) {
        throw const FormatException('Chat message is invalid.');
      }
      final message = Map<String, dynamic>.from(rawMessage);
      final role = message['role'] as String;
      if (role == 'system' || role == 'developer') {
        system.add({'text': _text(message['content'])});
        continue;
      }
      if (role == 'tool') {
        final id = message['tool_call_id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('Tool response ID is required.');
        }
        messages.add({
          'role': 'user',
          'content': [
            {
              'toolResult': {
                'toolUseId': id,
                'content': [
                  {'text': _text(message['content'])},
                ],
              },
            },
          ],
        });
        continue;
      }
      if (role != 'user' && role != 'assistant') {
        throw const FormatException('Chat role is unsupported.');
      }
      final content = <Map<String, dynamic>>[];
      final text = _textOrNull(message['content']);
      if (text != null && text.isNotEmpty) content.add({'text': text});
      final toolCalls = message['tool_calls'];
      if (toolCalls is List) {
        for (final rawCall in toolCalls) {
          if (rawCall is! Map || rawCall['function'] is! Map) {
            throw const FormatException('Tool call is invalid.');
          }
          final call = Map<String, dynamic>.from(rawCall);
          final function = Map<String, dynamic>.from(call['function'] as Map);
          final id = call['id'];
          final name = function['name'];
          if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
            throw const FormatException('Tool call identity is required.');
          }
          final arguments = function['arguments'];
          final input = arguments is Map
              ? Map<String, dynamic>.from(arguments)
              : arguments is String
                  ? _decodeObject(arguments)
                  : <String, dynamic>{};
          content.add({
            'toolUse': {'toolUseId': id, 'name': name, 'input': input},
          });
        }
      }
      if (content.isEmpty) {
        throw const FormatException('Chat message content is required.');
      }
      messages.add({'role': role, 'content': content});
    }
    if (messages.isEmpty) {
      throw const FormatException(
        'At least one user or assistant turn is required.',
      );
    }

    final inferenceConfig = <String, dynamic>{};
    final maxTokens = value['max_tokens'] ?? value['max_completion_tokens'];
    if (maxTokens is num && maxTokens > 0) {
      inferenceConfig['maxTokens'] = maxTokens.toInt();
    }
    for (final entry in const {
      'temperature': 'temperature',
      'top_p': 'topP',
    }.entries) {
      final amount = value[entry.key];
      if (amount is num) inferenceConfig[entry.value] = amount;
    }
    final stop = value['stop'];
    if (stop is String && stop.isNotEmpty) {
      inferenceConfig['stopSequences'] = [stop];
    } else if (stop is List && stop.every((item) => item is String)) {
      inferenceConfig['stopSequences'] = stop;
    }

    final result = <String, dynamic>{
      'messages': messages,
      if (system.isNotEmpty) 'system': system,
      if (inferenceConfig.isNotEmpty) 'inferenceConfig': inferenceConfig,
    };
    final toolChoice = value['tool_choice'];
    if (toolChoice != 'none') {
      final tools = _bedrockTools(value['tools']);
      if (tools.isNotEmpty) {
        final toolConfig = <String, dynamic>{'tools': tools};
        if (toolChoice == 'auto') {
          toolConfig['toolChoice'] = {'auto': {}};
        } else if (toolChoice == 'required') {
          toolConfig['toolChoice'] = {'any': {}};
        } else if (toolChoice is Map && toolChoice['function'] is Map) {
          final name = (toolChoice['function'] as Map)['name'];
          if (name is String && name.isNotEmpty) {
            toolConfig['toolChoice'] = {
              'tool': {'name': name},
            };
          }
        }
        result['toolConfig'] = toolConfig;
      }
    }
    return result;
  }

  static Map<String, dynamic> fromConverse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Bedrock response is invalid.');
    }
    final output = value['output'];
    final message = output is Map ? output['message'] : null;
    final rawContent = message is Map ? message['content'] : null;
    final text = StringBuffer();
    final toolCalls = <Map<String, dynamic>>[];
    if (rawContent is List) {
      for (final rawBlock in rawContent) {
        if (rawBlock is! Map) continue;
        final block = Map<String, dynamic>.from(rawBlock);
        if (block['text'] is String) text.write(block['text']);
        final toolUse = block['toolUse'];
        if (toolUse is Map) {
          final id = toolUse['toolUseId'];
          final name = toolUse['name'];
          if (id is String && name is String) {
            toolCalls.add({
              'id': id,
              'type': 'function',
              'function': {
                'name': name,
                'arguments': jsonEncode(toolUse['input'] ?? const {}),
              },
            });
          }
        }
      }
    }
    final reason = value['stopReason'];
    final finish = reason == 'tool_use'
        ? 'tool_calls'
        : reason == 'max_tokens'
            ? 'length'
            : 'stop';
    final usage = value['usage'];
    return {
      'object': 'chat.completion',
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': text.isEmpty ? null : text.toString(),
            if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
          },
          'finish_reason': finish,
        },
      ],
      if (usage is Map)
        'usage': {
          if (usage['inputTokens'] is num)
            'prompt_tokens': (usage['inputTokens'] as num).toInt(),
          if (usage['outputTokens'] is num)
            'completion_tokens': (usage['outputTokens'] as num).toInt(),
        },
    };
  }

  static List<Map<String, dynamic>> _bedrockTools(Object? rawTools) {
    if (rawTools == null) return const [];
    if (rawTools is! List) throw const FormatException('Tools are invalid.');
    final result = <Map<String, dynamic>>[];
    for (final rawTool in rawTools) {
      if (rawTool is! Map || rawTool['function'] is! Map) {
        throw const FormatException('Tool definition is invalid.');
      }
      final function = Map<String, dynamic>.from(rawTool['function'] as Map);
      final name = function['name'];
      if (name is! String || name.isEmpty) {
        throw const FormatException('Tool name is required.');
      }
      result.add({
        'toolSpec': {
          'name': name,
          if (function['description'] is String)
            'description': function['description'],
          'inputSchema': {
            'json': function['parameters'] is Map
                ? function['parameters']
                : const {'type': 'object'},
          },
        },
      });
    }
    return result;
  }

  static String _text(Object? value) =>
      _textOrNull(value) ?? (throw const FormatException('Text is required.'));

  static String? _textOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final parts = <String>[];
      for (final item in value) {
        if (item is Map && item['type'] == 'text' && item['text'] is String) {
          parts.add(item['text'] as String);
        } else {
          throw const FormatException('Bedrock chat content must be text.');
        }
      }
      return parts.join();
    }
    throw const FormatException('Bedrock chat content must be text.');
  }

  static Map<String, dynamic> _decodeObject(String source) {
    final value = jsonDecode(source);
    if (value is! Map) {
      throw const FormatException('Tool arguments are invalid.');
    }
    return Map<String, dynamic>.from(value);
  }
}
