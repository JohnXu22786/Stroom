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

  group('StartupApp - startup checks integration', () {
    test('detects stale format version and performs migration', () async {
      // Simulate an old format version
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': jsonEncode([
          {'id': 'old_provider', 'type': 'llm', 'name': 'Old', 'configs': []},
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String()
          },
        ]),
      });
      AppStorage.resetCache();

      // Run the startup check (this is called by StartupApp._runStartupSequence)
      final migrationResult = await StartupCheckService.checkFormatVersion();
      expect(migrationResult.needsMigration, isTrue);

      // After migration:
      final prefs = await SharedPreferences.getInstance();
      // Version should be updated
      expect(prefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
    });

    test('no migration needed when format version is current', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Normal',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // Should detect no migration needed
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.isEmpty, isTrue);
    });

    test('validates data formats without crash recovery', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test Provider',
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

      // Validate data formats (does not involve crash recovery)
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });
  });
}
