/// Protocol selection is stored with supplier/model configuration. Connector
/// types control credentials and request authentication only.
const kCustomHttpApiProtocols = <String>{
  'openai.chat_completions',
  'openai.responses',
  'anthropic.messages',
};

/// Converts the v0.5/v0.6 endpoint selector values into stable protocol IDs.
String apiProtocolFromLegacyEndpointType(String? endpointType) =>
    switch (endpointType) {
      'anthropic' => 'anthropic.messages',
      'openai' || null || '' => 'openai.chat_completions',
      // Previously stored dedicated native adapter IDs are already stable.
      final value => value,
    };

/// Selects an explicit protocol override, supplier setting, or native default.
String resolveApiProtocol({
  String? modelOverride,
  String? supplierProtocol,
  String? builtinDefault,
}) => firstNonEmptyProtocol([
  modelOverride,
  supplierProtocol,
  builtinDefault,
  'openai.chat_completions',
]);

/// Resolves persisted settings, including direct in-memory configs created by
/// older call sites that still populate only endpointType.
String configuredApiProtocol({
  required String? modelOverride,
  required String? modelLegacyEndpointType,
  required String? supplierProtocol,
  required String? supplierLegacyEndpointType,
}) => resolveApiProtocol(
  modelOverride:
      modelOverride ??
      (modelLegacyEndpointType == null
          ? null
          : apiProtocolFromLegacyEndpointType(modelLegacyEndpointType)),
  supplierProtocol:
      supplierProtocol ??
      apiProtocolFromLegacyEndpointType(supplierLegacyEndpointType),
);

/// Authentication connector identity is deliberately ignored here.
String resolveConnectorProtocol(
  String configuredProtocol,
  String connectorType,
) => configuredProtocol;

String firstNonEmptyProtocol(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.isNotEmpty) return value;
  }
  return 'openai.chat_completions';
}

String builtinDefaultApiProtocolForConnector(String? connectorType) =>
    switch (connectorType) {
      'codex' => 'openai.responses',
      'xai' ||
      'grok-cli' ||
      'xai-oauth' ||
      'meta' ||
      'muse-code' => 'openai.responses',
      'claude' => 'anthropic.messages',
      'gemini' || 'aistudio' || 'vertex' => 'google.gemini.generate_content',
      'gemini-interactions' => 'google.gemini.interactions',
      'ollama' => 'ollama.chat',
      'kimi-coding' => 'openai.chat_completions',
      _ => 'openai.chat_completions',
    };

void validateApiProtocolOverride(
  String? override,
  Set<String> supportedProtocols,
) {
  if (override == null || override.isEmpty) return;
  if (!supportedProtocols.contains(override)) {
    throw ArgumentError.value(override, 'override', 'Unsupported API protocol');
  }
}

/// Legacy ChatService supports the original two protocol implementations.
/// Routed Gateway providers consume the full stable protocol ID directly.
String legacyEndpointTypeForApiProtocol(String protocolId) =>
    switch (protocolId) {
      'anthropic.messages' => 'anthropic',
      'openai.chat_completions' || 'openai.responses' => 'openai',
      _ => protocolId,
    };

Set<String> supportedApiProtocolsForSupplier(
  String? supplierProtocol, {
  String? connectorType,
}) {
  final builtinProtocols = switch (connectorType) {
    'openai-api' => const {'openai.chat_completions', 'openai.responses'},
    'moonshot' ||
    'glm' ||
    'deepseek' ||
    'minimax' ||
    'qwen' => const {'openai.chat_completions'},
    'kimi' ||
    'kimi-ai' ||
    'kimi.ai' ||
    'kimi-coding' => kCustomHttpApiProtocols,
    _ => null,
  };
  if (builtinProtocols != null) return builtinProtocols;

  final nativeProtocol = switch (connectorType) {
    'claude' => 'anthropic.messages',
    'gemini' || 'aistudio' => 'google.gemini.generate_content',
    'gemini-interactions' => 'google.gemini.interactions',
    'ollama' => 'ollama.chat',
    'xai' ||
    'grok-cli' ||
    'xai-oauth' ||
    'meta' ||
    'muse-code' => 'openai.responses',
    'bedrock' ||
    'vertex' ||
    'codex' ||
    'antigravity' ||
    'devin' => supplierProtocol,
    _ => null,
  };
  if (nativeProtocol != null) return {nativeProtocol};
  if (supplierProtocol == null ||
      supplierProtocol.isEmpty ||
      kCustomHttpApiProtocols.contains(supplierProtocol)) {
    return kCustomHttpApiProtocols;
  }
  return {supplierProtocol};
}

const apiProtocolLabels = <String, String>{
  'openai.chat_completions': 'OpenAI Chat Completions',
  'openai.responses': 'OpenAI Responses',
  'anthropic.messages': 'Anthropic Messages',
};
