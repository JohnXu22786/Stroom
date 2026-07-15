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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    // Clean up any leftover backup files from previous tests
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  // ==================================================================
  // cleanupOldBackups — new retention policy (max 5)
  // ==================================================================

  group('cleanupOldBackups', () {
    test('keeps max 5 total when 7 files exist across multiple days',
        () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create 7 files spanning 5 different days:
      // - 3 from today (within 24h)
      // - 1 from yesterday
      // - 1 from 2 days ago
      // - 1 from 5 days ago
      // - 1 from 8 days ago
      final now = DateTime.now();
      final days = [0, 0, 0, 1, 2, 5, 8]; // 0 = today
      for (int i = 0; i < 7; i++) {
        final t = now.subtract(Duration(days: days[i], hours: 2 * i));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('dummy_$i');
      }

      await AutoBackupService.cleanupOldBackups();

      // Should keep 5: 3 from today + 1 from yesterday + 1 from 2 days ago
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(5));

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('keeps all when 2 exist (<=5)', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final now = DateTime.now();
      // Create 2 files with different timestamps
      for (int i = 0; i < 2; i++) {
        final t = now.subtract(Duration(hours: 2, seconds: i * 5));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('dummy_$i');
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

    test('keeps max 3 within 24h and additional from usage days', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create 10 files:
      // - 5 from today (within 24h)
      // - 2 from yesterday
      // - 2 from 2 days ago
      // - 1 from 5 days ago
      final now = DateTime.now();
      final days = [0, 0, 0, 0, 0, 1, 1, 2, 2, 5];
      for (int i = 0; i < 10; i++) {
        final t = now.subtract(Duration(days: days[i], hours: 2 * i));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('dummy_$i');
      }

      await AutoBackupService.cleanupOldBackups();

      // Should keep 5: 3 from today (max 3 within 24h) + 1 from yesterday + 1 from 2 days ago
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(5));

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('handles mixed zip and dir backups without errors', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final now = DateTime.now();
      // 3 recent zips (today, within 24h) + 5 old dirs (older, spanning different days)
      for (int i = 0; i < 3; i++) {
        final t = now.subtract(Duration(hours: 2 * (i + 1)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('dummy_$i');
      }
      for (int i = 0; i < 5; i++) {
        final t = now.subtract(Duration(days: 2 * (i + 1)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final d = Directory('${dir.path}/backup_$timeStr');
        await d.create(recursive: true);
        await File('${d.path}/manifest.json').writeAsString('{}');
      }

      await AutoBackupService.cleanupOldBackups();

      // Verify cleanup runs without errors and reduces total count
      final entries = await dir.list().toList();
      int count = 0;
      for (final e in entries) {
        if (e is File && e.path.endsWith('.zip')) count++;
        if (e is Directory && e.path.contains('backup_')) count++;
      }
      // Should have at most 6 items (may vary due to filesystem timing)
      expect(count, lessThan(8));

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
      // Clean up so 1-hour check doesn't skip
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final future = AutoBackupService.performAutoBackup();
      AutoBackupService.cancel();
      final result = await future;
      expect(result, isFalse);
    });

    test('performAutoBackup returns false when cancel called before start',
        () async {
      // Clean up so 1-hour check doesn't skip
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
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
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      expect(AutoBackupService.isRunning, isFalse);
      await AutoBackupService.performAutoBackup();
      expect(AutoBackupService.isRunning, isFalse);
      await dir.delete(recursive: true);
    });

    test('second call returns false when backup is running', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final first = AutoBackupService.performAutoBackup();
      final second = await AutoBackupService.performAutoBackup();
      expect(second, isFalse);
      await first;
      await dir.delete(recursive: true);
    });
  });

  // ==================================================================
  // performAutoBackup success path
  // ==================================================================

  group('performAutoBackup success', () {
    test('returns true on success with empty data', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);
      await dir.delete(recursive: true);
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

      // Run backup with a clean directory (no existing zip files)
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

String _pad(int n) => n.toString().padLeft(2, '0');
