part of 'conversation_provider.dart';

// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

///
/// **Bounded retention**: keeps at most [_maxCorruptBackups] backups. When
/// the cap is exceeded, the oldest backup is deleted. This prevents
/// SharedPreferences from growing without bound on devices that
/// repeatedly hit decode failures.
const int _maxCorruptBackups = 3;
const String _streamJournalFileName = 'conversation_stream_checkpoints.jsonl';
const String _streamJournalWebPrefix = 'conversation_stream_checkpoints/';
const String _pendingRestoredConversationKey =
    'conversation_stream_pending_restores';
const String _pendingRestoredMessageKey =
    'conversation_stream_pending_message_restores';
const String _webStreamJournalTimestampKey =
    'conversation_stream_checkpoint_last_timestamp';
const String _nativeStreamJournalPresentKey =
    'conversation_stream_checkpoints_present';
int _lastWebJournalTimestamp = 0;

/// Latest snapshot and completion shared by periodic stream checkpoints that
/// can safely supersede one another before the queue reaches them.
class _CoalescedStreamPersist {
  Map<String, Map<String, dynamic>> checkpoints;
  final Completer<void> completion = Completer<void>();
  bool accepting = true;

  _CoalescedStreamPersist(this.checkpoints);
}

class _ReplayMessageSections {
  final String conversationId;
  final String messageId;
  final _ReplaySectionDeltas text;
  final _ReplaySectionDeltas reasoning;
  bool shouldFinalize = false;

  _ReplayMessageSections({
    required this.conversationId,
    required this.messageId,
    required List<String> textSections,
    required List<String> reasoningSections,
  })  : text = _ReplaySectionDeltas(textSections),
        reasoning = _ReplaySectionDeltas(reasoningSections);
}

class _ReplaySectionDeltas {
  final List<String> sections;
  final List<List<String>> _chunksBySection;
  final List<int> _lengthsBySection;

  _ReplaySectionDeltas(List<String> initialSections)
      : sections = initialSections,
        _chunksBySection =
            initialSections.map((section) => <String>[section]).toList(),
        _lengthsBySection =
            initialSections.map((section) => section.length).toList();

  bool apply(dynamic rawDeltas) {
    if (rawDeltas is! List) return false;
    var changed = false;
    for (final raw in rawDeltas) {
      if (raw is! Map) continue;
      final section = raw['section'];
      final offset = raw['offset'];
      final text = raw['text'];
      if (section is! int || section < 0 || offset is! int || text is! String) {
        continue;
      }
      while (sections.length <= section) {
        sections.add('');
        _chunksBySection.add(<String>[]);
        _lengthsBySection.add(0);
      }
      final chunks = _chunksBySection[section];
      final currentLength = _lengthsBySection[section];
      if (offset == currentLength) {
        chunks.add(text);
        _lengthsBySection[section] = currentLength + text.length;
        changed = true;
      } else if (offset < currentLength) {
        // A later coalesced checkpoint can overlap a delta already appended
        // by an in-flight write. Match the saved prefix, then append only its
        // not-yet-replayed suffix.
        var overlapLength = currentLength - offset;
        if (overlapLength > text.length) overlapLength = text.length;
        if (_sectionChunksMatchAt(
          chunks,
          offset,
          text.substring(0, overlapLength),
          currentLength,
        )) {
          if (overlapLength < text.length) {
            final suffix = text.substring(overlapLength);
            chunks.add(suffix);
            _lengthsBySection[section] = currentLength + suffix.length;
            changed = true;
          }
          continue;
        }
      }
    }
    return changed;
  }

  List<String> materialize() => [
        for (final chunks in _chunksBySection) chunks.join(),
      ];
}

bool _sectionChunksMatchAt(
  List<String> chunks,
  int offset,
  String text,
  int totalLength,
) {
  if (offset + text.length > totalLength) return false;
  var chunkStart = 0;
  var textOffset = 0;
  for (final chunk in chunks) {
    final chunkEnd = chunkStart + chunk.length;
    if (chunkEnd > offset && chunkStart < offset + text.length) {
      final startInChunk = offset > chunkStart ? offset - chunkStart : 0;
      final count = (chunkEnd < offset + text.length
              ? chunkEnd
              : offset + text.length) -
          (chunkStart + startInChunk);
      if (chunk.substring(startInChunk, startInChunk + count) !=
          text.substring(textOffset, textOffset + count)) {
        return false;
      }
      textOffset += count;
    }
    chunkStart = chunkEnd;
    if (textOffset == text.length) return true;
  }
  return textOffset == text.length;
}

extension _ConversationsNotifierPersistenceExt on ConversationsNotifier {
  String _streamCheckpointKey(String conversationId, String messageId) =>
      jsonEncode([conversationId, messageId]);

  bool _hasStreamCheckpoint(String conversationId, String messageId) {
    final key = _streamCheckpointKey(conversationId, messageId);
    return _streamCheckpointKeys.contains(key) ||
        (_coalescedStreamPersist?.checkpoints.containsKey(key) ?? false);
  }

  /// Resolves message removals recorded while the startup journal index was
  /// still being read. Only removals that actually have a checkpoint need a
  /// durable tombstone; ordinary history edits must not trigger journal I/O.
  bool _resolveUnindexedMessageDeletions() {
    if (!_streamCheckpointKeyIndexIsCurrent ||
        _pendingUnindexedMessageDeletionIds.isEmpty) {
      return false;
    }
    final hadPendingDeletions = _pendingUnindexedMessageDeletionIds.isNotEmpty;
    for (final entry in _pendingUnindexedMessageDeletionIds.entries) {
      final checkpointedIds = entry.value
          .where((id) => _hasStreamCheckpoint(entry.key, id))
          .toList();
      if (checkpointedIds.isEmpty) continue;
      _pendingMessageDeletionIds
          .putIfAbsent(entry.key, () => <String>{})
          .addAll(checkpointedIds);
    }
    _pendingUnindexedMessageDeletionIds.clear();
    return hadPendingDeletions;
  }

  void _addPendingMessageDeletions(
      String conversationId, Iterable<String> ids) {
    _pendingMessageDeletionIds
        .putIfAbsent(conversationId, () => <String>{})
        .addAll(ids);
  }

  void _removePendingMessageDeletions(
    String conversationId,
    Iterable<String> ids,
  ) {
    final pending = _pendingMessageDeletionIds[conversationId];
    if (pending == null) return;
    pending.removeAll(ids);
    if (pending.isEmpty) _pendingMessageDeletionIds.remove(conversationId);
  }

  Future<void> _persistPendingMessageDeletions() async {
    for (final entry in _pendingMessageDeletionIds.entries.toList()) {
      final ids = Set<String>.from(entry.value);
      if (ids.isEmpty) continue;
      final currentMessages = state
          .where((conversation) => conversation.id == entry.key)
          .expand((conversation) => conversation.messages)
          .map((message) => message.id)
          .toSet();
      final restoredIds = ids.intersection(currentMessages);
      if (restoredIds.isNotEmpty) {
        await _appendMessageRestorations(
          entry.key,
          restoredIds,
          insidePersistenceQueue: true,
        );
      }
      ids.removeAll(restoredIds);
      if (ids.isEmpty) continue;
      await _appendStreamCheckpoint({
        'kind': 'messageDeleted',
        'conversationId': entry.key,
        'messageIds': ids.toList(),
      });
      _removePendingMessageDeletions(entry.key, ids);
    }
  }

