import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../models/tts_models.dart';
import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/audio_utils.dart';
import '../../../utils/http_timeout.dart';
import '../../../utils/provider_models.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

/// Builds the multipart fields from the model's typeConfig, mirroring the
/// app's own ASR request (asr_service.dart `_buildSharedParams`): only
/// enabled, user-configured params are sent — never the raw `enable*`
/// flags or a temperature the user turned off.
Map<String, dynamic> _buildAsrFormParams(Map<String, dynamic> tc) {
  final params = <String, dynamic>{};
  if (tc['enableResponseFormat'] == true && tc.containsKey('responseFormat')) {
    params['response_format'] = tc['responseFormat'] as String;
  }
  // Mirrors asr_service.dart effectiveLanguage (typeConfig-gated part).
  if (tc['enableLanguage'] == true && tc.containsKey('language')) {
    final lang = tc['language'] as String?;
    if (lang != null && lang.isNotEmpty) {
      params['language'] = lang;
    }
  }
  if (tc['enableTemperature'] == true && tc.containsKey('temperature')) {
    params['temperature'] = (tc['temperature'] as num).toDouble();
  }
  if (tc['enableTimestampGranularities'] == true &&
      tc.containsKey('timestampGranularities')) {
    params['timestamp_granularities'] = tc['timestampGranularities'] as String;
  }
  if (tc['enablePrompt'] == true && tc.containsKey('prompt')) {
    final prompt = tc['prompt'] as String;
    if (prompt.trim().isNotEmpty) {
      params['prompt'] = prompt;
    }
  }
  return params;
}

/// Parses a custom param value by type, mirroring asr_service.dart
/// `_parseParamValue`.
dynamic _parseCustomParamValue(String value, String type) {
  switch (type) {
    case 'number':
      return num.tryParse(value) ?? value;
    case 'boolean':
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
      return value;
    case 'json':
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    case 'string':
    default:
      return value;
  }
}

/// Builds the model's custom param fields, mirroring asr_service.dart
/// `_buildSharedParams` (skip empty names/values, parse by type).
Map<String, dynamic> _customParamFields(List<CustomParam> customParams) {
  final fields = <String, dynamic>{};
  for (final param in customParams) {
    final name = param.paramName.trim();
    if (name.isEmpty) continue;
    final value = param.defaultValue.trim();
    if (value.isEmpty) continue;
    final parsed = _parseCustomParamValue(value, param.type);
    fields[name] = parsed is String ? parsed : parsed.toString();
  }
  return fields;
}

Future<String> _callAsrApi({
  required Uint8List audioBytes,
  required String audioFormat,
  required String host,
  required String apiKey,
  required String modelId,
  Map<String, dynamic> typeConfig = const {},
  List<CustomParam> customParams = const [],
  CancelToken? cancelToken,
}) async {
  // Layered timeouts: fast-fail on connect/upload issues, no artificial
  // kill for slow-but-healthy servers (only a 60-min silent-server bound).
  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeoutDefault,
      sendTimeout: sendTimeoutForBytes(audioBytes.length),
      receiveTimeout: receiveTimeoutFallback,
    ),
  );
  try {
    // Same MIME mapping as the app's own ASR page (getMimeType) — e.g.
    // mp3 → audio/mpeg, m4a → audio/mp4; non-standard types like
    // audio/mp3 are rejected by strict OpenAI-compatible endpoints.
    final mimeStr = getMimeType(audioFormat);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: 'audio.$audioFormat',
        contentType: DioMediaType.parse(mimeStr),
      ),
      'model': modelId,
      'response_format': 'json',
      ..._buildAsrFormParams(typeConfig),
      ..._customParamFields(customParams),
    });
    final response = await dio.post(
      host,
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      cancelToken: cancelToken,
    );
    if (response.data is Map) return (response.data['text'] as String?) ?? '';
    return response.data.toString();
  } finally {
    dio.close();
  }
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
}) async {
  final inputBasename = p.basename(input);
  final title = '语音识别_${p.basenameWithoutExtension(inputBasename)}';

  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  bgNotifier.addTask(
    type: BackgroundTaskType.asr,
    title: title,
    taskId: taskId,
  );

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

  final modelIndex = asIntParam(block.params, 'modelIndex', 0);
  final saveFolder = asStringParam(block.params, 'saveFolder', '');
  // Model-level selection, same granularity as the ASR page: the shared
  // flattened list (configs without host/key are excluded).
  final models = flattenProviderModels(providerEntries, 'asr');

  if (models.isEmpty || modelIndex >= models.length) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '未配置ASR模型或索引越界',
    );
    throw BlockExecutionException(
      '未配置ASR模型',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = models[modelIndex].config;
  final model = models[modelIndex].model;

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final result = await _callAsrApi(
      audioBytes: audioBytes,
      audioFormat: audioFormat,
      host: config.host,
      apiKey: config.key,
      modelId: model.modelId,
      typeConfig: model.typeConfig,
      // Model-level custom params — the same list the ASR settings page
      // edits and the standalone ASR page sends.
      customParams: model.customParams,
      cancelToken: cancelToken,
    );
    // The flow may have been deleted while the request was in flight —
    // don't save an orphaned text record.
    if (!execNotifier.state.any((e) => e.id == execId)) {
      throw BlockExecutionException(
        '任务流已删除',
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
      // Guard against a flow deleted mid-save (narrow race after the
      // existence check above).
      shouldCommit: () => execNotifier.state.any((e) => e.id == execId),
    );
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
