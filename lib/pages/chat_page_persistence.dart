part of 'chat_page.dart';

/// Builds Tier A's saved conversation list without schema-round-tripping
/// unrelated records. Only understood raw diagnostic payloads are sanitized.
@visibleForTesting
List<dynamic> prepareConversationFallbackList(
  List<dynamic> decoded, {
  required String conversationId,
  required Map<String, dynamic> targetMap,
}) {
  final list = decoded.map<dynamic>((item) {
    if (item is! Map) return item;
    final preserved = Map<String, dynamic>.from(item);
    _sanitizeFallbackRawPayloads(preserved);
    return preserved;
  }).toList();

  final existingIdx = list.indexWhere(
    (item) => item is Map && item['id'] == conversationId,
  );
  final replacement = Map<String, dynamic>.from(targetMap);
  if (existingIdx >= 0) {
    final existing = list[existingIdx] as Map<String, dynamic>;
    replacement
      ..addAll(existing)
      ..['id'] = conversationId
      ..['updatedAt'] = targetMap['updatedAt']
      ..['messages'] = targetMap['messages'];
    list[existingIdx] = replacement;
  } else {
    list.insert(0, replacement);
  }
  return list;
}

void _sanitizeFallbackRawPayloads(Map<String, dynamic> conversation) {
  final messages = conversation['messages'];
  if (messages is! List) return;

  conversation['messages'] = messages.map<dynamic>((message) {
    if (message is! Map) return message;
    final preserved = Map<String, dynamic>.from(message);
    if (preserved['rawRequest'] is! Map && preserved['rawResponse'] is! Map) {
      return preserved;
    }

    try {
      final sanitized = ChatMessage.fromMap(preserved).toMap();
      for (final key in ['rawRequest', 'rawResponse']) {
        if (preserved[key] is Map && sanitized[key] is Map) {
          preserved[key] = sanitized[key];
        }
      }
    } catch (_) {
      // Preserve the original message if its raw payload cannot be understood.
    }
    return preserved;
  }).toList();
}

void _resetTemporaryExpiryOnMap(
  Map<String, dynamic> conversationMap,
  DateTime startedAt,
) {
  final conversation = Conversation.fromMap(conversationMap)
    ..isTemporary = true;
  conversation.resetTemporaryExpiry(startedAt);
  conversationMap.addAll(conversation.toMap());
}

@visibleForTesting
bool? applyTemporaryCountdownFallback(
  Map<String, dynamic> conversationMap, {
  required bool? wasTemporary,
  required bool persistedStateIsAuthoritative,
  required DateTime startedAt,
}) {
  if (wasTemporary == false) {
    conversationMap
      ..remove('isTemporary')
      ..remove('temporaryExpiresAt')
      ..remove('temporaryExpiryVersion')
      ..remove('temporaryPausedRemainingMilliseconds');
    return false;
  }

  if (wasTemporary == true) {
    if (conversationMap['isTemporary'] == true) return true;
    if (!persistedStateIsAuthoritative) {
      _resetTemporaryExpiryOnMap(conversationMap, startedAt);
      return true;
    }

    return false;
  }

  if (conversationMap['isTemporary'] == true) {
    return true;
  }

  return null;
}

void _copyTemporaryCountdownState(
  Map<String, dynamic> target,
  Map<String, dynamic> source,
) {
  for (final key in [
    'isTemporary',
    'temporaryExpiresAt',
    'temporaryExpiryVersion',
    'temporaryPausedRemainingMilliseconds',
  ]) {
    if (source.containsKey(key)) {
      target[key] = source[key];
    } else {
      target.remove(key);
    }
  }
}

