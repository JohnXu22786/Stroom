// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/backup_service_shared.dart';
import 'package:stroom/services/browser_profile_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

/// 流式恢复（restoreBackup）回归测试。
///
/// 背景：手动导入恢复走 restoreBackup，旧实现 `File(zipPath).readAsBytes()`
/// 把整个备份包读进内存后再解压到 fileMap —— 含大视频的备份（数百 MB）
/// 会直接 OOM。新实现流式读取：只解析中央目录 + 按条目分块解压落盘，
/// 峰值内存 O(块大小)，与旧自动备份的流式创建对称。
///
/// 这里直接以真实文件为输入验证 restoreBackup（dart:io 文件读写），
/// 写入侧走 WebFileStore 测试模式（与 _restoreFromBytes 测试一致）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String workDir;

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    await ManifestDatabase.clearAllData();
    workDir =
        '${Directory.systemTemp.path}/backup_stream_restore_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(workDir).create(recursive: true);
  });

  tearDown(() async {
    final dir = Directory(workDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  /// 把一个内存 Archive 编码为磁盘上的 zip 文件，返回其路径。
  Future<String> writeArchive(Archive archive, String name) async {
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final path = '$workDir/$name';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// 构造 v2 格式的最小合法备份归档（manifest + stroom_manifest）。
  Archive buildV2Archive({
    List<Map<String, dynamic>> imageRecords = const [],
    List<Map<String, dynamic>> videoRecords = const [],
    List<Map<String, dynamic>> textRecords = const [],
    Map<String, Uint8List> files = const {},
    int version = 2,
  }) {
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'version': version,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final dbData = {
      'image_records': imageRecords,
      'audio_records': <Map<String, dynamic>>[],
      'video_records': videoRecords,
      'text_records': textRecords,
      'folders': <String>[],
      ManifestTables.textFolders: <String>[],
      ManifestTables.audioFolders: <String>[],
      ManifestTables.imageFolders: <String>[],
      ManifestTables.videoFolders: <String>[],
    };
    final databaseManifest = utf8.encode(jsonEncode(dbData));
    archive.addFile(
      ArchiveFile(
        'stroom_manifest.json',
        databaseManifest.length,
        databaseManifest,
      ),
    );
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return archive;
  }

  // ==================================================================
  // store 模式大文件：流式恢复逐字节一致（主回归）
  // ==================================================================

  test(
    'restoreBackup roundtrips a large store-mode backup byte-identical',
    () async {
      final rng = Random(42);
      final largeSize = 12 * 1024 * 1024; // 覆盖 64KB 分块与多块累积
      final largeData = Uint8List(largeSize);
      for (var i = 0; i < largeSize; i++) {
        largeData[i] = rng.nextInt(256);
      }
      final srcPath = '$workDir/video.mp4';
      await File(srcPath).writeAsBytes(largeData, flush: true);
      final textPath = '$workDir/note.txt';
      await File(textPath).writeAsBytes(utf8.encode('hello 中文'), flush: true);

      final zipPath = '$workDir/backup.zip';
      BackupService.createBackupStreamingSyncForTest(
        jsonFiles: {
          'manifest.json': '{"version":2}',
          'settings.json': '{"darkMode":true}',
        },
        memoryFiles: {
          // 注意：conversations 在应用内以 JSON 字符串形式存储
          'chat_data.json': Uint8List.fromList(
            utf8.encode('{"conversations":"[]"}'),
          ),
        },
        diskFiles: [
          ['videos/big.mp4', srcPath],
          ['texts/note.txt', textPath],
        ],
        outputPath: zipPath,
      );

      // 恢复（勾选全量）
      final progress = <double>[];
      await BackupService.restoreBackup(zipPath, onProgress: progress.add);

      // 进度：0.0 开始、1.0 结束
      expect(progress.first, equals(0.0));
      expect(progress.last, equals(1.0));

      // 大视频逐字节一致（store 模式流式恢复损坏回归）
      final restored = await readBackupFile('videos', 'big.mp4');
      expect(restored, isNotNull, reason: '大文件必须被恢复出来');
      expect(restored!.length, equals(largeSize));
      expect(restored, equals(largeData), reason: '流式恢复必须逐字节还原大文件');

      // 文本文件
      final restoredText = await readBackupFile('texts', 'note.txt');
      expect(utf8.decode(restoredText!), equals('hello 中文'));

      // 设置类 preferences 从 settings.json 恢复
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('darkMode'),
        isTrue,
        reason: 'settings.json 必须在流式恢复中合并进 SharedPreferences',
      );
    },
  );

  // ==================================================================
  // deflate 压缩条目（旧备份默认压缩格式）
  // ==================================================================

  test('restoreBackup decompresses deflate-compressed entries', () async {
    final videoBytes = Uint8List.fromList(
      List<int>.generate(256 * 1024, (i) => i % 251),
    ); // 不易压缩的伪随机
    final archive = buildV2Archive(
      videoRecords: [
        {
          'id': 'v_deflate',
          'name': 'v_deflate',
          'hash': 'v_deflate',
          'format': 'mp4',
          'createdAt': DateTime.now().toIso8601String(),
          'size': videoBytes.length,
          'folder': '',
        },
      ],
      files: {'videos/v_deflate.mp4': videoBytes},
    );
    // 显式 deflate（archive 默认即 deflate，这里明确声明）
    for (final f in archive.files) {
      f.compression = CompressionType.deflate;
    }
    final zipPath = await writeArchive(archive, 'deflate.zip');

    await BackupService.restoreBackup(zipPath);

    final restored = await readBackupFile('videos', 'v_deflate.mp4');
    expect(restored, isNotNull);
    expect(restored, equals(videoBytes), reason: 'deflate 条目流式解压必须还原原始字节');

    final records = await ManifestDatabase.getAllVideoRecords();
    expect(records.length, equals(1));
    expect(records[0]['id'], equals('v_deflate'));
  });

  test('case-only media destination collisions fail before selected files are cleared', () async {
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: true,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: true,
      browserCookies: false,
    );
    const picturesOnlySelection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: true,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const attachmentsOnlySelection = BackupSelection(
      chatRecordsAndAttachments: true,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const browserAndPicturesSelection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: true,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: true,
    );
    const attachmentsAndTasksSelection = BackupSelection(
      chatRecordsAndAttachments: true,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: true,
      ankiData: false,
      browserCookies: false,
    );
    const tasksOnlySelection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: true,
      ankiData: false,
      browserCookies: false,
    );
    Archive buildSharedTaskAttachmentArchive({required bool sameContent}) {
      final archive = Archive();
      void addJson(String name, Object value) {
        final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      addJson('manifest.json', {
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
        'dataParts': [DataParts.chat, DataParts.tasks],
      });
      addJson('stroom_manifest.json', {
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
        ManifestTables.textFolders: <String>[],
        ManifestTables.audioFolders: <String>[],
        ManifestTables.imageFolders: <String>[],
        ManifestTables.videoFolders: <String>[],
      });
      addJson('chat_data.json', {'conversations': '[]'});
      addJson('synthesis/tasks.json', []);
      addJson('catcatch/tasks.json', []);
      addJson('background/tasks.json', []);
      addJson('task_flows/flows.json', []);
      addJson('task_flows/executions.json', []);
      final attachmentBytes = Uint8List.fromList([32, 33]);
      final taskAttachmentBytes = sameContent
          ? attachmentBytes
          : Uint8List.fromList([34, 35]);
      archive.addFile(
        ArchiveFile(
          'attachments/shared.txt',
          attachmentBytes.length,
          attachmentBytes,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'task_flow_attachments/shared.txt',
          taskAttachmentBytes.length,
          taskAttachmentBytes,
        ),
      );
      return archive;
    }

    Archive buildTaskAttachmentArchive(String relativePath) {
      final archive = Archive();
      void addJson(String name, Object value) {
        final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      addJson('manifest.json', {
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
        'dataParts': [DataParts.tasks],
      });
      addJson('stroom_manifest.json', {
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
        ManifestTables.textFolders: <String>[],
        ManifestTables.audioFolders: <String>[],
        ManifestTables.imageFolders: <String>[],
        ManifestTables.videoFolders: <String>[],
      });
      addJson('synthesis/tasks.json', []);
      addJson('catcatch/tasks.json', []);
      addJson('background/tasks.json', []);
      addJson('task_flows/flows.json', []);
      addJson('task_flows/executions.json', []);
      final bytes = Uint8List.fromList([40, 41]);
      archive.addFile(
        ArchiveFile('task_flow_attachments/$relativePath', bytes.length, bytes),
      );
      return archive;
    }

    const ankiDbOnlySelection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: true,
      browserCookies: false,
      includeMediaFiles: false,
    );
    final original = Uint8List.fromList(utf8.encode('keep existing image'));
    final originalAttachment = Uint8List.fromList(
      utf8.encode('keep existing attachment'),
    );
    WebFileStore.enableTestMode();
    await writeBackupFile('pictures', 'existing.jpg', original);
    await writeBackupFile('attachments', 'existing.jpg', originalAttachment);
    BackupService.restorePathsCaseInsensitiveForTesting = true;
    try {
      final archive = buildV2Archive(
        imageRecords: [
          {
            'id': 'ab',
            'name': 'ab',
            'hash': 'ab',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'AB',
            'name': 'AB',
            'hash': 'AB',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'cafe-nfc',
            'name': 'café',
            'hash': 'café',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'cafe-nfd',
            'name': 'cafe\u0301',
            'hash': 'cafe\u0301',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'greek-sigma',
            'name': 'Σ',
            'hash': 'Σ',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'greek-final-sigma',
            'name': 'ς',
            'hash': 'ς',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'sharp-s',
            'name': 'ß',
            'hash': 'ß',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'double-s',
            'name': 'SS',
            'hash': 'SS',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
        ],
        files: {
          'pictures/ab.jpg': Uint8List.fromList([1]),
          'pictures/AB.jpg': Uint8List.fromList([2]),
          'pictures/café.jpg': Uint8List.fromList([6]),
          'pictures/cafe\u0301.jpg': Uint8List.fromList([7]),
          'pictures/Σ.jpg': Uint8List.fromList([8]),
          'pictures/ς.jpg': Uint8List.fromList([9]),
          'pictures/ß.jpg': Uint8List.fromList([10]),
          'pictures/SS.jpg': Uint8List.fromList([11]),
          'attachments/café.jpg': Uint8List.fromList([12]),
          'attachments/cafe\u0301.jpg': Uint8List.fromList([13]),
          'chat_data.json': Uint8List.fromList(
            utf8.encode('{"conversations":"[]"}'),
          ),
          'anki/collection.anki2': Uint8List.fromList([3]),
          'anki/collection.media/a.jpg': Uint8List.fromList([4]),
          'anki/collection.media/A.jpg': Uint8List.fromList([5]),
        },
      );
      final zipPath = await writeArchive(archive, 'case_collision.zip');

      await expectLater(
        BackupService.restoreBackup(zipPath, selection: selection),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
        reason: 'collision preflight must run before selected media is cleared',
      );

      var browserRestorePreparationEntered = false;
      BrowserProfileService.onPrepareForRestoreForTesting = () =>
          browserRestorePreparationEntered = true;
      final browserCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/ab.jpg': Uint8List.fromList([30]),
            'pictures/AB.jpg': Uint8List.fromList([31]),
            'browser_cookies.json': Uint8List.fromList(utf8.encode('[]')),
          },
        ),
        'browser_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          browserCollisionZip,
          selection: browserAndPicturesSelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        browserRestorePreparationEntered,
        isFalse,
        reason: 'collision preflight must preserve an existing browser restore staging directory',
      );
      BrowserProfileService.onPrepareForRestoreForTesting = null;
      await BackupService.restoreBackup(
        zipPath,
        selection: ankiDbOnlySelection,
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
        reason: 'database-only Anki restore must ignore unselected media collisions',
      );

      final prefixCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/Foo': Uint8List.fromList([14]),
            'pictures/foo/bar.jpg': Uint8List.fromList([15]),
          },
        ),
        'prefix_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          prefixCollisionZip,
          selection: picturesOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
        reason:
            'file/directory prefix collisions must fail before clearing media',
      );

      final expansionPrefixZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/ß': Uint8List.fromList([16]),
            'pictures/SS/child.jpg': Uint8List.fromList([17]),
          },
        ),
        'case_expansion_prefix_collision.zip',
      );
      BackupService.restorePathsCaseExpansionInsensitiveForTesting = true;
      await expectLater(
        BackupService.restoreBackup(
          expansionPrefixZip,
          selection: picturesOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
        reason: 'expansion prefix collisions must fail before clearing media',
      );

      BackupService.restorePathsCaseExpansionInsensitiveForTesting = false;
      await BackupService.restoreBackup(
        expansionPrefixZip,
        selection: picturesOnlySelection,
      );
      expect(await readBackupFile('pictures', 'ß'), equals([16]));
      expect(await readBackupFile('pictures', 'SS/child.jpg'), equals([17]));

      BackupService.restorePathsWindowsNameNormalizationInsensitiveForTesting =
          true;
      final windowsNameCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/Foo': Uint8List.fromList([18]),
            'pictures/foo.': Uint8List.fromList([19]),
          },
        ),
        'windows_name_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          windowsNameCollisionZip,
          selection: picturesOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
      );

      final windowsSpaceCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/Name': Uint8List.fromList([24]),
            'pictures/name ': Uint8List.fromList([25]),
          },
        ),
        'windows_space_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          windowsSpaceCollisionZip,
          selection: picturesOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
      );

      final windowsPrefixCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/Folder.': Uint8List.fromList([20]),
            'pictures/folder /child.jpg': Uint8List.fromList([21]),
          },
        ),
        'windows_prefix_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          windowsPrefixCollisionZip,
          selection: picturesOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
      );

      final windowsAttachmentCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'attachments/Folder.': Uint8List.fromList([22]),
            'attachments/folder /child.jpg': Uint8List.fromList([23]),
          },
        ),
        'windows_attachment_prefix_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          windowsAttachmentCollisionZip,
          selection: attachmentsOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('attachments', 'existing.jpg'),
        equals(originalAttachment),
      );

      final matchingTaskAttachmentAliasZip = await writeArchive(
        buildSharedTaskAttachmentArchive(sameContent: true),
        'matching_task_attachment_alias.zip',
      );
      await BackupService.restoreBackup(
        matchingTaskAttachmentAliasZip,
        selection: attachmentsAndTasksSelection,
      );
      expect(
        await readBackupFile('attachments', 'shared.txt'),
        equals([32, 33]),
      );

      await writeBackupFile('attachments', 'existing.jpg', originalAttachment);
      final mismatchedTaskAttachmentAliasZip = await writeArchive(
        buildSharedTaskAttachmentArchive(sameContent: false),
        'mismatched_task_attachment_alias.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          mismatchedTaskAttachmentAliasZip,
          selection: attachmentsAndTasksSelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('attachments', 'existing.jpg'),
        equals(originalAttachment),
        reason: 'different-content shared attachment aliases must fail before clearing files',
      );

      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'messages': [
              {
                'attachments': [
                  {'storagePath': 'attachments/foo.'},
                ],
              },
            ],
          },
        ]),
      });
      final protectedAttachmentBytes = Uint8List.fromList([42]);
      await writeBackupFile('attachments', 'foo.', protectedAttachmentBytes);
      final protectedAttachmentCollisionZip = await writeArchive(
        buildTaskAttachmentArchive('Foo'),
        'protected_attachment_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          protectedAttachmentCollisionZip,
          selection: tasksOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('attachments', 'foo.'),
        equals(protectedAttachmentBytes),
        reason: 'Windows-equivalent unselected chat attachment references must be preserved',
      );
      SharedPreferences.setMockInitialValues({});

      final windowsAttachmentFileCollisionZip = await writeArchive(
        buildV2Archive(
          files: {
            'attachments/Name': Uint8List.fromList([26]),
            'attachments/name.': Uint8List.fromList([27]),
          },
        ),
        'windows_attachment_file_collision.zip',
      );
      await expectLater(
        BackupService.restoreBackup(
          windowsAttachmentFileCollisionZip,
          selection: attachmentsOnlySelection,
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('attachments', 'existing.jpg'),
        equals(originalAttachment),
      );

      BackupService.restorePathsCaseInsensitiveForTesting = false;
      final caseSensitiveWindowsZip = await writeArchive(
        buildV2Archive(
          files: {
            'pictures/Foo.': Uint8List.fromList([28]),
            'pictures/foo.': Uint8List.fromList([29]),
          },
        ),
        'case_sensitive_windows_names.zip',
      );
      await BackupService.restoreBackup(
        caseSensitiveWindowsZip,
        selection: picturesOnlySelection,
      );
      expect(await readBackupFile('pictures', 'Foo.'), equals([28]));
      expect(await readBackupFile('pictures', 'foo.'), equals([29]));

      final caseSensitiveAttachmentZip = await writeArchive(
        buildV2Archive(
          files: {
            'chat_data.json': Uint8List.fromList(
              utf8.encode('{"conversations":"[]"}'),
            ),
            'attachments/Foo': Uint8List.fromList([43]),
            'attachments/foo': Uint8List.fromList([44]),
          },
        ),
        'case_sensitive_windows_attachments.zip',
      );
      await BackupService.restoreBackup(
        caseSensitiveAttachmentZip,
        selection: attachmentsOnlySelection,
      );
      expect(await readBackupFile('attachments', 'Foo'), equals([43]));
      expect(await readBackupFile('attachments', 'foo'), equals([44]));

      BackupService.restorePathsNormalizationInsensitiveForTesting = true;
      await expectLater(
        BackupService.restoreBackup(zipPath, selection: picturesOnlySelection),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('pictures', 'existing.jpg'),
        equals(original),
        reason: 'normalization collision must also fail before selected files are cleared',
      );
      await expectLater(
        BackupService.restoreBackup(
          zipPath,
          selection: const BackupSelection(
            chatRecordsAndAttachments: true,
            settings: false,
            pictures: false,
            audio: false,
            videos: false,
            texts: false,
            tasks: false,
            ankiData: false,
            browserCookies: false,
          ),
        ),
        throwsA(isA<DataManagementPreflightException>()),
      );
      expect(
        await readBackupFile('attachments', 'existing.jpg'),
        equals(originalAttachment),
        reason:
            'attachment collisions must fail before selected files are cleared',
      );

      BackupService.restorePathsNormalizationInsensitiveForTesting = false;
      await BackupService.restoreBackup(
        zipPath,
        selection: picturesOnlySelection,
      );
      expect(await readBackupFile('pictures', 'ab.jpg'), equals([1]));
      expect(await readBackupFile('pictures', 'AB.jpg'), equals([2]));
      expect(await readBackupFile('pictures', 'café.jpg'), equals([6]));
      expect(await readBackupFile('pictures', 'cafe\u0301.jpg'), equals([7]));
      expect(await readBackupFile('pictures', 'Σ.jpg'), equals([8]));
      expect(await readBackupFile('pictures', 'ς.jpg'), equals([9]));
      expect(await readBackupFile('pictures', 'ß.jpg'), equals([10]));
      expect(await readBackupFile('pictures', 'SS.jpg'), equals([11]));

      BackupService.restorePathsCaseInsensitiveForTesting = true;
      final expansionArchive = buildV2Archive(
        imageRecords: [
          {
            'id': 'sharp-s',
            'name': 'ß',
            'hash': 'ß',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
          {
            'id': 'double-s',
            'name': 'SS',
            'hash': 'SS',
            'format': 'jpg',
            'createdAt': '2026-01-01T00:00:00.000',
            'size': 1,
            'folder': '',
          },
        ],
        files: {
          'pictures/ß.jpg': Uint8List.fromList([10]),
          'pictures/SS.jpg': Uint8List.fromList([11]),
        },
      );
      final expansionZip = await writeArchive(
        expansionArchive,
        'case_expansion.zip',
      );
      await BackupService.restoreBackup(
        expansionZip,
        selection: picturesOnlySelection,
      );
      expect(await readBackupFile('pictures', 'ß.jpg'), equals([10]));
      expect(await readBackupFile('pictures', 'SS.jpg'), equals([11]));
    } finally {
      BrowserProfileService.onPrepareForRestoreForTesting = null;
      BackupService.restorePathsCaseInsensitiveForTesting = null;
      BackupService.restorePathsNormalizationInsensitiveForTesting = null;
      BackupService.restorePathsCaseExpansionInsensitiveForTesting = null;
      BackupService.restorePathsWindowsNameNormalizationInsensitiveForTesting =
          null;
      WebFileStore.disableTestMode();
    }
  });

  test(
    'restoreBackup validates malformed task JSON before mutating restored data',
    () async {
      WebFileStore.disableTestMode();
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode(DataParts.currentVersions),
        'existing_pref': 'keep',
      });
      final appDir = await AppStorage.directory;
      final existingTaskBytes = Uint8List.fromList(utf8.encode('[]'));
      final existingTextBytes = Uint8List.fromList(utf8.encode('keep'));
      final existingTaskFile = File('$appDir/synthesis/tasks.json');
      await existingTaskFile.parent.create(recursive: true);
      await existingTaskFile.writeAsBytes(existingTaskBytes);
      final existingTextFile = File('$appDir/texts/keep.txt');
      await existingTextFile.parent.create(recursive: true);
      await existingTextFile.writeAsBytes(existingTextBytes);
      final incomingTextFile = File('$appDir/texts/new.txt');
      if (await incomingTextFile.exists()) await incomingTextFile.delete();
      addTearDown(() async {
        for (final path in [
          '$appDir/synthesis/tasks.json',
          '$appDir/texts/keep.txt',
          '$appDir/texts/new.txt',
        ]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      });
      await ManifestDatabase.insertVideoRecord({
        'id': 'existing_video',
        'name': 'existing_video',
        'hash': 'existing_video',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 1,
        'folder': '',
      });
      final archive = buildV2Archive(
        videoRecords: [
          {
            'id': 'incoming_video',
            'name': 'incoming_video',
            'hash': 'incoming_video',
            'format': 'mp4',
            'createdAt': DateTime.now().toIso8601String(),
            'size': 1,
            'folder': '',
          },
        ],
        files: {
          'synthesis/tasks.json': Uint8List.fromList(utf8.encode('{broken')),
          'settings.json': Uint8List.fromList(
            utf8.encode('{"existing_pref":"backup"}'),
          ),
          'texts/new.txt': Uint8List.fromList(utf8.encode('new')),
        },
      );
      final zipPath = await writeArchive(archive, 'malformed_task_json.zip');

      await expectLater(
        BackupService.restoreBackup(zipPath),
        throwsA(isA<BackupValidationException>()),
      );

      expect(
        (await ManifestDatabase.getAllVideoRecords()).map((r) => r['id']),
        ['existing_video'],
      );
      expect(
        await File('$appDir/synthesis/tasks.json').readAsBytes(),
        existingTaskBytes,
      );
      expect(
        await File('$appDir/texts/keep.txt').readAsBytes(),
        existingTextBytes,
      );
      expect(await File('$appDir/texts/new.txt').exists(), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString('existing_pref'),
        'keep',
      );
    },
  );

  // ==================================================================
  // 旧版 v1 布局：files/ 前缀、tasks/*.json、preferences.json
  // ==================================================================

  test(
    'restoreBackup maps legacy v1 layout (files/, tasks/, preferences.json)',
    () async {
      final archive = Archive()
        // 带非空 EOCD 注释：覆盖尾部搜索的注释长度边界检查
        ..comment = 'stroom backup with a non-empty comment 中文';
      final manifest = utf8.encode(
        jsonEncode({
          'version': 1,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      // v1：聊天+设置合并在一个 preferences.json
      // （conversations 在应用内以 JSON 字符串形式存储）
      archive.addFile(
        ArchiveFile(
          'preferences.json',
          utf8
              .encode(
                jsonEncode({
                  'conversations': '[]',
                  'active_conversation_id': 'conv_1',
                  'theme': 'dark',
                }),
              )
              .length,
          utf8.encode(
            jsonEncode({
              'conversations': '[]',
              'active_conversation_id': 'conv_1',
              'theme': 'dark',
            }),
          ),
        ),
      );
      // v1 二进制：files/ 前缀
      final jpg = Uint8List.fromList(List<int>.generate(4096, (i) => i % 256));
      archive.addFile(
        ArchiveFile('files/pictures/hash_legacy.jpg', jpg.length, jpg),
      );
      // v1 任务：tasks/synthesis_tasks.json
      final tasks = utf8.encode('{"jobs":[]}');
      archive.addFile(
        ArchiveFile('tasks/synthesis_tasks.json', tasks.length, tasks),
      );

      final zipPath = await writeArchive(archive, 'legacy_v1.zip');

      await BackupService.restoreBackup(zipPath);

      // preferences.json → 聊天键 + 设置键分别恢复
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_conversation_id'), equals('conv_1'));
      expect(prefs.getString('theme'), equals('dark'));

      // files/pictures/ → pictures/
      final restoredJpg = await readBackupFile('pictures', 'hash_legacy.jpg');
      expect(restoredJpg, equals(jpg));

      // tasks/synthesis_tasks.json → synthesis/tasks.json
      final restoredTasks = await readBackupFile('synthesis', 'tasks.json');
      expect(utf8.decode(restoredTasks!), equals('{"jobs":[]}'));
    },
  );

  // ==================================================================
  // 选择性恢复：未勾选类别保持原样
  // ==================================================================

  test('restoreBackup with selection skips unselected categories', () async {
    final videoBytes = Uint8List.fromList([1, 2, 3, 4]);
    final textBytes = Uint8List.fromList(utf8.encode('selected text'));
    final archive = buildV2Archive(
      videoRecords: [
        {
          'id': 'v_skip',
          'name': 'v_skip',
          'hash': 'v_skip',
          'format': 'mp4',
          'createdAt': DateTime.now().toIso8601String(),
          'size': videoBytes.length,
          'folder': '',
        },
      ],
      textRecords: [
        {
          'id': 't_keep',
          'name': 't_keep',
          'hash': 't_keep',
          'format': 'txt',
          'createdAt': DateTime.now().toIso8601String(),
          'size': textBytes.length,
          'folder': '',
          'textLength': textBytes.length,
        },
      ],
      files: {'videos/v_skip.mp4': videoBytes, 'texts/t_keep.txt': textBytes},
    );
    final zipPath = await writeArchive(archive, 'selective.zip');

    // 只勾选文本
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: true,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    await BackupService.restoreBackup(zipPath, selection: selection);

    // 未选中的视频：文件与记录都不应出现
    expect(
      await readBackupFile('videos', 'v_skip.mp4'),
      isNull,
      reason: '未勾选的视频类别不得恢复文件',
    );
    expect(
      await ManifestDatabase.getAllVideoRecords(),
      isEmpty,
      reason: '未勾选的视频类别不得恢复记录',
    );

    // 选中的文本：文件与记录都恢复
    final restoredText = await readBackupFile('texts', 't_keep.txt');
    expect(restoredText, equals(textBytes));
    final textRecords = await ManifestDatabase.getAllTextRecords();
    expect(textRecords.length, equals(1));
    expect(textRecords[0]['id'], equals('t_keep'));
  });

  // ==================================================================
  // 校验失败（验证先于删除）：不碰已有数据
  // ==================================================================

  test(
    'invalid backup throws BackupValidationException and keeps data intact',
    () async {
      // 已有数据（文件 + 偏好设置）
      await writeBackupFile(
        'texts',
        'keep.txt',
        Uint8List.fromList(utf8.encode('KEEP')),
      );
      SharedPreferences.setMockInitialValues({'theme': 'light'});

      final garbagePath = '$workDir/garbage.zip';
      await File(
        garbagePath,
      ).writeAsBytes(Uint8List.fromList(List.generate(1024, (i) => i % 256)));

      await expectLater(
        BackupService.restoreBackup(garbagePath),
        throwsA(isA<BackupValidationException>()),
      );

      // 校验失败发生在删除之前：已有数据必须原样保留
      final kept = await readBackupFile('texts', 'keep.txt');
      expect(utf8.decode(kept!), equals('KEEP'), reason: '校验失败的备份不得删除任何已有数据');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), equals('light'));
    },
  );

  test('restoreBackup rejects a zip without manifest.json', () async {
    final archive = Archive();
    archive.addFile(ArchiveFile('stroom_manifest.json', 2, utf8.encode('{}')));
    final zipPath = await writeArchive(archive, 'no_manifest.zip');

    await expectLater(
      BackupService.restoreBackup(zipPath),
      throwsA(isA<BackupValidationException>()),
    );
  });

  // ==================================================================
  // ZIP64 目录（>4GB 备份的大文件格式）：合成 zip64 EOCD + zip64 extra
  // ==================================================================

  test('restoreBackup parses zip64 end-of-central-directory', () async {
    // 手工合成：1 个普通条目（manifest.json）+ 1 个 zip64 条目
    // （local/central 尺寸与偏移字段全部置 0xFFFFFFFF，值放入 zip64 extra）。
    final manifestContent = utf8.encode(
      '{"version":2,"createdAt":"2026-01-01T00:00:00","appVersion":"test"}',
    );
    final binContent = Uint8List.fromList('ZIP64-CONTENT'.codeUnits);

    final b = BytesBuilder(copy: false);

    // ---- 条目 1：manifest.json（普通 store 条目）----
    final mName = utf8.encode('manifest.json');
    writeLocalHeader(
      b,
      mName,
      manifestContent.length,
      crc32: _zipCrc32(manifestContent),
    );
    b.add(manifestContent);

    // ---- 条目 2：pictures/zip64.bin（zip64 尺寸/偏移）----
    final zName = utf8.encode('pictures/zip64.bin');
    final binOffset = b.length;
    writeLocalHeader(
      b,
      zName,
      binContent.length,
      zip64Sizes: true,
      crc32: _zipCrc32(binContent),
    );
    b.add(binContent);

    // ---- 中央目录（zip64 条目在前，普通条目在后）----
    final cdOffset = b.length;
    writeCfh(
      b,
      'pictures/zip64.bin',
      binContent.length,
      binContent.length,
      binOffset,
      zip64Fields: true,
      crc32: _zipCrc32(binContent),
    );
    writeCfh(
      b,
      'manifest.json',
      manifestContent.length,
      manifestContent.length,
      0,
      crc32: _zipCrc32(manifestContent),
    );

    final cdSize = b.length - cdOffset;
    final zip64EocdOffset = b.length;

    // ---- zip64 EOCD（56 字节）----
    b.add(_le32(0x06064b50));
    b.add(_le64(44)); // size of remainder
    b.add(_le16(45));
    b.add(_le16(45));
    b.add(_le32(0));
    b.add(_le32(0));
    b.add(_le64(2)); // entries on disk
    b.add(_le64(2)); // total entries
    b.add(_le64(cdSize));
    b.add(_le64(cdOffset));

    // ---- zip64 EOCD locator（20 字节）----
    b.add(_le32(0x07064b50));
    b.add(_le32(0));
    b.add(_le64(zip64EocdOffset));
    b.add(_le32(1));

    // ---- 普通 EOCD（字段全部 maxed，强制走 zip64 分支）----
    writeEocd(b, entryCount: 0xFFFF, cdSize: 0xFFFFFFFF, cdOffset: 0xFFFFFFFF);

    final zipPath = '$workDir/zip64.zip';
    await File(zipPath).writeAsBytes(b.takeBytes(), flush: true);

    await BackupService.restoreBackup(zipPath);

    final restored = await readBackupFile('pictures', 'zip64.bin');
    expect(restored, equals(binContent), reason: 'zip64 中央目录条目必须被正确解析与流式恢复');
  });

  // ==================================================================
  // 恢复前的条目校验：损坏的条目不得导致已选类别被提前删除。
  // ==================================================================

  test('corrupt binary entry is rejected before restore mutation', () async {
    // manifest 和 stroom_manifest 合法；视频条目是合法但尺寸不符的
    // deflate 流。预检必须在删除现有数据前将其作为无效备份拒绝。
    final manifestContent = utf8.encode(
      '{"version":2,"createdAt":"2026-01-01T00:00:00","appVersion":"test"}',
    );
    final dbContent = utf8.encode(
      jsonEncode({
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
      }),
    );
    // 一个合法但内容极短的 raw deflate 流（解压后 5 字节）
    final shortContent = utf8.encode('SHORT');
    final shortDeflate = Uint8List.fromList(
      ZLibCodec(raw: true).encode(shortContent),
    );

    final b = BytesBuilder(copy: false);
    final mName = utf8.encode('manifest.json');
    writeLocalHeader(
      b,
      mName,
      manifestContent.length,
      crc32: _zipCrc32(manifestContent),
    );
    b.add(manifestContent);
    final dbName = utf8.encode('stroom_manifest.json');
    writeLocalHeader(b, dbName, dbContent.length, crc32: _zipCrc32(dbContent));
    b.add(dbContent);
    final vName = utf8.encode('videos/corrupt.mp4');
    final videoOffset = b.length;
    writeLocalHeader(
      b,
      vName,
      shortDeflate.length,
      crc32: _zipCrc32(shortContent),
      method: 8,
    );
    b.add(shortDeflate);

    final cdOffset = b.length;
    writeCfh(
      b,
      'manifest.json',
      manifestContent.length,
      manifestContent.length,
      0,
      crc32: _zipCrc32(manifestContent),
    );
    writeCfh(
      b,
      'stroom_manifest.json',
      dbContent.length,
      dbContent.length,
      mName.length + 30 + manifestContent.length,
      crc32: _zipCrc32(dbContent),
    );
    writeCfh(
      b,
      'videos/corrupt.mp4',
      shortDeflate.length,
      1000000,
      videoOffset,
      method: 8,
      crc32: _zipCrc32(shortContent),
    );
    final cdSize = b.length - cdOffset;
    writeEocd(b, entryCount: 3, cdSize: cdSize, cdOffset: cdOffset);

    final zipPath = '$workDir/corrupt_binary.zip';
    await File(zipPath).writeAsBytes(b.takeBytes(), flush: true);

    await expectLater(
      BackupService.restoreBackup(zipPath),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test(
    'truncated deflate stream is rejected instead of silent partial restore',
    () async {
      // 截断的 deflate 流：dart:io zlib 不会报错，只输出已解压的部分 ——
      // 解压字节数与中央目录声明不符时必须失败，禁止静默恢复半个文件。
      final fullData = Uint8List.fromList(
        List<int>.generate(128 * 1024, (i) => i % 251),
      );
      final fullDeflate = Uint8List.fromList(
        ZLibCodec(raw: true).encode(fullData),
      );
      // 截掉一半压缩数据
      final truncated = Uint8List.fromList(
        fullDeflate.sublist(0, fullDeflate.length ~/ 2),
      );

      final manifestContent = utf8.encode(
        '{"version":2,"createdAt":"2026-01-01T00:00:00","appVersion":"test"}',
      );
      final dbContent = utf8.encode(
        jsonEncode({
          'image_records': <Map<String, dynamic>>[],
          'audio_records': <Map<String, dynamic>>[],
          'video_records': <Map<String, dynamic>>[],
          'text_records': <Map<String, dynamic>>[],
          'folders': <String>[],
        }),
      );

      final b = BytesBuilder(copy: false);
      final mName = utf8.encode('manifest.json');
      writeLocalHeader(
        b,
        mName,
        manifestContent.length,
        crc32: _zipCrc32(manifestContent),
      );
      b.add(manifestContent);
      final dbName = utf8.encode('stroom_manifest.json');
      writeLocalHeader(
        b,
        dbName,
        dbContent.length,
        crc32: _zipCrc32(dbContent),
      );
      b.add(dbContent);
      final vName = utf8.encode('videos/truncated.mp4');
      final videoOffset = b.length;
      writeLocalHeader(
        b,
        vName,
        truncated.length,
        crc32: _zipCrc32(fullData),
        method: 8,
      );
      b.add(truncated);

      final cdOffset = b.length;
      writeCfh(
        b,
        'manifest.json',
        manifestContent.length,
        manifestContent.length,
        0,
        crc32: _zipCrc32(manifestContent),
      );
      writeCfh(
        b,
        'stroom_manifest.json',
        dbContent.length,
        dbContent.length,
        mName.length + 30 + manifestContent.length,
        crc32: _zipCrc32(dbContent),
      );
      writeCfh(
        b,
        'videos/truncated.mp4',
        truncated.length,
        fullData.length,
        videoOffset,
        method: 8,
        crc32: _zipCrc32(fullData),
      );
      final cdSize = b.length - cdOffset;
      writeEocd(b, entryCount: 3, cdSize: cdSize, cdOffset: cdOffset);

      final zipPath = '$workDir/truncated_deflate.zip';
      await File(zipPath).writeAsBytes(b.takeBytes(), flush: true);

      await expectLater(
        BackupService.restoreBackup(zipPath),
        throwsA(isA<BackupValidationException>()),
      );
      // 绝不允许出现半个文件
      expect(await readBackupFile('videos', 'truncated.mp4'), isNull);
    },
  );

  // ==================================================================
  // zip-slip 防护：含 `..` 路径段的条目名不得逃逸出应用数据目录
  // ==================================================================

  test(
    'restoreBackup skips entries with unsafe path segments (zip-slip guard)',
    () async {
      final archive = buildV2Archive(
        files: {
          'attachments/../../evil.txt': Uint8List.fromList(utf8.encode('EVIL')),
          // 绝对/根路径段：p.join 会把它当作路径重置（Windows 上逃逸）
          'pictures/C:/evil.txt': Uint8List.fromList(utf8.encode('EVIL2')),
          r'videos/\evil.txt': Uint8List.fromList(utf8.encode('EVIL3')),
        },
      );
      final zipPath = await writeArchive(archive, 'zip_slip.zip');

      // 不崩溃、正常完成，且恶意条目都被跳过
      await BackupService.restoreBackup(zipPath);

      expect(
        await readBackupFile('attachments', '../../evil.txt'),
        isNull,
        reason: '含 .. 路径段的条目必须被跳过',
      );
      expect(
        await readBackupFile('pictures', 'C:/evil.txt'),
        isNull,
        reason: '绝对路径条目必须被跳过',
      );
      expect(
        await readBackupFile('videos', r'\evil.txt'),
        isNull,
        reason: '根路径条目必须被跳过',
      );
    },
  );

  // ==================================================================
  // 物理截断的文件（数据区被砍）：解析阶段必须校验失败
  // ==================================================================

  test('restoreBackup rejects a physically truncated zip', () async {
    final archive = buildV2Archive(
      videoRecords: [
        {
          'id': 'v_trunc',
          'name': 'v_trunc',
          'hash': 'v_trunc',
          'format': 'mp4',
          'createdAt': DateTime.now().toIso8601String(),
          'size': 4096,
          'folder': '',
        },
      ],
      files: {
        'videos/v_trunc.mp4': Uint8List.fromList(
          List<int>.generate(4096, (i) => i % 256),
        ),
      },
    );
    final zipPath = await writeArchive(archive, 'truncated_file.zip');
    final full = await File(zipPath).readAsBytes();
    // 整体截断到一半：中央目录偏移超出文件范围，解析阶段必须失败
    await File(zipPath)
        .writeAsBytes(Uint8List.fromList(full.sublist(0, full.length ~/ 2)));

    await expectLater(
      BackupService.restoreBackup(zipPath),
      throwsA(isA<BackupValidationException>()),
    );
  });

  // ==================================================================
  // 恰好 65535 个条目的非 ZIP64 归档：EOCD 满值应回退到 32 位字段
  // ==================================================================

  test(
    'restoreBackup falls back to 32-bit EOCD for exactly 65535 entries',
    () async {
      // 手工合成：1 个真实 manifest 条目 + 65534 个只存在于中央目录的
      // 占位条目（不会匹配已知目录，恢复时被跳过）。EOCD 条目数恰好
      // 是 0xFFFF —— 这是合法值而非 ZIP64 溢出，定位器缺失时应回退。
      final manifestContent = utf8.encode(
        '{"version":2,"createdAt":"2026-01-01T00:00:00","appVersion":"test"}',
      );

      final b = BytesBuilder(copy: false);
      final mName = utf8.encode('manifest.json');
      writeLocalHeader(
        b,
        mName,
        manifestContent.length,
        crc32: _zipCrc32(manifestContent),
      );
      b.add(manifestContent);

      final cdOffset = b.length;
      writeCfh(
        b,
        'manifest.json',
        manifestContent.length,
        manifestContent.length,
        0,
        crc32: _zipCrc32(manifestContent),
      );
      for (var i = 0; i < 65534; i++) {
        final name = 'f${i.toString().padLeft(5, '0')}';
        final nameB = utf8.encode(name);
        b.add(_le32(0x02014b50));
        b.add(_le16(0x0314));
        b.add(_le16(20));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le32(0));
        b.add(_le32(1));
        b.add(_le32(1));
        b.add(_le16(nameB.length));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le16(0));
        b.add(_le32(0));
        b.add(_le32(0));
        b.add(nameB);
      }
      final cdSize = b.length - cdOffset;
      writeEocd(b, entryCount: 65535, cdSize: cdSize, cdOffset: cdOffset);

      final zipPath = '$workDir/65535_entries.zip';
      await File(zipPath).writeAsBytes(b.takeBytes(), flush: true);

      // 能解析（回退 32 位字段）、manifest 校验通过、占位条目被跳过
      await BackupService.restoreBackup(zipPath);
    },
  );

  // ==================================================================
  // 真实生产路径（关闭测试模式）：分块 dart:io 落盘
  // ==================================================================

  test(
    'restoreBackup works on the production path (chunked dart:io writes)',
    () async {
      // 生成大文件备份（生产流式创建）
      final rng = Random(2024);
      final size = 6 * 1024 * 1024;
      final data = Uint8List(size);
      for (var i = 0; i < size; i++) {
        data[i] = rng.nextInt(256);
      }
      // 带当前数据格式版本号：备份中包含后，恢复后的迁移为 no-op，
      // 避免在无插件测试环境触发数据安全检查（与生产一致：备份自带版本记录）。
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode(DataParts.currentVersions),
      });
      final appDir = await AppStorage.directory;
      for (final relativePath in const [
        'synthesis/tasks.json',
        'catcatch/tasks.json',
        'background/tasks.json',
        'task_flows/flows.json',
        'task_flows/executions.json',
      ]) {
        final taskFile = File('$appDir/$relativePath');
        if (await taskFile.exists()) await taskFile.delete();
      }
      final videosDir = Directory('$appDir/videos');
      await videosDir.create(recursive: true);
      addTearDown(() async {
        if (await videosDir.exists()) {
          await videosDir.delete(recursive: true);
        }
      });
      final videoPath = '$appDir/videos/prod_big.mp4';
      await File(videoPath).writeAsBytes(data, flush: true);

      await ManifestDatabase.clearAllData();
      await ManifestDatabase.insertVideoRecord({
        'id': 'prod_big',
        'name': 'prod_big',
        'hash': 'prod_big',
        'format': 'mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'size': size,
        'folder': '',
      });

      // 关闭测试模式 → 走真实生产路径（磁盘文件进备份计划 + 后台 isolate）
      WebFileStore.disableTestMode();
      addTearDown(() {
        ManifestDatabase.enableTestMode();
      });

      final zipPath = '$workDir/prod_backup.zip';
      await BackupService.createBackup(outputPath: zipPath);

      // 先清掉目标文件，再走真实生产恢复路径（分块 dart:io 落盘）
      if (await File(videoPath).exists()) {
        await File(videoPath).delete();
      }
      await BackupService.restoreBackup(zipPath, skipMissingCategories: true);

      final restoredFile = File(videoPath);
      expect(
        await restoredFile.exists(),
        isTrue,
        reason: '生产路径恢复必须把大文件写回应用数据目录',
      );
      final restoredBytes = await restoredFile.readAsBytes();
      expect(restoredBytes, equals(data), reason: '生产路径（分块 dart:io 落盘）不得损坏大文件');
    },
  );
}

