import 'dart:convert';
import 'dart:io';

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

  group('StartupCheckService - format version check', () {
    test('returns needsMigration=false when version matches', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'data_format_version', DataMigrationService.currentFormatVersion);

      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isFalse);
    });

    test('returns needsMigration=true when version is stale', () async {
      // No version set (defaults to 0)
      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isTrue);
    });

    test('returns needsMigration=false when version is newer', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 999);

      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isFalse);
    });
  });

  group('StartupCheckService - data format validation', () {
    test('validates provider_entries JSON structure', () async {
      final prefs = await SharedPreferences.getInstance();
      // Valid provider_entries
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'test_id',
              'type': 'llm',
              'name': 'Test Provider',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      // No issues expected with valid data
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });

    test('detects malformed provider_entries JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_entries', 'not valid json');
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      // Should have at least one error about malformed provider_entries
      expect(
        issues.any((i) =>
            i.severity == StartupIssueSeverity.error &&
            i.message.contains('provider_entries')),
        isTrue,
      );
    });

    test('detects provider_entries with null IDs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': null,
              'type': 'tts',
              'name': 'Broken Provider',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(
        issues.any((i) => i.message.contains('id') && i.message.contains('缺失')),
        isTrue,
      );
    });

    test('validates conversation data structure', () async {
      final prefs = await SharedPreferences.getInstance();
      // Valid conversations
      await prefs.setString(
          'conversations',
          jsonEncode([
            {
              'id': 'conv1',
              'title': 'Test',
              'messages': [],
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });

    test('detects corrupted conversation data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conversations', '{broken');
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(
        issues.any((i) =>
            i.severity == StartupIssueSeverity.error &&
            i.message.contains('conversations')),
        isTrue,
      );
    });
  });

  group('StartupCheckService - data integrity checks', () {
    test('detects orphaned provider entries with missing type registration',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'unknown_provider',
              'type': 'nonexistent_type',
              'name': 'Unknown',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.checkDataIntegrity();
      expect(
        issues.any((i) => i.message.contains('nonexistent_type')),
        isTrue,
      );
    });
  });

  group('StartupCheckService - checkFormatVersion tests', () {
    test('runs format version check and returns result', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'test_llm',
              'type': 'llm',
              'name': 'Test',
              'configs': [],
            }
          ]));
      await prefs.setString('conversations', '[]');

      final result = await StartupCheckService.checkFormatVersion();
      expect(result, isNotNull);
      // On fresh test setup without version, migration will be needed
      expect(result.needsMigration, isTrue);
    });

    test('handles empty data gracefully (no errors)', () async {
      final formatIssues = await StartupCheckService.validateDataFormats();
      final integrityIssues = await StartupCheckService.checkDataIntegrity();
      expect(formatIssues, isEmpty);
      expect(integrityIssues, isEmpty);
    });
  });

  group('StartupCheckService - conversation crash recovery', () {
    test('recovers from conversations_bak when conversations is corrupted',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conversations', '{corrupted');
      await prefs.setString(
          'conversations_bak',
          jsonEncode([
            {'id': 'conv1', 'messages': [], 'title': 'Saved'},
          ]));
      await prefs.setInt('data_format_version', 1);

      // After validateDataFormats, recovery should be possible
      final issues = await StartupCheckService.validateDataFormats();
      expect(
        issues.any((i) =>
            i.message.contains('conversations') &&
            i.severity == StartupIssueSeverity.error),
        isTrue,
      );

      // StartupCheckService should auto-recover
      final recovered = await StartupCheckService.recoverCrashData();
      expect(recovered, isTrue);

      // Conversations should now have valid data from bak
      final json = prefs.getString('conversations');
      expect(json, isNotNull);
      final list = jsonDecode(json!) as List;
      expect(list.length, equals(1));
      expect(list[0]['id'], equals('conv1'));
    });

    test('does nothing when no crash data exists', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'conversations',
          jsonEncode([
            {'id': 'conv1', 'messages': []},
          ]));
      await prefs.setInt('data_format_version', 1);

      final recovered = await StartupCheckService.recoverCrashData();
      expect(recovered, isFalse);
    });

    test('cleans up stale conversations_bak when conversations is valid',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'conversations',
          jsonEncode([
            {'id': 'conv1', 'messages': []},
          ]));
      await prefs.setString(
          'conversations_bak',
          jsonEncode([
            {'id': 'conv2', 'messages': []},
          ]));
      await prefs.setInt('data_format_version', 1);

      // Should clean up the stale bak
      final recovered = await StartupCheckService.recoverCrashData();
      expect(recovered, isTrue);
      expect(prefs.containsKey('conversations_bak'), isFalse);
    });
  });

  group('StartupCheckService - migration crash recovery', () {
    test('detects stale migration_in_progress flag and recovers', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 0);
      await prefs.setBool('migration_in_progress', true);

      // StartupCheckService should detect this and migrate
      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isTrue);

      // After migration, flag should be cleared
      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.containsKey('migration_in_progress'), isFalse);
    });
  });

  group('DataMigrationService - external backup location', () {
    test('backup directory is outside app data directory', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final appDir = await AppStorage.directory;

      // Verify they are different paths
      expect(backupRoot, isNot(equals(appDir)));
      // Backup root path should be non-empty
      expect(backupRoot.isNotEmpty, isTrue);
    });

    test('creates backup to external location', () async {
      // Create some test data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_key', 'test_value');

      final backupPath = await DataMigrationService.createBackup();
      expect(backupPath, isNotNull);

      // Verify it's a different path from app data
      final appDir = await AppStorage.directory;
      expect(backupPath, isNot(equals(appDir)));

      // Verify backup files exist
      final backupDir = Directory(backupPath!);
      expect(await backupDir.exists(), isTrue);

      // Cleanup
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
    });
  });
}
