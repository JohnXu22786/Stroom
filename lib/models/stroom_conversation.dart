import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'chat_message.dart';
import 'message_block.dart';
import 'tool_call.dart';

/// The current version of Stroom's connector-independent conversation schema.
const int kStroomConversationSchemaVersion = 1;

/// Optional debugging data kept outside the canonical message semantics.
///
/// These records are redacted and bounded before they are attached to a
/// message. Authentication-like keys are removed recursively.
@immutable
class StroomMessageDiagnostics {
  static const int maxSerializedBytes = 64 * 1024;

  final Map<String, dynamic>? rawRequest;
  final Map<String, dynamic>? rawResponse;

  StroomMessageDiagnostics._({this.rawRequest, this.rawResponse});

  factory StroomMessageDiagnostics.fromLegacy(ChatMessage message) =>
      _bounded(message.rawRequest, message.rawResponse);

  factory StroomMessageDiagnostics.fromMap(Map<String, dynamic> map) =>
      _bounded(
        map['rawRequest'] is Map
            ? Map<String, dynamic>.from(map['rawRequest'] as Map)
            : null,
        map['rawResponse'] is Map
            ? Map<String, dynamic>.from(map['rawResponse'] as Map)
            : null,
      );

  Map<String, dynamic> toMap() => {
    if (rawRequest != null) 'rawRequest': rawRequest,
    if (rawResponse != null) 'rawResponse': rawResponse,
  };

  static StroomMessageDiagnostics _bounded(
    Map<String, dynamic>? request,
    Map<String, dynamic>? response,
  ) {
    var safeRequest = _redactJson(request);
    var safeResponse = _redactJson(response);
    if (_serializedSize(safeRequest, safeResponse) > maxSerializedBytes) {
      safeResponse = null;
    }
    if (_serializedSize(safeRequest, safeResponse) > maxSerializedBytes) {
      safeRequest = null;
      safeResponse = null;
    }
    return StroomMessageDiagnostics._(
      rawRequest: safeRequest,
      rawResponse: safeResponse,
    );
  }

  static int _serializedSize(
    Map<String, dynamic>? request,
    Map<String, dynamic>? response,
  ) => utf8
      .encode(
        jsonEncode({
          if (request != null) 'rawRequest': request,
          if (response != null) 'rawResponse': response,
        }),
      )
      .length;

  static Map<String, dynamic>? _redactJson(Map<String, dynamic>? input) {
    if (input == null) return null;
    final sanitized = _sanitizeValue(input);
    return sanitized is Map ? Map<String, dynamic>.from(sanitized) : null;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key == null || _isSensitiveKey(entry.key.toString()))
          continue;
        result[entry.key.toString()] = _sanitizeValue(entry.value);
      }
      return result;
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return null;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'authorization' ||
        normalized == 'token' ||
        normalized.endsWith('token') ||
        normalized.endsWith('apikey') ||
        normalized.endsWith('secret') ||
        normalized.endsWith('password') ||
        normalized.endsWith('credential') ||
        normalized == 'cookie' ||
        normalized == 'setcookie';
  }
}

/// A protocol-neutral conversation record.
///
/// It intentionally contains no provider, account, connector, or routing
/// identifiers. Persisted conversations can be read and exported without an
/// AI Gateway account being present.
@immutable
class StroomConversation {
  final int schemaVersion;
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StroomMessage> messages;
  final Map<String, dynamic> extensions;
  final Map<String, dynamic> extraFields;

