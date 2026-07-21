import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/assistant.dart';
import '../models/chat_message.dart';
import '../services/app_log_service.dart';
import 'assistant_provider.dart';

// ============================================================================
// Helper: auto-fix conversations with null assistantId
// ============================================================================

/// Ensures all conversations have an assigned assistantId.
///
/// On every load, any conversation with a null assistantId is assigned to the
/// default assistant. This replaces the old one-time migration flag approach
/// which failed if new null-assistantId conversations were created after the
/// migration flag was set, or if the default assistant wasn't persisted yet.
///
/// Returns true if any conversations were modified.
Future<bool> assignNullAssistantConversations(
    SharedPreferences prefs, List<Conversation> conversations) async {
  try {
    // Check if any conversation has null assistantId
    final hasNull = conversations.any((c) => c.assistantId == null);
    if (!hasNull) return false;

    // Resolve the default assistant ID
    final defaultId = await _resolveDefaultAssistantId(prefs);
    if (defaultId == null) return false;

    // Assign the default ID to all null-assistantId conversations
    bool changed = false;
    for (final conv in conversations) {
      if (conv.assistantId == null) {
        conv.assistantId = defaultId;
        changed = true;
      }
    }

    // Persist the fix
    if (changed) {
      await prefs.setString('conversations',
          jsonEncode(conversations.map((e) => e.toMap()).toList()));
      debugPrint(
          'Auto-assigned null-assistantId conversations to default assistant ($defaultId)');
    }

    return changed;
  } catch (e) {
    debugPrint('Failed to auto-assign null-assistantId conversations: $e');
    return false;
  }
}

/// Resolves the default assistant ID from in-memory state or SharedPreferences.
///
/// Tries in order:
/// 1. The first assistant from [assistantProvider] (in-memory, if initialized)
/// 2. The first assistant from SharedPreferences
/// 3. Creates a new default assistant and persists it
Future<String?> _resolveDefaultAssistantId(SharedPreferences prefs) async {
  // Try from SharedPreferences first (safe across provider boundaries)
  final assistantsJson = prefs.getString('assistants');
  if (assistantsJson != null && assistantsJson.isNotEmpty) {
    final list =
        (jsonDecode(assistantsJson) as List).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) {
      return list.first['id'] as String;
    }
  }

  // No assistants exist yet - create a default one
  final defaultAssistant = Assistant(
    name: '默认助手',
    prompt: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
    emoji: '🤖',
  );
  await prefs.setString('assistants', jsonEncode([defaultAssistant.toMap()]));
  debugPrint(
      'Created default assistant during migration (${defaultAssistant.id})');
  return defaultAssistant.id;
}

// ============================================================================
// Conversation model
// ============================================================================

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ChatMessage> messages;
  bool isPinned;
  int sortOrder;
  String? assistantId;
  String draftText;

  /// Per-conversation set of MCP/built-in tool names that the user has enabled.
  /// Defaults to empty (interpreted by the chat page as "auto-enable all
  /// available tools" for new conversations; explicit empty is preserved
  /// via [hasExplicitEnabledMcpTools]).
  Set<String> enabledMcpToolNames = {};

  /// Whether the user has explicitly touched the MCP/built-in tool toggles
  /// in the "可用工具" panel for this conversation. Used to distinguish
  /// "new conversation — auto-enable all" (false) from "user toggled every
  /// tool off" (true). Persisted as a boolean flag so an explicit-empty
  /// set survives serialization.
  bool hasExplicitEnabledMcpTools = false;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.isPinned = false,
    this.sortOrder = 0,
    this.assistantId,
    this.draftText = '',
    Set<String>? enabledMcpToolNames,
    this.hasExplicitEnabledMcpTools = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [],
        enabledMcpToolNames = enabledMcpToolNames ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': isPinned,
        'sortOrder': sortOrder,
        if (assistantId != null) 'assistantId': assistantId,
        'draftText': draftText,
        // Persist the explicit-empty flag so a user who toggled every tool
        // off doesn't accidentally get them all re-enabled next time.
        if (hasExplicitEnabledMcpTools) 'hasExplicitEnabledMcpTools': true,
        // Persist the set whenever the user has explicitly touched the toggles,
        // even if it's empty. Otherwise omit it so new conversations fall back
        // to the "auto-enable all" default.
        if (hasExplicitEnabledMcpTools)
          'enabledMcpToolNames': enabledMcpToolNames.toList(),
      };

  factory Conversation.fromMap(Map<String, dynamic> map) {
    // Defensive DateTime parsing for createdAt
    DateTime? createdAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw != null && createdAtRaw is String) {
      try {
        createdAt = DateTime.parse(createdAtRaw);
      } catch (_) {
        createdAt = DateTime.now();
      }
    }

    // Defensive DateTime parsing for updatedAt
    DateTime? updatedAt;
    final updatedAtRaw = map['updatedAt'];
    if (updatedAtRaw != null && updatedAtRaw is String) {
      try {
        updatedAt = DateTime.parse(updatedAtRaw);
      } catch (_) {
        updatedAt = DateTime.now();
      }
    }

    // Defensive message parsing: skip invalid entries so a single corrupt
    // message does not prevent loading the entire conversation.
    List<ChatMessage> messages = [];
    final messagesRaw = map['messages'];
    if (messagesRaw is List) {
      for (final e in messagesRaw) {
        if (e is Map) {
          try {
            messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(e)));
          } catch (_) {
            // Skip corrupt message — log is optional to avoid noise
          }
        }
      }
    }

    // Defensive enabledMcpToolNames parsing
    Set<String> enabledMcpToolNames = {};
    final toolsRaw = map['enabledMcpToolNames'];
    if (toolsRaw is List) {
      enabledMcpToolNames = toolsRaw.map((e) => e.toString()).toSet();
    }
    // hasExplicitEnabledMcpTools is true if the user has touched the toggles
    // for this conversation. Defaults to false (new conversation → auto-enable
    // all available tools). Persisted explicitly so an empty
    // enabledMcpToolNames set survives serialization.
    final hasExplicit = map['hasExplicitEnabledMcpTools'] as bool? ?? false;

    return Conversation(
      id: map['id'] as String?,
      title: map['title'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: messages,
      isPinned: map['isPinned'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
      assistantId: map['assistantId'] as String?,
      draftText: map['draftText'] as String? ?? '',
      enabledMcpToolNames: enabledMcpToolNames,
      hasExplicitEnabledMcpTools: hasExplicit,
    );
  }

  @override
  String toString() => 'Conversation(id: $id, title: $title)';
}

