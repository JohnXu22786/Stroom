import '../l10n/app_localizations.dart';
import 'provider_config.dart';

/// Returns a localized label for the default built-in entries while leaving
/// renamed and user-created entries untouched.
String providerEntryDisplayName(ProviderEntry entry, AppLocalizations l10n) {
  final localizedName = switch ((entry.id, entry.type)) {
    ('builtin_tts', 'tts') when entry.name == 'TTS供应商' =>
      l10n.providerBuiltinTtsName,
    ('builtin_llm' || 'migrated_llm', 'llm') when entry.name == 'LLM供应商' =>
      l10n.providerBuiltinLlmName,
    ('builtin_ocr', 'ocr') when entry.name == 'OCR供应商' || entry.name == '云石' =>
      l10n.providerBuiltinOcrName,
    ('builtin_asr', 'asr')
        when entry.name == '音频转写供应商' || entry.name == '语音识别供应商' =>
      l10n.providerBuiltinAsrName,
    ('builtin_mcp', 'mcp') when entry.name == 'MCP供应商' =>
      l10n.providerBuiltinMcpName,
    _ => null,
  };
  return localizedName ?? entry.name;
}

/// Returns a localized label for the built-in MCP groups only.
String mcpGroupDisplayName(McpProviderGroup group, AppLocalizations l10n) {
  if (!group.isBuiltin) return group.name;
  return switch ((group.id, group.name)) {
    (builtinSearchMcpGroupId, '搜索') => l10n.providerBuiltinSearchGroupName,
    (builtinMcpServicesGroupId, '其他 MCP 服务') =>
      l10n.providerBuiltinMcpServicesGroupName,
    _ => group.name,
  };
}
