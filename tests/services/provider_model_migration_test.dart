import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/provider_model_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'normalizes legacy provider settings and keeps generated IDs on reload',
    () async {
      const legacyProvider = {
        'id': 'legacy-llm',
        'type': 'llm',
        'name': 'Legacy provider',
        'providerName': 'Example provider',
        'host': 'https://example.com',
        'key': 'test-key',
        'models': [
          {'name': 'Example model', 'modelId': 'example-model'},
        ],
      };
      final legacyJson = jsonEncode([legacyProvider]);
      final migratedJson = await ProviderModelMigration.migrateSettingsContent(
        legacyJson,
      );
      final entries = (jsonDecode(migratedJson) as List).cast<Map>();
      final entry = entries.single;
      expect(entry.containsKey('providerName'), isFalse);
      final configs = (entry['configs'] as List).cast<Map>();
      expect(configs, hasLength(1));
      final config = configs.single;
      expect(config['providerName'], 'Example provider');
      expect(config['host'], 'https://example.com');
      expect(config['key'], 'test-key');
      expect((config['id'] as String), startsWith('config_'));
      final models = (config['models'] as List).cast<Map>();
      expect(models, hasLength(1));
      expect(models.single['modelId'], 'example-model');
      expect((models.single['id'] as String), startsWith('model_'));

      expect(
        await ProviderModelMigration.migrateSettingsContent(migratedJson),
        migratedJson,
        reason: 'config and model identities stay stable on reload',
      );
    },
  );

  test('keeps equal model IDs scoped to separate provider configs', () async {
    final source = jsonEncode([
      {
        'id': 'first-llm-entry',
        'type': 'llm',
        'name': 'First provider entry',
        'configs': [
          {
            'id': 'first-config',
            'models': [
              {'id': 'shared-local-model-id', 'modelId': 'first-upstream'},
            ],
          },
        ],
      },
      {
        'id': 'second-llm-entry',
        'type': 'llm',
        'name': 'Second provider entry',
        'configs': [
          {
            'id': 'second-config',
            'models': [
              {'id': 'shared-local-model-id', 'modelId': 'second-upstream'},
            ],
          },
        ],
      },
    ]);

    final migrated = await ProviderModelMigration.migrateSettingsContent(
      source,
    );
    final entries = (jsonDecode(migrated) as List).cast<Map>();
    final firstConfig = ((entries[0]['configs'] as List).single as Map);
    final secondConfig = ((entries[1]['configs'] as List).single as Map);

    expect(
      (firstConfig['models'] as List).single['id'],
      'shared-local-model-id',
    );
    expect(
      (secondConfig['models'] as List).single['id'],
      'shared-local-model-id',
    );
  });
}
