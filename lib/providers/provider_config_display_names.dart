import '../l10n/app_localizations.dart';
import 'provider_config.dart';

/// Returns a localized label for built-in entries while leaving entries without
/// a recognized built-in identity untouched.
String providerEntryDisplayName(ProviderEntry entry, AppLocalizations l10n) {
  final localizedName = switch ((entry.id, entry.type)) {
    ('builtin_tts', 'tts') => l10n.providerBuiltinTtsName,
    ('builtin_llm' || 'migrated_llm', 'llm') => l10n.providerBuiltinLlmName,
    ('builtin_ocr', 'ocr') => l10n.providerBuiltinOcrName,
    ('builtin_asr', 'asr') => l10n.providerBuiltinAsrName,
    ('builtin_mcp', 'mcp') => l10n.providerBuiltinMcpName,
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
