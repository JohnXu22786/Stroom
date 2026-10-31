/// Provider protocol bridges used at the AI Gateway boundary.
///
/// The bridges keep Stroom's message semantics separate from upstream DTOs.
/// The original protocol payload is retained in the message's namespaced
/// extension so fields not understood by this version can make a lossless
/// round trip.
library;

import 'dart:convert';

import 'ai_gateway_contracts.dart';
import '../models/stroom_conversation.dart';

/// Built-in protocol mappings. Gemini Interactions is provider-specific and
/// remains separate from the four general chat contracts.
abstract final class AiGatewayProtocolBridges {
  static const openAiChatCompletions = _OpenAiChatCompletionsBridge();
  static const openAiResponses = _OpenAiResponsesBridge();
  static const anthropicMessages = _AnthropicMessagesBridge();
  static const geminiGenerateContent = _GeminiGenerateContentBridge();
  static const geminiInteractions = _GeminiInteractionsBridge();
  static const ollamaChat = _OllamaChatBridge();

  static AiGatewayProtocolBridge<Map<String, dynamic>>? forProtocol(
    String protocolId,
  ) =>
      switch (protocolId) {
        'openai.chat_completions' => openAiChatCompletions,
        'openai.responses' => openAiResponses,
        'anthropic.messages' => anthropicMessages,
        'google.gemini.generate_content' => geminiGenerateContent,
        'google.gemini.interactions' => geminiInteractions,
        'ollama.chat' => ollamaChat,
        _ => null,
      };

  static AiGatewayEncodedProtocolRequest? buildRequest(
    String protocolId,
    AiGatewayProtocolRequest request,
  ) =>
      forProtocol(protocolId) is _MapBridge
          ? (forProtocol(protocolId)! as _MapBridge).buildRequest(request)
          : null;
}

enum AiGatewayProtocolStreamEventKind {
  textDelta,
  reasoningDelta,
  toolCallDelta,
  usage,
  lifecycle,
  error,
  providerEvent,
}

/// A single provider-stream event normalized without discarding its source.
class AiGatewayProtocolStreamEvent {
  final AiGatewayProtocolStreamEventKind kind;
  final String type;
  final String? delta;
  final String? toolCallId;
  final int? toolCallIndex;
  final String? toolItemId;
  final String? toolName;
  final String? thoughtSignature;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic> raw;

  AiGatewayProtocolStreamEvent({
    required this.kind,
    required this.type,
    required this.raw,
    this.delta,
    this.toolCallId,
    this.toolCallIndex,
    this.toolItemId,
    this.toolName,
    this.thoughtSignature,
    this.usage,
  });
}

/// Per-stream correlation state for provider frames that split tool metadata
/// and arguments across separate events.
class AiGatewayProtocolStreamState {
  final Map<int, String> _anthropicToolIdsByIndex = {};
  final Map<int, String> _openAiToolIdsByIndex = {};
  final Map<String, String> _responseToolIdsByItemId = {};

  String? anthropicToolIdForIndex(int index) => _anthropicToolIdsByIndex[index];
}

/// Converts one decoded native stream frame into Gateway-owned event data.
abstract final class AiGatewayProtocolStreamBridge {
  /// Maps every semantic update represented by a provider frame. Some native
  /// frames contain several parts or tool-call deltas.
  static List<AiGatewayProtocolStreamEvent> mapEvents(
    String protocolId,
    Map<String, dynamic> event, {
    AiGatewayProtocolStreamState? state,
  }) {
    final eventType = protocolId == 'google.gemini.interactions'
        ? event['event_type'] ?? event['type']
        : event['type'];
    final type = eventType is String ? eventType : '';
    final raw = Map<String, dynamic>.unmodifiable(event);
    AiGatewayProtocolStreamEvent create(
      AiGatewayProtocolStreamEventKind kind, {
      String? delta,
      String? toolCallId,
      int? toolCallIndex,
      String? toolItemId,
      String? toolName,
      String? thoughtSignature,
      Map<String, dynamic>? usage,
    }) =>
        AiGatewayProtocolStreamEvent(
          kind: kind,
          type: type,
          raw: raw,
          delta: delta,
          toolCallId: toolCallId,
          toolCallIndex: toolCallIndex,
          toolItemId: toolItemId,
          toolName: toolName,
          thoughtSignature: thoughtSignature,
          usage: usage == null ? null : Map.unmodifiable(usage),
        );

    if (protocolId == 'openai.chat_completions') {
      final usage = _objectMap(event['usage']);
      if (usage.isNotEmpty) {
        return [create(AiGatewayProtocolStreamEventKind.usage, usage: usage)];
      }
      final choices = event['choices'];
      final delta =
          choices is List && choices.isNotEmpty && choices.first is Map
              ? (choices.first as Map)['delta']
              : null;
      if (delta is Map) {
        final mapped = <AiGatewayProtocolStreamEvent>[];
        if (delta['content'] is String) {
          mapped.add(
            create(
              AiGatewayProtocolStreamEventKind.textDelta,
              delta: delta['content'] as String,
            ),
          );
        }
        if (delta['reasoning_content'] is String) {
          mapped.add(
            create(
              AiGatewayProtocolStreamEventKind.reasoningDelta,
              delta: delta['reasoning_content'] as String,
            ),
          );
        }
        final calls = delta['tool_calls'];
        if (calls is List) {
          for (final rawCall in calls.whereType<Map>()) {
            final call = Map<String, dynamic>.from(rawCall);
            final index =
                call['index'] is num ? (call['index'] as num).toInt() : null;
            final id = _stringValue(call['id']);
            if (index != null && id != null) {
              state?._openAiToolIdsByIndex[index] = id;
            }
            final function = _objectMap(call['function']);
            mapped.add(
              create(
                AiGatewayProtocolStreamEventKind.toolCallDelta,
                delta: _stringValue(function['arguments']),
                toolCallId: id ??
                    (index == null
                        ? null
                        : state?._openAiToolIdsByIndex[index]),
                toolCallIndex: index,
                toolName: _stringValue(function['name']),
              ),
            );
          }
        }
        if (mapped.isNotEmpty) return mapped;
      }
      return [_mapSingleEvent(protocolId, event, state: state)];
    }

    if (protocolId == 'openai.responses') {
      if (type == 'response.output_item.added') {
        final item = _objectMap(event['item']);
        final itemId = _stringValue(item['id']);
        final callId = _stringValue(item['call_id']);
        if (item['type'] == 'function_call' &&
            itemId != null &&
            callId != null) {
          state?._responseToolIdsByItemId[itemId] = callId;
          return [
            create(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolCallId: callId,
              toolItemId: itemId,
              toolName: _stringValue(item['name']),
            ),
          ];
        }
      }
      if (type == 'response.function_call_arguments.delta') {
        final itemId = _stringValue(event['item_id']);
        return [
          create(
            AiGatewayProtocolStreamEventKind.toolCallDelta,
            delta: _stringValue(event['delta']),
            toolCallId: _stringValue(event['call_id']) ??
                (itemId == null
                    ? null
                    : state?._responseToolIdsByItemId[itemId]),
            toolItemId: itemId,
          ),
        ];
      }
    }

    if (protocolId == 'google.gemini.generate_content') {
      final usage = _objectMap(event['usageMetadata']);
      final usageEvent = usage.isEmpty
          ? null
          : create(AiGatewayProtocolStreamEventKind.usage, usage: usage);
      final candidates = event['candidates'];
      if (candidates is List) {
        final mapped = <AiGatewayProtocolStreamEvent>[];
        for (var candidateIndex = 0;
            candidateIndex < candidates.length;
            candidateIndex++) {
          final candidate = _objectMap(candidates[candidateIndex]);
          final parts = _objectMap(candidate['content'])['parts'];
          if (parts is! List) continue;
          for (var partIndex = 0; partIndex < parts.length; partIndex++) {
            final rawPart = parts[partIndex];
            final part = _objectMap(rawPart);
            if (part['text'] is String) {
              mapped.add(
                create(
                  part['thought'] == true
                      ? AiGatewayProtocolStreamEventKind.reasoningDelta
                      : AiGatewayProtocolStreamEventKind.textDelta,
                  delta: part['text'] as String,
                  toolCallIndex: candidateIndex,
                ),
              );
              continue;
            }
            final functionCall = _objectMap(part['functionCall']);
            if (functionCall.isNotEmpty) {
              mapped.add(
                create(
                  AiGatewayProtocolStreamEventKind.toolCallDelta,
                  toolName: _stringValue(functionCall['name']),
                  delta: jsonEncode(functionCall['args'] ?? const {}),
                  toolCallIndex: candidateIndex * 1000 + partIndex,
                  thoughtSignature: _stringValue(part['thoughtSignature']),
                ),
              );
            }
          }
        }
        if (mapped.isNotEmpty) {
          if (usageEvent != null) mapped.add(usageEvent);
          return mapped;
        }
        if (candidates.isNotEmpty) {
          final lifecycle = _mapSingleEvent(protocolId, event, state: state);
          if (usageEvent != null) return [lifecycle, usageEvent];
          return [lifecycle];
        }
      }
      if (usageEvent != null) return [usageEvent];
    }

    if (protocolId == 'ollama.chat') {
      final message = _objectMap(event['message']);
      final parts = <AiGatewayProtocolStreamEvent>[];
      final thinking = _stringValue(message['thinking']);
      if (thinking != null && thinking.isNotEmpty) {
        parts.add(
          create(
            AiGatewayProtocolStreamEventKind.reasoningDelta,
            delta: thinking,
          ),
        );
      }
      final text = _stringValue(message['content'] ?? event['delta']);
      if (text != null && text.isNotEmpty) {
        parts.add(
          create(AiGatewayProtocolStreamEventKind.textDelta, delta: text),
        );
      }
      final calls = message['tool_calls'];
      if (calls is List) {
        for (var index = 0; index < calls.length; index++) {
          final function = _objectMap(_objectMap(calls[index])['function']);
          if (function.isEmpty) continue;
          parts.add(
            create(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolCallIndex: index,
              toolName: _stringValue(function['name']),
              delta: jsonEncode(function['arguments'] ?? const {}),
            ),
          );
        }
      }
      if (event['prompt_eval_count'] is num || event['eval_count'] is num) {
        parts.add(
          create(
            AiGatewayProtocolStreamEventKind.usage,
            usage: {
              if (event['prompt_eval_count'] is num)
                'prompt_eval_count': event['prompt_eval_count'],
              if (event['eval_count'] is num) 'eval_count': event['eval_count'],
            },
          ),
        );
      }
      if (parts.isNotEmpty) return parts;
    }
    return [_mapSingleEvent(protocolId, event, state: state)];
  }

