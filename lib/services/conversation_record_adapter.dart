import '../models/chat_message.dart';
import '../models/stroom_conversation.dart';

/// Adapts the current Stroom conversation representation into the neutral M1
/// storage schema while preserving every legacy field in namespaced extensions.
class ConversationRecordAdapter {
  static const legacyMessageNamespace = 'stroom.legacy';
  static const legacyConversationNamespace = 'stroom.legacyConversation';

  static StroomConversation fromLegacyMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException(
          'Legacy conversation is missing its stable id.');
    }
    final rawMessages = map['messages'];
    if (rawMessages != null && rawMessages is! List) {
      throw const FormatException(
          'Legacy conversation messages must be a list.');
    }
    final messages = <StroomMessage>[];
    final usedMessageIds = <String>{};
    for (final rawMessage in (rawMessages as List? ?? const [])) {
      if (rawMessage is! Map) {
        throw FormatException(
            'Conversation $id contains a non-object message.');
      }
      final legacyMap = Map<String, dynamic>.from(rawMessage);
      final legacy = ChatMessage.fromMap(legacyMap);
      if (legacy.id.isEmpty || !usedMessageIds.add(legacy.id)) {
        throw FormatException(
            'Conversation $id contains a missing or duplicate message id.');
      }
      final neutral =
          StroomMessage.fromLegacy(legacy, sequence: messages.length);
      final oldLegacyExtension = neutral.extensions[legacyMessageNamespace];
      final legacyRecord = legacyMessageRecordForStorage(legacyMap);
      messages.add(
        StroomMessage(
          id: neutral.id,
          role: neutral.role,
          sequence: neutral.sequence,
          createdAt: _date(legacyMap['createdAt']),
          content: neutral.content,
          status: neutral.status,
          finishReason: neutral.finishReason,
          usage: neutral.usage,
          diagnostics: neutral.diagnostics,
          extensions: {
            ...neutral.extensions,
            legacyMessageNamespace: {
              if (oldLegacyExtension is Map)
                ...Map<String, dynamic>.from(oldLegacyExtension),
              'record': legacyRecord,
            },
          },
          extraFields: neutral.extraFields,
        ),
      );
    }

    final known = {
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
      id: id,
      title: map['title'] is String ? map['title'] as String : '',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      messages: messages,
      extensions: {
        if (map['extensions'] is Map)
          ...Map<String, dynamic>.from(map['extensions'] as Map),
        legacyConversationNamespace: {
          ..._withoutInlineDraftAttachmentBytes(
            Map<String, dynamic>.fromEntries(
              map.entries.where((entry) => !known.contains(entry.key)),
            ),
          ),
        },
      },
    );
  }

  static Map<String, dynamic> toLegacyMap(
    StroomConversation conversation,
    List<StroomMessage> messages,
  ) {
    final fields = conversation.extensions[legacyConversationNamespace];
    final result = <String, dynamic>{
      if (fields is Map) ...Map<String, dynamic>.from(fields),
      ...conversation.extraFields,
      'schemaVersion': conversation.schemaVersion,
      'id': conversation.id,
      'title': conversation.title,
      'createdAt': conversation.createdAt.toIso8601String(),
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'messages': messages.map(messageToLegacyMap).toList(),
    };
    final ordinaryExtensions =
        Map<String, dynamic>.from(conversation.extensions)
          ..remove(legacyConversationNamespace);
    if (ordinaryExtensions.isNotEmpty)
      result['extensions'] = ordinaryExtensions;
    return result;
  }

  static Map<String, dynamic> messageToLegacyMap(StroomMessage message) {
    final legacy = message.extensions[legacyMessageNamespace];
    final record = legacy is Map ? legacy['record'] : null;
    if (record is Map) {
      final result = <String, dynamic>{
        ...Map<String, dynamic>.from(record),
        'id': record['id'] is String ? record['id'] : message.id,
        'role': record['role'] is String ? record['role'] : message.role,
        'createdAt': record['createdAt'] is String
            ? record['createdAt']
            : message.createdAt.toIso8601String(),
      };
      final diagnostics = message.diagnostics?.toMap() ?? const {};
      return {
        ...result,
        ...diagnostics,
      };
    }
    return {
      ...message.extraFields,
      'id': message.id,
      'role': message.role,
      'createdAt': message.createdAt.toIso8601String(),
      'blocks': message.content.map((part) => part.toMap()).toList(),
      if (message.status == 'error') 'isError': true,
    };
  }

  /// Stores the complete legacy message shape except diagnostics, which are
  /// carried separately in StroomMessage's redacted, bounded diagnostics field.
  static Map<String, dynamic> legacyMessageRecordForStorage(
    Map<String, dynamic> map,
  ) =>
      Map<String, dynamic>.from(map)
        ..remove('rawRequest')
        ..remove('rawResponse');

  static DateTime _date(Object? value) {
    if (value is String) {
      try {
        return DateTime.parse(value);
      } on FormatException {
        // Preserve migration availability for old malformed optional dates.
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static Map<String, dynamic> _withoutInlineDraftAttachmentBytes(
    Map<String, dynamic> source,
  ) {
    // Only the known draft-attachment collection owns inline media payloads;
    // similarly named vendor extension fields remain opaque.
    final result = Map<String, dynamic>.from(source);
    final attachments = result['draftAttachments'];
    if (attachments is List) {
      result['draftAttachments'] = attachments.map((raw) {
        if (raw is! Map) return raw;
        return Map<String, dynamic>.from(raw)..remove('base64Data');
      }).toList();
    }
    return result;
  }
}
