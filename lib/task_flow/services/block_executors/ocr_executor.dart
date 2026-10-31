import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../models/ocr_batch_execution.dart';
import '../../../providers/background_task_provider.dart';
import '../../../providers/provider_config.dart';
import '../../../providers/task_provider_shared.dart';
import '../../../services/ocr_service.dart';
import '../../../utils/http_timeout.dart';
import '../../../utils/ocr_image_payload.dart';
import '../../../utils/ocr_diagnostics.dart';
import '../../../utils/provider_models.dart';
import '../../models/flow_payload.dart';
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

Future<Uint8List> _readInputBytesUpTo(File file, int maxBytes) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, maxBytes + 1)) {
    bytes.add(chunk);
  }
  return bytes.takeBytes();
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

  /// Allows bounded reads to be observed in preflight limit tests.
  Future<Uint8List> Function(File, int)? readInputBytes,

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
  final file = File(input);
  try {
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

  // Resolve the configured OCR budget before reading bytes. Estimate the
  // request with the actual JSON envelope, then apply the flow image ceiling.
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
  final requestSizeBudgetBytes = effectiveOcrRequestSizeBudgetBytes(
    modelValue: model.typeConfig['requestSizeBudgetBytes'],
    providerValue: config.typeConfig['requestSizeBudgetBytes'],
  );
  final ocrConfig = OcrConfig(
    host: config.host,
    apiKey: config.key,
    model: model.modelId,
    requestSizeBudgetBytes: requestSizeBudgetBytes,
    typeConfig: model.typeConfig,
    customParams: model.customParams,
  );
  final sizeEstimator = OcrService(config: ocrConfig);
  late final int maxRequestImageBytes;
  late final int maxReencodedPngBytes;
  try {
    maxRequestImageBytes = sizeEstimator.maxRawImageBytesWithinRequestBudget();
    maxReencodedPngBytes = sizeEstimator.maxRawImageBytesWithinRequestBudget(
      imageFormat: 'png',
    );
  } catch (e) {
    final safeError = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
          e.toString(),
          excludedValues: [config.key],
        ) ??
        OcrDiagnosticSnapshot.safeTaskError(e, excludedValues: [config.key]);
    bgNotifier.updateStep(taskId, 0, failed: true, error: safeError);
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '识别失败: $safeError',
    );
    throw BlockExecutionException(
      safeError,
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  } finally {
    sizeEstimator.close();
  }
  final maxInputBytes = maxRequestImageBytes < maxFlowImageInputBytes
      ? maxRequestImageBytes
      : maxFlowImageInputBytes;

  BlockExecutionException oversizedInputException() {
    final limitLabel = maxRequestImageBytes < maxFlowImageInputBytes
        ? 'OCR 请求大小预算（${ocrRequestSizeBudgetMib(requestSizeBudgetBytes)} MiB）'
        : '任务流图片输入上限（${ocrRequestSizeBudgetMib(maxFlowImageInputBytes)} MiB）';
    final error = 'OCR 输入图片超过$limitLabel允许的范围，请缩小图片后重试';
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      error,
    );
    return BlockExecutionException(
      error,
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }

  try {
    final inputLength = await file.length();
    if (inputLength > maxInputBytes) {
      throw oversizedInputException();
    }
    imageBytes = await (readInputBytes ?? _readInputBytesUpTo)(file, maxInputBytes);
    if (imageBytes.length > maxInputBytes) {
      throw oversizedInputException();
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

  late final OcrImagePayload payload;
  try {
    payload = await prepareOcrImagePayload(
      imageBytes,
      maxReencodedPngBytes: maxReencodedPngBytes,
    );
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

  try {
    bgNotifier.updateStep(taskId, 0, running: true);
    final String result;
    if (requestOcr != null) {
      result = await requestOcr(imageBytes, imageFormat);
    } else {
      final service = OcrService(
        config: ocrConfig,
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
    final safeError = OcrDiagnosticSnapshot.sanitizeStoredTaskError(
          e.toString(),
          excludedValues: [config.key],
        ) ??
        OcrDiagnosticSnapshot.safeTaskError(
          e,
          excludedValues: [config.key],
        );
    bgNotifier.updateStep(taskId, 0, failed: true, error: safeError);
    failSubTask(
      bgNotifier,
      taskId,
      execNotifier,
      execId,
      flowSubTask.id,
      '识别失败: $safeError',
    );
    throw BlockExecutionException(
      safeError,
      blockType: def.typeKey.name,
      blockTitle: def.label,
    );
  }
}
