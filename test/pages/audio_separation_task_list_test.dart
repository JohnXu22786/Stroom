import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/pages/audio_separation_shared.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  group('AudioSeparationPage - Shared', () {
    test('detectFormat returns correct format from filename', () {
      expect(detectFormat('video.mp4'), 'mp4');
      expect(detectFormat('video.mov'), 'mov');
      expect(detectFormat('video.avi'), 'avi');
      expect(detectFormat('video.mkv'), 'mkv');
      expect(detectFormat('video.webm'), 'webm');
      expect(detectFormat('video.flv'), 'flv');
      expect(detectFormat('video.m4v'), 'm4v');
      expect(detectFormat('video.3gp'), '3gp');
      expect(detectFormat('video.unknown'), 'mp4');
      expect(detectFormat(null), 'mp4');
    });

    test('formatFileSize returns correct string', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1048576), '1.0 MB');
      expect(formatFileSize(2097152), '2.0 MB');
    });

    test('SelectedVideo can be created', () {
      final video = SelectedVideo(
        bytes: Uint8List.fromList([0, 1, 2]),
        name: 'test.mp4',
        format: 'mp4',
      );
      expect(video.bytes.length, 3);
      expect(video.name, 'test.mp4');
      expect(video.format, 'mp4');
    });

    test('SelectedVideo defaults format to mp4', () {
      final video = SelectedVideo(
        bytes: Uint8List.fromList([0]),
        name: 'test.mov',
      );
      expect(video.format, 'mp4');
    });

    test('ChoiceCard can be created', () {
      // Just verify the widget can be instantiated without error
      expect(
        () => ChoiceCard(
          icon: Icons.video_library,
          title: 'Test',
          subtitle: 'Subtitle',
          color: Colors.green,
          onTap: () {},
        ),
        returnsNormally,
      );
    });
  });

  group('BackgroundTaskNotifier - Batch add tasks', () {
    test('addTask can add multiple tasks simultaneously', () {
      final notifier = BackgroundTaskNotifier();

      // Simulate batch-adding all tasks before processing
      final ids = <String>[];
      for (int i = 0; i < 3; i++) {
        final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: '音频分离_视频$i',
        );
        ids.add(id);
      }

      expect(notifier.state.length, 3);
      expect(ids.length, 3);
      expect(ids[0], isNot(ids[1]));
      expect(ids[1], isNot(ids[2]));

      // All tasks should be in running state
      for (final task in notifier.state) {
        expect(task.status, TaskStatus.running);
        expect(task.type, BackgroundTaskType.audioSeparation);
      }

      // Task titles should be unique (newest first order)
      expect(notifier.state[0].title, '音频分离_视频2');
      expect(notifier.state[1].title, '音频分离_视频1');
      expect(notifier.state[2].title, '音频分离_视频0');
    });

    test('batch-added tasks can be updated individually by ID', () {
      final notifier = BackgroundTaskNotifier();

      final ids = <String>[];
      for (int i = 0; i < 3; i++) {
        ids.add(notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: 'Task $i',
        ));
      }

      // Update step 0 of task 0 to running
      notifier.updateStep(ids[0], 0, running: true);
      expect(notifier.state.firstWhere((t) => t.id == ids[0]).steps[0].running,
          true);
      // Other tasks should still have pending steps
      for (int i = 1; i < 3; i++) {
        expect(
          notifier.state.firstWhere((t) => t.id == ids[i]).steps[0].status,
          BgStepStatus.pending,
        );
      }

      // Complete task 0
      notifier.completeTask(ids[0], downloadedFilePath: '/path/file.mp3');
      expect(notifier.state.firstWhere((t) => t.id == ids[0]).status,
          TaskStatus.completed);
      expect(
        notifier.state.firstWhere((t) => t.id == ids[0]).downloadedFilePath,
        '/path/file.mp3',
      );

      // Fail task 1
      notifier.failTask(ids[1], error: '提取失败');
      expect(notifier.state.firstWhere((t) => t.id == ids[1]).status,
          TaskStatus.failed);
      expect(
        notifier.state.firstWhere((t) => t.id == ids[1]).error,
        '提取失败',
      );

      // Task 2 should still be running
      expect(notifier.state.firstWhere((t) => t.id == ids[2]).status,
          TaskStatus.running);
    });

    test('batch add followed by complete keeps all tasks visible', () {
      final notifier = BackgroundTaskNotifier();

      // Add 5 tasks at once
      final ids = <String>[];
      for (int i = 0; i < 5; i++) {
        ids.add(notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: 'Task $i',
        ));
      }

      expect(notifier.state.length, 5);

      // Complete all tasks
      for (final id in ids) {
        notifier.completeTask(id);
      }

      // All 5 should remain visible as completed
      expect(notifier.state.length, 5);
      for (final task in notifier.state) {
        expect(task.status, TaskStatus.completed);
      }
    });

    test('audio separation task has correct step labels', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: '音频分离_test',
      );

      final task = notifier.state.firstWhere((t) => t.id == id);
      expect(task.steps.length, 2);
      expect(task.steps[0].label, '分离音频');
      expect(task.steps[1].label, '保存到文件');
    });
  });
}
