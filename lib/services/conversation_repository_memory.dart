import 'dart:typed_data';

import '../models/stroom_conversation.dart';
import 'conversation_repository.dart';

/// In-memory implementation for deterministic tests and isolated migrations.
class MemoryConversationRepository implements ConversationRepository {
  final Map<String, StroomConversation> _conversations = {};
  final Map<String, Map<String, StroomMessage>> _messages = {};
  List<String> _order = [];
  String? _migrationSourceHash;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<ConversationSummary>> listSummaries({int? limit}) async {
    final rows = _conversations.values
        .map(
          (conversation) => ConversationSummary.fromConversation(
            conversation,
            messageCount: _messages[conversation.id]?.length ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final ai = _order.indexOf(a.id);
        final bi = _order.indexOf(b.id);
        if (ai >= 0 && bi >= 0 && ai != bi) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        final updated = b.updatedAt.compareTo(a.updatedAt);
        return updated != 0 ? updated : a.id.compareTo(b.id);
      });
    return limit == null ? rows : rows.take(limit).toList();
  }

  @override
  Future<StroomConversation?> getConversation(String id) async =>
      _conversations[id];

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final rows = (_messages[conversationId]?.values.toList() ?? [])
      ..sort((a, b) {
        final sequence = a.sequence.compareTo(b.sequence);
        return sequence != 0 ? sequence : a.id.compareTo(b.id);
      });
    if (offset >= rows.length || limit <= 0) return const [];
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<void> upsertConversation(StroomConversation conversation) async {
    _conversations[conversation.id] = _withoutMessages(conversation);
    _messages.putIfAbsent(conversation.id, () => {});
  }

  @override
  Future<void> applyConversationChanges(
    StroomConversation conversation, {
    List<StroomMessage> upsertMessages = const [],
    List<String> deleteMessageIds = const [],
  }) async {
    final nextMessages = Map<String, StroomMessage>.from(
      _messages[conversation.id] ?? const <String, StroomMessage>{},
    );
    for (final id in deleteMessageIds) {
      nextMessages.remove(id);
    }
    for (final message in upsertMessages) {
      nextMessages[message.id] = message;
    }
    _conversations[conversation.id] = _withoutMessages(conversation);
    _messages[conversation.id] = nextMessages;
  }

  @override
  Future<void> setConversationOrder(List<String> conversationIds) async {
    _order = [
      ...conversationIds.where(_conversations.containsKey),
      ..._conversations.keys.where((id) => !conversationIds.contains(id)),
    ];
  }

  @override
  Future<void> clearConversations() async {
    _conversations.clear();
    _messages.clear();
    _order = [];
    _migrationSourceHash = null;
  }

  @override
  Future<void> importConversation(StroomConversation conversation) async {
    await upsertConversation(conversation);
    await replaceMessages(conversation.id, conversation.messages);
  }

  @override
  Future<void> replaceMessages(
    String conversationId,
    List<StroomMessage> messages,
  ) async {
    if (!_conversations.containsKey(conversationId)) {
      throw StateError('Unknown conversation: $conversationId');
    }
    _messages[conversationId] = {
      for (final message in messages) message.id: message,
    };
  }

  @override
  Future<void> upsertMessage(
    String conversationId,
    StroomMessage message,
  ) async {
    if (!_conversations.containsKey(conversationId)) {
      throw StateError('Unknown conversation: $conversationId');
    }
    _messages.putIfAbsent(conversationId, () => {})[message.id] = message;
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    _messages[conversationId]?.remove(messageId);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _conversations.remove(conversationId);
    _messages.remove(conversationId);
  }

  @override
  Future<int> countConversations() async => _conversations.length;

  @override
  Future<int> countMessages({String? conversationId}) async =>
      conversationId == null
          ? _messages.values.fold<int>(
              0,
              (count, messages) => count + messages.length,
            )
          : _messages[conversationId]?.length ?? 0;

  @override
  Future<String?> migrationSourceHash() async => _migrationSourceHash;

  @override
  Future<void> setMigrationSourceHash(String sourceHash) async {
    _migrationSourceHash = sourceHash;
  }

  @override
  Future<Map<String, dynamic>> exportData() async => {
        'schemaVersion': 1,
        if (_migrationSourceHash != null)
          'migrationSourceHash': _migrationSourceHash,
        'conversationOrder': [
          ..._order.where(_conversations.containsKey),
          ..._conversations.keys.where((id) => !_order.contains(id)),
        ],
        'conversations':
            _conversations.values.map((item) => item.toMap()).toList(),
        'messages': [
          for (final entry in _messages.entries)
            for (final message in entry.value.values)
              {'conversationId': entry.key, ...message.toMap()},
        ],
      };

