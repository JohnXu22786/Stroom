import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/assistant.dart';
import '../models/chat_message.dart';
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
  /// Defaults to empty (all tools OFF). Persisted with the conversation.
  Set<String> enabledMcpToolNames = {};

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
        if (enabledMcpToolNames.isNotEmpty)
          'enabledMcpToolNames': enabledMcpToolNames.toList(),
      };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'] as String?,
        title: map['title'] as String? ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : null,
        messages: (map['messages'] as List?)
                ?.map((e) =>
                    ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        isPinned: map['isPinned'] as bool? ?? false,
        sortOrder: map['sortOrder'] as int? ?? 0,
        assistantId: map['assistantId'] as String?,
        draftText: map['draftText'] as String? ?? '',
        enabledMcpToolNames: (map['enabledMcpToolNames'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {},
      );

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
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        state = list.map((m) => Conversation.fromMap(m)).toList();
      } else {
        state = [];
      }

      // Auto-fix conversations with null assistantId on every load.
      // This is more reliable than the old one-time migration flag:
      // it catches conversations that were created without assistantId
      // even after the old migration had already "run".
      await assignNullAssistantConversations(prefs, state);

      // Restore last active conversation
      final activeId = prefs.getString('active_conversation_id');
      if (activeId != null && state.any((c) => c.id == activeId)) {
        _ref.read(activeConversationIdProvider.notifier).state = activeId;
      }
      return;
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
    }
    state = [];
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
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = jsonEncode(state.map((e) => e.toMap()).toList());
        await prefs.setString('conversations', json);
      } catch (e) {
        debugPrint('Failed to persist conversations: $e');
      }
    });
  }

  Future<void> _persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((e) => e.toMap()).toList());
      await prefs.setString('conversations', json);
    } catch (e) {
      debugPrint('Failed to persist conversations synchronously: $e');
    }
  }

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
  void updateEnabledTools(String conversationId, Set<String> enabledTools) {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.enabledMcpToolNames = Set<String>.from(enabledTools);
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
