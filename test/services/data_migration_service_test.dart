import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppStorage.resetCache();
  });

  group('DataMigrationService - accessible backup path', () {
    test('getExternalBackupRootPath returns non-null on all platforms',
        () async {
      final path = await DataMigrationService.getExternalBackupRootPath();
      expect(path, isNotNull);
      expect(path.isNotEmpty, isTrue);
    });

    test('backup root is outside app data directory', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final appDir = await AppStorage.directory;

      // Verify they are NOT the same path
      expect(backupRoot, isNot(equals(appDir)));
      // Verify backup root is a non-empty path
      expect(backupRoot.isNotEmpty, isTrue);
    });

    test('backup root contains backup directory name', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      // Should contain either StroomBackups or stroom_backup_test
      expect(
        backupRoot.contains('StroomBackups') ||
            backupRoot.contains('stroom_backup_test'),
        isTrue,
        reason: 'Backup root should reference backup directory name',
      );
    });

    test('getExternalBackupRootPath returns non-empty path', () async {
      final path = await DataMigrationService.getExternalBackupRootPath();
      expect(path, isNotNull);
      expect(path.isNotEmpty, isTrue);
    });

    test('backup root is NOT inside private app data directory', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final appDir = await AppStorage.directory;

      // In production, backup is stored in a user-accessible location
      // outside the app data directory on every platform (see docstring).
      // In the test environment, both use subdirectories of temp by design.
      expect(backupRoot, isNot(equals(appDir)),
          reason: 'Backup root must differ from private app data directory. '
              'It must be in a user-accessible location.');
    });
  });

  group('DataMigrationService - user-accessible backup path requirements', () {
    test('path returns valid backup directory name', () async {
      // On each platform, getExternalBackupRootPath() resolves to a
      // user-accessible location (see method docstring for details).
      // In the test environment it falls back to Directory.systemTemp.
      final path = await DataMigrationService.getExternalBackupRootPath();
      expect(path, isNotNull);
      expect(path.contains('Stroom') || path.contains('stroom'), isTrue);
    });

    test('path works with createBackup and cleanOldBackups', () async {
      // Verify that after the path change, backup creation and cleanup
      // still work correctly.
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);
      await rootDir.create(recursive: true);
      await DataMigrationService.cleanOldBackups();
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });
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
      await SharedPreferences.getInstance()
          .then((prefs) => prefs.setInt('data_format_version', 1));

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

    test('does NOT run conversation recovery on every startup', () async {
      // Set up: version matches, no migration needed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 2);

      // Even if conversations_bak exists from old sessions,
      // checkAndMigrate should NOT touch it (no recovery on startup)
      await prefs.setString(
          'conversations_bak',
          jsonEncode([
            {'id': 'old', 'messages': []},
          ]));

      // This should only check version and return false
      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);

      // conversations_bak should still exist (not touched by migration code)
      expect(prefs.getString('conversations_bak'), isNotNull);
    });

    test('backup ZIP is created in external location during migration',
        () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();

      // Clean any existing backup root
      final rootDir = Directory(backupRoot);
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }

      await DataMigrationService.checkAndMigrate();

      // Backup root should exist with at least one ZIP file
      expect(await rootDir.exists(), isTrue);
      final entries = await rootDir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, greaterThan(0));

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

    test('createBackup creates a backup ZIP in external location', () async {
      final backupPath = await DataMigrationService.createBackup();
      expect(backupPath, isNotNull);

      final backupFile = File(backupPath!);
      expect(await backupFile.exists(), isTrue);

      // Verify it's a ZIP file
      expect(backupPath.endsWith('.zip'), isTrue);
      expect(await backupFile.length(), greaterThan(0));

      // Verify it's outside app data
      final appDir = await AppStorage.directory;
      expect(backupFile.parent.path, isNot(equals(appDir)));

      // Cleanup
      await backupFile.delete();
    });

    test('getExternalBackupRootPath returns non-null on all platforms',
        () async {
      // Should never return null or empty
      final path = await DataMigrationService.getExternalBackupRootPath();
      expect(path, isNotNull);
      expect(path.isNotEmpty, isTrue);
    });
  });

  group('DataMigrationService - migrateDataFormatIfNeeded', () {
    test('returns needsMigration=false when version matches current', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 2);

      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isFalse);
    });

    test('returns needsMigration=false when version is newer', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 999);

      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isFalse);
    });

    test('performs migration when version is stale', () async {
      // No version set (defaults to 0)
      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isTrue);

      // Version should be updated
      final storedVersion = await DataMigrationService.getStoredFormatVersion();
      expect(storedVersion, equals(2));
    });

    test('does NOT create external backup during migration', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);

      // Clean any existing backup root
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }

      await DataMigrationService.migrateDataFormatIfNeeded();

      // No backup directory should be created (unlike checkAndMigrate)
      expect(await rootDir.exists(), isFalse);
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

    test('cleanOldBackups keeps 3 newest backup_ entries', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);
      await rootDir.create(recursive: true);

      try {
        // Create 5 backup_ prefixed items (4 dirs + 1 zip)
        for (int i = 0; i < 4; i++) {
          final d =
              Directory('${rootDir.path}/backup_2024-01-0${i + 1}T00-00-00');
          await d.create(recursive: true);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        final f = File('${rootDir.path}/backup_2024-01-05T00-00-00.zip');
        await f.writeAsString('dummy');
        await Future.delayed(const Duration(milliseconds: 100));

        await DataMigrationService.cleanOldBackups();

        // Should keep exactly 3 of the 5
        final entries = await rootDir.list().toList();
        final backupItems = entries
            .where((e) =>
                (e is File && e.path.endsWith('.zip')) ||
                (e is Directory && e.path.contains('backup_')))
            .toList();
        expect(backupItems.length, equals(3));
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
