import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'stroom_conversation.dart';

/// A namespaced, versioned field that has no shared Stroom semantic.
@immutable
class ProtocolExtension {
  final String protocolId;
  final String version;
  final String type;
  final Map<String, dynamic> data;
  final Map<String, dynamic> extraFields;

  ProtocolExtension({
    required this.protocolId,
    required this.version,
    required this.type,
    required Map<String, dynamic> data,
    Map<String, dynamic> extraFields = const {},
  })  : data = Map.unmodifiable(data),
        extraFields = Map.unmodifiable(extraFields);

  Map<String, dynamic> toJson() => {
        ...extraFields,
        'protocolId': protocolId,
        'version': version,
        'type': type,
        'data': data,
      };

  factory ProtocolExtension.fromJson(Map<String, dynamic> json) {
    const knownFields = {'protocolId', 'version', 'type', 'data'};
    return ProtocolExtension(
      protocolId: json['protocolId'] as String? ?? 'unknown',
      version: json['version'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'unknown',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      extraFields: Map<String, dynamic>.fromEntries(
        json.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
    );
  }
}

/// An ordered typed event emitted by a streaming protocol.
@immutable
class ProtocolStreamEvent {
  final String type;
  final int sequence;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> extraFields;

  ProtocolStreamEvent({
    required this.type,
    required this.sequence,
    required Map<String, dynamic> payload,
    Map<String, dynamic> extraFields = const {},
  })  : payload = Map.unmodifiable(payload),
        extraFields = Map.unmodifiable(extraFields);

  Map<String, dynamic> toJson() => {
        ...extraFields,
        'type': type,
        'sequence': sequence,
        'payload': payload,
      };

  factory ProtocolStreamEvent.fromJson(Map<String, dynamic> json) {
    const knownFields = {'type', 'sequence', 'payload'};
    return ProtocolStreamEvent(
      type: json['type'] as String? ?? 'unknown',
      sequence: json['sequence'] is num ? (json['sequence'] as num).toInt() : 0,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      extraFields: Map<String, dynamic>.fromEntries(
        json.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
    );
  }
}

/// Lossless protocol-boundary data before/after mapping to Stroom semantics.
///
/// The raw payload is retained as an extension at this boundary so newer
/// upstream fields and event variants survive storage and same-protocol
/// serialization even when the current Stroom schema has no named field for
/// them. This is mapping data only; it does not perform HTTP requests.
@immutable
class ProtocolBridgeExchange {
  final Object? bridgeSchemaVersion;
  final Object? contractVersion;
  final Map<String, dynamic> payload;
  final List<ProtocolStreamEvent> events;
  final List<ProtocolExtension> extensions;
  final Map<String, dynamic> extraFields;

  ProtocolBridgeExchange({
    this.bridgeSchemaVersion = 1,
    this.contractVersion = '1',
    required Map<String, dynamic> payload,
    List<ProtocolStreamEvent> events = const [],
    List<ProtocolExtension> extensions = const [],
    Map<String, dynamic> extraFields = const {},
  })  : payload = Map.unmodifiable(payload),
        events = List.unmodifiable(events),
        extensions = List.unmodifiable(extensions),
        extraFields = Map.unmodifiable(extraFields);
}

/// Serialization contract implemented independently by each generic chat API.
abstract interface class ProtocolBridge {
  String get protocolId;
  String get contractVersion;

  /// Preserve fields/events belonging to this protocol while retaining
  /// unknown payload fields in the namespaced extension area.
  Map<String, dynamic> encode(ProtocolBridgeExchange exchange);

  /// Parse a previously encoded protocol envelope and reject another format.
  ProtocolBridgeExchange decode(Map<String, dynamic> envelope);

  /// Parse one protocol message into the neutral semantic model.
  StroomMessage parseMessage(
    Map<String, dynamic> message, {
    required String id,
    required int sequence,
    DateTime? createdAt,
  });

  /// Serialize a neutral message to this protocol, restoring its original
  /// wire message when it was parsed from the same protocol.
  ProtocolMappingResult serializeMessage(StroomMessage message);
}

abstract base class _JsonProtocolBridge implements ProtocolBridge {
  const _JsonProtocolBridge();

  static const Map<String, Set<String>> _knownMessageFields = {
    'openai.chat_completions': {
      'role',
      'content',
      'refusal',
      'tool_calls',
      'status',
      'finish_reason',
      'finishReason',
      'usage',
    },
    'openai.responses': {
      'id',
      'status',
      'output',
      'usage',
      'incomplete_details',
    },
    'anthropic.messages': {
      'id',
      'type',
      'role',
      'content',
      'model',
      'stop_reason',
      'stop_sequence',
      'usage',
    },
    'google.gemini': {
      'candidates',
      'usageMetadata',
      'promptFeedback',
      'modelVersion',
      'responseId',
    },
  };

  StroomMessage makeNeutralMessage({
    required Map<String, dynamic> wireMessage,
    required String id,
    required String role,
    required int sequence,
    DateTime? createdAt,
    required List<StroomContentPart> content,
    String? status,
    String? finishReason,
    Map<String, dynamic>? usage,
  }) {
    final neutral = StroomMessage(
      id: id,
      role: role,
      sequence: sequence,
      createdAt: createdAt ?? DateTime.now(),
      content: content,
      status: status,
      finishReason: finishReason,
      usage: usage,
    );
    return StroomMessage(
      id: neutral.id,
      role: neutral.role,
      sequence: neutral.sequence,
      createdAt: neutral.createdAt,
      content: neutral.content,
      status: neutral.status,
      finishReason: neutral.finishReason,
      usage: neutral.usage,
      extensions: {
        protocolId: ProtocolExtension(
          protocolId: protocolId,
          version: contractVersion,
          type: 'message',
          data: {
            'wireMessage': wireMessage,
            'neutralSnapshot': _neutralSnapshot(neutral),
          },
        ).toJson(),
      },
    );
  }

  String _neutralSnapshot(StroomMessage message) {
    final snapshot = message.toMap()
      ..remove('extensions')
      ..remove('diagnostics');
    return jsonEncode(snapshot);
  }

  bool _matchesNeutralSnapshot(
    StroomMessage message,
    ProtocolExtension extension,
  ) =>
      extension.data['neutralSnapshot'] is String &&
      extension.data['neutralSnapshot'] == _neutralSnapshot(message);

  Map<String, dynamic>? originalMessage(StroomMessage message) {
    final rawExtension = message.extensions[protocolId];
    if (rawExtension is! Map) return null;
    try {
      final extension = ProtocolExtension.fromJson(
        Map<String, dynamic>.from(rawExtension),
      );
      if (extension.protocolId != protocolId || extension.type != 'message') {
        return null;
      }
      if (!_matchesNeutralSnapshot(message, extension)) return null;
      final wireMessage = extension.data['wireMessage'];
      return wireMessage is Map ? Map<String, dynamic>.from(wireMessage) : null;
    } catch (_) {
      return null;
    }
  }

  ProtocolMappingResult mappingResult(
    StroomMessage message,
    Map<String, dynamic> payload, {
    required Set<String> supportedContentTypes,
    Set<String> supportedMetadata = const {},
    Set<String> preservedSameProtocolPartFields = const {},
  }) {
    final sourceExtensions = message.extensions.values
        .whereType<Map>()
        .where(
          (raw) =>
              raw.containsKey('protocolId') &&
              raw.containsKey('version') &&
              raw.containsKey('type') &&
              raw['data'] is Map,
        )
        .map(
          (raw) => ProtocolExtension.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList();
    final targetProtocolExtensions = sourceExtensions
        .where((extension) => extension.protocolId == protocolId)
        .toList();
    final sourceExtension = targetProtocolExtensions.isNotEmpty
        ? targetProtocolExtensions.first
        : sourceExtensions.isEmpty
            ? null
            : sourceExtensions.first;
    final sourceExtensionMatches = sourceExtension != null &&
        sourceExtension.protocolId == protocolId &&
        _matchesNeutralSnapshot(message, sourceExtension);
    final sameProtocolRoundTrip = sourceExtensionMatches;
    final lostTypes = sameProtocolRoundTrip
        ? <String>{}
        : message.content
            .map((part) => part.type)
            .where((type) => !supportedContentTypes.contains(type))
            .toSet();
    final lostMetadata = <String>[];
    if (!sameProtocolRoundTrip) {
      if (message.status != null && !supportedMetadata.contains('status')) {
        lostMetadata.add('status');
      }
      if (message.finishReason != null &&
          !supportedMetadata.contains('finishReason')) {
        lostMetadata.add('finish reason');
      }
      if (message.usage != null && !supportedMetadata.contains('usage')) {
        lostMetadata.add('usage');
      }
    }
    final details = <String>[
      ...lostTypes.map(
        (type) =>
            'Target $protocolId mapping does not preserve $type semantics exactly',
      ),
      ...lostMetadata.map(
        (field) => 'Target $protocolId mapping does not preserve $field',
      ),
    ];
    if (!sameProtocolRoundTrip) {
      for (final entry in message.extensions.entries) {
        if (entry.key == sourceExtension?.protocolId) continue;
        details.add(
          'Stroom extension ${entry.key} is retained in the mapping result '
          'but is not mapped to $protocolId',
        );
      }
      if (protocolId != 'google.gemini' &&
          message.content.any(
            (part) => part.type == 'tool_result' && part.data['name'] != null,
          )) {
        details.add(
          'Tool result function names are retained on the neutral part but '
          'not mapped to $protocolId',
        );
      }
    }
    if (sourceExtension?.protocolId == protocolId && !sourceExtensionMatches) {
      details.add(
        'The neutral message changed after parsing; current fields were '
        'serialized and source-only wire fields remain in the source extension',
      );
    }
    if (!sameProtocolRoundTrip) {
      for (final part in message.content) {
        for (final field in part.extraFields.keys) {
          if (sourceExtension?.protocolId == protocolId &&
              preservedSameProtocolPartFields.contains(field)) {
            continue;
          }
          details.add(
            'Source content field $field is retained on its neutral part but '
            'not mapped to $protocolId',
          );
        }
      }
      if (protocolId == 'openai.chat_completions') {
        final toolResults = message.content
            .where((part) => part.type == 'tool_result')
            .toList();
        if (toolResults.isNotEmpty && message.role != 'tool') {
          details.add(
            'OpenAI Chat Completions cannot map tool results when the message '
            'role is ${message.role}',
          );
        }
        if (message.role == 'tool' && toolResults.length > 1) {
          details.add(
            'There are multiple OpenAI Chat Completions tool results that '
            'cannot be '
            'serialized in one message; additional results are not mapped',
          );
        }
        if (toolResults.any((part) => part.data['isError'] == true)) {
          details.add(
            'OpenAI Chat Completions tool messages do not preserve the tool '
            'result error flag',
          );
        }
        if (toolResults.any(
          (part) =>
              part.data['result'] != null && part.data['result'] is! String,
        )) {
          details.add(
            'OpenAI Chat Completions tool results stringify structured '
            'values as text',
          );
        }
        if (message.role == 'tool' &&
            toolResults.isNotEmpty &&
            message.content.any((part) => part.type != 'tool_result')) {
          details.add(
            'OpenAI Chat Completions tool messages omit text or other '
            'non-result content parts that share the message',
          );
        }
        final sideChannelIndex = message.content.indexWhere(
          (part) =>
              part.type == 'tool_call' ||
              part.type == 'tool_result' ||
              part.type == 'refusal',
        );
        if (sideChannelIndex >= 0 &&
            message.content.any(
              (part) => part.type == 'text' || part.type == 'image',
            )) {
          details.add(
            'OpenAI Chat Completions payload fields cannot preserve the '
            'source content order around text, images, tool calls, results, '
            'or refusals',
          );
        }
      }
      if ((protocolId == 'anthropic.messages' ||
              protocolId == 'google.gemini') &&
          message.role == 'tool') {
        details.add(
          'Tool role is translated to user because $protocolId does not '
          'support a tool message role',
        );
      }
      if ((protocolId == 'anthropic.messages' ||
              protocolId == 'google.gemini') &&
          !{'user', 'assistant', 'tool'}.contains(message.role)) {
        details.add(
          'Source role ${message.role} is translated to user because '
          '$protocolId does not support that message role',
        );
      }
      if (protocolId == 'openai.responses' &&
          !{'assistant', 'user'}.contains(message.role) &&
          message.content.any(
            (part) => part.type == 'text' || part.type == 'refusal',
          )) {
        details.add(
          'Responses output messages only support the assistant role; '
          'source role ${message.role} is translated to assistant',
        );
      }
      if (protocolId == 'openai.responses' &&
          message.content.any(
            (part) =>
                part.type == 'tool_result' && part.data['isError'] == true,
          )) {
        details.add(
          'OpenAI Responses function_call_output does not preserve the '
          'tool-result error flag',
        );
      }
      if (protocolId == 'google.gemini' &&
          message.content.any(
            (part) =>
                part.type == 'tool_result' && part.data['isError'] == true,
          )) {
        details.add(
          'Google Gemini functionResponse does not preserve the tool result '
          'error flag',
        );
      }
    }
    if (!sameProtocolRoundTrip && sourceExtension != null) {
      final rawMessage = sourceExtension.data['wireMessage'];
      final knownFields = _knownMessageFields[sourceExtension.protocolId];
      if (rawMessage is Map && knownFields != null) {
        for (final field in rawMessage.keys.whereType<String>()) {
          if (!knownFields.contains(field)) {
            details.add(
              'Source ${sourceExtension.protocolId} field $field is retained '
              'in its extension but not mapped to $protocolId',
            );
          }
        }
        if (sourceExtension.protocolId == 'anthropic.messages' &&
            rawMessage['stop_sequence'] != null) {
          details.add(
            'Anthropic stop_sequence is retained in its source extension '
            'but not mapped to $protocolId',
          );
        }
        if (sourceExtension.protocolId == 'google.gemini') {
          if (rawMessage['candidates'] is List &&
              (rawMessage['candidates'] as List).length > 1) {
            details.add(
              'Additional Google Gemini candidates are retained in the source '
              'extension but not mapped to $protocolId',
            );
          }
          for (final field in [
            'modelVersion',
            'responseId',
            'promptFeedback',
          ]) {
            if (rawMessage[field] != null) {
              details.add(
                'Google Gemini field $field is retained in the source '
                'extension but not mapped to $protocolId',
              );
            }
          }
          final candidates = rawMessage['candidates'];
          if (candidates is List &&
              candidates.isNotEmpty &&
              candidates.first is Map) {
            final candidate = candidates.first as Map;
            for (final field in candidate.keys.whereType<String>()) {
              if (!{'content', 'finishReason'}.contains(field)) {
                details.add(
                  'Google Gemini candidate field $field is retained in the '
                  'source extension but not mapped to $protocolId',
                );
              }
            }
            final content = candidate['content'];
            if (content is Map) {
              for (final field in content.keys.whereType<String>()) {
                if (!{'role', 'parts'}.contains(field)) {
                  details.add(
                    'Google Gemini content field $field is retained in the '
                    'source extension but not mapped to $protocolId',
                  );
                }
              }
            }
          }
        }
        if (sourceExtension.protocolId == 'openai.responses' &&
            rawMessage['output'] is List) {
          for (final rawItem in rawMessage['output'] as List) {
            if (rawItem is! Map) continue;
            if (rawItem['type'] == 'message') {
              for (final field in rawItem.keys.whereType<String>()) {
                if (!{'type', 'role', 'content'}.contains(field)) {
                  details.add(
                    'OpenAI Responses message item field $field is retained in '
                    'the source extension but not mapped to $protocolId',
                  );
                }
              }
            } else if (rawItem['type'] == 'reasoning') {
              final summary = rawItem['summary'];
              if (summary is List) {
                for (final rawSummary in summary.whereType<Map>()) {
                  for (final field in rawSummary.keys.whereType<String>()) {
                    if (!{'type', 'text'}.contains(field)) {
                      details.add(
                        'OpenAI Responses reasoning summary field $field is '
                        'retained in the source extension but not mapped to '
                        '$protocolId',
                      );
                    }
                  }
                }
              }
              for (final field in rawItem.keys.whereType<String>()) {
                if (!{'type', 'summary'}.contains(field)) {
                  details.add(
                    'OpenAI Responses reasoning item field $field is retained '
                    'in the source extension but not mapped to $protocolId',
                  );
                }
              }
            } else {
              details.add(
                'OpenAI Responses output item ${rawItem['type']} is retained '
                'in the source extension but not mapped to $protocolId',
              );
            }
          }
        }
        if (sourceExtension.protocolId == 'openai.chat_completions' &&
            rawMessage['tool_calls'] is List) {
          for (final rawCall in rawMessage['tool_calls'] as List) {
            if (rawCall is! Map) continue;
            for (final field in rawCall.keys.whereType<String>()) {
              if (!{'id', 'type', 'function'}.contains(field)) {
                details.add(
                  'OpenAI tool call field $field is retained in its source '
                  'extension but not mapped to $protocolId',
                );
              }
            }
            final function = rawCall['function'];
            if (function is Map) {
              for (final field in function.keys.whereType<String>()) {
                if (!{'name', 'arguments'}.contains(field)) {
                  details.add(
                    'OpenAI tool function field $field is retained in its '
                    'source extension but not mapped to $protocolId',
                  );
                }
              }
            }
          }
        }
        if (sourceExtension.protocolId == 'anthropic.messages' &&
            protocolId != 'anthropic.messages' &&
            rawMessage['content'] is List &&
            (rawMessage['content'] as List).whereType<Map>().any(
                  (part) =>
                      part['type'] == 'thinking' && part['signature'] != null,
                )) {
          details.add(
            'Anthropic thinking signature is retained in its source extension '
            'but not mapped to $protocolId',
          );
        }
      }
    }
    return ProtocolMappingResult(
      targetPayload: payload,
      fidelity:
          details.isEmpty ? MappingFidelity.exact : MappingFidelity.partial,
      details: details,
      direction:
          '${sourceExtension?.protocolId ?? 'stroom.conversation'}->$protocolId',
      sourceProtocolId: sourceExtension?.protocolId ?? 'stroom.conversation',
      targetProtocolId: protocolId,
      sourceExtension: sourceExtension,
      sourceExtensionData: message.extensions,
    );
  }

  @override
  String get contractVersion => '1';

  @override
  Map<String, dynamic> encode(ProtocolBridgeExchange exchange) => {
        ...exchange.extraFields,
        'bridgeSchemaVersion': exchange.bridgeSchemaVersion,
        'protocolId': protocolId,
        'contractVersion': exchange.contractVersion,
        'payload': exchange.payload,
        'events': exchange.events.map((event) => event.toJson()).toList(),
        'extensions':
            exchange.extensions.map((extension) => extension.toJson()).toList(),
      };

  @override
  ProtocolBridgeExchange decode(Map<String, dynamic> envelope) {
    if (envelope['protocolId'] != protocolId) {
      throw FormatException(
        'Expected $protocolId bridge envelope; got ${envelope['protocolId']}',
      );
    }
    final payload = envelope['payload'];
    final rawEvents = envelope['events'];
    final rawExtensions = envelope['extensions'];
    const knownFields = {
      'bridgeSchemaVersion',
      'protocolId',
      'contractVersion',
      'payload',
      'events',
      'extensions',
    };
    return ProtocolBridgeExchange(
      bridgeSchemaVersion: envelope.containsKey('bridgeSchemaVersion')
          ? envelope['bridgeSchemaVersion']
          : 1,
      contractVersion: envelope.containsKey('contractVersion')
          ? envelope['contractVersion']
          : contractVersion,
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
      events: rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map(
                (event) => ProtocolStreamEvent.fromJson(
                  Map<String, dynamic>.from(event),
                ),
              )
              .toList()
          : const [],
      extensions: rawExtensions is List
          ? rawExtensions
              .whereType<Map>()
              .map(
                (extension) => ProtocolExtension.fromJson(
                  Map<String, dynamic>.from(extension),
                ),
              )
              .toList()
          : const [],
      extraFields: Map<String, dynamic>.fromEntries(
        envelope.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
    );
  }
}

/// OpenAI Chat Completions contract (roles/content, tool calls, usage and SSE).
final class OpenAiChatCompletionsBridge extends _JsonProtocolBridge {
  @override
  String get protocolId => 'openai.chat_completions';

  @override
  StroomMessage parseMessage(
    Map<String, dynamic> message, {
    required String id,
    required int sequence,
    DateTime? createdAt,
  }) {
    final parts = <StroomContentPart>[];
    final role = message['role'] as String? ?? 'unknown';
    final rawContent = message['content'];
    if (role == 'tool' && message['tool_call_id'] is String) {
      parts.add(
        StroomContentPart.toolResult(
          toolCallId: message['tool_call_id'] as String,
          result: rawContent,
        ),
      );
    } else if (rawContent is String) {
      if (rawContent.isNotEmpty) parts.add(StroomContentPart.text(rawContent));
    } else if (rawContent is List) {
      for (final rawPart in rawContent.whereType<Map>()) {
        final part = Map<String, dynamic>.from(rawPart);
        final imageUrl = part['image_url'];
        if (part['type'] == 'text') {
          parts.add(
            StroomContentPart(
              type: 'text',
              data: {'text': part['text'] ?? ''},
              extraFields: Map<String, dynamic>.fromEntries(
                part.entries.where(
                  (entry) => !{'type', 'text'}.contains(entry.key),
                ),
              ),
            ),
          );
        } else if (part['type'] == 'image_url' && imageUrl is Map) {
          final imageData = Map<String, dynamic>.from(imageUrl);
          final extraImageFields = Map<String, dynamic>.fromEntries(
            imageData.entries.where(
              (entry) => !{'url', 'detail'}.contains(entry.key),
            ),
          );
          final extraPartFields = Map<String, dynamic>.fromEntries(
            part.entries.where(
              (entry) => !{'type', 'image_url'}.contains(entry.key),
            ),
          );
          parts.add(
            StroomContentPart(
              type: 'image',
              data: {
                'reference': imageData['url'],
                if (imageData['detail'] != null) 'detail': imageData['detail'],
              },
              extraFields: {
                if (extraImageFields.isNotEmpty)
                  'openai.chat_completions.image_url': extraImageFields,
                if (extraPartFields.isNotEmpty)
                  'openai.chat_completions.content_part': extraPartFields,
              },
            ),
          );
        } else {
          parts.add(
            StroomContentPart(
              type: part['type'] as String? ?? 'unknown',
              data: part,
            ),
          );
        }
      }
    }
    if (message['refusal'] is String) {
      parts.add(StroomContentPart.refusal(message['refusal'] as String));
    }
    final calls = message['tool_calls'];
    if (calls is List) {
      for (final rawCall in calls.whereType<Map>()) {
        final call = Map<String, dynamic>.from(rawCall);
        final function = call['function'];
        if (function is Map) {
          parts.add(
            StroomContentPart.toolCall(
              id: call['id'] as String? ?? '',
              name: function['name'] as String? ?? '',
              arguments: _arguments(function['arguments']),
              extraFields: _opaqueArgumentFields(function['arguments']),
            ),
          );
        }
      }
    }
    return makeNeutralMessage(
      wireMessage: message,
      id: id,
      role: role,
      sequence: sequence,
      createdAt: createdAt,
      content: parts,
      status: message['status'] as String?,
      finishReason: message['finish_reason'] as String? ??
          message['finishReason'] as String?,
      usage: message['usage'] is Map
          ? Map<String, dynamic>.from(message['usage'] as Map)
          : null,
    );
  }

  @override
  ProtocolMappingResult serializeMessage(StroomMessage message) {
    final original = originalMessage(message);
    final supported = <String>{'text', 'tool_call', 'tool_result', 'refusal'};
    final supportsImages = message.role == 'user' &&
        message.content.any(
          (part) => part.type == 'image' && part.data['reference'] is String,
        );
    if (supportsImages) supported.add('image');
    if (original != null) {
      return mappingResult(
        message,
        original,
        supportedContentTypes: supported,
        preservedSameProtocolPartFields: const {
          'openai.chat_completions.image_url',
          'openai.chat_completions.content_part',
        },
      );
    }
    final orderedContent = <Map<String, dynamic>>[];
    for (final part in message.content) {
      if (part.type == 'text') {
        orderedContent.add({'type': 'text', 'text': part.data['text'] ?? ''});
      } else if (supportsImages &&
          part.type == 'image' &&
          part.data['reference'] is String) {
        final imageUrlExtras =
            part.extraFields['openai.chat_completions.image_url'];
        final contentPartExtras =
            part.extraFields['openai.chat_completions.content_part'];
        orderedContent.add({
          if (contentPartExtras is Map)
            ...Map<String, dynamic>.from(contentPartExtras),
          'type': 'image_url',
          'image_url': {
            if (imageUrlExtras is Map)
              ...Map<String, dynamic>.from(imageUrlExtras),
            'url': part.data['reference'],
            if (part.data['detail'] != null) 'detail': part.data['detail'],
          },
        });
      }
    }
    final textContent = message.content
        .where((part) => part.type == 'text')
        .map((part) => part.data['text'] ?? '')
        .join();
    final calls = message.content.where((part) => part.type == 'tool_call');
    final toolResults = message.content.where(
      (part) => part.type == 'tool_result',
    );
    final refusals = message.content.where((part) => part.type == 'refusal');
    final payload = {
      'role': message.role,
      'content': message.role == 'tool' && toolResults.isNotEmpty
          ? _chatToolResultContent(toolResults.first.data['result'])
          : supportsImages
              ? orderedContent
              : textContent,
      if (message.role == 'tool' && toolResults.isNotEmpty)
        'tool_call_id': toolResults.first.data['toolCallId'],
      if (message.finishReason != null) 'finish_reason': message.finishReason,
      if (message.usage != null) 'usage': message.usage,
      if (refusals.isNotEmpty)
        'refusal': refusals.map((part) => part.data['text'] ?? '').join(),
      if (calls.isNotEmpty)
        'tool_calls': calls
            .map(
              (part) => {
                'id': part.data['id'],
                'type': 'function',
                'function': {
                  'name': part.data['name'],
                  'arguments': jsonEncode(part.data['arguments'] ?? {}),
                },
              },
            )
            .toList(),
    };
    return mappingResult(
      message,
      payload,
      supportedContentTypes: supported,
      supportedMetadata: const {'finishReason', 'usage'},
      preservedSameProtocolPartFields: const {
        'openai.chat_completions.image_url',
        'openai.chat_completions.content_part',
      },
    );
  }
}

dynamic _chatToolResultContent(dynamic result) =>
    result == null || result is String ? result : jsonEncode(result);

/// OpenAI Responses contract (items, function calls, status and typed events).
final class OpenAiResponsesBridge extends _JsonProtocolBridge {
  @override
  String get protocolId => 'openai.responses';

  @override
  StroomMessage parseMessage(
    Map<String, dynamic> message, {
    required String id,
    required int sequence,
    DateTime? createdAt,
  }) {
    final parts = <StroomContentPart>[];
    final output = message['output'];
    if (output is List) {
      for (final itemRaw in output.whereType<Map>()) {
        final item = Map<String, dynamic>.from(itemRaw);
        final type = item['type'];
        if (type == 'message' && item['content'] is List) {
          for (final rawPart in (item['content'] as List).whereType<Map>()) {
            final part = Map<String, dynamic>.from(rawPart);
            final partType = part['type'];
            if (partType == 'output_text') {
              const knownFields = {'type', 'text'};
              parts.add(
                StroomContentPart(
                  type: 'text',
                  data: {'text': part['text'] as String? ?? ''},
                  extraFields: Map<String, dynamic>.fromEntries(
                    part.entries.where(
                      (entry) => !knownFields.contains(entry.key),
                    ),
                  ),
                ),
              );
            } else if (partType == 'input_image' ||
                partType == 'output_image') {
              parts.add(
                StroomContentPart(
                  type: 'image',
                  data: {
                    if (part['image_url'] is String)
                      'reference': part['image_url'],
                    if (part['detail'] != null) 'detail': part['detail'],
                    'wireType': partType,
                  },
                  extraFields: Map<String, dynamic>.fromEntries(
                    part.entries.where(
                      (entry) =>
                          !{'type', 'image_url', 'detail'}.contains(entry.key),
                    ),
                  ),
                ),
              );
            } else if (partType == 'refusal') {
              const knownFields = {'type', 'refusal'};
              parts.add(
                StroomContentPart(
                  type: 'refusal',
                  data: {'text': part['refusal'] as String? ?? ''},
                  extraFields: Map<String, dynamic>.fromEntries(
                    part.entries.where(
                      (entry) => !knownFields.contains(entry.key),
                    ),
                  ),
                ),
              );
            } else {
              parts.add(
                StroomContentPart(
                  type: partType as String? ?? 'unknown',
                  data: part,
                ),
              );
            }
          }
        } else if (type == 'function_call') {
          const knownFields = {'type', 'call_id', 'name', 'arguments'};
          final extraFields = Map<String, dynamic>.fromEntries(
            item.entries.where((entry) => !knownFields.contains(entry.key)),
          )..addAll(_opaqueArgumentFields(item['arguments']));
          parts.add(
            StroomContentPart.toolCall(
              id: item['call_id'] as String? ?? '',
              name: item['name'] as String? ?? '',
              arguments: _arguments(item['arguments']),
              extraFields: extraFields,
            ),
          );
        } else if (type == 'function_call_output') {
          const knownFields = {'type', 'call_id', 'output'};
          parts.add(
            StroomContentPart.toolResult(
              toolCallId: item['call_id'] as String? ?? '',
              result: item['output'],
              extraFields: Map<String, dynamic>.fromEntries(
                item.entries.where((entry) => !knownFields.contains(entry.key)),
              ),
            ),
          );
        } else if (type == 'reasoning') {
          const knownFields = {'type', 'summary'};
          parts.add(
            StroomContentPart(
              type: 'reasoning',
              data: {
                'text': _reasoningSummaryText(item['summary']),
                'summary': item['summary'],
              },
              extraFields: Map<String, dynamic>.fromEntries(
                item.entries.where((entry) => !knownFields.contains(entry.key)),
              ),
            ),
          );
        } else {
          parts.add(StroomContentPart(type: 'unknown', data: item));
        }
      }
    }
    return makeNeutralMessage(
      wireMessage: message,
      id: id,
      role: 'assistant',
      sequence: sequence,
      createdAt: createdAt,
      content: parts,
      status: message['status'] as String?,
      finishReason: message['incomplete_details'] is Map
          ? ((message['incomplete_details'] as Map)['reason'] as String?)
          : null,
      usage: message['usage'] is Map
          ? Map<String, dynamic>.from(message['usage'] as Map)
          : null,
    );
  }

  @override
  ProtocolMappingResult serializeMessage(StroomMessage message) {
    final original = originalMessage(message);
    final supported = <String>{
      'text',
      'tool_call',
      'tool_result',
      'refusal',
      'reasoning',
    };
    Map<String, dynamic>? responseFileItem(StroomContentPart part) {
      final source = part.data['source'];
      final sourceMap = source is Map ? source : const <String, dynamic>{};
      final inputFile = sourceMap['input_file'];
      final file = inputFile is Map ? inputFile : sourceMap;
      final rawReference = part.data['reference'] ??
          file['file_url'] ??
          file['file_data'] ??
          file['url'];
      final reference =
          rawReference is Map ? rawReference['url'] : rawReference;
      if (reference is! String || reference.isEmpty) return null;

      final dataUrl = RegExp(
        r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
        dotAll: true,
      ).firstMatch(reference);
      final fileName = part.data['fileName'] ?? file['filename'];
      final mimeType = part.data['mimeType'] ??
          file['mime_type'] ??
          (fileName is String && fileName.toLowerCase().endsWith('.pdf')
              ? 'application/pdf'
              : null);
      if (dataUrl != null) {
        final encoded = dataUrl.group(2);
        if (dataUrl.group(1) != 'application/pdf' ||
            (mimeType is String && mimeType != 'application/pdf') ||
            encoded == null ||
            encoded.isEmpty ||
            !_isValidBase64(encoded)) {
          return null;
        }
        return {
          'type': 'input_file',
          'file_data': encoded,
          if (fileName is String) 'filename': fileName,
        };
      }
      final uri = Uri.tryParse(reference);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          mimeType != 'application/pdf') {
        return null;
      }
      return {
        'type': 'input_file',
        'file_url': reference,
        if (fileName is String) 'filename': fileName,
      };
    }

    String? imageReference(StroomContentPart part) {
      final reference = part.data['reference'];
      final imageUrl = part.data['imageUrl'];
      final candidate = reference is String
          ? reference
          : imageUrl is String
              ? imageUrl
              : imageUrl is Map && imageUrl['url'] is String
                  ? imageUrl['url'] as String
                  : null;
      if (candidate == null || candidate.isEmpty) return null;
      final declaredMime = part.data['mimeType'];
      const imageMimeTypes = {
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
      };
      if (declaredMime is String && !imageMimeTypes.contains(declaredMime)) {
        return null;
      }
      final dataUrl = RegExp(
        r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
        dotAll: true,
      ).firstMatch(candidate);
      if (dataUrl != null) {
        final data = dataUrl.group(2);
        if (!imageMimeTypes.contains(dataUrl.group(1)) ||
            (declaredMime is String && declaredMime != dataUrl.group(1)) ||
            data == null ||
            data.isEmpty ||
            !_isValidBase64(data)) {
          return null;
        }
        return candidate;
      }
      final uri = Uri.tryParse(candidate);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      return candidate;
    }

    Object? imageDetail(StroomContentPart part) {
      final detail = part.data['detail'];
      if (detail != null) return detail;
      final imageUrl = part.data['imageUrl'];
      return imageUrl is Map ? imageUrl['detail'] : null;
    }

    final imageParts =
        message.content.where((part) => part.type == 'image').toList();
    if (message.role == 'user' &&
        imageParts.isNotEmpty &&
        imageParts.every((part) => imageReference(part) != null)) {
      supported.add('image');
    }
    final fileParts = message.content.where((part) => part.type == 'file');
    if (message.role == 'user' &&
        fileParts.isNotEmpty &&
        fileParts.every((part) => responseFileItem(part) != null)) {
      supported.add('file');
    }
    if (original != null) {
      return mappingResult(message, original, supportedContentTypes: supported);
    }
    final output = <Map<String, dynamic>>[];
    final targetRole = message.role == 'user' ? 'user' : 'assistant';
    final messageContent = <Map<String, dynamic>>[];
    void flushMessageContent() {
      if (messageContent.isEmpty) return;
      output.add({
        'type': 'message',
        'role': targetRole,
        'content': List<Map<String, dynamic>>.from(messageContent),
      });
      messageContent.clear();
    }

    for (final part in message.content) {
      if (part.type == 'text') {
        messageContent.add({
          'type': targetRole == 'user' ? 'input_text' : 'output_text',
          'text': part.data['text'] ?? '',
        });
      } else if (part.type == 'image' &&
          message.role == 'user' &&
          imageReference(part) != null) {
        messageContent.add({
          'type': 'input_image',
          'image_url': imageReference(part),
          if (imageDetail(part) != null) 'detail': imageDetail(part),
        });
      } else if (part.type == 'file' && message.role == 'user') {
        final inputFile = responseFileItem(part);
        if (inputFile != null) messageContent.add(inputFile);
      } else if (part.type == 'tool_call') {
        flushMessageContent();
        output.add({
          'type': 'function_call',
          'call_id': part.data['id'],
          'name': part.data['name'],
          'arguments': jsonEncode(part.data['arguments'] ?? {}),
        });
      } else if (part.type == 'tool_result') {
        flushMessageContent();
        output.add({
          'type': 'function_call_output',
          'call_id': part.data['toolCallId'],
          'output': part.data['result'],
        });
      } else if (part.type == 'refusal') {
        flushMessageContent();
        output.add({
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'refusal', 'refusal': part.data['text']},
          ],
        });
      } else if (part.type == 'reasoning') {
        flushMessageContent();
        output.add({
          'type': 'reasoning',
          'summary': part.data['summary'] is List
              ? part.data['summary']
              : [part.data['text'] ?? ''],
        });
      }
    }
    flushMessageContent();
    final payload = {
      'status': message.status ?? 'completed',
      'output': output,
      if (message.status == 'incomplete' && message.finishReason != null)
        'incomplete_details': {'reason': message.finishReason},
      if (message.usage != null) 'usage': message.usage,
    };
    return mappingResult(
      message,
      payload,
      supportedContentTypes: supported,
      supportedMetadata: {
        'status',
        'usage',
        if (message.status == 'incomplete') 'finishReason',
      },
    );
  }
}

/// Anthropic Messages contract (content blocks, tool use and event stream).
final class AnthropicMessagesBridge extends _JsonProtocolBridge {
  @override
  String get protocolId => 'anthropic.messages';

  @override
  StroomMessage parseMessage(
    Map<String, dynamic> message, {
    required String id,
    required int sequence,
    DateTime? createdAt,
  }) {
    final parts = <StroomContentPart>[];
    final rawContent = message['content'];
    if (rawContent is String) {
      parts.add(StroomContentPart.text(rawContent));
    } else if (rawContent is List) {
      for (final rawPart in rawContent.whereType<Map>()) {
        final part = Map<String, dynamic>.from(rawPart);
        final type = part['type'];
        if (type == 'text') {
          const knownFields = {'type', 'text'};
          parts.add(
            StroomContentPart(
              type: 'text',
              data: {'text': part['text'] as String? ?? ''},
              extraFields: Map<String, dynamic>.fromEntries(
                part.entries.where((entry) => !knownFields.contains(entry.key)),
              ),
            ),
          );
        } else if (type == 'thinking') {
          const knownFields = {'type', 'thinking', 'signature'};
          parts.add(
            StroomContentPart(
              type: 'reasoning',
              data: {
                'text': part['thinking'] ?? '',
                if (part['signature'] != null) 'signature': part['signature'],
              },
              extraFields: Map<String, dynamic>.fromEntries(
                part.entries.where((entry) => !knownFields.contains(entry.key)),
              ),
            ),
          );
        } else if (type == 'tool_use') {
          const knownFields = {'type', 'id', 'name', 'input'};
          final extraFields = Map<String, dynamic>.fromEntries(
            part.entries.where((entry) => !knownFields.contains(entry.key)),
          )..addAll(_opaqueArgumentFields(part['input']));
          parts.add(
            StroomContentPart.toolCall(
              id: part['id'] as String? ?? '',
              name: part['name'] as String? ?? '',
              arguments: _arguments(part['input']),
              extraFields: extraFields,
            ),
          );
        } else if (type == 'tool_result') {
          const knownFields = {'type', 'tool_use_id', 'content', 'is_error'};
          parts.add(
            StroomContentPart.toolResult(
              toolCallId: part['tool_use_id'] as String? ?? '',
              result: part['content'],
              isError: part['is_error'] == true,
              extraFields: Map<String, dynamic>.fromEntries(
                part.entries.where((entry) => !knownFields.contains(entry.key)),
              ),
            ),
          );
        } else if (type == 'document') {
          final source = part['source'];
          parts.add(
            StroomContentPart(
              type: 'file',
              data: {
                'source': part,
                if (part['title'] is String) 'fileName': part['title'],
                if (source is Map && source['media_type'] is String)
                  'mimeType': source['media_type'],
              },
            ),
          );
        } else {
          parts.add(
            StroomContentPart(type: type as String? ?? 'unknown', data: part),
          );
        }
      }
    }
    return makeNeutralMessage(
      wireMessage: message,
      id: id,
      role: message['role'] as String? ?? 'assistant',
      sequence: sequence,
      createdAt: createdAt,
      content: parts,
      finishReason: message['stop_reason'] as String?,
      usage: message['usage'] is Map
          ? Map<String, dynamic>.from(message['usage'] as Map)
          : null,
    );
  }

  @override
  ProtocolMappingResult serializeMessage(StroomMessage message) {
    final original = originalMessage(message);
    final supported = <String>{'text', 'tool_call', 'tool_result', 'reasoning'};
    final imageParts =
        message.content.where((part) => part.type == 'image').toList();
    if (message.role != 'assistant' &&
        imageParts.isNotEmpty &&
        imageParts.every(_anthropicImageSourceForPartIsSupported)) {
      supported.add('image');
    }
    final fileParts =
        message.content.where((part) => part.type == 'file').toList();
    if (message.role != 'assistant' &&
        fileParts.isNotEmpty &&
        fileParts.every(_anthropicFileDocumentForPartIsSupported)) {
      supported.add('file');
    }
    if (original != null) {
      return mappingResult(message, original, supportedContentTypes: supported);
    }
    final content = <Map<String, dynamic>>[];
    for (final part in message.content) {
      if (part.type == 'text') {
        content.add({'type': 'text', 'text': part.data['text']});
      } else if (part.type == 'tool_call') {
        content.add({
          'type': 'tool_use',
          'id': part.data['id'],
          'name': part.data['name'],
          'input': part.data['arguments'],
        });
      } else if (part.type == 'tool_result') {
        content.add({
          'type': 'tool_result',
          'tool_use_id': part.data['toolCallId'],
          'content': part.data['result'],
          if (part.data['isError'] == true) 'is_error': true,
        });
      } else if (part.type == 'reasoning') {
        final signature = part.data['signature'];
        content.add({
          'type': 'thinking',
          'thinking': _reasoningSummaryText(
            part.data['text'] ?? part.data['summary'],
          ),
          ...?(signature == null ? null : {'signature': signature}),
        });
      } else if (part.type == 'image' && message.role != 'assistant') {
        final source = _anthropicImageSource(part);
        if (source != null) {
          content.add({'type': 'image', 'source': source});
        }
      } else if (part.type == 'file' && message.role != 'assistant') {
        final document = _anthropicFileDocument(part);
        if (document != null) content.add(document);
      }
    }
    final payload = {
      'role': message.role == 'assistant' ? 'assistant' : 'user',
      'content': content,
      if (message.finishReason != null) 'stop_reason': message.finishReason,
      if (message.usage != null) 'usage': message.usage,
    };
    return mappingResult(
      message,
      payload,
      supportedContentTypes: supported,
      supportedMetadata: const {'finishReason', 'usage'},
    );
  }

  bool _anthropicImageSourceForPartIsSupported(StroomContentPart part) =>
      _anthropicImageSource(part) != null;

  bool _anthropicFileDocumentForPartIsSupported(StroomContentPart part) =>
      _anthropicFileDocument(part) != null;

  Map<String, dynamic>? _anthropicFileDocument(StroomContentPart part) {
    final source = part.data['source'];
    if (source is Map && source['type'] == 'document') {
      final documentSource = source['source'];
      if (documentSource is Map &&
          documentSource['type'] == 'base64' &&
          documentSource['media_type'] == 'application/pdf' &&
          documentSource['data'] is String &&
          (documentSource['data'] as String).isNotEmpty &&
          _isValidBase64(documentSource['data'] as String)) {
        return Map<String, dynamic>.from(source);
      }
      if (documentSource is Map &&
          documentSource['type'] == 'url' &&
          documentSource['url'] is String) {
        final uri = Uri.tryParse(documentSource['url'] as String);
        if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
          return Map<String, dynamic>.from(source);
        }
      }
    }
    final media = source is Map
        ? Map<String, dynamic>.from(
            source['input_file'] ?? source['file'] ?? source['document'] ?? {},
          )
        : const <String, dynamic>{};
    final rawReference = part.data['reference'] ??
        media['file_data'] ??
        media['file_url'] ??
        media['url'] ??
        media['uri'];
    final reference = rawReference is Map ? rawReference['url'] : rawReference;
    if (reference is! String || reference.isEmpty) return null;
    final dataUri = RegExp(
      r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
      dotAll: true,
    ).firstMatch(reference);
    final fileName = part.data['fileName'] ?? media['filename'];
    final declaredMimeType =
        part.data['mimeType'] ?? media['mime_type'] ?? media['mimeType'];
    final mimeType = dataUri?.group(1) ??
        declaredMimeType ??
        (fileName is String && fileName.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : null);
    if (mimeType != 'application/pdf') return null;
    if (dataUri != null) {
      final data = dataUri.group(2);
      if (data == null || data.isEmpty || !_isValidBase64(data)) return null;
      return {
        'type': 'document',
        'source': {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': data,
        },
        if (fileName is String) 'title': fileName,
      };
    }
    final uri = Uri.tryParse(reference);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return {
      'type': 'document',
      'source': {'type': 'url', 'url': reference},
      if (fileName is String) 'title': fileName,
    };
  }

  Map<String, dynamic>? _anthropicImageSource(StroomContentPart part) {
    final source = part.data['source'];
    if (source is Map) {
      final type = source['type'];
      final mediaType = source['media_type'];
      final data = source['data'];
      if (type == 'base64' &&
          _isAnthropicImageMediaType(mediaType) &&
          data is String) {
        try {
          if (base64.decode(data).isNotEmpty) {
            return Map<String, dynamic>.from(source);
          }
        } on FormatException {
          // Malformed retained bytes cannot be forwarded as an exact image.
        }
      }
      if (type == 'url' && source['url'] is String) {
        final uri = Uri.tryParse(source['url'] as String);
        if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
          return Map<String, dynamic>.from(source);
        }
      }
    }

    final reference = part.data['reference'];
    if (reference is! String) return null;
    final dataUrl = RegExp(
      r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
      dotAll: true,
    ).firstMatch(reference);
    if (dataUrl != null) {
      final mediaType = dataUrl.group(1);
      final data = dataUrl.group(2);
      if (!_isAnthropicImageMediaType(mediaType) ||
          data == null ||
          data.isEmpty ||
          !_isValidBase64(data)) {
        return null;
      }
      return {
        'type': 'base64',
        'media_type': mediaType,
        'data': data,
      };
    }
    final uri = Uri.tryParse(reference);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return {'type': 'url', 'url': reference};
  }
}

