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

  group('StartupApp - crash recovery integration', () {
    test('detects and recovers from stale migration_in_progress flag',
        () async {
      // Simulate a crash mid-migration
      SharedPreferences.setMockInitialValues({
        'migration_in_progress': true,
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
      // migration_in_progress should be cleared
      expect(prefs.containsKey('migration_in_progress'), isFalse);
      // Version should be updated
      expect(prefs.getInt('data_format_version'),
          equals(DataMigrationService.currentFormatVersion));
    });

    test('recovers conversations from bak when main is corrupted', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'conversations': 'broken json {{{',
        'conversations_bak': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Recovered',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // The recovery step should fix conversations
      final recovered = await StartupCheckService.recoverCrashData();
      expect(recovered, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('conversations');
      expect(json, isNotNull);
      final list = jsonDecode(json!) as List;
      expect(list.length, equals(1));
      expect(list[0]['id'], equals('conv1'));

      // bak should be cleaned up
      expect(prefs.containsKey('conversations_bak'), isFalse);
    });

    test('no crash data means clean startup without recovery', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Normal',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // Should detect no crash data
      final logged = <String>[];
      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.isEmpty, isTrue);

      // Recovery should be a no-op
      final recovered = await StartupCheckService.recoverCrashData();
      expect(recovered, isFalse);
    });
  });
}
