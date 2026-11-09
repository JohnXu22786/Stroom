import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/provider_config_display_names.dart';

void main() {
  test(
    'localizes built-in provider and group names without changing custom names',
    () {
      final entries = [
        ProviderEntry(id: 'builtin_tts', type: 'tts', name: 'TTS供应商'),
        ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
        ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
        ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
        ProviderEntry(id: 'builtin_mcp', type: 'mcp', name: 'MCP供应商'),
        ProviderEntry(id: 'builtin_tts', type: 'tts', name: 'My Speech Setup'),
        ProviderEntry(id: 'custom', type: 'tts', name: 'My Custom Provider'),
      ];
      const groups = [
        McpProviderGroup(
          id: builtinSearchMcpGroupId,
          name: '搜索',
          isBuiltin: true,
        ),
        McpProviderGroup(
          id: builtinMcpServicesGroupId,
          name: '其他 MCP 服务',
          isBuiltin: true,
        ),
        McpProviderGroup(id: 'custom-group', name: 'My Group'),
      ];
      final en = AppLocalizationsEn();
      final zh = AppLocalizationsZhCn();

      expect(
        entries.take(5).map((entry) => providerEntryDisplayName(entry, en)),
        [
          'TTS Provider',
          'LLM Provider',
          'OCR Provider',
          'Speech Recognition Provider',
          'MCP Provider',
        ],
      );
      expect(
        entries.take(5).map((entry) => providerEntryDisplayName(entry, zh)),
        ['TTS供应商', 'LLM供应商', 'OCR供应商', '音频转写供应商', 'MCP供应商'],
      );
      expect(providerEntryDisplayName(entries[5], en), 'My Speech Setup');
      expect(providerEntryDisplayName(entries[6], en), 'My Custom Provider');

      expect(groups.take(2).map((group) => mcpGroupDisplayName(group, en)), [
        'Search',
        'Other MCP Services',
      ]);
      expect(groups.take(2).map((group) => mcpGroupDisplayName(group, zh)), [
        '搜索',
        '其他 MCP 服务',
      ]);
      expect(mcpGroupDisplayName(groups[2], en), 'My Group');
    },
  );
}