/// Google Gemini API contract (contents/parts, function calls and chunks).
final class GeminiBridge extends _JsonProtocolBridge {
  @override
  String get protocolId => 'google.gemini';

  @override
  StroomMessage parseMessage(
    Map<String, dynamic> message, {
    required String id,
    required int sequence,
    DateTime? createdAt,
  }) {
    final candidates = message['candidates'];
    final candidate =
        candidates is List && candidates.isNotEmpty && candidates.first is Map
            ? Map<String, dynamic>.from(candidates.first as Map)
            : message;
    final content = candidate['content'];
    final role =
        content is Map ? (content['role'] as String? ?? 'model') : 'model';
    final parts = <StroomContentPart>[];
    if (content is Map && content['parts'] is List) {
      for (final rawPart in (content['parts'] as List).whereType<Map>()) {
        final part = Map<String, dynamic>.from(rawPart);
        if (part['text'] is String) {
          const knownFields = {'text', 'thought'};
          final extraFields = Map<String, dynamic>.fromEntries(
            part.entries.where((entry) => !knownFields.contains(entry.key)),
          );
          parts.add(
            StroomContentPart(
              type: part['thought'] == true ? 'reasoning' : 'text',
              data: part['thought'] == true
                  ? {'text': part['text'], 'complete': false}
                  : {'text': part['text']},
              extraFields: extraFields,
            ),
          );
        } else if (part['functionCall'] is Map) {
          final call = Map<String, dynamic>.from(part['functionCall'] as Map);
          const callFields = {'id', 'name', 'args'};
          final extraFields = Map<String, dynamic>.fromEntries(
            part.entries.where((entry) => entry.key != 'functionCall'),
          );
          extraFields.addAll(
            Map<String, dynamic>.fromEntries(
              call.entries.where((entry) => !callFields.contains(entry.key)),
            ),
          );
          extraFields.addAll(_opaqueArgumentFields(call['args']));
          parts.add(
            StroomContentPart.toolCall(
              id: call['id'] as String? ?? '',
              name: call['name'] as String? ?? '',
              arguments: _arguments(call['args']),
              extraFields: extraFields,
            ),
          );
        } else if (part['functionResponse'] is Map) {
          final response = Map<String, dynamic>.from(
            part['functionResponse'] as Map,
          );
          final extraFields = Map<String, dynamic>.fromEntries(
            part.entries.where((entry) => entry.key != 'functionResponse'),
          )..addAll(
              Map<String, dynamic>.fromEntries(
                response.entries.where(
                  (entry) => !{'id', 'name', 'response'}.contains(entry.key),
                ),
              ),
            );
          parts.add(
            StroomContentPart.toolResult(
              toolCallId: response['id'] as String? ??
                  response['name'] as String? ??
                  '',
              name: response['name'] as String?,
              result: response['response'],
              extraFields: extraFields,
            ),
          );
        } else if (part['inlineData'] is Map || part['fileData'] is Map) {
          final media = part['inlineData'] is Map
              ? part['inlineData'] as Map
              : part['fileData'] as Map;
          final mimeType = media['mimeType'] as String? ?? '';
          final mediaType = switch (mimeType.split('/').first) {
            'image' => 'image',
            'audio' => 'audio',
            'video' => 'video',
            _ => 'file',
          };
          parts.add(StroomContentPart(type: mediaType, data: part));
        } else {
          parts.add(StroomContentPart(type: 'unknown', data: part));
        }
      }
    }
    return makeNeutralMessage(
      wireMessage: message,
      id: id,
      role: role == 'model' ? 'assistant' : role,
      sequence: sequence,
      createdAt: createdAt,
      content: parts,
      finishReason: candidate['finishReason'] as String?,
      usage: message['usageMetadata'] is Map
          ? Map<String, dynamic>.from(message['usageMetadata'] as Map)
          : null,
    );
  }

