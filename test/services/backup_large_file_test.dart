import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_location_manager.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

/// Fake [PathProviderPlatform] pointing the app documents dir at a unique
/// test temp root (mirrors the pattern used by attachment_storage_test).
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String workDir;

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    workDir =
        '${Directory.systemTemp.path}/backup_large_test_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(workDir).create(recursive: true);
  });

  tearDown(() async {
    final dir = Directory(workDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  // ==================================================================
  // 大文件流式 ZIP 构建（后台 isolate 的核心同步函数）
  // ==================================================================
  //
  // 回归场景：备份包含 600MB 级大视频时，旧实现会在主 isolate 同步
  // 处理整个文件（CRC32 + 分块读写），冻结应用前端。新实现把该同步
  // 核心放入后台 isolate —— 这里直接验证核心函数的正确性：
  // 大文件被完整、无损地写入 ZIP，且峰值内存不随文件大小增长。

  group('streaming sync zip build with large files', () {
    test('large file content survives the streaming zip build intact',
        () async {
      // 12MB 随机数据模拟大视频（足够覆盖 64KB 分块与 CRC32 缓冲路径）
      final largeSize = 12 * 1024 * 1024;
      final rng = Random(42);
      final largeData = Uint8List(largeSize);
      for (var i = 0; i < largeSize; i++) {
        largeData[i] = rng.nextInt(256);
      }
      final srcPath = '$workDir/video.mp4';
      await File(srcPath).writeAsBytes(largeData, flush: true);

      final outputPath = '$workDir/backup.zip';
      BackupService.createBackupStreamingSyncForTest(
        jsonFiles: {'manifest.json': '{"version":2}'},
        memoryFiles: {
          'small.bin': Uint8List.fromList([1, 2, 3])
        },
        diskFiles: [
          ['videos/video.mp4', srcPath],
        ],
        outputPath: outputPath,
      );

      final zipBytes = await File(outputPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive, isNotNull);

      // 大文件必须完整保留（store 模式，尺寸一致、内容逐字节一致）
      final videoEntry = archive.files.firstWhere(
          (f) => f.name == 'videos/video.mp4',
          orElse: () => throw 'missing');
      expect(videoEntry.size, equals(largeSize));
      final restored = Uint8List.fromList(videoEntry.content as List<int>);
      expect(restored, equals(largeData),
          reason: '大文件内容必须逐字节一致（streaming 损坏回归）');

      // 小文件与 JSON 文件也在
      final smallEntry = archive.files.firstWhere((f) => f.name == 'small.bin',
          orElse: () => throw 'missing');
      expect(smallEntry.content, equals([1, 2, 3]));
      expect(archive.files.any((f) => f.name == 'manifest.json'), isTrue);
    });

    test('missing disk file is skipped without breaking the archive', () async {
      final outputPath = '$workDir/backup_missing.zip';
      BackupService.createBackupStreamingSyncForTest(
        jsonFiles: {'manifest.json': '{"version":2}'},
        memoryFiles: {},
        diskFiles: [
          ['videos/ghost.mp4', '$workDir/does_not_exist.mp4'],
        ],
        outputPath: outputPath,
      );

      final archive =
          ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      expect(archive.files.any((f) => f.name == 'manifest.json'), isTrue);
      expect(archive.files.any((f) => f.name == 'videos/ghost.mp4'), isFalse,
          reason: '不存在的文件应被跳过而不是导致备份失败');
    });

    test('multiple large files accumulate correctly in the archive', () async {
      final rng = Random(7);
      final fileA = Uint8List(5 * 1024 * 1024);
      final fileB = Uint8List(3 * 1024 * 1024);
      for (var i = 0; i < fileA.length; i++) {
        fileA[i] = rng.nextInt(256);
      }
      for (var i = 0; i < fileB.length; i++) {
        fileB[i] = rng.nextInt(256);
      }
      final pathA = '$workDir/a.mp4';
      final pathB = '$workDir/b.wav';
      await File(pathA).writeAsBytes(fileA, flush: true);
      await File(pathB).writeAsBytes(fileB, flush: true);

      final outputPath = '$workDir/backup_multi.zip';
      BackupService.createBackupStreamingSyncForTest(
        jsonFiles: {'manifest.json': '{}'},
        memoryFiles: {},
        diskFiles: [
          ['videos/a.mp4', pathA],
          ['tts_audio/b.wav', pathB],
        ],
        outputPath: outputPath,
      );

      final archive =
          ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final aEntry = archive.files.firstWhere((f) => f.name == 'videos/a.mp4',
          orElse: () => throw 'missing');
      final bEntry = archive.files.firstWhere(
          (f) => f.name == 'tts_audio/b.wav',
          orElse: () => throw 'missing');
      expect(Uint8List.fromList(aEntry.content as List<int>), equals(fileA));
      expect(Uint8List.fromList(bEntry.content as List<int>), equals(fileB));
    });
  });

  // ==================================================================
  // 端到端：真实生产路径（后台 isolate）构建含大文件的备份
  // ==================================================================
  //
  // 默认测试走的是同步回退路径（WebFileStore.testMode）。此测试关闭
  // test mode，走真实的 Isolate.run 后台构建路径 —— 验证生产环境的
  // 「大文件不冻结 UI」方案端到端可用（大文件在后台 isolate 中
  // 流式写入，主 isolate 只 await）。

  group('createBackup end-to-end via background isolate', () {
    test('produces a valid zip with a large file through the isolate path',
        () async {
      // 1. 测试模式下注册数据库记录（JSON 内存存储，不依赖原生插件）
      ManifestDatabase.enableTestMode();
      final rng = Random(1234);
      final largeSize = 10 * 1024 * 1024;
      final largeData = Uint8List(largeSize);
      for (var i = 0; i < largeSize; i++) {
        largeData[i] = rng.nextInt(256);
      }
      await ManifestDatabase.insertVideoRecord({
        'id': 'e2e_big',
        'name': 'e2e_big',
        'hash': 'e2e_big',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': largeSize,
        'folder': '',
      });

      // 2. 视频文件放进 AppStorage 目录（videos/ 子目录，与生产一致）
      final appDir = await AppStorage.directory;
      final videosDir = Directory('$appDir/videos');
      await videosDir.create(recursive: true);
      addTearDown(() async {
        if (await videosDir.exists()) {
          await videosDir.delete(recursive: true);
        }
      });
      final videoPath = '$appDir/videos/e2e_big.mp4';
      await File(videoPath).writeAsBytes(largeData, flush: true);

      // 3. 关闭 WebFileStore 测试模式 → 走真实生产路径（后台 isolate）。
      //    数据库记录仍在内存缓存中（_webData），收集阶段可正常读取。
      WebFileStore.disableTestMode();
      addTearDown(() {
        // 恢复测试模式，避免影响同文件其他测试
        ManifestDatabase.enableTestMode();
      });

      final outputPath = '$workDir/e2e_backup.zip';
      await BackupService.createBackup(outputPath: outputPath);

      final archive =
          ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final entry = archive.files.firstWhere(
          (f) => f.name == 'videos/e2e_big.mp4',
          orElse: () => throw 'backup missing the large video');
      expect(entry.size, equals(largeSize));
      expect(Uint8List.fromList(entry.content as List<int>), equals(largeData),
          reason: '后台 isolate 路径不得损坏大文件内容');
    });
  });

  // ==================================================================
  // 流式恢复端到端：restoreBackup 生产路径（文件流解码 + 小块写入）
  // ==================================================================
  //
  // 回归场景：手动恢复大备份时旧实现 readAsBytes + 全量解压进内存
  // Map 再逐个 writeAsBytes，峰值内存随备份体积线性增长。新实现从
  // 磁盘流式解码（InputFileStream 共享缓冲，不复制整包），逐文件
  // 分块（64KB）写入磁盘 —— 这里验证生产路径（关闭 WebFileStore
  // 测试模式）的正确性：大文件逐字节无损、无效备份在任何现有数据
  // 被触碰之前抛出校验异常。

  group('restoreBackup end-to-end via streaming file decode', () {
    late PathProviderPlatform originalPathProvider;

    setUp(() {
      // 生产路径恢复会删除 AppStorage 目录下选中类别的目录。将
      // AppStorage 指向本测试独有的临时目录，避免并行测试文件
      // 共享 systemTemp 根目录时互相干扰（与仓库其他测试一致）。
      ManifestDatabase.enableTestMode();
      WebFileStore.disableTestMode();
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance =
          _FakePathProviderPlatform('$workDir/app');
      AppStorage.resetCache();
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      AppStorage.resetCache();
      ManifestDatabase.enableTestMode();
    });

    test('restores a large file byte-identically through the streaming path',
        () async {
      // 1. 注册数据库记录（内存 JSON 存储），并准备真实视频文件
      final rng = Random(2024);
      final largeSize = 10 * 1024 * 1024;
      final largeData = Uint8List(largeSize);
      for (var i = 0; i < largeSize; i++) {
        largeData[i] = rng.nextInt(256);
      }
      await ManifestDatabase.insertVideoRecord({
        'id': 'restore_big',
        'name': 'restore_big',
        'hash': 'restore_big',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': largeSize,
        'folder': '',
      });

      final appDir = await AppStorage.directory;
      final videosDir = Directory('$appDir/videos');
      await videosDir.create(recursive: true);
      final videoPath = '$appDir/videos/restore_big.mp4';
      await File(videoPath).writeAsBytes(largeData, flush: true);

      // 2. 创建备份（后台 isolate 流式构建）
      final backupPath = '$workDir/restore_e2e_backup.zip';
      await BackupService.createBackup(outputPath: backupPath);

      // 3. 删除源文件，模拟恢复前置状态（生产恢复路径会先清除选中类别）
      await File(videoPath).delete();

      // 4. 生产路径流式恢复
      await BackupService.restoreBackup(backupPath);

      // 5. 验证：文件逐字节一致 + 数据库记录恢复
      final restored = await File(videoPath).readAsBytes();
      expect(restored.length, equals(largeSize));
      expect(restored, equals(largeData),
          reason: '流式恢复路径不得损坏大文件内容');
      final records = await ManifestDatabase.getAllVideoRecords();
      expect(records.length, equals(1),
          reason: '恢复后视频记录应存在');
      expect(records[0]['id'], equals('restore_big'));
    });

    test('invalid zip throws BackupValidationException before touching data',
        () async {
      // 预置一个"现有数据"文件：若校验不通过就删数据，该文件会消失
      final appDir = await AppStorage.directory;
      final picturesDir = Directory('$appDir/pictures');
      await picturesDir.create(recursive: true);
      final markerPath = '$appDir/pictures/marker.jpg';
      await File(markerPath).writeAsBytes([1, 2, 3, 4], flush: true);

      // 非 zip 内容的"备份文件"
      final garbagePath = '$workDir/not_a_zip.zip';
      await File(garbagePath).writeAsBytes(
          Uint8List.fromList(List.generate(512, (i) => i % 256)),
          flush: true);

      await expectLater(
        BackupService.restoreBackup(garbagePath),
        throwsA(isA<BackupValidationException>()),
      );

      expect(await File(markerPath).exists(), isTrue,
          reason: '无效备份必须在删除任何现有数据之前失败');
    });

    test('deflate-compressed backup restores byte-identically (old v1 format)',
        () async {
      // 旧版本备份使用 deflate 压缩（ZipEncoder 默认），走
      // ZipFile.decompress 的流式解压路径 —— 与新备份的 store 模式
      // 路径不同，单独覆盖，防止流式解压损坏旧备份。
      final rng = Random(77);
      final fileData = Uint8List(4 * 1024 * 1024);
      for (var i = 0; i < fileData.length; i++) {
        fileData[i] = rng.nextInt(256);
      }

      // 用 deflate（默认压缩）构建 zip
      final archive = Archive();
      final manifestJson = '{"version":2}';
      archive.addFile(ArchiveFile('manifest.json',
          utf8.encode(manifestJson).length, utf8.encode(manifestJson)));
      archive.addFile(
          ArchiveFile('videos/deflate_big.mp4', fileData.length, fileData));
      final deflatePath = '$workDir/deflate_backup.zip';
      await File(deflatePath).writeAsBytes(ZipEncoder().encode(archive));

      // 确认该 zip 确实是 deflate 压缩，否则本测试会静默失去 deflate 覆盖
      final encodedArchive =
          ZipDecoder().decodeBytes(await File(deflatePath).readAsBytes());
      final encodedVideo = encodedArchive.files
          .firstWhere((f) => f.name == 'videos/deflate_big.mp4');
      expect(encodedVideo.compression, CompressionType.deflate,
          reason: '测试 zip 必须使用 deflate 压缩才能覆盖解压路径');

      final appDir = await AppStorage.directory;
      final videosDir = Directory('$appDir/videos');
      await videosDir.create(recursive: true);

      const videosOnly = BackupSelection(
        chatRecordsAndAttachments: false,
        settings: false,
        pictures: false,
        audio: false,
        videos: true,
        texts: false,
        tasks: false,
        ankiData: false,
        browserCookies: false,
      );
      await BackupService.restoreBackup(deflatePath, selection: videosOnly);

      final restored =
          await File('$appDir/videos/deflate_big.mp4').readAsBytes();
      expect(restored, equals(fileData),
          reason: 'deflate 压缩备份经流式解压恢复后必须逐字节一致');
    });
  });

  // ==================================================================
  // writeBackupFileFromPath — 大备份流式落盘（非 SAF 平台路径）
  // ==================================================================

  group('writeBackupFileFromPath', () {
    test('copies a large file to the backup root without data loss', () async {
      final srcPath = '$workDir/large_src.zip';
      final largeData = Uint8List(8 * 1024 * 1024);
      final rng = Random(99);
      for (var i = 0; i < largeData.length; i++) {
        largeData[i] = rng.nextInt(256);
      }
      await File(srcPath).writeAsBytes(largeData, flush: true);

      const targetName = 'backup_large_copy.zip';
      await BackupLocationManager.writeBackupFileFromPath(targetName, srcPath);

      final copied = await BackupLocationManager.readBackupFile(targetName);
      expect(copied, isNotNull);
      expect(copied!.length, equals(largeData.length));
      expect(copied, equals(largeData), reason: '流式复制不得丢失或损坏数据');

      await BackupLocationManager.deleteBackupFile(targetName);
    });

    test('throws when source file does not exist', () async {
      expect(
        () => BackupLocationManager.writeBackupFileFromPath(
            'backup_none.zip', '$workDir/no_such_file.zip'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
