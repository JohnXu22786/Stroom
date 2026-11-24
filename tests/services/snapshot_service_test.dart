import 'dart:async';
import 'dart:convert';
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
    snapDir = await SnapshotService.snapshotsDir;
    if (await snapDir.exists()) {
      await snapDir.delete(recursive: true);
    }
    SnapshotService.debugNow = () => DateTime.now();
  });

  tearDown(() async {
    SnapshotService.debugNow = null;
    SnapshotService.debugAfterBackupCreated = null;
    SnapshotService.debugBeforeIndexCleanup = null;
    SnapshotService.debugBeforeIndexWrite = null;
    SnapshotService.debugBeforeDirectoryListing = null;
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

    test('index write failure reports failure and keeps archive recoverable',
        () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"index_failure"}]',
      });
      final original = await SnapshotService.createSnapshot(force: true);
      expect(original, isNotNull);

      SnapshotService.debugBeforeIndexWrite = () {
        throw const FileSystemException('simulated index write failure');
      };
      final failed = await SnapshotService.createSnapshot(force: true);
      expect(failed, isNull);

      final archives = (await snapDir.list().toList())
          .whereType<File>()
          .where((file) => file.path.endsWith('.zip'))
          .toList();
      expect(archives, hasLength(2),
          reason: 'a completed archive remains available for recovery');

      final recoveredDuringWriteFailure = await SnapshotService.readIndex();
      expect(recoveredDuringWriteFailure.map((entry) => entry.file).toSet(),
          archives.map((file) => p.basename(file.path)).toSet(),
          reason: 'index persistence failure does not hide recovered archives');

      SnapshotService.debugBeforeIndexWrite = null;
      final index = await SnapshotService.readIndex();
      expect(index.map((entry) => entry.file).toSet(),
          archives.map((file) => p.basename(file.path)).toSet(),
          reason: 'a later index read reconciles the unindexed archive');
    });

    test('readIndex keeps parsed entries when archive directory scan fails',
        () async {
      final snapshot = await SnapshotService.createSnapshot(force: true);
      expect(snapshot, isNotNull);

      SnapshotService.debugBeforeDirectoryListing = () {
        throw const FileSystemException('simulated directory listing failure');
      };
      final index = await SnapshotService.readIndex();

      expect(index.map((entry) => entry.file), [p.basename(snapshot!.path)],
          reason:
              'a failed unindexed-archive check must not hide valid entries');
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

    test('corrupt index is rebuilt from disk, snapshots still usable',
        () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"idx_conv"}]',
      });
      final file = await SnapshotService.createSnapshot();
      expect(file, isNotNull);

      // 弄坏索引
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString('{corrupted!!!');

      final index = await SnapshotService.readIndex();
      expect(index.length, 1, reason: '索引损坏时从磁盘扫描重建（快照仍在磁盘上）');
      expect(index.first.file, p.basename(file!.path));
      expect(index.first.sha256, isNotEmpty);
    });

    test('missing index is rebuilt from an existing snapshot archive',
        () async {
      await snapDir.create(recursive: true);
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      expect(await SnapshotService.readIndex(), isEmpty);
      expect(await indexFile.exists(), isFalse,
          reason:
              'an empty snapshots directory does not need an index rebuild');

      final snapshotFile = await SnapshotService.createSnapshot(force: true);
      expect(snapshotFile, isNotNull);
      await indexFile.delete();

      final snapshots = await SnapshotService.listSnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.file, p.basename(snapshotFile!.path));
      expect(snapshots.single.sha256, isNotEmpty);
      expect(await indexFile.exists(), isTrue);
    });

    test('empty index is rebuilt from an existing snapshot archive', () async {
      await snapDir.create(recursive: true);
      final snapshotFile = await SnapshotService.createSnapshot(force: true);
      expect(snapshotFile, isNotNull);
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString(jsonEncode({'snapshots': []}));

      final snapshots = await SnapshotService.listSnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.file, p.basename(snapshotFile!.path));
      expect(snapshots.single.sha256, isNotEmpty);
      expect(jsonDecode(await indexFile.readAsString())['snapshots'],
          hasLength(1));
    });

    test('listing removes missing archives from a small snapshot index',
        () async {
      final snapshotFile = await SnapshotService.createSnapshot(force: true);
      expect(snapshotFile, isNotNull);

      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      const missingFile = 'backup_2026-10-01T18-29-18.268046.zip';
      await indexFile.writeAsString(jsonEncode({
        'snapshots': [
          SnapshotEntry(
            file: p.basename(snapshotFile!.path),
            sha256: 'present',
            createdAt: DateTime.now().toIso8601String(),
            partVersions: const {},
          ).toJson(),
          const SnapshotEntry(
            file: missingFile,
            sha256: 'missing',
            createdAt: '2026-10-01T18:29:18.268046',
            partVersions: {},
          ).toJson(),
        ],
      }));

      final snapshots = await SnapshotService.listSnapshots();

      expect(snapshots.map((entry) => entry.file),
          [p.basename(snapshotFile.path)]);
      expect(
          jsonDecode(await indexFile.readAsString())['snapshots'], hasLength(1),
          reason: 'the persisted index must drop the missing archive');
    });

    test('invalid archive is not added to a rebuilt index', () async {
      await snapDir.create(recursive: true);
      const snapshotName = 'backup_2026-10-01T18-29-18.268046.zip';
      await File(p.join(snapDir.path, snapshotName)).writeAsBytes([1, 2, 3]);

      final snapshots = await SnapshotService.listSnapshots();

      expect(snapshots, isEmpty);
    });

    test('mixed valid and malformed index entries rebuild from disk', () async {
      final snapshot = await SnapshotService.createSnapshot(force: true);
      expect(snapshot, isNotNull);

      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString(jsonEncode({
        'snapshots': [
          SnapshotEntry(
            file: 'backup_2026-10-01T18-29-18.268046.zip',
            sha256: 'stale',
            createdAt: '2026-10-01T18:29:18.268046',
            partVersions: const {},
          ).toJson(),
          null,
        ],
      }));

      final index = await SnapshotService.readIndex();

      expect(index, hasLength(1));
      expect(index.single.file, p.basename(snapshot!.path));
      expect(index.single.sha256, isNot('stale'));
    });

    test('index entries cannot name files outside the snapshots directory',
        () async {
      await snapDir.create(recursive: true);
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString(jsonEncode({
        'snapshots': [
          SnapshotEntry(
            file: '../outside.zip',
            sha256: 'matching-digest-is-not-enough',
            createdAt: '2026-10-01T18:29:18.268046',
            partVersions: const {},
          ).toJson(),
        ],
      }));

      final index = await SnapshotService.readIndex();

      expect(index, isEmpty);
    });

    test('rebuilt index preserves fractional timestamp precision', () async {
      final timestamp = DateTime.parse('2026-10-01T18:29:18.268046');
      SnapshotService.debugNow = () => timestamp;
      final snapshotFile = await SnapshotService.createSnapshot(force: true);
      expect(snapshotFile, isNotNull);

      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString('{corrupted!!!');

      final index = await SnapshotService.readIndex();
      expect(index, hasLength(1));
      expect(index.single.file, p.basename(snapshotFile!.path));
      expect(index.single.createdAt, '2026-10-01T18:29:18.268046');
    });

    test('snapshot ordering repairs legacy index timestamps without fractions',
        () async {
      await snapDir.create(recursive: true);
      const olderFile = 'backup_2026-10-01T18-29-18.191016.zip';
      const newerFile = 'backup_2026-10-01T18-29-18.268046.zip';
      const truncatedCreatedAt = '2026-10-01T18:29:18.000';
      await File(p.join(snapDir.path, olderFile)).create();
      await File(p.join(snapDir.path, newerFile)).create();
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString(jsonEncode({
        'snapshots': [
          SnapshotEntry(
            file: olderFile,
            sha256: 'older',
            createdAt: truncatedCreatedAt,
            partVersions: const {},
          ).toJson(),
          SnapshotEntry(
            file: newerFile,
            sha256: 'newer',
            createdAt: truncatedCreatedAt,
            partVersions: const {},
          ).toJson(),
        ],
      }));

      final snapshots = await SnapshotService.listSnapshots();
      expect(snapshots.map((entry) => entry.file), [newerFile, olderFile]);
    });

    test('tmp leftover does not trigger the 1-hour rule and is cleaned',
        () async {
      // 模拟崩溃残留的写入中文件（setUp 删除了快照目录，先重建）
      await snapDir.create(recursive: true);
      final tmpFile =
          File(p.join(snapDir.path, 'backup_2026-01-01T00-00-00.zip.tmp'));
      await tmpFile.writeAsString('half-written');
      await tmpFile
          .setLastModified(DateTime.now().subtract(const Duration(days: 2)));

      // 残留 tmp 不算快照 → 1 小时规则不命中
      expect(await SnapshotService.hasSnapshotWithinHour(), isFalse,
          reason: '写入中的 tmp 残留不能算作快照');

      // 清理时删除 tmp 残留
      await SnapshotService.cleanupOldSnapshots();
      expect(await tmpFile.exists(), isFalse, reason: 'cleanup 应清理 tmp 残留');
    });

    test('cleanup preserves an active snapshot temporary file', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"concurrent_snapshot"}]',
      });
      final writeStarted = Completer<void>();
      final finishWrite = Completer<void>();
      SnapshotService.debugAfterBackupCreated = (file) async {
        await file
            .setLastModified(DateTime.now().subtract(const Duration(days: 2)));
        writeStarted.complete();
        await finishWrite.future;
      };

      final snapshotFuture = SnapshotService.createSnapshot(force: true);
      await writeStarted.future;
      final tmpFile = (await snapDir.list().toList())
          .whereType<File>()
          .singleWhere((file) => file.path.endsWith('.zip.tmp'));
      expect(await tmpFile.exists(), isTrue);

      await SnapshotService.cleanupOldSnapshots();
      expect(await tmpFile.exists(), isTrue);

      finishWrite.complete();
      final snapshot = await snapshotFuture;
      expect(snapshot, isNotNull);
      expect(await snapshot!.exists(), isTrue);
      expect(await tmpFile.exists(), isFalse);
    });

    test('overlapping forced snapshots reserve distinct paths', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"concurrent_snapshot"}]',
      });
      final sameTimestamp = DateTime(2026, 1, 1);
      SnapshotService.debugNow = () => sameTimestamp;
      final bothWritesStarted = Completer<void>();
      final finishWrites = Completer<void>();
      var writeCount = 0;
      SnapshotService.debugAfterBackupCreated = (file) async {
        writeCount++;
        if (writeCount == 2) bothWritesStarted.complete();
        await finishWrites.future;
      };

      final firstFuture = SnapshotService.createSnapshot(force: true);
      final secondFuture = SnapshotService.createSnapshot(force: true);
      await bothWritesStarted.future;
      finishWrites.complete();
      final snapshots = await Future.wait([firstFuture, secondFuture]);

      expect(snapshots, everyElement(isNotNull));
      expect(snapshots.map((file) => file!.path).toSet(), hasLength(2));
      for (final file in snapshots) {
        expect(await file!.exists(), isTrue);
      }
      expect((await SnapshotService.readIndex()).length, 2);
    });

    test('cleanup preserves snapshots indexed after its retention scan',
        () async {
      await snapDir.create(recursive: true);
      final now = DateTime.now();
      final oldEntries = <SnapshotEntry>[];
      for (var daysAgo = 5; daysAgo >= 2; daysAgo--) {
        final timestamp = now.subtract(Duration(days: daysAgo));
        final name =
            'backup_${timestamp.toIso8601String().replaceAll(':', '-')}.zip';
        await File(p.join(snapDir.path, name)).writeAsBytes([1]);
        oldEntries.add(SnapshotEntry(
          file: name,
          sha256: 'old-$daysAgo',
          createdAt: timestamp.toIso8601String(),
          partVersions: const {},
        ));
      }
      final indexFile =
          File(p.join(snapDir.path, SnapshotService.manifestName));
      await indexFile.writeAsString(jsonEncode({
        'snapshots': oldEntries.map((entry) => entry.toJson()).toList(),
      }));

      final retentionScanned = Completer<void>();
      final continueCleanup = Completer<void>();
      SnapshotService.debugBeforeIndexCleanup = () async {
        SnapshotService.debugBeforeIndexCleanup = null;
        retentionScanned.complete();
        await continueCleanup.future;
      };

      final cleanup = SnapshotService.cleanupOldSnapshots();
      await retentionScanned.future;

      SharedPreferences.setMockInitialValues({
        'conversations': '[{"id":"indexed_during_cleanup"}]',
      });
      final snapshot = await SnapshotService.createSnapshot(force: true);
      expect(snapshot, isNotNull);

      continueCleanup.complete();
      await cleanup;

      final index = await SnapshotService.readIndex();
      expect(index.map((entry) => entry.file),
          contains(p.basename(snapshot!.path)));
      expect(await snapshot.exists(), isTrue);
    });
  });
}