  @override
  ProtocolMappingResult serializeMessage(StroomMessage message) {
    final original = originalMessage(message);
    final supported = <String>{'text', 'reasoning', 'tool_call', 'tool_result'};
    final transcriptionParts =
        message.content.where((part) => part.type == 'transcription').toList();
    if (transcriptionParts.isNotEmpty &&
        transcriptionParts.every((part) =>
            part.data['text'] is String &&
            !(part.data['segments'] is List &&
                (part.data['segments'] as List).any(
                  (segment) =>
                      segment is Map &&
                      const {
                        'start',
                        'end',
                        'startSeconds',
                        'endSeconds',
                        'start_seconds',
                        'end_seconds',
                        'timestamp',
                      }.any(segment.containsKey),
                )))) {
      supported.add('transcription');
    }
    final inlineMediaParts =
        message.content.where((part) => part.type == 'inline_media').toList();
    if (inlineMediaParts.isNotEmpty &&
        inlineMediaParts.every((part) =>
            _geminiInlineDataIsSupported(part.data['inlineData']) ||
            _geminiFileDataIsSupported(part.data['fileData']))) {
      supported.add('inline_media');
    }
    for (final type in const {'image', 'audio', 'video', 'file'}) {
      final mediaParts =
          message.content.where((part) => part.type == type).toList();
      if (mediaParts.isNotEmpty &&
          mediaParts.every((part) =>
              !(part.type == 'video' && part.data['timestamp'] != null) &&
              (_geminiInlineDataIsSupported(part.data['inlineData'],
                      expectedType: type) ||
                  _geminiFileDataIsSupported(part.data['fileData'],
                      expectedType: type) ||
                  _geminiMediaReferenceIsSupported(
                    part.data['reference'],
                    expectedType: type,
                    declaredMime: part.data['mimeType'],
                  )))) {
        supported.add(type);
      }
    }
    if (original != null) {
      return mappingResult(message, original, supportedContentTypes: supported);
    }
    final parts = <Map<String, dynamic>>[];
    for (final part in message.content) {
      if (part.type == 'text') {
        parts.add({'text': part.data['text']});
      } else if (part.type == 'reasoning') {
        parts.add({'text': part.data['text'], 'thought': true});
      } else if (part.type == 'transcription' && part.data['text'] is String) {
        parts.add({'text': part.data['text']});
      } else if (part.type == 'tool_call') {
        parts.add({
          'functionCall': {
            'id': part.data['id'],
            'name': part.data['name'],
            'args': part.data['arguments'],
          },
        });
      } else if (part.type == 'tool_result') {
        parts.add({
          'functionResponse': {
            'id': part.data['toolCallId'],
            if (part.data['name'] != null) 'name': part.data['name'],
            'response': part.data['result'],
          },
        });
      } else if ((part.type == 'inline_media' ||
              {'image', 'audio', 'video', 'file'}.contains(part.type)) &&
          (_geminiInlineDataIsSupported(part.data['inlineData'],
                  expectedType: part.type) ||
              _geminiFileDataIsSupported(part.data['fileData'],
                  expectedType: part.type))) {
        final mediaData = Map<String, dynamic>.from(part.data);
        if (part.data['inlineData'] is Map &&
            !_geminiInlineDataIsSupported(part.data['inlineData'],
                expectedType: part.type)) {
          mediaData.remove('inlineData');
        }
        if (part.data['fileData'] is Map &&
            !_geminiFileDataIsSupported(part.data['fileData'],
                expectedType: part.type)) {
          mediaData.remove('fileData');
        }
        parts.add(mediaData);
      } else if ({'image', 'audio', 'video', 'file'}.contains(part.type) &&
          _geminiMediaReferenceIsSupported(
            part.data['reference'],
            expectedType: part.type,
            declaredMime: part.data['mimeType'],
          ) &&
          part.data['mimeType'] is String) {
        final reference = part.data['reference'] as String;
        final inlineData = _geminiInlineDataFromReference(reference);
        final mediaPart = inlineData == null
            ? <String, dynamic>{
                'fileData': {
                  'mimeType': part.data['mimeType'],
                  'fileUri': reference,
                },
              }
            : <String, dynamic>{
                'inlineData': {
                  'mimeType': inlineData.$1,
                  'data': inlineData.$2,
                },
              };
        final videoMetadata = part.data['videoMetadata'];
        if (part.type == 'video' && videoMetadata is Map) {
          mediaPart['videoMetadata'] = Map<String, dynamic>.from(videoMetadata);
        }
        parts.add(mediaPart);
      } else {
        // Unknown and unsupported neutral shapes remain on the source message
        // and are reported as partial by mappingResult; they are not valid
        // Gemini Part objects to forward verbatim.
      }
    }
    final payload = {
      'contents': [
        {
          'role': switch (message.role) {
            'assistant' => 'model',
            _ => 'user',
          },
          'parts': parts,
        },
      ],
    };
    return mappingResult(message, payload, supportedContentTypes: supported);
  }
}