  /// Maps a frame only when it contains a single semantic event. Multi-event
  /// frames require [mapEvents] and fail here instead of silently dropping
  /// updates.
  @Deprecated('Use mapEvents; a provider frame may contain multiple updates.')
  static AiGatewayProtocolStreamEvent mapEvent(
    String protocolId,
    Map<String, dynamic> event, {
    AiGatewayProtocolStreamState? state,
  }) {
    final mapped = mapEvents(protocolId, event, state: state);
    if (mapped.length != 1) {
      throw StateError('This provider frame contains multiple stream events.');
    }
    return mapped.single;
  }

  static AiGatewayProtocolStreamEvent _mapSingleEvent(
    String protocolId,
    Map<String, dynamic> event, {
    AiGatewayProtocolStreamState? state,
  }) {
    final eventType = protocolId == 'google.gemini.interactions'
        ? event['event_type'] ?? event['type']
        : event['type'];
    final type = eventType is String ? eventType : '';
    final raw = Map<String, dynamic>.unmodifiable(event);
    AiGatewayProtocolStreamEvent make(
      AiGatewayProtocolStreamEventKind kind, {
      String? delta,
      String? toolCallId,
      int? toolCallIndex,
      String? toolName,
      Map<String, dynamic>? usage,
    }) =>
        AiGatewayProtocolStreamEvent(
          kind: kind,
          type: type,
          raw: raw,
          delta: delta,
          toolCallId: toolCallId,
          toolCallIndex: toolCallIndex,
          toolName: toolName,
          usage: usage == null ? null : Map.unmodifiable(usage),
        );

    if (event['error'] != null || type == 'error') {
      return make(AiGatewayProtocolStreamEventKind.error);
    }
    switch (protocolId) {
      case 'openai.chat_completions':
        final usage = _objectMap(event['usage']);
        if (usage.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.usage, usage: usage);
        }
        final choices = event['choices'];
        final delta =
            choices is List && choices.isNotEmpty && choices.first is Map
                ? (choices.first as Map)['delta']
                : null;
        if (delta is Map && delta['content'] is String) {
          return make(
            AiGatewayProtocolStreamEventKind.textDelta,
            delta: delta['content'] as String,
          );
        }
        if (delta is Map && delta['reasoning_content'] is String) {
          return make(
            AiGatewayProtocolStreamEventKind.reasoningDelta,
            delta: delta['reasoning_content'] as String,
          );
        }
        final calls = delta is Map ? delta['tool_calls'] : null;
        if (calls is List && calls.isNotEmpty && calls.first is Map) {
          final call = calls.first as Map;
          final function = call['function'];
          return make(
            AiGatewayProtocolStreamEventKind.toolCallDelta,
            delta: function is Map && function['arguments'] is String
                ? function['arguments'] as String
                : null,
            toolCallId: call['id'] is String
                ? call['id'] as String
                : call['index'] is num
                    ? call['index'].toString()
                    : null,
            toolName: function is Map && function['name'] is String
                ? function['name'] as String
                : null,
          );
        }
        if (choices is List && choices.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.lifecycle);
        }
      case 'openai.responses':
        if (type == 'response.failed') {
          return make(AiGatewayProtocolStreamEventKind.error);
        }
        if (type == 'response.output_text.delta') {
          return make(
            AiGatewayProtocolStreamEventKind.textDelta,
            delta: _stringValue(event['delta']),
          );
        }
        if (type == 'response.refusal.delta') {
          return make(
            AiGatewayProtocolStreamEventKind.textDelta,
            delta: _stringValue(event['delta']),
          );
        }
        if (type == 'response.reasoning_summary_text.delta') {
          return make(
            AiGatewayProtocolStreamEventKind.reasoningDelta,
            delta: _stringValue(event['delta']),
          );
        }
        if (type == 'response.function_call_arguments.delta') {
          return make(
            AiGatewayProtocolStreamEventKind.toolCallDelta,
            delta: _stringValue(event['delta']),
            toolCallId: _stringValue(event['call_id'] ?? event['item_id']),
          );
        }
        if (type == 'response.output_item.added') {
          final item = _objectMap(event['item']);
          if (item['type'] == 'function_call') {
            return make(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolCallId: _stringValue(item['call_id'] ?? item['id']),
              toolName: _stringValue(item['name']),
            );
          }
        }
        if (type.startsWith('response.')) {
          final response = _objectMap(event['response']);
          final usage = _objectMap(response['usage']);
          return make(
            usage.isEmpty
                ? AiGatewayProtocolStreamEventKind.lifecycle
                : AiGatewayProtocolStreamEventKind.usage,
            usage: usage.isEmpty ? null : usage,
          );
        }
      case 'anthropic.messages':
        final message = _objectMap(event['message']);
        final usage = _objectMap(event['usage'] ?? message['usage']);
        if (usage.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.usage, usage: usage);
        }
        final contentDelta = _objectMap(event['delta']);
        final deltaType = _stringValue(contentDelta['type']);
        if (deltaType == 'text_delta' || deltaType == 'thinking_delta') {
          return make(
            deltaType == 'text_delta'
                ? AiGatewayProtocolStreamEventKind.textDelta
                : AiGatewayProtocolStreamEventKind.reasoningDelta,
            delta: _stringValue(
              contentDelta[deltaType == 'text_delta' ? 'text' : 'thinking'],
            ),
          );
        }
        if (deltaType == 'input_json_delta') {
          final index =
              event['index'] is num ? (event['index'] as num).toInt() : null;
          return make(
            AiGatewayProtocolStreamEventKind.toolCallDelta,
            delta: _stringValue(contentDelta['partial_json']),
            toolCallId:
                index == null ? null : state?.anthropicToolIdForIndex(index),
            toolCallIndex: index,
          );
        }
        if (type == 'content_block_start') {
          final block = _objectMap(event['content_block']);
          if (block['type'] == 'tool_use') {
            final index =
                event['index'] is num ? (event['index'] as num).toInt() : null;
            final id = _stringValue(block['id']);
            if (index != null && id != null) {
              state?._anthropicToolIdsByIndex[index] = id;
            }
            return make(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolCallId: id,
              toolCallIndex: index,
              toolName: _stringValue(block['name']),
            );
          }
        }
        if (type.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.lifecycle);
        }
      case 'google.gemini.generate_content':
        final usage = _objectMap(event['usageMetadata']);
        if (usage.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.usage, usage: usage);
        }
        final candidates = event['candidates'];
        final parts = candidates is List &&
                candidates.isNotEmpty &&
                candidates.first is Map
            ? _objectMap((candidates.first as Map)['content'])['parts']
            : null;
        if (parts is List && parts.isNotEmpty && parts.first is Map) {
          final part = parts.first as Map;
          if (part['text'] is String) {
            return make(
              part['thought'] == true
                  ? AiGatewayProtocolStreamEventKind.reasoningDelta
                  : AiGatewayProtocolStreamEventKind.textDelta,
              delta: part['text'] as String,
            );
          }
          final functionCall = _objectMap(part['functionCall']);
          if (functionCall.isNotEmpty) {
            return make(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolName: _stringValue(functionCall['name']),
              delta: jsonEncode(functionCall['args'] ?? const {}),
            );
          }
        }
        if (candidates is List && candidates.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.lifecycle);
        }
      case 'google.gemini.interactions':
        if (type == 'interaction.error' || event['error'] is Map) {
          return make(AiGatewayProtocolStreamEventKind.error);
        }
        final delta = _objectMap(event['delta']);
        final eventOutput = _objectMap(event['output'] ?? event['step']);
        final output = eventOutput.isEmpty ? delta : eventOutput;
        if (type.contains('function_call') ||
            output['type'] == 'function_call') {
          final arguments = output['arguments'];
          return make(
            AiGatewayProtocolStreamEventKind.toolCallDelta,
            toolCallId: _stringValue(output['id'] ?? output['call_id']),
            toolName: _stringValue(output['name']),
            delta: arguments is String
                ? arguments
                : jsonEncode(arguments ?? const <String, dynamic>{}),
          );
        }
        final rawDelta = event['delta'];
        final interactionText = _stringValue(
          delta['text'] ??
              delta['delta'] ??
              (rawDelta is String ? rawDelta : null) ??
              output['text'],
        );
        if (interactionText != null && interactionText.isNotEmpty) {
          return make(
            AiGatewayProtocolStreamEventKind.textDelta,
            delta: interactionText,
          );
        }
        final interactionUsage = _objectMap(event['usage']);
        if (interactionUsage.isNotEmpty) {
          return make(
            AiGatewayProtocolStreamEventKind.usage,
            usage: interactionUsage,
          );
        }
        if (type.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.lifecycle);
        }
      case 'ollama.chat':
        final message = _objectMap(event['message']);
        final thinking = _stringValue(message['thinking']);
        final text = _stringValue(message['content'] ?? event['delta']);
        final calls = message['tool_calls'];
        if (calls is List && calls.isNotEmpty) {
          final function = _objectMap(_objectMap(calls.first)['function']);
          if (function.isNotEmpty) {
            return make(
              AiGatewayProtocolStreamEventKind.toolCallDelta,
              toolCallIndex: 0,
              toolName: _stringValue(function['name']),
              delta: jsonEncode(function['arguments'] ?? const {}),
            );
          }
        }
        if (thinking != null && thinking.isNotEmpty) {
          return make(
            AiGatewayProtocolStreamEventKind.reasoningDelta,
            delta: thinking,
          );
        }
        if (text != null && text.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.textDelta, delta: text);
        }
        final usage = _objectMap(event['usage'] ?? event['usageMetadata']);
        if (usage.isEmpty &&
            (event['prompt_eval_count'] is num || event['eval_count'] is num)) {
          return make(
            AiGatewayProtocolStreamEventKind.usage,
            usage: {
              if (event['prompt_eval_count'] is num)
                'prompt_eval_count': event['prompt_eval_count'],
              if (event['eval_count'] is num) 'eval_count': event['eval_count'],
            },
          );
        }
        if (usage.isNotEmpty) {
          return make(AiGatewayProtocolStreamEventKind.usage, usage: usage);
        }
        if (type.isNotEmpty || event['done'] == true) {
          return make(AiGatewayProtocolStreamEventKind.lifecycle);
        }
    }
    return make(AiGatewayProtocolStreamEventKind.providerEvent);
  }

  static Map<String, dynamic> _objectMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String? _stringValue(Object? value) => value is String ? value : null;
}

