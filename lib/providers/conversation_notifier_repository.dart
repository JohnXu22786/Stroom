part of 'conversation_provider.dart';

// Extension methods on the notifier use StateNotifier's protected state
// through the owning receiver, matching the behavior of the inline methods.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

const int _conversationRepositoryMessagePageSize = 20;

extension ConversationsNotifierRepository on ConversationsNotifier {
  Future<void> _loadFromConversationRepository() async {
    final preferences = await SharedPreferences.getInstance();
    await _loadStreamJournalMarkers(preferences);
    final repository = _ref.read(conversationRepositoryProvider);
    _conversationRepository = repository;
    final migration =
        await ConversationMigrationService(repository).migrate(preferences);
    if (!migration.verified)
      throw StateError('Conversation migration was not verified.');

    final summaries = await repository.listSummaries();
    final conversations = <Conversation>[];
    for (final summary in summaries) {
      final record = await repository.getConversation(summary.id);
      if (record == null)
        throw StateError('Missing conversation ${summary.id}.');
      final conversation = Conversation.fromMap(
        ConversationRecordAdapter.toLegacyMap(record, const []),
      );
      if (conversation.isTemporary &&
          conversation.temporaryExpiryVersion <
              kTemporaryConversationDurationVersion) {
        // Repository migrations can start from records written by the old
        // 24-hour temporary conversation policy, just like the legacy
        // SharedPreferences loader above.
        conversation.temporaryExpiresAt = conversation.temporaryExpiresAt!
            .subtract(const Duration(hours: 23));
        conversation.temporaryExpiryVersion =
            kTemporaryConversationDurationVersion;
        final migratedRecord = ConversationRecordAdapter.fromLegacyMap(
          conversation.toMap(),
        );
        await repository.upsertConversation(migratedRecord);
      }
      conversations.add(conversation);
      _persistedConversationRecords[summary.id] = _conversationRecordSignature(
        conversation,
      );
      _persistedMessageRecords[summary.id] = {};
    }
    if (conversations.any((conversation) => conversation.assistantId == null)) {
      final defaultAssistantId = await _resolveDefaultAssistantId(preferences);
      if (defaultAssistantId != null) {
        for (final conversation in conversations) {
          if (conversation.assistantId != null) continue;
          conversation.assistantId = defaultAssistantId;
          final record = ConversationRecordAdapter.fromLegacyMap(
            conversation.toMap(),
          );
          await repository.upsertConversation(
            StroomConversation(
              schemaVersion: record.schemaVersion,
              id: record.id,
              title: record.title,
              createdAt: record.createdAt,
              updatedAt: record.updatedAt,
              extensions: record.extensions,
              extraFields: record.extraFields,
            ),
          );
          _persistedConversationRecords[conversation.id] =
              _conversationRecordSignature(conversation);
        }
      }
    }
    if (!mounted) return;
    final loadedIds =
        conversations.map((conversation) => conversation.id).toSet();
    final inMemoryAdditions = state
        .where((conversation) => !loadedIds.contains(conversation.id))
        .toList();
    for (final conversation in inMemoryAdditions) {
      // These conversations have a complete in-memory transcript. Mark it as
      // loaded before persistence so the repository snapshot includes messages
      // created or edited while the initial repository load was pending.
      _messageLoadedConversationIds.add(conversation.id);
      _completeMessageSnapshotGenerations[conversation.id] =
          ++_completeMessageSnapshotGeneration;
    }
    state = pinnedFirstStable([...inMemoryAdditions, ...conversations]);
    _repositoryReady = true;
    _loadHasRun = true;
    final inMemoryAdditionIds =
        inMemoryAdditions.map((conversation) => conversation.id).toSet();
    final additionsPersisted =
        inMemoryAdditions.isEmpty ? true : await _persistCoreResult();

    final activeId = preferences.getString('active_conversation_id');
    if (activeId != null &&
        state.any((conversation) => conversation.id == activeId) &&
        (!inMemoryAdditionIds.contains(activeId) || additionsPersisted)) {
      _ref.read(activeConversationIdProvider.notifier).state = activeId;
      await _loadMessagesFromRepository(activeId);
    }
    if (_streamJournalPresent ||
        _pendingMessageRestorationIds.isNotEmpty ||
        _pendingRestoredConversations.isNotEmpty) {
      state = await _replayStreamCheckpoints(
        state,
        pendingRestoredConversations: _pendingRestoredConversationsFor(state),
        pendingRestoredConversationSnapshots:
            _pendingRestoredConversationSnapshots,
        pendingRestoredMessageIds: _pendingMessageRestorationIds,
      );
      if (_resolveUnindexedMessageDeletions()) {
        await _persistCoreResult();
      }
    }
    if (_resumePausedTemporaryCountdowns(DateTime.now())) {
      await _persistCoreResult();
    }
    _syncTemporaryTimer();
    unawaited(_checkTemporaryExpiry());
  }

