import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant.dart';

// ============================================================================
// Provider: selected assistant ID for the current session
// ============================================================================

/// ID of the currently selected assistant (in the assistant→topic→chat flow).
final selectedAssistantIdProvider = StateProvider<String?>((ref) => null);

/// Currently selected assistant object, derived from [selectedAssistantIdProvider].
final selectedAssistantProvider = Provider<Assistant?>((ref) {
  final id = ref.watch(selectedAssistantIdProvider);
  if (id == null) return null;
  final assistants = ref.watch(assistantProvider);
  return assistants.where((a) => a.id == id).firstOrNull;
});

// ============================================================================
// Provider: list of all assistants
// ============================================================================

final assistantProvider =
    StateNotifierProvider<AssistantsNotifier, List<Assistant>>((ref) {
  final notifier = AssistantsNotifier();
  notifier._load();
  return notifier;
});

class AssistantsNotifier extends StateNotifier<List<Assistant>> {
  AssistantsNotifier() : super([]);

  // --------------------------------------------------------------------------
  // Persistence
  // --------------------------------------------------------------------------

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('assistants');
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        state = list.map((m) => Assistant.fromMap(m)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load assistants: $e');
    }
    // If no assistants, create a default one
    if (state.isEmpty) {
      _createDefaultAssistant();
    }

    // Migration: assign old conversations (null assistantId) to the
    // default assistant.  Runs at most once.
    // Must run after the default assistant is guaranteed to exist.
    await _migrateOldConversations();
  }

  /// Assigns the default assistant's ID to conversations that have a null
  /// [assistantId], so they become visible in the topic selection page.
  ///
  /// Guarded by the `migrated_old_conversations` flag so it only runs once.
  Future<void> _migrateOldConversations() async {
    if (state.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('migrated_old_conversations') == true) return;

      final convJson = prefs.getString('conversations');
      if (convJson == null) {
        await prefs.setBool('migrated_old_conversations', true);
        return;
      }

      final convList = (jsonDecode(convJson) as List)
          .cast<Map<String, dynamic>>();
      final defaultId = state.first.id;

      var migrated = false;
      final updated = convList.map((m) {
        if (m['assistantId'] == null) {
          migrated = true;
          return <String, dynamic>{...m, 'assistantId': defaultId};
        }
        return m;
      }).toList();

      if (migrated) {
        await prefs.setString('conversations', jsonEncode(updated));
        debugPrint('Migrated old conversations to default assistant.');
      }

      await prefs.setBool('migrated_old_conversations', true);
    } catch (e) {
      debugPrint('Failed to migrate old conversations: $e');
      // Set the flag even on error to avoid retrying a permanently
      // malformed store on every startup.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('migrated_old_conversations', true);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('assistants', toJson());
    } catch (e) {
      debugPrint('Failed to persist assistants: $e');
    }
  }

  /// Serializes current state to JSON string.
  String toJson() =>
      jsonEncode(state.map((a) => a.toMap()).toList());

  /// Restores state from a JSON string (used for testing).
  void loadFromJson(String json) {
    try {
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      state = list.map((m) => Assistant.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Failed to load assistants from JSON: $e');
    }
  }

  void _createDefaultAssistant() {
    createAssistant(
      name: '默认助手',
      prompt: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
      emoji: '🤖',
      description: '通用AI助手',
    );
  }

  // --------------------------------------------------------------------------
  // Mutations
  // --------------------------------------------------------------------------

  /// Creates a new assistant and adds it to the list.
  Assistant createAssistant({
    required String name,
    required String prompt,
    String emoji = '🤖',
    String description = '',
    AssistantSettings? settings,
    String? modelId,
  }) {
    final assistant = Assistant(
      name: name,
      prompt: prompt,
      emoji: emoji,
      description: description,
      settings: settings,
      modelId: modelId,
    );
    state = [...state, assistant];
    _persist();
    return assistant;
  }

  /// Updates fields of an existing assistant.
  void updateAssistant({
    required String id,
    String? name,
    String? prompt,
    String? emoji,
    String? description,
    AssistantSettings? settings,
    String? modelId,
  }) {
    state = state.map((a) {
      if (a.id != id) return a;
      return a.copyWith(
        name: name,
        prompt: prompt,
        emoji: emoji,
        description: description,
        settings: settings,
        modelId: modelId,
      );
    }).toList();
    _persist();
  }

  /// Updates only the settings of an assistant.
  void updateAssistantSettings({
    required String assistantId,
    double? temperature,
    bool? enableTemperature,
    double? topP,
    bool? enableTopP,
    int? maxTokens,
    bool? enableMaxTokens,
    bool? streamOutput,
    String? reasoningEffort,
    bool? enableWebSearch,
    int? maxToolCalls,
    bool? enableMaxToolCalls,
    List<CustomParameter>? customParameters,
  }) {
    state = state.map((a) {
      if (a.id != assistantId) return a;
      return a.copyWith(
        settings: a.settings.copyWith(
          temperature: temperature,
          enableTemperature: enableTemperature,
          topP: topP,
          enableTopP: enableTopP,
          maxTokens: maxTokens,
          enableMaxTokens: enableMaxTokens,
          streamOutput: streamOutput,
          reasoningEffort: reasoningEffort,
          enableWebSearch: enableWebSearch,
          maxToolCalls: maxToolCalls,
          enableMaxToolCalls: enableMaxToolCalls,
          customParameters: customParameters,
        ),
      );
    }).toList();
    _persist();
  }

  /// Deletes an assistant by [id].
  void deleteAssistant(String id) {
    state = state.where((a) => a.id != id).toList();
    _persist();
  }
}
