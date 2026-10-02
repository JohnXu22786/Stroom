import 'package:uuid/uuid.dart';

import '../../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../../catcatch/models/media_kind.dart';
import '../../../catcatch/models/media_resource.dart';
import '../../../catcatch/providers/catcatch_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../models/block_type_definition.dart';
import '../../models/io_type.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
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
  Duration pollInterval = const Duration(milliseconds: 500),
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
    await Future.delayed(pollInterval);
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
    } else if (task.status != catcatch.TaskStatus.completed &&
        task.status != catcatch.TaskStatus.failed &&
        DateTime.now().difference(lastProgressAt) > stallTimeout) {
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
      final path = task.downloadedFilePath;
      if (path == null || path.isEmpty) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '下载完成但无文件路径',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      final actualType = catCatchOutputType(task);
      if (actualType != def.outputType) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '下载结果为${actualType.label}，此步骤声明输出${def.outputType.label}；请修改输出类型或选择匹配的资源',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      execNotifier.updateSubTaskStatus(
        execId,
        flowSubTask.id,
        TaskStatus.completed,
      );
      return path;
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
            final selected = selectAutomaticCatCatchResource(
              task.detectedMedia,
              desiredType: def.outputType,
            );
            if (selected == null) {
              throw const FormatException('没有可安全自动选择的完整资源，请在 CatCatch 页面单独下载');
            }
            catcatchNotifier.selectMedia(taskId, selected);
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

/// Discovery order depends on network timing. Choose a complete video before
/// a playlist, then audio; URL and metadata break ties consistently. Split
/// tracks need a separate audio/video merge decision and are never guessed.
MediaResource? selectAutomaticCatCatchResource(
  List<MediaResource> resources, {
  IOType? desiredType,
}) {
  int rank(MediaResource media) {
    final mime = media.mimeType?.split(';').first.trim().toLowerCase() ?? '';
    if (mime.startsWith('audio/') || media.isAudio) return 2;
    if (media.isPlaylist) return 1;
    if (mime.startsWith('video/') || media.isVideo) return 0;
    return 3;
  }

  final candidates = resources.where((media) {
    final priority = rank(media);
    if (media.isLikelySplitTrack || priority == 3) return false;
    if (desiredType == IOType.audio) return priority == 2;
    if (desiredType == IOType.video) return priority < 2;
    return true;
  }).toList();
  candidates.sort((a, b) {
    final priority = rank(a).compareTo(rank(b));
    if (priority != 0) return priority;
    final url = a.url.compareTo(b.url);
    if (url != 0) return url;
    return '${a.name}|${a.ext}|${a.mimeType}|${a.groupId}'.compareTo(
      '${b.name}|${b.ext}|${b.mimeType}|${b.groupId}',
    );
  });
  return candidates.firstOrNull;
}

/// Keep the flow's declared output in sync with the engine's gallery routing.
IOType catCatchOutputType(catcatch.CatCatchTask task) {
  return switch (catCatchMediaKind(task, task.downloadedFilePath ?? '')) {
    CatCatchMediaKind.audio => IOType.audio,
    CatCatchMediaKind.video => IOType.video,
    CatCatchMediaKind.other => IOType.file,
  };
}

/// Compact signature of everything that constitutes "visible progress" for
/// a CatCatch task: status, per-step completion flags + progress, received
/// bytes (byte-granularity — percent progress stays 0 for chunked
/// downloads without Content-Length), the selected media, and the
/// pending-confirm flag.
String _progressSignatureOf(catcatch.CatCatchTask? task) {
  if (task == null) return '';
  final steps = task.steps
      .map(
        (s) =>
            '${s.type.name}:${s.completed}:${s.skipped}:${s.failed}:${s.progress}',
      )
      .join('|');
  return '${task.status.name}|${task.downloadedBytes}|'
      '${task.selectedMedia?.url}|${task.metadata['pendingConfirm']}|$steps';
}
