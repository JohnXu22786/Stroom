import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/auto_backup_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
  });

  // ==================================================================
  // cleanupOldBackups — count-based retention
  // ==================================================================

  group('cleanupOldBackups', () {
    test('keeps 3 when 5 zip files exist', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create 5 dummy backup zip files with distinct timestamps
      for (int i = 0; i < 5; i++) {
        final file = File('${dir.path}/backup_2024-01-0${i + 1}T00-00-00.zip');
        await file.writeAsString('dummy_$i');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await AutoBackupService.cleanupOldBackups();

      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(3));

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('keeps all when 2 exist (<=3)', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      for (int i = 0; i < 2; i++) {
        final file = File('${dir.path}/backup_2024-01-0${i + 1}T00-00-00.zip');
        await file.writeAsString('dummy_$i');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await AutoBackupService.cleanupOldBackups();

      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(2));

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('handles mixed zip and dir backups', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 2 zips + 2 old-style dirs = 4 total → keep 3
      for (int i = 0; i < 2; i++) {
        final file = File('${dir.path}/backup_2024-01-0${i + 1}T00-00-00.zip');
        await file.writeAsString('dummy_$i');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      for (int i = 0; i < 2; i++) {
        final d = Directory('${dir.path}/backup_2024-01-0${i + 3}T00-00-00');
        await d.create(recursive: true);
        await File('${d.path}/manifest.json').writeAsString('{}');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await AutoBackupService.cleanupOldBackups();

      final entries = await dir.list().toList();
      int count = 0;
      for (final e in entries) {
        if (e is File && e.path.endsWith('.zip')) count++;
        if (e is Directory && e.path.contains('backup_')) count++;
      }
      expect(count, equals(3));

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('is idempotent when no backups exist', () async {
      // Should not throw
      await AutoBackupService.cleanupOldBackups();
    });
  });

  // ==================================================================
  // Cancellation
  // ==================================================================

  group('cancellation', () {
    test('BackupService.createBackup throws BackupCancelledException',
        () async {
      expect(
        () => BackupService.createBackup(
          outputPath: '/tmp/test_cancel.zip',
          isCancelled: () => true,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
    });

    test('performAutoBackup returns false when cancelled during execution',
        () async {
      final future = AutoBackupService.performAutoBackup();
      AutoBackupService.cancel();
      final result = await future;
      expect(result, isFalse);
    });

    test('performAutoBackup returns false when cancel called before start',
        () async {
      // Cancel before performAutoBackup is even called
      AutoBackupService.cancel();
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isFalse);
    });
  });

  // ==================================================================
  // isRunning state
  // ==================================================================

  group('isRunning state', () {
    test('isRunning is false before and after backup', () async {
      expect(AutoBackupService.isRunning, isFalse);
      await AutoBackupService.performAutoBackup();
      expect(AutoBackupService.isRunning, isFalse);
    });

    test('second call returns false when backup is running', () async {
      final first = AutoBackupService.performAutoBackup();
      final second = await AutoBackupService.performAutoBackup();
      expect(second, isFalse);
      await first;
    });
  });

  // ==================================================================
  // performAutoBackup success path
  // ==================================================================

  group('performAutoBackup success', () {
    test('returns true on success with empty data', () async {
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);
    });

    test('creates a valid zip file in backup directory', () async {
      // Clean up any previous backup files
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Verify zip file was created
      expect(await dir.exists(), isTrue);
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(1));
      expect(zips.first.lengthSync(), greaterThan(0));

      // Cleanup
      await dir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Atomic rename (tmp -> zip)
  // ==================================================================

  group('atomic rename (tmp -> zip)', () {
    test(
        'performAutoBackup creates .tmp file during backup and renames to .zip',
        () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Verify zip file was created (not .tmp)
      expect(await dir.exists(), isTrue);
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      final tmps = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(zips.length, equals(1),
          reason: 'Should create a .zip file after rename');
      expect(tmps, isEmpty,
          reason: 'Should not leave .tmp files after successful backup');
      expect(zips.first.lengthSync(), greaterThan(0));

      // Cleanup
      await dir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Tmp file cleanup on backup start
  // ==================================================================

  group('tmp file cleanup on next backup start', () {
    test('leftover .tmp files are cleaned up at start of next backup',
        () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);

      // Create a leftover .tmp file simulating an interrupted backup
      final tmpFile = File('${dir.path}/backup_leftover.tmp');
      await tmpFile.writeAsString('leftover_data');

      // Also create some valid zip files
      for (int i = 0; i < 2; i++) {
        final file = File('${dir.path}/backup_2024-01-0${i + 1}T00-00-00.zip');
        await file.writeAsString('dummy_$i');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Run backup - should clean up tmp files first
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Verify no .tmp files remain
      final entries = await dir.list().toList();
      final tmps = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(tmps, isEmpty, reason: 'Should clean up leftover .tmp files');

      // Cleanup
      await dir.delete(recursive: true);
    });
  });

  // ==================================================================
  // DataMigrationService delegation
  // ==================================================================

  group('DataMigrationService delegation', () {
    test('cleanOldBackups delegates to AutoBackupService', () async {
      await DataMigrationService.cleanOldBackups();
    });
  });
}
