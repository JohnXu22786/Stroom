import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('DataMigrationService - format version', () {
    test('returns current format version constant', () {
      expect(DataMigrationService.currentFormatVersion, equals(1));
    });

    test('default stored version is 0 (not yet set)', () async {
      final version = await DataMigrationService.getStoredFormatVersion();
      expect(version, equals(0));
    });

    test('returns stored version when previously set', () async {
      await SharedPreferences.getInstance().then((prefs) =>
        prefs.setInt('data_format_version', 1)
      );

      final version = await DataMigrationService.getStoredFormatVersion();
      expect(version, equals(1));
    });
  });

  group('DataMigrationService - checkAndMigrate', () {
    test('no migration needed when version matches current', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 1);

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);
      expect(result.restartRequired, isFalse);
    });

    test('no migration needed when version is newer than current', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 999);

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);
    });

    test('migration needed when no version stored', () async {
      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);
      expect(result.restartRequired, isFalse);

      // After migration, version should be updated
      final storedVersion = await DataMigrationService.getStoredFormatVersion();
      expect(storedVersion, equals(1));
    });

    test('subsequent call does not need migration', () async {
      // First migration
      final result1 = await DataMigrationService.checkAndMigrate();
      expect(result1.needsMigration, isTrue);

      // Second call - should not need migration
      final result2 = await DataMigrationService.checkAndMigrate();
      expect(result2.needsMigration, isFalse);
    });

    test('backup directory is created during migration', () async {
      // Clean any existing backup
      final appDir = await AppStorage.directory;
      final backupRoot = Directory('${appDir}/data_backup');
      if (await backupRoot.exists()) {
        await backupRoot.delete(recursive: true);
      }

      await DataMigrationService.checkAndMigrate();

      // Backup should exist (at least one subdirectory)
      expect(await backupRoot.exists(), isTrue);
      final entries = await backupRoot.list().toList();
      expect(entries.length, greaterThan(0));
    });
  });

  group('DataMigrationService - backup', () {
    setUp(() async {
      // Ensure migration is in known state
      await DataMigrationService.checkAndMigrate();
      // Reset mock prefs for clean backup test
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'test_key': 'test_value',
      });
      AppStorage.resetCache();
    });

    test('createBackup creates a backup directory with manifest', () async {
      final backupPath = await DataMigrationService.createBackup();
      expect(backupPath, isNotNull);

      // Verify backup directory exists
      final backupDir = Directory(backupPath!);
      expect(await backupDir.exists(), isTrue);

      // Verify manifest file exists
      final manifestFile = File('${backupDir.path}/manifest.json');
      expect(await manifestFile.exists(), isTrue);

      // Verify manifest content
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      expect(manifest['backupType'], equals('pre_migration'));

      // Verify preferences backup
      final prefsFile = File('${backupDir.path}/preferences.json');
      expect(await prefsFile.exists(), isTrue);

      // Cleanup
      await backupDir.delete(recursive: true);
    });
  });

  group('DataMigrationService - cleanup', () {
    test('cleanOldBackups handles empty backup directory', () async {
      final appDir = await AppStorage.directory;
      final backupRoot = Directory('${appDir}/data_backup');

      // Should not throw when directory doesn't exist
      if (await backupRoot.exists()) {
        await backupRoot.delete(recursive: true);
      }
      await DataMigrationService.cleanOldBackups();
      // No exception = test passes
    });

    test('cleanOldBackups keeps recent backups', () async {
      final appDir = await AppStorage.directory;
      final backupRoot = Directory('${appDir}/data_backup');
      await backupRoot.create(recursive: true);

      try {
        // Create a recent backup
        final recentDir = Directory('${backupRoot.path}/recent_backup');
        await recentDir.create(recursive: true);

        await DataMigrationService.cleanOldBackups();

        // Recent backup should still exist
        expect(await recentDir.exists(), isTrue);
      } finally {
        if (await backupRoot.exists()) {
          await backupRoot.delete(recursive: true);
        }
      }
    });

    test('cleanOldBackups does not crash on invalid entries', () async {
      final appDir = await AppStorage.directory;
      final backupRoot = Directory('${appDir}/data_backup');
      await backupRoot.create(recursive: true);

      try {
        // Create a file (not a directory) in the backup root
        final file = File('${backupRoot.path}/not_a_dir');
        await file.writeAsString('test');

        // Should not throw when encountering non-directory entries
        await DataMigrationService.cleanOldBackups();
      } finally {
        if (await backupRoot.exists()) {
          await backupRoot.delete(recursive: true);
        }
      }
    });
  });
}
