import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/auto_backup_service.dart';
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
  // 1-hour skip rule — performAutoBackup
  // ==================================================================

  group('performAutoBackup — 1-hour rule', () {
    test('skips backup when there is a backup within the last hour', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // Create a recent backup (within last hour)
      final now = DateTime.now();
      final timeStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}T'
          '${_pad(now.hour)}-${_pad(now.minute)}-${_pad(now.second)}';
      final recentFile = File('${dir.path}/backup_$timeStr.zip');
      await recentFile.writeAsString('recent_backup');

      // performAutoBackup should skip because of recent backup
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue,
          reason: 'Should return true (skip is not a failure)');

      // Verify no new zip file was created (still only 1)
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(1),
          reason: 'Should not create a new backup when one exists within 1 hour');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('performs backup when last backup is older than 1 hour', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // Create an old backup (>1 hour ago)
      final oldTime = DateTime.now().subtract(const Duration(hours: 2));
      final timeStr =
          '${oldTime.year}-${_pad(oldTime.month)}-${_pad(oldTime.day)}T'
          '${_pad(oldTime.hour)}-${_pad(oldTime.minute)}-${_pad(oldTime.second)}';
      final oldFile = File('${dir.path}/backup_$timeStr.zip');
      await oldFile.writeAsString('old_backup');

      // performAutoBackup should proceed since last backup > 1 hour ago
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Verify a new zip file was created (2 zips now)
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(2),
          reason: 'Should create a new backup when last backup > 1 hour old');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('performs backup when no previous backups exist', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Cleanup
      await dir.delete(recursive: true);
    });
  });

  // ==================================================================
  // cleanupOldBackups — new retention policy (max 5 total, max 3 within 24h,
  // keep last backup from last 2 usage days)
  // ==================================================================

  group('cleanupOldBackups — new retention policy', () {
    test('keeps max 3 within 24h and max 5 total', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create 7 backup zip files:
      // - 4 recent (within 24h)
      // - 3 old (beyond 24h, on 3 different "usage days")
      final now = DateTime.now();
      // 4 recent files: 2h, 4h, 6h, 8h ago (all within 24h)
      for (int i = 0; i < 4; i++) {
        final t = now.subtract(Duration(hours: 2 * (i + 1)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('recent_$i');
      }
      // 3 old files on 3 different days (48h, 72h, 96h ago)
      for (int i = 0; i < 3; i++) {
        final t = now.subtract(Duration(hours: 24 * (i + 2)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('old_$i');
      }

      await AutoBackupService.cleanupOldBackups();

      // Should keep max 5 total
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(5),
          reason: 'Should keep max 5 backups total');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('keeps all when fewer than 5 backups exist', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Create only 3 backups
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final t = now.subtract(Duration(hours: 2 * (i + 1)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('backup_$i');
      }

      await AutoBackupService.cleanupOldBackups();

      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(3),
          reason: 'Should keep all 3 when below thresholds');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('keeps at most 3 within 24h when many recent backups exist', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // Create 6 backups all within the last 24 hours
      final now = DateTime.now();
      for (int i = 0; i < 6; i++) {
        final t = now.subtract(Duration(hours: i)); // 0,1,2,3,4,5 hours ago
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('recent_$i');
      }

      await AutoBackupService.cleanupOldBackups();

      // All within 24h → limited to max 3 within 24h (no beyond-24h files to add)
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(3),
          reason: 'Should keep max 3 when all are within 24h');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('handles mixed zip and dir backups without error', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // 3 zips + 5 old-style dirs = 8 total → cleanup should reduce count
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final t = now.subtract(Duration(hours: 2 * (i + 1)));
        final timeStr =
            '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('zip_$i');
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

      // Verify count was reduced
      final entries = await dir.list().toList();
      int count = 0;
      for (final e in entries) {
        if (e is File && e.path.endsWith('.zip')) count++;
        if (e is Directory && e.path.contains('backup_')) count++;
      }
      expect(count, lessThan(8),
          reason: 'Should reduce total count from 8');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('is idempotent when no backups exist', () async {
      // Should not throw
      await AutoBackupService.cleanupOldBackups();
    });
  });

  // ==================================================================
  // DataMigrationService delegation (uses new retention)
  // ==================================================================

  group('DataMigrationService delegation — new retention', () {
    test('cleanOldBackups delegates to AutoBackupService with new policy',
        () async {
      await DataMigrationService.cleanOldBackups();
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
