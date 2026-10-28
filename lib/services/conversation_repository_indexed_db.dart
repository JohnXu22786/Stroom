import 'dart:convert';
import 'dart:typed_data';

import '../models/stroom_conversation.dart';
import '../utils/web_file_store.dart';
import 'conversation_repository.dart';

/// IndexedDB implementation built on WebFileStore's existing files object
/// store. Each conversation and message has an independent key; batch writes
/// share one IndexedDB transaction.
class IndexedDbConversationRepository implements ConversationRepository {
  @override
  Object get migrationLockKey => 'indexeddb:conversation_repository';

  static Future<void> _mutationQueue = Future<void>.value();

  static const _root = 'conversation_repository/';
  static const _conversationPrefix = '${_root}conversations/';
  static const _messagePrefix = '${_root}messages/';
  static const _messageIndexPrefix = '${_root}message_ids/';
  static const _orderKey = '${_root}order';
  static const _migrationSourceHashKey = '${_root}migration_source_hash';

  String _conversationKey(String id) => '$_conversationPrefix${_key(id)}';
  String _messagePrefixFor(String id) => '$_messagePrefix${_key(id)}/';
  String _messageIndexPrefixFor(String id) =>
      '$_messageIndexPrefix${_key(id)}/';
  String _orderedMessageKey(String conversationId, StroomMessage message) =>
      '${_messagePrefixFor(conversationId)}'
      '${_sortableSequence(message.sequence)}/${_key(message.id)}';
  String _messageIndexKey(String conversationId, String messageId) =>
      '${_messageIndexPrefixFor(conversationId)}${_key(messageId)}';

  static String _sortableSequence(int sequence) {
    final digits = BigInt.from(sequence).abs().toString().padLeft(20, '0');
    if (sequence >= 0) return '1$digits';
    final inverted = digits
        .split('')
        .map((digit) => (9 - int.parse(digit)).toString())
        .join();
    return '0$inverted';
  }

