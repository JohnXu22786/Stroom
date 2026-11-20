part of 'conversation_provider.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

void _markTemporaryConversationUpdated(
  Conversation conversation,
  DateTime changedAt,
) {
  conversation.updatedAt = changedAt.isAfter(conversation.updatedAt)
      ? changedAt
      : conversation.updatedAt.add(const Duration(microseconds: 1));
}

extension ConversationsNotifierMutationsExt on ConversationsNotifier {
  DateTime _nextConversationCheckpointTime(Iterable<String> conversationIds) {
    var timestamp = DateTime.now();
    for (final id in conversationIds) {
      final fallbackTime = DateTime.tryParse(
        _pendingRestoredConversationSnapshots[id]?['restoredAt'] as String? ??
            '',
      );
      final previous = _conversationDeletionTimestamps[id];
      for (final candidate in [fallbackTime, previous]) {
        if (candidate != null && !timestamp.isAfter(candidate)) {
          timestamp = candidate.add(const Duration(microseconds: 1));
        }
      }
    }
    return timestamp;
  }

  List<Conversation> _restoreDeletedConversationOrder(
    List<Conversation> original,
    List<Conversation> deleted,
  ) {
    final restored = List<Conversation>.from(state);
    final deletedById = {
      for (final conversation in deleted) conversation.id: conversation,
    };
    for (var originalIndex = 0;
        originalIndex < original.length;
        originalIndex++) {
      final conversation = deletedById[original[originalIndex].id];
      if (conversation == null) continue;
      var insertionIndex = -1;
      for (var previousIndex = originalIndex - 1;
          previousIndex >= 0;
          previousIndex--) {
        final currentIndex = restored.indexWhere(
          (item) => item.id == original[previousIndex].id,
        );
        if (currentIndex >= 0) {
          insertionIndex = currentIndex + 1;
          break;
        }
      }
      if (insertionIndex < 0) {
        for (var nextIndex = originalIndex + 1;
            nextIndex < original.length;
            nextIndex++) {
          insertionIndex = restored.indexWhere(
            (item) => item.id == original[nextIndex].id,
          );
          if (insertionIndex >= 0) break;
        }
      }
      if (insertionIndex < 0) {
        insertionIndex = originalIndex.clamp(0, restored.length).toInt();
      }
      restored.insert(insertionIndex, conversation);
    }
    return pinnedFirstStable(restored);
  }

  // --------------------------------------------------------------------------
  // Mutations
  // --------------------------------------------------------------------------

  bool _markLatestAssistantMessageRead(
    Conversation? conversation, {
    bool clearManualUnread = false,
    bool skipErrors = false,
  }) {
    if (conversation == null) return false;
    var changed = false;
    if (clearManualUnread && conversation.isManuallyUnread) {
      conversation.isManuallyUnread = false;
      changed = true;
    }
    for (final message in conversation.messages.reversed) {
      if (message.role != 'assistant' || message.isStreaming) continue;
      if (message.isError) {
        if (skipErrors) continue;
        return changed;
      }
      if (conversation.lastReadMessageId == message.id) return changed;
      conversation.lastReadMessageId = message.id;
      return true;
    }
    return changed;
  }

