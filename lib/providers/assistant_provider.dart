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

/// Provider that resolves the default assistant (first one, or creates one).
/// Falls back to the first assistant in the list.
final defaultAssistantProvider = Provider<Assistant?>((ref) {
  final assistants = ref.watch(assistantProvider);
  if (assistants.isEmpty) return null;
  return assistants.first;
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
    // NOTE: Old conversation migration (null assistantId → default assistant)
    // is handled inside ConversationsNotifier._load() to avoid race conditions
    // between the two providers. See conversation_provider.dart.
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
  String toJson() => jsonEncode(state.map((a) => a.toMap()).toList());

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
    bool? enableWebSearch,
    int? maxToolCalls,
    bool? enableMaxToolCalls,
    double? frequencyPenalty,
    bool? enableFrequencyPenalty,
    double? presencePenalty,
    bool? enablePresencePenalty,
    int? seed,
    bool? enableSeed,
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
          enableWebSearch: enableWebSearch,
          maxToolCalls: maxToolCalls,
          enableMaxToolCalls: enableMaxToolCalls,
          frequencyPenalty: frequencyPenalty,
          enableFrequencyPenalty: enableFrequencyPenalty,
          presencePenalty: presencePenalty,
          enablePresencePenalty: enablePresencePenalty,
          seed: seed,
          enableSeed: enableSeed,
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