/// Neutral conversation data needed to prepare one provider request.
class AiGatewayProtocolRequest {
  final String modelId;
  final String operation;
  final List<StroomMessage> messages;
  final String? system;
  final List<Map<String, dynamic>> tools;
  final bool stream;
  final int? maxOutputTokens;
  final double? temperature;
  final Map<String, dynamic> options;
  final String? previousInteractionId;

  AiGatewayProtocolRequest({
    required this.modelId,
    required List<StroomMessage> messages,
    this.operation = 'generate',
    this.system,
    List<Map<String, dynamic>> tools = const [],
    this.stream = false,
    this.maxOutputTokens,
    this.temperature,
    Map<String, dynamic> options = const {},
    this.previousInteractionId,
  })  : messages = List.unmodifiable(messages),
        tools = List.unmodifiable(tools),
        options = Map.unmodifiable(options);
}

/// Provider-specific request body, before authentication and HTTP execution.
class AiGatewayEncodedProtocolRequest {
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final bool streams;

  AiGatewayEncodedProtocolRequest({
    this.method = 'POST',
    required this.path,
    required Map<String, dynamic> body,
    required this.streams,
  }) : body = Map.unmodifiable(body);
}

abstract base class _MapBridge
    implements AiGatewayProtocolBridge<Map<String, dynamic>> {
  const _MapBridge();

  String get _extensionKey => protocolId;

  @override
  Map<String, dynamic> fromStroom(StroomMessage message) {
    final retained = message.extensions[_extensionKey];
    if (retained is Map && retained['source'] is Map) {
      final source = _copyMap(retained['source'] as Map);
      if (jsonEncode(retained['neutral']) == jsonEncode(_snapshot(message))) {
        return source;
      }
      return source..addAll(_encodeNeutral(message));
    }
    return _encodeNeutral(message);
  }

  Map<String, dynamic> _encodeNeutral(StroomMessage message);

  AiGatewayEncodedProtocolRequest buildRequest(
    AiGatewayProtocolRequest request,
  ) {
    final countTokens = protocolId == 'anthropic.messages' &&
        request.operation == 'count_tokens';
    if (request.operation != 'generate' && !countTokens) {
      throw ArgumentError.value(request.operation, 'operation');
    }
    final topLevelSystem = const {
      'openai.responses',
      'anthropic.messages',
      'google.gemini.generate_content',
      'google.gemini.interactions',
    }.contains(protocolId);
    final systemTexts = <String>[
      if (request.system?.isNotEmpty == true) request.system!,
    ];
    if (topLevelSystem) {
      for (final message in request.messages.where(
        (message) => message.role == 'system',
      )) {
        final text = message.content
            .where((part) => part.type == 'text')
            .map((part) => part.data['text'])
            .whereType<String>()
            .join('\n');
        if (text.isNotEmpty && !systemTexts.contains(text)) {
          systemTexts.add(text);
        }
      }
    }
    final systemText = systemTexts.join('\n');
    final systemInstruction = systemText.isEmpty ? null : systemText;
    final explicitSystemIsInMessages = request.system?.isNotEmpty == true &&
        request.messages.any((message) {
          if (message.role != 'system') return false;
          final text = message.content
              .where((part) => part.type == 'text')
              .map((part) => part.data['text'])
              .whereType<String>()
              .join('\n');
          return text == request.system;
        });
    final geminiSystemFields = systemInstruction == null
        ? null
        : <String, dynamic>{
            'systemInstruction': {
              'parts': [
                {'text': systemInstruction},
              ],
            },
          };
    final interactionsSystemFields = systemInstruction == null
        ? null
        : <String, dynamic>{'system_instruction': systemInstruction};
    final anthropicSystemFields = systemInstruction == null
        ? null
        : <String, dynamic>{'system': systemInstruction};
    final messages = encodeMessages(
      topLevelSystem
          ? request.messages.where((message) => message.role != 'system')
          : request.messages,
    );
    final options = Map<String, dynamic>.from(request.options);
    final ollamaOptions = _asMap(options.remove('options'));
    final ollamaRootFields = <String, dynamic>{};
    for (final key in const {
      'format',
      'keep_alive',
      'think',
      'logprobs',
      'top_logprobs',
    }) {
      if (options.containsKey(key)) ollamaRootFields[key] = options.remove(key);
    }
    options.removeWhere(
      (key, _) => const {
        'model',
        'messages',
        'input',
        'contents',
        'stream',
        'tools',
        'system',
        'systemInstruction',
        'instructions',
        'max_tokens',
        'max_output_tokens',
        'options',
      }.contains(key),
    );
    final generationOptions = _asMap(options.remove('generationConfig'));
    final body = switch (protocolId) {
      'openai.chat_completions' => {
          'messages': [
            if (request.system?.isNotEmpty == true &&
                !explicitSystemIsInMessages)
              {'role': 'system', 'content': request.system},
            ...messages,
          ],
          if (request.maxOutputTokens != null)
            'max_tokens': request.maxOutputTokens,
          if (request.temperature != null) 'temperature': request.temperature,
          if (request.tools.isNotEmpty) 'tools': request.tools,
          'stream': request.stream,
          ...options,
          'model': request.modelId,
        },
      'openai.responses' => {
          'input': messages,
          // The formatter CI intentionally parses this file as Dart 3.0.
          // ignore: use_null_aware_elements
          if (systemInstruction != null) 'instructions': systemInstruction,
          if (request.maxOutputTokens != null)
            'max_output_tokens': request.maxOutputTokens,
          if (request.temperature != null) 'temperature': request.temperature,
          if (request.tools.isNotEmpty)
            'tools': _toolsForProtocol(request.tools, 'openai.responses'),
          'stream': request.stream,
          ...options,
          'model': request.modelId,
        },
      'anthropic.messages' => {
          'messages': messages,
          ...?anthropicSystemFields,
          if (!countTokens) 'max_tokens': request.maxOutputTokens ?? 4096,
          if (!countTokens && request.temperature != null)
            'temperature': request.temperature,
          if (request.tools.isNotEmpty)
            'tools': _toolsForProtocol(request.tools, 'anthropic.messages'),
          if (!countTokens) 'stream': request.stream,
          ...options,
          'model': request.modelId,
        },
      'google.gemini.generate_content' => {
          'contents': messages,
          ...?geminiSystemFields,
          if (request.maxOutputTokens != null ||
              request.temperature != null ||
              generationOptions.isNotEmpty)
            'generationConfig': {
              if (request.maxOutputTokens != null)
                'maxOutputTokens': request.maxOutputTokens,
              if (request.temperature != null)
                'temperature': request.temperature,
              ...generationOptions,
            },
          if (request.tools.isNotEmpty)
            'tools': _toolsForProtocol(
              request.tools,
              'google.gemini.generate_content',
            ),
          ...options,
        },
      'google.gemini.interactions' => {
          'input': _interactionInputs(
            request.previousInteractionId == null || request.messages.isEmpty
                ? request.messages
                : [request.messages.last],
          ),
          ...?interactionsSystemFields,
          if (request.previousInteractionId != null)
            'previous_interaction_id': request.previousInteractionId,
          if (request.tools.isNotEmpty)
            'tools': _toolsForProtocol(
              request.tools,
              'google.gemini.interactions',
            ),
          if (request.maxOutputTokens != null ||
              request.temperature != null ||
              generationOptions.isNotEmpty)
            'generation_config': {
              if (request.maxOutputTokens != null)
                'max_output_tokens': request.maxOutputTokens,
              if (request.temperature != null)
                'temperature': request.temperature,
              ...generationOptions,
            },
          'stream': request.stream,
          ...options,
          'model': request.modelId,
        },
      'ollama.chat' => {
          'messages': [
            if (request.system?.isNotEmpty == true &&
                !explicitSystemIsInMessages)
              {'role': 'system', 'content': request.system},
            ...messages,
          ],
          ...ollamaRootFields,
          if (request.tools.isNotEmpty) 'tools': request.tools,
          'stream': request.stream,
          'options': {
            if (request.temperature != null) 'temperature': request.temperature,
            ...ollamaOptions,
            ...options,
            if (request.maxOutputTokens != null)
              'num_predict': request.maxOutputTokens,
          },
          'model': request.modelId,
        },
      _ => throw ArgumentError.value(protocolId, 'protocolId'),
    };
    final path = switch (protocolId) {
      'openai.chat_completions' => '/v1/chat/completions',
      'openai.responses' => '/v1/responses',
      'anthropic.messages' =>
        countTokens ? '/v1/messages/count_tokens' : '/v1/messages',
      'google.gemini.generate_content' =>
        '/v1beta/models/${Uri.encodeComponent(request.modelId)}:'
            '${request.stream ? 'streamGenerateContent?alt=sse' : 'generateContent'}',
      'google.gemini.interactions' =>
        '/v1beta/interactions${request.stream ? '?alt=sse' : ''}',
      'ollama.chat' => '/api/chat',
      _ => throw ArgumentError.value(protocolId, 'protocolId'),
    };
    return AiGatewayEncodedProtocolRequest(
      path: path,
      body: body,
      streams: request.stream && !countTokens,
    );
  }

  List<Map<String, dynamic>> encodeMessages(Iterable<StroomMessage> messages) =>
      messages.map(fromStroom).toList(growable: false);

  List<Map<String, dynamic>> _toolsForProtocol(
    List<Map<String, dynamic>> tools,
    String targetProtocol,
  ) {
    Map<String, dynamic> functionOf(Map<String, dynamic> tool) {
      final nested = tool['function'];
      return nested is Map
          ? Map<String, dynamic>.from(nested)
          : Map<String, dynamic>.from(tool);
    }

    return switch (targetProtocol) {
      'openai.responses' => [
          for (final tool in tools)
            if (tool['type'] == 'function' && tool['function'] is Map)
              {'type': 'function', ...functionOf(tool)}
            else
              Map<String, dynamic>.from(tool),
        ],
      'anthropic.messages' => [
          for (final tool in tools)
            if (tool['type'] == 'function' && tool['function'] is Map)
              _anthropicTool(functionOf(tool))
            else if (tool['name'] is String && tool['input_schema'] is Map)
              Map<String, dynamic>.from(tool)
            else
              Map<String, dynamic>.from(tool),
        ],
      'google.gemini.generate_content' => [
          if (tools.every((tool) => tool['functionDeclarations'] is List))
            ...tools.map(Map<String, dynamic>.from)
          else
            {
              'functionDeclarations': [
                for (final tool in tools)
                  if (tool['type'] == 'function' && tool['function'] is Map)
                    {
                      'name': functionOf(tool)['name'],
                      if (functionOf(tool)['description'] != null)
                        'description': functionOf(tool)['description'],
                      if (functionOf(tool)['parameters'] is Map)
                        'parameters': functionOf(tool)['parameters'],
                    }
                  else
                    Map<String, dynamic>.from(tool),
              ],
            },
        ],
      'google.gemini.interactions' => [
          for (final tool in tools)
            if (tool['type'] == 'function' && tool['function'] is Map)
              {'type': 'function', ...functionOf(tool)}
            else
              Map<String, dynamic>.from(tool),
        ],
      _ => [for (final tool in tools) Map<String, dynamic>.from(tool)],
    };
  }

  Map<String, dynamic> _anthropicTool(Map<String, dynamic> function) => {
        for (final entry in function.entries)
          if (!const {'parameters'}.contains(entry.key)) entry.key: entry.value,
        'input_schema': function['parameters'] is Map
            ? function['parameters']
            : const {'type': 'object', 'properties': <String, dynamic>{}},
      };

  Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<Map<String, dynamic>> _interactionInputs(
    Iterable<StroomMessage> messages,
  ) =>
      [for (final message in messages) ..._interactionMessage(message)];

  List<Map<String, dynamic>> _interactionMessage(StroomMessage message) {
    final source = message.extensions['google.gemini.interactions'];
    if (source is Map &&
        source['source'] is Map &&
        jsonEncode(source['neutral']) == jsonEncode(_snapshot(message))) {
      final retained = _copyValueMap(source['source']);
      final steps = retained['steps'];
      if (steps is List) {
        return [for (final step in steps.whereType<Map>()) _copyMap(step)];
      }
      final outputs = retained['outputs'];
      if (outputs is List) {
        return [
          for (final output in outputs.whereType<Map>()) _copyMap(output),
        ];
      }
    }
    final contents = <Map<String, dynamic>>[];
    final steps = <Map<String, dynamic>>[];
    for (final part in message.content) {
      if (part.type == 'text') {
        contents.add(
          _overlaySource(_targetSource(message, part), {
            'type': 'text',
            'text': part.data['text'],
          }),
        );
      } else if (part.type == 'image') {
        final source = _targetSource(message, part);
        if (source.isEmpty) {
          throw UnsupportedError(
            'This image has no Gemini Interactions representation.',
          );
        }
        contents.add(source);
      } else if (part.type == 'tool_call') {
        steps.add({
          ..._targetSource(message, part),
          'type': 'function_call',
          'id': part.data['id'],
          'name': part.data['name'],
          'arguments': part.data['arguments'],
        });
      } else if (part.type == 'tool_result') {
        steps.add({
          ..._targetSource(message, part),
          'type': 'function_result',
          'call_id': part.data['toolCallId'],
          if (part.data['name'] != null) 'name': part.data['name'],
          'result': part.data['result'],
        });
      } else if (part.type == 'reasoning') {
        contents.add({
          'type': 'text',
          'text': part.data['text'],
          ..._targetSource(message, part),
        });
      }
    }
    if (message.role == 'assistant' && contents.isNotEmpty) {
      steps.insert(0, {'type': 'model_output', 'content': contents});
    } else if (contents.isNotEmpty) {
      steps.insertAll(0, contents);
    }
    return steps;
  }

  StroomMessage _message(
    Map<String, dynamic> source, {
    required String role,
    required List<StroomContentPart> content,
    String? id,
    String? finishReason,
    Map<String, dynamic>? usage,
    Map<String, dynamic> extraExtensions = const {},
  }) {
    final neutralSnapshot = {
      'id': id ?? '',
      'role': role,
      'content': content.map((part) => part.toMap()).toList(),
      ...?(finishReason == null ? null : {'finishReason': finishReason}),
      ...?(usage == null ? null : {'usage': usage}),
    };
    final extensions = <String, dynamic>{
      ...extraExtensions,
      _extensionKey: {
        ...source,
        ..._copyValueMap(extraExtensions[_extensionKey]),
        'source': _copyMap(source),
        'neutral': neutralSnapshot,
      },
    };
    return StroomMessage(
      id: id ?? '',
      role: role,
      sequence: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      content: content,
      finishReason: finishReason,
      usage: usage,
      extensions: extensions,
    );
  }

  Map<String, dynamic> _snapshot(StroomMessage message) => {
        'id': message.id,
        'role': message.role,
        'content': message.content.map((part) => part.toMap()).toList(),
        if (message.finishReason != null) 'finishReason': message.finishReason,
        if (message.usage != null) 'usage': message.usage,
      };

  List<StroomContentPart> _textParts(Object? value) {
    if (value is String) {
      return value.isEmpty ? [] : [StroomContentPart.text(value)];
    }
    if (value is! List) return [];
    final parts = <StroomContentPart>[];
    for (final item in value.whereType<Map>()) {
      final text = _textBlock(item);
      if (text != null) {
        parts.add(text);
      } else if (const {
        'image_url',
        'input_image',
        'output_image',
      }.contains(item['type'])) {
        parts.add(
          StroomContentPart(
            type: 'image',
            data: {
              if (item['image_url'] != null) 'imageUrl': item['image_url'],
              'source': _copyMap(item),
            },
          ),
        );
      } else {
        parts.add(_genericPart(item));
      }
    }
    return parts;
  }

  StroomContentPart? _textBlock(Map item) {
    final type = item['type'];
    if (const {'text', 'input_text', 'output_text'}.contains(type) &&
        item['text'] is String) {
      return StroomContentPart(
        type: 'text',
        data: {'text': item['text'], 'source': _copyMap(item)},
      );
    }
    return null;
  }

  Map<String, dynamic> _copyMap(Map value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  Map<String, dynamic> _copyValueMap(Object? value) =>
      value is Map ? _copyMap(value) : <String, dynamic>{};

  String _toolResultText(Object? value) =>
      value is String ? value : jsonEncode(value);

  String _string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return _copyMap(decoded);
      } on FormatException {
        // Invalid tool arguments remain available through the source extension.
      }
    }
    return <String, dynamic>{};
  }

  List<StroomContentPart> _partsOfType(StroomMessage message, String type) =>
      message.content
          .where((part) => part.type == type)
          .toList(growable: false);

  Map<String, dynamic> _sourceOf(StroomContentPart part) =>
      _copyValueMap(part.data['source'] ?? part.extraFields['source']);

  Map<String, dynamic> _targetSource(
    StroomMessage message,
    StroomContentPart part,
  ) =>
      message.extensions[_extensionKey] is Map ? _sourceOf(part) : {};

  Map<String, dynamic> _overlaySource(
    Map<String, dynamic> source,
    Map<String, dynamic> fields,
  ) =>
      source..addAll(fields);

  StroomContentPart _genericPart(Map item) => StroomContentPart(
        type: _string(item['type'], 'unknown'),
        data: {'source': _copyMap(item)},
      );
}