(String, String)? _geminiInlineDataFromReference(String reference) {
  final match = RegExp(
    r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
    dotAll: true,
  ).firstMatch(reference);
  if (match == null) return null;
  final mimeType = match.group(1)!;
  final data = match.group(2)!;
  try {
    if (base64Decode(data).isEmpty) return null;
    return (mimeType, data);
  } on FormatException {
    return null;
  }
}

bool _geminiInlineDataIsSupported(
  Object? value, {
  String? expectedType,
}) {
  if (value is! Map) return false;
  final mimeType = value['mimeType'];
  final data = value['data'];
  if (mimeType is! String || mimeType.isEmpty || data is! String) {
    return false;
  }
  if (const {'image', 'audio', 'video'}.contains(expectedType) &&
      !mimeType.startsWith('$expectedType/')) {
    return false;
  }
  return _isValidBase64(data);
}

bool _geminiFileDataIsSupported(
  Object? value, {
  String? expectedType,
}) {
  if (value is! Map) return false;
  final mimeType = value['mimeType'];
  final reference = value['fileUri'];
  if (mimeType is! String || mimeType.isEmpty || reference is! String) {
    return false;
  }
  if (const {'image', 'audio', 'video'}.contains(expectedType) &&
      !mimeType.startsWith('$expectedType/')) {
    return false;
  }
  if (reference.startsWith('attachments/') ||
      reference.startsWith('temp_edited/')) {
    return true;
  }
  final uri = Uri.tryParse(reference);
  return uri?.scheme == 'https' && uri!.host.isNotEmpty ||
      uri?.scheme == 'gs' && uri!.host.isNotEmpty;
}