  /// Creates a new conversation with an empty title and adds it to the list.
  ///
  /// By default the new conversation becomes the active one (the chat page
  /// opens on it). Background producers (task-flow chat blocks) pass
  /// [activate] false so the conversation is created quietly without
  /// hijacking the chat tab's active conversation.
  ///
  /// [id] explicitly pins the conversation id (used by flow-created
  /// conversations so the stream manager's per-conversation persist and the
  /// flow's cancel/cleanup paths agree on one id); when null a UUID is
  /// generated, so [Conversation.id] stays unique as usual.
  ///
  /// When [assistantId] points to an existing assistant, the NEW conversation
  /// is seeded with the assistant's conversation defaults:
  /// - [Assistant.defaultToolNames] (non-null = the user configured the
  ///   defaults tab) becomes the conversation's explicit enabled-tool set,
  ///   with [Conversation.hasExplicitEnabledMcpTools] set — so tools NOT in
  ///   the default set stay OFF instead of being auto-enabled. An assistant
  ///   whose defaults were never configured (null set) keeps the legacy
  ///   behavior (new topics auto-enable all tools). A per-conversation
  ///   override made later in the chat page persists independently and
  ///   never affects other conversations.
  /// - [Assistant.defaultModelName] is pre-recorded as the conversation's
  ///   last-used model, so the chat page restores it on first entry (and the
  ///   user's later model switches stay per-conversation).
  ///
  /// Conversations created WITHOUT an assistant keep the legacy behavior:
  /// no explicit tool prefs (chat page auto-enables all tools) and no model
  /// preset (new topics fall back to the chat page's first model in the
  /// display order).
  ///
  /// 立即持久化（_persistNow）：空对话在未发消息前被杀进程即永久丢失；
  /// _persistCore 的 _loadHasRun 守卫保证启动窗口内不覆写磁盘，
  /// _load 完成时会把内存新对话合并落盘。
  String createConversation({
    String? id,
    String? assistantId,
    bool activate = true,
  }) {
    final now = DateTime.now();
    final assistant = assistantId == null
        ? null
        : _ref
            .read(assistantProvider)
            .where((a) => a.id == assistantId)
            .firstOrNull;
    final hasToolDefaults = assistant?.defaultToolNames != null;
    final conv = Conversation(
      id: id,
      title: '',
      createdAt: now,
      updatedAt: now,
      messages: [],
      assistantId: assistantId,
      enabledMcpToolNames: hasToolDefaults
          ? Set<String>.from(assistant!.defaultToolNames!)
          : null,
      hasExplicitEnabledMcpTools: hasToolDefaults,
      lastUsedModelName: assistant?.defaultModelName,
      lastUsedModelId: assistant?.defaultModelId,
      lastUsedProviderName: assistant?.defaultProviderName,
    );
    if (activate) {
      final previousActiveId = _ref.read(activeConversationIdProvider);
      final previousActive = previousActiveId == null
          ? null
          : state.where((c) => c.id == previousActiveId).firstOrNull;
      _markLatestAssistantMessageRead(previousActive);
    }
    state = pinnedFirstStable([conv, ...state]);
    unawaited(_appendJournalBarrier({
      'kind': 'conversationCreated',
      'conversationId': conv.id,
      'createdAt': now.toIso8601String(),
    }).catchError((Object error) {
      debugPrint('Failed to record conversation creation: $error');
    }));
    if (activate) {
      _ref.read(activeConversationIdProvider.notifier).state = conv.id;
      _persistActiveId();
    }
    // 立即持久化新对话（_persistNow 而非防抖 _persist）：空对话在
    // 未发消息前被杀进程即永久丢失；防抖还会在测试/快速连续创建时
    // 留下 pending timer。
    _persistNow();
    return conv.id;
  }