final class _OpenAiChatCompletionsBridge extends _MapBridge {
  const _OpenAiChatCompletionsBridge();

  @override
  String get protocolId => 'openai.chat_completions';

  @override
  List<Map<String, dynamic>> encodeMessages(Iterable<StroomMessage> messages) =>
      [for (final message in messages) ..._encodeMessageItems(message)];

  List<Map<String, dynamic>> _encodeMessageItems(StroomMessage message) {
    final retained = message.extensions[protocolId];
    if (retained is Map &&
        retained['source'] is Map &&
        jsonEncode(retained['neutral']) == jsonEncode(_snapshot(message))) {
      return [super.fromStroom(message)];
    }
    final results = _partsOfType(message, 'tool_result');
    if (results.isEmpty) return [fromStroom(message)];

    final remainingContent =
        message.content.where((part) => part.type != 'tool_result').toList();
    final encoded = <Map<String, dynamic>>[];
    if (remainingContent.isNotEmpty) {
      encoded.add(
        super.fromStroom(
          StroomMessage(
            id: message.id,
            role: message.role,
            sequence: message.sequence,
            createdAt: message.createdAt,
            content: remainingContent,
            finishReason: message.finishReason,
            usage: message.usage,
            extensions: message.extensions,
            extraFields: message.extraFields,
          ),
        ),
      );
    }
    final messageSource = _copyValueMap(
      retained is Map ? retained['source'] : null,
    );
    for (final result in results) {
      final value = result.data['result'];
      encoded.add(
        _overlaySource(_targetSource(message, result), {
          ...messageSource,
          'role': 'tool',
          'tool_call_id': _string(result.data['toolCallId']),
          'content': value is String ? value : jsonEncode(value),
        }),
      );
    }
    return encoded;
  }

