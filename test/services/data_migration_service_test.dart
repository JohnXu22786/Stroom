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

  tearDownAll(() async {
    // Remove the per-isolate test backup root so parallel runs do not
    // accumulate directories in systemTemp.
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
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
      // Should contain either Stroom/AutoBackups or stroom_backup_test
      expect(
        backupRoot.contains('AutoBackups') ||
            backupRoot.contains('AutoBackup') ||
            backupRoot.contains('stroom_backup_test'),
        isTrue,
        reason: 'Backup root should reference backup directory name',
      );
    });

    test('backup root is stable within the test isolate', () async {
      // Regression: parallel test files share systemTemp and must each use
      // their own per-isolate root (BackupLocationManager.testBackupRoot);
      // within one isolate (one test file) the path must not change between
      // calls, otherwise setUp/cleanup in the backup tests would break.
      final root1 = await DataMigrationService.getExternalBackupRootPath();
      final root2 = await DataMigrationService.getExternalBackupRootPath();
      expect(root1, root2,
          reason: 'Repeated resolution must return the same test root');
      expect(root1.contains('stroom_backup_test'), isTrue,
          reason: 'Test root must stay under the stroom_backup_test prefix');
      // Discriminator: the pre-fix shared-root implementation resolved to
      // exactly this fixed path — unique per-isolate roots must differ.
      expect(root1,
          isNot(equals('${Directory.systemTemp.path}/stroom_backup_test')),
          reason: 'Test root must be unique per isolate, not the shared path');
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
      expect(DataMigrationService.currentFormatVersion, equals(3));
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
      await prefs.setInt('data_format_version', 3);

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
      expect(storedVersion, equals(3));
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
      await prefs.setInt('data_format_version', 3);

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
      await prefs.setInt('data_format_version', 3);

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
      expect(storedVersion, equals(3));
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

    test('cleanOldBackups keeps max 5 backup_ entries (new policy)', () async {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final rootDir = Directory(backupRoot);
      await rootDir.create(recursive: true);

      try {
        // Create 7 backup_ prefixed items (4 dirs + 3 zips) on different dates
        for (int i = 0; i < 4; i++) {
          final t = DateTime.now().subtract(Duration(days: 2 * (i + 1)));
          final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
              '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
          final d = Directory('${rootDir.path}/backup_$timeStr');
          await d.create(recursive: true);
        }
        for (int i = 0; i < 3; i++) {
          final t = DateTime.now().subtract(Duration(hours: 2 * (i + 1)));
          final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
              '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
          final f = File('${rootDir.path}/backup_$timeStr.zip');
          await f.writeAsString('dummy');
        }

        await DataMigrationService.cleanOldBackups();

        // Should keep 5 of the 7 (new retention policy: max 5 total)
        final entries = await rootDir.list().toList();
        final backupItems = entries
            .where((e) =>
                (e is File && e.path.endsWith('.zip')) ||
                (e is Directory && e.path.contains('backup_')))
            .toList();
        expect(backupItems.length, equals(5));
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

  group('DataMigrationService - corrupt provider_entries quarantine', () {
    test('non-list provider_entries is quarantined and reset to empty list',
        () async {
      // 顶层损坏（provider_entries 不是数组）：旧代码 `as List` 强转
      // TypeError 静默中断修复，版本号仍被提升 → ProviderEntry 解析
      // 继续闪退、错误边界重试永远失败。现在应隔离并重置。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': '{"not": "an array"}',
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('provider_entries'), '[]',
          reason: '损坏数据必须被隔离，应用才能正常启动');
      final corruptKeys = prefs.getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty,
          reason: '损坏数据必须保留在带时间戳的隔离 key 中');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      expect(prefs.getInt('data_format_version'),
          DataMigrationService.currentFormatVersion);
    });

    test('corrupt provider_entries is quarantined even when chat_configs '
        'triggers an overwrite', () async {
      // 回归：migrateOldChatConfigs 在 chat_configs 存在时会重写
      // provider_entries —— 若此时现有数据已损坏（非数组），旧代码
      // 会直接覆盖销毁损坏现场（后续隔离逻辑永远触发不到）。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': '{"not": "an array"}',
        'chat_configs': jsonEncode([
          {
            'providerName': 'Old',
            'host': '',
            'key': '',
            'models': [
              {'modelId': 'm1', 'temperature': 0.5},
            ],
          },
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      // 损坏现场必须被保留在隔离 key 中，而不是被迁移写入覆盖。
      final corruptKeys = prefs.getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty,
          reason: '迁移覆盖前必须隔离原始损坏数据');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 迁移结果正常写入（migrated_llm 条目）。
      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(entries, isNotEmpty);
      expect(prefs.getInt('data_format_version'),
          DataMigrationService.currentFormatVersion);
    });
  });

  group('DataMigrationService - v2→v3 defensive migration', () {
    test('corrupt tool call entries are skipped, migration still completes',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2,
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'title': 't',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'toolCalls': ['not-a-map'], // 损坏条目：跳过而非中断
                'toolCallRoundStarts': [0],
              },
              {
                'role': 'user',
                'content': 'hello',
              },
            ],
          },
        ]),
      });
      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('data_format_version'), 3);
    });

    test('non-Map message entries are skipped, migration still completes',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2,
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'title': 't',
            'messages': [
              'garbage-string', // 非 Map 消息：跳过而非结构性错误
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
              },
            ],
          },
        ]),
      });
      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('data_format_version'), 3);
    });

    test('structural failure (invalid JSON) does NOT bump the version',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2,
        'conversations': 'not-json{{{',
      });
      await expectLater(
        DataMigrationService.migrateDataFormatIfNeeded(),
        throwsA(anything),
      );
      final prefs = await SharedPreferences.getInstance();
      // 版本不提升 → 下次启动自动重试（而非"假成功"永久跳过）
      expect(prefs.getInt('data_format_version'), 2);
    });

    test('decodable-but-non-array conversations is quarantined, not rethrown',
        () async {
      // 回归：conversations 是可解析但不是数组（对象/标量）时，旧代码
      // `as List` 强转抛 TypeError 被误判为「结构性错误」上抛 → 版本号
      // 永不提升、每次启动都重复迁移与备份。现在应隔离并重置。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2,
        'conversations': '{"not": "an array"}',
      });

      final result = await DataMigrationService.migrateDataFormatIfNeeded();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), '[]');
      final corruptKeys = prefs.getKeys()
          .where((k) => k.startsWith('conversations_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty,
          reason: '原始损坏数据必须保留在隔离 key 中');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 版本正常提升（不再无限重试迁移）。
      expect(prefs.getInt('data_format_version'), 3);
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
