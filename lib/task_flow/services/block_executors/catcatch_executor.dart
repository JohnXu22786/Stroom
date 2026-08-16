import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../../catcatch/providers/catcatch_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'catcatch_output_registrator.dart';
import 'shared_helpers.dart';

Future<String> executeCatCatchBlock({
  required BlockTypeDefinition def,
  required TaskFlowBlock block,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required CatCatchNotifier catcatchNotifier,
  String videoFolder = '',
  String audioFolder = '',
  /// Per-run duration (seconds) from the run-mode input box. When > 0 it
  /// overrides the block's configured `durationSec`; 0 = use the block's
  /// configured value. Lets a CatCatch-first flow reuse the CatCatch
  /// page's URL + 时/分/秒 input box semantics.
  int durationSecOverride = 0,
  Duration stallTimeout = const Duration(minutes: 10),
}) async {
  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  final durationSec = durationSecOverride > 0
      ? durationSecOverride
      : asIntParam(block.params, 'durationSec', 0);
  catcatchNotifier.addTask(
    input,
    durationSec,
    taskId: taskId,
    videoFolder: videoFolder,
    audioFolder: audioFolder,
  );

  // Stall detection instead of a wall-clock deadline: a large download or
  // long conversion updates step progress continuously, so a healthy task
  // is never killed — only a task with NO progress change for
  // [stallTimeout] is abandoned (and its engine work cancelled).
  var lastProgressSignature = _progressSignatureOf(
    catcatchNotifier.state.where((t) => t.id == taskId).firstOrNull,
  );
  var lastProgressAt = DateTime.now();
  bool autoSelected = false;
  bool autoConfirmed = false;

  while (true) {
    await Future.delayed(const Duration(milliseconds: 500));
    final task =
        catcatchNotifier.state.where((t) => t.id == taskId).firstOrNull;

    if (task == null) {
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.failed,
      );
      throw BlockExecutionException(
        '任务丢失',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    final signature = _progressSignatureOf(task);
    if (signature != lastProgressSignature) {
      lastProgressSignature = signature;
      lastProgressAt = DateTime.now();
    } else if (DateTime.now().difference(lastProgressAt) > stallTimeout) {
      // No progress for the stall window — cancel the engine work and
      // fail the block. removeTask cancels the pipeline's CancelToken and
      // cleans up partial files.
      catcatchNotifier.removeTask(taskId);
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.failed,
      );
      throw BlockExecutionException(
        '下载无进展，已取消',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    if (task.status == catcatch.TaskStatus.completed) {
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.completed,
      );
      if (task.downloadedFilePath != null) {
        // Best-effort gallery registration, mirroring the engine's own
        // swallow behavior: on web the dart:io/Isolate-based registrator
        // cannot run, and a registration hiccup must not fail a
        // successfully completed download.
        try {
          await registerFlowCatCatchOutput(task.downloadedFilePath!, task);
        } catch (e) {
          debugPrint('[TaskFlow] registerFlowCatCatchOutput failed: $e');
        }
        return task.downloadedFilePath!;
      }
      throw BlockExecutionException(
        '下载完成但无文件路径',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    if (task.status == catcatch.TaskStatus.failed) {
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.failed,
      );
      throw BlockExecutionException(
        task.error ?? '任务失败',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    if (task.status == catcatch.TaskStatus.paused) {
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.paused,
      );
      throw BlockExecutionException(
        '任务已暂停',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }

    if (!autoSelected) {
      final us = task.steps.where(
        (s) => s.type == catcatch.StepType.userSelecting,
      );
      if (us.isNotEmpty && !us.first.completed && !us.first.skipped) {
        if (task.detectedMedia.isNotEmpty) {
          try {
            catcatchNotifier.selectMedia(taskId, task.detectedMedia.first);
            autoSelected = true;
            execNotifier.updateSubTaskStatus(
              execId,
              flowSubTask.id,
              TaskStatus.running,
            );
          } catch (e) {
            // The flow gives up on a live task — cancel its engine work.
            catcatchNotifier.removeTask(taskId);
            execNotifier.updateSubTaskStatus(
              execId,
              flowSubTask.id,
              TaskStatus.failed,
            );
            throw BlockExecutionException(
              '自动选择媒体失败: $e',
              blockType: def.typeKey.name,
              blockTitle: def.label,
            );
          }
        }
      }
    }

    if (!autoConfirmed && task.metadata['pendingConfirm'] == 'special_format') {
      autoConfirmed = true;
      try {
        catcatchNotifier.confirmAndContinue(taskId);
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.running,
        );
      } catch (e) {
        // The flow gives up on a live task — cancel its engine work.
        catcatchNotifier.removeTask(taskId);
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '自动处理特殊格式失败: $e',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
    }
  }
}

/// Compact signature of everything that constitutes "visible progress" for
/// a CatCatch task: status, per-step completion flags + progress, received
/// bytes (byte-granularity — percent progress stays 0 for chunked
/// downloads without Content-Length), the selected media, and the
/// pending-confirm flag.
String _progressSignatureOf(catcatch.CatCatchTask? task) {
  if (task == null) return '';
  final steps = task.steps
      .map((s) =>
          '${s.type.name}:${s.completed}:${s.skipped}:${s.failed}:${s.progress}')
      .join('|');
  return '${task.status.name}|${task.downloadedBytes}|'
      '${task.selectedMedia?.url}|${task.metadata['pendingConfirm']}|$steps';
}
