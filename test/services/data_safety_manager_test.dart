import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/data_integrity_checker.dart';
import 'package:stroom/services/data_safety_manager.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/snapshot_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String appDir;
  late Directory snapDir;

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppStorage.resetCache();
    appDir = await AppStorage.directory;
    // 清理共享 systemTemp 下其他测试文件可能残留的脏数据文件
    //（checkAndRepair 会扫描这些路径，残留坏文件会造成误判损坏）
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
        frozenByVersion: 'other-version-999',
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
  });
}