bool _geminiMediaReferenceIsSupported(
  Object? value, {
  String? expectedType,
  Object? declaredMime,
}) {
  if (value is! String || value.isEmpty) return false;
  if (value.startsWith('data:')) {
    final inlineData = _geminiInlineDataFromReference(value);
    return inlineData != null &&
        _geminiMediaMimeMatches(inlineData.$1, expectedType) &&
        (declaredMime is! String ||
            _geminiMediaMimeMatches(declaredMime, expectedType));
  }
  if (declaredMime is! String ||
      !_geminiMediaMimeMatches(declaredMime, expectedType)) {
    return false;
  }
  if (value.startsWith('attachments/') || value.startsWith('temp_edited/')) {
    return true;
  }
  final uri = Uri.tryParse(value);
  return uri?.scheme == 'https' && uri!.host.isNotEmpty ||
      uri?.scheme == 'gs' && uri!.host.isNotEmpty;
}

bool _geminiMediaMimeMatches(String mimeType, String? expectedType) =>
    !const {'image', 'audio', 'video'}.contains(expectedType) ||
    mimeType.startsWith('$expectedType/');

bool _isValidBase64(String value) {
  try {
    return base64Decode(value).isNotEmpty;
  } on FormatException {
    return false;
  }
}

bool _isAnthropicImageMediaType(Object? value) => const {
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp'
    }.contains(value);