  /// Deletes a conversation by [id]. If it was the active conversation, clears
  /// the active selection.
  Future<bool> deleteConversation(String id) async {
    final original = List<Conversation>.from(state);
    final deleted = state.where((c) => c.id == id).toList();
    if (deleted.isEmpty) return false;
    final deletedAt = _nextConversationCheckpointTime([id]);
    state = state.where((c) => c.id != id).toList();
    try {
      await _appendJournalBarrier({
        'kind': 'conversationDeleted',
        'conversationId': id,
        'deletedAt': deletedAt.toIso8601String(),
      });
    } catch (error) {
      if (mounted) {
        state = _restoreDeletedConversationOrder(original, deleted);
        _syncTemporaryTimer();
      }
      debugPrint('Failed to record conversation deletion: $error');
      return false;
    }
    _conversationDeletionTimestamps[id] = deletedAt;
    if (!mounted) return true;
    if (_ref.read(activeConversationIdProvider) == id) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
    }
    _syncTemporaryTimer();
    await _persist();
    await _persistActiveId();
    return true;
  }

  /// Restores conversations removed by a delete flow whose file cleanup failed.
  /// The restoration checkpoint keeps their attachment paths reachable after
  /// the deletion checkpoint has already been persisted.
  Future<void> restoreDeletedConversations(
    List<Conversation> conversations, {
    required List<Conversation> originalOrder,
    String? previousActiveConversationId,
  }) async {
    if (!mounted) {
      for (final conversation in conversations) {
        final restoredAt = _nextConversationCheckpointTime([conversation.id]);
        try {
          await _appendJournalBarrier({
            'kind': 'conversationRestored',
            'conversationId': conversation.id,
            'conversation': conversation.toMap(),
            'index': originalOrder.indexOf(conversation),
            'restoredAt': restoredAt.toIso8601String(),
          });
        } catch (error) {
          debugPrint('Failed to restore conversation checkpoint: $error');
          _pendingRestoredConversations[conversation.id] =
              '${conversation.createdAt.toIso8601String()}|${restoredAt.toIso8601String()}';
          _pendingRestoredConversationSnapshots[conversation.id] = {
            'conversation': conversation.toMap(),
            'index': originalOrder.indexOf(conversation),
            'restoredAt': restoredAt.toIso8601String(),
          };
        }
      }
      if (_pendingRestoredConversations.isNotEmpty) {
        final snapshotPersisted =
            await _persistPendingRestoredConversationSnapshots();
        if (snapshotPersisted) {
          await _persistPendingRestoredConversations();
        }
      }
      return;
    }

    final missing = conversations
        .where((conversation) =>
            !state.any((current) => current.id == conversation.id))
        .toList();
    if (missing.isEmpty) return;

    state = _restoreDeletedConversationOrder(originalOrder, missing);
    _syncTemporaryTimer();
    if (mounted &&
        previousActiveConversationId != null &&
        missing.any(
          (conversation) => conversation.id == previousActiveConversationId,
        ) &&
        _ref.read(activeConversationIdProvider) == null) {
      _ref.read(activeConversationIdProvider.notifier).state =
          previousActiveConversationId;
    }
    for (final conversation in missing) {
      final restoredAt = _nextConversationCheckpointTime([conversation.id]);
      try {
        await _appendJournalBarrier({
          'kind': 'conversationRestored',
          'conversationId': conversation.id,
          'conversation': conversation.toMap(),
          'index': originalOrder.indexOf(conversation),
          'restoredAt': restoredAt.toIso8601String(),
        });
      } catch (error) {
        debugPrint('Failed to restore conversation checkpoint: $error');
        _pendingRestoredConversations[conversation.id] =
            '${conversation.createdAt.toIso8601String()}|${restoredAt.toIso8601String()}';
        _pendingRestoredConversationSnapshots[conversation.id] = {
          'conversation': conversation.toMap(),
          'index': originalOrder.indexOf(conversation),
          'restoredAt': restoredAt.toIso8601String(),
        };
      }
    }
    if (_pendingRestoredConversations.isNotEmpty) {
      final snapshotPersisted =
          await _persistPendingRestoredConversationSnapshots();
      final markerPersisted = snapshotPersisted
          ? await _persistPendingRestoredConversations()
          : false;
      if (!markerPersisted || !snapshotPersisted) {
        debugPrint('Failed to persist restored conversation checkpoint');
      }
    }
    try {
      if (mounted && !await _persistNowChecked()) {
        debugPrint(
          'Failed to persist restored conversations after cleanup failure',
        );
      }
    } catch (error) {
      debugPrint(
        'Failed to persist restored conversations after cleanup failure: $error',
      );
    }
    if (mounted &&
        previousActiveConversationId != null &&
        missing.any(
          (conversation) => conversation.id == previousActiveConversationId,
        ) &&
        _ref.read(activeConversationIdProvider) ==
            previousActiveConversationId) {
      // The restored conversation is already durably checkpointed above.
      // Persisting this secondary selection preference should not delay the
      // caller's cleanup-failure feedback.
      unawaited(_persistActiveId());
    }
  }

  /// Replaces a flow-owned conversation from a prior attempt. Unlike the
  /// ordinary history delete, this also removes copied attachments and writes
  /// the removal immediately before a new conversation with the same ID starts.
  Future<bool> deleteFlowConversationWithFiles(String id) async {
    final original = List<Conversation>.from(state);
    final old = state.where((c) => c.id == id).toList();
    if (old.isEmpty) return true;
    state = state.where((c) => c.id != id).toList();
    _syncTemporaryTimer();
    bool saved;
    try {
      await _appendJournalBarrier({
        'kind': 'conversationDeleted',
        'conversationId': id,
        'deletedAt': DateTime.now().toIso8601String(),
      });
      saved = await _persistNowChecked();
    } catch (error) {
      debugPrint('Failed to remove flow conversation: $error');
      saved = false;
    }
    if (!saved) {
      // SharedPreferences updates its in-memory cache before calling the
      // platform store, which can still reject the write. Restore the visible
      // conversation and keep its attachment copies when disk removal fails.
      if (mounted) {
        state = _restoreDeletedConversationOrder(original, old);
        _syncTemporaryTimer();
      }
      try {
        await _appendJournalBarrier({
          'kind': 'conversationRestored',
          'conversationId': id,
        });
      } catch (error) {
        debugPrint('Failed to restore conversation checkpoint marker: $error');
        final restored = old.first;
        _pendingRestoredConversations[id] =
            '${restored.createdAt.toIso8601String()}|${DateTime.now().toIso8601String()}';
        if (!await _persistPendingRestoredConversations()) {
          debugPrint('Failed to persist restored conversation rollback marker');
        }
        try {
          if (!await _persistNowChecked()) {
            debugPrint(
              'Failed to persist restored flow conversation after checkpoint rollback',
            );
          }
        } catch (persistError) {
          debugPrint(
            'Failed to persist restored flow conversation after checkpoint rollback: $persistError',
          );
        }
      }
      return false;
    }
    if (mounted && _ref.read(activeConversationIdProvider) == id) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
      await _persistActiveId();
    }
    for (final conversation in old) {
      await _cleanupConversationFiles(conversation);
    }
    return true;
  }

  /// Selects a conversation by [id], setting it as the active one.
  void selectConversation(String id) {
    final previousId = _ref.read(activeConversationIdProvider);
    var markedRead = false;
    for (final conversation in state) {
      if (conversation.id != id && conversation.id != previousId) continue;
      markedRead = _markLatestAssistantMessageRead(
            conversation,
            clearManualUnread: conversation.id == id,
          ) ||
          markedRead;
    }
    _ref.read(activeConversationIdProvider.notifier).state = id;
    if (markedRead) {
      state = List<Conversation>.from(state);
      _persist();
    }
    _persistActiveId();
  }

  /// Toggles a conversation's explicit unread override from the topic menu.
  /// Marking read also advances the successful assistant read marker.
  void toggleConversationReadState(String id, {required bool isUnread}) {
    final conversation = state.where((item) => item.id == id).firstOrNull;
    if (conversation == null) return;
    if (isUnread) {
      _markLatestAssistantMessageRead(
        conversation,
        clearManualUnread: true,
        skipErrors: true,
      );
    } else {
      conversation.isManuallyUnread = true;
    }
    state = List<Conversation>.from(state);
    _persist();
  }

  /// Renames a conversation.
  /// 手动改名会清除自动生成标记（AI 标题不再覆盖）。
  Future<void> renameConversation(String id, String title) async {
    state = state.map((c) {
      if (c.id != id) return c;
      c.title = title;
      c.titleAutoGenerated = false;
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }

  /// 用 AI 标题助手更新标题（保持 [Conversation.titleAutoGenerated]，
  /// 对话演进后可再次自动更新；手动改名请走 [renameConversation]）。
  Future<void> updateTitle(String id, String title) async {
    state = state.map((c) {
      if (c.id != id) return c;
      c.title = title;
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }

  /// Toggles the pinned state of a conversation.
  /// Does NOT modify [updatedAt] — pinning is a metadata operation that should
  /// preserve the conversation's original last-updated time.
  ///
  /// 归一化存储：置顶/取消置顶后 state 重新满足"置顶在前"不变量。
  /// 取消置顶的对话留在原显示位置；其位置之后仍有置顶对话时，
  /// 滑到置顶块末尾（与旧版稳定显示排序的行为一致）。
  void togglePin(String id) {
    final list = state.map((c) {
      if (c.id != id) return c;
      c.isPinned = !c.isPinned;
      return c;
    }).toList();
    state = pinnedFirstStable(list);
    _persist();
  }

  /// 开启/关闭临时对话模式。
  ///
  /// 开启：从当前时刻起倒计时 [kTemporaryConversationDuration]（1 小时），
  /// 到期自动删除；关闭：清除倒计时，对话本身保留。重新开启会得到
  /// 一个全新的 1 小时窗口（倒计时的重置方式之一）。
  Future<void> toggleTemporary(String id) async {
    state = state.map((c) {
      if (c.id != id) return c;
      final turnOn = !c.isTemporary;
      c.isTemporary = turnOn;
      if (turnOn) {
        c.resetTemporaryExpiry(DateTime.now());
      } else {
        c.temporaryExpiresAt = null;
        c.temporaryPausedRemainingMilliseconds = null;
      }
      _markTemporaryConversationUpdated(c, DateTime.now());
      return c;
    }).toList();
    _syncTemporaryTimer();
    await _persist();
  }

  /// Freezes the current one-hour countdown while a reply is being generated.
  Future<void> pauseTemporaryCountdown(String id) async {
    if (!mounted) return;
    final now = DateTime.now();
    state = state.map((conversation) {
      if (conversation.id == id) {
        final wasPaused = conversation.temporaryPausedRemainingMilliseconds;
        conversation.pauseTemporaryExpiry(now);
        if (wasPaused == null &&
            conversation.temporaryPausedRemainingMilliseconds != null) {
          _markTemporaryConversationUpdated(conversation, now);
        }
      }
      return conversation;
    }).toList();
    await _persistNow();
  }

  /// Restarts the hour after a successful reply, or restores the time left
  /// before sending when generation is cancelled or fails.
  Future<void> finishTemporaryCountdown(
    String id, {
    required bool successful,
  }) async {
    if (!mounted) return;
    final now = DateTime.now();
    state = state.map((conversation) {
      if (conversation.id == id) {
        final wasPaused = conversation.temporaryPausedRemainingMilliseconds;
        conversation.resumeTemporaryExpiry(now, successful: successful);
        if (wasPaused != null) {
          _markTemporaryConversationUpdated(conversation, now);
        }
      }
      return conversation;
    }).toList();
    await _persistNow();
  }

  /// A process restart ends any in-flight generation. Continue paused
  /// conversations from their persisted remaining time after stream replay.
  @visibleForTesting
  Future<void> resumePausedTemporaryCountdownsAfterRestart() async {
    if (!mounted) return;
    if (_resumePausedTemporaryCountdowns(DateTime.now())) {
      await _persistNow();
    }
  }

  bool _resumePausedTemporaryCountdowns(DateTime resumedAt) {
    var changed = false;
    state = state.map((conversation) {
      if (conversation.isTemporary &&
          conversation.temporaryPausedRemainingMilliseconds != null) {
        conversation.resumeTemporaryExpiry(resumedAt, successful: false);
        _markTemporaryConversationUpdated(conversation, resumedAt);
        changed = true;
      }
      return conversation;
    }).toList();
    return changed;
  }

  /// Reorders a conversation from [oldIndex] to [newIndex] in the list.
  ///
  /// [newIndex] 为"移除 [oldIndex] 之后"的插入索引（与 Flutter
  /// `onReorderItem` 语义一致）。
  ///
  /// 归一化存储：拖拽跨置顶/非置顶边界时结果吸附到所在组的边界
  /// （置顶对话不能拖出置顶块、非置顶对话不能拖入置顶块），state
  /// 始终保持"置顶在前"的稳定顺序——否则会产生显示层无法表达的
  /// 隐藏交错，取消置顶/切换助手时乱序才暴露。
  void reorderConversation(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = pinnedFirstStable(list);
    _persist();
  }

  /// Deletes multiple conversations by [ids]. Also clears active if included.
  Future<bool> batchDelete(List<String> ids) async {
    final original = List<Conversation>.from(state);
    final idSet = ids.toSet();
    final deleted = state.where((c) => idSet.contains(c.id)).toList();
    if (deleted.isEmpty) return false;
    final deletedAt = _nextConversationCheckpointTime(
      deleted.map((conversation) => conversation.id),
    );
    state = state.where((c) => !idSet.contains(c.id)).toList();
    try {
      await _appendJournalBarrier({
        'kind': 'conversationsDeleted',
        'conversationIds':
            deleted.map((conversation) => conversation.id).toList(),
        'deletedAt': deletedAt.toIso8601String(),
      });
    } catch (error) {
      if (mounted) {
        state = _restoreDeletedConversationOrder(original, deleted);
        _syncTemporaryTimer();
      }
      debugPrint('Failed to record batch conversation deletion: $error');
      return false;
    }
    for (final conversation in deleted) {
      _conversationDeletionTimestamps[conversation.id] = deletedAt;
    }
    if (!mounted) return true;
    if (idSet.contains(_ref.read(activeConversationIdProvider))) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
    }
    _syncTemporaryTimer();
    await _persist();
    await _persistActiveId();
    return true;
  }

  /// Auto-generates a title for a conversation using the first messages.
  /// 生成的标题标记为自动生成（AI 标题助手可覆盖）。
  Future<void> autoRenameConversation(String id) async {
    final conv = state.where((c) => c.id == id).firstOrNull;
    if (conv == null || conv.messages.isEmpty) return;

    final firstUser = conv.messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => conv.messages.first,
    );
    final firstAssistant =
        conv.messages.where((m) => m.role == 'assistant').firstOrNull;

    String combined = firstUser.content.trim().isNotEmpty
        ? firstUser.content
        : firstUser.attachments.firstOrNull?.fileName ?? '';
    if (firstAssistant != null) {
      combined += ' - ${firstAssistant.content}';
    }
    final title =
        combined.length > 60 ? '${combined.substring(0, 60)}…' : combined;

    state = state.map((c) {
      if (c.id != id) return c;
      c.title = title;
      c.titleAutoGenerated = true;
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }

  /// Replaces the message list of a conversation (e.g. after sending or
  /// loading a different conversation).
  ///
  Future<bool> updateMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    if (!mounted) return false;
    var current = state.where((c) => c.id == conversationId).firstOrNull;
    if (current != null) {
      List<String> removedMessageIds() {
        final nextIds = messages.map((message) => message.id).toSet();
        return current!.messages
            .where((message) => !nextIds.contains(message.id))
            .map((message) => message.id)
            .toList();
      }

      final allRemovedIds = removedMessageIds();
      final removedIds = allRemovedIds
          .where((id) => _hasStreamCheckpoint(conversationId, id))
          .toList();
      if (!_streamCheckpointKeyIndexIsCurrent) {
        final uncertainIds =
            allRemovedIds.where((id) => !removedIds.contains(id)).toList();
        if (uncertainIds.isNotEmpty) {
          _pendingUnindexedMessageDeletionIds
              .putIfAbsent(conversationId, () => <String>{})
              .addAll(uncertainIds);
        }
      }
      final supersededRestorations =
          (_pendingMessageRestorationIds[conversationId] ?? <String>{})
              .intersection(removedIds.toSet());

      final previousMessages = List<ChatMessage>.from(current.messages);
      _replaceMessages(conversationId, messages);
      if (removedIds.isNotEmpty) {
        _addPendingMessageDeletions(conversationId, removedIds);
        try {
          await _appendJournalBarrier({
            'kind': 'messageDeleted',
            'conversationId': conversationId,
            'messageIds': removedIds,
          });
          final latestIds = state
              .where((conversation) => conversation.id == conversationId)
              .expand((conversation) => conversation.messages)
              .map((message) => message.id)
              .toSet();
          final restoredDuringDelete =
              removedIds.where(latestIds.contains).toList();
          if (restoredDuringDelete.isNotEmpty) {
            await _appendMessageRestorations(
              conversationId,
              restoredDuringDelete,
            );
          }
          final restorationsToClear =
              supersededRestorations.difference(restoredDuringDelete.toSet());
          if (restorationsToClear.isNotEmpty) {
            _removePendingMessageRestorations(
              conversationId,
              restorationsToClear,
            );
            if (!await _persistPendingRestoredMessages()) {
              _addPendingMessageRestorations(
                conversationId,
                restorationsToClear,
              );
              throw StateError(
                'Failed to persist message deletion after restore',
              );
            }
          }
          _removePendingMessageDeletions(conversationId, removedIds);
        } catch (_) {
          final latest = state.where((c) => c.id == conversationId).firstOrNull;
          if (mounted &&
              latest != null &&
              identical(latest.messages, messages) &&
              (_pendingMessageDeletionIds[conversationId]
                      ?.containsAll(removedIds) ??
                  false)) {
            _replaceMessages(conversationId, previousMessages);
            try {
              await _appendMessageRestorations(conversationId, removedIds);
            } catch (restoreError) {
              debugPrint(
                'Failed to persist message deletion rollback: $restoreError',
              );
            }
          } else if (mounted && latest != null) {
            final latestIds =
                latest.messages.map((message) => message.id).toSet();
            final restoredIds = removedIds
                .where((messageId) => latestIds.contains(messageId))
                .toList();
            if (restoredIds.isNotEmpty) {
              try {
                await _appendMessageRestorations(conversationId, restoredIds);
              } catch (restoreError) {
                debugPrint(
                  'Failed to persist concurrent message restoration: '
                  '$restoreError',
                );
              }
            }
          }
          rethrow;
        }
      }
    } else {
      _replaceMessages(conversationId, messages);
    }
    if (!mounted) return false;
    return _persistNowChecked();
  }

  /// Restores history after a failed destructive operation and records a
  /// tombstone cancellation for any checkpointed messages in [restoredIds].
  Future<bool> restoreMessagesChecked(
    String conversationId,
    List<ChatMessage> messages, {
    required Iterable<String> restoredIds,
  }) async {
    if (!mounted ||
        !state.any((conversation) => conversation.id == conversationId)) {
      return false;
    }
    if (!await updateMessages(conversationId, messages)) return false;
    try {
      await _appendMessageRestorations(conversationId, restoredIds);
    } catch (error) {
      debugPrint('Failed to record restored message history: $error');
      return false;
    }
    return _persistNowChecked();
  }

  /// Queues a supersedable periodic stream checkpoint journal entry.
  /// Consecutive checkpoints share one queued persistence task; explicit
  /// writes remain ordering barriers in the normal persistence path.
  Future<void> updateMessagesPeriodically(
    String conversationId, {
    required Map<String, dynamic> checkpoint,
  }) async {
    if (!state.any((conversation) => conversation.id == conversationId)) {
      return;
    }
    final checkpointTime = DateTime.now();
    DateTime? checkpointUpdatedAt;
    state = state.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      _markTemporaryConversationUpdated(conversation, checkpointTime);
      checkpointUpdatedAt = conversation.updatedAt;
      return conversation;
    }).toList();
    final conversation = state
        .where((conversation) => conversation.id == conversationId)
        .firstOrNull;
    if (conversation != null) {
      checkpoint['updatedAt'] = checkpointUpdatedAt!.toIso8601String();
      checkpoint['conversationCreatedAt'] =
          conversation.createdAt.toIso8601String();
      checkpoint['isTemporary'] = conversation.isTemporary;
      checkpoint['temporaryExpiresAt'] =
          conversation.temporaryExpiresAt?.toIso8601String();
      checkpoint['temporaryExpiryVersion'] =
          conversation.temporaryExpiryVersion;
      checkpoint['temporaryPausedRemainingMilliseconds'] =
          conversation.temporaryPausedRemainingMilliseconds;
      if (checkpoint['baseSnapshotPending'] == true) {
        checkpoint['baseConversation'] = conversation.toMap();
      }
    }
    await _persistStreamCheckpoint(checkpoint);
  }

  /// Confirm flow messages reached disk before sending or completing a step.
  Future<bool> updateFlowMessagesChecked(
      String conversationId, List<ChatMessage> messages) async {
    if (!mounted || !state.any((c) => c.id == conversationId)) return false;
    _replaceMessages(conversationId, messages);
    return _persistNowChecked();
  }

  void _replaceMessages(String conversationId, List<ChatMessage> messages) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.messages = messages;
      c.updatedAt = DateTime.now();
      // Derive title from the conversation overview if title is empty.
      if (c.title.isEmpty && messages.isNotEmpty) {
        final firstUser = messages.firstWhere(
          (m) => m.role == 'user',
          orElse: () => messages.first,
        );
        final firstAssistant =
            messages.where((m) => m.role == 'assistant').firstOrNull;

        String combined = firstUser.content.trim().isNotEmpty
            ? firstUser.content
            : firstUser.attachments.firstOrNull?.fileName ?? '';
        if (firstAssistant != null) {
          combined += ' - ${firstAssistant.content}';
        }
        c.title =
            combined.length > 60 ? '${combined.substring(0, 60)}…' : combined;
        // 标记为自动生成：流完成后由标题助手用 AI 标题覆盖
        c.titleAutoGenerated = true;
      }
      return c;
    }).toList();
  }

  /// Saves the draft (text + unsent attachment snapshots) for a specific
  /// conversation.
  ///
  /// Drafts are per-conversation and persisted along with the conversation
  /// data. When [draftText] is empty and [draftAttachments] is empty, the
  /// draft is cleared.
  void queueDraftAttachmentFileDelete(String storagePath) {
    _pendingDraftAttachmentFileDeletes.add(storagePath);
  }

  void queueDraftAttachmentCacheDelete({
    required String? conversationId,
    required String hash,
    Future<void>? waitFor,
  }) {
    final key = (conversationId: conversationId, hash: hash);
    if (waitFor == null) {
      _pendingDraftAttachmentCacheDeletes.putIfAbsent(
        key,
        Future<void>.value,
      );
      return;
    }

    final previous = _pendingDraftAttachmentCacheDeletes[key];
    _pendingDraftAttachmentCacheDeletes[key] = previous == null
        ? waitFor
        : Future.wait([previous, waitFor]).then((_) {});
  }

  void cancelDraftAttachmentCacheDelete({
    required String conversationId,
    required String hash,
  }) {
    _pendingDraftAttachmentCacheDeletes.remove(
      (conversationId: conversationId, hash: hash),
    );
  }

  void saveDraft(
    String conversationId,
    String draftText, {
    List<Attachment>? draftAttachments,
  }) {
    _updateDraft(conversationId, draftText, draftAttachments);
    _persist();
  }

  /// Saves a draft and waits for the updated conversation snapshot to reach
  /// storage before callers clean up files removed from the draft.
  Future<bool> saveDraftAndWait(
    String conversationId,
    String draftText, {
    List<Attachment>? draftAttachments,
  }) {
    _updateDraft(conversationId, draftText, draftAttachments);
    return _persistNowChecked();
  }

  /// Persist a current snapshot so queued attachment cleanup can safely run
  /// even when the composer has no draft to update (for example in edit mode).
  Future<bool> persistSnapshotForAttachmentCleanup() => _persistNowChecked();

  void _updateDraft(
    String conversationId,
    String draftText,
    List<Attachment>? draftAttachments,
  ) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.draftText = draftText;
      if (draftAttachments != null) {
        // composer 传入的是快照副本（toMap/fromMap 深拷贝），与
        // pending 列表无引用共享——后续预压缩/编辑不会污染草稿。
        c.draftAttachments = draftAttachments;
      }
      return c;
    }).toList();
  }

  /// Updates the enabled MCP/built-in tool names for a conversation.
  /// These are the tools the user has turned ON for this specific conversation.
  /// Also marks the conversation as having an explicit tool selection so the
  /// chat page won't auto-enable all tools on next load (preserves the
  /// "user toggled every tool off" case).
  void updateEnabledTools(String conversationId, Set<String> enabledTools) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.enabledMcpToolNames = Set<String>.from(enabledTools);
      c.hasExplicitEnabledMcpTools = true;
      return c;
    }).toList();
    _persist();
  }

  /// Updates the last used model for a conversation.
  /// This is used to restore the model when re-entering the conversation.
  ///
  /// [modelName] 是显示名（用于兼容旧数据与显示），[modelId] 是 API 模型
  /// ID、[providerName] 是供应商名——两者构成绝对身份，模型/供应商被
  /// 重命名后该对话记录仍能解析回同一模型。
  void updateLastUsedModel(
    String conversationId,
    String modelName, {
    String? modelId,
    String? providerName,
  }) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.lastUsedModelName = modelName;
      c.lastUsedModelId = modelId;
      c.lastUsedProviderName = providerName;
      return c;
    }).toList();
    _persist();
  }

  /// 更新对话的实际 token 计量与累计花费。
  ///
  /// [inputTokens]/[outputTokens] 来自 API 返回的 usage（非估算）；
  /// [costIncrement] 为 API usage 快照相对上次快照的花费差额（如
  /// OpenRouter usage.total_cost）；可能为负，用于应用后续修正。
  Future<void> updateUsage({
    required String conversationId,
    int? inputTokens,
    int? outputTokens,
    double costIncrement = 0,
  }) async {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      if (inputTokens != null) c.lastInputTokens = inputTokens;
      if (outputTokens != null) c.lastOutputTokens = outputTokens;
      if (costIncrement != 0) {
        c.totalCost = (c.totalCost + costIncrement)
            .clamp(0.0, double.infinity)
            .toDouble();
      }
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }

  /// Updates the context compaction summary for a conversation.
  Future<void> updateContextSummary(String conversationId, String summary,
      {String? tailStartId}) async {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.contextSummary = summary;
      // 记录尾部起点消息 ID（prune 边界，对齐 opencode tail_start_id）
      if (tailStartId != null) c.compactionTailStartId = tailStartId;
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }
}
