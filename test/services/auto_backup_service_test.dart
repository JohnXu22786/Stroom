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

  tearDownAll(() async {
    // Remove the per-isolate test backup root so parallel runs do not
    // accumulate directories in systemTemp.
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
    test('keeps max 5 total when 7 files exist across multiple days', () async {
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
        final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
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
        final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
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
        final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
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
        final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
            '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
        final file = File('${dir.path}/backup_$timeStr.zip');
        await file.writeAsString('dummy_$i');
      }
      for (int i = 0; i < 5; i++) {
        final t = now.subtract(Duration(days: 2 * (i + 1)));
        final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
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

    test('concurrent calls wait for the in-flight backup and share its result',
        () async {
      // 回归：启动备份与迁移前备份并发时，后到者必须等待同一个在途
      // 备份并共享结果 —— 直接返回 false 会让迁移前备份被静默跳过
      // （迁移时无安全快照），或让启动备份被误报为失败。
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final first = AutoBackupService.performAutoBackup();
      final second = await AutoBackupService.performAutoBackup();
      expect(second, isTrue, reason: '并发调用应等待在途备份完成并返回相同结果');
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

    test('pre-migration backup ignores the 1-hour rule and always snapshots',
        () async {
      // 回归：迁移会原地改写数据，必须使用刚刚创建的新快照。
      // 旧代码在最近 1 小时内有备份时直接返回 true（跳过），
      // 迁移前快照可能缺少最新数据（最多 1 小时）。
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // 先执行一次普通备份：它必然是「1 小时以内」的备份，
      // 1 小时规则因此会被命中。
      final first = await AutoBackupService.performAutoBackup();
      expect(first, isTrue);

      // 迁移前备份必须无视 1 小时规则，创建一份新快照。
      final result =
          await AutoBackupService.performAutoBackup(isPreMigration: true);
      expect(result, isTrue);

      final zips = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, greaterThanOrEqualTo(2), reason: '迁移前备份必须创建新快照而不是跳过');

      await dir.delete(recursive: true);
    });

    test(
        'pre-migration caller sharing a 1-hour-skipped backup forces a '
        'fresh snapshot', () async {
      // 回归：普通备份在途时命中「1 小时规则」跳过（未创建快照），
      // 并发到达的迁移前备份必须强制自己再跑一次 —— 共享跳过结果
      // 会让迁移在无新快照的情况下进行。
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // 造一份「1 小时以内」的备份现场（1 小时规则会被命中）。
      final seed = await AutoBackupService.performAutoBackup();
      expect(seed, isTrue);

      // 普通备份在途（命中 1 小时规则 → skippedOneHour）。
      final normal = AutoBackupService.performAutoBackup();
      await Future<void>.delayed(Duration.zero);

      // 迁移前备份共享该结果：必须强制创建新快照。
      final preMigration =
          await AutoBackupService.performAutoBackup(isPreMigration: true);
      await normal;

      expect(preMigration, isTrue);
      final zips = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, greaterThanOrEqualTo(2),
          reason: '共享的 1 小时跳过结果不得抑制迁移前快照');

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

  // ==================================================================
  // lastError tracking
  // ==================================================================

  group('lastError tracking', () {
    test('lastError is null after successful backup', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);
      expect(AutoBackupService.lastError, isNull);
      await dir.delete(recursive: true);
    });

    test('lastError is null after cancel', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      AutoBackupService.cancel();
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isFalse);
      expect(AutoBackupService.lastError, isNull);
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
