import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../models/tts_models.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/provider_config.dart';
import '../models/block_type_definition.dart';
import '../../utils/provider_models.dart';

/// Friendly display value for a block param — raw ids (assistant uuids,
/// voice ids like zh-CN-XiaoxiaoNeural, model indices) must never appear
/// to the user. Used by the block card summary AND the run-mode 查看参数
/// dialog, so both surfaces always agree.
String friendlyParamValue(
  BlockParamDefinition? paramDef,
  dynamic value,
  WidgetRef ref,
) {
  if (paramDef == null) return value.toString();
  final raw = value?.toString() ?? '';
  switch (paramDef.type) {
    case BlockParamType.assistantSelector:
      if (raw.isEmpty) return '未指定';
      final builtIn = builtInPromptById(raw);
      if (builtIn != null) return '${builtIn.emoji} ${builtIn.name}';
      final assistants = ref.read(assistantProvider);
      final a = assistants.where((a) => a.id == raw).firstOrNull;
      return a != null ? '${a.emoji} ${a.name}' : '已失效';
    case BlockParamType.voiceSelector:
      final voices = ttsVoicesOf(ref);
      final v = voices.where((v) => v.id == raw).firstOrNull;
      return v != null ? v.name : '已失效';
    case BlockParamType.modelSelector:
      final models = flattenProviderModels(
        ref.read(providerEntriesProvider),
        paramDef.configType,
      );
      final idx = int.tryParse(raw) ?? -1;
      if (idx < 0 || idx >= models.length) return '已失效';
      final m = models[idx].model;
      final c = models[idx].config;
      final name = m.name.isNotEmpty ? m.name : m.modelId;
      return '$name | ${c.providerName}';
    default:
      return raw;
  }
}

/// Voices of the TTS model the executors use (configs.first.models.first —
/// same source as the settings panel and the TTS page).
List<VoiceEntry> ttsVoicesOf(WidgetRef ref) {
  final state = ref.read(providerEntriesProvider);
  for (final e in state.entries) {
    if (e.type != 'tts') continue;
    for (final c in e.configs) {
      if (c.models.isEmpty) continue;
      return c.models.first.voices;
    }
  }
  return const [];
}