  Future<void> _loadStreamJournalMarkers(SharedPreferences preferences) async {
    _streamJournalPresent =
        preferences.getBool(_nativeStreamJournalPresentKey) ?? false;
    final restored = preferences.getString(_pendingRestoredConversationKey);
    if (restored != null) {
      try {
        final decoded = jsonDecode(restored);
        if (decoded is Map) {
          _pendingRestoredConversations
            ..clear()
            ..addAll({
              for (final entry in decoded.entries)
                if (entry.key is String && entry.value is String)
                  entry.key as String: entry.value as String,
            });
        }
      } catch (error) {
        debugPrint('Failed to decode pending conversation restores: $error');
      }
    }
    final snapshots = preferences.getString(
      _pendingRestoredConversationSnapshotKey,
    );
    if (snapshots != null) {
      try {
        final decoded = jsonDecode(snapshots);
        if (decoded is Map) {
          _pendingRestoredConversationSnapshots
            ..clear()
            ..addAll({
              for (final entry in decoded.entries)
                if (entry.key is String && entry.value is Map)
                  entry.key as String: Map<String, dynamic>.from(
                    entry.value as Map,
                  ),
            });
        }
      } catch (error) {
        debugPrint('Failed to decode pending conversation snapshots: $error');
      }
    }
    final messageRestores = preferences.getString(_pendingRestoredMessageKey);
    if (messageRestores != null) {
      try {
        final decoded = jsonDecode(messageRestores);
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
      } catch (error) {
        debugPrint('Failed to decode pending message restores: $error');
      }
    }
  }

  ChatMessage _legacyMessageFromRepository(StroomMessage message) =>
      ChatMessage.fromMap(
        ConversationRecordAdapter.messageToLegacyMap(message),
      );

