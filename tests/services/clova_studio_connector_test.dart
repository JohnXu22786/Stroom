import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/api_protocol_config.dart';
import 'package:stroom/services/clova_studio_protocol.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';

void main() {
  test('registers CLOVA as a static API-key provider with native protocol', () {
    final connector = LlmConnectorRegistry.find('clova-studio');

    expect(connector?.protocol, LlmNativeProtocol.clovaStudioChat);
    expect(connector?.authTypes, {'api_key'});
    expect(connector?.modelCatalog, kClovaStudioModelIds);
    expect(
      builtinDefaultApiProtocolForConnector('clova-studio'),
      kClovaStudioProtocolId,
    );
    expect(
      supportedApiProtocolsForSupplier(null, connectorType: 'clova-studio'),
      {kClovaStudioProtocolId},
    );
  });

  test(
    'discovers only source-listed models with their declared capabilities',
    () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentialStore(),
      );
      final models = await service.discoverModels(
        LlmAccount(
          id: 'clova',
          connectorType: 'clova-studio',
          authType: 'api_key',
          displayName: 'CLOVA Studio',
        ),
      );

      expect(
        models.map((model) => model.upstreamModelId),
        kClovaStudioModelIds,
      );
      expect(models[0].capabilities['contextLength'], 128000);
      expect(models[0].capabilities['maxOutputTokens'], 32768);
      expect(models[0].capabilities['reasoning'], isTrue);
      expect(models[1].capabilities['vision'], isTrue);
      expect(models[2].capabilities['contextLength'], 32000);
      for (final model in models) {
        expect(model.capabilities['supportedApiProtocols'], [
          kClovaStudioProtocolId,
        ]);
      }
    },
  );

  test('builds an escaped v3 URL and bearer-authenticated stream request', () {
    final account = LlmAccount(
      id: 'clova',
      connectorType: 'clova-studio',
      authType: 'api_key',
      displayName: 'CLOVA Studio',
    );
    final request = LlmNativeRequestBuilder().build(
      account: account,
      credential: 'clova-secret',
      modelId: 'HCX-005',
      body: const {'messages': []},
      stream: true,
      nativeFormat: 'clova',
    );

    expect(
      request.uri.toString(),
      'https://clovastudio.stream.ntruss.com/v3/chat-completions/HCX-005',
    );
    expect(request.headers['Authorization'], 'Bearer clova-secret');
    expect(request.headers['Accept'], contains('text/event-stream'));
  });

  test('rejects unlisted model paths and foreign protocol overrides', () {
    expect(ClovaStudioProtocol.encodeModelPathSegment('HCX/005'), 'HCX%2F005');
    expect(
      () => ClovaStudioProtocol.requestUri('unknown-model'),
      throwsArgumentError,
    );
    final account = LlmAccount(
      id: 'clova',
      connectorType: 'clova-studio',
      authType: 'api_key',
      displayName: 'CLOVA Studio',
    );
    expect(
      () => LlmNativeRequestBuilder().build(
        account: account,
        credential: 'clova-secret',
        modelId: 'HCX-005',
        body: const {},
        nativeFormat: 'openai.chat_completions',
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
  });
}

class _MemoryPreferences implements LlmAccountPreferences {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<bool> remove(String key) async => true;

  @override
  Future<bool> setString(String key, String value) async => true;
}

class _MemoryCredentialStore implements LlmCredentialStore {
  @override
  Future<void> delete(String reference) async {}

  @override
  Future<String?> read(String reference) async => null;

  @override
  Future<void> write(String reference, String secret) async {}
}