// ============================================================================
// Providers
// ============================================================================

/// ID of the currently active conversation, or null if none is selected.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

final conversationSearchQueryProvider = StateProvider<String>((ref) => '');

/// Persistent list of all conversations.
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>((ref) {
  final notifier = ConversationsNotifier(ref);
  notifier._load();
  return notifier;
});

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final Ref _ref;

  ConversationsNotifier(this._ref) : super([]);

  Timer? _persistTimer;

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
            if (mounted) state = conversations;
            await AppLogService.info(
                'ConversationsNotifier', '加载了 ${conversations.length} 个对话');
          } else {
            if (mounted) state = [];
            await AppLogService.info('ConversationsNotifier', '对话数据格式无效');
          }
        } catch (e) {
          debugPrint('Failed to decode conversations JSON: $e');
          await AppLogService.error('ConversationsNotifier', '解析对话 JSON 失败', e);
          // Back up the corrupt file so the user can manually recover it
          // and we don't silently overwrite it on the next save.
          await _backupCorruptConversationsFile(prefs, json);
          if (mounted) state = [];
        }
      } else {
        if (mounted) state = [];
        await AppLogService.info('ConversationsNotifier', '没有已保存的对话');
      }

      // Auto-fix conversations with null assistantId on every load.
      // This is more reliable than the old one-time migration flag:
      // it catches conversations that were created without assistantId
      // even after the old migration had already "run".
      try {
        if (mounted) {
          await assignNullAssistantConversations(prefs, state);
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
  ///
  /// **Bounded retention**: keeps at most [_maxCorruptBackups] backups. When
  /// the cap is exceeded, the oldest backup is deleted. This prevents
  /// SharedPreferences from growing without bound on devices that
  /// repeatedly hit decode failures.
  static const int _maxCorruptBackups = 3;

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
                        ))
                    .toList(),
                isPinned: c.isPinned,
                sortOrder: c.sortOrder,
                assistantId: c.assistantId,
                draftText: c.draftText,
                enabledMcpToolNames: c.enabledMcpToolNames,
                hasExplicitEnabledMcpTools: c.hasExplicitEnabledMcpTools,
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

  /// Whether the initial async _load has completed at least once.
  /// Used to skip a no-op persist triggered before any data has loaded.
  bool _loadHasRun = false;

  @override
  void dispose() {
    _persistNow();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Mutations
  // --------------------------------------------------------------------------

  /// Creates a new conversation with an empty title, adds it to the list,
  /// and sets it as the active conversation.
  ///
  /// 不在此处持久化（避免与后续 updateMessages 的持久化竞争），
  /// 由 chat_provider 的 listener 负责持久化带消息的状态。
  String createConversation({String? assistantId}) {
    final now = DateTime.now();
    final conv = Conversation(
      title: '',
      createdAt: now,
      updatedAt: now,
      messages: [],
      assistantId: assistantId,
    );
    state = [conv, ...state];
    _ref.read(activeConversationIdProvider.notifier).state = conv.id;
    _persistActiveId();
    return conv.id;
  }

  /// Deletes a conversation by [id]. If it was the active conversation, clears
  /// the active selection.
  Future<void> deleteConversation(String id) async {
    state = state.where((c) => c.id != id).toList();
    if (_ref.read(activeConversationIdProvider) == id) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
    }
    await _persist();
    await _persistActiveId();
  }

  /// Selects a conversation by [id], setting it as the active one.
  void selectConversation(String id) {
    _ref.read(activeConversationIdProvider.notifier).state = id;
    _persistActiveId();
  }

  /// Renames a conversation.
  Future<void> renameConversation(String id, String title) async {
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
  void togglePin(String id) {
    state = state.map((c) {
      if (c.id != id) return c;
      c.isPinned = !c.isPinned;
      return c;
    }).toList();
    _persist();
  }

  /// Reorders a conversation from [oldIndex] to [newIndex] in the list.
  void reorderConversation(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _persist();
  }

  /// Deletes multiple conversations by [ids]. Also clears active if included.
  Future<void> batchDelete(List<String> ids) async {
    final idSet = ids.toSet();
    state = state.where((c) => !idSet.contains(c.id)).toList();
    if (idSet.contains(_ref.read(activeConversationIdProvider))) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
    }
    await _persist();
    await _persistActiveId();
  }

  /// Auto-generates a title for a conversation using the first messages.
  Future<void> autoRenameConversation(String id) async {
    final conv = state.where((c) => c.id == id).firstOrNull;
    if (conv == null || conv.messages.isEmpty) return;

    final firstUser = conv.messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => conv.messages.first,
    );
    final firstAssistant =
        conv.messages.where((m) => m.role == 'assistant').firstOrNull;

    String combined = firstUser.content;
    if (firstAssistant != null) {
      combined += ' - ${firstAssistant.content}';
    }
    final title =
        combined.length > 60 ? '${combined.substring(0, 60)}…' : combined;

    state = state.map((c) {
      if (c.id != id) return c;
      c.title = title;
      c.updatedAt = DateTime.now();
      return c;
    }).toList();
    await _persist();
  }

  /// Replaces the message list of a conversation (e.g. after sending or
  /// loading a different conversation).
  Future<void> updateMessages(
      String conversationId, List<ChatMessage> messages) async {
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

        String combined = firstUser.content;
        if (firstAssistant != null) {
          combined += ' - ${firstAssistant.content}';
        }
        c.title =
            combined.length > 60 ? '${combined.substring(0, 60)}…' : combined;
      }
      return c;
    }).toList();
    await _persist();
  }

  /// Saves the draft text for a specific conversation.
  ///
  /// Drafts are per-conversation and persisted along with the conversation
  /// data. When [draftText] is empty, the draft is cleared.
  void saveDraft(String conversationId, String draftText) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.draftText = draftText;
      return c;
    }).toList();
    _persist();
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
}

