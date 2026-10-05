import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/connectivity_test_service.dart';

void main() {
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
    );

    expect(result.succeeded, isFalse);
    expect(result.details, contains('Brave Search API Key 未配置'));
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
    );

    expect(result.succeeded, isFalse);
    expect(result.details, contains('搜索关键词不能为空'));
  });
}