// ---- 手工合成 ZIP 的小端字节工具 ----

/// 写 ZIP 本地文件头（store 或 deflate，可选 zip64 满值尺寸）。
void writeLocalHeader(
  BytesBuilder b,
  Uint8List name,
  int dataLen, {
  required int crc32,
  bool zip64Sizes = false,
  int method = 0,
}) {
  b.add(_le32(0x04034b50));
  b.add(_le16(20)); // version needed
  b.add(_le16(0)); // flags
  b.add(_le16(method));
  b.add(_le16(0));
  b.add(_le16(0));
  b.add(_le32(crc32));
  if (zip64Sizes) {
    b.add(_le32(0xFFFFFFFF));
    b.add(_le32(0xFFFFFFFF));
  } else {
    b.add(_le32(dataLen));
    b.add(_le32(dataLen));
  }
  b.add(_le16(name.length));
  b.add(_le16(0)); // extra
  b.add(name);
}

/// 写 ZIP 中央目录条目（store 或 deflate，可选 zip64 extra）。
void writeCfh(
  BytesBuilder b,
  String name,
  int comp,
  int uncomp,
  int offset, {
  required int crc32,
  bool zip64Fields = false,
  int method = 0,
}) {
  final nameB = utf8.encode(name);
  b.add(_le32(0x02014b50));
  b.add(_le16(0x0314)); // version made by
  b.add(_le16(20));
  b.add(_le16(0)); // flags
  b.add(_le16(method));
  b.add(_le16(0));
  b.add(_le16(0));
  b.add(_le32(crc32));
  if (zip64Fields) {
    b.add(_le32(0xFFFFFFFF));
    b.add(_le32(0xFFFFFFFF));
  } else {
    b.add(_le32(comp));
    b.add(_le32(uncomp));
  }
  b.add(_le16(nameB.length));
  b.add(_le16(zip64Fields ? 28 : 0)); // extra len
  b.add(_le16(0)); // comment len
  b.add(_le16(0)); // disk
  b.add(_le16(0)); // internal attrs
  b.add(_le32(0)); // external attrs
  b.add(_le32(zip64Fields ? 0xFFFFFFFF : offset)); // local header offset
  b.add(nameB);
  if (zip64Fields) {
    b.add(_le16(0x0001)); // zip64 extra id
    b.add(_le16(24)); // data size
    b.add(_le64(uncomp));
    b.add(_le64(comp));
    b.add(_le64(offset));
  }
}

/// 写 ZIP End Of Central Directory（22 字节 + 可选注释）。
void writeEocd(
  BytesBuilder b, {
  required int entryCount,
  required int cdSize,
  required int cdOffset,
}) {
  b.add(_le32(0x06054b50));
  b.add(_le16(0));
  b.add(_le16(0));
  b.add(_le16(entryCount));
  b.add(_le16(entryCount));
  b.add(_le32(cdSize));
  b.add(_le32(cdOffset));
  b.add(_le16(0)); // comment len
}

Uint8List _le16(int v) => Uint8List.fromList([v & 0xff, (v >> 8) & 0xff]);

int _zipCrc32(List<int> bytes) {
  var checksum = 0xffffffff;
  for (final byte in bytes) {
    checksum ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      checksum = (checksum & 1) != 0
          ? (checksum >> 1) ^ 0xedb88320
          : checksum >> 1;
    }
  }
  return (checksum ^ 0xffffffff) & 0xffffffff;
}

Uint8List _le32(int v) => Uint8List.fromList([
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
]);

Uint8List _le64(int v) {
  final b = Uint8List(8);
  for (var i = 0; i < 8; i++) {
    b[i] = (v >> (8 * i)) & 0xff;
  }
  return b;
}
