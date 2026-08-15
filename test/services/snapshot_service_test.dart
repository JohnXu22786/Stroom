import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/snapshot_service.dart';
import 'package:stroom/services/storage_service.dart';

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
    snapDir = Directory(p.join(appDir, SnapshotService.snapshotsDirName));
    if (await snapDir.exists()) {
      await snapDir.delete(recursive: true);
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
  });

  group('SnapshotService', () {
    test('createSnapshot writes a zip snapshot with index entry', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv1"}]',
        'data_format_versions': '{"chat":1}',
      });

      final file = await SnapshotService.createSnapshot();
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(file.path, endsWith('.zip'));
      expect(file.path.contains('.tmp'), isFalse);

      final index = await SnapshotService.readIndex();
      expect(index.length, 1);
      expect(index.first.file, p.basename(file.path));
      expect(index.first.sha256, isNotEmpty);
      expect(index.first.partVersions['chat'], 1);
    });

    test('snapshot is skipped within the 1-hour rule', () async {
      await SnapshotService.createSnapshot();
      // 同一小时内再次创建 → 跳过（返回 null）
      final second = await SnapshotService.createSnapshot();
      expect(second, isNull);
      final index = await SnapshotService.readIndex();
      expect(index.length, 1);
    });

    test('force ignores the 1-hour rule', () async {
      await SnapshotService.createSnapshot();
      final second = await SnapshotService.createSnapshot(force: true);
      expect(second, isNotNull);
      final index = await SnapshotService.readIndex();
      expect(index.length, 2);
    });

    test('retention keeps newest 3 within 24h plus 2 usage days (max 5)',
        () async {
      // 构造 7 个跨天快照：今天 3 个 + 昨天 1 个 + 前天 1 个 + 更旧 2 个
      final now = DateTime.now();
      final day = Duration(days: 1);
      SnapshotService.debugNow = () => now.subtract(const Duration(days: 8));
      await SnapshotService.createSnapshot(force: true); // 8 天前
      SnapshotService.debugNow = () => now.subtract(const Duration(days: 5));
      await SnapshotService.createSnapshot(force: true); // 5 天前
      SnapshotService.debugNow = () => now.subtract(const Duration(days: 2));
      await SnapshotService.createSnapshot(force: true); // 前天
      SnapshotService.debugNow = () => now.subtract(day);
      await SnapshotService.createSnapshot(force: true); // 昨天
      SnapshotService.debugNow = () => now.subtract(const Duration(hours: 5));
      await SnapshotService.createSnapshot(force: true); // 今天
      SnapshotService.debugNow = () => now.subtract(const Duration(hours: 2));
      await SnapshotService.createSnapshot(force: true); // 今天
      SnapshotService.debugNow = () => now;
      await SnapshotService.createSnapshot(force: true); // 今天

      final index = await SnapshotService.readIndex();
      expect(index.length, 5, reason: '24h 内 3 个 + 前天/昨天各 1 个 = 5 个，其余清理');

      final names = index.map((e) => e.file).toSet();
      final dirFiles = (await snapDir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(dirFiles.length, 5, reason: '磁盘上的快照文件应与索引一致');
      for (final f in dirFiles) {
        expect(names, contains(p.basename(f.path)));
      }
    });

    test('snapshot zip contains structured data only', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"conv_snap"}]',
        'active_conversation_id': 'conv_snap',
      });
      final file = await SnapshotService.createSnapshot();
      expect(file, isNotNull);

      // 直接读回文件验证 ZIP 内容（archive 包）
      final bytes = await file!.readAsBytes();
      // 至少能解析出 chat_data.json（用字符串搜索验证结构内容存在）
      final content = String.fromCharCodes(bytes);
      expect(content.contains('chat_data.json'), isTrue);
      expect(content.contains('conv_snap'), isTrue);
    });
  });
}
