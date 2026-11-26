import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_check_service.dart';

Future<List<StartupIssue>> _validateMalformedConfigParam(
  String fieldName,
  Object? malformedValue,
) async {
  SharedPreferences.setMockInitialValues({
    'data_format_version': DataMigrationService.currentFormatVersion,
    'provider_entries': jsonEncode([
      {
        'id': 'broken_provider',
        'type': 'llm',
        'name': 'Broken Provider',
        'configs': [
          {
            'providerName': 'Broken Config',
            fieldName: [malformedValue],
            'models': [],
          },
        ],
      },
      {
        'id': 'valid_provider',
        'type': 'llm',
        'name': 'Valid Provider',
        'configs': [
          {
            'providerName': 'Valid Config',
            'customParams': [
              {'paramName': 'temperature', 'defaultValue': '0.7'},
            ],
            'reasoningParams': [
              {
                'paramName': 'effort',
                'options': ['low', 'high']
              },
            ],
            'models': [],
          },
        ],
      },
    ]),
  });
  AppStorage.resetCache();

  return StartupCheckService.validateDataFormats();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
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

    test('validateDataFormats detects non-Map entries in models list',
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

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect non-Map entries in models
      final modelsIssues = issues.where(
        (i) => i.message.contains('models'),
      );
      expect(modelsIssues, isNotEmpty);
    });

    test('validateDataFormats detects non-Map entries in customParams list',
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

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect non-Map entries in customParams
      final customParamsIssues = issues.where(
        (i) => i.message.contains('customParams'),
      );
      expect(customParamsIssues, isNotEmpty);
    });

    test('validateDataFormats detects non-Map entries in voices list',
        () async {
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

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect non-Map entries in voices
      final voicesIssues = issues.where(
        (i) => i.message.contains('voices'),
      );
      expect(voicesIssues, isNotEmpty);
    });

    test('validateDataFormats detects non-Map entries in reasoningParams list',
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

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect non-Map entries in reasoningParams
      final reasoningParamsIssues = issues.where(
        (i) => i.message.contains('reasoningParams'),
      );
      expect(reasoningParamsIssues, isNotEmpty);
    });

    test('validateDataFormats detects config-level malformed customParams',
        () async {
      final issues = await _validateMalformedConfigParam('customParams', null);

      final customParamsIssues = issues
          .where((issue) => issue.message.contains('customParams'))
          .toList();
      expect(customParamsIssues, hasLength(1));
      expect(
        customParamsIssues.single.message,
        contains('provider_entries[0].configs[0].customParams[0]'),
      );
    });

    test('validateDataFormats detects config-level malformed reasoningParams',
        () async {
      final issues = await _validateMalformedConfigParam(
        'reasoningParams',
        'invalid',
      );

      final reasoningParamsIssues = issues
          .where((issue) => issue.message.contains('reasoningParams'))
          .toList();
      expect(reasoningParamsIssues, hasLength(1));
      expect(
        reasoningParamsIssues.single.message,
        contains('provider_entries[0].configs[0].reasoningParams[0]'),
      );
    });
  });

  group('StartupCheckService - validateDataFormats - mixed', () {
    test('validateDataFormats preserves valid entries and detects invalid ones',
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

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect the null entry in configs
      final configsIssues = issues.where(
        (i) => i.message.contains('configs'),
      );
      expect(configsIssues, isNotEmpty);
      // Should NOT report errors about valid entries' fields
      final idIssues = issues.where(
        (i) => i.message.contains('id') && i.message.contains('缺失'),
      );
      expect(idIssues, isEmpty);
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
    test('validateDataFormats does not crash on top-level null/s tring entries',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          null,
          'not a map',
          42,
        ]),
      });
      AppStorage.resetCache();

      // Should NOT crash - validateDataFormats has is! guard
      final issues = await StartupCheckService.validateDataFormats();

      // Should report errors for all 3 invalid entries
      final nullTypeIssues = issues.where(
        (i) => i.message.contains('provider_entries'),
      );
      expect(nullTypeIssues.length, equals(3));
    });
  });
}
