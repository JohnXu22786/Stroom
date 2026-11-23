import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/connectivity_test_service.dart';

void main() {
  test('MCP connectivity details include every discovered tool name', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final toolNames = List.generate(15, (index) => 'tool_${index + 1}');
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final message = jsonDecode(body) as Map<String, dynamic>;
      final method = message['method'];
      if (method == 'notifications/initialized') {
        request.response.statusCode = HttpStatus.accepted;
        await request.response.close();
        return;
      }

      final result = switch (method) {
        'initialize' => {
            'protocolVersion': '2024-11-05',
            'serverInfo': {'name': 'local fixture'},
          },
        'tools/list' => {
            'tools': [
              for (final name in toolNames)
                {
                  'name': name,
                  'inputSchema': {'type': 'object'}
                },
            ],
          },
        _ => throw StateError('Unexpected MCP request: $method'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': message['id'],
        'result': result,
      }));
      await request.response.close();
    });

    final result = await ConnectivityTestService.runProviderTest(
      config: ProviderConfigItem(
        providerName: 'Local fixture',
        typeConfig: {
          'transport': 'sse',
          'url': 'http://${server.address.address}:${server.port}/mcp',
        },
      ),
      testContent: '{"method":"tools/list"}',
      localizations: AppLocalizationsEnUs(),
      locale: const Locale('en', 'US'),
    );

    expect(result.succeeded, isTrue);
    for (final toolName in toolNames) {
      expect(result.details, contains(toolName));
    }
    expect(result.details, isNot(contains('remaining tools omitted')));
  });

  test('HTTP connectivity test ignores unrelated custom headers as API keys',
      () async {
    final result = await ConnectivityTestService.runProviderTest(
      config: ProviderConfigItem(
        providerName: 'Brave Search',
        host: 'https://api.search.brave.com',
        models: [
          ModelConfig(
            name: 'Brave Search',
            modelId: 'http',
            typeConfig: {
              'transport': 'http',
              'isHttpTool': true,
              'headers': {'X-Custom-Metadata': 'stale-custom-value'},
            },
          ),
        ],
      ),
      testContent: '{"query":""}',
      localizations: AppLocalizationsEnUs(),
      locale: const Locale('en', 'US'),
    );

    expect(result.succeeded, isFalse);
    expect(
      result.details,
      'Error: Brave Search API key is not configured. Configure it in settings.',
    );
  });

  test('HTTP connectivity test uses the stable name after display rename',
      () async {
    final result = await ConnectivityTestService.runProviderTest(
      config: ProviderConfigItem(
        providerName: 'My Brave Search',
        host: 'https://api.search.brave.com',
        models: [
          ModelConfig(
            name: 'Brave Search',
            modelId: 'http',
            typeConfig: {
              'transport': 'http',
              'isHttpTool': true,
              'headers': {'X-Subscription-Token': 'configured-key'},
            },
          ),
        ],
      ),
      testContent: '{"query":""}',
      localizations: AppLocalizationsEnUs(),
      locale: const Locale('en', 'US'),
    );

    expect(result.succeeded, isFalse);
    expect(result.details, 'Error: The search query cannot be empty.');
  });
}
