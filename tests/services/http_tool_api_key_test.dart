import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
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
    test('config refresh clears removed keys and preserves configured keys',
        () async {
      final adapter = ChatAdapter();
      addTearDown(() {
        adapter.initializeBuiltinTools(const ProviderEntriesState());
        adapter.dispose();
      });

      ProviderConfigItem httpTool(String name, Map<String, dynamic> config) =>
          ProviderConfigItem(
            providerName: name,
            host: 'https://example.com',
            key: '',
            models: [
              ModelConfig(name: name, modelId: 'http', typeConfig: config),
            ],
          );

      ProviderEntriesState stateWith(List<ProviderConfigItem> configs) =>
          ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'test_mcp',
                type: 'mcp',
                name: 'MCP供应商',
                configs: configs,
              ),
            ],
          );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final authorizationHeaders = <String?>[];
      server.listen((request) async {
        authorizationHeaders.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"results":[]}');
        await request.response.close();
      });

      adapter.initializeBuiltinTools(stateWith([
        httpTool('Brave Search', {
          'isHttpTool': true,
          'apiKey': 'old-brave-key',
        }),
        httpTool('Bocha', {
          'isHttpTool': true,
          'apiKey': 'removed-bocha-key',
        }),
        httpTool('Querit', {
          'isHttpTool': true,
          'apiKey': 'removed-querit-key',
        }),
        httpTool('Searxng', {
          'isHttpTool': true,
          'url': 'https://removed.example',
          'apiKey': 'removed-searxng-key',
        }),
      ]));

      Future<void> expectConfigured(Future<String> result) async {
        expect(await result, contains('query cannot be empty'));
      }

      // Each provider remains usable when it is still present in a refreshed
      // snapshot, while values for providers removed from that snapshot clear.
      adapter.initializeBuiltinTools(stateWith([
        httpTool('Brave Search', {
          'isHttpTool': true,
          'apiKey': 'current-brave-key',
        }),
      ]));
      await expectConfigured(HttpToolService.handleBraveSearch({'query': ''}));
      expect(
        await HttpToolService.handleBochaSearch({'query': ''}),
        contains('API key is not configured'),
      );

      adapter.initializeBuiltinTools(stateWith([
        httpTool('Bocha', {
          'isHttpTool': true,
          'apiKey': 'current-bocha-key',
        }),
      ]));
      await expectConfigured(HttpToolService.handleBochaSearch({'query': ''}));
      expect(
        await HttpToolService.handleBraveSearch({'query': ''}),
        contains('API key is not configured'),
      );

      adapter.initializeBuiltinTools(stateWith([
        httpTool('Querit', {
          'isHttpTool': true,
          'apiKey': 'current-querit-key',
        }),
      ]));
      await expectConfigured(
        HttpToolService.handleQueritSearch({'query': ''}),
      );

      adapter.initializeBuiltinTools(stateWith([
        httpTool('Searxng', {
          'isHttpTool': true,
          'url': 'https://current.example',
          'apiKey': 'current-searxng-key',
        }),
      ]));
      await expectConfigured(
        HttpToolService.handleSearxngSearch({'query': ''}),
      );
      await HttpToolService.handleSearxngSearch(
        {'query': 'configured'},
        url: 'http://${server.address.address}:${server.port}',
      );
      expect(authorizationHeaders.last, 'Bearer current-searxng-key');

      adapter.initializeBuiltinTools(stateWith([
        httpTool('Brave Search', {
          'isHttpTool': true,
          'apiKey': 'current-brave-key',
        }),
      ]));
      expect(
        await HttpToolService.handleQueritSearch({'query': ''}),
        contains('API key is not configured'),
      );
      expect(
        await HttpToolService.handleSearxngSearch({'query': ''}),
        contains('URL is not configured'),
      );
      await HttpToolService.handleSearxngSearch(
        {'query': 'removed'},
        url: 'http://${server.address.address}:${server.port}',
      );
      expect(authorizationHeaders.last, isNull);
      expect(
        await HttpToolService.handleBraveSearch({'query': ''}),
        contains('query cannot be empty'),
      );
    });

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
      final result = await HttpToolService.handleBochaSearch(
        {'query': ''},
        locale: const Locale('en', 'US'),
      );
      expect(result, contains('API key is not configured'),
          reason: 'placeholder "Bearer " header must not be collected as an '
              'API key (regression: the 6-char "Bearer" was auto-filled, '
              'sending "Authorization: Bearer Bearer")');
    });
    test(
        'localizes search output labels and errors without changing provider text',
        () async {
      final englishEmptyQuery = await HttpToolService.handleBraveSearch(
        {'query': ''},
        apiKey: 'test-key',
        locale: const Locale('en', 'US'),
      );
      final chineseEmptyQuery = await HttpToolService.handleBraveSearch(
        {'query': ''},
        apiKey: 'test-key',
        locale: const Locale('zh', 'CN'),
      );
      expect(englishEmptyQuery, 'Error: The search query cannot be empty.');
      expect(chineseEmptyQuery, '错误：搜索关键词不能为空。');

      const result = (
        title: 'Provider title',
        url: 'https://example.com/article',
        description: 'Provider snippet',
      );
      final englishResults = HttpToolService.formatSearchResults(
        [result],
        locale: const Locale('en', 'US'),
      );
      final chineseResults = HttpToolService.formatSearchResults(
        [result],
        locale: const Locale('zh', 'CN'),
      );
      expect(englishResults, contains('Title: Provider title'));
      expect(englishResults, contains('Link: https://example.com/article'));
      expect(englishResults, contains('Summary: Provider snippet'));
      expect(chineseResults, contains('标题: Provider title'));
      expect(chineseResults, contains('链接: https://example.com/article'));
      expect(chineseResults, contains('摘要: Provider snippet'));
    });
  });
}