  @override
  StroomMessage toStroom(Map<String, dynamic> message) {
    final content = _textParts(message['content']);
    final role = _string(message['role'], 'unknown');
    if (role == 'tool') {
      content
        ..clear()
        ..add(
          StroomContentPart.toolResult(
            toolCallId: _string(message['tool_call_id']),
            result: message['content'],
            extraFields: {'source': _copyMap(message)},
          ),
        );
    }
    final reasoning = message['reasoning_content'];
    if (reasoning is String && reasoning.isNotEmpty) {
      content.add(StroomContentPart.reasoning(reasoning, complete: true));
    }
    final calls = message['tool_calls'];
    if (calls is List) {
      for (final raw in calls.whereType<Map>()) {
        final function = raw['function'];
        if (function is! Map) {
          content.add(_genericPart(raw));
          continue;
        }
        content.add(
          StroomContentPart.toolCall(
            id: _string(raw['id']),
            name: _string(function['name'], 'unknown'),
            arguments: _jsonObject(function['arguments']),
            extraFields: {'source': _copyMap(raw)},
          ),
        );
      }
    }
    return _message(
      message,
      role: role,
      content: content,
      id: _string(message['id']),
      finishReason: _string(message['finish_reason'], ''),
      usage: _copyValueMap(message['usage']),
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) {
    final toolResults = _partsOfType(message, 'tool_result');
    if (toolResults.isNotEmpty) {
      if (toolResults.length != 1 || message.content.length != 1) {
        throw UnsupportedError(
          'OpenAI Chat Completions cannot encode multiple tool results in one message.',
        );
      }
      final result = toolResults.single;
      return {
        'role': 'tool',
        'tool_call_id': _string(result.data['toolCallId']),
        'content': _toolResultText(result.data['result']),
      };
    }
    return {
      'role': message.role,
      'content': _openAiContent(message),
      if (_partsOfType(message, 'reasoning').isNotEmpty)
        'reasoning_content': _partsOfType(
          message,
          'reasoning',
        ).map((part) => part.data['text']).whereType<String>().join(),
      if (_partsOfType(message, 'tool_call').isNotEmpty)
        'tool_calls': [
          for (final part in _partsOfType(message, 'tool_call'))
            _overlaySource(_targetSource(message, part), {
              'id': _string(part.data['id']),
              'type': 'function',
              'function': {
                ..._copyValueMap(_targetSource(message, part)['function']),
                'name': _string(part.data['name'], 'unknown'),
                'arguments': jsonEncode(_copyValueMap(part.data['arguments'])),
              },
            }),
        ],
    };
  }

  Object _openAiContent(StroomMessage message) {
    final text = _partsOfType(message, 'text');
    final hasMultimodalContent = message.content.any(
      (part) => !const {
        'text',
        'reasoning',
        'tool_call',
        'tool_result',
      }.contains(part.type),
    );
    if (!hasMultimodalContent) {
      return text.map((part) => part.data['text']).whereType<String>().join();
    }
    final content = <Map<String, dynamic>>[];
    for (final part in message.content) {
      if (part.type == 'text') {
        content.add({'type': 'text', 'text': part.data['text']});
      } else if (part.type == 'image') {
        final source = _targetSource(message, part);
        if (source['type'] == 'image_url') {
          content.add(source);
        } else {
          final imageValue = part.data['imageUrl'] ?? source['image_url'];
          final url = imageValue is Map ? imageValue['url'] : imageValue;
          content.add({
            'type': 'image_url',
            'image_url': {
              if (url is String)
                'url': url
              else if (part.data['reference'] is String)
                'url': part.data['reference'],
            },
          });
        }
      } else if (!const {
        'reasoning',
        'tool_call',
        'tool_result',
      }.contains(part.type)) {
        final source = _targetSource(message, part);
        if (source.isNotEmpty) {
          content.add(source);
        } else {
          throw UnsupportedError(
            'OpenAI Chat Completions cannot map ${part.type} content.',
          );
        }
      }
    }
    return content;
  }
}

final class _OpenAiResponsesBridge extends _MapBridge {
  const _OpenAiResponsesBridge();

  @override
  String get protocolId => 'openai.responses';

  @override
  Map<String, dynamic> fromStroom(StroomMessage message) {
    final retained = message.extensions[protocolId];
    if (retained is Map &&
        retained['source'] is Map &&
        jsonEncode(retained['neutral']) == jsonEncode(_snapshot(message))) {
      return super.fromStroom(message);
    }
    final items = _encodeMessageItems(message);
    if (items.length != 1) {
      throw UnsupportedError(
        'This Stroom message maps to multiple Responses items; encode it as a message sequence.',
      );
    }
    return items.single;
  }

  @override
  List<Map<String, dynamic>> encodeMessages(Iterable<StroomMessage> messages) =>
      [for (final message in messages) ..._encodeMessageItems(message)];

