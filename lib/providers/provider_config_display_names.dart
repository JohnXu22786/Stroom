import '../l10n/app_localizations.dart';
import 'provider_config.dart';

/// Returns a localized label for the default built-in entries while leaving
/// renamed and user-created entries untouched.
String providerEntryDisplayName(ProviderEntry entry, AppLocalizations l10n) {
  final localizedName = switch ((entry.id, entry.name)) {
    ('builtin_tts', 'TTS供应商') => l10n.providerBuiltinTtsName,
    ('builtin_llm', 'LLM供应商') => l10n.providerBuiltinLlmName,
    ('builtin_ocr', 'OCR供应商') => l10n.providerBuiltinOcrName,
    ('builtin_asr', '音频转写供应商') => l10n.providerBuiltinAsrName,
    ('builtin_mcp', 'MCP供应商') => l10n.providerBuiltinMcpName,
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
