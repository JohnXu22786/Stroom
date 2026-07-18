import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_check_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('Startup checks - sequential execution', () {
    test('three checks run sequentially and all complete', () async {
      // Set up realistic test data
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      // Run each check sequentially (one after another, not in parallel)
      final result1 = await StartupCheckService.checkFormatVersion();
      final result2 = await StartupCheckService.validateDataFormats();
      final result3 = await StartupCheckService.checkDataIntegrity();

      // All results should be valid
      expect(result1, isA<MigrationResult>());
      expect(result2, isA<List<StartupIssue>>());
      expect(result3, isA<List<StartupIssue>>());
    });

    test('sequential checks do not interfere with each other', () async {
      // Set up data with format issues
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': '', // Empty id → error
            'type': 'unknown_type', // Unknown type → warning
            'name': 'Test',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      // Run each check sequentially
      final migrationResult = await StartupCheckService.checkFormatVersion();
      final formatIssues = await StartupCheckService.validateDataFormats();
      final integrityIssues = await StartupCheckService.checkDataIntegrity();

      // Format version check
      expect(migrationResult.needsMigration, isFalse);

      // Data format validation should find the empty id error
      final emptyIdIssues =
          formatIssues.where((i) => i.message.contains('id 字段缺失'));
      expect(emptyIdIssues.length, greaterThanOrEqualTo(1));

      // Data integrity check should find the unknown type warning
      final unknownTypeIssues =
          integrityIssues.where((i) => i.message.contains('未知的供应商类型'));
      expect(unknownTypeIssues.length, greaterThanOrEqualTo(1));
    });

    test('sequential checks complete without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([]),
        'conversations': jsonEncode([]),
      });
      AppStorage.resetCache();

      // Run each check sequentially with yields in between
      final r1 = await StartupCheckService.checkFormatVersion();
      // Yield to event loop between checks (simulates UI frame)
      await Future<void>.microtask(() {});
      final r2 = await StartupCheckService.validateDataFormats();
      await Future<void>.microtask(() {});
      final r3 = await StartupCheckService.checkDataIntegrity();

      // All checks should complete with valid results
      expect(r1, isA<MigrationResult>());
      expect(r2, isA<List<StartupIssue>>());
      expect(r3, isA<List<StartupIssue>>());
      // No results should be null
      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r3, isNotNull);
    });
  });
}