  List<Map<String, dynamic>> _encodeMessageItems(StroomMessage message) {
    final retained = message.extensions[protocolId];
    if (retained is Map &&
        retained['source'] is Map &&
        jsonEncode(retained['neutral']) == jsonEncode(_snapshot(message))) {
      return [super.fromStroom(message)];
    }
    final visibleParts = message.content.where(
      (part) => part.type == 'text' || part.type == 'image',
    );
    final items = <Map<String, dynamic>>[];
    if (visibleParts.isNotEmpty) {
      items.add({
        'type': 'message',
        'role': message.role,
        'content': [
          for (final part in visibleParts)
            if (part.type == 'text')
              {
                'type': message.role == 'user' ? 'input_text' : 'output_text',
                'text': part.data['text'],
              }
            else
              _responsesImageContent(part, message),
        ],
      });
    }
    for (final part in message.content) {
      if (part.type == 'reasoning') {
        items.add({
          ..._targetSource(message, part),
          'type': 'reasoning',
          'summary': [
            {'type': 'summary_text', 'text': part.data['text']},
          ],
        });
      } else if (part.type == 'tool_call') {
        items.add({
          ..._targetSource(message, part),
          'type': 'function_call',
          'call_id': part.data['id'],
          'name': part.data['name'],
          'arguments': jsonEncode(_copyValueMap(part.data['arguments'])),
        });
      } else if (part.type == 'tool_result') {
        items.add({
          ..._targetSource(message, part),
          'type': 'function_call_output',
          'call_id': part.data['toolCallId'],
          'output': _toolResultText(part.data['result']),
        });
      } else if (part.type != 'text' && part.type != 'image') {
        final source = _targetSource(message, part);
        if (source.isEmpty) {
          throw UnsupportedError(
            'Responses cannot represent this ${part.type} content part.',
          );
        }
        items.add(source);
      }
    }
    if (items.isEmpty) {
      items.add({'type': 'message', 'role': message.role, 'content': []});
    }
    return items;
  }

  Map<String, dynamic> _responsesImageContent(
    StroomContentPart part,
    StroomMessage message,
  ) {
    final source = _targetSource(message, part);
    if (source['type'] == 'input_image' || source['type'] == 'output_image') {
      return source;
    }
    final imageUrl = part.data['imageUrl'];
    final url = imageUrl is Map
        ? imageUrl['url']
        : imageUrl is String
            ? imageUrl
            : part.data['reference'];
    final detail = imageUrl is Map ? imageUrl['detail'] : null;
    if (detail is String && !const {'auto', 'low', 'high'}.contains(detail)) {
      throw UnsupportedError(
        'OpenAI Responses does not support image detail "$detail".',
      );
    }
    return {
      'type': message.role == 'user' ? 'input_image' : 'output_image',
      if (url is String) 'image_url': url,
      if (detail is String) 'detail': detail,
    };
  }

  @override
  StroomMessage toStroom(Map<String, dynamic> item) {
    final type = _string(item['type']);
    final content = <StroomContentPart>[];
    if (type == 'function_call' || type == 'tool_call') {
      content.add(
        StroomContentPart.toolCall(
          id: _string(item['call_id'], _string(item['id'])),
          name: _string(item['name'], 'unknown'),
          arguments: _jsonObject(item['arguments']),
          extraFields: {
            'itemId': _string(item['id']),
            'source': _copyMap(item),
          },
        ),
      );
    } else if (type == 'function_call_output' || type == 'tool_result') {
      content.add(
        StroomContentPart.toolResult(
          toolCallId: _string(item['call_id']),
          result: item['output'],
          isError: item['is_error'] == true,
          extraFields: {'source': _copyMap(item)},
        ),
      );
    } else if (type == 'input_image' || type == 'output_image') {
      content.add(
        StroomContentPart(
          type: 'image',
          data: {
            if (item['image_url'] != null) 'imageUrl': item['image_url'],
            'source': _copyMap(item),
          },
        ),
      );
    } else {
      content.addAll(_textParts(item['content'] ?? item['output']));
      if (type == 'reasoning') {
        final summary = item['summary'];
        if (summary is List) {
          for (final block in summary.whereType<Map>()) {
            if (block['text'] is String) {
              content.add(
                StroomContentPart.reasoning(
                  block['text'] as String,
                  complete: true,
                ),
              );
            }
          }
        }
      }
      if (content.isEmpty && item.isNotEmpty) content.add(_genericPart(item));
    }
    return _message(
      item,
      role: _string(
        item['role'],
        type == 'function_call_output' ? 'tool' : 'assistant',
      ),
      content: content,
      id: _string(item['id'], _string(item['call_id'])),
      finishReason: _string(item['status'], ''),
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) => {
        if (_partsOfType(message, 'tool_call').isNotEmpty)
          ..._overlaySource(
            _targetSource(message, _partsOfType(message, 'tool_call').first),
            {
              'type': 'function_call',
              'call_id': _string(
                _partsOfType(message, 'tool_call').first.data['id'],
              ),
              'name': _string(
                _partsOfType(message, 'tool_call').first.data['name'],
              ),
              'arguments': jsonEncode(
                _copyValueMap(
                  _partsOfType(message, 'tool_call').first.data['arguments'],
                ),
              ),
            },
          )
        else ...{
          'type': 'message',
          'role': message.role,
          'content': [
            for (final part in message.content)
              if (part.type == 'text')
                {'type': 'output_text', 'text': part.data['text']}
              else if (part.type == 'image')
                _responsesImageContent(part, message),
          ],
        },
      };
}

final class _AnthropicMessagesBridge extends _MapBridge {
  const _AnthropicMessagesBridge();

  @override
  String get protocolId => 'anthropic.messages';

  @override
  StroomMessage toStroom(Map<String, dynamic> message) {
    final content = <StroomContentPart>[];
    final blocks = message['content'];
    if (blocks is List) {
      for (final raw in blocks.whereType<Map>()) {
        switch (raw['type']) {
          case 'text':
            if (raw['text'] is String) {
              content.add(
                StroomContentPart(
                  type: 'text',
                  data: {'text': raw['text'], 'source': _copyMap(raw)},
                ),
              );
            }
          case 'thinking':
          case 'redacted_thinking':
            content.add(
              StroomContentPart(
                type: 'reasoning',
                data: {
                  'text': _string(raw['thinking']),
                  'complete': true,
                  'source': _copyMap(raw),
                  if (raw.containsKey('signature'))
                    'signature': raw['signature'],
                },
              ),
            );
          case 'tool_use':
            content.add(
              StroomContentPart.toolCall(
                id: _string(raw['id']),
                name: _string(raw['name'], 'unknown'),
                arguments: _copyValueMap(raw['input']),
                extraFields: {'source': _copyMap(raw)},
              ),
            );
          case 'tool_result':
            content.add(
              StroomContentPart.toolResult(
                toolCallId: _string(raw['tool_use_id']),
                result: raw['content'],
                isError: raw['is_error'] == true,
                extraFields: {'source': _copyMap(raw)},
              ),
            );
          case 'image':
            content.add(
              StroomContentPart(
                type: 'image',
                data: {
                  'source': _copyMap(raw),
                  'mediaType': raw['source'] is Map
                      ? (raw['source'] as Map)['media_type']
                      : null,
                },
              ),
            );
          default:
            content.add(_genericPart(raw));
        }
      }
    } else {
      content.addAll(_textParts(blocks));
    }
    return _message(
      message,
      role: _string(message['role'], 'assistant'),
      content: content,
      id: _string(message['id']),
      finishReason: _string(message['stop_reason'], ''),
      usage: _copyValueMap(message['usage']),
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) => {
        'role': message.role == 'tool' ? 'user' : message.role,
        'content': [
          for (final part in message.content)
            if (part.type == 'text')
              _overlaySource(_targetSource(message, part), {
                'type': 'text',
                'text': part.data['text'],
              })
            else if (part.type == 'reasoning')
              _encodeAnthropicReasoning(message, part)
            else if (part.type == 'tool_call')
              _overlaySource(_targetSource(message, part), {
                'type': 'tool_use',
                'id': part.data['id'],
                'name': part.data['name'],
                'input': part.data['arguments'],
              })
            else if (part.type == 'tool_result')
              _overlaySource(_targetSource(message, part), {
                'type': 'tool_result',
                'tool_use_id': part.data['toolCallId'],
                'content': _toolResultText(part.data['result']),
                if (part.data['isError'] == true) 'is_error': true,
              })
            else if (part.type == 'image')
              _encodeAnthropicImage(message, part)
            else if (part.type == 'document' && part.data['source'] is Map)
              _copyValueMap(part.data['source'])
            else if (_targetSource(message, part).isNotEmpty)
              _targetSource(message, part)
            else
              throw UnsupportedError(
                'Anthropic Messages cannot map ${part.type} content.',
              ),
        ],
      };

  Map<String, dynamic> _encodeAnthropicReasoning(
    StroomMessage message,
    StroomContentPart part,
  ) {
    final source = _targetSource(message, part);
    if (source['type'] == 'redacted_thinking') return source;
    return _overlaySource(source, {
      'type': 'thinking',
      'thinking': part.data['text'],
      if (part.data['signature'] != null) 'signature': part.data['signature'],
    });
  }

  Map<String, dynamic> _encodeAnthropicImage(
    StroomMessage message,
    StroomContentPart part,
  ) {
    final source = _targetSource(message, part);
    if (source['type'] == 'image' && source['source'] is Map) {
      return _copyMap(source);
    }
    final imageValue =
        part.data['imageUrl'] ?? part.data['reference'] ?? source['image_url'];
    if (imageValue is Map && imageValue['detail'] != null) {
      throw UnsupportedError(
        'Anthropic Messages does not support OpenAI image detail hints.',
      );
    }
    final rawUrl = imageValue is Map ? imageValue['url'] : imageValue;
    if (rawUrl is! String || rawUrl.isEmpty) {
      throw UnsupportedError('Anthropic image input requires an image URL.');
    }
    final dataUrl = RegExp(
      r'^data:([^;,]+);base64,(.+)$',
      dotAll: true,
    ).firstMatch(rawUrl);
    if (dataUrl != null) {
      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': dataUrl.group(1),
          'data': dataUrl.group(2),
        },
      };
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri?.scheme == 'https' && uri!.host.isNotEmpty) {
      return {
        'type': 'image',
        'source': {'type': 'url', 'url': rawUrl},
      };
    }
    throw UnsupportedError(
      'Anthropic image references must be HTTPS URLs or base64 data URLs.',
    );
  }
}

final class _GeminiGenerateContentBridge extends _MapBridge {
  const _GeminiGenerateContentBridge();