  Future<List<ChatMessage>> _readAllRepositoryMessages(
    String conversationId,
  ) async {
    final repository = _ref.read(conversationRepositoryProvider);
    final result = <ChatMessage>[];
    const pageSize = 100;
    var offset = 0;
    while (true) {
      final page = await repository.getMessages(
        conversationId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      result.addAll(page.map(_legacyMessageFromRepository));
      offset += page.length;
      if (page.length < pageSize) break;
    }
    return result;
  }

  /// Loads complete history for a model request without expanding the active
  /// chat's displayed, paged window or the list-view summaries.
  Future<List<ChatMessage>> loadFullMessagesForContext(
    String conversationId,
  ) async {
    await ready;
    if (!_repositoryReady) {
      return List<ChatMessage>.from(
        state
                .where((conversation) => conversation.id == conversationId)
                .firstOrNull
                ?.messages ??
            const [],
      );
    }
    final repository = _ref.read(conversationRepositoryProvider);
    final result = <ChatMessage>[];
    const pageSize = 100;
    var offset = 0;
    while (true) {
      final page = await repository.getMessages(
        conversationId,
        offset: offset,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      for (final message in page) {
        _rememberRepositoryMessageSequence(
          conversationId,
          message.id,
          message.sequence,
        );
        result.add(_legacyMessageFromRepository(message));
      }
      offset += page.length;
      if (page.length < pageSize) break;
    }
    return result;
  }

  /// Checks attachment references across the full persisted transcript while
  /// leaving the active conversation's paged message window unchanged.
  Future<Set<String>> getOtherMessageAttachmentPaths(
    String conversationId,
    String messageId,
  ) async {
    final messages = await loadFullMessagesForContext(conversationId);
    return {
      for (final message in messages)
        if (message.id != messageId)
          for (final attachment in message.attachments) attachment.storagePath,
    };
  }

  /// Reloads the latest page after a stream persisted its complete context.
  /// The stream manager can work with the full history while the UI stays
  /// windowed to the latest segment until the user scrolls back.
  Future<List<ChatMessage>> reloadLatestMessagePage(
    String conversationId,
  ) async {
    if (!_repositoryReady) {
      return List<ChatMessage>.from(
        state
                .where((conversation) => conversation.id == conversationId)
                .firstOrNull
                ?.messages ??
            const [],
      );
    }
    await _loadMessagesFromRepository(conversationId);
    return List<ChatMessage>.from(
      state
              .where((conversation) => conversation.id == conversationId)
              .firstOrNull
              ?.messages ??
          const [],
    );
  }

  Future<void> _loadMessagesFromRepository(String conversationId) async {
    final loadGeneration = _invalidateRepositoryMessageLoads(conversationId);
    final completeMarkerAtStart =
        _completeMessageSnapshotGenerations[conversationId];
    final repository = _ref.read(conversationRepositoryProvider);
    final messageCount = await repository.countMessages(
      conversationId: conversationId,
    );
    if ((_repositoryMessageLoadGenerations[conversationId] ?? 0) !=
        loadGeneration) {
      return;
    }
    final offset = (messageCount - _conversationRepositoryMessagePageSize)
        .clamp(0, messageCount)
        .toInt();
    final repositoryMessages = await repository.getMessages(
      conversationId,
      offset: offset,
      limit: _conversationRepositoryMessagePageSize,
    );
    if ((_repositoryMessageLoadGenerations[conversationId] ?? 0) !=
        loadGeneration) {
      return;
    }
    final messages =
        repositoryMessages.map(_legacyMessageFromRepository).toList();
    if (!mounted) return;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return;
    if (completeMarkerAtStart != null &&
        _completeMessageSnapshotGenerations[conversationId] ==
            completeMarkerAtStart) {
      _completeMessageSnapshotGenerations.remove(conversationId);
    }
    conversation.messages = messages;
    _messageLoadedConversationIds.add(conversationId);
    _repositoryMessageOffsets[conversationId] = offset;
    _repositoryMessageCounts[conversationId] = messageCount;
    _persistedMessageRecords[conversationId] = {
      for (var index = 0; index < repositoryMessages.length; index++)
        repositoryMessages[index].id: jsonEncode({
          'sequence': repositoryMessages[index].sequence,
          'record': messages[index].toMap(),
        }),
    };
    _persistedMessageSequences[conversationId] = {
      for (final message in repositoryMessages) message.id: message.sequence,
    };
    for (final message in repositoryMessages) {
      _rememberRepositoryMessageSequence(
        conversationId,
        message.id,
        message.sequence,
      );
    }
    state = List<Conversation>.from(state);
  }

  bool hasEarlierRepositoryMessages(String conversationId) =>
      _repositoryReady && (_repositoryMessageOffsets[conversationId] ?? 0) > 0;

  bool hasLaterRepositoryMessages(String conversationId) {
    if (!_repositoryReady) return false;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return false;
    final offset = _repositoryMessageOffsets[conversationId] ?? 0;
    final count = _repositoryMessageCounts[conversationId] ?? 0;
    return offset + conversation.messages.length < count;
  }

  /// Returns whether a message's repository order falls before (-1), inside
  /// (0), or after (1) the currently loaded page. Null means repository
  /// paging is unavailable for this conversation.
  int? repositoryMessagePageDirection(String conversationId, int messageOrder) {
    if (!_repositoryReady || messageOrder < 0) return null;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return null;
    final start = _repositoryMessageOffsets[conversationId] ?? 0;
    final end = start + conversation.messages.length;
    if (messageOrder < start) return -1;
    if (messageOrder >= end) return 1;
    return 0;
  }

  /// Fetches one earlier page without replacing the provider's visible list
  /// state. The chat page owns the loaded window and asks for additional pages
  /// as the user scrolls toward the beginning of the history.
  Future<List<ChatMessage>> loadEarlierRepositoryMessages(
    String conversationId, {
    int limit = _conversationRepositoryMessagePageSize,
  }) async {
    if (!_repositoryReady || limit <= 0) return const [];
    final currentOffset = _repositoryMessageOffsets[conversationId] ?? 0;
    if (currentOffset <= 0) return const [];
    final newOffset = (currentOffset - limit).clamp(0, currentOffset).toInt();
    final repository = _ref.read(conversationRepositoryProvider);
    final rows = await repository.getMessages(
      conversationId,
      offset: newOffset,
      limit: currentOffset - newOffset,
    );
    if (rows.isEmpty) _repositoryMessageOffsets[conversationId] = 0;
    final messages = rows.map(_legacyMessageFromRepository).toList();
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      _rememberRepositoryMessageSequence(conversationId, row.id, row.sequence);
    }
    return messages;
  }

  /// Fetches one later page after a search result opened an older history
  /// window. The chat view appends these rows as the user scrolls toward the
  /// conversation's newest messages.
  Future<List<ChatMessage>> loadLaterRepositoryMessages(
    String conversationId, {
    int limit = _conversationRepositoryMessagePageSize,
  }) async {
    if (!_repositoryReady || limit <= 0) return const [];
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return const [];
    final offset = _repositoryMessageOffsets[conversationId] ?? 0;
    final count = _repositoryMessageCounts[conversationId] ?? 0;
    final nextOffset = offset + conversation.messages.length;
    if (nextOffset >= count) return const [];
    final repository = _ref.read(conversationRepositoryProvider);
    final rows = await repository.getMessages(
      conversationId,
      offset: nextOffset,
      limit: limit,
    );
    final messages = rows.map(_legacyMessageFromRepository).toList();
    for (final row in rows) {
      _rememberRepositoryMessageSequence(conversationId, row.id, row.sequence);
    }
    return messages;
  }

  /// Loads the page containing a selected message so search results can open
  /// older records without retaining the entire conversation in chat state.
  Future<bool> loadMessagesAroundMessage(
    String conversationId,
    String messageId, {
    int pageSize = _conversationRepositoryMessagePageSize,
  }) async {
    if (!_repositoryReady || pageSize <= 0) return false;
    final loadGeneration = _invalidateRepositoryMessageLoads(conversationId);
    final repository = _ref.read(conversationRepositoryProvider);
    const scanPageSize = 100;
    var scanOffset = 0;
    int? targetOffset;
    while (true) {
      final page = await repository.getMessages(
        conversationId,
        offset: scanOffset,
        limit: scanPageSize,
      );
      if ((_repositoryMessageLoadGenerations[conversationId] ?? 0) !=
          loadGeneration) {
        return false;
      }
      if (page.isEmpty) break;
      final index = page.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        targetOffset = scanOffset + index;
        break;
      }
      scanOffset += page.length;
      if (page.length < scanPageSize) break;
    }
    if (targetOffset == null) return false;

    final messageOffset = (targetOffset ~/ pageSize) * pageSize;
    final rows = await repository.getMessages(
      conversationId,
      offset: messageOffset,
      limit: pageSize,
    );
    if ((_repositoryMessageLoadGenerations[conversationId] ?? 0) !=
        loadGeneration) {
      return false;
    }
    if (!rows.any((message) => message.id == messageId)) return false;
    final messages = rows.map(_legacyMessageFromRepository).toList();
    if (!mounted) return false;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return false;
    final messageCount = await repository.countMessages(
      conversationId: conversationId,
    );
    if (!mounted ||
        (_repositoryMessageLoadGenerations[conversationId] ?? 0) !=
            loadGeneration) {
      return false;
    }
    conversation.messages = messages;
    _messageLoadedConversationIds.add(conversationId);
    _repositoryMessageOffsets[conversationId] = messageOffset;
    _repositoryMessageCounts[conversationId] = messageCount;
    _persistedMessageRecords[conversationId] = {
      for (var index = 0; index < rows.length; index++)
        rows[index].id: jsonEncode({
          'sequence': rows[index].sequence,
          'record': messages[index].toMap(),
        }),
    };
    _persistedMessageSequences[conversationId] = {
      for (final row in rows) row.id: row.sequence,
    };
    for (final row in rows) {
      _rememberRepositoryMessageSequence(conversationId, row.id, row.sequence);
    }
    state = List<Conversation>.from(state);
    return true;
  }

