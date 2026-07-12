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

  group('Startup checks - parallel execution', () {
    test('three checks can be started simultaneously and all complete',
        () async {
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

      // Start all three checks in parallel (as Future.wait would do)
      final results = await Future.wait([
        StartupCheckService.checkFormatVersion(),
        StartupCheckService.validateDataFormats(),
        StartupCheckService.checkDataIntegrity(),
      ]);

      expect(results.length, equals(3));

      // All results should be valid
      expect(results[0], isA<MigrationResult>());
      expect(results[1], isA<List<StartupIssue>>());
      expect(results[2], isA<List<StartupIssue>>());
    });

    test('parallel checks do not interfere with each other', () async {
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

      // Run all checks in parallel
      final results = await Future.wait([
        StartupCheckService.checkFormatVersion(),
        StartupCheckService.validateDataFormats(),
        StartupCheckService.checkDataIntegrity(),
      ]);

      // Format version check
      expect((results[0] as MigrationResult).needsMigration, isFalse);

      // Data format validation should find the empty id error
      final formatIssues = results[1] as List<StartupIssue>;
      final emptyIdIssues =
          formatIssues.where((i) => i.message.contains('id 字段缺失'));
      expect(emptyIdIssues.length, greaterThanOrEqualTo(1));

      // Data integrity check should find the unknown type warning
      final integrityIssues = results[2] as List<StartupIssue>;
      final unknownTypeIssues =
          integrityIssues.where((i) => i.message.contains('未知的供应商类型'));
      expect(unknownTypeIssues.length, greaterThanOrEqualTo(1));
    });

    test('parallel checks return quickly without blocking', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([]),
        'conversations': jsonEncode([]),
      });
      AppStorage.resetCache();

      final stopwatch = Stopwatch()..start();

      // Run all checks in parallel
      await Future.wait([
        StartupCheckService.checkFormatVersion(),
        StartupCheckService.validateDataFormats(),
        StartupCheckService.checkDataIntegrity(),
      ]);

      stopwatch.stop();

      // Parallel execution should be fast (comparable to the slowest single check)
      // Each check individually is fast, so all three in parallel should also be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
