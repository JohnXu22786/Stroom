import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../utils/http_timeout.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

Future<String> _callOcrApi({
  required Uint8List imageBytes,
  required String imageFormat,
  required String host,
  required String apiKey,
  required String modelId,
  CancelToken? cancelToken,
}) async {
  // Layered timeouts: fast-fail on connect/upload issues, no artificial
  // kill for slow-but-healthy servers (only a 60-min silent-server bound).
  // The upload budget is sized from the encoded JSON body (base64 inflates
  // the image ~33%), not the raw image bytes.
  final dio = Dio(
    BaseOptions(
      connectTimeout: connectTimeoutDefault,
      sendTimeout: sendTimeoutForBytes(
        _encodedBodyLength(imageBytes, imageFormat),
      ),
      receiveTimeout: receiveTimeoutFallback,
    ),
  );
  try {
    final dataUri =
        'data:image/$imageFormat;base64,${base64Encode(imageBytes)}';
    final body = {
      'model': modelId,
      'max_tokens': 4096,
      'temperature': 0.0,
      'messages': [
        {'role': 'system', 'content': '请提取图片中的所有文字内容。只返回文字，不要添加任何解释。'},
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': dataUri, 'detail': 'high'},
            },
          ],
        },
      ],
    };
    final response = await dio.post(
      host,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );
    if (response.data is Map) {
      final choices = response.data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final msg = choices.first['message'] as Map<String, dynamic>?;
        return msg?['content'] as String? ?? '';
      }
    }
    return '';
  } finally {
    dio.close();
  }
}

/// Approximate length of the JSON request body: the base64 data-URI is the
/// dominant term (~1.33x the raw image bytes) plus a fixed envelope.
int _encodedBodyLength(Uint8List imageBytes, String imageFormat) {
  final b64 = base64Encode(imageBytes).length;
  final dataUri = 'data:image/$imageFormat;base64,'.length + b64;
  return dataUri + 512; // JSON envelope overhead (model, messages, etc.)
}

Future<String> executeOcrBlock({
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
  final title = '文字识别_${p.basenameWithoutExtension(inputBasename)}';
  final saveFolder = asStringParam(block.params, 'saveFolder', '');

  final taskId = const Uuid().v4();
  execNotifier.updateSubTaskId(execId, flowSubTask.id, taskId);
  execNotifier.updateSubTaskStatus(execId, flowSubTask.id, TaskStatus.running);
  bgNotifier.addTask(
    type: BackgroundTaskType.ocr,
    title: title,
    taskId: taskId,
  );

  Uint8List imageBytes;
  String imageFormat;
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
    imageBytes = await file.readAsBytes();
    imageFormat = p.extension(input).replaceFirst('.', '').toLowerCase();
    if (imageBytes.isEmpty) {
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

  // Model-level selection, same granularity as the OCR page: flatten all
  // configured OCR models (each entry carries its config for host/key).
  final modelIndex = asIntParam(block.params, 'modelIndex', 0);
  final models = <({dynamic config, dynamic model})>[
    for (final e in providerEntries.entries)
      if (e.type == 'ocr')
        for (final c in e.configs)
          if ((c.host as String? ?? '').isNotEmpty &&
              (c.key as String? ?? '').isNotEmpty)
            for (final m in c.models as List<dynamic>? ?? const [])
              (config: c, model: m),
  ];
  if (models.isEmpty || modelIndex >= models.length) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '未配置OCR模型或索引越界',
    );
    throw BlockExecutionException(
      '未配置OCR模型',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = models[modelIndex].config;
  final model = models[modelIndex].model;

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final result = await _callOcrApi(
      imageBytes: imageBytes,
      imageFormat: imageFormat,
      host: config.host,
      apiKey: config.key,
      modelId: model.modelId,
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
