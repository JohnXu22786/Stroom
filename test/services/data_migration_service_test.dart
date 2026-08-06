import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

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

  group('DataMigrationService - legacy global format version', () {
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

  group('DataMigrationService - per-part versioning', () {
    test('current part versions: chat/settings/media = 1, others = 0',
        () async {
      // 回归：各部分当前版本号是独立的。只有实际发生（过）格式迁移的
      // 部分才有 > 0 的当前版本；tasks/anki/cookies 从未迁移，保持 0
      //（机制就位，未来各自演进时递增各自版本号）。
      final current = DataMigrationService.currentPartVersions;
      expect(current[DataMigrationService.partChat], equals(1),
          reason: 'chat: blocks 格式（原全局 v2→v3）');
      expect(current[DataMigrationService.partSettings], equals(1),
          reason: 'settings: provider_entries 格式（原全局 v0→v1）');
      for (final part in [
        DataMigrationService.partPictures,
        DataMigrationService.partAudio,
        DataMigrationService.partVideos,
        DataMigrationService.partTexts,
      ]) {
        expect(current[part], equals(1),
            reason: '$part: per-type folders（原全局 v1→v2）');
      }
      for (final part in [
        DataMigrationService.partTasks,
        DataMigrationService.partAnki,
        DataMigrationService.partBrowserCookies,
      ]) {
        expect(current[part], equals(0), reason: '$part: 无迁移历史');
      }
      // 所有备份类别都有各自的版本号（与 BackupSelection 一一对应）。
      expect(current.length, equals(9));
    });

    test('getStoredPartVersions defaults to all zero when never stored',
        () async {
      final stored = await DataMigrationService.getStoredPartVersions();
      for (final part in DataMigrationService.partIds) {
        expect(stored[part], equals(0), reason: 'part $part');
      }
    });

    test('getStoredPartVersions reads stored JSON, missing parts default 0',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions':
            '{"chat": 1, "settings": 1, "audio": 1, "tasks": 0}',
      });
      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partChat], equals(1));
      expect(stored[DataMigrationService.partSettings], equals(1));
      expect(stored[DataMigrationService.partAudio], equals(1));
      expect(stored[DataMigrationService.partTasks], equals(0));
      // JSON 中缺失的部分（如 pictures）按 0 处理 → 需要迁移
      expect(stored[DataMigrationService.partPictures], equals(0));
    });

    test('invalid value type in one part is isolated to that part', () async {
      // 回归：单个部分的值类型错误（如 "chat": "v1"）只让该部分按 0
      // 处理（重新迁移），绝不能导致整个记录作废 —— 否则其他已迁移
      // 部分会被降级重新迁移（一个坏键丢整个记录的旧实现）。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          DataMigrationService.partChat: 'v1', // 类型错误
          DataMigrationService.partSettings: 1,
          DataMigrationService.partPictures: 1,
          DataMigrationService.partAudio: 1,
          DataMigrationService.partVideos: 1,
          DataMigrationService.partTexts: 1,
          DataMigrationService.partTasks: 0,
          DataMigrationService.partAnki: 0,
          DataMigrationService.partBrowserCookies: 0,
        }),
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'textSections': ['answer'],
                'toolCalls': [],
              },
            ],
          },
        ]),
        'provider_entries': jsonEncode([
          {'id': 'p1', 'type': 'llm', 'name': 'P1', 'configs': []},
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      // 值损坏的 chat 部分按 0 处理并迁移到当前版本。
      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partChat], equals(1),
          reason: '值类型损坏的部分按 0 处理并重新迁移');
      // 值正常的 settings 部分保持原记录，不被降级或重迁。
      expect(stored[DataMigrationService.partSettings], equals(1));
      // 记录整体未损坏：不应产生隔离 key。
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs
            .getKeys()
            .where((k) => k.startsWith('data_format_versions_corrupt_')),
        isEmpty,
        reason: '逐键防御下整个记录没有被当作损坏处理',
      );
    });

    test('non-object data_format_versions is quarantined and rebuilt',
        () async {
      // 回归：版本记录可解析但不是对象（如数组/标量）时，与解析失败
      // 同样处理 —— 先隔离损坏现场，再从旧全局版本/v0 展开重建。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': '[1, 2, 3]',
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('data_format_versions_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty,
          reason: '非对象记录必须被隔离保留');
      expect(corruptKeys.any((k) => prefs.getString(k) == '[1, 2, 3]'),
          isTrue);
      await _expectAllPartsCurrent();
    });

    test('legacy v3 expands to all parts current, no migration, key removed',
        () async {
      // 回归：现有最新用户（旧全局 v3）升级到 per-part 机制时
      // 必须无感 —— 不迁移、不重启，只把版本记录转为 per-part。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 3,
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {'role': 'assistant', 'content': 'hi', 'blocks': []},
            ],
          },
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);
      expect(result.restartRequired, isFalse);

      // 展开的 per-part 版本已落盘，旧 key 退役。
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('data_format_version'), isFalse,
          reason: '旧全局 key 必须被移除，避免双源版本记录');
      await _expectAllPartsCurrent();
    });

    test('legacy v2 migrates ONLY the chat part (blocks)', () async {
      // 回归：旧全局 v2 只说明 chat 部分（v3 引入的 blocks）未迁移；
      // settings（v1）与 media（v2）已是最新，绝不能重复执行它们的迁移。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 2,
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'textSections': ['answer'],
                'toolCalls': [],
                'toolCallRoundStarts': [0],
              },
            ],
          },
        ]),
        'provider_entries': jsonEncode([
          {'id': 'p1', 'type': 'llm', 'name': 'P1', 'configs': []},
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      // chat 部分迁移完成：assistant 消息获得了 blocks。
      final prefs = await SharedPreferences.getInstance();
      final conversations =
          jsonDecode(prefs.getString('conversations')!) as List;
      final message = (conversations[0] as Map)['messages'][0] as Map;
      expect(message.containsKey('blocks'), isTrue,
          reason: 'chat 部分必须执行 v0→v1（blocks）迁移');

      // settings 数据原样保留（未重复迁移）。
      final providerEntries =
          jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(providerEntries, hasLength(1));

      await _expectAllPartsCurrent();
    });

    test('legacy v1 migrates chat + media parts, settings not repeated',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'textSections': ['answer'],
                'toolCalls': [],
              },
            ],
          },
        ]),
        'provider_entries': jsonEncode([
          {'id': 'p1', 'type': 'llm', 'name': 'P1', 'configs': []},
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      // chat 迁移执行。
      final conversations =
          jsonDecode(prefs.getString('conversations')!) as List;
      final message = (conversations[0] as Map)['messages'][0] as Map;
      expect(message.containsKey('blocks'), isTrue);
      // settings 未重复迁移（provider_entries 原样，无 migrated_llm 混入）。
      final providerEntries =
          jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(providerEntries, hasLength(1));
      // media 迁移执行（legacy folders 表被清理，JSON 模式下无 legacy key）。
      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partPictures], equals(1));
      expect(stored[DataMigrationService.partAudio], equals(1));

      await _expectAllPartsCurrent();
    });

    test('legacy v0 performs full migration (chat_configs → provider_entries)',
        () async {
      // 回归：最老的数据（无任何版本标记）必须走完全量迁移链。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
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
      // settings 部分迁移：chat_configs → provider_entries。
      expect(prefs.getString('provider_entries'), isNotNull);
      expect(prefs.containsKey('chat_configs'), isFalse);

      await _expectAllPartsCurrent();
    });

    test('media migration actually migrates legacy shared folders',
        () async {
      // 回归：media 部分的迁移接线必须真正执行物理迁移（共享 folders
      // → per-type 文件夹表），而不是只提升版本记账 —— 否则误删
      // media 迁移分支时测试依然通过（review 发现的问题）。
      // 播种 v1 时代的 JSON 数据：带 legacy 共享 folders 键。
      final legacyWebData = <String, dynamic>{
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>['legacy_folder', 'shared_folder'],
        'text_folders': <String>[],
        'audio_folders': <String>[],
        'image_folders': <String>[],
        'video_folders': <String>[],
      };
      await WebFileStore.write(
        'manifest_database_data',
        utf8Encode(jsonEncode(legacyWebData)),
      );

      SharedPreferences.setMockInitialValues({
        'data_format_version': 1, // settings 已迁移，media/chat 落后
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      // legacy folders 被复制到全部四个 per-type 文件夹表。
      for (final recordTable in [
        ManifestTables.textRecords,
        ManifestTables.audioRecords,
        ManifestTables.imageRecords,
        ManifestTables.videoRecords,
      ]) {
        final folders = await ManifestDatabase.getAllFolders(
            recordTable: recordTable);
        expect(folders, containsAll(['legacy_folder', 'shared_folder']),
            reason: '$recordTable 必须获得 legacy folders');
      }
      // legacy key 被移除。
      final raw = await WebFileStore.read('manifest_database_data');
      final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
      expect(data.containsKey('folders'), isFalse,
          reason: '迁移后 legacy 共享 folders 键必须被移除');

      await _expectAllPartsCurrent();
    });

    test('migration does NOT downgrade parts with future versions', () async {
      // 回归：某部分存储版本高于当前版本（未来版本迁移后回滚到本构建）
      // 时，迁移其他落后部分不得把超前部分降级 —— 否则回滚再升级会
      // 对已迁移数据重复执行迁移。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          DataMigrationService.partChat: 0,
          DataMigrationService.partSettings: 5, // 超前（未来版本）
          DataMigrationService.partPictures: 1,
          DataMigrationService.partAudio: 1,
          DataMigrationService.partVideos: 1,
          DataMigrationService.partTexts: 1,
          DataMigrationService.partTasks: 0,
          DataMigrationService.partAnki: 0,
          DataMigrationService.partBrowserCookies: 0,
        }),
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'textSections': ['answer'],
                'toolCalls': [],
              },
            ],
          },
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partChat], equals(1),
          reason: '落后的 chat 部分被迁移到当前版本');
      expect(stored[DataMigrationService.partSettings], equals(5),
          reason: '超前的 settings 部分必须保持原值，绝不降级');
    });

    test('corrupt data_format_versions is quarantined, not silently overwritten',
        () async {
      // 回归：版本记录本身损坏（JSON 解析失败）时，必须按项目
      // 「先隔离再覆盖」的约定保留损坏现场，再重新展开迁移 ——
      // 否则损坏证据被静默销毁，无法排查。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': 'not-json{{{',
        'conversations': jsonEncode([]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('data_format_versions_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty,
          reason: '损坏现场必须保留在带时间戳的隔离 key 中');
      expect(corruptKeys.any((k) => prefs.getString(k) == 'not-json{{{'),
          isTrue);
      await _expectAllPartsCurrent();
    });

    test('all parts current in per-part JSON → no migration', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions':
            jsonEncode(DataMigrationService.currentPartVersions),
        'conversations': jsonEncode([]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);
      expect(result.restartRequired, isFalse);
    });

    test('only the outdated part migrates when per-part JSON is stale',
        () async {
      // 回归：per-part 机制下，单个部分的迁移失败/落后不应波及其他部分
      // —— 只重试落后的部分，已是最新的部分原样保留。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          DataMigrationService.partChat: 0,
          DataMigrationService.partSettings: 1,
          DataMigrationService.partPictures: 1,
          DataMigrationService.partAudio: 1,
          DataMigrationService.partVideos: 1,
          DataMigrationService.partTexts: 1,
          DataMigrationService.partTasks: 0,
          DataMigrationService.partAnki: 0,
          DataMigrationService.partBrowserCookies: 0,
        }),
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'role': 'assistant',
                'content': 'hi',
                'reasoningSections': ['think'],
                'textSections': ['answer'],
                'toolCalls': [],
              },
            ],
          },
        ]),
        'provider_entries': jsonEncode([
          {'id': 'p1', 'type': 'llm', 'name': 'P1', 'configs': []},
        ]),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final conversations =
          jsonDecode(prefs.getString('conversations')!) as List;
      final message = (conversations[0] as Map)['messages'][0] as Map;
      expect(message.containsKey('blocks'), isTrue,
          reason: '落后的 chat 部分必须迁移');

      await _expectAllPartsCurrent();
    });

    test('both keys present → per-part wins, legacy key removed', () async {
      // 回滚再升级场景：旧版应用把旧 key 写回 3，但 per-part 记录
      // 显示某部分落后 —— per-part 是唯一事实来源，旧 key 被忽略并清理。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 3,
        'data_format_versions': jsonEncode({
          DataMigrationService.partChat: 0,
          DataMigrationService.partSettings: 1,
          DataMigrationService.partPictures: 1,
          DataMigrationService.partAudio: 1,
          DataMigrationService.partVideos: 1,
          DataMigrationService.partTexts: 1,
          DataMigrationService.partTasks: 0,
          DataMigrationService.partAnki: 0,
          DataMigrationService.partBrowserCookies: 0,
        }),
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue,
          reason: 'per-part 记录显示 chat 落后，不能因旧 key=3 而跳过');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('data_format_version'), isFalse,
          reason: '旧 key 必须清理，避免误导');
      await _expectAllPartsCurrent();
    });

    test('structural failure in chat part does NOT bump versions', () async {
      // 回归（延续旧 v2→v3 哲学）：结构性迁移失败（JSON 无法解析）时
      // 版本不得提升 —— 否则数据永久停留在"假成功"且永远不会重试。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          DataMigrationService.partChat: 0,
          DataMigrationService.partSettings: 1,
          DataMigrationService.partPictures: 1,
          DataMigrationService.partAudio: 1,
          DataMigrationService.partVideos: 1,
          DataMigrationService.partTexts: 1,
          DataMigrationService.partTasks: 0,
          DataMigrationService.partAnki: 0,
          DataMigrationService.partBrowserCookies: 0,
        }),
        'conversations': 'not-json{{{',
      });

      await expectLater(
        DataMigrationService.checkAndMigrate(),
        throwsA(anything),
      );

      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partChat], equals(0),
          reason: '失败的 chat 部分版本不得提升，下次启动自动重试');
      expect(stored[DataMigrationService.partSettings], equals(1),
          reason: '其他部分保持原记录');
    });
  });

  group('DataMigrationService - checkAndMigrate', () {
    test('no migration needed when legacy version is newer than current',
        () async {
      // 999 是展开输入：全部部分展开为当前版本 → 无迁移、无重启，
      // 且展开结果必须落盘、旧 key 必须退役（不依赖下次启动）。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('data_format_version', 999);

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isFalse);
      expect(result.restartRequired, isFalse);

      await _expectAllPartsCurrent();
    });

    test('migration needed when no version stored', () async {
      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);
      expect(result.restartRequired, isTrue);

      // After migration, per-part versions should all be current
      await _expectAllPartsCurrent();
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

      // Per-part versions should all be current
      await _expectAllPartsCurrent();
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

  group('DataMigrationService - SAF backup verification', () {
    test('_latestZipName filters non-zip files and picks the newest', () {
      // 回归：SAF 列表未排序且可能包含非 zip 文件（如访问测试临时文件），
      // 直接取 files.last 会返回错误的「已校验」文件。
      final files = [
        '.saf_access_test_123.tmp',
        'backup_2026-01-01T10-00-00.zip',
        'notes.txt',
        'backup_2026-08-04T22-00-00.zip',
        'backup_2026-03-15T08-30-00.zip',
      ];
      expect(DataMigrationBackup.latestZipName(files),
          'backup_2026-08-04T22-00-00.zip');

      expect(DataMigrationBackup.latestZipName(['a.txt', 'b.log']), isNull);
      expect(DataMigrationBackup.latestZipName(const []), isNull);
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
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '损坏数据必须保留在带时间戳的隔离 key 中');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      await _expectAllPartsCurrent();
    });

    test(
        'corrupt provider_entries is quarantined even when chat_configs '
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
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '迁移覆盖前必须隔离原始损坏数据');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 迁移结果正常写入（migrated_llm 条目）。
      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(entries, isNotEmpty);
      await _expectAllPartsCurrent();
    });

    test('quarantine pruning keeps only the 3 newest corrupt backups',
        () async {
      // 回归：隔离数据使用带时间戳的 key 且只保留最近 3 份。
      // 旧固定 key 会被下一次隔离覆盖，丢失前一份损坏证据。
      SharedPreferences.setMockInitialValues({
        'data_format_version': 0,
        'provider_entries': '{"not": "an array"}',
        // 预先存在 5 份旧的隔离数据（13 位 epoch 毫秒时间戳，
        // 全部早于当前时间 2026-08 ≈ 1.785e12，保证本次新隔离的
        // 数据（时间戳最大）是「最新」的）
        'provider_entries_corrupt_1700000000000': '{"old": 1}',
        'provider_entries_corrupt_1710000000000': '{"old": 2}',
        'provider_entries_corrupt_1720000000000': '{"old": 3}',
        'provider_entries_corrupt_1730000000000': '{"old": 4}',
        'provider_entries_corrupt_1740000000000': '{"old": 5}',
      });

      final result = await DataMigrationService.checkAndMigrate();
      expect(result.needsMigration, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList()
        ..sort();
      // 旧的 5 份 + 本次新隔离的 1 份 = 6 份，裁剪后只保留 3 份。
      expect(corruptKeys, hasLength(3), reason: '只保留最近的 3 份隔离备份');
      // 保留的是时间戳最大的 3 份（含本次新隔离的）。
      expect(corruptKeys.contains('provider_entries_corrupt_1700000000000'),
          isFalse,
          reason: '最旧的 3 份必须被裁剪');
      expect(corruptKeys.contains('provider_entries_corrupt_1710000000000'),
          isFalse);
      expect(corruptKeys.contains('provider_entries_corrupt_1720000000000'),
          isFalse);
      expect(corruptKeys.contains('provider_entries_corrupt_1730000000000'),
          isTrue);
      expect(corruptKeys.contains('provider_entries_corrupt_1740000000000'),
          isTrue);
      expect(
          corruptKeys.last.startsWith('provider_entries_corrupt_178'), isTrue,
          reason: '本次新隔离的备份（当前时间戳）必须被保留');
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
      await _expectAllPartsCurrent();
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
      await _expectAllPartsCurrent();
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
      // 版本不提升 → 下次启动自动重试（而非"假成功"永久跳过）
      final stored = await DataMigrationService.getStoredPartVersions();
      expect(stored[DataMigrationService.partChat], equals(0),
          reason: '失败的 chat 部分版本不得提升');
      expect(stored[DataMigrationService.partSettings], equals(1),
          reason: '其他部分保持展开后的版本记录');
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
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('conversations_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '原始损坏数据必须保留在隔离 key 中');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 版本正常提升（不再无限重试迁移）。
      await _expectAllPartsCurrent();
    });
  });
}

/// 断言迁移后所有部分的存储版本都是当前版本，且旧全局 key 已退役。
Future<void> _expectAllPartsCurrent() async {
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.containsKey('data_format_version'), isFalse,
      reason: '迁移完成后旧全局 key 必须被移除（per-part 唯一事实来源）');
  final stored = await DataMigrationService.getStoredPartVersions();
  for (final entry in DataMigrationService.currentPartVersions.entries) {
    expect(stored[entry.key], equals(entry.value),
        reason: 'part ${entry.key} 必须迁移到当前版本');
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');
