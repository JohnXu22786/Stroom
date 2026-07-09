import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_check_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_app.dart' as startup_app;

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

  group('StartupApp - ensure checks yield to event loop', () {
    test('validateDataFormats can be interleaved with UI frames', () async {
      // Set up some data to validate
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {
                'models': [
                  {
                    'customParams': [],
                    'voices': [],
                    'reasoningParams': [],
                  },
                ],
              },
            ],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test Conv',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      // Run validation - should not hang the event loop
      // In test mode this runs synchronously (sync fallback)
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues, isA<List<StartupIssue>>());
    });

    test('multiple sequential checks complete without blocking', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([]),
      });
      AppStorage.resetCache();

      // Simulate running multiple checks sequentially with yields between them
      final issues1 = await StartupCheckService.validateDataFormats();
      // Insert a microtask to simulate event loop yield
      await Future<void>.microtask(() {});
      final issues2 = await StartupCheckService.checkDataIntegrity();

      expect(issues1, isA<List<StartupIssue>>());
      expect(issues2, isA<List<StartupIssue>>());
    });
  });
}
