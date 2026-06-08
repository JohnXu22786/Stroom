import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';

// ============================================================================
// Helper: migrate old conversations with null assistantId to default assistant
// ============================================================================

/// Migrates old conversations with null assistantId to the default assistant.
///
/// Old conversations created before the multi-assistant feature had
/// null assistantId, making them invisible when filtered by assistant.
/// This migration assigns them to the default assistant (first in list).
///
/// Guarded by the 'migrated_old_conversations' SharedPreferences flag
/// to ensure it runs only once.
///
/// Returns the list of migrated [Conversation]s (in-memory) so callers can
/// update their state, or `null` if migration was skipped or no assistants
/// exist yet.
Future<List<Conversation>?> migrateConversationsFromPrefs(
    SharedPreferences prefs) async {
  try {
    final alreadyMigrated =
        prefs.getBool('migrated_old_conversations') ?? false;
    if (alreadyMigrated) return null;

    // Read the default assistant from the assistants store
    final assistantsJson = prefs.getString('assistants');
    if (assistantsJson == null || assistantsJson.isEmpty) {
      return null; // No assistants persisted yet, migration will run next time
    }

    final assistantsList = (jsonDecode(assistantsJson) as List)
        .cast<Map<String, dynamic>>();
    if (assistantsList.isEmpty) {
      return null; // No assistants, nothing to migrate to
    }
    final defaultAssistantId = assistantsList.first['id'] as String;

    // Read and migrate conversations
    final conversationsJson = prefs.getString('conversations');
    if (conversationsJson == null) return null;

    final conversationList = (jsonDecode(conversationsJson) as List)
        .cast<Map<String, dynamic>>();
    bool changed = false;

    for (final conv in conversationList) {
      if (conv['assistantId'] == null) {
        conv['assistantId'] = defaultAssistantId;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString(
          'conversations', jsonEncode(conversationList));
      debugPrint(
          'Migrated old conversations to default assistant ($defaultAssistantId)');
    }

    await prefs.setBool('migrated_old_conversations', true);

    // Return the migrated conversations for in-memory state update
    return conversationList
        .map((m) => Conversation.fromMap(m))
        .toList();
  } catch (e) {
    debugPrint('Failed to migrate old conversations: $e');
    return null;
  }
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

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    this.isPinned = false,
    this.sortOrder = 0,
    this.assistantId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': isPinned,
        'sortOrder': sortOrder,
        if (assistantId != null) 'assistantId': assistantId,
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

      // Migrate old conversations with null assistantId to default assistant.
      // This runs before the active conversation ID is restored so the UI
      // sees migrated data from the first frame.
      final migrated = await migrateConversationsFromPrefs(prefs);
      if (migrated != null) {
        state = migrated;
      }

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

  void _persistNow() {
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      final prefs = SharedPreferences.getInstance();
      final json = jsonEncode(state.map((e) => e.toMap()).toList());
      prefs.then((p) => p.setString('conversations', json));
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
    state = [...state, conv];
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
  void togglePin(String id) {
    state = state.map((c) {
      if (c.id != id) return c;
      c.isPinned = !c.isPinned;
      c.updatedAt = DateTime.now();
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
}