  Future<bool> _persistPendingRestoredConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingRestoredConversations.isEmpty) {
        return prefs.remove(_pendingRestoredConversationKey);
      }
      return prefs.setString(
        _pendingRestoredConversationKey,
        jsonEncode(_pendingRestoredConversations),
      );
    } catch (e) {
      debugPrint('Failed to persist restored conversation markers: $e');
      return false;
    }
  }

  Future<bool> _clearPendingRestoredConversationMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(_pendingRestoredConversationKey);
      if (removed) _pendingRestoredConversations.clear();
      return removed;
    } catch (e) {
      debugPrint('Failed to clear restored conversation markers: $e');
      return false;
    }
  }

  Future<bool> _persistPendingRestoredMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingMessageRestorationIds.isEmpty) {
        return prefs.remove(_pendingRestoredMessageKey);
      }
      return prefs.setString(
        _pendingRestoredMessageKey,
        jsonEncode({
          for (final entry in _pendingMessageRestorationIds.entries)
            entry.key: entry.value.toList(),
        }),
      );
    } catch (e) {
      debugPrint('Failed to persist restored message markers: $e');
      return false;
    }
  }

  Future<bool> _clearPendingRestoredMessageMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pendingRestoredMessageKey) == null) {
        _pendingMessageRestorationIds.clear();
        return true;
      }
      final removed = await prefs.remove(_pendingRestoredMessageKey);
      if (removed) _pendingMessageRestorationIds.clear();
      return removed;
    } catch (e) {
      debugPrint('Failed to clear restored message markers: $e');
      return false;
    }
  }

  void _addPendingMessageRestorations(
    String conversationId,
    Iterable<String> ids,
  ) {
    _pendingMessageRestorationIds
        .putIfAbsent(conversationId, () => <String>{})
        .addAll(ids);
  }

  Set<String> _removePendingMessageRestorations(
    String conversationId,
    Iterable<String> ids,
  ) {
    final pending = _pendingMessageRestorationIds[conversationId];
    if (pending == null) return <String>{};
    final removed = pending.intersection(ids.toSet());
    pending.removeAll(removed);
    if (pending.isEmpty) _pendingMessageRestorationIds.remove(conversationId);
    return removed;
  }

  Future<void> _appendMessageRestorations(
      String conversationId, Iterable<String> ids,
      {bool insidePersistenceQueue = false}) async {
    final restoredIds = ids.toSet();
    _addPendingMessageRestorations(conversationId, restoredIds);
    final preferenceSaved = await _persistPendingRestoredMessages();
    var journalSaved = false;
    final record = <String, dynamic>{
      'kind': 'messageRestored',
      'conversationId': conversationId,
      'messageIds': restoredIds.toList(),
    };
    try {
      if (insidePersistenceQueue) {
        await _appendStreamCheckpoint(record);
      } else {
        await _appendJournalBarrier(record);
      }
      journalSaved = true;
    } catch (e) {
      debugPrint('Failed to append restored message marker: $e');
    }
    if (journalSaved || preferenceSaved) {
      _removePendingMessageDeletions(conversationId, restoredIds);
    }
    if (!preferenceSaved && !journalSaved) {
      throw StateError('Failed to persist restored message markers');
    }
  }

  Map<String, DateTime> _pendingRestoredConversationsFor(
    List<Conversation> conversations,
  ) {
    final createdAtById = {
      for (final conversation in conversations)
        conversation.id: conversation.createdAt.toIso8601String(),
    };
    return {
      for (final entry in _pendingRestoredConversations.entries)
        if (createdAtById[entry.key] == entry.value.split('|').first &&
            entry.value.split('|').length > 1)
          entry.key: DateTime.tryParse(entry.value.split('|').last) ??
              DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  Future<String> _streamJournalPath() async =>
      p.join(await AppStorage.directory, _streamJournalFileName);

  Future<void> _appendStreamCheckpoint(Map<String, dynamic> checkpoint) async {
    if (kIsWeb) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      var persistedLastTimestamp = prefs.getInt(_webStreamJournalTimestampKey);
      if (persistedLastTimestamp == null) {
        final existingKeys =
            await WebFileStore.keysWithPrefix(_streamJournalWebPrefix)
              ..sort();
        persistedLastTimestamp = existingKeys.isEmpty
            ? 0
            : int.tryParse(existingKeys.last.substring(
                  _streamJournalWebPrefix.length,
                )) ??
                0;
      }
      final previousTimestamp =
          persistedLastTimestamp > _lastWebJournalTimestamp
              ? persistedLastTimestamp
              : _lastWebJournalTimestamp;
      _lastWebJournalTimestamp =
          now > previousTimestamp ? now : previousTimestamp + 1;
      if (!await prefs.setInt(
        _webStreamJournalTimestampKey,
        _lastWebJournalTimestamp,
      )) {
        throw StateError('Failed to persist web stream journal sequence');
      }
      final key = '$_streamJournalWebPrefix'
          '${_lastWebJournalTimestamp.toString().padLeft(20, '0')}';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(checkpoint)));
      await WebFileStore.write(key, bytes);
      _rememberAppendedStreamCheckpoint(checkpoint);
      return;
    }
    if (!_streamJournalPresent) {
      // Set the marker before touching the journal. A crash between these
      // writes only causes an empty read at startup; the reverse ordering
      // could leave a durable checkpoint that startup never discovers.
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(_nativeStreamJournalPresentKey, true)) {
        throw StateError('Failed to mark native stream journal present');
      }
      _streamJournalPresent = true;
    }
    await AppStorage.appendDurableLine(
      await _streamJournalPath(),
      jsonEncode(checkpoint),
    );
    _rememberAppendedStreamCheckpoint(checkpoint);
  }

  void _rememberAppendedStreamCheckpoint(Map<String, dynamic> record) {
    if (record['kind'] != null) return;
    final conversationId = record['conversationId'];
    final messageId = record['messageId'];
    if (conversationId is String &&
        messageId is String &&
        messageId.isNotEmpty) {
      _streamCheckpointKeys
          .add(_streamCheckpointKey(conversationId, messageId));
    }
    if (!_streamCheckpointReplayInProgress) {
      _streamCheckpointKeyIndexIsCurrent = true;
    }
  }

  Future<void> _appendJournalBarrier(Map<String, dynamic> record) async {
    final current = _coalescedStreamPersist;
    if (current != null) current.accepting = false;
    final write = _persistQueue.then((_) => _appendStreamCheckpoint(record));
    _persistQueue = write.then((_) {}, onError: (Object error, StackTrace st) {
      debugPrint('Failed to queue conversation persistence: $error');
    });
    await write;
  }

  Future<bool> _clearStreamCheckpoints() async {
    try {
      if (kIsWeb) {
        await WebFileStore.deleteByPrefix(_streamJournalWebPrefix);
        _streamCheckpointKeys.clear();
        _streamCheckpointKeyIndexIsCurrent = true;
        return true;
      }
      if (!_streamJournalPresent) {
        _streamCheckpointKeys.clear();
        _streamCheckpointKeyIndexIsCurrent = true;
        return true;
      }
      final deleted = await AppStorage.deleteStorageFile(
        await _streamJournalPath(),
      );
      if (deleted) {
        final prefs = await SharedPreferences.getInstance();
        if (await prefs.remove(_nativeStreamJournalPresentKey)) {
          _streamJournalPresent = false;
        }
        _streamCheckpointKeys.clear();
        _streamCheckpointKeyIndexIsCurrent = true;
      }
      return deleted;
    } catch (e) {
      debugPrint('Failed to clear conversation stream checkpoints: $e');
      return false;
    }
  }

  Future<List<Conversation>> _replayStreamCheckpoints(
    List<Conversation> conversations, {
    bool onlyKnownConversations = false,
    bool strict = false,
    Map<String, DateTime> pendingRestoredConversations =
        const <String, DateTime>{},
    Map<String, Set<String>> pendingRestoredMessageIds =
        const <String, Set<String>>{},
  }) async {
    final refreshCheckpointIndex = !_streamCheckpointKeyIndexIsCurrent;
    if (refreshCheckpointIndex) {
      _streamCheckpointReplayInProgress = true;
    }
    try {
      conversations = List<Conversation>.from(conversations);
      final webKeys = kIsWeb
          ? await WebFileStore.keysWithPrefix(_streamJournalWebPrefix)
          : null;
      webKeys?.sort();
      final nativeJournalPath =
          !kIsWeb && _streamJournalPresent ? await _streamJournalPath() : null;
      final nativeJournalEnd = nativeJournalPath == null
          ? null
          : await AppStorage.durableFileLength(nativeJournalPath);
      final deletedConversations = <String>{};
      final deletedConversationAt = <String, DateTime>{};
      final deletedMessages = <String, Set<String>>{};
      final recreatedConversations = <String, DateTime>{};
      await for (final line in _readStreamCheckpointRecords(
        webKeys: webKeys,
        nativePath: nativeJournalPath,
        nativeEnd: nativeJournalEnd,
      )) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is! Map) continue;
          final kind = decoded['kind'];
          if (kind == 'conversationsDeleted') {
            final ids = decoded['conversationIds'];
            final deletedAt =
                DateTime.tryParse(decoded['deletedAt'] as String? ?? '');
            if (ids is List) {
              for (final id in ids.whereType<String>()) {
                deletedConversations.add(id);
                recreatedConversations.remove(id);
                if (deletedAt != null) deletedConversationAt[id] = deletedAt;
              }
            }
            continue;
          }
          final conversationId = decoded['conversationId'];
          if (conversationId is! String) continue;
          if (kind == 'conversationDeleted') {
            deletedConversations.add(conversationId);
            recreatedConversations.remove(conversationId);
            final deletedAt =
                DateTime.tryParse(decoded['deletedAt'] as String? ?? '');
            if (deletedAt != null) {
              deletedConversationAt[conversationId] = deletedAt;
            }
          } else if (kind == 'conversationRestored') {
            deletedConversations.remove(conversationId);
            deletedConversationAt.remove(conversationId);
          } else if (kind == 'conversationCreated') {
            deletedConversations.remove(conversationId);
            deletedConversationAt.remove(conversationId);
            deletedMessages.remove(conversationId);
            final createdAt =
                DateTime.tryParse(decoded['createdAt'] as String? ?? '');
            if (createdAt != null) {
              recreatedConversations[conversationId] = createdAt;
            }
          } else if (kind == 'messageDeleted') {
            final messageIds = decoded['messageIds'];
            if (messageIds is List) {
              deletedMessages
                  .putIfAbsent(conversationId, () => <String>{})
                  .addAll(messageIds.whereType<String>());
            } else if (decoded['messageId'] is String) {
              deletedMessages
                  .putIfAbsent(conversationId, () => <String>{})
                  .add(decoded['messageId'] as String);
            }
          } else if (kind == 'messageRestored') {
            final messageIds = decoded['messageIds'];
            if (messageIds is List) {
              deletedMessages[conversationId]?.removeAll(
                messageIds.whereType<String>(),
              );
            }
          } else if (kind == null &&
              deletedConversations.contains(conversationId)) {
            final createdAt = DateTime.tryParse(
              decoded['conversationCreatedAt'] as String? ?? '',
            );
            final deletedAt = deletedConversationAt[conversationId];
            if (createdAt != null &&
                deletedAt != null &&
                createdAt.isAfter(deletedAt)) {
              deletedConversations.remove(conversationId);
              deletedConversationAt.remove(conversationId);
              deletedMessages.remove(conversationId);
              recreatedConversations[conversationId] = createdAt;
            }
          }
        } catch (_) {
          // A torn last record is ignored; earlier checkpoints remain usable.
        }
      }
      for (final entry in pendingRestoredConversations.entries) {
        final deletedAt = deletedConversationAt[entry.key];
        if (deletedAt == null || !deletedAt.isAfter(entry.value)) {
          deletedConversations.remove(entry.key);
          deletedConversationAt.remove(entry.key);
        }
      }
      for (final entry in pendingRestoredMessageIds.entries) {
        deletedMessages[entry.key]?.removeAll(entry.value);
      }
      conversations.removeWhere((conversation) {
        final deletedAt = deletedConversationAt[conversation.id];
        return deletedConversations.contains(conversation.id) &&
            (deletedAt == null || !conversation.createdAt.isAfter(deletedAt));
      });
      for (final conversation in conversations) {
        final deletedForConversation = deletedMessages[conversation.id];
        if (deletedForConversation == null) continue;
        conversation.messages.removeWhere(
          (message) => deletedForConversation.contains(message.id),
        );
      }
      final byId = {
        for (final conversation in conversations) conversation.id: conversation,
      };
      final messageIndexesByConversationId = <String, Map<String, int>>{};
      final indexedMessagesByConversationId = <String, List<ChatMessage>>{};
      final unorderedMessageConversationIds = <String>{};
      final replayedMessageSections = <String, _ReplayMessageSections>{};
      await for (final line in _readStreamCheckpointRecords(
        webKeys: webKeys,
        nativePath: nativeJournalPath,
        nativeEnd: nativeJournalEnd,
      )) {
        if (line.isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is! Map) continue;
          final record = Map<String, dynamic>.from(decoded);
          final conversationId = record['conversationId'];
          final messageId = record['messageId'];
          if (conversationId is! String ||
              messageId is! String ||
              messageId.isEmpty) {
            continue;
          }
          if (deletedConversations.contains(conversationId) ||
              (deletedMessages[conversationId]?.contains(messageId) ?? false)) {
            continue;
          }
          _streamCheckpointKeys
              .add(_streamCheckpointKey(conversationId, messageId));
          final recreatedAt = recreatedConversations[conversationId];
          final checkpointCreatedAt =
              DateTime.tryParse(record['createdAt'] as String? ?? '');
          if (recreatedAt != null &&
              checkpointCreatedAt != null &&
              checkpointCreatedAt.isBefore(recreatedAt)) {
            continue;
          }
          var conversation = byId[conversationId];
          final needsToAddConversation = conversation == null;
          final baseConversationRaw = record['baseConversation'];
          Conversation? baseConversation;
          if (baseConversationRaw is Map) {
            try {
              baseConversation = Conversation.fromMap(
                Map<String, dynamic>.from(baseConversationRaw),
              );
              if (baseConversation.id != conversationId) {
                baseConversation = null;
              }
            } catch (_) {
              baseConversation = null;
            }
          }
          if (conversation == null) {
            if (onlyKnownConversations) continue;
            final conversationCreatedAt = DateTime.tryParse(
              record['conversationCreatedAt'] as String? ?? '',
            );
            final checkpointUpdatedAt =
                DateTime.tryParse(record['updatedAt'] as String? ?? '');
            conversation = baseConversation ??
                Conversation(
                  id: conversationId,
                  title: '',
                  createdAt: conversationCreatedAt,
                  updatedAt: checkpointUpdatedAt ?? conversationCreatedAt,
                  isTemporary: record['isTemporary'] as bool? ?? false,
                  temporaryExpiresAt: DateTime.tryParse(
                    record['temporaryExpiresAt'] as String? ?? '',
                  ),
                  temporaryExpiryVersion:
                      record['temporaryExpiryVersion'] as int? ??
                          kTemporaryConversationDurationVersion,
                  messages: [],
                );
          }
          var messageIndexes = messageIndexesByConversationId[conversationId];
          if (messageIndexes == null ||
              !identical(
                indexedMessagesByConversationId[conversationId],
                conversation.messages,
              )) {
            messageIndexes =
                _buildCheckpointMessageIndex(conversation.messages);
            messageIndexesByConversationId[conversationId] = messageIndexes;
            indexedMessagesByConversationId[conversationId] =
                conversation.messages;
            if (_checkpointMessagesAreOrdered(conversation.messages)) {
              unorderedMessageConversationIds.remove(conversationId);
            } else {
              unorderedMessageConversationIds.add(conversationId);
            }
          }
          final checkpointMessageExists = messageIndexes.containsKey(messageId);
          final checkpointUpdatedAt =
              DateTime.tryParse(record['updatedAt'] as String? ?? '');
          final checkpointMetadataIsCurrent = checkpointUpdatedAt != null &&
              !checkpointUpdatedAt.isBefore(conversation.updatedAt);
          final checkpointIsCurrent = checkpointUpdatedAt != null &&
              (!checkpointMessageExists || checkpointMetadataIsCurrent);
          if (!checkpointIsCurrent) continue;
          if (needsToAddConversation) {
            conversations.add(conversation);
            byId[conversationId] = conversation;
          }
          _mergeCheckpointHistoryMessages(
            conversation,
            baseConversationRaw is Map ? baseConversationRaw['messages'] : null,
            deletedMessages[conversationId] ?? const <String>{},
            messageIndexes,
            unorderedMessageConversationIds.contains(conversationId),
          );
          _mergeCheckpointHistoryMessages(
            conversation,
            record['historyMessages'],
            deletedMessages[conversationId] ?? const <String>{},
            messageIndexes,
            unorderedMessageConversationIds.contains(conversationId),
          );
          final existingIndex = messageIndexes[messageId] ?? -1;
          final existing =
              existingIndex < 0 ? null : conversation.messages[existingIndex];
          final messageKey = _streamCheckpointKey(conversationId, messageId);
          final sections = replayedMessageSections.putIfAbsent(
            messageKey,
            () => _ReplayMessageSections(
              conversationId: conversationId,
              messageId: messageId,
              textSections: existing?.textSections?.toList() ??
                  (existing != null && existing.content.isNotEmpty
                      ? <String>[existing.content]
                      : <String>[]),
              reasoningSections: existing?.reasoningSections?.toList() ??
                  (existing?.reasoningContent == null
                      ? <String>[]
                      : <String>[existing!.reasoningContent!]),
            ),
          );
          final callsRaw = record['toolCalls'];
          final calls = <String, ToolCallData>{
            for (final call in existing?.toolCalls ?? const <ToolCallData>[])
              call.id: call,
          };
          if (checkpointMetadataIsCurrent &&
              checkpointUpdatedAt!.isAfter(conversation.updatedAt)) {
            conversation.updatedAt = checkpointUpdatedAt;
          }
          var conversationMetadataChanged = false;
          if (checkpointMetadataIsCurrent && record['isTemporary'] is bool) {
            final isTemporary = record['isTemporary'] as bool;
            final expiryRaw = record['temporaryExpiresAt'];
            final expiry =
                expiryRaw is String ? DateTime.tryParse(expiryRaw) : null;
            final expiryVersion = record['temporaryExpiryVersion'];
            if (conversation.isTemporary != isTemporary ||
                conversation.temporaryExpiresAt != expiry ||
                (expiryVersion is int &&
                    conversation.temporaryExpiryVersion != expiryVersion)) {
              conversation.isTemporary = isTemporary;
              conversation.temporaryExpiresAt = expiry;
              if (expiryVersion is int) {
                conversation.temporaryExpiryVersion = expiryVersion;
              }
              conversationMetadataChanged = true;
            }
          }
          if (callsRaw is List) {
            for (final rawCall in callsRaw.whereType<Map>()) {
              final call = ToolCallData.fromMap(
                Map<String, dynamic>.from(rawCall),
              );
              calls[call.id] = call;
            }
          }
          final callsChanged = existing == null ||
              jsonEncode(calls.values.map((call) => call.toMap()).toList()) !=
                  jsonEncode(
                    (existing.toolCalls ?? const <ToolCallData>[])
                        .map((call) => call.toMap())
                        .toList(),
                  );
          final roundStartsRaw = record['toolCallRoundStarts'];
          final roundStarts =
              roundStartsRaw is List && roundStartsRaw.isNotEmpty
                  ? roundStartsRaw.whereType<int>().toList()
                  : existing?.toolCallRoundStarts;
          final roundStartsChanged = existing == null ||
              jsonEncode(roundStarts) !=
                  jsonEncode(existing.toolCallRoundStarts);
          final recordCreatedAt =
              DateTime.tryParse(record['createdAt'] as String? ?? '');
          final textChanged = sections.text.apply(record['textDeltas']);
          final reasoningChanged =
              sections.reasoning.apply(record['reasoningDeltas']);
          if (existing != null &&
              !textChanged &&
              !reasoningChanged &&
              !callsChanged &&
              !roundStartsChanged &&
              !conversationMetadataChanged) {
            continue;
          }
          sections.shouldFinalize = true;
          final createdAt =
              recordCreatedAt ?? existing?.createdAt ?? DateTime.now();
          final message = ChatMessage(
            id: messageId,
            role: 'assistant',
            content: '',
            createdAt: existing?.createdAt ?? createdAt,
            isError: existing?.isError ?? false,
            rawRequest: existing?.rawRequest,
            rawResponse: existing?.rawResponse,
            textSections: sections.text.sections.isEmpty
                ? null
                : sections.text.sections,
            reasoningSections: sections.reasoning.sections.isEmpty
                ? null
                : sections.reasoning.sections,
            toolCalls: calls.isEmpty ? null : calls.values.toList(),
            toolCallRoundStarts:
                roundStarts?.isEmpty ?? true ? null : roundStarts,
            contentFromTextSections: true,
          );
          if (existingIndex < 0) {
            if (conversation.messages.isNotEmpty &&
                conversation.messages.last.createdAt
                    .isAfter(message.createdAt)) {
              unorderedMessageConversationIds.add(conversationId);
            }
            conversation.messages.add(message);
            messageIndexes[messageId] = conversation.messages.length - 1;
          } else {
            conversation.messages[existingIndex] = message;
          }
        } catch (e) {
          debugPrint('Skipping invalid conversation stream checkpoint: $e');
        }
      }
      for (final sections in replayedMessageSections.values) {
        if (!sections.shouldFinalize) continue;
        final conversation = byId[sections.conversationId];
        if (conversation == null) continue;
        final messageIndexes = _buildCheckpointMessageIndex(conversation.messages);
        final messageIndex = messageIndexes[sections.messageId];
        if (messageIndex == null) continue;
        conversation.messages[messageIndex] =
            conversation.messages[messageIndex].copyWith(
          textSections: sections.text.sections.isEmpty
              ? null
              : sections.text.materialize(),
          reasoningSections: sections.reasoning.sections.isEmpty
              ? null
              : sections.reasoning.materialize(),
        );
      }
      if (refreshCheckpointIndex) {
        _streamCheckpointKeyIndexIsCurrent = true;
      }
    } catch (e) {
      if (refreshCheckpointIndex) {
        _streamCheckpointKeyIndexIsCurrent = false;
      }
      debugPrint('Failed to replay conversation stream checkpoints: $e');
      if (strict) rethrow;
    } finally {
      if (refreshCheckpointIndex) {
        _streamCheckpointReplayInProgress = false;
      }
    }
    return conversations;
  }

  Stream<String> _readStreamCheckpointRecords({
    required List<String>? webKeys,
    required String? nativePath,
    required int? nativeEnd,
  }) async* {
    if (webKeys != null) {
      for (final key in webKeys) {
        final bytes = await WebFileStore.read(key);
        if (bytes != null) {
          yield utf8.decode(bytes, allowMalformed: true);
        }
      }
      return;
    }
    if (nativePath == null || nativeEnd == null) return;
    final records = await AppStorage.readDurableLines(
      nativePath,
      end: nativeEnd,
    );
    if (records != null) yield* records;
  }

  Map<String, int> _buildCheckpointMessageIndex(List<ChatMessage> messages) {
    final indexes = <String, int>{};
    for (var index = 0; index < messages.length; index++) {
      indexes.putIfAbsent(messages[index].id, () => index);
    }
    return indexes;
  }

  bool _checkpointMessagesAreOrdered(List<ChatMessage> messages) {
    for (var index = 1; index < messages.length; index++) {
      if (messages[index - 1].createdAt.isAfter(messages[index].createdAt)) {
        return false;
      }
    }
    return true;
  }

  int _checkpointHistoryInsertionIndex(
    List<ChatMessage> messages,
    DateTime createdAt,
  ) {
    var low = 0;
    var high = messages.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (messages[middle].createdAt.isAfter(createdAt)) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low < messages.length ? low : -1;
  }

  void _mergeCheckpointHistoryMessages(
    Conversation conversation,
    dynamic rawMessages,
    Set<String> deletedMessageIds,
    Map<String, int> messageIndexes,
    bool messageOrderIsUnsorted,
  ) {
    if (rawMessages is! List) return;
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      try {
        final message = ChatMessage.fromMap(Map<String, dynamic>.from(raw));
        if (deletedMessageIds.contains(message.id)) continue;
        if (messageIndexes.containsKey(message.id)) continue;
        final insertionIndex = messageOrderIsUnsorted
            ? conversation.messages.indexWhere(
                (existing) => existing.createdAt.isAfter(message.createdAt),
              )
            : _checkpointHistoryInsertionIndex(
                conversation.messages,
                message.createdAt,
              );
        if (insertionIndex < 0) {
          conversation.messages.add(message);
          messageIndexes[message.id] = conversation.messages.length - 1;
        } else {
          conversation.messages.insert(insertionIndex, message);
          messageIndexes.updateAll(
            (id, index) => index >= insertionIndex ? index + 1 : index,
          );
          messageIndexes[message.id] = insertionIndex;
        }
      } catch (e) {
        debugPrint(
          'Skipping invalid history message in stream checkpoint: $e',
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // Persistence
  // --------------------------------------------------------------------------

  Future<void> _load() async {
    _unparsedConversationRecords = [];
    // 启动窗口内用户创建了新对话（合并进内存）时，_load 完成后
    // 需要把合并结果落盘（见 finally）：否则"下次持久化前退出"
    // 会丢失新对话。
    var hadInMemoryMerge = false;
    List<Conversation>? loadedConversations;
    try {
      final prefs = await SharedPreferences.getInstance();
      _streamJournalPresent =
          prefs.getBool(_nativeStreamJournalPresentKey) ?? false;
      final pendingRestoresJson =
          prefs.getString(_pendingRestoredConversationKey);
      if (pendingRestoresJson != null) {
        try {
          final decoded = jsonDecode(pendingRestoresJson);
          if (decoded is Map) {
            _pendingRestoredConversations
              ..clear()
              ..addAll({
                for (final entry in decoded.entries)
                  if (entry.key is String && entry.value is String)
                    entry.key as String: entry.value as String,
              });
          }
        } catch (e) {
          debugPrint('Failed to decode pending conversation restores: $e');
        }
      }
      final pendingMessageRestoresJson =
          prefs.getString(_pendingRestoredMessageKey);
      if (pendingMessageRestoresJson != null) {
        try {
          final decoded = jsonDecode(pendingMessageRestoresJson);
          if (decoded is Map) {
            _pendingMessageRestorationIds
              ..clear()
              ..addAll({
                for (final entry in decoded.entries)
                  if (entry.key is String && entry.value is List)
                    entry.key as String:
                        (entry.value as List).whereType<String>().toSet(),
              });
          }
        } catch (e) {
          debugPrint('Failed to decode pending message restores: $e');
        }
      }
      final json = prefs.getString('conversations');
      if (json != null && json.isNotEmpty) {
        try {
          final decoded = jsonDecode(json);
          if (decoded is List) {
            final conversations = <Conversation>[];
            var migratedTemporaryExpiries = false;
            for (final item in decoded) {
              if (item is Map) {
                try {
                  final conversation = Conversation.fromMap(
                    Map<String, dynamic>.from(item),
                  );
                  if (conversation.isTemporary &&
                      conversation.temporaryExpiryVersion <
                          kTemporaryConversationDurationVersion) {
                    // Version 0 records used a 24-hour window. Store the
                    // adjusted expiry and version in the same JSON write.
                    conversation.temporaryExpiresAt = conversation
                        .temporaryExpiresAt!
                        .subtract(const Duration(hours: 23));
                    conversation.temporaryExpiryVersion =
                        kTemporaryConversationDurationVersion;
                    item['temporaryExpiresAt'] =
                        conversation.temporaryExpiresAt!.toIso8601String();
                    item['temporaryExpiryVersion'] =
                        kTemporaryConversationDurationVersion;
                    migratedTemporaryExpiries = true;
                  }
                  conversations.add(conversation);
                } catch (e) {
                  _unparsedConversationRecords.add(item);
                  debugPrint('ConversationsNotifier: 跳过损坏的对话条目: $e');
                  await AppLogService.warning(
                    'ConversationsNotifier',
                    '跳过损坏的对话条目: $e',
                  );
                }
              } else {
                _unparsedConversationRecords.add(item);
              }
            }
            if (migratedTemporaryExpiries) {
              try {
                // Encode the original list so skipped malformed entries and
                // unknown fields remain available for recovery.
                final migratedJson = jsonEncode(decoded);
                final saved = await prefs.setString(
                  'conversations',
                  migratedJson,
                );
                if (!saved) {
                  debugPrint(
                    'ConversationsNotifier: failed to save migrated temporary expiries',
                  );
                }
              } catch (e) {
                debugPrint(
                  'ConversationsNotifier: failed to migrate temporary expiries: $e',
                );
                await AppLogService.warning(
                  'ConversationsNotifier',
                  '迁移临时对话倒计时失败，已保留内存中的倒计时',
                );
              }
            }
            if (mounted) {
              // 竞态防护：_load 的 await 窗口内用户可能已创建对话
              // （createConversation 只改内存态，磁盘无记录）——
              // 磁盘加载结果与内存合并：磁盘对话为准，内存中磁盘
              // 没有的新对话保留（置前，保持"新对话在顶部"；随后
              // 归一化使置顶对话浮到前面），避免新对话被静默覆盖
              // 丢失，也避免新对话被合并到列表末尾。
              final inMemory = state;
              if (inMemory.isNotEmpty) {
                final diskIds = conversations.map((c) => c.id).toSet();
                final extra =
                    inMemory.where((c) => !diskIds.contains(c.id)).toList();
                loadedConversations = pinnedFirstStable([
                  ...extra,
                  ...conversations,
                ]);
                hadInMemoryMerge = true;
              } else {
                loadedConversations = pinnedFirstStable(conversations);
              }
              final activeId = prefs.getString('active_conversation_id');
              if (activeId != null &&
                  _ref.read(activeConversationIdProvider) == null) {
                // Restore the saved selection before publishing the canonical
                // list. It may refer to a conversation present only in the
                // stream journal, which is replayed below.
                _ref.read(activeConversationIdProvider.notifier).state =
                    activeId;
              }
              state = loadedConversations;
            }
            await AppLogService.info(
              'ConversationsNotifier',
              '加载了 ${conversations.length} 个对话',
            );
          } else {
            // 磁盘数据无效：内存已有对话（用户刚创建）时保留内存
            if (mounted && state.isEmpty) state = [];
            // 磁盘不可用但内存有新对话：标记合并，finally 落盘
            // （否则启动窗口内创建的新对话在下次持久化前退出会丢失）
            if (mounted && state.isNotEmpty) hadInMemoryMerge = true;
            await AppLogService.info('ConversationsNotifier', '对话数据格式无效');
          }
        } catch (e) {
          debugPrint('Failed to decode conversations JSON: $e');
          await AppLogService.error('ConversationsNotifier', '解析对话 JSON 失败', e);
          // Back up the corrupt file so the user can manually recover it
          // and we don't silently overwrite it on the next save.
          await _backupCorruptConversationsFile(prefs, json);
          // 磁盘损坏：内存已有对话（用户刚创建）时保留内存
          if (mounted && state.isEmpty) state = [];
          if (mounted && state.isNotEmpty) hadInMemoryMerge = true;
        }
      } else {
        // 无已保存数据：内存已有对话时保留内存
        if (mounted && state.isEmpty) state = [];
        if (mounted && state.isNotEmpty) hadInMemoryMerge = true;
        await AppLogService.info('ConversationsNotifier', '没有已保存的对话');
      }

      if (mounted) {
        final replayStartingConversations = {
          for (final conversation in state) conversation.id: conversation,
        };
        // Conversation is mutable: message updates replace its messages list
        // without replacing the Conversation object. Keep the original list
        // identity too, so an update that lands during journal I/O is not
        // mistaken for the unchanged object captured above.
        final replayStartingMessages = {
          for (final conversation in state)
            conversation.id: conversation.messages,
        };
        final replayStartingMessageIds = {
          for (final conversation in state)
            conversation.id:
                conversation.messages.map((message) => message.id).toSet(),
        };
        final restored = await _replayStreamCheckpoints(
          loadedConversations ?? state,
          pendingRestoredConversations: _pendingRestoredConversationsFor(
            loadedConversations ?? state,
          ),
          pendingRestoredMessageIds: _pendingMessageRestorationIds,
        );
        if (_resolveUnindexedMessageDeletions()) {
          // The explicit save that ran during loading could not persist yet.
          // Persist again after _loadHasRun is set in the finally block.
          hadInMemoryMerge = true;
        }
        if (mounted) {
          final replayedById = {
            for (final conversation in restored) conversation.id: conversation,
          };
          final finalConversations = <Conversation>[];
          // Preserve the current state order: users may reorder conversations
          // while replay is awaiting storage I/O.
          for (final current in state) {
            final startingConversation =
                replayStartingConversations[current.id];
            final replayed = replayedById.remove(current.id);
            if (startingConversation == null) {
              finalConversations.add(current);
              hadInMemoryMerge = true;
            } else if (replayed == null) {
              // A replay tombstone removes a canonical record unless the user
              // replaced that conversation while replay was awaiting I/O.
              if (!identical(current, startingConversation)) {
                finalConversations.add(current);
                hadInMemoryMerge = true;
              }
            } else if (identical(current, startingConversation) &&
                identical(
                  current.messages,
                  replayStartingMessages[current.id],
                )) {
              final startingMessageIds =
                  replayStartingMessageIds[current.id] ?? const <String>{};
              final currentMessageIds =
                  current.messages.map((message) => message.id).toSet();
              final removedMessageIds =
                  startingMessageIds.difference(currentMessageIds);
              if (removedMessageIds.isNotEmpty) {
                replayed.messages.removeWhere(
                  (message) => removedMessageIds.contains(message.id),
                );
              }
              finalConversations.add(replayed);
            } else {
              // Keep an in-memory edit that landed while journal records were
              // being read. Replaying the older canonical snapshot for the
              // same mutable Conversation would otherwise restore messages
              // that the user had just removed (including old tool cards).
              finalConversations.add(current);
              hadInMemoryMerge = true;
            }
          }
          // Journal-only conversations discovered during replay are not in
          // the current state list; append them after preserving user order.
          for (final conversation in replayedById.values) {
            if (!replayStartingConversations.containsKey(conversation.id)) {
              finalConversations.add(conversation);
            }
          }
          final orderedConversations = pinnedFirstStable(finalConversations);
          final activeId = prefs.getString('active_conversation_id');
          final currentActiveId = _ref.read(activeConversationIdProvider);
          final hasCurrentActiveConversation = currentActiveId != null &&
              orderedConversations.any((c) => c.id == currentActiveId);
          if (!hasCurrentActiveConversation &&
              activeId != null &&
              orderedConversations.any((c) => c.id == activeId)) {
            _ref.read(activeConversationIdProvider.notifier).state = activeId;
          } else if (currentActiveId != null && !hasCurrentActiveConversation) {
            _ref.read(activeConversationIdProvider.notifier).state = null;
          }
          state = orderedConversations;
        }
      }

      // Auto-fix conversations with null assistantId on every load.
      // This is more reliable than the old one-time migration flag:
      // it catches conversations that were created without assistantId
      // even after the old migration had already "run".
      try {
        if (mounted) {
          await assignNullAssistantConversations(
            prefs,
            state,
            preservedRecords: _unparsedConversationRecords,
          );
          // 修复函数可能原位修改了 state 列表：重新赋值以触发
          // 监听者刷新（await 期间 notifier 可能被 dispose，需重查）。
          if (mounted) {
            state = List<Conversation>.from(state);
          }
        }
      } catch (e) {
        debugPrint('Failed to auto-fix null assistant conversations: $e');
        await AppLogService.error(
          'ConversationsNotifier',
          '修复空 assistantId 失败',
          e,
        );
      }

      // Restore last active conversation
      try {
        if (mounted) {
          final activeId = prefs.getString('active_conversation_id');
          if (activeId != null && state.any((c) => c.id == activeId)) {
            await AppLogService.info(
              'ConversationsNotifier',
              '恢复上次活跃对话: $activeId',
            );
          } else {
            if (_ref.read(activeConversationIdProvider) == activeId) {
              _ref.read(activeConversationIdProvider.notifier).state = null;
            }
            await AppLogService.warning(
              'ConversationsNotifier',
              '未找到上次活跃对话或 activeId 为 null: activeId=$activeId',
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to restore active conversation: $e');
        await AppLogService.error('ConversationsNotifier', '恢复活跃对话失败', e);
      }
      return;
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
      await AppLogService.error('ConversationsNotifier', '加载对话失败', e);
      if (mounted) state = [];
    } finally {
      // Mark the initial load as having run, so a subsequent debounced
      // _persist (with empty state) doesn't write an empty list over the
      // previous good save before _load completes.
      _loadHasRun = true;
      if (mounted) {
        // 启动临时对话 tick 并立即清理加载期间已到期的临时对话
        // （不等首轮 tick，避免过期对话在启动瞬间仍可见）。
        _syncTemporaryTimer();
        unawaited(_checkTemporaryExpiry());
      }
      // 启动窗口内用户创建的新对话已合并进内存：立即落盘
      // （_loadHasRun 已置位，_persistCore 守卫放行），防止
      // "下次持久化前退出"丢失新对话。
      if (hadInMemoryMerge && mounted) {
        unawaited(_persistCore());
      }
    }
  }

  /// Move a corrupt conversations JSON blob to a timestamped backup key so
  /// the user can inspect it later and we don't overwrite it on the next save.
  ///
  /// This is called when `jsonDecode` throws on the on-disk JSON. The previous
  /// behavior was to silently throw away the data; this preserves the
  /// undecodable payload in case the user wants to recover it manually.

  Future<void> _backupCorruptConversationsFile(
    SharedPreferences prefs,
    String corruptJson,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupKey = 'conversations.corrupt.$timestamp';
      await prefs.setString(backupKey, corruptJson);
      // Also clear the original key so the next save starts fresh instead of
      // repeatedly trying to decode the same corrupt blob.
      await prefs.remove('conversations');
      debugPrint(
        'ConversationsNotifier: backed up corrupt conversations to $backupKey',
      );
      await AppLogService.warning(
        'ConversationsNotifier',
        '检测到损坏的对话数据，已备份到 $backupKey，原始数据已清空',
      );

      // Enforce the cap: keep only the N most recent backups.
      final backupKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('conversations.corrupt.'))
          .toList()
        ..sort();
      while (backupKeys.length > _maxCorruptBackups) {
        final oldest = backupKeys.removeAt(0);
        await prefs.remove(oldest);
        debugPrint(
          'ConversationsNotifier: removed old corrupt backup $oldest (cap=$_maxCorruptBackups)',
        );
      }
    } catch (e) {
      debugPrint('Failed to back up corrupt conversations: $e');
    }
  }

  Future<void> _persistActiveId() async {
    try {
      // 在 await 之前捕获 activeId：notifier 可能在 getInstance 的
      // 异步间隙被 dispose，之后再用 _ref.read 会抛错。
      final activeId = _ref.read(activeConversationIdProvider);
      final prefs = await SharedPreferences.getInstance();
      if (activeId != null) {
        await prefs.setString('active_conversation_id', activeId);
      } else {
        await prefs.remove('active_conversation_id');
      }
    } catch (e) {
      debugPrint('Failed to persist active conversation ID: $e');
    }
  }

  Future<void> _persist() async {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () async {
      await _persistCore();
    });
  }

  Future<void> _persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _persistCore();
  }

  /// Flow-owned attachment cleanup needs confirmation that the conversation
  /// removal reached storage before it can safely delete its files.
  Future<bool> _persistNowChecked() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    return _persistCoreResult();
  }

  /// Queue one latest-wins stream delta while preserving the normal serial
  /// queue. Explicit persistence calls seal the current checkpoint so later
  /// periodic writes cannot cross their ordering barrier.
  Future<void> _persistStreamCheckpoint(Map<String, dynamic> checkpoint) {
    if (!_loadHasRun) {
      return Future<void>.error(
        StateError('Conversation load has not completed'),
      );
    }

    final current = _coalescedStreamPersist;
    final key = _streamCheckpointKey(
      checkpoint['conversationId'] as String,
      checkpoint['messageId'] as String,
    );
    _streamCheckpointKeys.add(key);
    if (current != null && current.accepting) {
      current.checkpoints = {...current.checkpoints, key: checkpoint};
      return current.completion.future;
    }

    final queued = _CoalescedStreamPersist({key: checkpoint});
    _coalescedStreamPersist = queued;
    final write = _persistQueue.then(
      (_) => _drainStreamCheckpoints(queued),
    );
    _persistQueue = write.then(
      (_) {},
      onError: (Object error, StackTrace st) {
        debugPrint('Failed to queue conversation persistence: $error');
      },
    );
    return queued.completion.future;
  }

  Future<void> _drainStreamCheckpoints(
      _CoalescedStreamPersist checkpoint) async {
    try {
      while (true) {
        final deltas = checkpoint.checkpoints;
        for (final delta in deltas.values) {
          await _appendStreamCheckpoint(delta);
        }
        if (identical(checkpoint.checkpoints, deltas)) break;
      }
      checkpoint.accepting = false;
      if (identical(_coalescedStreamPersist, checkpoint)) {
        _coalescedStreamPersist = null;
      }
      checkpoint.completion.complete();
    } catch (error, stackTrace) {
      checkpoint.accepting = false;
      if (identical(_coalescedStreamPersist, checkpoint)) {
        _coalescedStreamPersist = null;
      }
      checkpoint.completion.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// Persist the current state to SharedPreferences with fallback.
  ///
  /// Tries these strategies in order, stopping at the first success:
  /// 1. Normal save (jsonEncode full state toMap) — preserves rawRequest
  ///    and rawResponse for the "view raw data" feature.
  /// 2. Save with rawRequest/rawResponse stripped from every message —
  ///    used when (1) throws so the user's message content is preserved
  ///    even if diagnostic raw data is lost.
  ///
  /// We intentionally do NOT have a tier that drops message content.
  /// Silently losing chat history to "make the save succeed" is worse than
  /// failing the save and keeping the previous good copy on disk.
  ///
  /// All failures are logged so the user can find the cause.
  ///
  /// **Important**: captures a local snapshot of [state] at function entry
  /// so the save still completes if the notifier is disposed mid-call
  /// (e.g. `dispose()` schedules a final save but the notifier is torn down
  /// before it can run — the snapshot is already captured at that point).
  /// We therefore do NOT bail out on `!mounted` at the top; the snapshot
  /// pattern is what protects us.
  Future<void> _persistCore() async {
    await _persistCoreResult();
  }

  Future<bool> _persistCoreResult() async {
    // Seal any coalescible checkpoint before taking an explicit snapshot.
    // Future stream checkpoints then enter the serial queue after this write.
    final streamCheckpoint = _coalescedStreamPersist;
    if (streamCheckpoint != null) streamCheckpoint.accepting = false;

    final List<Conversation> snapshot;
    try {
      snapshot = List<Conversation>.from(state);
    } catch (_) {
      // Notifier was already disposed before we could snapshot. Nothing we
      // can do — the previous good save is still on disk.
      return false;
    }
    if (!_loadHasRun) return false;
    final write = _persistQueue.then((_) => _persistSnapshot(snapshot));
    // Keep the queue usable after an unexpected write error. Callers still
    // await their own write and receive its error.
    _persistQueue = write.then((_) {}, onError: (Object error, StackTrace st) {
      debugPrint('Failed to queue conversation persistence: $error');
    });
    return write;
  }

  Future<bool> _persistSnapshot(List<Conversation> snapshot) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Failed to get SharedPreferences: $e');
      return false;
    }

    // Merge queued checkpoint deltas into the explicit canonical snapshot
    // before writing it. If the journal cannot be read, keep the prior good
    // canonical save and leave the journal intact for startup recovery.
    try {
      if (_pendingMessageDeletionIds.isNotEmpty) {
        await _persistPendingMessageDeletions();
      }
    } catch (e) {
      debugPrint('Failed to persist pending message deletion markers: $e');
      return false;
    }
    if (!_streamCheckpointKeyIndexIsCurrent ||
        _streamCheckpointKeys.isNotEmpty ||
        _pendingMessageRestorationIds.isNotEmpty) {
      try {
        snapshot = await _replayStreamCheckpoints(
          snapshot,
          onlyKnownConversations: true,
          strict: true,
          pendingRestoredConversations:
              _pendingRestoredConversationsFor(snapshot),
          pendingRestoredMessageIds: _pendingMessageRestorationIds,
        );
      } catch (e) {
        debugPrint(
          'Failed to merge stream checkpoints into conversation save: $e',
        );
        return false;
      }
    }

    // Tier 1: full save
    try {
      final records = <dynamic>[
        ...snapshot.map((conversation) => conversation.toMap()),
        ..._unparsedConversationRecords,
      ];
      final json = jsonEncode(records);
      if (!await prefs.setString('conversations', json)) {
        throw StateError('conversation save returned false');
      }
      if (await _clearStreamCheckpoints()) {
        await _clearPendingRestoredConversationMarker();
        await _clearPendingRestoredMessageMarker();
      }
      await AppLogService.debug(
        'ConversationsNotifier',
        '对话已持久化, 共 ${snapshot.length} 个',
      );
      return true;
    } catch (e) {
      debugPrint('Failed to persist conversations (full): $e');
      await AppLogService.error('ConversationsNotifier', '持久化对话失败 (完整)', e);
    }

    // Tier 2: drop rawRequest/rawResponse from every message.
    try {
      final stripped = snapshot
          .map(
            (c) => Conversation(
              id: c.id,
              title: c.title,
              createdAt: c.createdAt,
              updatedAt: c.updatedAt,
              messages: c.messages
                  // Preserve section-backed content while dropping the large
                  // request/response snapshots that made the full save fail.
                  .map((m) => m.copyWith(stripRawData: true))
                  .toList(),
              isPinned: c.isPinned,
              sortOrder: c.sortOrder,
              assistantId: c.assistantId,
              draftText: c.draftText,
              draftAttachments: c.draftAttachments,
              enabledMcpToolNames: c.enabledMcpToolNames,
              hasExplicitEnabledMcpTools: c.hasExplicitEnabledMcpTools,
              contextSummary: c.contextSummary,
              compactionTailStartId: c.compactionTailStartId,
              titleAutoGenerated: c.titleAutoGenerated,
              lastUsedModelName: c.lastUsedModelName,
              lastUsedModelId: c.lastUsedModelId,
              lastUsedProviderName: c.lastUsedProviderName,
              lastInputTokens: c.lastInputTokens,
              lastOutputTokens: c.lastOutputTokens,
              totalCost: c.totalCost,
              isTemporary: c.isTemporary,
              temporaryExpiresAt: c.temporaryExpiresAt,
              temporaryExpiryVersion: c.temporaryExpiryVersion,
            ),
          )
          .toList();
      final records = <dynamic>[
        ...stripped.map((conversation) => conversation.toMap()),
        ..._unparsedConversationRecords,
      ];
      final json = jsonEncode(records);
      if (!await prefs.setString('conversations', json)) {
        throw StateError('stripped conversation save returned false');
      }
      if (await _clearStreamCheckpoints()) {
        await _clearPendingRestoredConversationMarker();
        await _clearPendingRestoredMessageMarker();
      }
      await AppLogService.warning(
        'ConversationsNotifier',
        '持久化对话成功 (剥离 rawRequest/rawResponse 后)',
      );
      return true;
    } catch (e) {
      debugPrint('Failed to persist conversations (stripped): $e');
      await AppLogService.error('ConversationsNotifier', '持久化对话失败 (剥离后)', e);
      // Both tiers failed. The previous good save on disk is preserved
      // (we never overwrote it). Log loudly so the user can find the cause.
    }
    return false;
  }
}
