import '../models/tts_models.dart';
import '../providers/provider_config.dart';

/// Flattens the models of a provider type across ALL configs, skipping
/// configs without a host or API key.
///
/// Single source of truth for model lists: the standalone pages (ASR/OCR),
/// the flow executors, and the block settings panel must agree on the
/// ORDER and MEMBERSHIP of this list — a selected model index resolves to
/// the same model everywhere. Keep the page/executor/panel call sites in
/// sync when changing the filter.
List<({ProviderConfigItem config, ModelConfig model})> flattenProviderModels(
  ProviderEntriesState state,
  String type,
) {
  return [
    for (final e in state.entries)
      if (e.type == type)
        for (final c in e.configs)
          if (c.host.isNotEmpty && c.key.isNotEmpty)
            for (final m in c.models) (config: c, model: m),
  ];
}
