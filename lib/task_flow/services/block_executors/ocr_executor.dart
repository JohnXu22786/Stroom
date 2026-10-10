import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/ocr_service.dart';
import '../../../utils/http_timeout.dart';
import '../../../utils/ocr_image_payload.dart';
import '../../../utils/provider_models.dart';
import '../../models/block_type_definition.dart';
import '../../models/task_flow_execution.dart';
import '../../models/task_flow_definition.dart';
import '../../models/task_flow_exception.dart';
import '../../providers/task_flow_execution_provider.dart';
import 'shared_helpers.dart';

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

  /// Allows the response to be held and released in cancellation tests.
  Future<String> Function(Uint8List, String)? requestOcr,

  /// Controlled Dio client for request/response contract tests.
  Dio? ocrDio,
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

  late final OcrImagePayload payload;
  try {
    payload = await prepareOcrImagePayload(imageBytes);
  } on FormatException catch (error) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      error.message,
    );
    throw BlockExecutionException(
      error.message,
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
  imageBytes = payload.bytes;
  imageFormat = payload.format;

  // Model-level selection, same granularity as the OCR page: the shared
  // flattened list (configs without host/key are excluded).
  final selected =
      resolveProviderModel(providerEntries, 'ocr', block.params['modelRef']);
  if (selected == null) {
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '未配置OCR模型或模型引用已失效，请重新选择',
    );
    throw BlockExecutionException(
      '未配置OCR模型',
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  final config = selected.config;
  final model = selected.model;

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final String result;
    if (requestOcr != null) {
      result = await requestOcr(imageBytes, imageFormat);
    } else {
      final service = OcrService(
        config: OcrConfig(
          host: config.host,
          apiKey: config.key,
          model: model.modelId,
          typeConfig: model.typeConfig,
          customParams: model.customParams,
        ),
        dio: ocrDio,
        connectTimeout: connectTimeoutDefault,
        sendTimeout: sendTimeoutForBytes(
          _encodedBodyLength(imageBytes, imageFormat),
        ),
        receiveTimeout: receiveTimeoutFallback,
      );
      late final OcrResult ocrResult;
      try {
        ocrResult = await service.recognize(
          imageBytes: imageBytes,
          imageFormat: imageFormat,
          cancelToken: cancelToken,
        );
      } finally {
        if (ocrDio == null) service.close();
      }
      if (!ocrResult.isComplete) {
        if (!isFlowExecutionActive(execNotifier, execId)) {
          throw BlockExecutionException(
            '任务流已结束或删除',
            blockType: def.typeKey.name,
            blockTitle: def.label,
          );
        }
        bgNotifier.setResult(taskId, ocrResult.text);
        final error = 'OCR 返回了不完整结果（finish_reason=${ocrResult.finishReason}）';
        bgNotifier.updateStep(taskId, 0, failed: true, error: error);
        failSubTask(
          bgNotifier,
          taskId,
          execNotifier,
          execId,
          flowSubTask.id,
          error,
        );
        throw BlockExecutionException(
          error,
          blockType: def.typeKey.name,
          blockTitle: def.label,
        );
      }
      result = ocrResult.text;
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
