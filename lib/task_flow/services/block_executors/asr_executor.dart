import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/asr_service.dart';
import '../../../utils/audio_utils.dart';
import '../../../utils/file_manifest.dart';
import '../../../utils/provider_models.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Builds the ASR block's output record title from the input audio path.
///
/// In-app audio (TTS synthesis / audio separation products) is stored
/// under a hash filename (`<hash>.<format>`), so the raw basename would
/// surface as a meaningless hex string. When the input hash matches one
/// distinct non-empty [AudioRecord] name, that human-readable name is used —
/// for TTS products that is the source text's first 20 chars, so a
/// chat → tts → asr flow names its result after the text it came from.
/// Matching records with different names cannot identify the source record,
/// so those inputs use the neutral hash-based title.
@visibleForTesting
String asrOutputTitleFromRecords(String input, List<AudioRecord> records) {
  final inputBasename = p.basename(input);
  final inputHash = p.basenameWithoutExtension(inputBasename);
  final matchingNames = records
      .where((record) => record.hash == inputHash)
      .map((record) => record.name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  if (matchingNames.length == 1) {
    return '语音识别_${matchingNames.single}';
  }
  return '语音识别_$inputHash';
}

Future<String> executeAsrBlock({
  required TaskFlowBlock block,
  required BlockTypeDefinition def,
  required String input,
  required String execId,
  required TaskFlowExecutionNotifier execNotifier,
  required FlowSubTask flowSubTask,
  required BackgroundTaskNotifier bgNotifier,
  required ProviderEntriesState providerEntries,
  CancelToken? cancelToken,

  /// Allows the response to be held and released in cancellation tests.
  Future<String> Function(Uint8List, String)? requestAsr,
  AsrService Function(AsrConfig config)? asrServiceFactory,
}) async {
  // Resolve a human-readable base for the output record name: in-app
  // audio is stored under a hash filename — map it back to the record's
  // name (TTS products carry the source text) so results don't surface
  // as hex garbage. Unreadable record list → plain basename.
  List<AudioRecord> audioRecords;
  try {
    audioRecords = await FileManifest.loadRecords();
  } catch (_) {
    audioRecords = const [];
  }
  final title = asrOutputTitleFromRecords(input, audioRecords);

  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  bgNotifier.addTask(
    type: BackgroundTaskType.asr,
    title: title,
    taskId: taskId,
  );

  final selected = resolveProviderModel(
    providerEntries,
    'asr',
    block.params['modelRef'],
  );
  if (selected == null) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '未配置ASR模型或模型引用已失效，请重新选择',
    );
    throw BlockExecutionException(
      '未配置ASR模型',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = createAsrConfigFromProviderModel(
    host: selected.config.host,
    apiKey: selected.config.key,
    model: selected.model,
    providerTypeConfig: selected.config.typeConfig,
  );
  if (config.uploadMethod == AudioUploadMethod.url) {
    const message = '当前供应商使用 URL 上传方式，任务流本地音频文件不能使用该配置';
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      message,
    );
    throw BlockExecutionException(
      message,
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  Uint8List audioBytes;
  String audioFormat;
  try {
    final file = File(input);
    if (!await file.exists()) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '输入文件不存在: $input',
      );
      throw BlockExecutionException(
        '输入文件不存在',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    audioBytes = await file.readAsBytes();
    audioFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
    // Prefer the content-based format over the file extension — a file
    // with an unknown extension (or a .mp3-suffixed file that is actually
    // WAV) would otherwise be mislabeled in the multipart MIME and get
    // rejected by strict endpoints. Falls back to the extension when the
    // content is not a known audio format (detectAudioFormat → 'pcm').
    final detected = normalizeAudioFormat(detectAudioFormat(audioBytes));
    if (detected != 'pcm') {
      audioFormat = detected;
    }
    audioFormat = normalizeAsrUploadFormat(audioFormat);
    if (audioBytes.isEmpty) {
      failSubTask(
        bgNotifier,
        taskId,
        execNotifier,
        execId,
        flowSubTask.id,
        '输入文件为空',
      );
      throw BlockExecutionException(
        '输入文件为空',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '读取文件失败: $e',
    );
    throw BlockExecutionException(
      '读取文件失败',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final saveFolder = asStringParam(block.params, 'saveFolder', '');

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final String result;
    if (requestAsr != null) {
      result = await requestAsr(audioBytes, audioFormat);
    } else {
      final service =
          asrServiceFactory?.call(config) ?? AsrService(config: config);
      try {
        result = (await service.transcribe(
          audioBytes: audioBytes,
          audioFormat: audioFormat,
          cancelToken: cancelToken,
        ))
            .text;
      } finally {
        service.close();
      }
    }
    // The flow may have ended while the request was in flight — don't
    // save an orphaned text record.
    if (!isFlowExecutionActive(execNotifier, execId)) {
      throw BlockExecutionException(
        '任务流已结束或删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    bgNotifier.updateStep(taskId, 0, completed: true);
    bgNotifier.setResult(taskId, result);

    final textPath = await saveTextForFlow(
      result,
      saveFolder: saveFolder,
      title: title,
      // Guard against a flow cancelled or deleted mid-save.
      shouldCommit: () => isFlowExecutionActive(execNotifier, execId),
    );
    if (!isFlowExecutionActive(execNotifier, execId)) {
      throw BlockExecutionException(
        '任务流已结束或删除',
        blockType: def.typeKey.name,
        blockTitle: def.label,
      );
    }
    bgNotifier.completeTask(taskId, downloadedFilePath: textPath);
    execNotifier.updateSubTaskStatus(
      execId,
      flowSubTask.id,
      TaskStatus.completed,
    );
    return result;
  } catch (e) {
    if (e is BlockExecutionException) rethrow;
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '识别失败: $e',
    );
    throw BlockExecutionException(
      e.toString(),
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
}
