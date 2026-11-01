import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/services/api_protocol_config.dart';
import 'package:stroom/ai_gateway/ai_gateway_protocol_bridges.dart';

void main() {
  group('API protocol configuration', () {
    test(
        'Codex defaults to Responses while OpenAI API keys stay Chat Completions',
        () {
      expect(
          builtinDefaultApiProtocolForConnector('codex'), 'openai.responses');
      expect(
        builtinDefaultApiProtocolForConnector('openai-api'),
        'openai.chat_completions',
      );
      expect(
        supportedApiProtocolsForSupplier(
          'openai.responses',
          connectorType: 'codex',
        ),
        {'openai.responses'},
      );
      expect(
        supportedApiProtocolsForSupplier(
          'openai.chat_completions',
          connectorType: 'openai-api',
        ),
        {'openai.chat_completions', 'openai.responses'},
      );
    });

    test('migrates legacy provider and model endpoint types on read', () {
      final provider = ProviderConfigItem.fromMap({
        'endpointType': 'anthropic',
        'models': [
          {'name': 'Claude', 'modelId': 'claude'},
        ],
      });
      final model = ModelConfig.fromMap({
        'name': 'Claude',
        'modelId': 'claude',
        'endpointType': 'openai',
      });

      expect(provider.apiProtocol, 'anthropic.messages');
      expect(model.apiProtocolOverride, 'openai.chat_completions');
      expect(
        configuredApiProtocol(
          modelOverride: model.apiProtocolOverride,
          modelLegacyEndpointType: model.endpointType,
          supplierProtocol: provider.apiProtocol,
          supplierLegacyEndpointType: provider.endpointType,
        ),
        'openai.chat_completions',
      );
      expect(provider.toMap()['endpointType'], 'anthropic');
      expect(provider.toMap()['apiProtocol'], 'anthropic.messages');
      expect(model.toMap()['apiProtocolOverride'], 'openai.chat_completions');
      expect(
        ProviderConfigItem.fromMap(provider.toMap()).apiProtocol,
        'anthropic.messages',
      );
      expect(
        ModelConfig.fromMap(model.toMap()).apiProtocolOverride,
        'openai.chat_completions',
      );
    });

    test(
      'resolves model override, supplier default, then built-in default',
      () {
        final provider = ProviderConfigItem(
          apiProtocol: 'openai.responses',
          models: [ModelConfig(name: 'A', modelId: 'a')],
        );
        expect(
          resolveApiProtocol(
            modelOverride: provider.models.single.apiProtocolOverride,
            supplierProtocol: provider.apiProtocol,
          ),
          'openai.responses',
        );

        provider.models.single.apiProtocolOverride = 'anthropic.messages';
        expect(
          resolveApiProtocol(
            modelOverride: provider.models.single.apiProtocolOverride,
            supplierProtocol: provider.apiProtocol,
          ),
          'anthropic.messages',
        );

        provider.models.single.apiProtocolOverride = null;
        provider.apiProtocol = null;
        expect(
          resolveApiProtocol(
            modelOverride: provider.models.single.apiProtocolOverride,
            supplierProtocol: provider.apiProtocol,
          ),
          'openai.chat_completions',
        );
      },
    );

    test('all three custom formats have registered runtime bridges', () {
      for (final protocol in kCustomHttpApiProtocols) {
        expect(AiGatewayProtocolBridges.forProtocol(protocol), isNotNull);
      }
    });

    test('protocol remains independent of connector authentication type', () {
      const selected = 'openai.responses';
      expect(resolveConnectorProtocol(selected, 'openai-api'), selected);
      expect(resolveConnectorProtocol(selected, 'claude'), selected);
      expect(
        resolveConnectorProtocol(
          'google.gemini.generate_content',
          'vertex',
        ),
        'google.gemini.generate_content',
      );
    });

    test('keeps native suppliers on their declared protocol', () {
      expect(
        supportedApiProtocolsForSupplier(
          'anthropic.messages',
          connectorType: 'claude',
        ),
        {'anthropic.messages'},
      );
      expect(
        () => validateApiProtocolOverride(
          'openai.responses',
          supportedApiProtocolsForSupplier(
            'anthropic.messages',
            connectorType: 'claude',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        supportedApiProtocolsForSupplier(
          'google.gemini.generate_content',
          connectorType: 'gemini',
        ),
        {'google.gemini.generate_content'},
      );
      expect(
        builtinDefaultApiProtocolForConnector('vertex'),
        'google.gemini.generate_content',
      );
      expect(
        supportedApiProtocolsForSupplier(
          'google.gemini.generate_content',
          connectorType: 'vertex',
        ),
        {'google.gemini.generate_content'},
      );
    });

    test('limits built-in suppliers to their implemented API formats', () {
      expect(
        supportedApiProtocolsForSupplier(
          'openai.chat_completions',
          connectorType: 'moonshot',
        ),
        {'openai.chat_completions'},
      );
      expect(
        supportedApiProtocolsForSupplier(
          'openai.chat_completions',
          connectorType: 'openai-api',
        ),
        {'openai.chat_completions', 'openai.responses'},
      );
      expect(
        supportedApiProtocolsForSupplier(
          'openai.chat_completions',
          connectorType: 'openai-compatibility',
        ),
        kCustomHttpApiProtocols,
      );
    });

    test('validates overrides against supplier supported protocols', () {
      expect(
        () => validateApiProtocolOverride('anthropic.messages', const {
          'openai.chat_completions',
        }),
        throwsArgumentError,
      );
    });
  });
}
