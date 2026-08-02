import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
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

Future<String> _callAsrApi({
  required Uint8List audioBytes,
  required String audioFormat,
  required String host,
  required String apiKey,
  required String modelId,
  Map<String, dynamic> typeConfig = const {},
}) async {
  final dio = Dio();
  try {
    final mimeStr = audioFormat == 'wav' ? 'audio/wav' : 'audio/$audioFormat';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audioBytes,
        filename: 'audio.$audioFormat',
        contentType: DioMediaType.parse(mimeStr),
      ),
      'model': modelId,
      'response_format': 'json',
      ..._buildAsrFormParams(typeConfig),
    });
    // A stalled server must not hang the flow forever — the executor's
    // catch routes the timeout through failSubTask like every other block.
    final response = await dio
        .post(
          host,
          data: formData,
          options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        )
        .timeout(const Duration(minutes: 10));
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
  final configs = providerEntries.entries
      .where((e) => e.type == 'asr')
      .expand((e) => e.configs)
      .toList();

  if (configs.isEmpty || modelIndex >= configs.length) {
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

  final config = configs[modelIndex];
  final model = config.models.isNotEmpty ? config.models.first : null;
  if (model == null) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      'ASR模型配置为空',
    );
    throw BlockExecutionException(
      '模型配置为空',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final result = await _callAsrApi(
      audioBytes: audioBytes,
      audioFormat: audioFormat,
      host: config.host,
      apiKey: config.key,
      modelId: model.modelId,
      typeConfig: model.typeConfig,
    );
    bgNotifier.updateStep(taskId, 0, completed: true);
    bgNotifier.setResult(taskId, result);

    final textPath = await saveTextForFlow(
      result,
      saveFolder: saveFolder,
      title: title,
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
