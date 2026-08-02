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

extension _ConversationsNotifierPersistenceExt on ConversationsNotifier {
  // --------------------------------------------------------------------------
  // Persistence
  // --------------------------------------------------------------------------

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('conversations');
      if (json != null && json.isNotEmpty) {
        try {
          final decoded = jsonDecode(json);
          if (decoded is List) {
            final conversations = <Conversation>[];
            for (final item in decoded) {
              if (item is Map) {
                try {
                  conversations.add(
                      Conversation.fromMap(Map<String, dynamic>.from(item)));
                } catch (e) {
                  debugPrint('ConversationsNotifier: 跳过损坏的对话条目: $e');
                  await AppLogService.warning(
                      'ConversationsNotifier', '跳过损坏的对话条目: $e');
                }
              }
            }
            if (mounted) {
              // 竞态防护：_load 的 await 窗口内用户可能已创建对话
              // （createConversation 只改内存态，磁盘无记录）——
              // 磁盘加载结果与内存合并：磁盘对话为准，内存中磁盘
              // 没有的新对话保留，避免新对话被静默覆盖丢失。
              final inMemory = state;
              if (inMemory.isNotEmpty) {
                final diskIds = conversations.map((c) => c.id).toSet();
                final extra =
                    inMemory.where((c) => !diskIds.contains(c.id)).toList();
                state = [...conversations, ...extra];
              } else {
                state = conversations;
              }
            }
            await AppLogService.info(
                'ConversationsNotifier', '加载了 ${conversations.length} 个对话');
          } else {
            // 磁盘数据无效：内存已有对话（用户刚创建）时保留内存
            if (mounted && state.isEmpty) state = [];
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
        }
      } else {
        // 无已保存数据：内存已有对话时保留内存
        if (mounted && state.isEmpty) state = [];
        await AppLogService.info('ConversationsNotifier', '没有已保存的对话');
      }

      // Auto-fix conversations with null assistantId on every load.
      // This is more reliable than the old one-time migration flag:
      // it catches conversations that were created without assistantId
      // even after the old migration had already "run".
      try {
        if (mounted) {
          await assignNullAssistantConversations(prefs, state);
          // 修复函数可能原位修改了 state 列表：重新赋值以触发
          // 监听者刷新（await 期间 notifier 可能被 dispose，需重查）。
          if (mounted) {
            state = List<Conversation>.from(state);
          }
        }
      } catch (e) {
        debugPrint('Failed to auto-fix null assistant conversations: $e');
        await AppLogService.error(
            'ConversationsNotifier', '修复空 assistantId 失败', e);
      }

      // Restore last active conversation
      try {
        if (mounted) {
          final activeId = prefs.getString('active_conversation_id');
          if (activeId != null && state.any((c) => c.id == activeId)) {
            _ref.read(activeConversationIdProvider.notifier).state = activeId;
            await AppLogService.info(
                'ConversationsNotifier', '恢复上次活跃对话: $activeId');
          } else {
            await AppLogService.warning('ConversationsNotifier',
                '未找到上次活跃对话或 activeId 为 null: activeId=$activeId');
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
    }
  }

  /// Move a corrupt conversations JSON blob to a timestamped backup key so
  /// the user can inspect it later and we don't overwrite it on the next save.
  ///
  /// This is called when `jsonDecode` throws on the on-disk JSON. The previous
  /// behavior was to silently throw away the data; this preserves the
  /// undecodable payload in case the user wants to recover it manually.

  Future<void> _backupCorruptConversationsFile(
      SharedPreferences prefs, String corruptJson) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupKey = 'conversations.corrupt.$timestamp';
      await prefs.setString(backupKey, corruptJson);
      // Also clear the original key so the next save starts fresh instead of
      // repeatedly trying to decode the same corrupt blob.
      await prefs.remove('conversations');
      debugPrint(
          'ConversationsNotifier: backed up corrupt conversations to $backupKey');
      await AppLogService.warning(
          'ConversationsNotifier', '检测到损坏的对话数据，已备份到 $backupKey，原始数据已清空');

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
            'ConversationsNotifier: removed old corrupt backup $oldest (cap=$_maxCorruptBackups)');
      }
    } catch (e) {
      debugPrint('Failed to back up corrupt conversations: $e');
    }
  }

  Future<void> _persistActiveId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeId = _ref.read(activeConversationIdProvider);
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
    final List<Conversation> snapshot;
    try {
      snapshot = List<Conversation>.from(state);
    } catch (_) {
      // Notifier was already disposed before we could snapshot. Nothing we
      // can do — the previous good save is still on disk.
      return;
    }
    if (snapshot.isEmpty && !_loadHasRun) return;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Failed to get SharedPreferences: $e');
      return;
    }

    // Tier 1: full save
    try {
      final json = jsonEncode(snapshot.map((e) => e.toMap()).toList());
      await prefs.setString('conversations', json);
      await AppLogService.debug(
          'ConversationsNotifier', '对话已持久化, 共 ${snapshot.length} 个');
      return;
    } catch (e) {
      debugPrint('Failed to persist conversations (full): $e');
      await AppLogService.error('ConversationsNotifier', '持久化对话失败 (完整)', e);
    }

    // Tier 2: drop rawRequest/rawResponse from every message.
    try {
      final stripped = snapshot
          .map((c) => Conversation(
                id: c.id,
                title: c.title,
                createdAt: c.createdAt,
                updatedAt: c.updatedAt,
                messages: c.messages
                    .map((m) => ChatMessage(
                          id: m.id,
                          role: m.role,
                          content: m.content,
                          createdAt: m.createdAt,
                          attachments: m.attachments,
                          isStreaming: m.isStreaming,
                          isError: m.isError,
                          reasoningContent: m.reasoningContent,
                          toolCalls: m.toolCalls,
                          reasoningSections: m.reasoningSections,
                          textSections: m.textSections,
                          toolCallRoundStarts: m.toolCallRoundStarts,
                          blocks: m.blocks,
                          // Tier 2 的目的就是剥离 rawRequest/rawResponse
                          // （通常含大体积 base64，Tier 1 全量保存失败的
                          // 原因）：这里必须传 null，否则与 Tier 1 相同
                          // 的内容会再次失败，兜底层形同虚设。
                          rawRequest: null,
                          rawResponse: null,
                        ))
                    .toList(),
                isPinned: c.isPinned,
                sortOrder: c.sortOrder,
                assistantId: c.assistantId,
                draftText: c.draftText,
                enabledMcpToolNames: c.enabledMcpToolNames,
                hasExplicitEnabledMcpTools: c.hasExplicitEnabledMcpTools,
                contextSummary: c.contextSummary,
                compactionTailStartId: c.compactionTailStartId,
                titleAutoGenerated: c.titleAutoGenerated,
                lastUsedModelName: c.lastUsedModelName,
                lastInputTokens: c.lastInputTokens,
                lastOutputTokens: c.lastOutputTokens,
                totalCost: c.totalCost,
              ))
          .toList();
      final json = jsonEncode(stripped.map((e) => e.toMap()).toList());
      await prefs.setString('conversations', json);
      await AppLogService.warning(
          'ConversationsNotifier', '持久化对话成功 (剥离 rawRequest/rawResponse 后)');
    } catch (e) {
      debugPrint('Failed to persist conversations (stripped): $e');
      await AppLogService.error('ConversationsNotifier', '持久化对话失败 (剥离后)', e);
      // Both tiers failed. The previous good save on disk is preserved
      // (we never overwrote it). Log loudly so the user can find the cause.
    }
  }
}