  @override
  String get protocolId => 'google.gemini.generate_content';

  @override
  List<Map<String, dynamic>> encodeMessages(Iterable<StroomMessage> messages) =>
      _encodeConversation(messages.toList(growable: false));

  List<Map<String, dynamic>> _encodeConversation(List<StroomMessage> messages) {
    final toolNames = <String, String>{};
    for (final message in messages) {
      for (final part in message.content.where(
        (part) => part.type == 'tool_call',
      )) {
        final id = part.data['id'];
        final name = part.data['name'];
        if (id is String &&
            id.isNotEmpty &&
            name is String &&
            name.isNotEmpty) {
          toolNames[id] = name;
        }
      }
    }

    return [
      for (final message in messages)
        _encodeConversationMessage(message, toolNames),
    ];
  }

  Map<String, dynamic> _encodeConversationMessage(
    StroomMessage message,
    Map<String, String> toolNames,
  ) {
    final encoded = _encodeNeutral(message);
    if (message.role != 'tool') return encoded;
    final parts = encoded['parts'];
    if (parts is! List) return encoded;
    return {
      ...encoded,
      'role': 'user',
      'parts': [
        for (final raw in parts.whereType<Map>())
          if (raw['functionResponse'] is Map)
            _encodeFunctionResponse(raw, toolNames)
          else
            _copyMap(raw),
      ],
    };
  }

  String? _functionResponseName(Map raw, Map<String, String> toolNames) {
    final response = _asMap(raw['functionResponse']);
    final existing = response['name'];
    if (existing is String && existing.isNotEmpty) return existing;
    final id = response['id'];
    return id is String ? toolNames[id] : null;
  }

  Map<String, dynamic> _encodeFunctionResponse(
    Map raw,
    Map<String, String> toolNames,
  ) {
    final name = _functionResponseName(raw, toolNames);
    if (name == null) {
      throw UnsupportedError(
        'Gemini function responses require a matching function call name.',
      );
    }
    return _overlaySource(_copyMap(raw), {
      'functionResponse': {
        ..._copyValueMap(raw['functionResponse']),
        'name': name,
      },
    });
  }

  @override
  StroomMessage toStroom(Map<String, dynamic> contentRecord) {
    final content = <StroomContentPart>[];
    final candidates = contentRecord['candidates'];
    final candidate =
        candidates is List ? candidates.whereType<Map>().firstOrNull : null;
    final candidateContent = candidate?['content'];
    final parts = candidateContent is Map
        ? candidateContent['parts']
        : contentRecord['parts'];
    if (parts is List) {
      for (final raw in parts.whereType<Map>()) {
        final text = raw['text'];
        if (text is String) {
          content.add(
            StroomContentPart(
              type: raw['thought'] == true ? 'reasoning' : 'text',
              data: {
                'text': text,
                if (raw['thought'] == true) 'complete': true,
                'source': _copyMap(raw),
                if (raw.containsKey('thoughtSignature'))
                  'thoughtSignature': raw['thoughtSignature'],
              },
            ),
          );
        } else if (raw['inlineData'] is Map) {
          final data = _copyValueMap(raw['inlineData']);
          content.add(
            StroomContentPart(
              type: data['mimeType'] is String &&
                      (data['mimeType'] as String).startsWith('image/')
                  ? 'image'
                  : 'media',
              data: {'inlineData': data, 'source': _copyMap(raw)},
            ),
          );
        } else if (raw['fileData'] is Map) {
          content.add(
            StroomContentPart(
              type: 'media',
              data: {
                'fileData': _copyValueMap(raw['fileData']),
                'source': _copyMap(raw),
              },
            ),
          );
        } else if (raw['functionCall'] is Map) {
          final call = _copyValueMap(raw['functionCall']);
          content.add(
            StroomContentPart.toolCall(
              id: _string(call['id']),
              name: _string(call['name'], 'unknown'),
              arguments: _copyValueMap(call['args']),
              extraFields: {'source': _copyMap(raw)},
            ),
          );
        } else if (raw['functionResponse'] is Map) {
          final result = _copyValueMap(raw['functionResponse']);
          content.add(
            StroomContentPart.toolResult(
              toolCallId: _string(result['id']),
              name: _string(result['name']),
              result: result['response'],
              extraFields: {'source': _copyMap(raw)},
            ),
          );
        } else {
          content.add(_genericPart(raw));
        }
      }
    }
    final sourceRole = _string(
      candidateContent is Map
          ? candidateContent['role']
          : contentRecord['role'],
      'model',
    );
    return _message(
      contentRecord,
      role: sourceRole == 'model' ? 'assistant' : sourceRole,
      content: content,
      id: _string(contentRecord['id']),
      finishReason: _string(candidate?['finishReason'], ''),
      usage: _copyValueMap(contentRecord['usageMetadata']),
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) => {
        'role': switch (message.role) {
          'assistant' => 'model',
          'tool' => 'user',
          final role => role,
        },
        'parts': [
          for (final part in message.content)
            if (part.type == 'text')
              _overlaySource(_targetSource(message, part), {
                'text': part.data['text'],
              })
            else if (part.type == 'reasoning')
              _overlaySource(_targetSource(message, part), {
                'text': part.data['text'],
                'thought': true,
                if (part.data['thoughtSignature'] != null)
                  'thoughtSignature': part.data['thoughtSignature'],
              })
            else if (part.type == 'image' || part.type == 'media')
              _geminiMediaPart(message, part)
            else if (part.type == 'tool_call')
              _overlaySource(_targetSource(message, part), {
                'functionCall': {
                  ..._copyValueMap(
                      _targetSource(message, part)['functionCall']),
                  'id': part.data['id'],
                  'name': part.data['name'],
                  'args': part.data['arguments'],
                },
                if (_sourceOf(part)['thoughtSignature'] != null)
                  'thoughtSignature': _sourceOf(part)['thoughtSignature'],
              })
            else if (part.type == 'tool_result')
              _overlaySource(_targetSource(message, part), {
                'functionResponse': {
                  ..._copyValueMap(
                    _targetSource(message, part)['functionResponse'],
                  ),
                  'id': part.data['toolCallId'],
                  if (part.data['name'] != null) 'name': part.data['name'],
                  'response': part.data['result'],
                },
              })
            else if (const {
              'input_audio',
              'audio_url',
              'video_url',
              'file',
              'document',
            }.contains(part.type))
              _geminiGenericMediaPart(part)
            else if (_targetSource(message, part).isNotEmpty)
              _targetSource(message, part)
            else
              _rejectUnsupportedGeminiPart(part),
        ],
      };

  Map<String, dynamic> _rejectUnsupportedGeminiPart(StroomContentPart part) =>
      throw UnsupportedError(
        'Gemini cannot map ${part.type} content from another protocol.',
      );

  Map<String, dynamic> _geminiMediaPart(
    StroomMessage message,
    StroomContentPart part,
  ) {
    final source = _targetSource(message, part);
    final inlineData = part.data['inlineData'] ?? source['inlineData'];
    if (inlineData is Map) {
      return _overlaySource(source, {'inlineData': _copyMap(inlineData)});
    }
    final fileData = part.data['fileData'] ?? source['fileData'];
    if (fileData is Map) {
      return _overlaySource(source, {'fileData': _copyMap(fileData)});
    }

    final imageValue = part.data['reference'] ?? part.data['imageUrl'];
    final reference = imageValue is Map ? imageValue['url'] : imageValue;
    if (reference is String) {
      final dataUri = RegExp(
        r'^data:([^;,]+);base64,(.*)$',
      ).firstMatch(reference);
      if (dataUri != null) {
        return _overlaySource(source, {
          'inlineData': {
            'mimeType': dataUri.group(1),
            'data': dataUri.group(2),
          },
        });
      }
      final uri = Uri.tryParse(reference);
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'gs') &&
          uri.host.isNotEmpty) {
        return _overlaySource(source, {
          'fileData': {
            'fileUri': reference,
            if (part.data['mimeType'] is String)
              'mimeType': part.data['mimeType'],
          },
        });
      }
    }
    throw UnsupportedError(
      'Gemini image references must be base64 data or an HTTPS/gs URI.',
    );
  }