  /// Commits a page fetched by the chat view after it has incorporated that
  /// page into its local history window. Keeping the notifier window in sync
  /// protects later metadata saves from treating loaded older rows as deleted.
  void commitLoadedRepositoryMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    if (!_repositoryReady || messages.isEmpty) return;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return;
    final existingIds =
        conversation.messages.map((message) => message.id).toSet();
    final older =
        messages.where((message) => !existingIds.contains(message.id)).toList();
    if (older.isEmpty) return;
    conversation.messages = [...older, ...conversation.messages];
    final signatures = _persistedMessageRecords.putIfAbsent(
      conversationId,
      () => {},
    );
    final sequences = _persistedMessageSequences[conversationId] ?? const {};
    for (final message in older) {
      final sequence = sequences[message.id];
      if (sequence == null) continue;
      signatures[message.id] = jsonEncode({
        'sequence': sequence,
        'record': message.toMap(),
      });
    }
    final currentOffset = _repositoryMessageOffsets[conversationId] ?? 0;
    _repositoryMessageOffsets[conversationId] =
        (currentOffset - older.length).clamp(0, currentOffset).toInt();
    state = List<Conversation>.from(state);
  }

  /// Commits a page fetched after the currently loaded window.
  void commitLoadedLaterRepositoryMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    if (!_repositoryReady || messages.isEmpty) return;
    final conversation =
        state.where((item) => item.id == conversationId).firstOrNull;
    if (conversation == null) return;
    final existingIds =
        conversation.messages.map((message) => message.id).toSet();
    final newer =
        messages.where((message) => !existingIds.contains(message.id)).toList();
    if (newer.isEmpty) return;
    conversation.messages = [...conversation.messages, ...newer];
    final signatures = _persistedMessageRecords.putIfAbsent(
      conversationId,
      () => {},
    );
    final sequences = _persistedMessageSequences[conversationId] ?? const {};
    for (final message in newer) {
      final sequence = sequences[message.id];
      if (sequence == null) continue;
      signatures[message.id] = jsonEncode({
        'sequence': sequence,
        'record': message.toMap(),
      });
    }
    state = List<Conversation>.from(state);
  }

  /// Loads a conversation's message history from its repository pages. This
  /// leaves list-view summaries free of message bodies until a chat is opened.
  Future<void> loadMessages(String conversationId) async {
    if (!_repositoryReady ||
        _messageLoadedConversationIds.contains(conversationId)) {
      return;
    }
    await _loadMessagesFromRepository(conversationId);
  }

  /// Loads histories into a transient search snapshot without retaining every
  /// conversation's messages in the list-view provider state.
  Future<List<Conversation>> loadConversationsForSearch() async {
    await ready;
    final snapshot = List<Conversation>.from(state);
    if (!_repositoryReady) return snapshot;
    final results = <Conversation>[];
    for (final conversation in snapshot) {
      final messages = await _readAllRepositoryMessages(conversation.id);
      results.add(
        Conversation.fromMap({
          ...conversation.toMap(),
          'messages': messages.map((message) => message.toMap()).toList(),
        }),
      );
    }
    return results;
  }

  String _conversationRecordSignature(Conversation conversation) {
    final record = ConversationRecordAdapter.fromLegacyMap(
      conversation.toMap(),
    );
    final metadata = StroomConversation(
      schemaVersion: record.schemaVersion,
      id: record.id,
      title: record.title,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      extensions: record.extensions,
      extraFields: record.extraFields,
    );
    return jsonEncode(metadata.toMap());
  }

  void _clearCompleteSnapshotGenerations(Map<String, int> generations) {
    for (final entry in generations.entries) {
      if (_completeMessageSnapshotGenerations[entry.key] == entry.value) {
        _completeMessageSnapshotGenerations.remove(entry.key);
      }
    }
  }

  Future<bool> _persistRepositorySnapshot(
    List<Conversation> snapshot,
    Map<String, int> completeSnapshots,
  ) async {
    final repository = _conversationRepository;
    if (repository == null) {
      _clearCompleteSnapshotGenerations(completeSnapshots);
      return false;
    }
    try {
      final persistedConversationRecords = Map<String, String>.from(
        _persistedConversationRecords,
      );
      final persistedMessageRecords = {
        for (final entry in _persistedMessageRecords.entries)
          entry.key: Map<String, String>.from(entry.value),
      };
      final persistedMessageSequences = {
        for (final entry in _persistedMessageSequences.entries)
          entry.key: Map<String, int>.from(entry.value),
      };
      final changes = <ConversationRepositoryChange>[];
      for (final conversation in snapshot) {
        if (!persistedConversationRecords.containsKey(conversation.id)) {
          _messageLoadedConversationIds.add(conversation.id);
          _completeMessageSnapshotGenerations[conversation.id] =
              ++_completeMessageSnapshotGeneration;
        }
        final signature = _conversationRecordSignature(conversation);
        final metadataChanged =
            persistedConversationRecords[conversation.id] != signature;
        final oldRecords = Map<String, String>.from(
          persistedMessageRecords[conversation.id] ?? const <String, String>{},
        );
        final sequences = Map<String, int>.from(
          persistedMessageSequences[conversation.id] ?? const <String, int>{},
        );
        if (completeSnapshots.containsKey(conversation.id)) {
          var offset = 0;
          while (true) {
            final rows = await repository.getMessages(
              conversation.id,
              offset: offset,
              limit: _conversationRepositoryMessagePageSize,
            );
            for (final row in rows) {
              sequences.putIfAbsent(row.id, () => row.sequence);
            }
            offset += rows.length;
            if (rows.length < _conversationRepositoryMessagePageSize) break;
          }
        }
        final cachedHighWaterMark = sequences.isEmpty
            ? -1
            : sequences.values.reduce((a, b) => a > b ? a : b);
        final repositoryHighWaterMark =
            _repositoryMessageSequenceHighWaterMarks[conversation.id] ?? -1;
        var nextSequence = (cachedHighWaterMark > repositoryHighWaterMark
                ? cachedHighWaterMark
                : repositoryHighWaterMark) +
            1;
        final currentIds = <String>{};
        final upserts = <StroomMessage>[];
        if (_messageLoadedConversationIds.contains(conversation.id)) {
          for (final message in conversation.messages) {
            currentIds.add(message.id);
            final existingSequence = sequences[message.id];
            final sequence = existingSequence ?? nextSequence++;
            sequences[message.id] = sequence;
            final messageSignature = jsonEncode({
              'sequence': sequence,
              'record': message.toMap(),
            });
            final previousSignature = oldRecords[message.id];
            // A sequence loaded by the full-context reader identifies an
            // existing row even when its full message signature was never
            // retained in memory. Preserve that row unless a loaded page has
            // a prior signature showing a real edit.
            final isNewMessage = existingSequence == null;
            if (previousSignature == messageSignature ||
                (previousSignature == null &&
                    !isNewMessage &&
                    !completeSnapshots.containsKey(conversation.id))) {
              continue;
            }
            final neutral = StroomMessage.fromLegacy(
              message,
              sequence: sequence,
            );
            upserts.add(
              StroomMessage(
                id: neutral.id,
                role: neutral.role,
                sequence: neutral.sequence,
                createdAt: neutral.createdAt,
                content: neutral.content,
                status: neutral.status,
                finishReason: neutral.finishReason,
                usage: neutral.usage,
                diagnostics: neutral.diagnostics,
                extensions: {
                  ...neutral.extensions,
                  ConversationRecordAdapter.legacyMessageNamespace: {
                    ...?neutral.extensions[ConversationRecordAdapter
                        .legacyMessageNamespace] as Map<String, dynamic>?,
                    'record':
                        ConversationRecordAdapter.legacyMessageRecordForStorage(
                      message.toMap(),
                    ),
                  },
                },
                extraFields: neutral.extraFields,
              ),
            );
            oldRecords[message.id] = messageSignature;
          }
        }
        final deletionCandidates =
            completeSnapshots.containsKey(conversation.id)
                ? sequences.keys
                : oldRecords.keys;
        final deletedIds =
            _messageLoadedConversationIds.contains(conversation.id)
                ? deletionCandidates
                    .where((id) => !currentIds.contains(id))
                    .toList()
                : const <String>[];
        for (final staleId in deletedIds) {
          oldRecords.remove(staleId);
          sequences.remove(staleId);
        }
        if (metadataChanged || upserts.isNotEmpty || deletedIds.isNotEmpty) {
          final record = ConversationRecordAdapter.fromLegacyMap(
            conversation.toMap(),
          );
          changes.add(
            ConversationRepositoryChange(
              conversation: StroomConversation(
                schemaVersion: record.schemaVersion,
                id: record.id,
                title: record.title,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                extensions: record.extensions,
                extraFields: record.extraFields,
              ),
              upsertMessages: upserts,
              deleteMessageIds: deletedIds,
            ),
          );
        }
        persistedConversationRecords[conversation.id] = signature;
        if (_messageLoadedConversationIds.contains(conversation.id)) {
          persistedMessageRecords[conversation.id] = oldRecords;
          persistedMessageSequences[conversation.id] = sequences;
        }
      }
      final currentIds =
          snapshot.map((conversation) => conversation.id).toSet();
      final deletedConversationIds = persistedConversationRecords.keys
          .where((id) => !currentIds.contains(id))
          .toList();
      final persistedChanges = <ConversationRepositoryChange>[];
      for (final change in changes) {
        final persistedMessages = <StroomMessage>[];
        for (final message in change.upsertMessages) {
          persistedMessages.add(await externalizeConversationMedia(message));
        }
        persistedChanges.add(
          ConversationRepositoryChange(
            conversation: change.conversation,
            upsertMessages: persistedMessages,
            deleteMessageIds: change.deleteMessageIds,
          ),
        );
      }
      await repository.applySnapshotChanges(
        changes: persistedChanges,
        conversationOrder:
            snapshot.map((conversation) => conversation.id).toList(),
        deleteConversationIds: deletedConversationIds,
      );
      _persistedConversationRecords
        ..clear()
        ..addAll(persistedConversationRecords);
      _persistedMessageRecords
        ..clear()
        ..addAll(persistedMessageRecords);
      _persistedMessageSequences
        ..clear()
        ..addAll(persistedMessageSequences);
      for (final entry in persistedMessageSequences.entries) {
        for (final sequence in entry.value.values) {
          final highWaterMark =
              _repositoryMessageSequenceHighWaterMarks[entry.key];
          if (highWaterMark == null || sequence > highWaterMark) {
            _repositoryMessageSequenceHighWaterMarks[entry.key] = sequence;
          }
        }
      }
      _clearCompleteSnapshotGenerations(completeSnapshots);
      for (final staleId in deletedConversationIds) {
        _persistedConversationRecords.remove(staleId);
        _persistedMessageRecords.remove(staleId);
        _persistedMessageSequences.remove(staleId);
        _repositoryMessageSequenceHighWaterMarks.remove(staleId);
        _repositoryMessageOffsets.remove(staleId);
        _repositoryMessageCounts.remove(staleId);
        _messageLoadedConversationIds.remove(staleId);
      }
      return true;
    } catch (error) {
      debugPrint('Failed to persist conversation repository rows: $error');
      await AppLogService.error('ConversationsNotifier', '持久化对话仓库记录失败', error);
      return false;
    }
  }
}
