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
  });
}
