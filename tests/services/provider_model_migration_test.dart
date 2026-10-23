import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/provider_model_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
