import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/zed_keychain_import.dart';

void main() {
  group('ZedKeychainImportService', () {
    test('discovery exposes only approved provider service metadata', () async {
      final reader = _FakeKeychainReader(
        candidates: [
          _candidate('zed-openai', 'work', 'secret-one'),
          _candidate('zed-openrouter', 'other', 'secret-two'),
        ],
      );
      final service = ZedKeychainImportService(
        reader: reader,
        saveAccount: (account, {required secret}) async => account,
      );

      final candidates = await service.discover();

      expect(candidates, hasLength(1));
      expect(candidates.single.provider, 'openai');
      expect(candidates.single.service, 'zed-openai');
      expect(candidates.single.account, 'work');
      expect(candidates.single.fingerprint, isNot(contains('secret-one')));
      expect(reader.reads, isEmpty);
    });

    test('rejects stale keychain values before account persistence', () async {
      final candidate = _candidate('zed-openai', 'work', 'old-secret');
      final reader = _FakeKeychainReader(
        candidates: [candidate],
        secret: 'rotated-secret',
      );
      var saves = 0;
      final service = ZedKeychainImportService(
        reader: reader,
        saveAccount: (account, {required secret}) async {
          saves++;
          return account;
        },
      );

      await expectLater(
        service.importConfirmed(candidate),
        throwsA(isA<ZedKeychainImportException>()),
      );

      expect(reader.reads, ['zed-openai/work']);
      expect(saves, 0);
    });

    test('imports as the selected vendor API-key account', () async {
      const secret = 'openai-live-key';
      final candidate = _candidate('zed-openai', 'personal', secret);
      final reader =
          _FakeKeychainReader(candidates: [candidate], secret: secret);
      AiGatewayAccount? savedAccount;
      String? savedSecret;
      final service = ZedKeychainImportService(
        reader: reader,
        saveAccount: (account, {required secret}) async {
          savedAccount = account;
          savedSecret = secret;
          return account;
        },
      );

      final account = await service.importConfirmed(candidate);

      expect(account.connectorType, 'openai-api');
      expect(account.authType, 'api_key');
      expect(account.displayName, contains('OpenAI'));
      expect(account.hasCredential, isTrue);
      expect(savedAccount?.connectorType, 'openai-api');
      expect(savedSecret, secret);
      expect(account.endpointConfig['sourceProvider'], 'openai');
    });

    test('keeps all five Zed provider identities on vendor-compatible routes',
        () async {
      const expected = {
        'zed-openai': 'openai-api',
        'zed-anthropic': 'claude',
        'zed-google': 'gemini',
        'zed-mistral': 'openai-compatibility',
        'zed-xai': 'xai',
      };
      for (final entry in expected.entries) {
        final candidate = _candidate(entry.key, 'account', 'vendor-key');
        final service = ZedKeychainImportService(
          reader: _FakeKeychainReader(
              candidates: [candidate], secret: 'vendor-key'),
          saveAccount: (account, {required secret}) async => account,
        );

        final account = await service.importConfirmed(candidate);

        expect(account.connectorType, entry.value, reason: entry.key);
        expect(account.authType, 'api_key', reason: entry.key);
        expect(
          LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
            account.connectorType,
            account.authType,
          ),
          isTrue,
          reason: '${entry.key} must use the shared Chat and Task Flow route',
        );
        expect(account.endpointConfig['sourceProvider'], candidate.provider);
        expect(account.displayName, contains(candidate.account));
      }
    });
  });
}

ZedKeychainCredentialCandidate _candidate(
  String service,
  String account,
  String secret,
) =>
    ZedKeychainCredentialCandidate(
      provider:
          ZedKeychainImportService.providerForService(service) ?? 'unknown',
      service: service,
      account: account,
      fingerprint:
          ZedKeychainImportService.fingerprint(service, account, secret),
    );

class _FakeKeychainReader implements ZedKeychainReader {
  _FakeKeychainReader({required this.candidates, String? secret})
      : _secret = secret;

  final List<ZedKeychainCredentialCandidate> candidates;
  final String? _secret;
  final List<String> reads = [];

  @override
  Future<List<ZedKeychainCredentialCandidate>> discover() async => candidates;

  @override
  Future<String?> readSecret(String service, String account) async {
    reads.add('$service/$account');
    return _secret;
  }
}
