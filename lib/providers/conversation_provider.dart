import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';

// ============================================================================
// Conversation model
// ============================================================================

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ChatMessage> messages;

  Conversation({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
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
      };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        messages: (map['messages'] as List?)
                ?.map((e) =>
                    ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );

  @override
  String toString() => 'Conversation(id: $id, title: $title)';
}

// ============================================================================
// Providers
// ============================================================================

/// ID of the currently active conversation, or null if none is selected.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

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
        return;
      }
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
    }
    state = [];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((e) => e.toMap()).toList());
      await prefs.setString('conversations', json);
    } catch (e) {
      debugPrint('Failed to persist conversations: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Mutations
  // --------------------------------------------------------------------------

  /// Creates a new conversation with an empty title, adds it to the list,
  /// and sets it as the active conversation.
  ///
  /// 不在此处持久化（避免与后续 updateMessages 的持久化竞争），
  /// 由 chat_provider 的 listener 负责持久化带消息的状态。
  String createConversation() {
    final now = DateTime.now();
    final conv = Conversation(
      title: '',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
    state = [...state, conv];
    _ref.read(activeConversationIdProvider.notifier).state = conv.id;
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
  }

  /// Selects a conversation by [id], setting it as the active one.
  void selectConversation(String id) {
    _ref.read(activeConversationIdProvider.notifier).state = id;
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

  /// Replaces the message list of a conversation (e.g. after sending or
  /// loading a different conversation).
  Future<void> updateMessages(
      String conversationId, List<ChatMessage> messages) async {
    state = state.map((c) {
      if (c.id != conversationId) return c;
      c.messages = messages;
      c.updatedAt = DateTime.now();
      // Derive title from the first user message if title is empty.
      if (c.title.isEmpty && messages.isNotEmpty) {
        final firstUser = messages.firstWhere(
          (m) => m.role == 'user',
          orElse: () => messages.first,
        );
        c.title = firstUser.content.length > 60
            ? '${firstUser.content.substring(0, 60)}…'
            : firstUser.content;
      }
      return c;
    }).toList();
    await _persist();
  }
}