  Map<String, dynamic> _geminiGenericMediaPart(StroomContentPart part) {
    final source = _sourceOf(part);
    final sourceType = _string(source['type'], part.type);
    if (sourceType == 'input_audio') {
      final audio = _asMap(source['input_audio']);
      final rawData = audio['data'];
      if (rawData is! String || rawData.isEmpty) {
        throw UnsupportedError('Gemini audio input requires audio data.');
      }
      final dataUri = RegExp(
        r'^data:([^;,]+);base64,(.*)$',
        dotAll: true,
      ).firstMatch(rawData);
      final format = _string(audio['format']).toLowerCase();
      final mimeType = dataUri?.group(1) ??
          (audio['mime_type'] is String
              ? audio['mime_type'] as String
              : switch (format) {
                  'wav' => 'audio/wav',
                  'mp3' => 'audio/mpeg',
                  _ => null,
                });
      if (mimeType == null) {
        throw UnsupportedError(
          'Gemini audio input requires a supported audio format.',
        );
      }
      return {
        'inlineData': {
          'mimeType': mimeType,
          'data': dataUri?.group(2) ?? rawData,
        },
      };
    }

    final media = _asMap(
      source[sourceType] ?? source['file'] ?? source['document'],
    );
    final dataValue = media['file_data'] ?? media['data'];
    final data = dataValue is Map ? dataValue['data'] : dataValue;
    final dataUrl = data is String
        ? RegExp(r'^data:([^;,]+);base64,(.*)$', dotAll: true).firstMatch(data)
        : null;
    final explicitMime =
        media['mime_type'] ?? media['mimeType'] ?? media['mimetype'];
    final mimeType = dataUrl?.group(1) ??
        (explicitMime is String
            ? explicitMime
            : _geminiMimeType(media['filename'] ?? media['name']));
    if (data is String && data.isNotEmpty && mimeType != null) {
      return {
        'inlineData': {'mimeType': mimeType, 'data': dataUrl?.group(2) ?? data},
      };
    }

    final rawUri =
        media['url'] ?? media['file_url'] ?? media['file_uri'] ?? media['uri'];
    final uriValue = rawUri is Map ? rawUri['url'] : rawUri;
    if (uriValue is String) {
      final uri = Uri.tryParse(uriValue);
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'gs') &&
          uri.host.isNotEmpty) {
        final videoMime =
            sourceType == 'video_url' ? _geminiMimeType(uri.path) : null;
        final resolvedMime = mimeType ?? videoMime;
        if (resolvedMime == null) {
          throw UnsupportedError(
            'Gemini media references require a MIME type.',
          );
        }
        return {
          'fileData': {'fileUri': uriValue, 'mimeType': resolvedMime},
        };
      }
    }
    throw UnsupportedError(
      'Gemini media requires supported base64 data or an HTTPS/gs file URI.',
    );
  }

  String? _geminiMimeType(Object? rawName) {
    if (rawName is! String) return null;
    final name = rawName.toLowerCase().split('?').first;
    return switch (name.split('.').last) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'mpeg' || 'mpg' => 'video/mpeg',
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
  }
}

final class _GeminiInteractionsBridge extends _MapBridge {
  const _GeminiInteractionsBridge();

  @override
  String get protocolId => 'google.gemini.interactions';

  @override
  StroomMessage toStroom(Map<String, dynamic> interaction) {
    final content = <StroomContentPart>[];
    final outputs = interaction['outputs'] ?? interaction['steps'];
    if (outputs is List) {
      for (final raw in outputs.whereType<Map>()) {
        final stepOutput = raw['output'];
        final output = stepOutput is Map ? stepOutput : raw;
        final type = _string(output['type'], _string(raw['type']));
        if (type == 'model_output') {
          final blocks = output['content'];
          if (blocks is List) {
            for (final block in blocks.whereType<Map>()) {
              if (block['type'] == 'text' && block['text'] is String) {
                content.add(
                  StroomContentPart(
                    type: 'text',
                    data: {'text': block['text'], 'source': _copyMap(block)},
                  ),
                );
              } else {
                content.add(_genericPart(block));
              }
            }
          }
        } else if (type == 'text' || type == 'output_text') {
          content.add(
            StroomContentPart(
              type: 'text',
              data: {
                'text': _string(output['text']),
                'source': _copyMap(output),
              },
            ),
          );
        } else if (type == 'function_call' || type == 'tool_call') {
          content.add(
            StroomContentPart.toolCall(
              id: _string(output['id']),
              name: _string(output['name'], 'unknown'),
              arguments: _copyValueMap(output['arguments']),
              extraFields: {'source': _copyMap(output)},
            ),
          );
        } else if (type == 'function_result' || type == 'tool_result') {
          content.add(
            StroomContentPart.toolResult(
              toolCallId: _string(output['call_id']),
              name: _string(output['name']),
              result: output['result'] ?? output['output'],
              isError: output['is_error'] == true,
              extraFields: {'source': _copyMap(output)},
            ),
          );
        } else {
          content.add(_genericPart(output));
        }
      }
    }
    final extensions = <String, dynamic>{
      'google.gemini.interactions': {
        if (interaction.containsKey('id')) 'interaction_id': interaction['id'],
        if (interaction.containsKey('previous_interaction_id'))
          'previous_interaction_id': interaction['previous_interaction_id'],
        if (interaction.containsKey('status')) 'status': interaction['status'],
      },
    };
    return _message(
      interaction,
      role: 'assistant',
      content: content,
      id: '', // Upstream interaction IDs are never Stroom conversation IDs.
      finishReason: _string(interaction['status'], ''),
      extraExtensions: extensions,
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) => {
        'outputs': [
          for (final part in message.content)
            if (part.type == 'text')
              {'type': 'text', 'text': part.data['text']}
            else if (part.type == 'tool_call')
              {
                'type': 'function_call',
                'id': part.data['id'],
                'name': part.data['name'],
                'arguments': part.data['arguments'],
              }
            else if (part.type == 'tool_result')
              {
                'type': 'function_result',
                'call_id': part.data['toolCallId'],
                'name': part.data['name'],
                'result': part.data['result'],
                'is_error': part.data['isError'],
              }
            else if (_targetSource(message, part).isNotEmpty)
              _targetSource(message, part)
            else
              throw UnsupportedError(
                'Gemini Interactions cannot map ${part.type} content.',
              ),
        ],
      };
}

final class _OllamaChatBridge extends _MapBridge {
  const _OllamaChatBridge();

  @override
  String get protocolId => 'ollama.chat';

  @override
  StroomMessage toStroom(Map<String, dynamic> message) {
    final content = _textParts(message['content']);
    final images = message['images'];
    if (images is List) {
      for (final image in images.whereType<String>()) {
        content.add(StroomContentPart(type: 'image', data: {'base64': image}));
      }
    }
    final calls = message['tool_calls'];
    if (calls is List) {
      for (final raw in calls.whereType<Map>()) {
        final function = raw['function'];
        if (function is Map) {
          content.add(
            StroomContentPart.toolCall(
              id: _string(raw['id']),
              name: _string(function['name'], 'unknown'),
              arguments: _copyValueMap(function['arguments']),
            ),
          );
        } else {
          content.add(_genericPart(raw));
        }
      }
    }
    final thinking = message['thinking'];
    if (thinking is String && thinking.isNotEmpty) {
      content.add(StroomContentPart.reasoning(thinking, complete: true));
    }
    return _message(
      message,
      role: _string(message['role'], 'unknown'),
      content: content,
      id: _string(message['id']),
    );
  }

  @override
  Map<String, dynamic> _encodeNeutral(StroomMessage message) => {
        'role': message.role,
        'content': _ollamaContent(message),
        if (_partsOfType(message, 'reasoning').isNotEmpty)
          'thinking': _partsOfType(
            message,
            'reasoning',
          ).map((part) => part.data['text']).whereType<String>().join(),
        if (_partsOfType(message, 'image').isNotEmpty)
          'images': [
            for (final part in _partsOfType(message, 'image'))
              _ollamaImageData(message, part),
          ],
        if (_partsOfType(message, 'tool_call').isNotEmpty)
          'tool_calls': [
            for (final part in _partsOfType(message, 'tool_call'))
              {
                'function': {
                  'name': part.data['name'],
                  'arguments': part.data['arguments'],
                },
              },
          ],
      };

  String _ollamaContent(StroomMessage message) => message.content
      .map((part) {
        if (part.type == 'text') return _string(part.data['text']);
        if (part.type == 'tool_result') {
          final result = part.data['result'];
          return result is String ? result : jsonEncode(result);
        }
        if (const {'reasoning', 'image', 'tool_call'}.contains(part.type)) {
          return '';
        }
        throw UnsupportedError('Ollama cannot map ${part.type} content.');
      })
      .where((content) => content.isNotEmpty)
      .join();

  String _ollamaImageData(StroomMessage message, StroomContentPart part) {
    final base64 = part.data['base64'];
    if (base64 is String && base64.isNotEmpty) return base64;
    final source = _targetSource(message, part);
    final imageValue =
        part.data['imageUrl'] ?? part.data['reference'] ?? source['image_url'];
    if (imageValue is Map && imageValue['detail'] != null) {
      throw UnsupportedError('Ollama does not support image detail hints.');
    }
    final rawUrl = imageValue is Map ? imageValue['url'] : imageValue;
    if (rawUrl is String) {
      final dataUrl = RegExp(
        r'^data:image/[^;,]+;base64,(.+)$',
        dotAll: true,
      ).firstMatch(rawUrl);
      if (dataUrl != null) return dataUrl.group(1)!;
    }
    throw UnsupportedError(
      'Ollama image inputs must be base64 or an image data URL.',
    );
  }
}