Map<String, dynamic> _arguments(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = value.isEmpty ? null : value;
      if (decoded != null) {
        final parsed = jsonDecode(decoded);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      // Malformed function arguments are retained as an opaque extension by
      // the protocol's original message field.
    }
  }
  return const {};
}

Map<String, dynamic> _opaqueArgumentFields(dynamic value) {
  if (value == null || value is Map) return const {};
  if (value is String) {
    try {
      if (jsonDecode(value) is Map) return const {};
    } catch (_) {
      // Keep malformed argument strings opaque rather than implying they are {}.
    }
  }
  return {'opaque_arguments': value};
}

String _reasoningSummaryText(dynamic value) {
  if (value is String) return value;
  if (value is List) {
    return value
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
  }
  return '';
}

enum MappingFidelity { exact, partial, unsupported }

/// Result of mapping between a source and target protocol.
@immutable
class ProtocolMappingResult {
  final Map<String, dynamic>? targetPayload;
  final MappingFidelity fidelity;
  final List<String> details;
  final ProtocolExtension? sourceExtension;
  final Map<String, dynamic> sourceExtensionData;
  final String? direction;
  final String? sourceProtocolId;
  final String? targetProtocolId;

  ProtocolMappingResult({
    required this.fidelity,
    this.targetPayload,
    List<String> details = const [],
    this.sourceExtension,
    Map<String, dynamic> sourceExtensionData = const {},
    this.direction,
    this.sourceProtocolId,
    this.targetProtocolId,
  })  : details = List.unmodifiable(details),
        sourceExtensionData = Map.unmodifiable(sourceExtensionData);

