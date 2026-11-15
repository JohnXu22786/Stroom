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
        ProviderEntry(id: 'migrated_llm', type: 'llm', name: 'LLM供应商'),
        ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: '云石'),
        ProviderEntry(id: 'builtin_asr', type: 'asr', name: '语音识别供应商'),
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
        entries.take(6).map((entry) => providerEntryDisplayName(entry, en)),
        [
          'TTS (Text to Speech)',
          'LLM (Large Language Model)',
          'LLM (Large Language Model)',
          'OCR (Optical Character Recognition)',
          'STT (Speech to Text)',
          'MCP (Model Context Protocol)',
        ],
      );
      expect(
        entries.take(6).map((entry) => providerEntryDisplayName(entry, zh)),
        [
          'TTS（文本转语音）',
          'LLM（大语言模型）',
          'LLM（大语言模型）',
          'OCR（光学字符识别）',
          'STT（语音转文本）',
          'MCP（模型上下文协议）',
        ],
      );
      expect(providerEntryDisplayName(entries[6], en), 'My Speech Setup');
      expect(providerEntryDisplayName(entries[7], en), 'My Custom Provider');

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
