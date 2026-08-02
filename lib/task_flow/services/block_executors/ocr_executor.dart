import 'dart:async';
import 'dart:convert';
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

Future<String> _callOcrApi({
  required Uint8List imageBytes,
  required String imageFormat,
  required String host,
  required String apiKey,
  required String modelId,
}) async {
  final dio = Dio();
  final cancelToken = CancelToken();
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
    // A stalled server must not hang the flow forever — the executor's
    // catch routes the timeout through failSubTask like every other block,
    // and the token cancels the request so no socket lingers.
    final response = await dio
        .post(
      host,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    )
        .timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        cancelToken.cancel();
        throw TimeoutException('请求超时');
      },
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

Future<String> executeOcrBlock({
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

  final configs = providerEntries.entries
      .where((e) => e.type == 'ocr')
      .expand((e) => e.configs)
      .toList();
  if (configs.isEmpty) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '未配置OCR模型',
    );
    throw BlockExecutionException(
      '未配置OCR模型',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = configs.first;
  final model = config.models.isNotEmpty ? config.models.first : null;
  if (model == null) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      'OCR模型配置为空',
    );
    throw BlockExecutionException(
      '模型配置为空',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final result = await _callOcrApi(
      imageBytes: imageBytes,
      imageFormat: imageFormat,
      host: config.host,
      apiKey: config.key,
      modelId: model.modelId,
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
