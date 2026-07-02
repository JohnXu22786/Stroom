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

  group('StartupCheckService - data repair', () {
    test('validateDataFormats detects null id in provider_entries', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {'type': 'tts', 'name': 'Broken Provider'}, // missing 'id'
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect the null/missing id
      final idIssues = issues.where(
        (i) =>
            i.message.contains('id') &&
            i.severity == StartupIssueSeverity.error,
      );
      expect(idIssues, isNotEmpty);
    });

    test('validateDataFormats handles null type field', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {'id': 'test_id', 'name': 'No Type'}, // missing 'type'
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      final typeIssues = issues.where(
        (i) => i.message.contains('type') || i.message.contains('id'),
      );
      expect(typeIssues, isNotEmpty);
    });

    test('validateDataFormats handles null entry in list', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          null, // null entry
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      final nullEntryIssues = issues.where(
        (i) => i.message.contains('null'),
      );
      expect(nullEntryIssues, isNotEmpty);
    });

    test('validateDataFormats handles malformed JSON', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': 'not valid json {{{',
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      final formatIssues = issues.where(
        (i) => i.message.contains('格式错误') || i.message.contains('JSON'),
      );
      expect(formatIssues, isNotEmpty);
    });

    test('validateDataFormats returns no issues for valid data', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {'id': 'valid_id', 'type': 'tts', 'name': 'Valid', 'configs': []},
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
          },
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      expect(
        issues.where((i) => i.severity == StartupIssueSeverity.error),
        isEmpty,
      );
    });
  });

  group('DataMigrationService - null id repair', () {
    test('_performMigration fixes null ids in provider_entries (v0→v1)',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([
          {'type': 'tts', 'name': 'Null ID Entry'}, // no id
        ]),
      });
      AppStorage.resetCache();

      await DataMigrationService.checkAndMigrate();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      expect(json, isNotNull);

      final list = jsonDecode(json!) as List;
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        expect(map['id'], isNotNull,
            reason: 'id should not be null after migration');
        expect((map['id'] as String).isNotEmpty, isTrue);
      }
    });

    test('migrateDataFormatIfNeeded also fixes null ids', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([
          {'type': 'llm', 'name': 'Null ID LLM'}, // no id
          {'id': null, 'type': 'tts', 'name': 'Null ID TTS'}, // null id
        ]),
      });
      AppStorage.resetCache();

      await DataMigrationService.migrateDataFormatIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      expect(json, isNotNull);

      final list = jsonDecode(json!) as List;
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        expect(map['id'], isNotNull);
        expect((map['id'] as String).isNotEmpty, isTrue);
      }
    });

    test('already migrated data is not affected by re-migration', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'already_valid_id',
            'type': 'tts',
            'name': 'Already Valid',
            'configs': [],
          },
        ]),
      });
      AppStorage.resetCache();

      // Should not throw or corrupt data
      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      expect((list[0] as Map)['id'], equals('already_valid_id'));
    });

    test('empty provider_entries survives migration', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([]),
      });
      AppStorage.resetCache();

      await DataMigrationService.checkAndMigrate();

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('provider_entries');
      final list = jsonDecode(json!) as List;
      expect(list, isEmpty, reason: 'empty list should remain empty');
    });
  });

  group('DataMigrationService - v1→v2 migration edge cases', () {
    test('migration from v1 to v2 handles null provider_entries', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        // No provider_entries set at all
      });
      AppStorage.resetCache();

      await DataMigrationService.checkAndMigrate();

      final storedVersion = await DataMigrationService.getStoredFormatVersion();
      expect(storedVersion, equals(DataMigrationService.currentFormatVersion));

      final prefs = await SharedPreferences.getInstance();
      // Should NOT have created provider_entries (migration only modifies existing)
      expect(prefs.containsKey('provider_entries'), isFalse);
    });
  });
}
