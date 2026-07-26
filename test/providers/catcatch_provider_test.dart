import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/config/default_rules.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('CatCatchNotifier.cleanupTaskFiles', () {
    late Directory tempDir;
    late String appDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('catcatch_test_');
      appDir = tempDir.path;
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    /// Helper to create a task.
    CatCatchTask createTask({
      required String id,
      required TaskStatus status,
      MediaResource? selectedMedia,
      String? downloadedFilePath,
      Map<String, String>? metadata,
    }) {
      return CatCatchTask(
        id: id,
        url: 'https://example.com/video.mp4',
        expectedDurationSec: 120,
        title: '测试视频',
        status: status,
        steps: StepType.values.map((t) => StepStatus.pending(t)).toList(),
        createdAt: DateTime.now(),
        selectedMedia: selectedMedia,
        downloadedFilePath: downloadedFilePath,
        metadata: metadata ?? const {},
      );
    }

    MediaResource createMedia() {
      return MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'test_video',
        ext: 'mp4',
        initiator: 'https://example.com',
        isPlayable: true,
      );
    }

    /// Create common temp files for a download task.
    Future<void> createTempFiles(String taskId, String fileName) async {
      // Downloads directory
      final downloadDir = Directory(p.join(appDir, 'catcatch', 'downloads'));
      await downloadDir.create(recursive: true);

      // Temp file — DownloadManager creates it without leading dot
      await File(
        p.join(downloadDir.path, '$fileName${DefaultRules.tempFileSuffix}'),
      ).writeAsString('partial data');

      // Progress file
      final progressDir = Directory(p.join(appDir, 'catcatch', '.progress'));
      await progressDir.create(recursive: true);
      await File(
        p.join(progressDir.path, '${taskId}_dl_progress.json'),
      ).writeAsString(jsonEncode({'completed': 5}));

      // Converted file
      final convertDir = Directory(p.join(appDir, 'catcatch', 'converted'));
      await convertDir.create(recursive: true);
      await File(
        p.join(convertDir.path, 'test_video.mp4'),
      ).writeAsString('converted data');
    }

    // ====================================================================
    // Tests
    // ====================================================================

    test('deletes temp download file and progress for running task', () async {
      final media = createMedia();
      final taskId = 'test-1';
      final task = createTask(
        id: taskId,
        status: TaskStatus.running,
        selectedMedia: media,
      );
      final fileName = 'test_video.mp4';
      await createTempFiles(taskId, fileName);

      // Verify files exist (both dot-prefixed and non-dot-prefixed temp variants)
      final noDotTemp = File(p.join(appDir, 'catcatch', 'downloads',
          '$fileName${DefaultRules.tempFileSuffix}'));
      final dotTemp = File(p.join(appDir, 'catcatch', 'downloads',
          '.${fileName}${DefaultRules.tempFileSuffix}'));
      expect(noDotTemp.existsSync(), isTrue);
      expect(dotTemp.existsSync(), isFalse,
          reason:
              'Dot-prefixed temp file should not exist (createTempFiles creates non-dot)');
      expect(
        File(p.join(
                appDir, 'catcatch', '.progress', '${taskId}_dl_progress.json'))
            .existsSync(),
        isTrue,
      );

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      // Files deleted
      expect(noDotTemp.existsSync(), isFalse);
      expect(
          dotTemp.existsSync(), isFalse); // should also be handled gracefully
      expect(
        File(p.join(
                appDir, 'catcatch', '.progress', '${taskId}_dl_progress.json'))
            .existsSync(),
        isFalse,
      );
    });

    test('deletes converted file', () async {
      final media = createMedia();
      final task = createTask(
        id: 'test-convert',
        status: TaskStatus.running,
        selectedMedia: media,
      );
      await createTempFiles('test-convert', 'test_video.mp4');

      final convertFile =
          File(p.join(appDir, 'catcatch', 'converted', 'test_video.mp4'));
      expect(convertFile.existsSync(), isTrue);

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(convertFile.existsSync(), isFalse);
    });

    test('deletes segment parts directory for playlist downloads', () async {
      final media = MediaResource(
        url: 'https://example.com/playlist.m3u8',
        name: 'playlist',
        ext: 'm3u8',
        isPlaylist: true,
      );
      final taskId = 'test-playlist';
      final task = createTask(
        id: taskId,
        status: TaskStatus.running,
        selectedMedia: media,
      );

      // Create segment parts dir (naming: .{mergedFilename}_parts/)
      final downloadDir = Directory(p.join(appDir, 'catcatch', 'downloads'));
      await downloadDir.create(recursive: true);
      // For playlist with name='playlist' and ext='m3u8', buildDownloadFileName returns
      // 'playlist.m3u8', basenameWithoutExtension = 'playlist', so merged file is
      // 'playlist_merged.ts' and parts dir is '.playlist_merged.ts_parts'
      final partsDir =
          Directory(p.join(downloadDir.path, '.playlist_merged.ts_parts'));
      await partsDir.create(recursive: true);
      await File(p.join(partsDir.path, 'part_0')).writeAsString('data');

      // Create merged playlist file
      await File(p.join(downloadDir.path, 'playlist_merged.ts'))
          .writeAsString('data');

      expect(partsDir.existsSync(), isTrue);
      expect(File(p.join(downloadDir.path, 'playlist_merged.ts')).existsSync(),
          isTrue);

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(partsDir.existsSync(), isFalse);
      expect(File(p.join(downloadDir.path, 'playlist_merged.ts')).existsSync(),
          isFalse);
    });

    test('does NOT delete downloadedFilePath for completed tasks', () async {
      final completedDir = Directory(p.join(appDir, 'catcatch', 'completed'));
      await completedDir.create(recursive: true);
      final completedFile = File(p.join(completedDir.path, 'test_video.mp4'));
      await completedFile.writeAsString('completed data');

      final task = createTask(
        id: 'test-completed',
        status: TaskStatus.completed,
        selectedMedia: createMedia(),
        downloadedFilePath: completedFile.path,
      );

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(completedFile.existsSync(), isTrue,
          reason: 'Completed task final file should NOT be deleted');
    });

    test('deletes downloadedFilePath for non-completed tasks', () async {
      final downloadDir = Directory(p.join(appDir, 'catcatch', 'downloads'));
      await downloadDir.create(recursive: true);
      final partialFile = File(p.join(downloadDir.path, 'partial_video.mp4'));
      await partialFile.writeAsString('partial');

      final task = createTask(
        id: 'test-failed',
        status: TaskStatus.failed,
        downloadedFilePath: partialFile.path,
      );

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(partialFile.existsSync(), isFalse,
          reason: 'Failed task partial file should be deleted');
    });

    test('is no-op when selectedMedia is null (no download started yet)',
        () async {
      final task = createTask(
        id: 'test-no-media',
        status: TaskStatus.running,
        selectedMedia: null,
      );

      await expectLater(
        () => CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir),
        returnsNormally,
      );
    });

    test('is no-op when temp files do not exist', () async {
      final task = createTask(
        id: 'test-no-files',
        status: TaskStatus.running,
        selectedMedia: createMedia(),
      );

      await expectLater(
        () => CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir),
        returnsNormally,
      );
    });

    test('handles non-existent downloadedFilePath gracefully', () async {
      final badPath = p.join(appDir, 'nonexistent', 'file.mp4');
      final task = createTask(
        id: 'test-bad-path',
        status: TaskStatus.failed,
        selectedMedia: createMedia(),
        downloadedFilePath: badPath,
      );

      await expectLater(
        () => CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir),
        returnsNormally,
      );
    });

    test('handles page-title based download filenames', () async {
      final media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'original_name',
        ext: 'mp4',
      );
      final taskId = 'test-pagetitle';
      final task = CatCatchTask(
        id: taskId,
        url: 'https://example.com/page',
        expectedDurationSec: 120,
        title: '测试页面标题',
        status: TaskStatus.running,
        steps: StepType.values.map((t) => StepStatus.pending(t)).toList(),
        createdAt: DateTime.now(),
        selectedMedia: media,
        metadata: {'pageTitle': '页面标题'},
      );

      final fileName = '页面标题.mp4';
      await createTempFiles(taskId, fileName);

      final noDotTempPath = p.join(
        appDir,
        'catcatch',
        'downloads',
        '$fileName${DefaultRules.tempFileSuffix}',
      );
      expect(File(noDotTempPath).existsSync(), isTrue,
          reason: 'Page-title based temp file should exist before cleanup');

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(File(noDotTempPath).existsSync(), isFalse,
          reason: 'Page-title based temp file should be deleted after cleanup');
    });

    test('deletes both download file and temp file for paused tasks', () async {
      final media = createMedia();
      final taskId = 'test-paused';
      final task = createTask(
        id: taskId,
        status: TaskStatus.paused,
        selectedMedia: media,
      );
      final fileName = 'test_video.mp4';
      await createTempFiles(taskId, fileName);

      // Also create the base download file (without temp suffix)
      final downloadFile =
          File(p.join(appDir, 'catcatch', 'downloads', fileName));
      await downloadFile.writeAsString('partial download');

      // Also create the dot-prefixed temp variant (used by task_executor for resume)
      final dotTempFile = File(
        p.join(appDir, 'catcatch', 'downloads',
            '.${fileName}${DefaultRules.tempFileSuffix}'),
      );
      await dotTempFile.writeAsString('partial data');

      await CatCatchNotifier.cleanupTaskFiles(task, appDirPath: appDir);

      expect(downloadFile.existsSync(), isFalse,
          reason: 'Download file itself should be deleted for paused task');
      expect(
        File(p.join(appDir, 'catcatch', 'downloads',
                '.${fileName}${DefaultRules.tempFileSuffix}'))
            .existsSync(),
        isFalse,
        reason: 'Dot-prefixed temp file should be deleted for paused task',
      );
      expect(
        File(p.join(appDir, 'catcatch', 'downloads',
                '$fileName${DefaultRules.tempFileSuffix}'))
            .existsSync(),
        isFalse,
        reason: 'Non-dot-prefixed temp file should be deleted for paused task',
      );
    });
  });
}
