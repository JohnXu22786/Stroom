import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/data_integrity_checker.dart';
import 'package:stroom/services/data_safety_manager.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/snapshot_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/app_version.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

final class _DocumentsDirectory extends PathProviderPlatform {
  _DocumentsDirectory(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

final class _RealIO extends IOOverrides {}

final class _FailingMigrationStagedFile extends Fake implements File {
  _FailingMigrationStagedFile(this.file, this.destinationPath);

  final File file;
  final String destinationPath;

  @override
  String get path => file.path;

  @override
  Future<bool> exists() => file.exists();

  @override
  Future<File> rename(String newPath) async {
    if (p.normalize(newPath) == p.normalize(destinationPath)) {
      throw FileSystemException('Injected migration destination failure', path);
    }
    return file.rename(newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);

  @override
  Future<String> resolveSymbolicLinks() => file.resolveSymbolicLinks();
}

final class _FailingDeleteFile extends Fake implements File {
  _FailingDeleteFile(this.file);

  final File file;

  @override
  String get path => file.path;

  @override
  Future<FileStat> stat() => file.stat();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    throw FileSystemException('Injected cache delete failure', path);
  }
}

final class _FailingListDirectory extends Fake implements Directory {
  _FailingListDirectory(this.directory);

  final Directory directory;

  @override
  String get path => directory.path;

  @override
  Future<bool> exists() => directory.exists();

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      Stream.error(
        FileSystemException('Injected cache directory read failure', path),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String appDir;
  late Directory snapDir;
  late Directory isolatedAppDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppStorage.resetCache();
    isolatedAppDir = await Directory.systemTemp.createTemp(
      'stroom_data_safety_test_',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsDirectory(isolatedAppDir.path);
    appDir = await AppStorage.directory;
    // 只扫描本测试隔离目录中的数据，避免其他并行测试的文件影响判断。
    for (final rel in [
      'synthesis/tasks.json',
      'catcatch/tasks.json',
      'background/tasks.json',
      'task_flows/flows.json',
      'task_flows/executions.json',
      'browser_cookies.json',
    ]) {
      final f = File(p.join(appDir, rel));
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    snapDir = await SnapshotService.snapshotsDir;
    if (await snapDir.exists()) {
      await snapDir.delete(recursive: true);
    }
    final stateFile = File(p.join(appDir, DataSafetyManager.stateFileName));
    if (await stateFile.exists()) {
      await stateFile.delete();
    }
    SnapshotService.debugNow = () => DateTime.now();
  });

  tearDown(() async {
    SnapshotService.debugNow = null;
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    try {
      if (await snapDir.exists()) {
        await snapDir.delete(recursive: true);
      }
    } catch (_) {}
    try {
      final stateFile = File(p.join(appDir, DataSafetyManager.stateFileName));
      if (await stateFile.exists()) {
        await stateFile.delete();
      }
    } catch (_) {}
    try {
      if (await isolatedAppDir.exists()) {
        await isolatedAppDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('DataSafetyManager', () {
    test('clean data: checkAndRepair does nothing, stays normal', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[]',
        'data_format_versions': '{"chat":1}',
      });
      final result = await DataSafetyManager.checkAndRepair();
      expect(result.corruptionFound, isFalse);
      expect(result.repaired, isFalse);
      expect(result.frozen, isFalse);
      final status = await DataSafetyManager.loadStatus();
      expect(status.state, DataSafetyState.normal);
    });

    test('corrupt data: rolls back to latest snapshot and recovers', () async {
      // 先创建一版健康快照
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"good_conv"}]',
        'active_conversation_id': 'good_conv',
        'data_format_versions': '{"chat":1}',
      });
      final snapshot = await SnapshotService.createSnapshot();
      expect(snapshot, isNotNull);

      // 模拟数据损坏
      SharedPreferences.setMockInitialValues({
        'conversations': '{broken json!!!',
        'active_conversation_id': 'good_conv',
        'data_format_versions': '{"chat":1}',
      });

      final result = await DataSafetyManager.checkAndRepair();
      expect(result.corruptionFound, isTrue);
      expect(result.repaired, isTrue);
      expect(result.frozen, isFalse);

      // 数据已恢复
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), contains('good_conv'),
          reason: '回滚后 conversations 应从快照恢复');

      // 状态回 normal
      final status = await DataSafetyManager.loadStatus();
      expect(status.state, DataSafetyState.normal);

      // 修复后打了一版干净快照（force），索引应有 2 条
      final index = await SnapshotService.readIndex();
      expect(index.length, 2);
    });