  static String _key(String value) => Uri.encodeComponent(value);
  static Uint8List _encode(Object value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));
  static Map<String, dynamic> _decode(Uint8List bytes) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  static Map<String, StroomMessage> _latestMessagesById(
    Iterable<StroomMessage> messages,
  ) =>
      {for (final message in messages) message.id: message};

  static Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final result = _mutationQueue.then((_) => mutation());
    _mutationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  @override
  Future<void> initialize() async {
    await WebFileStore.keysWithPrefix(_root);
    final orderBytes = await WebFileStore.read(_orderKey);
    if (orderBytes != null) {
      try {
        _cachedOrder = List<String>.from(
          jsonDecode(utf8.decode(orderBytes)) as List,
        );
      } catch (_) {
        _cachedOrder = [];
      }
    }
  }

  @override
  Future<List<ConversationSummary>> listSummaries({int? limit}) async {
    final keys = await WebFileStore.keysWithPrefix(_conversationPrefix);
    final orderBytes = await WebFileStore.read(_orderKey);
    List<String> currentOrder;
    if (orderBytes == null) {
      currentOrder = [];
    } else {
      try {
        currentOrder = List<String>.from(
          jsonDecode(utf8.decode(orderBytes)) as List,
        );
      } catch (_) {
        currentOrder = [];
      }
    }
    _cachedOrder = currentOrder;
    final summaries = <ConversationSummary>[];
    for (final key in keys) {
      final bytes = await WebFileStore.read(key);
      if (bytes == null) continue;
      final conversation = StroomConversation.fromMap(_decode(bytes));
      final count = (await WebFileStore.keysWithPrefix(
        _messagePrefixFor(conversation.id),
      ))
          .length;
      summaries.add(
        ConversationSummary.fromConversation(
          _withoutMessages(conversation),
          messageCount: count,
        ),
      );
    }
    summaries.sort((a, b) {
      final ai = currentOrder.indexOf(a.id);
      final bi = currentOrder.indexOf(b.id);
      if (ai >= 0 && bi >= 0 && ai != bi) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      final updated = b.updatedAt.compareTo(a.updatedAt);
      return updated != 0 ? updated : a.id.compareTo(b.id);
    });
    return limit == null ? summaries : summaries.take(limit).toList();
  }

  @override
  Future<StroomConversation?> getConversation(String id) async {
    final bytes = await WebFileStore.read(_conversationKey(id));
    return bytes == null
        ? null
        : _withoutMessages(StroomConversation.fromMap(_decode(bytes)));
  }

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 || limit < 0) throw ArgumentError('Invalid message page.');
    final prefix = _messagePrefixFor(conversationId);
    final keys = await WebFileStore.keysWithPrefix(prefix)
      ..sort((a, b) {
        final aOrder = a.substring(prefix.length);
        final bOrder = b.substring(prefix.length);
        final aSeparator = aOrder.indexOf('/');
        final bSeparator = bOrder.indexOf('/');
        final sequence = aOrder
            .substring(0, aSeparator)
            .compareTo(bOrder.substring(0, bSeparator));
        if (sequence != 0) return sequence;
        return Uri.decodeComponent(aOrder.substring(aSeparator + 1))
            .compareTo(Uri.decodeComponent(bOrder.substring(bSeparator + 1)));
      });
    if (offset >= keys.length || limit == 0) return const [];
    final page = keys.skip(offset).take(limit);
    final messages = <StroomMessage>[];
    for (final key in page) {
      final bytes = await WebFileStore.read(key);
      if (bytes != null) {
        messages.add(StroomMessage.fromMap(_decode(bytes)));
      }
    }
    return messages;
  }

  @override
  Future<void> upsertConversation(StroomConversation conversation) =>
      _serializeMutation(() async {
        await WebFileStore.write(
          _conversationKey(conversation.id),
          _encode(_withoutMessages(conversation).toMap()),
        );
      });

  @override
  Future<void> applyConversationChanges(
    StroomConversation conversation, {
    List<StroomMessage> upsertMessages = const [],
    List<String> deleteMessageIds = const [],
  }) =>
      _serializeMutation(() async {
        final uniqueMessages = _latestMessagesById(upsertMessages);
        final writes = <String, Uint8List>{
          _conversationKey(conversation.id): _encode(
            _withoutMessages(conversation).toMap(),
          ),
        };
        final deletes = <String>{};
        final indexKeys = <String>{
          ...deleteMessageIds
              .map((id) => _messageIndexKey(conversation.id, id)),
          ...uniqueMessages.keys.map(
            (id) => _messageIndexKey(conversation.id, id),
          ),
        };
        for (final indexKey in indexKeys) {
          final existing = await WebFileStore.read(indexKey);
          if (existing != null) deletes.add(utf8.decode(existing));
        }
        for (final id in deleteMessageIds) {
          deletes.add(_messageIndexKey(conversation.id, id));
        }
        for (final message in uniqueMessages.values) {
          final rowKey = _orderedMessageKey(conversation.id, message);
          writes[rowKey] = _encode(message.toMap());
          writes[_messageIndexKey(conversation.id, message.id)] =
              Uint8List.fromList(utf8.encode(rowKey));
          deletes.remove(rowKey);
        }
        await WebFileStore.writeBatch(writes, deletes: deletes);
      });

  @override
  Future<void> applySnapshotChanges({
    required List<ConversationRepositoryChange> changes,
    required List<String> conversationOrder,
    required List<String> deleteConversationIds,
  }) =>
      _serializeMutation(() async {
        final writes = <String, Uint8List>{};
        final deletes = <String>{};
        final stagedMessageRowsByIndex = <String, String>{};
        for (final change in changes) {
          final uniqueMessages = _latestMessagesById(change.upsertMessages);
          final conversation = change.conversation;
          writes[_conversationKey(conversation.id)] = _encode(
            _withoutMessages(conversation).toMap(),
          );
          final indexKeys = <String>{
            ...change.deleteMessageIds.map(
              (id) => _messageIndexKey(conversation.id, id),
            ),
            ...uniqueMessages.keys.map(
              (id) => _messageIndexKey(conversation.id, id),
            ),
          };
          for (final indexKey in indexKeys) {
            final staged = stagedMessageRowsByIndex[indexKey];
            final existing = staged == null
                ? await WebFileStore.read(indexKey)
                : Uint8List.fromList(utf8.encode(staged));
            if (existing != null) {
              final existingRowKey = utf8.decode(existing);
              deletes.add(existingRowKey);
              writes.remove(existingRowKey);
            }
          }
          for (final id in change.deleteMessageIds) {
            final indexKey = _messageIndexKey(conversation.id, id);
            deletes.add(indexKey);
            writes.remove(indexKey);
            stagedMessageRowsByIndex.remove(indexKey);
          }
          for (final message in uniqueMessages.values) {
            final rowKey = _orderedMessageKey(conversation.id, message);
            writes[rowKey] = _encode(message.toMap());
            final indexKey = _messageIndexKey(conversation.id, message.id);
            writes[indexKey] = Uint8List.fromList(utf8.encode(rowKey));
            stagedMessageRowsByIndex[indexKey] = rowKey;
            deletes.remove(rowKey);
          }
        }
        for (final id in deleteConversationIds) {
          deletes.add(_conversationKey(id));
          deletes
              .addAll(await WebFileStore.keysWithPrefix(_messagePrefixFor(id)));
          deletes.addAll(
            await WebFileStore.keysWithPrefix(_messageIndexPrefixFor(id)),
          );
        }
        writes[_orderKey] = _encode(conversationOrder);
        await WebFileStore.writeBatch(writes, deletes: deletes);
        _cachedOrder = List<String>.from(conversationOrder);
      });

  @override
  Future<void> importConversation(StroomConversation conversation) =>
      _serializeMutation(() async {
        final oldRows = await WebFileStore.keysWithPrefix(
          _messagePrefixFor(conversation.id),
        );
        final oldIndexes = await WebFileStore.keysWithPrefix(
          _messageIndexPrefixFor(conversation.id),
        );
        final writes = <String, Uint8List>{
          _conversationKey(conversation.id): _encode(
            _withoutMessages(conversation).toMap(),
          ),
        };
        final uniqueMessages = _latestMessagesById(conversation.messages);
        for (final message in uniqueMessages.values) {
          final rowKey = _orderedMessageKey(conversation.id, message);
          writes[rowKey] = _encode(message.toMap());
          writes[_messageIndexKey(conversation.id, message.id)] =
              Uint8List.fromList(utf8.encode(rowKey));
        }
        await WebFileStore.writeBatch(writes,
            deletes: [...oldRows, ...oldIndexes]);
      });

  List<String> _cachedOrder = [];

  @override
  Future<void> setConversationOrder(List<String> conversationIds) =>
      _serializeMutation(() async {
        final bytes = await WebFileStore.read(_orderKey);
        if (bytes != null) {
          try {
            _cachedOrder = List<String>.from(
              jsonDecode(utf8.decode(bytes)) as List,
            );
          } catch (_) {
            _cachedOrder = [];
          }
        }
        final next = List<String>.from(conversationIds);
        if (_sameIds(_cachedOrder, next)) return;
        await WebFileStore.write(_orderKey, _encode(next));
        _cachedOrder = next;
      });

  @override
  Future<void> clearConversations() => _serializeMutation(() async {
        final conversations = await WebFileStore.keysWithPrefix(
          _conversationPrefix,
        );
        final messages = await WebFileStore.keysWithPrefix(_messagePrefix);
        final indexes = await WebFileStore.keysWithPrefix(_messageIndexPrefix);
        await WebFileStore.writeBatch(
          const {},
          deletes: [
            ...conversations,
            ...messages,
            ...indexes,
            _orderKey,
            _migrationSourceHashKey,
          ],
        );
        _cachedOrder = [];
      });

  @override
  Future<void> replaceMessages(
    String conversationId,
    List<StroomMessage> messages,
  ) =>
      _serializeMutation(() async {
        if (await getConversation(conversationId) == null) {
          throw StateError('Unknown conversation: $conversationId');
        }
        final prefix = _messagePrefixFor(conversationId);
        final oldKeys = await WebFileStore.keysWithPrefix(prefix);
        final oldIndexKeys = await WebFileStore.keysWithPrefix(
          _messageIndexPrefixFor(conversationId),
        );
        final writes = <String, Uint8List>{};
        final uniqueMessages = <String, StroomMessage>{
          for (final message in messages) message.id: message,
        };
        for (final message in uniqueMessages.values) {
          final rowKey = _orderedMessageKey(conversationId, message);
          writes[rowKey] = _encode(message.toMap());
          writes[_messageIndexKey(conversationId, message.id)] =
              Uint8List.fromList(
            utf8.encode(rowKey),
          );
        }
        await WebFileStore.writeBatch(
          writes,
          deletes: [...oldKeys, ...oldIndexKeys],
        );
      });

  @override
  Future<void> upsertMessage(
    String conversationId,
    StroomMessage message,
  ) =>
      _serializeMutation(() async {
        if (await getConversation(conversationId) == null) {
          throw StateError('Unknown conversation: $conversationId');
        }
        final indexKey = _messageIndexKey(conversationId, message.id);
        final oldIndex = await WebFileStore.read(indexKey);
        final oldRowKey = oldIndex == null ? null : utf8.decode(oldIndex);
        final rowKey = _orderedMessageKey(conversationId, message);
        await WebFileStore.writeBatch(
          {
            rowKey: _encode(message.toMap()),
            indexKey: Uint8List.fromList(utf8.encode(rowKey)),
          },
          deletes:
              oldRowKey == null || oldRowKey == rowKey ? const [] : [oldRowKey],
        );
      });

  @override
  Future<void> deleteMessage(String conversationId, String messageId) =>
      _serializeMutation(() async {
        final indexKey = _messageIndexKey(conversationId, messageId);
        final index = await WebFileStore.read(indexKey);
        final rowKey = index == null ? null : utf8.decode(index);
        await WebFileStore.writeBatch(
          const {},
          deletes: [if (rowKey != null) rowKey, indexKey],
        );
      });

  @override
  Future<void> deleteConversation(String conversationId) =>
      _serializeMutation(() async {
        final messages = await WebFileStore.keysWithPrefix(
          _messagePrefixFor(conversationId),
        );
        final indexes = await WebFileStore.keysWithPrefix(
          _messageIndexPrefixFor(conversationId),
        );
        await WebFileStore.writeBatch(
          const {},
          deletes: [...messages, ...indexes, _conversationKey(conversationId)],
        );
      });

  @override
  Future<int> countConversations() async =>
      (await WebFileStore.keysWithPrefix(_conversationPrefix)).length;

  @override
  Future<int> countMessages({String? conversationId}) async {
    if (conversationId != null) {
      return (await WebFileStore.keysWithPrefix(
        _messagePrefixFor(conversationId),
      ))
          .length;
    }
    var count = 0;
    final conversations = await WebFileStore.keysWithPrefix(
      _conversationPrefix,
    );
    for (final key in conversations) {
      final bytes = await WebFileStore.read(key);
      if (bytes != null) {
        final id = StroomConversation.fromMap(_decode(bytes)).id;
        count += (await WebFileStore.keysWithPrefix(
          _messagePrefixFor(id),
        ))
            .length;
      }
    }
    return count;
  }

  @override
  Future<String?> migrationSourceHash() async {
    final bytes = await WebFileStore.read(_migrationSourceHashKey);
    return bytes == null ? null : utf8.decode(bytes);
  }

  @override
  Future<void> setMigrationSourceHash(String sourceHash) =>
      _serializeMutation(() async {
        await WebFileStore.write(
          _migrationSourceHashKey,
          Uint8List.fromList(utf8.encode(sourceHash)),
        );
      });

  @override
  Future<Map<String, dynamic>> exportData() async {
    final conversations = <Map<String, dynamic>>[];
    final messages = <Map<String, dynamic>>[];
    final conversationKeys = await WebFileStore.keysWithPrefix(
      _conversationPrefix,
    );
    conversationKeys.sort();
    final orderBytes = await WebFileStore.read(_orderKey);
    final order = orderBytes == null
        ? const <String>[]
        : List<String>.from(jsonDecode(utf8.decode(orderBytes)) as List);
    final sourceHash = await migrationSourceHash();
    final recordsById = <String, StroomConversation>{};
    for (final key in conversationKeys) {
      final bytes = await WebFileStore.read(key);
      if (bytes == null) continue;
      final conversation = StroomConversation.fromMap(_decode(bytes));
      recordsById[conversation.id] = _withoutMessages(conversation);
      final messageKeys =
          await WebFileStore.keysWithPrefix(_messagePrefixFor(conversation.id))
            ..sort();
      for (final messageKey in messageKeys) {
        final messageBytes = await WebFileStore.read(messageKey);
        if (messageBytes != null) {
          messages.add({
            'conversationId': conversation.id,
            'record': _decode(messageBytes),
          });
        }
      }
    }
    final orderedIds = <String>[
      ...order.where(recordsById.containsKey),
      ...recordsById.keys.where((id) => !order.contains(id)),
    ];
    conversations.addAll(orderedIds.map((id) => recordsById[id]!.toMap()));
    return {
      'schemaVersion': 1,
      'messageEnvelopeVersion': 1,
      if (sourceHash != null) 'migrationSourceHash': sourceHash,
      'conversationOrder': orderedIds,
      'conversations': conversations,
      'messages': messages,
    };
  }

  @override
  Future<void> restoreData(Map<String, dynamic> data) =>
      _serializeMutation(() async {
        final rawConversations = data['conversations'];
        final rawMessages = data['messages'];
        if (rawConversations is! List || rawMessages is! List) {
          throw const FormatException(
              'Invalid conversation repository backup.');
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
            throw const FormatException(
                'Invalid or duplicate conversation id.');
          }
          conversations[conversation.id] = _withoutMessages(conversation);
        }
        final writes = <String, Uint8List>{};
        for (final conversation in conversations.values) {
          writes[_conversationKey(conversation.id)] =
              _encode(conversation.toMap());
        }
        final rawOrder = data['conversationOrder'];
        final orderedIds = rawOrder is List
            ? [
                ...rawOrder
                    .whereType<String>()
                    .where(conversations.containsKey),
                ...conversations.keys.where(
                  (id) => !rawOrder.whereType<String>().contains(id),
                ),
              ]
            : conversations.keys.toList();
        writes[_orderKey] = _encode(orderedIds);
        final migrationSourceHash = data['migrationSourceHash'];
        if (migrationSourceHash is String) {
          writes[_migrationSourceHashKey] = Uint8List.fromList(
            utf8.encode(migrationSourceHash),
          );
        }
        final seenMessageIds = <String>{};
        for (final raw in rawMessages) {
          if (raw is! Map)
            throw const FormatException('Invalid message record.');
          final row = Map<String, dynamic>.from(raw);
          final conversationId = row.remove('conversationId');
          if (conversationId is! String ||
              !conversations.containsKey(conversationId)) {
            throw const FormatException(
              'Message references a missing conversation.',
            );
          }
          final record =
              data['messageEnvelopeVersion'] == 1 ? row['record'] : row;
          if (record is! Map) {
            throw const FormatException('Invalid message envelope.');
          }
          final message =
              StroomMessage.fromMap(Map<String, dynamic>.from(record));
          final compositeId = '$conversationId\u0000${message.id}';
          if (message.id.isEmpty || !seenMessageIds.add(compositeId)) {
            throw const FormatException('Invalid or duplicate message id.');
          }
          final rowKey = _orderedMessageKey(conversationId, message);
          writes[rowKey] = _encode(message.toMap());
          writes[_messageIndexKey(conversationId, message.id)] =
              Uint8List.fromList(
            utf8.encode(rowKey),
          );
        }
        final currentConversationKeys = await WebFileStore.keysWithPrefix(
          _conversationPrefix,
        );
        final currentMessageKeys = await WebFileStore.keysWithPrefix(
          _messagePrefix,
        );
        final currentIndexKeys = await WebFileStore.keysWithPrefix(
          _messageIndexPrefix,
        );
        await WebFileStore.writeBatch(
          writes,
          deletes: [
            ...currentConversationKeys,
            ...currentMessageKeys,
            ...currentIndexKeys,
            if (migrationSourceHash is! String) _migrationSourceHashKey,
          ],
        );
        _cachedOrder = orderedIds;
      });

  @override
  Future<List<ConversationIntegrityIssue>> checkIntegrity({
    required Future<Uint8List?> Function(String reference) readMedia,
  }) async {
    final issues = <ConversationIntegrityIssue>[];
    final conversationIds = <String>{};
    final conversationKeys = await WebFileStore.keysWithPrefix(
      _conversationPrefix,
    );
    for (final key in conversationKeys) {
      final conversationBytes = await WebFileStore.read(key);
      if (conversationBytes == null) continue;
      final conversation = StroomConversation.fromMap(
        _decode(conversationBytes),
      );
      conversationIds.add(conversation.id);
      final messages = await getMessages(
        conversation.id,
        limit: await countMessages(conversationId: conversation.id),
      );
      for (final message in messages) {
        for (final reference in conversationMessageMediaReferences(message)) {
          await _validateMediaReference(
            issues,
            conversation.id,
            message.id,
            reference,
            readMedia,
          );
        }
      }
      for (final reference in conversationDraftAttachmentReferences(
        conversation,
      )) {
        await _validateMediaReference(
          issues,
          conversation.id,
          'conversation',
          reference,
          readMedia,
        );
      }
    }
    final allMessageKeys = await WebFileStore.keysWithPrefix(_messagePrefix);
    for (final key in allMessageKeys) {
      final suffix = key.substring(_messagePrefix.length);
      final encodedConversationId = suffix.split('/').first;
      final conversationId = Uri.decodeComponent(encodedConversationId);
      if (!conversationIds.contains(conversationId)) {
        issues.add(_issue(conversationId, '', key, 'missing_conversation'));
      }
    }
    return issues;
  }

  static Future<void> _validateMediaReference(
    List<ConversationIntegrityIssue> issues,
    String conversationId,
    String messageId,
    Map<String, dynamic> reference,
    Future<Uint8List?> Function(String reference) readMedia,
  ) async {
    final path = conversationLocalMediaPath(reference['reference']) ??
        conversationLocalMediaPath(reference['storagePath']);
    if (path == null) {
      final thumbnailPath =
          conversationLocalMediaPath(reference['thumbnailPath']);
      if (!conversationIsExternalMediaUri(reference['reference']) &&
          !conversationIsExternalMediaUri(reference['storagePath']) &&
          thumbnailPath == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: '',
            reason: 'missing_reference',
          ),
        );
      }
    } else {
      final bytes = await readMedia(path);
      if (bytes == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: path,
            reason: 'missing_media',
          ),
        );
      } else {
        final size = reference['size'] ?? reference['fileSize'];
        if (!conversationMediaHashMatches(reference, bytes)) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: path,
              reason: 'hash_mismatch',
            ),
          );
        }
        if (size is num && size.toInt() != bytes.length) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: path,
              reason: 'size_mismatch',
            ),
          );
        }
      }
    }
    final rawThumbnailPath = reference['thumbnailPath'];
    final thumbnailPath = conversationLocalMediaPath(rawThumbnailPath);
    if (thumbnailPath != null && thumbnailPath != path) {
      final thumbnailBytes = await readMedia(thumbnailPath);
      if (thumbnailBytes == null) {
        issues.add(
          ConversationIntegrityIssue(
            conversationId: conversationId,
            messageId: messageId,
            reference: thumbnailPath,
            reason: 'missing_media',
          ),
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
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: thumbnailPath,
              reason: 'hash_mismatch',
            ),
          );
        }
        final thumbnailSize = reference['thumbnailSize'];
        if (thumbnailSize is num &&
            thumbnailSize.toInt() != thumbnailBytes.length) {
          issues.add(
            ConversationIntegrityIssue(
              conversationId: conversationId,
              messageId: messageId,
              reference: thumbnailPath,
              reason: 'size_mismatch',
            ),
          );
        }
      }
    } else if (rawThumbnailPath != null && rawThumbnailPath is! String) {
      issues.add(
        ConversationIntegrityIssue(
          conversationId: conversationId,
          messageId: messageId,
          reference: '',
          reason: 'missing_reference',
        ),
      );
    }
  }

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

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  @override
  Future<void> close() async {}
}
