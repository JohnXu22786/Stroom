import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:stroom/l10n/app_localizations_en.dart';
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
