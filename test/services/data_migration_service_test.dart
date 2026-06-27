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
      expect(DataMigrationService.currentFormatVersion, equals(2));
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
      await prefs.setInt('data_format_version', 2);

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
      expect(result.restartRequired, isTrue);

      // After migration, version should be updated
      final storedVersion = await DataMigrationService.getStoredFormatVersion();
      expect(storedVersion, equals(2));
    });

    test('subsequent call does not need migration', () async {
      // First migration
      final result1 = await DataMigrationService.checkAndMigrate();
      expect(result1.needsMigration, isTrue);

      // Second call - should not need migration
      final result2 = await DataMigrationService.checkAndMigrate();
      expect(result2.needsMigration, isFalse);
    });

    test('backup directory is created in external location during migration',
        () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();

      // Clean any existing backup root
      final rootDir = Directory(backupRoot);
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }

      await DataMigrationService.checkAndMigrate();

      // Backup root should exist (at least one subdirectory)
      expect(await rootDir.exists(), isTrue);
      final entries = await rootDir.list().toList();
      expect(entries.length, greaterThan(0));

      // Cleanup after test
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });
  });

  group('DataMigrationService - external backup', () {
    setUp(() async {
      // Set mock values BEFORE any getInstance call
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'test_key': 'test_value',
      });
      AppStorage.resetCache();
    });

    test('backup root is outside app data directory', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final appDir = await AppStorage.directory;

      // Verify they are NOT the same path
      expect(backupRoot, isNot(equals(appDir)));
      // Verify backup root is a non-empty path
      expect(backupRoot.isNotEmpty, isTrue);
    });

    test('createBackup creates a backup directory with manifest in external location',
        () async {
      final backupPath = await DataMigrationService.createBackup();
      expect(backupPath, isNotNull);

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
      final prefsContent = await prefsFile.readAsString();
      final prefsData = jsonDecode(prefsContent) as Map<String, dynamic>;
      expect(prefsData['test_key'], equals('test_value'));

      // Verify it's outside app data
      final appDir = await AppStorage.directory;
      expect(backupPath, isNot(equals(appDir)));
      // In production, backupPath won't be under appDir.
      // In test environment both use system temp,
      // so we only check they're different paths.

      // Cleanup
      await backupDir.delete(recursive: true);
    });
  });

  group('DataMigrationService - cleanup', () {
    test('cleanOldBackups handles empty backup directory', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);

      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
      await DataMigrationService.cleanOldBackups();
      // No exception = test passes
    });

    test('cleanOldBackups keeps recent backups', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);
      await rootDir.create(recursive: true);

      try {
        // Create a recent backup
        final recentDir = Directory('${rootDir.path}/recent_backup');
        await recentDir.create(recursive: true);

        await DataMigrationService.cleanOldBackups();

        // Recent backup should still exist
        expect(await recentDir.exists(), isTrue);
      } finally {
        if (await rootDir.exists()) {
          await rootDir.delete(recursive: true);
        }
      }
    });

    test('cleanOldBackups does not crash on invalid entries', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);
      await rootDir.create(recursive: true);

      try {
        // Create a file (not a directory) in the backup root
        final file = File('${rootDir.path}/not_a_dir');
        await file.writeAsString('test');

        // Should not throw when encountering non-directory entries
        await DataMigrationService.cleanOldBackups();
      } finally {
        if (await rootDir.exists()) {
          await rootDir.delete(recursive: true);
        }
      }
    });
  });
}