// ============================================================================
// Legacy: one-time conversation migration (left for test compatibility)
// ============================================================================

/// One-time migration that assigns [assistantId] to all conversations
/// lacking one, guarded by a [migrated_old_conversations] flag.
///
/// Returns the migrated conversation list, or `null` if already done.
Future<List<Conversation>?> migrateConversationsFromPrefs(
    SharedPreferences prefs) async {
  try {
    if (prefs.getBool('migrated_old_conversations') == true) return null;

    final assistantsJson = prefs.getString('assistants');
    if (assistantsJson == null || assistantsJson.isEmpty) {
      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
        emoji: '🤖',
      );
      await prefs.setString(
          'assistants', jsonEncode([defaultAssistant.toMap()]));
    }

    final refreshedJson = prefs.getString('assistants');
    if (refreshedJson == null || refreshedJson.isEmpty) return null;
    final tempList = jsonDecode(refreshedJson);
    if (tempList is! List) return null;
    final assistants = tempList.cast<Map<String, dynamic>>();
    if (assistants.isEmpty) return null;
    final defaultId = assistants.first['id'];
    if (defaultId is! String) return null;

    final conversationsJson = prefs.getString('conversations');
    if (conversationsJson == null || conversationsJson.isEmpty) return null;

    final tempConv = jsonDecode(conversationsJson);
    if (tempConv is! List) return null;
    final conversations = tempConv.cast<Map<String, dynamic>>();

    bool changed = false;
    for (final conv in conversations) {
      if (conv['assistantId'] == null) {
        conv['assistantId'] = defaultId;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString('conversations', jsonEncode(conversations));
    }

    await prefs.setBool('migrated_old_conversations', true);

    return conversations.map((e) => Conversation.fromMap(e)).toList();
  } catch (e) {
    debugPrint('migrateConversationsFromPrefs failed: $e');
    return null;
  }
}
