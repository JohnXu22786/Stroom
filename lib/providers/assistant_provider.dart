import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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

  /// Updates an assistant's conversation defaults: the default model
  /// (display name + absolute identity, applied to NEW conversations) and
  /// the default enabled tool names (tools not in the set stay off in new
  /// conversations).
  ///
  /// Unlike [updateAssistant]'s copyWith semantics, a null [defaultModelName]
  /// here explicitly CLEARS the default (new conversations fall back to the
  /// global model selection), so the assistant is rebuilt directly instead of
  /// via copyWith. [defaultModelId]/[defaultProviderName] 是绝对身份
  /// （API 模型 ID + 供应商名），与 [defaultModelName] 一起保存；重命名
  /// 显示名后默认模型仍可解析。
  ///
  /// ASYMMETRY: a null [defaultToolNames] KEEPS the assistant's previous
  /// tool-default state. Pass a non-null set — including an empty one, which
  /// means "configured, all tools off" — to set it. Pass [clearDefaultToolNames]
  /// = true (with a null [defaultToolNames]) to return the assistant to
  /// "never configured" (new topics auto-enable all tools again).
  ///
  /// 注意：编辑助手对话框的"取消配置"按钮已移除，UI 不再产生
  /// [clearDefaultToolNames] = true 的调用；该参数保留给测试与
  /// 未来入口使用。
  void updateAssistantDefaults({
    required String id,
    String? defaultModelName,
    String? defaultModelId,
    String? defaultProviderName,
    Set<String>? defaultToolNames,
    bool clearDefaultToolNames = false,
  }) {
    assert(
      !(clearDefaultToolNames && defaultToolNames != null),
      'clearDefaultToolNames 与 defaultToolNames 互斥：清除时集合应传 null',
    );
    state = state.map((a) {
      if (a.id != id) return a;
      return Assistant(
        id: a.id,
        name: a.name,
        prompt: a.prompt,
        emoji: a.emoji,
        description: a.description,
        settings: a.settings,
        modelId: a.modelId,
        defaultModelName: defaultModelName,
        defaultModelId: defaultModelId,
        defaultProviderName: defaultProviderName,
        // 拷贝一份：不持有调用方的可变 Set 实例（对话框保存后仍会复用）。
        // 传入非 null（含空集合）即视为"已配置默认工具"；
        // clearDefaultToolNames 显式回到"从未配置"（null）。
        defaultToolNames: clearDefaultToolNames
            ? null
            : defaultToolNames != null
                ? Set<String>.from(defaultToolNames)
                : a.defaultToolNames,
        createdAt: a.createdAt,
        updatedAt: DateTime.now(),
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
