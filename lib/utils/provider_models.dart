import '../models/tts_models.dart';
import '../providers/provider_config.dart';

typedef ProviderModel = ({ProviderConfigItem config, ModelConfig model});

/// Configured models shared by standalone pages and task flow selectors.
/// List position is presentation only; persisted flows use local identities.
List<ProviderModel> flattenProviderModels(
  ProviderEntriesState state,
  String type,
) {
  return [
    for (final e in state.entries)
      if (e.type == type)
        for (final c in e.configs)
          if (c.host.trim().isNotEmpty && c.key.trim().isNotEmpty)
            for (final m in c.models) (config: c, model: m),
  ];
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
      reference['modelId'] is! String) return null;
  final matches = flattenProviderModels(state, type).where((entry) =>
      entry.config.id == reference['configId'] &&
      entry.model.id == reference['modelId']);
  return matches.length == 1 ? matches.single : null;
}
