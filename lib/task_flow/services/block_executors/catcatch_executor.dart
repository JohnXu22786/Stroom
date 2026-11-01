import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:uuid/uuid.dart';

import '../../../catcatch/engine/executor_save.dart'
    show CompletedMediaRegistration;

import '../../../catcatch/models/media_resource.dart';
import '../../../catcatch/models/media_kind.dart';

import '../../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../../catcatch/providers/catcatch_provider.dart';
import '../../../providers/task_provider_shared.dart';
import '../../models/block_type_definition.dart';
import '../../models/flow_payload.dart';
import '../../models/io_type.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'catcatch_output_registrator.dart';
import 'shared_helpers.dart';
import '../task_flow_execution_service.dart' show catCatchOutputPayload;

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
  bool temporaryOutput = false,

  /// Per-run duration (seconds) from the run-mode input box. When > 0 it
  /// overrides the block's configured `durationSec`; 0 = use the block's
  /// configured value. Lets a CatCatch-first flow reuse the CatCatch
  /// page's URL + 时/分/秒 input box semantics.
  int durationSecOverride = 0,
  Duration stallTimeout = const Duration(minutes: 10),
  Duration pollInterval = const Duration(milliseconds: 500),
  @visibleForTesting void Function()? onFallbackRegistration,
  IOType? nextInputType,
  void Function(String taskId)? onManualWait,
  void Function(String taskId, List<MediaResource> candidates)?
      onManualWaitWithCandidates,
  void Function(IOType type)? onOutputType,
  void Function(FlowPayload payload)? onOutputPayload,
}) async {
  final outputTypes = block.outputTypesForNext(nextInputType);
  if (outputTypes.isEmpty ||
      (nextInputType != null &&
          !outputTypes.any((type) => type.isCompatibleWith(nextInputType)))) {
    throw BlockExecutionException(
      block.followsDownstreamOutput
          ? '下游需要${nextInputType?.label ?? '兼容的媒体类型'}，下载资源没有可匹配的音频或视频类型'
          : '下载输出类型与下一步输入不兼容，请修改输出策略',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
  final resolvedOutputType = outputTypes.length == 1
      ? outputTypes.single
      : null;
  final selectionPolicy = block.catCatchResourceSelectionPolicy;
  final automatic = selectionPolicy != 'manual';
  final automaticWithPrompt = selectionPolicy == 'automaticWithPrompt';
  final desiredType = resolvedOutputType;
  final taskId = const Uuid().v4();
  if (temporaryOutput) {
    if (!await execNotifier.updateSubTaskIdPersisted(
      execId,
      flowSubTask.id,
      taskId,
    )) {
      throw BlockExecutionException(
        '无法保存临时任务标识',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    if (!execNotifier.startSubTaskIfActive(execId, flowSubTask.id, taskId)) {
      throw BlockExecutionException(
        '任务流已暂停或结束，未启动临时下载任务',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
  } else {
    execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.running,
    );
  }
  final durationSec = durationSecOverride > 0
      ? durationSecOverride
      : asIntParam(block.params, 'durationSec', 0);
  if (temporaryOutput) {
    catcatchNotifier.addTemporaryTask(
      input,
      durationSec,
      taskId: taskId,
      executionId: execId,
      blockId: block.id,
      flowManagedSelection: automaticWithPrompt,
      deferSingleResourceSelection: automatic,
    );
  } else {
    catcatchNotifier.addTask(
      input,
      durationSec,
      taskId: taskId,
      videoFolder: videoFolder,
      audioFolder: audioFolder,
      flowManagedSelection: automaticWithPrompt,
      deferSingleResourceSelection: automatic,
    );
  }

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
  bool promptOpen = false;

  bool isCurrent() {
    if (!execNotifier.mounted || !isFlowExecutionActive(execNotifier, execId)) {
      return false;
    }
    try {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      return catcatchNotifier.state.any(
        (current) =>
          current.id == taskId &&
            current.status == catcatch.TaskStatus.completed,
      );
    } catch (_) {
      return false;
    }
  }

  while (true) {
    await Future.delayed(pollInterval);
    final execution = execNotifier.mounted
        ? execNotifier.executions
            .where((execution) => execution.id == execId)
            .firstOrNull
        : null;
    if (execution == null || execution.isTerminal) {
      if (catcatchNotifier.mounted) catcatchNotifier.removeTask(taskId);
      throw BlockExecutionException(
        '任务流已删除或已停止',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    final task = catcatchNotifier.state
        .where((t) => t.id == taskId)
        .firstOrNull;

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
    final awaitingSelection =
        task.selectedMedia == null &&
        task.steps.any(
          (step) =>
              step.type == catcatch.StepType.userSelecting &&
              step.running &&
              !step.completed &&
              !step.skipped,
        );
    final awaitingConfirmation =
        task.metadata['pendingConfirm'] == 'special_format';
    // Waiting for an intentional human decision or a user pause is not a stall.
    // Reset the window so resumed engine work receives a full stall allowance.
    if (!awaitingSelection || task.selectedMedia != null) promptOpen = false;
    if (automaticWithPrompt &&
        awaitingSelection &&
        task.detectedMedia.isNotEmpty) {
      final candidates = catCatchSafeResourceCandidates(
        task.detectedMedia,
        desiredType: desiredType,
      );
      if (candidates.length != 1 &&
          task.status == catcatch.TaskStatus.running) {
        if (!promptOpen) {
          final promptCandidates = catCatchPromptResourceCandidates(
            task.detectedMedia,
            desiredType: desiredType,
          );
          if (promptCandidates.isEmpty) {
            catcatchNotifier.removeTask(taskId);
            execNotifier.updateSubTaskStatus(
              execId,
              flowSubTask.id,
              TaskStatus.failed,
            );
            throw BlockExecutionException(
              '没有与下游输入类型兼容的媒体资源可供选择',
              blockType: def.typeKey.name,
              blockTitle: def.label,
            );
          }
          onManualWaitWithCandidates?.call(taskId, promptCandidates);
          onManualWait?.call(taskId);
        }
        promptOpen = true;
      }
    }
    final intentionallyWaiting =
        task.status == catcatch.TaskStatus.paused ||
        promptOpen ||
        (!automatic && (awaitingSelection || awaitingConfirmation));
    if (!automatic &&
        task.status == catcatch.TaskStatus.running &&
        ((awaitingSelection && task.detectedMedia.length > 1) ||
            awaitingConfirmation)) {
      onManualWait?.call(taskId);
    }
    if (intentionallyWaiting || signature != lastProgressSignature) {
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
      final actualType = await catCatchOutputType(task);
      if (actualType == IOType.file) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '无法验证下载文件的音视频类型，请检查媒体文件',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      if ((resolvedOutputType != null && actualType != resolvedOutputType) ||
          (nextInputType != null &&
              !actualType.isCompatibleWith(nextInputType))) {
        execNotifier.updateSubTaskStatus(
          execId,
          flowSubTask.id,
          TaskStatus.failed,
        );
        throw BlockExecutionException(
          '下载结果为${actualType.label}，此步骤要求输出${resolvedOutputType?.label ?? '音频或视频'}${nextInputType == null ? '' : '，下一步需要${nextInputType.label}'}；请修改输出类型或重新选择匹配的资源',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      onOutputType?.call(actualType);
      onOutputPayload?.call(await catCatchOutputPayload(path));
      // Native saves have already registered this exact completed path.
      // Legacy and mocked tasks still use the cancellation-aware fallback.
      CompletedMediaRegistration? registration;
      if (!temporaryOutput &&
          task.metadata[catcatch.CatCatchTask.nativeRegisteredPathKey] !=
              path) {
        try {
          onFallbackRegistration?.call();
          registration = await registerFlowCatCatchOutput(
            path,
            task,
            isCurrent: isCurrent,
          );
        } catch (e) {
          if (!isCurrent()) {
            throw BlockExecutionException(
              '任务已取消',
              blockType: def.typeKey.name,
              blockTitle: def.label,
            );
          }
          debugPrint('[TaskFlow] registerFlowCatCatchOutput failed: $e');
        }
      }
      if (!isCurrent()) {
        await registration?.rollback();
        throw BlockExecutionException(
          '任务已取消',
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      // The service commits the step only after saving its output checkpoint.
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
      continue;
    }

    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.running,
    );

    if (automatic && !autoSelected && awaitingSelection) {
      final us = task.steps.where(
        (s) => s.type == catcatch.StepType.userSelecting,
      );
      if (us.isNotEmpty && !us.first.completed && !us.first.skipped) {
        if (task.detectedMedia.isNotEmpty) {
          try {
            final candidates = catCatchSafeResourceCandidates(
              task.detectedMedia,
              desiredType: desiredType,
            );
            if (automaticWithPrompt && candidates.length != 1) {
              // Keep the existing resource picker active until the user picks.
              continue;
            }
            final selected = automaticWithPrompt
                ? candidates.firstOrNull
                : selectAutomaticCatCatchResource(
                    task.detectedMedia,
                    desiredType: desiredType,
                  );
            if (selected == null) {
              throw FormatException(
                automaticWithPrompt
                    ? '没有符合输出类型的安全资源，请手动检查下载资源'
                    : '没有可安全自动选择的完整资源，请关闭自动选择后手动选择',
              );
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

    if (automatic && !autoConfirmed && awaitingConfirmation) {
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
      .map(
        (s) =>
            '${s.type.name}:${s.completed}:${s.skipped}:${s.failed}:${s.progress}',
      )
      .join('|');
  return '${task.status.name}|${task.downloadedBytes}|'
      '${task.selectedMedia?.url}|${task.metadata['pendingConfirm']}|$steps';
}

/// Discovery order depends on network timing. Choose a complete video before
/// a playlist, then audio. An untyped shared container can satisfy either
/// declared output only after its downloaded tracks are checked. URL and
/// metadata break ties.
/// Split tracks need a separate audio/video merge decision and are never guessed.
MediaResource? selectAutomaticCatCatchResource(
  List<MediaResource> resources, {
  IOType? desiredType,
}) {
  return catCatchSafeResourceCandidates(
    resources,
    desiredType: desiredType,
  ).firstOrNull;
}

/// All non-split resources that satisfy the output policy. Ambiguity prompting
/// uses the full set; legacy Automatic continues to pick its deterministic top.
List<MediaResource> catCatchSafeResourceCandidates(
  List<MediaResource> resources, {
  IOType? desiredType,
}) {
  int rank(MediaResource media) {
    final kind = catCatchResourceKindHint(media);
    if (kind == CatCatchMediaKind.audio) return 2;
    if (media.isPlaylist) return 1;
    if (kind == CatCatchMediaKind.video) return 0;
    if (catCatchIsSharedContainerExtension(media.ext)) return 3;
    return 4;
  }

  final available = resources
      .where((media) => !media.isLikelySplitTrack && rank(media) != 4)
      .toList();
  bool matchesDeclaredType(MediaResource media) {
    final priority = rank(media);
    if (desiredType == IOType.audio) return priority == 2 || priority == 3;
    if (desiredType == IOType.video) return priority < 2 || priority == 3;
    return true;
  }

  final preferred = available.where(matchesDeclaredType).toList();
  // Discovery MIME can mislabel shared containers. Keep the existing fallback
  // only when no resource advertises the requested type; download verification
  // still decides whether that shared container is actually acceptable.
  final candidates = preferred.isNotEmpty || desiredType == null
      ? preferred
      : available
          .where((media) => catCatchIsSharedContainerExtension(media.ext))
          .toList();
  candidates.sort(_compareCatCatchCandidates);
  return candidates;
}

/// Resources shown by automatic-with-prompt after applying the downstream
/// type. Split tracks remain available when their own track matches the type.
@visibleForTesting
List<MediaResource> catCatchPromptResourceCandidates(
  List<MediaResource> resources, {
  IOType? desiredType,
}) {
  bool matchesResolvedType(MediaResource media) {
    if (desiredType == null) return true;
    final hint = catCatchResourceKindHint(media);
    if (hint == null) {
      return catCatchIsSharedContainerExtension(media.ext) ||
          (desiredType == IOType.video && media.isPlaylist);
    }
    return desiredType == IOType.audio
        ? hint == CatCatchMediaKind.audio
        : hint == CatCatchMediaKind.video;
  }

  final candidates = catCatchSafeResourceCandidates(
    resources,
    desiredType: desiredType,
  ).where(matchesResolvedType).toList();
  final included = candidates.map((media) => media.url).toSet();
  for (final media in resources) {
    if (included.contains(media.url)) continue;
    final matches = matchesResolvedType(media);
    if (matches) {
      candidates.add(media);
      included.add(media.url);
    }
  }
  return candidates;
}

int _compareCatCatchCandidates(MediaResource a, MediaResource b) {
  int rank(MediaResource media) {
    final kind = catCatchResourceKindHint(media);
    if (kind == CatCatchMediaKind.audio) return 2;
    if (media.isPlaylist) return 1;
    if (kind == CatCatchMediaKind.video) return 0;
    if (catCatchIsSharedContainerExtension(media.ext)) return 3;
    return 4;
  }

  {
    final priority = rank(a).compareTo(rank(b));
    if (priority != 0) return priority;
    final url = a.url.compareTo(b.url);
    if (url != 0) return url;
    return '${a.name}|${a.ext}|${a.mimeType}|${a.groupId}'.compareTo(
      '${b.name}|${b.ext}|${b.mimeType}|${b.groupId}',
    );
  }
}

/// Keep the flow's declared output in sync with the engine's gallery routing.
Future<IOType> catCatchOutputType(catcatch.CatCatchTask task) async {
  final kind = await catCatchMediaKindFromFile(
    task,
    task.downloadedFilePath ?? '',
  );
  return switch (kind) {
    CatCatchMediaKind.audio => IOType.audio,
    CatCatchMediaKind.video => IOType.video,
    CatCatchMediaKind.other => IOType.file,
  };
}