  @override
  Future<void> restoreData(Map<String, dynamic> data) async {
    final rawConversations = data['conversations'];
    final rawMessages = data['messages'];
    if (rawConversations is! List || rawMessages is! List) {
      throw const FormatException('Invalid conversation repository backup.');
    }
    final conversations = <String, StroomConversation>{};
    for (final raw in rawConversations) {
      if (raw is! Map)
        throw const FormatException('Invalid conversation record.');
      final conversation = StroomConversation.fromMap(
        Map<String, dynamic>.from(raw),
      );
      if (conversation.id.isEmpty ||
          conversations.containsKey(conversation.id)) {
        throw const FormatException('Invalid or duplicate conversation id.');
      }
      conversations[conversation.id] = _withoutMessages(conversation);
    }
    final messages = <String, Map<String, StroomMessage>>{
      for (final id in conversations.keys) id: {},
    };
    for (final raw in rawMessages) {
      if (raw is! Map) throw const FormatException('Invalid message record.');
      final row = Map<String, dynamic>.from(raw);
      final conversationId = row.remove('conversationId');
      if (conversationId is! String ||
          !conversations.containsKey(conversationId)) {
        throw const FormatException(
          'Message references a missing conversation.',
        );
      }
      final message = StroomMessage.fromMap(row);
      if (message.id.isEmpty ||
          messages[conversationId]!.containsKey(message.id)) {
        throw const FormatException('Invalid or duplicate message id.');
      }
      messages[conversationId]![message.id] = message;
    }
    _conversations
      ..clear()
      ..addAll(conversations);
    final rawOrder = data['conversationOrder'];
    _order = rawOrder is List
        ? [
            ...rawOrder.whereType<String>().where(conversations.containsKey),
            ...conversations.keys.where(
              (id) => !rawOrder.whereType<String>().contains(id),
            ),
          ]
        : conversations.keys.toList();
    _messages
      ..clear()
      ..addAll(messages);
    _migrationSourceHash = data['migrationSourceHash'] as String?;
  }

  @override
  Future<List<ConversationIntegrityIssue>> checkIntegrity({
    required Future<Uint8List?> Function(String reference) readMedia,
  }) async {
    final issues = <ConversationIntegrityIssue>[];
    for (final entry in _messages.entries) {
      for (final message in entry.value.values) {
        for (final reference in conversationMessageMediaReferences(message)) {
          await _checkReference(
            issues,
            entry.key,
            message.id,
            reference,
            readMedia,
          );
        }
      }
    }
    for (final conversation in _conversations.values) {
      for (final reference in conversationDraftAttachmentReferences(
        conversation,
      )) {
        await _checkReference(
          issues,
          conversation.id,
          'conversation',
          reference,
          readMedia,
        );
      }
    }
    return issues;
  }

  static StroomConversation _withoutMessages(StroomConversation source) =>
      StroomConversation(
        schemaVersion: source.schemaVersion,
        id: source.id,
        title: source.title,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        extensions: source.extensions,
        extraFields: source.extraFields,
      );

  static ConversationIntegrityIssue _issue(
    String conversationId,
    String messageId,
    String reference,
    String reason,
  ) =>
      ConversationIntegrityIssue(
        conversationId: conversationId,
        messageId: messageId,
        reference: reference,
        reason: reason,
      );

  static Future<void> _checkReference(
    List<ConversationIntegrityIssue> issues,
    String conversationId,
    String messageId,
    Map<String, dynamic> reference,
    Future<Uint8List?> Function(String reference) readMedia,
  ) async {
    final path = conversationLocalMediaPath(reference['reference']) ??
        conversationLocalMediaPath(reference['storagePath']);
    if (path == null) {
      if (!conversationIsExternalMediaUri(reference['reference']) &&
          !conversationIsExternalMediaUri(reference['storagePath'])) {
        issues.add(_issue(conversationId, messageId, '', 'missing_reference'));
      }
    } else {
      final bytes = await readMedia(path);
      if (bytes == null) {
        issues.add(_issue(conversationId, messageId, path, 'missing_media'));
      } else {
        if (!conversationMediaHashMatches(reference, bytes)) {
          issues.add(_issue(conversationId, messageId, path, 'hash_mismatch'));
        }
        final size = reference['size'] ?? reference['fileSize'];
        if (size is num && size.toInt() != bytes.length) {
          issues.add(_issue(conversationId, messageId, path, 'size_mismatch'));
        }
      }
    }
    final rawThumbnailPath = reference['thumbnailPath'];
    final thumbnailPath = conversationLocalMediaPath(rawThumbnailPath);
    if (thumbnailPath != null && thumbnailPath != path) {
      final thumbnailBytes = await readMedia(thumbnailPath);
      if (thumbnailBytes == null) {
        issues.add(
          _issue(conversationId, messageId, thumbnailPath, 'missing_media'),
        );
      } else {
        final thumbnailReference = <String, dynamic>{
          if (reference['thumbnailSha256'] is String)
            'sha256': reference['thumbnailSha256'],
          if (reference['thumbnailHash'] is String)
            'hash': reference['thumbnailHash'],
        };
        if (thumbnailReference.isNotEmpty &&
            !conversationMediaHashMatches(thumbnailReference, thumbnailBytes)) {
          issues.add(
            _issue(conversationId, messageId, thumbnailPath, 'hash_mismatch'),
          );
        }
        final thumbnailSize = reference['thumbnailSize'];
        if (thumbnailSize is num &&
            thumbnailSize.toInt() != thumbnailBytes.length) {
          issues.add(
            _issue(conversationId, messageId, thumbnailPath, 'size_mismatch'),
          );
        }
      }
    } else if (rawThumbnailPath != null && rawThumbnailPath is! String) {
      issues.add(_issue(conversationId, messageId, '', 'missing_reference'));
    }
  }

  @override
  Future<void> close() async {}
}
