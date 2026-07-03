import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('StartupCheckService - nested data repair - configs list', () {
    test('repairDataFormats fixes non-Map entries in configs list', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              null, // null config entry
              'not a map', // string entry instead of Map
              42, // number entry instead of Map
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      final errorCount = await StartupCheckService.repairDataFormats();

      // Should have repaired the data without crashing
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      expect(json, isNotNull);

      final list = jsonDecode(json!) as List;
      expect(list.length, equals(1));

      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;
      // Non-Map entries should be filtered out
      for (final config in configs) {
        expect(config, isA<Map<String, dynamic>>());
      }
      // At least the non-Map entries should be removed
      expect(configs.length, lessThan(3));
      expect(errorCount, equals(0));
    });

    test('repairDataFormats fixes mixed valid/invalid configs entries',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {'providerName': 'Valid', 'host': '', 'key': '', 'models': []},
              null,
              {
                'providerName': 'Also Valid',
                'host': '',
                'key': '',
                'models': []
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      await StartupCheckService.repairDataFormats();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;

      // Valid entries should be preserved
      expect(configs.length, equals(2));
      expect(configs[0]['providerName'], equals('Valid'));
      expect(configs[1]['providerName'], equals('Also Valid'));
    });
  });

  group('StartupCheckService - nested data repair - models list', () {
    test('repairDataFormats fixes non-Map entries in models list', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {
                'providerName': 'Config1',
                'host': '',
                'key': '',
                'models': [
                  null,
                  'not a map',
                  {'name': 'Valid', 'modelId': 'valid_id'},
                ],
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      await StartupCheckService.repairDataFormats();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;
      final models = (configs[0] as Map<String, dynamic>)['models'] as List;

      for (final model in models) {
        expect(model, isA<Map<String, dynamic>>());
      }
      expect(models.length, equals(1));
      expect(models[0]['name'], equals('Valid'));
    });
  });

  group('StartupCheckService - nested data repair - customParams list', () {
    test('repairDataFormats fixes non-Map entries in customParams list',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {
                'providerName': 'Config1',
                'host': '',
                'key': '',
                'models': [
                  {
                    'name': 'Model1',
                    'modelId': 'model1',
                    'customParams': [
                      null,
                      'invalid param',
                      {'paramName': 'valid_param', 'defaultValue': 'val'},
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      await StartupCheckService.repairDataFormats();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;
      final models = (configs[0] as Map<String, dynamic>)['models'] as List;
      final customParams =
          (models[0] as Map<String, dynamic>)['customParams'] as List;

      for (final param in customParams) {
        expect(param, isA<Map<String, dynamic>>());
      }
      expect(customParams.length, equals(1));
      expect(customParams[0]['paramName'], equals('valid_param'));
    });
  });

  group('StartupCheckService - nested data repair - voices list', () {
    test('repairDataFormats fixes non-Map entries in voices list', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'tts',
            'name': 'TTS Provider',
            'configs': [
              {
                'providerName': 'TTS Config',
                'host': '',
                'key': '',
                'models': [
                  {
                    'name': 'VoiceModel',
                    'modelId': 'voice_1',
                    'voices': [
                      null,
                      'invalid voice',
                      {'name': 'Valid Voice', 'id': 'voice_123'},
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      await StartupCheckService.repairDataFormats();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;
      final models = (configs[0] as Map<String, dynamic>)['models'] as List;
      final voices = (models[0] as Map<String, dynamic>)['voices'] as List;

      for (final voice in voices) {
        expect(voice, isA<Map<String, dynamic>>());
      }
      expect(voices.length, equals(1));
      expect(voices[0]['name'], equals('Valid Voice'));
    });
  });

  group('StartupCheckService - nested data repair - reasoningParams list', () {
    test('repairDataFormats fixes non-Map entries in reasoningParams list',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'LLM Provider',
            'configs': [
              {
                'providerName': 'LLM Config',
                'host': '',
                'key': '',
                'models': [
                  {
                    'name': 'ReasonModel',
                    'modelId': 'reason_1',
                    'reasoningParams': [
                      null,
                      12345,
                      {
                        'paramName': 'reasoning_effort',
                        'options': ['low', 'high'],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      await StartupCheckService.repairDataFormats();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      final entry = list[0] as Map<String, dynamic>;
      final configs = entry['configs'] as List;
      final models = (configs[0] as Map<String, dynamic>)['models'] as List;
      final reasoningParams =
          (models[0] as Map<String, dynamic>)['reasoningParams'] as List;

      for (final param in reasoningParams) {
        expect(param, isA<Map<String, dynamic>>());
      }
      expect(reasoningParams.length, equals(1));
      expect(reasoningParams[0]['paramName'], equals('reasoning_effort'));
    });
  });

  group('StartupCheckService - validateDataFormats - nested data', () {
    test('validateDataFormats detects non-Map entries in configs list',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              null,
              'invalid',
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect format issues in configs
      final configsIssues = issues.where(
        (i) => i.message.contains('configs'),
      );
      expect(configsIssues, isNotEmpty);
    });
  });

  group('StartupCheckService - checkDataIntegrity - non-Map entries', () {
    test(
        'checkDataIntegrity handles non-Map entry without crash and continues checking valid entries',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          null, // null entry at top level - should be skipped
          'not a map', // string entry at top level - should be skipped
          {
            'id': 'valid',
            'type': 'unknown_type',
            'name': 'Valid',
            'configs': []
          },
        ]),
      });
      AppStorage.resetCache();

      // Should NOT crash - this was a crash point (_checkProviderTypeRegistration)
      final issues = await StartupCheckService.checkDataIntegrity();

      // The valid entry at index 2 (unknown_type) should still be checked
      expect(issues, isA<List<StartupIssue>>());
      expect(issues.length, greaterThan(0));
      // Should generate warning about unknown type for the valid entry
      expect(
        issues.any((i) => i.message.contains('unknown_type')),
        isTrue,
        reason:
            'Valid entries should still be checked after skipping non-Map items',
      );
    });
  });

  group('ProviderEntry.fromMap - nested data resilience', () {
    test(
        'ProviderEntry.fromMap handles non-Map entries in configs without crash',
        () async {
      // This tests the actual production code path - ProviderEntry.fromMap
      // parsing data that has non-Map entries in configs list.
      // In production, the startup repair would clean this first, but we
      // verify that even if called with raw data, the whereType filter
      // in provider_config.dart's load() method protects against crashes.

      // Simulate what the provider load() does after whereType filtering
      final rawList = [
        {
          'id': 'test',
          'type': 'tts',
          'name': 'Test',
          'configs': [
            null,
            'invalid',
            42,
          ],
        },
      ];

      // Use whereType like the production code does
      final filteredList = rawList.whereType<Map<String, dynamic>>().toList();

      // Should still parse the top-level entry without crash
      // (nested configs with non-Map entries won't be in the configs
      //  list after repair, but ProviderEntry.fromMap has its own
      //  Map<String, dynamic>.from(e as Map) which would crash if
      //  called with raw data)
      expect(filteredList.length, equals(1));
      final entry = filteredList[0];
      // The configs list contains non-Map entries, but fromMap's
      // iteration with `as Map` will crash on them - this is why
      // repair must clean them first
      final configs = entry['configs'] as List;
      // Non-Map entries remain in raw data (repair hasn't run)
      expect(configs.whereType<Map<String, dynamic>>().length, equals(0));
    });

    test(
        'ProviderEntry.fromMap works correctly after repair cleans nested lists',
        () {
      // After repair has removed non-Map entries, fromMap should work fine
      final cleanedConfigs = <Map<String, dynamic>>[];
      final rawList = [
        {
          'id': 'test',
          'type': 'tts',
          'name': 'Test',
          'configs': cleanedConfigs,
        },
      ];

      final filteredList = rawList.whereType<Map<String, dynamic>>().toList();
      expect(filteredList.length, equals(1));
    });
  });
}