  Map<String, dynamic> toJson() => {
        'fidelity': fidelity.name,
        'details': details,
        if (targetPayload != null) 'targetPayload': targetPayload,
        if (direction != null) 'direction': direction,
        if (sourceProtocolId != null) 'sourceProtocolId': sourceProtocolId,
        if (targetProtocolId != null) 'targetProtocolId': targetProtocolId,
        if (sourceExtension != null)
          'sourceExtension': sourceExtension!.toJson(),
        if (sourceExtensionData.isNotEmpty)
          'sourceExtensionData': sourceExtensionData,
      };

  factory ProtocolMappingResult.fromJson(Map<String, dynamic> json) =>
      ProtocolMappingResult(
        targetPayload: json['targetPayload'] is Map
            ? Map<String, dynamic>.from(json['targetPayload'] as Map)
            : null,
        fidelity: MappingFidelity.values.firstWhere(
          (value) => value.name == json['fidelity'],
          orElse: () => MappingFidelity.partial,
        ),
        details: json['details'] is List
            ? (json['details'] as List).whereType<String>().toList()
            : const [],
        direction:
            json['direction'] is String ? json['direction'] as String : null,
        sourceProtocolId: json['sourceProtocolId'] is String
            ? json['sourceProtocolId'] as String
            : null,
        targetProtocolId: json['targetProtocolId'] is String
            ? json['targetProtocolId'] as String
            : null,
        sourceExtension: json['sourceExtension'] is Map
            ? ProtocolExtension.fromJson(
                Map<String, dynamic>.from(json['sourceExtension'] as Map),
              )
            : null,
        sourceExtensionData: json['sourceExtensionData'] is Map
            ? Map<String, dynamic>.from(json['sourceExtensionData'] as Map)
            : const {},
      );
}
