import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/llm_account.dart';
import 'package:uuid/uuid.dart' show Namespace, Uuid;

/// Source-backed Amazon Q Developer endpoints and account model catalog.
/// Amazon Q uses its own regional Q service API; it is not a Bedrock protocol.
abstract final class AmazonQConnector {
  static const supportedProfileRegions = {'us-east-1', 'eu-central-1'};
  static const _adaptiveThinkingModels = {
    'claude-opus-5',
    'claude-opus-5.5',
    'claude-sonnet-5',
  };
  static const _nativeReasoningModels = {
    'gpt-5.6-sol',
    'gpt-5.6-terra',
    'gpt-5.6-luna',
  };

  static Uri chatUri(String region) =>
      _uri(region, '/generateAssistantResponse');

  static Uri modelsUri(String region) => _uri(
        region,
        '/ListAvailableModels',
      ).replace(queryParameters: const {'origin': 'AI_EDITOR'});

  static Uri _uri(String rawRegion, String path) {
    final region = rawRegion.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9-]{3,32}$').hasMatch(region) ||
        !supportedProfileRegions.contains(region)) {
      throw ArgumentError.value(rawRegion, 'region');
    }
    return Uri.https('q.$region.amazonaws.com', path);
  }

  /// Q returns an account-specific model list. Do not guess models when the
  /// account does not expose them; model IDs and names come from AWS.
  static List<LlmUpstreamModel> parseModels(Object? value) {
    if (value is! Map) throw ArgumentError.value(value, 'value');
    final rawModels = value['models'] ?? value['availableModels'];
    if (rawModels is! Iterable) return const [];
    final seen = <String>{};
    final models = <LlmUpstreamModel>[];
    for (final raw in rawModels) {
      if (raw is! Map) continue;
      final id = (raw['modelId'] ?? raw['id']) is String
          ? ((raw['modelId'] ?? raw['id']) as String).trim()
          : '';
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      final name = (raw['modelName'] ?? raw['name']) is String
          ? ((raw['modelName'] ?? raw['name']) as String).trim()
          : '';
      final limits = raw['tokenLimits'];
      models.add(
        LlmUpstreamModel(
          id: 'amazon-q:$id',
          upstreamModelId: id,
          displayName: name.isEmpty ? id : name,
          capabilities: const {'chat': true, 'streaming': true, 'tools': true},
          config: {
            'catalogSource': 'account-entitlement',
            if (limits is Map && limits['maxInputTokens'] is num)
              'inputTokenLimit': limits['maxInputTokens'],
            if (limits is Map && limits['maxOutputTokens'] is num)
              'outputTokenLimit': limits['maxOutputTokens'],
          },
        ),
      );
    }
    return List.unmodifiable(models);
  }

  static bool isSupportedRegion(String region) =>
      supportedProfileRegions.contains(region.trim().toLowerCase());

  /// OIDC clients can be registered in any AWS region supported by IAM Identity
  /// Center. Keep this separate from [supportedProfileRegions], which describes
  /// where Amazon Q profiles and runtime endpoints are hosted.
  static String oidcRegion(Object? value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return 'us-east-1';
    }
    if (value is! String) {
      throw const FormatException('Amazon Q OIDC region is invalid.');
    }
    final region = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z]{2}-[a-z]+-\d{1,2}$').hasMatch(region)) {
      throw const FormatException('Amazon Q OIDC region is invalid.');
    }
    return region;
  }

  static Map<String, dynamic> parseCredentialImport(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid Amazon Q credential import.');
    }
    final credential = Map<String, dynamic>.from(decoded);
    String? read(List<String> keys) {
      for (final key in keys) {
        final value = credential[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final refreshToken = read(const ['refresh_token', 'refreshToken']);
    if (refreshToken == null) {
      throw const FormatException('Amazon Q import requires a refresh token.');
    }
    final accessToken = read(const ['access_token', 'accessToken']);
    final clientId = read(const ['clientId', 'client_id']);
    final clientSecret = read(const ['clientSecret', 'client_secret']);
    if ((clientId == null) != (clientSecret == null)) {
      throw const FormatException(
        'Amazon Q OAuth client credentials must be supplied together.',
      );
    }
    credential['refresh_token'] = refreshToken;
    if (accessToken != null) credential['access_token'] = accessToken;
    if (clientId != null) credential['clientId'] = clientId;
    if (clientSecret != null) credential['clientSecret'] = clientSecret;
    return credential;
  }

  static Map<String, dynamic> buildChatRequest({
    required String modelId,
    String accountId = '',
    required String? conversationId,
    required List<Map<String, dynamic>> messages,
    String? system,
    List<Map<String, dynamic>> tools = const [],
    int? maxOutputTokens,
    double? temperature,
    Map<String, dynamic> options = const {},
  }) {
    if (modelId.trim().isEmpty || messages.isEmpty) {
      throw const FormatException(
        'Amazon Q chat requires a model and messages.',
      );
    }
    final turns = <Map<String, dynamic>>[];
    Map<String, dynamic>? current;
    void flush() {
      if (current != null) turns.add(current!);
      current = null;
    }

    void addUserTurn(String text) {
      final input = current?['userInputMessage'];
      if (input is Map) {
        final old = input['content'];
        input['content'] =
            old is String && old.isNotEmpty ? '$old\n\n$text' : text;
        return;
      }
      flush();
      current = {
        'userInputMessage': {
          'content': text,
          'modelId': modelId,
          'origin': 'AI_EDITOR',
        },
      };
    }

    String textContent(Object? value) {
      if (value is String) return value;
      if (value is! Iterable) {
        throw const FormatException('Amazon Q supports text messages only.');
      }
      final parts = <String>[];
      for (final part in value) {
        if (part is! Map || part['type'] != 'text' || part['text'] is! String) {
          throw const FormatException('Amazon Q supports text messages only.');
        }
        parts.add(part['text'] as String);
      }
      return parts.join('\n');
    }

    final sourceMessages = <Map<String, dynamic>>[
      if (system?.isNotEmpty == true &&
          !messages.any(
            (message) =>
                message['role'] == 'system' && message['content'] == system,
          ))
        {'role': 'system', 'content': system},
      ...messages,
    ];
    for (final message in sourceMessages) {
      final role = message['role'];
      if (role is! String) {
        throw const FormatException('Amazon Q chat role is invalid.');
      }
      if (role == 'system' || role == 'developer') {
        final text = textContent(message['content']);
        if (text.isNotEmpty) {
          addUserTurn('<system-reminder>\n$text\n</system-reminder>');
        }
        continue;
      }
      if (role == 'user') {
        final text = textContent(message['content']);
        addUserTurn(text);
        continue;
      }
      if (role == 'assistant') {
        final assistantContent = message['content'];
        final assistantText =
            assistantContent == null ? '' : textContent(assistantContent);
        final reasoning = message['reasoning_content'];
        // Q's transcript schema has no separate reasoning field. Keep source
        // returned reasoning in the assistant turn so follow-up requests do
        // not discard it from the conversation history.
        final text = [
          if (reasoning is String && reasoning.isNotEmpty)
            '<thinking>\n$reasoning\n</thinking>',
          if (assistantText.isNotEmpty) assistantText,
        ].join('\n\n');
        final uses = _toolUses(message['tool_calls']);
        final existing = current?['assistantResponseMessage'];
        if (existing is Map) {
          final content = existing['content'];
          if (text.isNotEmpty) {
            existing['content'] = content is String && content.isNotEmpty
                ? '$content\n\n$text'
                : text;
          }
          if (uses.isNotEmpty) {
            final old = existing['toolUses'];
            existing['toolUses'] = [if (old is Iterable) ...old, ...uses];
          }
        } else {
          flush();
          current = {
            'assistantResponseMessage': {
              if (text.isNotEmpty) 'content': text,
              if (uses.isNotEmpty) 'toolUses': uses,
            },
          };
        }
        continue;
      }
      if (role == 'tool') {
        final id = message['tool_call_id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException(
            'Amazon Q tool results require a call ID.',
          );
        }
        final result = {
          'toolUseId': id,
          'status': message['is_error'] == true ? 'error' : 'success',
          'content': [
            {'text': textContent(message['content'])},
          ],
        };
        final input = current?['userInputMessage'];
        if (input is Map) {
          final context = input.putIfAbsent(
            'userInputMessageContext',
            () => <String, dynamic>{},
          );
          final results = (context as Map).putIfAbsent(
            'toolResults',
            () => <Map<String, dynamic>>[],
          );
          (results as List).add(result);
        } else {
          flush();
          current = {
            'userInputMessage': {
              'content': '',
              'modelId': modelId,
              'origin': 'AI_EDITOR',
              'userInputMessageContext': <String, dynamic>{
                'toolResults': <Map<String, dynamic>>[result],
              },
            },
          };
        }
        continue;
      }
      throw const FormatException('Amazon Q chat role is unsupported.');
    }
    flush();

    if (turns.isEmpty ||
        !turns.any((turn) => turn.containsKey('userInputMessage'))) {
      throw const FormatException('Amazon Q chat requires a user message.');
    }
    if (turns.first.containsKey('assistantResponseMessage')) {
      turns.insert(0, {
        'userInputMessage': {
          'content': '(empty)',
          'modelId': modelId,
          'origin': 'AI_EDITOR',
        },
      });
    }
    final last = turns.removeLast();
    final currentMessage = last.containsKey('userInputMessage')
        ? last
        : {
            'userInputMessage': {
              'content': '...',
              'modelId': modelId,
              'origin': 'AI_EDITOR',
            },
          };
    final userInput =
        currentMessage['userInputMessage'] as Map<String, dynamic>;
    if (tools.isNotEmpty) {
      final context = userInput.putIfAbsent(
        'userInputMessageContext',
        () => <String, dynamic>{},
      );
      (context as Map)['tools'] = _toolSpecifications(tools);
    }
    final stableSession = conversationId?.trim().isNotEmpty == true
        ? conversationId!.trim()
        : const Uuid().v4();
    final id = const Uuid().v5(
      Namespace.url.value,
      'stroom:amazon-q:$accountId:$stableSession',
    );
    final effort = _reasoningEffort(options);
    final normalizedModelId = modelId.replaceFirst(
      RegExp(r'^(claude-(?:opus|sonnet|haiku|3-\d+)-\d+)-(\d{1,2})$'),
      r'$1.$2',
    );
    final usesAdaptiveThinking =
        effort != null && _adaptiveThinkingModels.contains(normalizedModelId);
    final usesNativeReasoning =
        effort != null && _nativeReasoningModels.contains(normalizedModelId);
    if (usesAdaptiveThinking) {
      final length = switch (effort) {
        'max' => 120000,
        'xhigh' => 64000,
        'high' => 32000,
        'medium' => 16000,
        _ => 8000,
      };
      final input = userInput['content'];
      userInput['content'] = '<thinking_mode>enabled</thinking_mode>'
          '<max_thinking_length>$length</max_thinking_length>\n\n'
          '${input is String ? input : ''}';
    }
    final additionalModelRequestFields = usesAdaptiveThinking
        ? {
            'output_config': {'effort': effort},
            'thinking': {'type': 'adaptive', 'display': 'summarized'},
            'max_tokens': maxOutputTokens == null || maxOutputTokens < 1024
                ? 32000
                : maxOutputTokens,
          }
        : usesNativeReasoning
            ? {
                'reasoning': {'effort': effort},
              }
            : null;
    final request = <String, dynamic>{
      'conversationState': {
        'chatTriggerType': 'MANUAL',
        'conversationId': id,
        'currentMessage': currentMessage,
        'history': turns,
      },
    };
    final inferenceConfig = <String, dynamic>{};
    if (maxOutputTokens != null) {
      inferenceConfig['maxTokens'] = maxOutputTokens;
    }
    if (!usesAdaptiveThinking && temperature != null) {
      inferenceConfig['temperature'] = temperature;
    }
    if (inferenceConfig.isNotEmpty) {
      request['inferenceConfig'] = inferenceConfig;
    }
    if (additionalModelRequestFields != null) {
      request['additionalModelRequestFields'] = additionalModelRequestFields;
    }
    return request;
  }

  static String? _reasoningEffort(Map<String, dynamic> options) {
    var effort = options['reasoning_effort'];
    if (effort is! String || effort.trim().isEmpty) {
      final outputConfig = options['output_config'];
      effort = outputConfig is Map ? outputConfig['effort'] : null;
    }
    if (effort is! String || effort.trim().isEmpty) {
      final thinking = options['thinking'];
      if (thinking is Map) {
        if (thinking['type'] == 'adaptive') {
          effort = 'high';
        } else if (thinking['type'] == 'enabled') {
          final budget = thinking['budget_tokens'];
          final tokens =
              budget is num ? budget.toInt() : int.tryParse('$budget') ?? 0;
          effort = tokens >= 32000
              ? 'high'
              : tokens >= 16000
                  ? 'medium'
                  : tokens > 0
                      ? 'low'
                      : null;
        }
      }
    }
    if (effort is! String) return null;
    final normalized = effort.trim().toLowerCase();
    final value = normalized == 'minimal' ? 'low' : normalized;
    return const {'low', 'medium', 'high', 'xhigh', 'max'}.contains(value)
        ? value
        : null;
  }

  static List<Map<String, dynamic>> _toolUses(Object? rawCalls) {
    if (rawCalls == null) return const [];
    if (rawCalls is! Iterable) {
      throw const FormatException('Amazon Q tool calls are invalid.');
    }
    return [
      for (final raw in rawCalls)
        if (raw is Map && raw['function'] is Map)
          _oneToolUse(raw)
        else
          throw const FormatException('Amazon Q tool calls are invalid.'),
    ];
  }

  static Map<String, dynamic> _oneToolUse(Map raw) {
    final function = raw['function'] as Map;
    final id = raw['id'];
    final name = function['name'];
    final arguments = function['arguments'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('Amazon Q tool call identity is invalid.');
    }
    Map<String, dynamic> input;
    if (arguments is Map) {
      input = Map<String, dynamic>.from(arguments);
    } else if (arguments is String) {
      final decoded = jsonDecode(arguments);
      if (decoded is! Map) {
        throw const FormatException(
          'Amazon Q tool arguments must be an object.',
        );
      }
      input = Map<String, dynamic>.from(decoded);
    } else {
      throw const FormatException('Amazon Q tool arguments are invalid.');
    }
    return {'toolUseId': id, 'name': name, 'input': input};
  }

  static List<Map<String, dynamic>> _toolSpecifications(
    List<Map<String, dynamic>> tools,
  ) =>
      [
        for (final tool in tools)
          if (tool['type'] == 'function' && tool['function'] is Map)
            _oneToolSpecification(tool['function'] as Map)
          else
            throw const FormatException(
              'Amazon Q tools must use function schemas.',
            ),
      ];

  static Map<String, dynamic> _oneToolSpecification(Map function) {
    final name = function['name'];
    final parameters = function['parameters'];
    if (name is! String || name.isEmpty || parameters is! Map) {
      throw const FormatException('Amazon Q tool schema is invalid.');
    }
    return {
      'toolSpecification': {
        'name': name,
        'description': function['description'] is String &&
                (function['description'] as String).isNotEmpty
            ? function['description']
            : 'Tool: $name',
        'inputSchema': {'json': Map<String, dynamic>.from(parameters)},
      },
    };
  }

  static Stream<List<int>> toOpenAiSse(
    Stream<List<int>> source, {
    required String modelId,
  }) async* {
    final pending = <int>[];
    final toolIndexes = <String, int>{};
    final announcedToolIds = <String>{};
    final bufferedToolInputs = <String, Map<String, dynamic>>{};
    var nextToolIndex = 0;
    var sawStop = false;
    var sawToolCall = false;

    List<int> frame(Map<String, dynamic> chunk) =>
        utf8.encode('data: ${jsonEncode(chunk)}\n\n');
    Map<String, dynamic> chunk(Map<String, dynamic> delta, {String? finish}) =>
        {
          'id': 'amazon-q-stream',
          'object': 'chat.completion.chunk',
          'model': modelId,
          'choices': [
            {'index': 0, 'delta': delta, 'finish_reason': finish},
          ],
        };

    await for (final bytes in source) {
      pending.addAll(bytes);
      var offset = 0;
      while (pending.length - offset >= 12) {
        final view = ByteData.sublistView(Uint8List.fromList(pending), offset);
        final totalLength = view.getUint32(0, Endian.big);
        final headerLength = view.getUint32(4, Endian.big);
        if (totalLength < 16 ||
            headerLength > totalLength - 16 ||
            totalLength > 16 * 1024 * 1024) {
          throw const FormatException('Invalid Amazon Q EventStream frame.');
        }
        if (pending.length - offset < totalLength) break;
        final eventFrame = Uint8List.fromList(
          pending.sublist(offset, offset + totalLength),
        );
        offset += totalLength;
        _validateFrame(eventFrame, headerLength);
        final headers = _readStringHeaders(eventFrame, headerLength);
        final eventType = headers[':event-type'];
        final payloadBytes = eventFrame.sublist(
          12 + headerLength,
          totalLength - 4,
        );
        final decoded = payloadBytes.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(utf8.decode(payloadBytes));
        if (decoded is! Map &&
            !(eventType == 'toolUseEvent' && decoded is List)) {
          throw const FormatException('Invalid Amazon Q EventStream payload.');
        }
        final event = eventType ?? headers[':message-type'];
        final rawPayload = decoded;
        final payload = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
        if (event == null ||
            event == 'exception' ||
            headers[':message-type'] == 'exception') {
          throw const FormatException(
            'Amazon Q returned an EventStream error.',
          );
        }
        if (event == 'assistantResponseEvent') {
          final text = payload['content'];
          if (text is String && text.isNotEmpty) {
            yield frame(chunk({'content': text}));
          }
        } else if (event == 'reasoningContentEvent') {
          final raw =
              payload['reasoningText'] ?? payload['text'] ?? payload['content'];
          final text = raw is Map ? raw['text'] : raw;
          final signature =
              raw is Map ? raw['signature'] : payload['signature'];
          if (text is String && text.isNotEmpty) {
            yield frame(
              chunk({
                'reasoning_content': text,
                if (signature is String && signature.isNotEmpty)
                  'stroom.reasoningSignature': signature,
              }),
            );
          } else if (signature is String && signature.isNotEmpty) {
            yield frame(chunk({'stroom.reasoningSignature': signature}));
          }
        } else if (event == 'toolUseEvent') {
          final List<dynamic> rawUses =
              rawPayload is List ? rawPayload : [payload];
          for (final rawUse in rawUses) {
            if (rawUse is! Map) {
              throw const FormatException('Invalid Amazon Q tool event.');
            }
            final id = rawUse['toolUseId'] ?? rawUse['toolCallId'];
            final name = rawUse['name'];
            if (id is! String ||
                id.isEmpty ||
                name is! String ||
                name.isEmpty) {
              throw const FormatException('Invalid Amazon Q tool identity.');
            }
            final index = toolIndexes.putIfAbsent(id, () => nextToolIndex++);
            final toolInput = rawUse['input'];
            final args = toolInput is String
                ? toolInput
                : toolInput is Map
                    ? jsonEncode(toolInput)
                    : '';
            sawToolCall = true;
            if (announcedToolIds.add(id)) {
              yield frame(
                chunk({
                  'tool_calls': [
                    {
                      'index': index,
                      'id': id,
                      'type': 'function',
                      'function': {'name': name, 'arguments': ''},
                    },
                  ],
                }),
              );
            }
            if (toolInput is Map) {
              bufferedToolInputs[id] = Map<String, dynamic>.from(toolInput);
            } else if (args.isNotEmpty) {
              yield frame(
                chunk({
                  'tool_calls': [
                    {
                      'index': index,
                      'function': {'arguments': args},
                    },
                  ],
                }),
              );
            }
          }
        } else if (event == 'messageStopEvent') {
          sawStop = true;
          for (final entry in bufferedToolInputs.entries) {
            yield frame(
              chunk({
                'tool_calls': [
                  {
                    'index': toolIndexes[entry.key],
                    'function': {'arguments': jsonEncode(entry.value)},
                  },
                ],
              }),
            );
          }
          bufferedToolInputs.clear();
          yield frame(
            chunk(const {}, finish: sawToolCall ? 'tool_calls' : 'stop'),
          );
        } else if (event == 'metadataEvent' || event == 'usageEvent') {
          final rawUsage =
              payload['usage'] is Map ? payload['usage'] as Map : payload;
          final input = rawUsage['inputTokens'] ?? rawUsage['input_tokens'];
          final output = rawUsage['outputTokens'] ?? rawUsage['output_tokens'];
          if (input is num || output is num) {
            yield frame({
              'id': 'amazon-q-stream',
              'object': 'chat.completion.chunk',
              'model': modelId,
              'choices': const [],
              'usage': {
                if (input is num) 'prompt_tokens': input.toInt(),
                if (output is num) 'completion_tokens': output.toInt(),
              },
            });
          }
        }
      }
      if (offset > 0) pending.removeRange(0, offset);
    }
    if (pending.isNotEmpty || !sawStop) {
      throw const FormatException(
        'Amazon Q EventStream ended before messageStopEvent.',
      );
    }
    yield utf8.encode('data: [DONE]\n\n');
  }

  static Future<Map<String, dynamic>> toOpenAiCompletion(
    Stream<List<int>> source, {
    required String modelId,
  }) async {
    final text = StringBuffer();
    final reasoning = StringBuffer();
    final signatures = <String>[];
    final toolCalls = <int, Map<String, dynamic>>{};
    Map<String, dynamic>? usage;
    String finishReason = 'stop';
    final sse = toOpenAiSse(source, modelId: modelId);
    await for (final line
        in utf8.decoder.bind(sse).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final raw = line.substring(6);
      if (raw == '[DONE]') continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Invalid Amazon Q chat response.');
      }
      final chunk = Map<String, dynamic>.from(decoded);
      if (chunk['usage'] is Map) {
        usage = Map<String, dynamic>.from(chunk['usage'] as Map);
      }
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final choice = choices.first as Map;
      if (choice['finish_reason'] is String) {
        finishReason = choice['finish_reason'] as String;
      }
      final delta = choice['delta'];
      if (delta is! Map) continue;
      if (delta['content'] is String) text.write(delta['content']);
      if (delta['reasoning_content'] is String) {
        reasoning.write(delta['reasoning_content']);
      }
      if (delta['stroom.reasoningSignature'] is String) {
        signatures.add(delta['stroom.reasoningSignature'] as String);
      }
      final calls = delta['tool_calls'];
      if (calls is List) {
        for (final rawCall in calls.whereType<Map>()) {
          final index = rawCall['index'];
          if (index is! num) continue;
          final call = toolCalls.putIfAbsent(
            index.toInt(),
            () => {
              'id': '',
              'type': 'function',
              'function': {'name': '', 'arguments': ''},
            },
          );
          if (rawCall['id'] is String) call['id'] = rawCall['id'];
          final function = rawCall['function'];
          if (function is Map) {
            final target = call['function'] as Map<String, dynamic>;
            if (function['name'] is String) target['name'] = function['name'];
            if (function['arguments'] is String) {
              target['arguments'] =
                  '${target['arguments']}${function['arguments']}';
            }
          }
        }
      }
    }
    final completion = <String, dynamic>{
      'id': 'amazon-q-completion',
      'object': 'chat.completion',
      'model': modelId,
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': text.toString(),
            if (reasoning.isNotEmpty) 'reasoning_content': reasoning.toString(),
            if (signatures.isNotEmpty)
              'stroom.reasoningSignature': signatures.join(),
            if (toolCalls.isNotEmpty)
              'tool_calls': [
                for (final entry
                    in toolCalls.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key)))
                  entry.value,
              ],
          },
          'finish_reason': finishReason,
        },
      ],
    };
    if (usage != null) completion['usage'] = usage;
    return completion;
  }

  static void _validateFrame(Uint8List frame, int headerLength) {
    final view = ByteData.sublistView(frame);
    if (headerLength > frame.length - 16 ||
        view.getUint32(8, Endian.big) != _crc32(frame.sublist(0, 8)) ||
        view.getUint32(frame.length - 4, Endian.big) !=
            _crc32(frame.sublist(0, frame.length - 4))) {
      throw const FormatException(
        'Amazon Q EventStream CRC validation failed.',
      );
    }
  }

  static Map<String, String> _readStringHeaders(Uint8List frame, int length) {
    final headers = <String, String>{};
    var offset = 12;
    final end = offset + length;
    while (offset < end) {
      final keyLength = frame[offset++];
      if (offset + keyLength + 1 > end) {
        throw const FormatException('Invalid Amazon Q EventStream header.');
      }
      final key = utf8.decode(frame.sublist(offset, offset + keyLength));
      offset += keyLength;
      final type = frame[offset++];
      if (type != 7 || offset + 2 > end) {
        throw const FormatException('Unsupported Amazon Q EventStream header.');
      }
      final valueLength = ByteData.sublistView(
        frame,
      ).getUint16(offset, Endian.big);
      offset += 2;
      if (offset + valueLength > end) {
        throw const FormatException('Truncated Amazon Q EventStream header.');
      }
      headers[key] = utf8.decode(frame.sublist(offset, offset + valueLength));
      offset += valueLength;
    }
    if (offset != end) {
      throw const FormatException(
        'Invalid Amazon Q EventStream header length.',
      );
    }
    return headers;
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
