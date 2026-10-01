import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tts_models.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/provider_config.dart';
import '../models/block_type_definition.dart';
import '../../utils/provider_models.dart';

/// Friendly display value for a block param — raw ids (assistant uuids,
/// voice ids like zh-CN-XiaoxiaoNeural, model references) must never appear
/// to the user. Used by the block card summary AND the run-mode 查看参数
/// dialog, so both surfaces always agree.
///
/// [params] is the block's full param map — voice resolution follows the
/// selected model reference, exactly like the executor and the
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
      // Only user-defined assistants are valid on blocks — legacy
      // built-in prompt ids read as 已失效.
      final assistants = ref.read(assistantProvider);
      final a = assistants.where((a) => a.id == raw).firstOrNull;
      return a != null ? '${a.emoji} ${a.name}' : '已失效';
    case BlockParamType.voiceSelector:
      final voices = selectedTtsVoices(ref, params);
      final v = voices.where((v) => v.id == raw).firstOrNull;
      return v != null ? v.name : '已失效';
    case BlockParamType.modelSelector:
      final selected = resolveProviderModel(
        ref.read(providerEntriesProvider),
        paramDef.configType,
        value,
      );
      if (selected == null) return '已失效，请重新选择';
      final m = selected.model;
      final c = selected.config;
      final name = m.name.isNotEmpty ? m.name : m.modelId;
      return '$name | ${c.providerName}';
    case BlockParamType.filePath:
      // An empty path = the root folder — show it explicitly so a
      // root-folder save config is visible on the block card and in the
      // run-mode 查看参数 panel instead of looking unset.
      return raw.isEmpty ? '根目录' : raw;
    default:
      return raw;
  }
}

/// Voices of the same persistent model reference used by the executor.
List<VoiceEntry> selectedTtsVoices(
  WidgetRef ref,
  Map<String, dynamic> params,
) =>
    resolveProviderModel(
      ref.read(providerEntriesProvider),
      'tts',
      params['modelRef'],
    )?.model.voices ??
    const [];