extension _ChatPagePersistenceExt on _ChatPageState {
  /// Saves the currently enabled tool names to the active conversation.
  /// This ensures per-conversation tool preferences persist across sessions.
  void _saveEnabledToolsToConversation() {
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;
    final enabledTools = ref.read(enabledToolNamesProvider);
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == convId).firstOrNull;
    if (conv == null) return;
    // Keep preferences for tools temporarily hidden by an MCP ancestor. They
    // reappear with the same selection when that ancestor is enabled again.
    final entriesState = ref.read(providerEntriesProvider);
    final mcpEntry =
        entriesState.entries.where((entry) => entry.type == 'mcp').firstOrNull;
    final configuredMcpNames = mcpPlaceholderToolNamesByConfigId(
      mcpEntry?.configs ?? const <ProviderConfigItem>[],
    ).values.toSet();
    final currentTools = _adapter.getAllToolDefinitions();
    final hiddenSavedNames = conv.enabledMcpToolNames.where((name) =>
        !enabledTools.contains(name) &&
        !currentTools.any((tool) => tool.name == name) &&
        (configuredMcpNames.contains(name) ||
            kMcpSearchToolNames.contains(name)));
    final savedEnabledTools = {...enabledTools, ...hiddenSavedNames};
    // 从未配置过偏好的对话：运行时集与当前自动启用基线一致（用户没有
    // 手动偏离过）时不写入——保持"未配置"状态，MCP 总开关重新开启后
    // 下次解析会自动重新启用 MCP 工具；用户手动开关过（集合偏离基线，
    // 含全部关闭）才冻结为显式偏好。否则第一次发送就会把"当时可选择"
    // 的集合永久固化，被总开关隐藏过的 MCP 工具再也不会回来。
    if (!conv.hasExplicitEnabledMcpTools &&
        setEquals(
          enabledTools,
          _adapter.getAllToolDefinitions().map((t) => t.name).toSet(),
        )) {
      return;
    }
    // Only persist if the set actually changed to avoid unnecessary writes
    if (conv.enabledMcpToolNames.length != savedEnabledTools.length ||
        !conv.enabledMcpToolNames.containsAll(savedEnabledTools)) {
      // We need to update the conversation's enabledMcpToolNames.
      // Since Conversation is mutable, we update it in-place and let
      // the existing _persist mechanism handle the save.
      // Access the notifier to trigger persistence.
      ref
          .read(conversationsProvider.notifier)
          .updateEnabledTools(convId, savedEnabledTools);
    }
  }

  /// 保存当前 `_history` 到对话；临时计时器状态由生成生命周期单独管理。
  Future<bool> _saveMessages({
    String? capturedConvId,
    Map<String, dynamic>? capturedTemporaryState,
    List<ChatMessage>? historyOverride,
    bool requireNotifierPersistence = false,
  }) async {
    final historySnapshot = List<ChatMessage>.from(historyOverride ?? _history);
    try {
      final convId = capturedConvId ?? ref.read(activeConversationIdProvider);
      if (convId == null) return false;
      final persisted =
          await ref.read(conversationsProvider.notifier).updateMessages(
        convId,
        [...historySnapshot],
      );
      return persisted;
    } catch (e, s) {
      // Fallback: save directly to SharedPreferences if the notifier is
      // unavailable (e.g. during background streaming after page disposal).
      debugPrint('_saveMessages via notifier failed: $e\n$s');
      await AppLogService.error(
        'ChatPage',
        requireNotifierPersistence
            ? '通过 notifier 持久化消息失败'
            : '通过 notifier 保存消息失败, 尝试直接写入',
        e,
        s,
      );
      if (requireNotifierPersistence) return false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final convId = capturedConvId ?? ref.read(activeConversationIdProvider);
        if (convId == null) return false;
        var fallbackTemporaryState =
            capturedTemporaryState?['isTemporary'] == true;
        var fallbackTemporaryStateWasRead = false;
        try {
          final currentConversation = ref
              .read(conversationsProvider)
              .where((conversation) => conversation.id == convId)
              .firstOrNull;
          if (currentConversation != null) {
            fallbackTemporaryState = currentConversation.isTemporary;
            fallbackTemporaryStateWasRead = true;
          }
        } catch (_) {
          // The provider may already be disposed; retain the send-time state.
        }
        final savedAt = DateTime.now();

        // Tier A: read existing, modify the target conversation, write back.
        // Preserve raw records and sanitize only understood message payloads;
        // model round-trips can discard legacy and future schema fields.
        var tierACanFallbackToTargetOnly = true;
        try {
          final allJson = prefs.getString('conversations');
          if (allJson != null && allJson.isNotEmpty) {
            final decoded = jsonDecode(allJson);
            if (decoded is List) {
              // A decoded list is recoverable data. If preserving any value
              // later makes encoding fail, never overwrite it with Tier B's
              // target-only list.
              tierACanFallbackToTargetOnly = false;
              final targetMap = <String, dynamic>{
                'id': convId,
                'title': '',
                'createdAt': savedAt.toIso8601String(),
                'updatedAt': savedAt.toIso8601String(),
                'messages': historySnapshot.map((m) => m.toMap()).toList(),
                'isPinned': false,
                'sortOrder': 0,
                'draftText': '',
              };
              final list = prepareConversationFallbackList(
                decoded.cast<dynamic>(),
                conversationId: convId,
                targetMap: targetMap,
              );
              final savedTarget = list.firstWhere(
                (item) => item is Map && item['id'] == convId,
              ) as Map<String, dynamic>;
              if (fallbackTemporaryState == false) {
                applyTemporaryCountdownFallback(
                  savedTarget,
                  wasTemporary: false,
                  persistedStateIsAuthoritative: true,
                  startedAt: savedAt,
                );
              } else if (fallbackTemporaryStateWasRead &&
                  fallbackTemporaryState == true &&
                  savedTarget['isTemporary'] != true &&
                  capturedTemporaryState != null) {
                _copyTemporaryCountdownState(
                  savedTarget,
                  capturedTemporaryState,
                );
              }
              final json = jsonEncode(list);
              if (!await prefs.setString('conversations', json)) {
                await AppLogService.error(
                  'ChatPage',
                  '保存消息失败 (Tier A: SharedPreferences 写入返回 false)',
                );
                return false;
              }
              await AppLogService.warning(
                'ChatPage',
                '通过直接写入 SharedPreferences 成功保存消息 (Tier A)',
              );
              return true;
            }
          }
        } catch (eA, sA) {
          debugPrint('_saveMessages Tier A failed: $eA\n$sA');
          await AppLogService.error(
            'ChatPage',
            '保存消息失败 (Tier A: 修改现有对话)',
            eA,
            sA,
          );
          if (!tierACanFallbackToTargetOnly) return false;
        }

        // Tier B: existing data is missing or corrupt — overwrite with just
        // this conversation. The user's history is preserved because the
        // backup keys (conversations.corrupt.*) created by _load still
        // contain the undecodable data for manual recovery.
        try {
          final convMap = <String, dynamic>{
            'id': convId,
            'title': '',
            'createdAt': savedAt.toIso8601String(),
            'updatedAt': savedAt.toIso8601String(),
            'messages': historySnapshot.map((m) => m.toMap()).toList(),
            'isPinned': false,
            'sortOrder': 0,
            'draftText': '',
          };
          if (fallbackTemporaryState == true &&
              capturedTemporaryState != null) {
            _copyTemporaryCountdownState(convMap, capturedTemporaryState);
          }
          final json = jsonEncode([convMap]);
          if (!await prefs.setString('conversations', json)) {
            throw StateError('SharedPreferences Tier B save returned false');
          }
          await AppLogService.error(
            'ChatPage',
            '通过直接写入 SharedPreferences 成功保存消息 (Tier B - 仅当前对话)',
          );
          return true;
        } catch (eB, sB) {
          debugPrint('_saveMessages Tier B failed: $eB\n$sB');
          await AppLogService.error(
            'ChatPage',
            '保存消息失败 (Tier B: 全新写入)',
            eB,
            sB,
          );
        }
      } catch (eOuter, sOuter) {
        debugPrint('_saveMessages outer fallback failed: $eOuter\n$sOuter');
        await AppLogService.error('ChatPage', '保存消息失败 (外层兜底)', eOuter, sOuter);
      }
    }
    return false;
  }

  Future<StreamResult?> _onMessageSend(
    String text,
    List<Attachment> attachments, {
    List<ChatMessage>? historyForRequestPrefix,
    void Function(String messageId)? onUserMessageCreated,
    bool allowDuringHistoryModification = false,
  }) async {
    if (_isModifyingHistory && !allowDuringHistoryModification) return null;
    // Guard: only block sending if THIS conversation is streaming,
    // not if another conversation happens to be streaming elsewhere.
    String? convId = ref.read(activeConversationIdProvider);
    ConversationsNotifier? temporaryCountdownNotifier;
    var countdownPaused = false;
    var countdownResolved = false;
    var pendingSendReserved = false;
    if (convId != null &&
        ref.read(streamingConversationsProvider).contains(convId)) {
      return null;
    }
    // Synchronous guard: prevent double-send from rapid Enter / button taps
    // during the async gap between the guard above and the synchronous
    // _streams insertion inside manager.startStreaming.
    if (convId != null && _pendingSendConvIds.contains(convId)) return null;
    try {
      if (convId != null) {
        _pendingSendConvIds.add(convId);
        pendingSendReserved = true;
        final conversationsNotifier = ref.read(conversationsProvider.notifier);
        temporaryCountdownNotifier = conversationsNotifier;
        final temporaryConversation = ref
            .read(conversationsProvider)
            .where(
              (conversation) =>
                  conversation.id == convId && conversation.isTemporary,
            )
            .firstOrNull;
        if (temporaryConversation != null) {
          countdownPaused = true;
          await conversationsNotifier.pauseTemporaryCountdown(convId);
        }
      }
      await AppLogService.info(
        'ChatPage',
        '发送消息, convId=$convId, text长度=${text.length}, '
            'attachments=${attachments.length}',
      );
      if (convId == null) {
        await AppLogService.info('ChatPage', '无活跃对话，创建新对话');
        ref.read(conversationsProvider.notifier).createConversation();
        convId = ref.read(activeConversationIdProvider);
        await AppLogService.info('ChatPage', '新对话创建完成: $convId');
      }
      if (convId == null) return null;
      // 登记在 convId 解析**之后**（含新建对话路径）：否则无活跃对话
      // 时两次极速回车都不会被 pending 拦截，第二条消息已入库却在
      // _startStreaming 的流式守卫处被静默丢弃（孤儿消息）。
      if (!pendingSendReserved) {
        if (_pendingSendConvIds.contains(convId)) return null;
        _pendingSendConvIds.add(convId);
        pendingSendReserved = true;
      }

      final temporaryConversation = ref
          .read(conversationsProvider)
          .where(
            (conversation) =>
                conversation.id == convId && conversation.isTemporary,
          )
          .firstOrNull;
      final conversationsNotifier = ref.read(conversationsProvider.notifier);
      temporaryCountdownNotifier = conversationsNotifier;
      if (temporaryConversation != null && !countdownPaused) {
        countdownPaused = true;
        await conversationsNotifier.pauseTemporaryCountdown(convId);
      }

      // 附件归属当前对话：图片压缩磁盘缓存按（对话, 哈希）隔离存储，
      // 发送前必须登记（选中时对话可能尚未创建）。若归属发生变化
      // （切换活跃对话后发送），清除"已落盘"标记——旧对话目录下的
      // 缓存作废，发送路径会在新对话下重新落盘（零等待保证不失效）。
      for (final att in attachments) {
        if (att.conversationId != convId) {
          att.conversationId = convId;
          att.compressedCachePersisted = false;
        }
      }

      await _ensureHistoryLoaded(convId);
      if (!mounted || ref.read(activeConversationIdProvider) != convId) {
        return null;
      }

      // Save the current enabled tools to the conversation before sending.
      // This ensures the tool preferences are persisted even if the user
      // switches conversations or navigates away during streaming.
      _saveEnabledToolsToConversation();
      final activeTemporaryConversation = ref
          .read(conversationsProvider)
          .where(
            (conversation) =>
                conversation.id == convId && conversation.isTemporary,
          )
          .firstOrNull;
      final capturedTemporaryState =
          temporaryConversation == null || activeTemporaryConversation == null
              ? null
              : activeTemporaryConversation.toMap();

      final userMsgId = 'u${DateTime.now().microsecondsSinceEpoch}';

      _history.add(
        ChatMessage(
          role: 'user',
          content: text,
          id: userMsgId,
          attachments: attachments,
        ),
      );
      await _controller?.insertMessage(
        Message.text(
          id: userMsgId,
          authorId: _currentUser.id,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      onUserMessageCreated?.call(userMsgId);

      // Persist the user message before starting the background stream. If the
      // page is disposed during generation, the next page instance can load
      // this message even before the manager's periodic partial save runs.
      final historyForStream = List<ChatMessage>.from(_history);
      final requestHistory = historyForRequestPrefix == null
          ? null
          : <ChatMessage>[
              ...historyForRequestPrefix,
              historyForStream.last,
            ];
      final saveFuture = _saveMessages(
        capturedConvId: convId,
        capturedTemporaryState: capturedTemporaryState,
      );

      StreamResult? result;
      var successful = false;
      try {
        result = await _startStreaming(
          text,
          capturedConvId: convId,
          historyOverride: historyForStream,
          requestHistoryOverride: requestHistory,
          historyOnSuccess: requestHistory,
        );
        await saveFuture;
        successful = result != null &&
            !result.cancelled &&
            !result.failed &&
            result.assistantMessage?.isError != true;
      } finally {
        if (capturedTemporaryState != null) {
          countdownResolved = true;
          await conversationsNotifier.finishTemporaryCountdown(
            convId,
            successful: successful,
          );
        }
      }

      // Reload _history from conversation provider to ensure it reflects the
      // manager's persisted messages. Post-stream code in _startStreaming may
      // not execute reliably if the widget was disposed or an async error
      // occurred during background streaming.
      await _syncHistoryFromProvider(capturedConvId: convId);

      try {
        await AppLogService.info(
          'ChatPage',
          '[STREAM-SEND] _onMessageSend: after sync, _history.length=${_history.length}',
        );
      } catch (_) {}
      return result;
    } finally {
      if (countdownPaused && !countdownResolved) {
        countdownResolved = true;
        await temporaryCountdownNotifier?.finishTemporaryCountdown(
          convId!,
          successful: false,
        );
      }
      if (convId != null) _pendingSendConvIds.remove(convId);
    }
  }
}
