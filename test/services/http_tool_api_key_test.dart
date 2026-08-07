import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/http_tool_service.dart';

/// Regression test for the "6-char key auto-filled on MCP default tools" bug.
///
/// BUG: built-in MCP configs (Bocha, Querit, Jina AI, Zhipu) ship with a
/// header placeholder `'Authorization': 'Bearer '`. The API-key collector
/// trims the value to `"Bearer"` (6 chars), the `startsWith('Bearer ')`
/// check then fails (no trailing space after trim), so `"Bearer"` is
/// collected as if it were a real API key. The default HTTP tool then
/// believes a key is configured and sends `Authorization: Bearer Bearer`
/// (HTTP 401) instead of reporting "API Key 未配置".
void main() {
  group('built-in HTTP tool API key collection', () {
    test('placeholder "Bearer " header is NOT collected as a real API key',
        () async {
      final adapter = ChatAdapter();
      addTearDown(adapter.dispose);

      adapter.initializeBuiltinTools(ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'Bocha',
                host: 'https://api.bochaai.com/v1/web-search',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Bocha',
                    modelId: 'http',
                    typeConfig: {
                      'transport': 'http',
                      'isHttpTool': true,
                      'url': 'https://api.bochaai.com/v1/web-search',
                      // Placeholder prefix only — no real key.
                      'headers': {'Authorization': 'Bearer '},
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ));

      // With no real key configured the tool must report "key not
      // configured" — it must NOT have the 6-char "Bearer" placeholder
      // auto-filled as its API key.
      final result = await HttpToolService.handleBochaSearch({'query': ''});
      expect(result, contains('API Key 未配置'),
          reason: 'placeholder "Bearer " header must not be collected as an '
              'API key (regression: the 6-char "Bearer" was auto-filled, '
              'sending "Authorization: Bearer Bearer")');
    });
  });
}