  StroomConversation({
    this.schemaVersion = kStroomConversationSchemaVersion,
    required this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StroomMessage> messages = const [],
    Map<String, dynamic> extensions = const {},
    Map<String, dynamic> extraFields = const {},
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       messages = List.unmodifiable(messages),
       extensions = Map.unmodifiable(extensions),
       extraFields = Map.unmodifiable(extraFields);

  Map<String, dynamic> toMap() => {
    ...extraFields,
    'schemaVersion': schemaVersion,
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toMap()).toList(),
    'extensions': extensions,
  };

  String toJson() => jsonEncode(toMap());

  factory StroomConversation.fromJson(String json) =>
      StroomConversation.fromMap(Map<String, dynamic>.from(jsonDecode(json)));

  factory StroomConversation.fromMap(Map<String, dynamic> map) {
    final extensionRaw = map['extensions'];
    const knownFields = {
      'schemaVersion',
      'id',
      'title',
      'createdAt',
      'updatedAt',
      'messages',
      'extensions',
    };
    return StroomConversation(
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : kStroomConversationSchemaVersion,
      id: map['id'] is String ? map['id'] as String : '',
      title: map['title'] is String ? map['title'] as String : '',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      messages: map['messages'] is List
          ? (map['messages'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      StroomMessage.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      extensions: extensionRaw is Map
          ? Map<String, dynamic>.from(extensionRaw)
          : const {},
      extraFields: Map<String, dynamic>.fromEntries(
        map.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
    );
  }

  static DateTime _date(dynamic value) {
    if (value is String) {
      try {
        return DateTime.parse(value);
      } on FormatException {
        // Use an explicit fallback for damaged or pre-versioned records.
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

/// A message in Stroom's neutral semantic schema.
///
/// `role` is open-ended so system, developer, tool, and future participant
/// names do not need to be coerced into the legacy user/assistant pair.
@immutable
class StroomMessage {
  static const legacyExtensionEnvelopeVersionKey =
      '_stroomAdapterLegacyExtensionEnvelopeVersion';
  static const legacyExtensionEnvelopeVersion = 1;
  static const legacyExtensionPresentKey =
      '_stroomAdapterLegacyExtensionPresent';
  static const legacyExtensionValueKey = '_stroomAdapterLegacyExtensionValue';

  final String id;
  final String role;
  final int sequence;
  final DateTime createdAt;
  final List<StroomContentPart> content;
  final String? status;
  final String? finishReason;
  final Map<String, dynamic>? usage;

  /// Self-describing protocol extensions keyed by a reverse-DNS namespace,
  /// such as `openai.responses` or `anthropic.messages`.
  final Map<String, dynamic> extensions;
  final Map<String, dynamic> extraFields;
  final StroomMessageDiagnostics? diagnostics;

  StroomMessage({
    required this.id,
    required this.role,
    required this.sequence,
    required this.createdAt,
    List<StroomContentPart> content = const [],
    this.status,
    this.finishReason,
    Map<String, dynamic>? usage,
    Map<String, dynamic> extensions = const {},
    Map<String, dynamic> extraFields = const {},
    this.diagnostics,
  }) : content = List.unmodifiable(content),
       usage = usage == null ? null : Map.unmodifiable(usage),
       extensions = Map.unmodifiable(extensions),
       extraFields = Map.unmodifiable(extraFields);

  Map<String, dynamic> toMap() => {
    ...extraFields,
    'id': id,
    'role': role,
    'sequence': sequence,
    'createdAt': createdAt.toIso8601String(),
    'content': content.map((part) => part.toMap()).toList(),
    if (status != null) 'status': status,
    if (finishReason != null) 'finishReason': finishReason,
    if (usage != null) 'usage': usage,
    if (extensions.isNotEmpty) 'extensions': extensions,
    if (diagnostics != null) 'diagnostics': diagnostics!.toMap(),
  };

  factory StroomMessage.fromMap(Map<String, dynamic> map) {
    final rawContent = map['content'];
    final rawExtensions = map['extensions'];
    final rawUsage = map['usage'];
    final rawDiagnostics = map['diagnostics'];
    const knownFields = {
      'id',
      'role',
      'sequence',
      'createdAt',
      'content',
      'status',
      'finishReason',
      'usage',
      'extensions',
      'diagnostics',
    };
    return StroomMessage(
      id: map['id'] is String ? map['id'] as String : '',
      role: map['role'] is String ? map['role'] as String : 'unknown',
      sequence: map['sequence'] is num ? (map['sequence'] as num).toInt() : 0,
      createdAt: StroomConversation._date(map['createdAt']),
      content: rawContent is List
          ? rawContent
                .whereType<Map>()
                .map(
                  (part) => StroomContentPart.fromMap(
                    Map<String, dynamic>.from(part),
                  ),
                )
                .toList()
          : const [],
      status: map['status'] is String ? map['status'] as String : null,
      finishReason: map['finishReason'] is String
          ? map['finishReason'] as String
          : null,
      usage: rawUsage is Map ? Map<String, dynamic>.from(rawUsage) : null,
      extensions: rawExtensions is Map
          ? Map<String, dynamic>.from(rawExtensions)
          : const {},
      extraFields: Map<String, dynamic>.fromEntries(
        map.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
      diagnostics: rawDiagnostics is Map
          ? StroomMessageDiagnostics.fromMap(
              Map<String, dynamic>.from(rawDiagnostics),
            )
          : null,
    );
  }

  /// Adapts the legacy message without discarding any legacy semantics.
  factory StroomMessage.fromLegacy(
    ChatMessage message, {
    required int sequence,
  }) {
    final retainedStatus = message.legacyFields['status'];
    final retainedFinishReason = message.legacyFields['finishReason'];
    final retainedUsage = message.legacyFields['usage'];
    final retainedExtensions = message.legacyFields['extensions'];
    final hasRetainedLegacyExtension =
        retainedExtensions is Map &&
        retainedExtensions.containsKey('stroom.legacy');
    final retainedLegacyExtension = retainedExtensions is Map
        ? retainedExtensions['stroom.legacy']
        : null;
    final retainedOrdinaryExtensions = retainedExtensions is Map
        ? (Map<String, dynamic>.from(retainedExtensions)
            ..remove('stroom.legacy'))
        : <String, dynamic>{};
    final retainedLegacyFields = Map<String, dynamic>.from(message.legacyFields)
      ..removeWhere(
        (key, _) =>
            key == 'status' ||
            key == 'finishReason' ||
            key == 'usage' ||
            key == 'extensions',
      );
    final content = <StroomContentPart>[];
    if (message.blocks != null && message.blocks!.isNotEmpty) {
      for (final block in message.blocks!) {
        if (block is ToolCallBlock) {
          content.add(
            StroomContentPart.toolCall(
              id: block.id,
              name: block.name,
              arguments: block.arguments,
              extraFields: {
                ...block.extraFields,
                'legacyStatus': block.status.name,
                if (block.compactedAt != null)
                  'compactedAt': block.compactedAt!.toIso8601String(),
              },
            ),
          );
          if (block.result != null) {
            content.add(
              StroomContentPart.toolResult(
                toolCallId: block.id,
                result: block.result,
                isError: block.status == ToolCallStatus.error,
              ),
            );
          }
          continue;
        }
        final data = block.toMap();
        final type = data['type'];
        content.add(
          StroomContentPart(
            type: type is String ? type : 'unknown',
            data: data,
          ),
        );
      }
    } else {
      final reasoningSections = message.reasoningSections?.isNotEmpty == true
          ? message.reasoningSections!
          : message.reasoningContent == null
          ? const <String>[]
          : [message.reasoningContent!];
      final textSections =
          message.textSections?.any((text) => text.isNotEmpty) == true
          ? message.textSections!
          : message.content.isEmpty
          ? const <String>[]
          : [message.content];
      final toolCalls = message.toolCalls ?? const [];
      final roundStarts = message.toolCallRoundStarts ?? const [];
      final roundCount = roundStarts.isNotEmpty
          ? roundStarts.length
          : toolCalls.isEmpty
          ? 0
          : 1;

      void appendRound(int index) {
        if (index < reasoningSections.length) {
          content.add(
            StroomContentPart.reasoning(
              reasoningSections[index],
              complete: true,
            ),
          );
        }
        if (index < textSections.length && textSections[index].isNotEmpty) {
          content.add(StroomContentPart.text(textSections[index]));
        }
        final start = roundStarts.isEmpty
            ? (index == 0 ? 0 : toolCalls.length)
            : roundStarts[index];
        final end = roundStarts.isNotEmpty && index + 1 < roundStarts.length
            ? roundStarts[index + 1]
            : toolCalls.length;
        for (
          var callIndex = start;
          callIndex < end && callIndex < toolCalls.length;
          callIndex++
        ) {
          final call = toolCalls[callIndex];
          content.add(
            StroomContentPart.toolCall(
              id: call.id,
              name: call.name,
              arguments: call.arguments,
              extraFields: {
                'legacyStatus': call.status.name,
                if (call.compactedAt != null)
                  'compactedAt': call.compactedAt!.toIso8601String(),
              },
            ),
          );
          if (call.result != null) {
            content.add(
              StroomContentPart.toolResult(
                toolCallId: call.id,
                result: call.result,
                isError: call.status == ToolCallStatus.error,
              ),
            );
          }
        }
      }

      for (var index = 0; index < roundCount; index++) {
        appendRound(index);
      }
      final remainingCount = reasoningSections.length > textSections.length
          ? reasoningSections.length
          : textSections.length;
      for (var index = roundCount; index < remainingCount; index++) {
        appendRound(index);
      }
    }
    for (final attachment in message.attachments) {
      content.add(
        StroomContentPart(
          type: attachment.fileType,
          data: {'attachment': attachment.toMap()},
        ),
      );
    }
    return StroomMessage(
      id: message.id,
      role: message.originalRole ?? message.role,
      sequence: sequence,
      createdAt: message.createdAt,
      content: content,
      status: message.isError
          ? 'error'
          : retainedStatus is String
          ? retainedStatus
          : null,
      finishReason: retainedFinishReason is String
          ? retainedFinishReason
          : null,
      usage: retainedUsage is Map
          ? Map<String, dynamic>.from(retainedUsage)
          : null,
      diagnostics: message.rawRequest == null && message.rawResponse == null
          ? null
          : StroomMessageDiagnostics.fromLegacy(message),
      extensions: {
        ...retainedOrdinaryExtensions,
        'stroom.legacy': {
          legacyExtensionEnvelopeVersionKey: legacyExtensionEnvelopeVersion,
          legacyExtensionPresentKey: hasRetainedLegacyExtension,
          if (hasRetainedLegacyExtension)
            legacyExtensionValueKey: retainedLegacyExtension,
          'schemaVersion': message.schemaVersion,
          'content': message.content,
          'isStreaming': message.isStreaming,
          'isError': message.isError,
          'reasoningContent': message.reasoningContent,
          'reasoningSections': message.reasoningSections,
          'textSections': message.textSections,
          'toolCallRoundStarts': message.toolCallRoundStarts,
          'toolCalls': message.toolCalls?.map((call) => call.toMap()).toList(),
          'blocks': message.blocks?.map((block) => block.toMap()).toList(),
          'legacyFields': retainedLegacyFields,
        },
      },
    );
  }
}

/// One ordered text, tool, structured, or media reference in a message.
///
/// The `data` value carries stable media references and modality-specific
/// structure; binary media stays outside the conversation JSON.
@immutable
class StroomContentPart {
  final String type;
  final Map<String, dynamic> data;
  final Map<String, dynamic> extraFields;

  StroomContentPart({
    required this.type,
    required Map<String, dynamic> data,
    Map<String, dynamic> extraFields = const {},
  }) : data = Map.unmodifiable(data),
       extraFields = Map.unmodifiable(extraFields);

  factory StroomContentPart.text(String text) =>
      StroomContentPart(type: 'text', data: {'text': text});

  factory StroomContentPart.reasoning(String text, {bool complete = false}) =>
      StroomContentPart(
        type: 'reasoning',
        data: {'text': text, 'complete': complete},
      );

  factory StroomContentPart.refusal(String text) =>
      StroomContentPart(type: 'refusal', data: {'text': text});

  factory StroomContentPart.structuredOutput({
    required String format,
    required dynamic value,
  }) => StroomContentPart(
    type: 'structured_output',
    data: {'format': format, 'value': value},
  );

  factory StroomContentPart.toolCall({
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    Map<String, dynamic> extraFields = const {},
  }) => StroomContentPart(
    type: 'tool_call',
    data: {'id': id, 'name': name, 'arguments': arguments},
    extraFields: extraFields,
  );

  factory StroomContentPart.toolResult({
    required String toolCallId,
    String? name,
    required dynamic result,
    bool isError = false,
    Map<String, dynamic> extraFields = const {},
  }) => StroomContentPart(
    type: 'tool_result',
    data: {
      'toolCallId': toolCallId,
      if (name != null) 'name': name,
      'result': result,
      'isError': isError,
    },
    extraFields: extraFields,
  );

  factory StroomContentPart.image({
    required String reference,
    String? mimeType,
    String? detail,
  }) => StroomContentPart._media(
    'image',
    reference,
    mimeType: mimeType,
    detail: detail,
  );

  factory StroomContentPart.audio({
    required String reference,
    String? mimeType,
    String? transcript,
  }) => StroomContentPart(
    type: 'audio',
    data: {
      'reference': reference,
      if (mimeType != null) 'mimeType': mimeType,
      if (transcript != null) 'transcript': transcript,
    },
  );

  factory StroomContentPart.video({
    required String reference,
    String? mimeType,
    DateTime? timestamp,
  }) => StroomContentPart(
    type: 'video',
    data: {
      'reference': reference,
      if (mimeType != null) 'mimeType': mimeType,
      if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
    },
  );

  factory StroomContentPart.file({
    required String reference,
    String? fileName,
    String? mimeType,
  }) => StroomContentPart(
    type: 'file',
    data: {
      'reference': reference,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
    },
  );

  factory StroomContentPart.transcription({
    required String text,
    List<Map<String, dynamic>> segments = const [],
  }) => StroomContentPart(
    type: 'transcription',
    data: {'text': text, 'segments': segments},
  );

  factory StroomContentPart.citation({
    required String uri,
    String? title,
    int? startIndex,
    int? endIndex,
  }) => StroomContentPart(
    type: 'citation',
    data: {
      'uri': uri,
      if (title != null) 'title': title,
      if (startIndex != null) 'startIndex': startIndex,
      if (endIndex != null) 'endIndex': endIndex,
    },
  );

  factory StroomContentPart.error(String message) =>
      StroomContentPart(type: 'error', data: {'message': message});

  factory StroomContentPart._media(
    String type,
    String reference, {
    String? mimeType,
    String? detail,
  }) => StroomContentPart(
    type: type,
    data: {
      'reference': reference,
      if (mimeType != null) 'mimeType': mimeType,
      if (detail != null) 'detail': detail,
    },
  );

  Map<String, dynamic> toMap() => {...extraFields, 'type': type, 'data': data};

  factory StroomContentPart.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    const knownFields = {'type', 'data'};
    return StroomContentPart(
      type: map['type'] is String ? map['type'] as String : 'unknown',
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : map,
      extraFields: Map<String, dynamic>.fromEntries(
        map.entries.where((entry) => !knownFields.contains(entry.key)),
      ),
    );
  }
}