    test('corrupt data with no snapshots: freezes', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '{broken',
        'data_format_versions': '{"chat":1}',
      });
      final result = await DataSafetyManager.checkAndRepair();
      expect(result.corruptionFound, isTrue);
      expect(result.repaired, isFalse);
      expect(result.frozen, isTrue);
      final status = await DataSafetyManager.loadStatus();
      expect(status.state, DataSafetyState.frozen);
      expect(status.frozenByVersion, appVersion);
    });

    test('corrupt snapshot in chain is skipped, older good one used', () async {
      // 旧快照（健康）
      SnapshotService.debugNow =
          () => DateTime.now().subtract(const Duration(hours: 2));
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"old_good"}]',
        'data_format_versions': '{"chat":1}',
      });
      await SnapshotService.createSnapshot(force: true);
      // 新快照（健康）——随后被"损坏"
      SnapshotService.debugNow = () => DateTime.now();
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"new_good"}]',
        'data_format_versions': '{"chat":1}',
      });
      await SnapshotService.createSnapshot(force: true);

      // 弄坏最新的快照文件内容（SHA 不符）
      final index = await SnapshotService.listSnapshots(); // 新 → 旧
      final newest = index.first;
      final file = File(p.join(snapDir.path, newest.file));
      await file.writeAsString('garbage-content');

      // 当前数据损坏
      SharedPreferences.setMockInitialValues({
        'conversations': '{corrupt',
        'data_format_versions': '{"chat":1}',
      });

      final result = await DataSafetyManager.checkAndRepair();
      expect(result.repaired, isTrue);

      // 恢复的是旧版健康快照
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('conversations'), contains('old_good'),
          reason: 'SHA 不符的快照应被跳过，回滚到更旧的健康快照');
    });

    test(
        'freeze is version-aware: same version stays frozen, other '
        'version is released', () async {
      // 相同版本 → 冻结保持
      await DataSafetyManager.freezeForMigrationFailure(
          targetFormatVersion: 5, description: 'v4→v5');
      var result = await DataSafetyManager.checkAndRepair();
      expect(result.skippedDueToFreeze, isTrue);
      expect(result.frozen, isTrue);

      // 模拟"旧版/修复版"（冻结版本不同）→ 解除冻结
      final status = await DataSafetyManager.loadStatus();
      await DataSafetyManager.saveStatus(DataSafetyStatus(
        state: DataSafetyState.frozen,
        frozenByVersion: 'v0.4.9',
        failedMigration: status.failedMigration,
      ));
      result = await DataSafetyManager.checkAndRepair();
      expect(result.skippedDueToFreeze, isFalse, reason: '不同构建应解除冻结');
      final after = await DataSafetyManager.loadStatus();
      expect(after.state, DataSafetyState.normal);
    });

    test(
        'cleanupOrphans deletes unreferenced files older than 3 days '
        'and keeps referenced/new ones', () async {
      // 引用：附件 basename + 媒体 hash
      SharedPreferences.setMockInitialValues({
        'conversations':
            '[{"id":"c1","messages":[{"attachments":[{"storagePath":"attachments/ref_attach_1.jpg"}]}]}]',
      });
      await ManifestDatabase.insertImageRecord({
        'id': 'img_1',
        'name': 'img',
        'hash': 'ref_hash_1',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 10,
        'height': 10,
      });

      final attachmentsDir = Directory(p.join(appDir, 'attachments'));
      await attachmentsDir.create(recursive: true);
      final picturesDir = Directory(p.join(appDir, 'pictures'));
      await picturesDir.create(recursive: true);

      // 被引用的文件（老 mtime 也不删）
      final referenced = File(p.join(attachmentsDir.path, 'ref_attach_1.jpg'));
      await referenced.writeAsString('x');
      final oldReferencedTs = DateTime.now().subtract(const Duration(days: 10));
      await referenced.setLastModified(oldReferencedTs);

      // 有引用媒体文件
      final refMedia = File(p.join(picturesDir.path, 'ref_hash_1.jpg'));
      await refMedia.writeAsString('x');
      await refMedia.setLastModified(oldReferencedTs);

      // 无引用且超 3 天 → 删除
      final orphan = File(p.join(attachmentsDir.path, 'orphan_old.jpg'));
      await orphan.writeAsString('x');
      await orphan.setLastModified(oldReferencedTs);

      // 无引用但 3 天内 → 保留
      final fresh = File(p.join(attachmentsDir.path, 'orphan_fresh.jpg'));
      await fresh.writeAsString('x');
      await fresh.setLastModified(DateTime.now());

      await DataSafetyManager.cleanupOrphans();

      expect(await referenced.exists(), isTrue, reason: '被引用的文件不能删');
      expect(await refMedia.exists(), isTrue, reason: '被引用的媒体文件不能删');
      expect(await orphan.exists(), isFalse, reason: '无引用且超 3 天应删除');
      expect(await fresh.exists(), isTrue, reason: '3 天缓冲内的文件应保留');
    });

    test(
        'cleanupOrphans removes aged nested compressed caches but keeps recent '
        'caches and referenced originals', () async {
      SharedPreferences.setMockInitialValues({
        'conversations':
            '[{"id":"c1","messages":[{"attachments":[{"storagePath":"attachments/keep-original.png"}]}]}]',
      });
      final oldTimestamp = DateTime.now().subtract(const Duration(days: 10));
      final cacheDir = Directory(
        p.join(appDir, 'attachments', 'temp_compressed', 'conversation-1'),
      );
      await cacheDir.create(recursive: true);
      final agedCache = File(p.join(cacheDir.path, 'aged-cache.jpg'));
      await agedCache.writeAsString('regenerable cache');
      await agedCache.setLastModified(oldTimestamp);
      final recentCache = File(p.join(cacheDir.path, 'recent-cache.jpg'));
      await recentCache.writeAsString('recent cache');

      final original = File(p.join(appDir, 'attachments', 'keep-original.png'));
      await original.writeAsString('original attachment');
      await original.setLastModified(oldTimestamp);

      await DataSafetyManager.cleanupOrphans();

      expect(await agedCache.exists(), isFalse,
          reason: 'aged unreferenced compressed caches are reclaimable');
      expect(await recentCache.exists(), isTrue,
          reason: 'the existing three-day grace period applies to caches');
      expect(await original.exists(), isTrue,
          reason: 'referenced original attachments must stay intact');
    });

    test(
        'cleanupOrphans removes aged cache colliding with a legacy original '
        'but keeps the original and recent cache', () async {
      const legacyName = 'legacy-content-hash.jpg';
      SharedPreferences.setMockInitialValues({
        'conversations':
            '[{"id":"c1","messages":[{"attachments":[{"storagePath":"attachments/$legacyName"}]}]}]',
      });
      final oldTimestamp = DateTime.now().subtract(const Duration(days: 10));
      final oldCacheDir = Directory(p.join(
        appDir,
        'attachments',
        'temp_compressed',
        'conversation-old',
      ));
      final recentCacheDir = Directory(p.join(
        appDir,
        'attachments',
        'temp_compressed',
        'conversation-recent',
      ));
      await oldCacheDir.create(recursive: true);
      await recentCacheDir.create(recursive: true);

      final agedCache = File(p.join(oldCacheDir.path, legacyName));
      await agedCache.writeAsString('regenerable compressed cache');
      await agedCache.setLastModified(oldTimestamp);
      final recentCache = File(p.join(recentCacheDir.path, legacyName));
      await recentCache.writeAsString('recent compressed cache');
      final original = File(p.join(appDir, 'attachments', legacyName));
      await original.parent.create(recursive: true);
      await original.writeAsString('legacy original attachment');
      await original.setLastModified(oldTimestamp);

      await DataSafetyManager.cleanupOrphans();

      expect(await agedCache.exists(), isFalse,
          reason: 'aged caches are disposable despite a referenced basename');
      expect(await original.exists(), isTrue,
          reason: 'the referenced legacy original must remain intact');
      expect(await recentCache.exists(), isTrue,
          reason: 'the three-day grace period still applies to caches');
    });

    test('cleanupOrphans continues past unreadable cache folders and files',
        () async {
      final cacheRoot = Directory(
        p.join(appDir, 'attachments', 'temp_compressed'),
      );
      final unreadableDir = Directory(p.join(cacheRoot.path, 'unreadable'));
      final readableDir = Directory(p.join(cacheRoot.path, 'readable'));
      await unreadableDir.create(recursive: true);
      await readableDir.create(recursive: true);
      final unreadableCache = File(p.join(unreadableDir.path, 'cache.jpg'));
      await unreadableCache.writeAsString('cache');
      await unreadableCache.setLastModified(
        DateTime.now().subtract(const Duration(days: 10)),
      );
      final undeletableCache = File(p.join(readableDir.path, 'locked.jpg'));
      await undeletableCache.writeAsString('cache');
      await undeletableCache.setLastModified(
        DateTime.now().subtract(const Duration(days: 10)),
      );
      final deletableCache = File(p.join(readableDir.path, 'orphan.jpg'));
      await deletableCache.writeAsString('cache');
      await deletableCache.setLastModified(
        DateTime.now().subtract(const Duration(days: 10)),
      );

      final outerZone = Zone.current;
      await IOOverrides.runZoned(() async {
        await DataSafetyManager.cleanupOrphans();
      }, createDirectory: (path) {
        final delegate = outerZone.run(() => Directory(path));
        if (p.normalize(path) == p.normalize(unreadableDir.path)) {
          return _FailingListDirectory(delegate);
        }
        return delegate;
      }, createFile: (path) {
        final delegate = outerZone.run(() => File(path));
        if (p.normalize(path) == p.normalize(undeletableCache.path)) {
          return _FailingDeleteFile(delegate);
        }
        return delegate;
      });

      expect(await unreadableCache.exists(), isTrue,
          reason: 'a cache folder that cannot be listed is left untouched');
      expect(await undeletableCache.exists(), isTrue,
          reason: 'failed cache deletion is tolerated');
      expect(await deletableCache.exists(), isFalse,
          reason: 'one cache failure must not stop cleanup of other caches');
    });

    test('cleanupOrphans does not follow a compressed cache root symlink',
        () async {
      if (Platform.isWindows) return;

      final attachmentsDir = Directory(p.join(appDir, 'attachments'));
      await attachmentsDir.create(recursive: true);
      final cacheTarget = Directory(p.join(appDir, 'cache-target'));
      final targetConversation = Directory(
        p.join(cacheTarget.path, 'conversation-1'),
      );
      await targetConversation.create(recursive: true);
      final agedCache = File(p.join(targetConversation.path, 'orphan.jpg'));
      await agedCache.writeAsString('cache outside the managed namespace');
      await agedCache.setLastModified(
        DateTime.now().subtract(const Duration(days: 10)),
      );

      await Link(p.join(attachmentsDir.path, 'temp_compressed'))
          .create(cacheTarget.path);

      await DataSafetyManager.cleanupOrphans();

      expect(await agedCache.exists(), isTrue,
          reason: 'a symlink target outside the cache namespace is untouched');
    });

    test(
      'cleanupOrphans preserves legacy audio after migration write failure',
      () async {
        const hash = 'legacy_audio_hash';
        const format = 'wa%v';
        await ManifestDatabase.insertAudioRecord({
          'id': 'legacy_audio_1',
          'name': 'legacy audio',
          'hash': hash,
          'format': format,
          'createdAt': DateTime.now().toIso8601String(),
          'size': 100,
          'folder': '',
          'sourceText': '',
          'duration': 1,
        });
        WebFileStore.disableTestMode();
        addTearDown(WebFileStore.enableTestMode);
        FileManifest.invalidateCache();

        final audioDir = Directory(p.join(appDir, 'tts_audio'));
        await audioDir.create(recursive: true);
        const legacyName = '$hash.$format';
        final legacyAudio = File(p.join(audioDir.path, legacyName));
        await legacyAudio.writeAsString('only surviving audio copy');
        final storageName = AudioRecord.storageFileNameFor(
          hash: hash,
          format: format,
        );
        final destinationPath = p.join(audioDir.path, storageName);
        final realIO = IOOverrides.current ?? _RealIO();
        await IOOverrides.runZoned(
          () => FileManifest.loadRecords(),
          createFile: (path) {
            final file = realIO.createFile(path);
            return p.basename(path).startsWith('.audio-migration-')
                ? _FailingMigrationStagedFile(file, destinationPath)
                : file;
          },
        );
        expect(await legacyAudio.exists(), isTrue,
            reason: 'failed destination migration must retain its source');
        expect(await File(destinationPath).exists(), isFalse,
            reason:
                'the injected migration write failure blocks the destination');
        await legacyAudio.setLastModified(
          DateTime.now().subtract(const Duration(days: 10)),
        );

        await DataSafetyManager.cleanupOrphans();

        expect(await legacyAudio.exists(), isTrue,
            reason: 'the live record must keep its legacy source referenced');

        FileManifest.invalidateCache();
        await FileManifest.loadRecords();
        expect(await legacyAudio.exists(), isFalse,
            reason:
                'a later successful migration retry removes the legacy file');
        expect(await File(destinationPath).exists(), isTrue,
            reason:
                'a later successful migration retry writes the escaped file');
      },
    );

    test('cleanupOrphans keeps old audio with a Windows-invalid format',
        () async {
      const hash = 'ref_audio_hash_1';
      const format = 'wa?v';
      await ManifestDatabase.insertAudioRecord({
        'id': 'audio_1',
        'name': 'audio',
        'hash': hash,
        'format': format,
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'sourceText': '',
        'duration': 1,
      });

      final audioPath = AudioRecord.storageFileNameFor(
        hash: hash,
        format: format,
      );
      final audio = File(p.join(appDir, 'tts_audio', audioPath));
      await audio.parent.create(recursive: true);
      await audio.writeAsString('audio');
      await audio.setLastModified(
        DateTime.now().subtract(const Duration(days: 10)),
      );

      await DataSafetyManager.cleanupOrphans();

      expect(await audio.exists(), isTrue,
          reason: 'aged audio stored under the manifest-safe name stays alive');
    });
  });
}
