import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([legacyProvider]),
      });

      await ProviderModelMigration.migrateSettings();

      final preferences = await SharedPreferences.getInstance();
      final migratedJson = preferences.getString('provider_entries')!;
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

      await ProviderModelMigration.migrateSettings();

      expect(
        preferences.getString('provider_entries'),
        migratedJson,
        reason: 'persisted config and model identities stay stable on reload',
      );
    },
  );
}
