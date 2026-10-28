import '../models/chat_message.dart';
import '../models/stroom_conversation.dart';

/// Adapts the current Stroom conversation representation into the neutral M1
/// storage schema while preserving every legacy field in namespaced extensions.
class ConversationRecordAdapter {
  static const legacyMessageNamespace = 'stroom.legacy';
  static const legacyConversationNamespace = 'stroom.legacyConversation';
  static const _conversationEnvelopeVersionKey =
      '_stroomAdapterLegacyConversationEnvelopeVersion';
  static const _conversationEnvelopeVersion = 1;
  static const _conversationExtensionPresentKey =
      '_stroomAdapterLegacyConversationExtensionPresent';
  static const _conversationExtensionValueKey =
      '_stroomAdapterLegacyConversationExtensionValue';
  static const _conversationRawExtensionsPresentKey =
      '_stroomAdapterLegacyConversationRawExtensionsPresent';
  static const _conversationRawExtensionsValueKey =
      '_stroomAdapterLegacyConversationRawExtensionsValue';

  static StroomConversation fromLegacyMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException(
        'Legacy conversation is missing its stable id.',
      );
    }
    final rawMessages = map['messages'];
    if (rawMessages != null && rawMessages is! List) {
      throw const FormatException(
        'Legacy conversation messages must be a list.',
      );
    }
    final messages = <StroomMessage>[];
    final usedMessageIds = <String>{};
    for (final rawMessage in (rawMessages as List? ?? const [])) {
      if (rawMessage is! Map) {
        throw FormatException(
          'Conversation $id contains a non-object message.',
        );
      }
      final legacyMap = Map<String, dynamic>.from(rawMessage);
      final legacy = ChatMessage.fromMap(legacyMap);
      if (legacy.id.isEmpty || !usedMessageIds.add(legacy.id)) {
        throw FormatException(
          'Conversation $id contains a missing or duplicate message id.',
        );
      }
      final neutral = StroomMessage.fromLegacy(
        legacy,
        sequence: messages.length,
      );
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
    final legacyExtensions = map['extensions'];
    final hasRawLegacyExtensions =
        map.containsKey('extensions') && legacyExtensions is! Map;
    final hasLegacyConversationExtension = legacyExtensions is Map &&
        legacyExtensions.containsKey(legacyConversationNamespace);
    final legacyConversationExtension = legacyExtensions is Map
        ? legacyExtensions[legacyConversationNamespace]
        : null;
    final ordinaryExtensions = legacyExtensions is Map
        ? (Map<String, dynamic>.from(legacyExtensions)
          ..remove(legacyConversationNamespace))
        : <String, dynamic>{};
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
        ...ordinaryExtensions,
        legacyConversationNamespace: {
          _conversationEnvelopeVersionKey: _conversationEnvelopeVersion,
          _conversationExtensionPresentKey: hasLegacyConversationExtension,
          if (hasLegacyConversationExtension)
            _conversationExtensionValueKey: legacyConversationExtension,
          _conversationRawExtensionsPresentKey: hasRawLegacyExtensions,
          if (hasRawLegacyExtensions)
            _conversationRawExtensionsValueKey: legacyExtensions,
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
    final legacyFields =
        fields is Map ? Map<String, dynamic>.from(fields) : <String, dynamic>{};
    final hasTaggedEnvelope = legacyFields[_conversationEnvelopeVersionKey] ==
            _conversationEnvelopeVersion &&
        legacyFields[_conversationExtensionPresentKey] is bool;
    final hasOriginalExtension = hasTaggedEnvelope
        ? legacyFields[_conversationExtensionPresentKey] == true
        : legacyFields.containsKey('opaqueExtensionValue');
    final originalExtensionValue = hasTaggedEnvelope
        ? legacyFields[_conversationExtensionValueKey]
        : legacyFields['opaqueExtensionValue'];
    final hasRawExtensions = hasTaggedEnvelope &&
        legacyFields[_conversationRawExtensionsPresentKey] == true;
    final rawExtensionsValue = legacyFields[_conversationRawExtensionsValueKey];
    legacyFields.remove(_conversationEnvelopeVersionKey);
    legacyFields.remove(_conversationExtensionPresentKey);
    legacyFields.remove(_conversationExtensionValueKey);
    legacyFields.remove(_conversationRawExtensionsPresentKey);
    legacyFields.remove(_conversationRawExtensionsValueKey);
    if (!hasTaggedEnvelope) legacyFields.remove('opaqueExtensionValue');
    final result = <String, dynamic>{
      ...legacyFields,
      ...conversation.extraFields,
      'schemaVersion': conversation.schemaVersion,
      'id': conversation.id,
      'title': conversation.title,
      'createdAt': conversation.createdAt.toIso8601String(),
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'messages': messages.map(messageToLegacyMap).toList(),
    };
    final ordinaryExtensions = Map<String, dynamic>.from(
      conversation.extensions,
    )..remove(legacyConversationNamespace);
    if (hasOriginalExtension) {
      ordinaryExtensions[legacyConversationNamespace] = originalExtensionValue;
    }
    if (hasRawExtensions && ordinaryExtensions.isEmpty) {
      result['extensions'] = rawExtensionsValue;
    } else if (ordinaryExtensions.isNotEmpty) {
      result['extensions'] = ordinaryExtensions;
    }
    return result;
  }

  static Map<String, dynamic> messageToLegacyMap(StroomMessage message) {
    final legacy = message.extensions[legacyMessageNamespace];
    final ordinaryExtensions = Map<String, dynamic>.from(message.extensions)
      ..remove(legacyMessageNamespace);
    final hasTaggedLegacyExtension = legacy is Map &&
        legacy[StroomMessage.legacyExtensionEnvelopeVersionKey] ==
            StroomMessage.legacyExtensionEnvelopeVersion &&
        legacy[StroomMessage.legacyExtensionPresentKey] == true;
    final hasRawLegacyExtensions = legacy is Map &&
        legacy[StroomMessage.legacyRawExtensionsPresentKey] == true;
    if (hasTaggedLegacyExtension) {
      ordinaryExtensions[legacyMessageNamespace] =
          legacy[StroomMessage.legacyExtensionValueKey];
    } else if (legacy is Map && legacy.containsKey('opaqueExtensionValue')) {
      ordinaryExtensions[legacyMessageNamespace] =
          legacy['opaqueExtensionValue'];
    }
    final rawLegacyExtensions = legacy is Map
        ? legacy[StroomMessage.legacyRawExtensionsValueKey]
        : null;
    final record = legacy is Map ? legacy['record'] : null;
    if (record is Map) {
      final result = <String, dynamic>{
        ...Map<String, dynamic>.from(record),
        ...message.extraFields,
        'id': message.id,
        'role': message.role,
        'createdAt': message.createdAt.toIso8601String(),
        'content': message.content
            .where((part) => part.type == 'text' && part.data['text'] is String)
            .map((part) => part.data['text'] as String)
            .join(),
        'blocks': message.content
            .map(
              (part) => <String, dynamic>{
                ...part.extraFields,
                'type': part.type,
                ...part.data,
              },
            )
            .toList(),
      };
      final attachments = <Map<String, dynamic>>[];
      for (final part in message.content) {
        final attachment = part.data['attachment'];
        if (attachment is Map) {
          attachments.add(Map<String, dynamic>.from(attachment));
        } else if (const {
          'image',
          'audio',
          'video',
          'file',
        }.contains(part.type)) {
          attachments.add(Map<String, dynamic>.from(part.data));
        }
      }
      if (attachments.isNotEmpty || result.containsKey('attachments')) {
        result['attachments'] = attachments;
      }
      if (message.status == null) {
        result.remove('status');
        result.remove('isStreaming');
        result.remove('isError');
      } else {
        result['status'] = message.status;
        result['isStreaming'] = message.status == 'streaming';
        result['isError'] = message.status == 'error';
      }
      if (message.finishReason == null) {
        result.remove('finishReason');
      } else {
        result['finishReason'] = message.finishReason;
      }
      if (message.usage == null) {
        result.remove('usage');
      } else {
        result['usage'] = message.usage;
      }
      if (ordinaryExtensions.isEmpty) {
        if (hasRawLegacyExtensions) {
          result['extensions'] = rawLegacyExtensions;
        } else {
          result.remove('extensions');
        }
      } else {
        result['extensions'] = ordinaryExtensions;
      }
      final diagnostics = message.diagnostics?.toMap() ?? const {};
      return {...result, ...diagnostics};
    }
    return {
      ...message.extraFields,
      'id': message.id,
      'role': message.role,
      'createdAt': message.createdAt.toIso8601String(),
      'blocks': message.content.map((part) => part.toMap()).toList(),
      if (message.status != null) 'status': message.status,
      if (message.finishReason != null) 'finishReason': message.finishReason,
      if (message.usage != null) 'usage': message.usage,
      if (ordinaryExtensions.isNotEmpty)
        'extensions': ordinaryExtensions
      else if (hasRawLegacyExtensions)
        'extensions': rawLegacyExtensions,
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
