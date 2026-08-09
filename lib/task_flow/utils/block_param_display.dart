import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../models/tts_models.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/provider_config.dart';
import '../models/block_type_definition.dart';
import '../services/block_executors/shared_helpers.dart' show asIntParam;
import '../../utils/provider_models.dart';

/// Friendly display value for a block param — raw ids (assistant uuids,
/// voice ids like zh-CN-XiaoxiaoNeural, model indices) must never appear
/// to the user. Used by the block card summary AND the run-mode 查看参数
/// dialog, so both surfaces always agree.
///
/// [params] is the block's full param map — voice resolution follows the
/// selected model (modelIndex), exactly like the executor and the
/// settings panel.
String friendlyParamValue(
  BlockParamDefinition? paramDef,
  dynamic value,
  WidgetRef ref, {
  required Map<String, dynamic> params,
}) {
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
      final voices = selectedTtsVoices(ref, params);
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

/// Voices of the TTS model selected by the block's modelIndex param —
/// the same model the executor synthesizes with (shared
/// flattenProviderModels list).
List<VoiceEntry> selectedTtsVoices(
  WidgetRef ref,
  Map<String, dynamic> params,
) {
  final models = flattenProviderModels(
    ref.read(providerEntriesProvider),
    'tts',
  );
  final idx = asIntParam(params, 'modelIndex', 0);
  if (models.isEmpty || idx >= models.length) return const [];
  final m = models[idx].model;
  return m.voices;
}
