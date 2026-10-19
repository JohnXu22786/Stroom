import '../models/tts_models.dart';
import '../providers/provider_config.dart';
import '../services/llm_chat_runtime.dart';
import '../services/llm_model_group_provider.dart';

typedef ProviderModel = ({ProviderConfigItem config, ModelConfig model});

/// Configured models shared by standalone pages and task flow selectors.
/// List position is presentation only; persisted flows use local identities.
List<ProviderModel> flattenProviderModels(
  ProviderEntriesState state,
  String type, {
  bool includeShadowedLegacyModels = false,
  bool includeUnavailableGroupModels = false,
}) {
  bool hasEquivalentGroup(ProviderConfigItem config, ModelConfig model) {
    final expectedGroupId = type == 'ocr'
        ? llmOcrModelGroupIdForConfig(config.id, model.id)
        : stableLlmModelGroupId(config.id, model.id);
    return state.entries
        .where((entry) => entry.type == 'llm')
        .expand((entry) => entry.configs)
        .any(
          (groupConfig) =>
              isLlmModelGroupProviderConfig(groupConfig) &&
              llmModelGroupIdForConfig(groupConfig) == expectedGroupId,
        );
  }

  final models = <ProviderModel>[];
  for (final entry in state.entries) {
    final isOcrGroupCatalog = type == 'ocr' && entry.type == 'llm';
    if (entry.type != type && !isOcrGroupCatalog) continue;
    for (final config in entry.configs) {
      final isGroupConfig = isLlmModelGroupProviderConfig(config);
      if (isOcrGroupCatalog && !isGroupConfig) {
        continue;
      }
      if (type == 'llm' && isUnsupportedLegacyLlmSelectorConfig(config)) {
        continue;
      }
      if (!isGroupConfig &&
          (config.host.trim().isEmpty || config.key.trim().isEmpty)) {
        continue;
      }
      for (final model in config.models) {
        if (type == 'llm' &&
            isGroupConfig &&
            !includeUnavailableGroupModels &&
            !llmModelConfigSupportsCapability(model, 'streaming')) {
          continue;
        }
        if (isOcrGroupCatalog &&
            isGroupConfig &&
            !llmModelConfigSupportsCapability(model, 'vision')) {
          continue;
        }
        if ((type == 'llm' || type == 'ocr') &&
            !includeShadowedLegacyModels &&
            !isGroupConfig &&
            hasEquivalentGroup(config, model)) {
          continue;
        }
        models.add((config: config, model: model));
      }
    }
  }
  return models;
}

/// A flow stores only these two opaque IDs, never connection credentials.
Map<String, String> providerModelReference(ProviderModel selected) => {
  'configId': selected.config.id,
  'modelId': selected.model.id,
};

/// Missing/ambiguous references must be reselected, never resolved by position.
ProviderModel? resolveProviderModel(
  ProviderEntriesState state,
  String type,
  dynamic reference,
) {
  if (reference is! Map ||
      reference['configId'] is! String ||
      reference['modelId'] is! String)
    return null;
  // Keep resolving old references from provider_entries even when a matching
  // model-group row now supplies the selector option.
  final matches =
      flattenProviderModels(
        state,
        type,
        includeShadowedLegacyModels: true,
        includeUnavailableGroupModels: true,
      ).where(
        (entry) =>
            entry.config.id == reference['configId'] &&
            entry.model.id == reference['modelId'],
      );
  final exactMatches = matches.toList(growable: false);
  if (exactMatches.length == 1) return exactMatches.single;
  if (exactMatches.isNotEmpty || !{'llm', 'ocr'}.contains(type)) return null;

  // A legacy model reference can outlive its provider config (or that config
  // can have no API key, as with a local endpoint). Resolve only its M1 stable
  // account/model group in that case; never guess a different model or group.
  final groupId = type == 'ocr'
      ? llmOcrModelGroupIdForConfig(
          reference['configId'] as String,
          reference['modelId'] as String,
        )
      : stableLlmModelGroupId(
          reference['configId'] as String,
          reference['modelId'] as String,
        );
  final groupMatches =
      flattenProviderModels(state, type, includeUnavailableGroupModels: true)
          .where(
            (entry) =>
                isLlmModelGroupProviderConfig(entry.config) &&
                entry.config.id == groupId &&
                entry.model.id == reference['modelId'],
          )
          .toList(growable: false);
  return groupMatches.length == 1 ? groupMatches.single : null;
}
